extends Node
## SaveManager (autoload): the only code that reads or writes save files.
##
## Slots: user://saves/slot_<1..3>.json, one JSON document = WorldState.to_dict().
## Writing is crash-safe: the new data goes to slot_N.json.tmp, the current file becomes
## slot_N.json.bak (the previous version is always kept), then the temp file takes its
## place. Loading tries slot_N.json, then slot_N.json.bak, and never crashes: a file that
## cannot be read is reported and left alone.
##
## Versions: meta.save_version, upgraded one step at a time by _migrate_step() (v0 is the
## old GameState format: {version 3|4, chapter, checkpoint, flags, echoes_seen, memory, world}).
## import_legacy_saves() folds the old two-file saves (save.json + world_test.json) into
## slot 1 once, logs what could not be carried over and renames them *.migrated.
##
## Autosaves (to the active slot) on EventBus.checkpoint_rested and region_changed.
## Never writes while a debug --demo is running.

const EchoDirector := preload("res://scripts/echoes/echo_director.gd")
const SLOTS := 3

## Folders are variables so the headless tests can use their own.
var directory := "user://saves/"
var legacy_directory := "user://"
## The slot the running game belongs to (0 = none yet).
var active_slot := 0
## Set by the tests: allow saving although a --demo is running.
var allow_in_demo := false


func _ready() -> void:
	EventBus.checkpoint_rested.connect(func(_id: StringName): autosave())
	EventBus.region_changed.connect(func(_r: StringName): autosave())


# --- Slots ---------------------------------------------------------------------------------------

func slot_path(slot: int) -> String:
	return directory + "slot_%d.json" % slot


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(slot_path(slot) + ".bak")


## {exists, readable, last_saved_timestamp, playtime, region, chapter} without loading it.
func slot_info(slot: int) -> Dictionary:
	var info := {"exists": slot_exists(slot), "readable": false, "last_saved_timestamp": 0, "playtime": 0.0, "region": "", "chapter": 0}
	if not info["exists"]:
		return info
	for path in [slot_path(slot), slot_path(slot) + ".bak"]:
		var d := _read_state(path)
		if not d.is_empty():
			info["readable"] = true
			info["last_saved_timestamp"] = int(d["meta"]["last_saved_timestamp"])
			info["playtime"] = float(d["meta"]["playtime"])
			info["region"] = String(d["player"]["current_region"])
			info["chapter"] = int(d["story"]["chapter"])
			break
	return info


func has_any_save() -> bool:
	for s in range(1, SLOTS + 1):
		if slot_exists(s):
			return true
	return false


## The slot written most recently, or 0.
func most_recent_slot() -> int:
	var best := 0
	var best_t := -1
	for s in range(1, SLOTS + 1):
		var info := slot_info(s)
		if info["readable"] and int(info["last_saved_timestamp"]) > best_t:
			best = s
			best_t = int(info["last_saved_timestamp"])
	return best


## The first slot with no file, or 0 if all are taken.
func first_empty_slot() -> int:
	for s in range(1, SLOTS + 1):
		if not slot_exists(s):
			return s
	return 0


## The slot that has gone longest without a save (what "new game" offers to overwrite).
func oldest_slot() -> int:
	var best := 1
	var best_t := 9223372036854775807
	for s in range(1, SLOTS + 1):
		var t := int(slot_info(s)["last_saved_timestamp"])
		if t < best_t:
			best = s
			best_t = t
	return best


## "27.09.2026 14:32" in local time, for the overwrite confirmation.
static func format_time(unix: int) -> String:
	if unix <= 0:
		return "—"
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var d := Time.get_datetime_dict_from_unix_time(unix + bias * 60)
	return "%02d.%02d.%04d %02d:%02d" % [d["day"], d["month"], d["year"], d["hour"], d["minute"]]


# --- Saving --------------------------------------------------------------------------------------

## Never inside an echo (EchoDirector.active) or during a debug --demo.
func can_save() -> bool:
	return active_slot > 0 and not EchoDirector.active and (Settings.demo == "" or allow_in_demo)


func autosave() -> void:
	if can_save():
		save(active_slot)


