extends Node
## Headless checks for the state foundation: WorldState, EventBus, SaveManager, memory
## registry and translations. Uses its own folders (user://test_saves/, user://test_legacy/),
## never the player's saves.
## Run: godot --headless --path . res://scenes/tests/state_test.tscn   (exit code = failures)

const MainMenu := preload("res://scripts/ui/main_menu.gd")
const MemoryRegistry := preload("res://scripts/core/memory_registry.gd")
const TEST_DIR := "user://test_saves/"
const LEGACY_DIR := "user://test_legacy/"

var _fails := 0
var _events: Array = []


func _ready() -> void:
	SaveManager.directory = TEST_DIR
	SaveManager.legacy_directory = LEGACY_DIR
	SaveManager.allow_in_demo = true
	_run.call_deferred()


func _run() -> void:
	_translations()
	_signals()
	_round_trip()
	_memory_survives()
	_corrupt_files()
	_backup_fallback()
	await _menu_cases()
	_legacy_import()
	_wipe(TEST_DIR)
	_wipe(LEGACY_DIR)
	print("STATE SELFTEST DONE, failures: ", _fails)
	get_tree().quit(_fails)


# --- Checks --------------------------------------------------------------------------------------

func _translations() -> void:
	_check("tr() finds the memory names (Turkish)", tr("MEMORY_RUFET_FACE_NAME") == "Rüfet'in yüzü")
	var defs: Array = Memory.all()
	var combat: Array = Memory.combat_memories()
	_check("registry loads the 6 combat memories in order, plus own_name and narin", defs.size() == 8 and combat.size() == 6
		and combat[0].id == &"rufet_face" and combat[5].id == &"first_sword" and not MemoryRegistry.get_def(&"own_name").combat_burnable and not MemoryRegistry.get_def(&"narin").combat_burnable)
	for d in defs:
		if tr(d.display_name_key) == d.display_name_key or tr(d.description_key) == d.description_key or tr(d.cost_key) == d.cost_key:
			_check("every key of %s is translated" % d.id, false)


func _signals() -> void:
	WorldState.new_game()
	_events.clear()
	var rec := func(a = null, b = null, c = null): _events.append([a, b, c])
	EventBus.flag_changed.connect(rec)
	EventBus.inventory_changed.connect(rec)
	EventBus.time_of_day_changed.connect(rec)
	WorldState.set_flag(&"met_rufet")
	WorldState.set_flag(&"met_rufet")        # no change: no signal
	_check("flag_changed(key, old, new) once", _events.size() == 1 and _events[0][0] == &"met_rufet" and _events[0][1] == null and _events[0][2] == true)
	_events.clear()
	WorldState.add_item(&"nar_seed", 2)
	_check("inventory_changed(item, total)", _events.size() == 1 and _events[0][1] == 2)
	_check("remove_item refuses more than there is", not WorldState.remove_item(&"nar_seed", 3) and WorldState.item_count(&"nar_seed") == 2)
	_events.clear()
	WorldState.set_time_of_day(9.0)          # 8.5 → 9: still day
	WorldState.set_time_of_day(19.0)         # → dusk
	_check("time_of_day_changed only on a new phase", _events.size() == 1 and _events[0][0] == &"dusk")
	WorldState.set_time_of_day(23.5)
	WorldState.set_time_of_day(0.5)
	_check("the clock wrapping past midnight starts day 2", WorldState.get_day_count() == 2)
	EventBus.flag_changed.disconnect(rec)
	EventBus.inventory_changed.disconnect(rec)
	EventBus.time_of_day_changed.disconnect(rec)


func _round_trip() -> void:
	_wipe(TEST_DIR)
	_fill_state()
	SaveManager.active_slot = 1
	_check("save writes slot 1", SaveManager.save(1) and FileAccess.file_exists(TEST_DIR + "slot_1.json"))
	var before := WorldState.to_dict()
	WorldState.new_game()
	_check("load reads slot 1", SaveManager.load_slot(1))
	var after := WorldState.to_dict()
	for section in before:
		_check("round trip keeps '%s' identical" % section, _deep_equal(before[section], after[section]))


func _memory_survives() -> void:
	WorldState.new_game()
	var got: Array = []
	var rec := func(id: StringName): got.append(id)
	EventBus.memory_burned.connect(rec)
	var def = Memory.burn(&"father_voice")
	EventBus.memory_burned.disconnect(rec)
	_check("burning emits memory_burned(id)", got == [&"father_voice"] and def != null and def.id == &"father_voice")
	_check("a burned memory cannot burn twice", Memory.burn(&"father_voice") == null)
	_check("unknown ids are refused", not WorldState.burn_memory(&"no_such_memory"))
	SaveManager.save(2)
	WorldState.new_game()
	SaveManager.load_slot(2)
	_check("the burned memory survives save/load", WorldState.has_burned(&"father_voice") and Memory.burned_count() == 1)


func _corrupt_files() -> void:
	WorldState.new_game()
	WorldState.set_flag(&"marker", 7)
	var before := WorldState.to_dict()
	var cases := {
		"garbage": "#!@ not json at all",
		"truncated": JSON.stringify(before, "\t").substr(0, 120),
		"wrong shape": JSON.stringify({"meta": 5, "player": []}),
		"from the future": JSON.stringify(_with_version(before, 99)),
		"empty": "",
	}
	for label in cases:
		_write(TEST_DIR + "slot_3.json", cases[label])
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR + "slot_3.json.bak"))
		var ok := SaveManager.load_slot(3)
		_check("corrupt save (%s): load fails without a crash, state untouched" % label, not ok and _deep_equal(WorldState.to_dict(), before))
	_check("slot_info reports a corrupt slot as unreadable", not SaveManager.slot_info(3)["readable"])


func _backup_fallback() -> void:
	_wipe(TEST_DIR)
	WorldState.new_game()
	WorldState.set_flag(&"version", 1)
	SaveManager.save(3)
	WorldState.set_flag(&"version", 2)
	SaveManager.save(3)
	_check("each save keeps the previous one as .bak", FileAccess.file_exists(TEST_DIR + "slot_3.json.bak")
		and _read_flag(TEST_DIR + "slot_3.json.bak", "version") == 1 and _read_flag(TEST_DIR + "slot_3.json", "version") == 2)
	_write(TEST_DIR + "slot_3.json", "{ broken")
	WorldState.new_game()
	_check("a broken main file falls back to its .bak", SaveManager.load_slot(3) and WorldState.get_flag(&"version") == 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR + "slot_3.json"))
	WorldState.new_game()
	_check("a missing main file falls back to its .bak", SaveManager.load_slot(3) and WorldState.get_flag(&"version") == 1)