## Writes WorldState to `slot` (default: the active slot). False if not allowed or failed.
func save(slot := -1) -> bool:
	if slot < 0:
		slot = active_slot
	if slot < 1 or slot > SLOTS:
		push_warning("SaveManager: no slot to save to")
		return false
	if Settings.demo != "" and not allow_in_demo:
		return false
	if EchoDirector.active:
		push_warning("SaveManager: no saving inside an echo")
		return false
	EventBus.saving.emit(slot)   # the active mode copies live values in now
	WorldState.mark_saved(int(Time.get_unix_time_from_system()))
	if not _write_atomic(slot_path(slot), JSON.stringify(WorldState.to_dict(), "\t")):
		return false
	active_slot = slot
	EventBus.game_saved.emit(slot)
	return true


func _write_atomic(path: String, text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var tmp := path + ".tmp"
	var bak := path + ".bak"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.flush()
	f.close()
	# The file on disk must read back before it may replace anything
	if _read_state(tmp).is_empty():
		push_error("SaveManager: %s did not read back; the old save is untouched" % tmp)
		return false
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(bak))
		var e := DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(bak))
		if e != OK:
			push_error("SaveManager: cannot keep the previous save as .bak (%s)" % error_string(e))
			return false
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("SaveManager: cannot move %s into place (%s); the previous save is in .bak" % [tmp, error_string(err)])
		return false
	return true


# --- Loading -------------------------------------------------------------------------------------