func _menu_cases() -> void:
	# No save at all: Continue is greyed out, New Game takes slot 1
	_wipe(TEST_DIR)
	var menu = await _open_menu()
	_check("no save: Continue is disabled", menu._continue.disabled and not menu._new.disabled)
	menu._on_continue()
	_check("no save: pressing Continue does nothing", not menu._starting)
	SaveManager.active_slot = 0
	menu._on_new_game()
	_check("no save: New Game takes slot 1 without asking", SaveManager.active_slot == 1 and not menu.is_confirming())
	menu.queue_free()

	# Some saves: Continue loads the most recently written slot
	_wipe(TEST_DIR)
	_write_slot(1, 1, 1000)
	_write_slot(3, 3, 3000)
	_write_slot(2, 2, 2000)
	menu = await _open_menu()
	_check("some saves: Continue is enabled", not menu._continue.disabled)
	WorldState.new_game()
	menu._on_continue()
	_check("Continue loads the most recently written slot", WorldState.get_flag(&"slot") == 3 and SaveManager.active_slot == 3 and menu._starting)
	menu.queue_free()
	_wipe(TEST_DIR)
	_write_slot(1, 1, 1000)
	menu = await _open_menu()
	SaveManager.active_slot = 0
	menu._on_new_game()
	_check("some saves: New Game takes the first empty slot", SaveManager.active_slot == 2 and not menu.is_confirming())
	menu.queue_free()

	# Continue falls back to the .bak of the newest slot
	_wipe(TEST_DIR)
	_write_slot(2, 20, 5000)
	_write(TEST_DIR + "slot_2.json.bak", _slot_text(21, 4000))
	_write(TEST_DIR + "slot_2.json", "{ broken")
	menu = await _open_menu()
	WorldState.new_game()
	menu._on_continue()
	_check("Continue falls back to the slot's .bak", WorldState.get_flag(&"slot") == 21 and menu._starting)
	menu.queue_free()

	# Every file of the only slot broken: the menu stays and says so
	_wipe(TEST_DIR)
	_write(TEST_DIR + "slot_1.json", "garbage")
	_write(TEST_DIR + "slot_1.json.bak", "garbage")
	menu = await _open_menu()
	_check("unreadable save: Continue is disabled", menu._continue.disabled)
	_write(TEST_DIR + "slot_2.json", _slot_text(2, 100))
	menu.refresh()
	_write(TEST_DIR + "slot_2.json", "garbage")   # breaks after the menu opened
	menu._on_continue()
	_check("a failed Continue keeps the menu, shows why, starts nothing", not menu._starting and menu._status.visible and menu._status.text == tr("MENU_LOAD_FAILED"))
	menu.queue_free()

	# All slots full: New Game asks, naming the slot and its time; Cancel changes nothing
	_wipe(TEST_DIR)
	for s in [1, 2, 3]:
		_write_slot(s, s, 1000 * s)
	var files := _slot_files()
	menu = await _open_menu()
	SaveManager.active_slot = 0
	menu._on_new_game()
	_check("all slots full: New Game asks before overwriting", menu.is_confirming() and SaveManager.active_slot == 0)
	_check("the question names the oldest slot and its last-played time", menu._confirm_text.text.contains(tr("MENU_SLOT_NAME") % 1)
		and menu._confirm_text.text.contains(SaveManager.format_time(1000)))
	menu._cancel_confirm()
	await _frames(2)
	_check("Cancel returns to the menu and overwrites nothing", not menu.is_confirming() and menu._menu.visible and SaveManager.active_slot == 0 and _slot_files() == files)
	menu._on_new_game()
	menu._confirm.get_node("Box/Buttons").get_child(0).emit_signal("pressed")
	_check("confirming picks the oldest slot for the new game", SaveManager.active_slot == 1 and menu._starting)
	menu.queue_free()
	_check("the title shows Continue, New Game, Settings, Quit", _menu_buttons(await _open_menu()) == [tr("MENU_CONTINUE"), tr("MENU_NEW_GAME"), tr("MENU_SETTINGS"), tr("MENU_QUIT")])
	menu = await _open_menu()
	menu._on_settings()
	_check("Settings opens the pause menu's settings screen", menu._settings.visible and not menu._menu.visible)
	menu._settings._close()   # what its Back button does
	_check("closing Settings returns to the title", not menu._settings.visible and menu._menu.visible)
	menu.queue_free()


func _legacy_import() -> void:
	_wipe(TEST_DIR)
	_wipe(LEGACY_DIR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LEGACY_DIR))
	_write(LEGACY_DIR + "save.json", JSON.stringify({"version": 4, "chapter": 2, "checkpoint": "c2_start",
		"flags": {"wave_confirmed": true}, "echoes_seen": [0, 1, 2], "memory": {"burned": ["rufet_face"]}, "world": {}}))
	_write(LEGACY_DIR + "world_test.json", JSON.stringify({"version": 4, "chapter": 1, "checkpoint": "start", "flags": {"met_guard": true},
		"echoes_seen": [], "memory": {"burned": ["rufet_face", "mother_name"]},
		"world": {"hearths": ["hearth_west"], "chests": ["chest@0"], "discovered": ["hearth_west", "village"], "fog": "AAAA",
			"hour": 14.5, "max_flasks": 5, "last_hearth": "hearth_west", "mystery": 1}}))
	var report: Array = SaveManager.import_legacy_saves()
	_check("old saves become slot 1", SaveManager.load_slot(1))
	_check("story progress carried over", WorldState.get_chapter() == 2 and WorldState.get_checkpoint() == "c2_start" and WorldState.echoes_seen() == [0, 1, 2])
	_check("burned memories from the story save carried over", WorldState.has_burned(&"rufet_face") and not WorldState.has_burned(&"mother_name"))
	_check("flags from both files merged", WorldState.has_flag(&"wave_confirmed") and WorldState.has_flag(&"met_guard"))
	_check("open-world progress carried over", WorldState.has_world_entry(&"hearths", "hearth_west") and WorldState.get_player_stat(&"max_flasks") == 5
		and is_equal_approx(WorldState.get_time_of_day(), 14.5) and WorldState.get_world_value(&"last_hearth") == "hearth_west")
	var text := "\n".join(PackedStringArray(report))
	_check("the log names what was not migrated", text.contains("NOT MIGRATED") and text.contains("mother_name") and text.contains("world.mystery"))
	_check("old files are kept as *.migrated", FileAccess.file_exists(LEGACY_DIR + "save.json.migrated") and not FileAccess.file_exists(LEGACY_DIR + "save.json"))
	_write(LEGACY_DIR + "save.json", "garbage")
	_wipe(TEST_DIR)
	var bad: Array = SaveManager.import_legacy_saves()
	_check("an unreadable old save is reported, not a crash", "\n".join(PackedStringArray(bad)).contains("unreadable"))