## Loads `slot` into WorldState: the main file, else its .bak. False (state unchanged) if
## neither can be read.
func load_slot(slot: int) -> bool:
	for path in [slot_path(slot), slot_path(slot) + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var d := _read_state(path)
		if d.is_empty():
			push_warning("SaveManager: %s is unreadable" % path)
			continue
		if WorldState.from_dict(d):
			if path.ends_with(".bak"):
				push_warning("SaveManager: slot %d main file was bad; loaded its backup" % slot)
			active_slot = slot
			EventBus.game_loaded.emit(slot)
			return true
	push_error("SaveManager: slot %d could not be loaded" % slot)
	return false


## Parses a save file and upgrades it to the current version. {} if it cannot be used.
func _read_state(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("SaveManager: %s is not valid JSON (line %d: %s)" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	var migrated := migrate(json.data)
	return WorldState.normalize(migrated)


## Upgrades any known save format to WorldState.SAVE_VERSION, one version at a time.
## {} for unknown or future formats.
func migrate(data: Variant) -> Dictionary:
	if not (data is Dictionary):
		return {}
	var d: Dictionary = data
	var version := 0
	if d.get("meta") is Dictionary:
		version = int(d["meta"].get("save_version", 0))
	elif not d.has("version"):
		return {}
	if version > WorldState.SAVE_VERSION:
		push_warning("SaveManager: save_version %d is newer than this game (%d)" % [version, WorldState.SAVE_VERSION])
		return {}
	while version < WorldState.SAVE_VERSION:
		d = _migrate_step(d, version)
		if d.is_empty():
			return {}
		version += 1
	return d


## One step up the chain: `from` → `from + 1`. Add a case for every future schema change.
func _migrate_step(d: Dictionary, from: int) -> Dictionary:
	match from:
		0:
			return _legacy_to_v1(d, [])
		1:
			return _v1_to_v2(d)
		2:
			return _v2_to_v3(d)
		3:
			return _v3_to_v4(d)
		# 4: return _v4_to_v5(d)
	push_warning("SaveManager: no migration from save_version %d" % from)
	return {}


## The old GameState file (versions 3 and 4) → the v1 layout. `lost` collects what could
## not be carried over, for the report.
func _legacy_to_v1(old: Dictionary, lost: Array) -> Dictionary:
	if int(old.get("version", 0)) not in [3, 4]:
		lost.append("unknown old save version %s" % str(old.get("version")))
		return {}
	var s := WorldState.default_state()
	var chapter := int(old.get("chapter", 1))
	s["story"]["chapter"] = chapter
	s["story"]["checkpoint"] = String(old.get("checkpoint", ""))
	s["story"]["echoes_seen"] = old.get("echoes_seen", [])
	s["player"]["current_region"] = "son_ocaq" if chapter == 2 else "kozqala"
	var flags: Dictionary = old.get("flags", {}) if old.get("flags") is Dictionary else {}
	s["flags"] = flags.duplicate()
	var mem: Dictionary = old.get("memory", {}) if old.get("memory") is Dictionary else {}
	s["player"]["burned_memories"] = mem.get("burned", [])
	var w: Dictionary = old.get("world", {}) if old.get("world") is Dictionary else {}
	_merge_legacy_world(s, w, lost)
	return s


## v2: memories get three states. The burned list becomes {id: "burned"}; everything
## else is UNKNOWN (absent). The protagonist's old name, which could appear in keys or
## values of old saves, becomes the neutral id "protagonist".
func _v1_to_v2(d: Dictionary) -> Dictionary:
	var out: Dictionary = _rename_old_protagonist(d)
	var p: Dictionary = out.get("player", {})
	var mems := {}
	for id in p.get("burned_memories", []):
		mems[String(id)] = "burned"
	p.erase("burned_memories")
	p["memories"] = mems
	out["player"] = p
	out["meta"]["save_version"] = 2
	return out


## v3: burned memories record where they burned; every memory burned before v3 burned in
## combat (echoes did not exist). NPC records get the full layout (WorldState.normalize
## fills defaults; the old reserved free-form records carry over what matches).
func _v2_to_v3(d: Dictionary) -> Dictionary:
	var p: Dictionary = d.get("player", {})
	var ctx := {}
	var mems: Dictionary = p.get("memories", {}) if p.get("memories") is Dictionary else {}
	for id in mems:
		if String(mems[id]) == "burned":
			ctx[String(id)] = "combat"
	p["burn_context"] = ctx
	d["player"] = p
	# Reserved v2 NPC records were free-form: keep the known fields, move the rest to flags
	var npcs: Dictionary = d.get("npcs", {}) if d.get("npcs") is Dictionary else {}
	for id in npcs:
		if not (npcs[id] is Dictionary):
			continue
		var rec: Dictionary = npcs[id]
		var flags: Dictionary = rec.get("flags", {}) if rec.get("flags") is Dictionary else {}
		for k in rec.keys():
			if not String(k) in ["alive", "location_id", "rescued", "relationship", "death_cause", "flags"]:
				flags[String(k)] = rec[k]
				rec.erase(k)
		rec["flags"] = flags
	d["meta"]["save_version"] = 3
	return d


## v4: the caravan head "anar" became "nermin" (STORY_BIBLE.md §7: Nərmin replaces Anar).
## Her record keeps everything it had.
const RENAMED_NPCS := {"anar": "nermin"}


func _v3_to_v4(d: Dictionary) -> Dictionary:
	var npcs: Dictionary = d.get("npcs", {}) if d.get("npcs") is Dictionary else {}
	for old_id in RENAMED_NPCS:
		if npcs.has(old_id):
			npcs[RENAMED_NPCS[old_id]] = npcs[old_id]
			npcs.erase(old_id)
	d["npcs"] = npcs
	d["meta"]["save_version"] = 4
	return d


## The protagonist was called "Ayxan" before v2; old saves may carry that name in flag
## or NPC keys and in string values ("ayxan_met" → "protagonist_met").
const OLD_PROTAGONIST_ID := "ayxan"


func _rename_old_protagonist(v: Variant) -> Variant:
	if v is Dictionary:
		var out := {}
		for k in v:
			out[_rename_old_protagonist(k)] = _rename_old_protagonist(v[k])
		return out
	if v is Array:
		return (v as Array).map(func(x): return _rename_old_protagonist(x))
	if v is String and (v as String).to_lower().contains(OLD_PROTAGONIST_ID):
		var s: String = v
		var at := s.to_lower().find(OLD_PROTAGONIST_ID)
		while at >= 0:
			s = s.substr(0, at) + "protagonist" + s.substr(at + OLD_PROTAGONIST_ID.length())
			at = s.to_lower().find(OLD_PROTAGONIST_ID)
		return s
	return v


func _merge_legacy_world(s: Dictionary, w: Dictionary, lost: Array) -> void:
	for list in WorldState.WORLD_LISTS:
		if w.has(list):
			s["world"][list] = w[list]
	for key in ["fog", "last_hearth"]:
		if w.has(key):
			s["world"][key] = w[key]
	if w.has("hour"):
		s["world"]["time_of_day"] = float(w["hour"])
	if w.has("max_flasks"):
		s["player"]["stats"]["max_flasks"] = int(w["max_flasks"])
	if w.has("pos") and w["pos"] is Array and (w["pos"] as Array).size() == 3:
		s["player"]["position"] = w["pos"]
	for k in w:
		if not (k in WorldState.WORLD_LISTS or k in ["fog", "last_hearth", "hour", "max_flasks", "pos"]):
			lost.append("world.%s (no place in the new save)" % k)


# --- Old two-file saves --------------------------------------------------------------------------

## Folds user://save.json (story) and user://world_test.json (open world) into slot 1, once.
## Returns the report lines (also printed). Does nothing if a slot already exists.
func import_legacy_saves() -> Array:
	var story_path := legacy_directory + "save.json"
	var world_path := legacy_directory + "world_test.json"
	var have_story := FileAccess.file_exists(story_path)
	var have_world := FileAccess.file_exists(world_path)
	if not have_story and not have_world:
		return []
	var report: Array = []
	if has_any_save():
		report.append("old saves found but slots already exist; old files left as they are")
		_print_log(report)
		return report
	var lost: Array = []
	var state: Dictionary = {}
	var story: Variant = _parse_json_file(story_path) if have_story else null
	if have_story:
		if story is Dictionary:
			state = _legacy_to_v1(story, lost)
			if state.is_empty():
				report.append("save.json: not a known old save, skipped")
			else:
				report.append("save.json: chapter %d, checkpoint '%s', %d flags, %d burned memories" % [
					int(state["story"]["chapter"]), state["story"]["checkpoint"], state["flags"].size(), state["player"]["burned_memories"].size()])
		else:
			report.append("save.json: unreadable, skipped")
	var world: Variant = _parse_json_file(world_path) if have_world else null
	if have_world:
		if world is Dictionary and int(world.get("version", 0)) in [3, 4]:
			if state.is_empty():
				state = WorldState.default_state()
				state["player"]["current_region"] = "kur_vadisi"
				state["player"]["burned_memories"] = []   # built in the v1 layout, like _legacy_to_v1
			var w: Dictionary = world.get("world", {}) if world.get("world") is Dictionary else {}
			_merge_legacy_world(state, w, lost)
			var wf: Dictionary = world.get("flags", {}) if world.get("flags") is Dictionary else {}
			for k in wf:
				if not state["flags"].has(k):
					state["flags"][k] = wf[k]
			report.append("world_test.json: %d hearths, %d chests, %d discovered places" % [
				state["world"]["hearths"].size(), state["world"]["chests"].size(), state["world"]["discovered"].size()])
			var wm: Dictionary = world.get("memory", {}) if world.get("memory") is Dictionary else {}
			var test_burned: Array = wm.get("burned", [])
			var kept: Array = state["player"]["burned_memories"]
			var dropped: Array = test_burned.filter(func(id): return not id in kept)
			if not dropped.is_empty():
				lost.append("memories burned only in the open-world test session: %s (not carried over)" % ", ".join(PackedStringArray(dropped)))
			if int(world.get("chapter", 1)) != 1 or String(world.get("checkpoint", "")) != "start":
				lost.append("the open-world test file's chapter/checkpoint (the story save owns those)")
		else:
			report.append("world_test.json: unreadable or unknown version, skipped")
	if state.is_empty():
		report.append("nothing could be migrated; old files left as they are")
		_print_log(report + lost.map(func(l): return "NOT MIGRATED: " + l))
		return report
	state["meta"]["save_version"] = 1          # built in the v1 layout: run the rest of the chain
	var clean := WorldState.normalize(migrate(state))
	clean["meta"]["last_saved_timestamp"] = int(Time.get_unix_time_from_system())
	if not _write_atomic(slot_path(1), JSON.stringify(clean, "\t")):
		report.append("could not write slot 1; old files left as they are")
		_print_log(report)
		return report
	for path in [story_path, world_path]:
		if FileAccess.file_exists(path):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".migrated"))
	report.append("old saves moved into slot 1; originals kept as *.migrated")
	for l in lost:
		report.append("NOT MIGRATED: " + l)
	_print_log(report)
	return report


func _parse_json_file(path: String) -> Variant:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return json.data


func _print_log(lines: Array) -> void:
	for l in lines:
		if String(l).begins_with("NOT MIGRATED"):
			push_warning("[save import] " + l)
		else:
			print("[save import] ", l)