# --- Helpers -------------------------------------------------------------------------------------

func _fill_state() -> void:
	WorldState.new_game()
	WorldState.set_flag(&"met_rufet")
	WorldState.set_flag(&"times_warned", 3)
	WorldState.set_flag(&"door_word", "kül")
	Memory.burn(&"rufet_face")
	Memory.burn(&"sabir_lesson")
	WorldState.set_player_stats({"health": 88.5, "max_health": 120.0, "flasks": 2, "max_flasks": 5, "fire": 40.0, "weapon": "sword_shield", "level": 3})
	WorldState.set_player_position(Vector3(301.5, 13.25, 342.0))
	WorldState.set_region(&"kur_vadisi")
	WorldState.add_item(&"nar_seed", 2)
	WorldState.set_chapter(2)
	WorldState.set_checkpoint("c2_start")
	WorldState.set_echoes_seen([0, 2])
	WorldState.move_npc(&"sabir", "kurkend")
	WorldState.change_npc_relationship(&"sabir", 2)
	WorldState.set_npc_flag(&"sabir", &"trust", 2)
	WorldState.kill_npc(&"nermin", "test")
	WorldState.set_time_of_day(20.25)
	WorldState.resolve_grief(&"sona")
	WorldState.set_door_override(&"door_sahbaz", "closed")
	WorldState.add_world_entry(&"hearths", "hearth_west")
	WorldState.add_world_entry(&"killed", "den@2")
	WorldState.set_world_value(&"fog", "AbCd")
	WorldState.set_world_value(&"last_hearth", "hearth_west")


## Strict: same types all the way down (1 and 1.0 differ), so JSON number drift is caught.
func _deep_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _deep_equal(a[k], b[k]):
				return false
		return true
	if a is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _deep_equal(a[i], b[i]):
				return false
		return true
	return a == b


func _with_version(d: Dictionary, v: int) -> Dictionary:
	var c := d.duplicate(true)
	c["meta"]["save_version"] = v
	return c


func _read_flag(path: String, key: String) -> Variant:
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return int(d["flags"][key]) if d is Dictionary else null


func _open_menu() -> Node:
	var menu = MainMenu.new()
	add_child(menu)
	await _frames(2)
	return menu


func _menu_buttons(menu: Node) -> Array:
	var out: Array = []
	for c in menu._menu.get_children():
		if c is Button:
			out.append(c.text)
	menu.queue_free()
	return out


## A save file whose flag "slot" = `marker`, written `stamp` seconds after the epoch.
func _slot_text(marker: int, stamp: int) -> String:
	var d := WorldState.default_state()
	d["flags"]["slot"] = marker
	d["meta"]["last_saved_timestamp"] = stamp
	return JSON.stringify(d)


func _write_slot(slot: int, marker: int, stamp: int) -> void:
	_write(TEST_DIR + "slot_%d.json" % slot, _slot_text(marker, stamp))


func _slot_files() -> Dictionary:
	var out := {}
	for s in [1, 2, 3]:
		out[s] = FileAccess.get_file_as_string(TEST_DIR + "slot_%d.json" % s)
	return out


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _wipe(dir: String) -> void:
	var full := ProjectSettings.globalize_path(dir)
	if not DirAccess.dir_exists_absolute(full):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(full.path_join(f))
	DirAccess.remove_absolute(full)   # the folder too, once empty


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_fails += 1
