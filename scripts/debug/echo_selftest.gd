extends Node
## Headless checks for the echo system, the three-state memory model, the protagonist's
## name and the save migration. Plays the real flow: host scene → echo scene → choice →
## back to the host, for both KEEP and BURN. Uses its own save folder.
## Run: godot --headless --path . res://scenes/tests/echo_test.tscn   (exit code = failures)

const EchoDirector := preload("res://scripts/echoes/echo_director.gd")
const Names := preload("res://scripts/core/names.gd")
const HOST := "res://scenes/tests/echo_host.tscn"
const ECHO_SCENE := "res://scenes/echoes/test_echo.tscn"
const TEST_DIR := "user://test_echo_saves/"
const S := WorldState.MemoryState
# Built from parts so the old name never appears in this file
const OLD := "ay" + "xan"

var _fails := 0
var _events: Array = []


func _ready() -> void:
	SaveManager.directory = TEST_DIR
	SaveManager.allow_in_demo = true
	# Scene changes must not free the test: hand the "current scene" role to a dummy
	var dummy := Node.new()
	get_tree().root.add_child.call_deferred(dummy)
	_start.call_deferred(dummy)


func _start(dummy: Node) -> void:
	get_tree().current_scene = dummy
	_run()


func _run() -> void:
	_wipe()
	EventBus.memory_kept.connect(func(id: StringName): _events.append(["kept", id]))
	EventBus.memory_burned.connect(func(id: StringName): _events.append(["burned", id]))
	WorldState.new_game()
	SaveManager.active_slot = 1
	_three_states()
	_migration()
	await _keep_path()
	await _burn_path()
	await _blank_name()
	_no_old_name()
	_wipe()
	print("ECHO TESTS DONE, failures: ", _fails)
	get_tree().quit(_fails)


# --- Memory states and saves ------------------------------------------------------------------

func _three_states() -> void:
	WorldState.new_game()
	_check("a memory starts UNKNOWN", WorldState.get_memory_state(&"rufet_face") == S.UNKNOWN)
	_check("keep_memory: UNKNOWN → KEPT", WorldState.keep_memory(&"rufet_face") and WorldState.get_memory_state(&"rufet_face") == S.KEPT)
	_check("a kept memory cannot be kept again", not WorldState.keep_memory(&"rufet_face"))
	_check("burn_memory: → BURNED", WorldState.burn_memory(&"sabir_lesson") and WorldState.get_memory_state(&"sabir_lesson") == S.BURNED)
	_check("a burned memory can be neither kept nor burned again", not WorldState.keep_memory(&"sabir_lesson") and not WorldState.burn_memory(&"sabir_lesson"))
	_check("dialogue condition kept:<id>", WorldState.check("kept:rufet_face") and not WorldState.check("kept:sabir_lesson"))
	_check("dialogue condition memory:<id> (burned) still works", WorldState.check("memory:sabir_lesson") and not WorldState.check("memory:rufet_face"))
	SaveManager.save(1)
	WorldState.new_game()
	SaveManager.load_slot(1)
	_check("save/load keeps all three states", WorldState.get_memory_state(&"rufet_face") == S.KEPT
		and WorldState.get_memory_state(&"sabir_lesson") == S.BURNED and WorldState.get_memory_state(&"mother_name") == S.UNKNOWN)


func _migration() -> void:
	# A v1 save: burned-only list, and the protagonist's old name in keys and values
	var v1 := WorldState.default_state()
	v1["meta"]["save_version"] = 1
	v1["player"].erase("memories")
	v1["player"]["burned_memories"] = ["rufet_face", "father_voice"]
	v1["flags"] = {OLD + "_met_rufet": true, "helped": OLD.capitalize()}
	v1["npcs"] = {OLD: {"alive": true}}
	var up := SaveManager.migrate(JSON.parse_string(JSON.stringify(v1)))
	var clean := WorldState.normalize(up)
	_check("migration v1 → v2: burned list → BURNED, the rest UNKNOWN", clean["player"]["memories"] == {"rufet_face": "burned", "father_voice": "burned"}
		and not clean["player"].has("burned_memories"))
	_check("migration renames the old protagonist id in keys and values", clean["flags"].has("protagonist_met_rufet")
		and clean["flags"]["helped"] == "protagonist" and clean["npcs"].has("protagonist"))
	_check("the migrated save loads", WorldState.from_dict(clean) and WorldState.has_burned(&"father_voice") and WorldState.get_memory_state(&"mother_name") == S.UNKNOWN)
	var legacy := {"version": 4, "chapter": 1, "checkpoint": "waves", "flags": {}, "echoes_seen": [], "memory": {"burned": ["first_sword"]}, "world": {}}
	var from_legacy := WorldState.normalize(SaveManager.migrate(legacy))
	_check("the whole chain: old GameState file → v2", from_legacy["player"]["memories"] == {"first_sword": "burned"} and int(from_legacy["meta"]["save_version"]) == 2)
	# The same through the file path, as an old save on disk would come in
	_write(TEST_DIR + "slot_2.json", JSON.stringify(v1))
	_check("an old v1 slot file loads through SaveManager", SaveManager.load_slot(2) and WorldState.has_burned(&"rufet_face"))
	SaveManager.active_slot = 1


# --- The echo flow ---------------------------------------------------------------------------

func _keep_path() -> void:
	WorldState.new_game()
	SaveManager.active_slot = 1
	SaveManager.save(1)
	var host := await _go_host()
	var at := Vector3(3.0, host.player.global_position.y, -5.0)
	host.player.global_position = at
	host.player.face_towards(at + Vector3(1, 0, 0))
	await _frames(30)
	var at_real: Vector3 = host.player.global_position
	_events.clear()
	_check("entering the test echo", EchoDirector.enter(&"test_echo", host, host.player, 13.25))
	var echo := await _scene(ECHO_SCENE)
	_check("inside an echo nothing is saved", EchoDirector.active and not SaveManager.can_save() and not SaveManager.save(1))
	_check("the protagonist cannot die in an echo", echo.player.is_invulnerable())
	# Play it: walk the embers (teleport onto each in turn)
	for i in 3:
		var m: Vector3 = echo.marker_position()
		echo.player.global_position = Vector3(m.x, 0.1, m.z)
		await _frames(4)
	await _until(func(): return echo.choice_screen != null, 3.0)
	_check("following the embers ends the echo on the choice screen", echo.choice_screen != null)
	Input.action_press("echo_keep")
	await _frames(2)
	Input.action_release("echo_keep")
	var back := await _scene(HOST)
	_check("KEEP: the memory is KEPT and memory_kept was emitted", WorldState.get_memory_state(&"first_sword") == S.KEPT and _events == [["kept", &"first_sword"]])
	_check("KEEP: saved at once", _saved_state("first_sword") == "kept")
	_check("back exactly where he stood", back.player.global_position.distance_to(at_real) < 0.25, "%s vs %s" % [back.player.global_position, at_real])
	_check("facing the same way", back.player.facing().dot(Vector3(1, 0, 0)) > 0.9)
	_check("the clock he left at is restored", is_equal_approx(WorldState.get_time_of_day(), 13.25))
	_check("the saved position is the world one, not the echo's", _saved_position().distance_to(at_real) < 0.25)
	_check("a decided memory's echo cannot be entered again", not EchoDirector.enter(&"test_echo", back, back.player, 12.0))


func _burn_path() -> void:
	WorldState.new_game()
	SaveManager.save(1)
	var host := await _go_host()
	_events.clear()
	EchoDirector.enter(&"test_echo", host, host.player, 20.0)
	var echo := await _scene(ECHO_SCENE)
	echo.complete()
	await _frames(3)
	var choice = echo.choice_screen
	# A single press can never burn
	Input.action_press("echo_burn")
	await _seconds(0.15)
	Input.action_release("echo_burn")
	await _seconds(0.3)
	_check("a single press of BURN does nothing", WorldState.get_memory_state(&"first_sword") == S.UNKNOWN and is_instance_valid(choice) and choice.burn_progress() == 0.0)
	Input.action_press("echo_burn")
	await _seconds(0.8)
	Input.action_release("echo_burn")
	await _seconds(0.2)
	_check("letting go before 1.5 s cancels the burn", WorldState.get_memory_state(&"first_sword") == S.UNKNOWN and choice.burn_progress() == 0.0)
	Input.action_press("echo_burn")
	await _seconds(1.7)
	Input.action_release("echo_burn")
	var back := await _scene(HOST)
	_check("holding BURN 1.5 s burns the memory (memory_burned emitted)", WorldState.get_memory_state(&"first_sword") == S.BURNED and _events == [["burned", &"first_sword"]])
	_check("BURN: saved at once", _saved_state("first_sword") == "burned")
	var fired := await _until(func(): return back.player._state == back.player.S.CAST, 2.0)
	_check("the burned memory's fire is released on return (Alov Dalğası)", fired)


# --- The protagonist's name ------------------------------------------------------------------

func _blank_name() -> void:
	WorldState.new_game()
	var host = get_tree().current_scene
	_check("the name is Aras via PROTAGONIST_NAME", Names.protagonist() == "Aras" and tr("PROTAGONIST_NAME") == "Aras")
	_check("the HUD shows it", host.hud._name_label.text == "ARAS")
	WorldState.burn_memory(Names.PROTAGONIST_MEMORY)
	await _frames(2)
	var blank := tr("NAME_FORGOTTEN")
	_check("after burning the name memory the UI shows a blank", Names.protagonist() == blank and host.hud._name_label.text == blank.to_upper())
	_check("people still know him: NPC lines keep the name", Names.protagonist_known() == "Aras" and Names.fill("{PROTAGONIST}!") == "Aras!")
	_check("his own UI lines use the blank", Names.fill("{PROTAGONIST}", false) == blank)
	_check("the name memory is not offered to the fire wheel", Memory.combat_memories().all(func(d): return d.id != Names.PROTAGONIST_MEMORY))


## No file of the project may contain the old name, except the save migration.
func _no_old_name() -> void:
	var hits: Array = []
	_scan("res://", hits)
	_check("the old protagonist name appears nowhere (except the save migration)", hits.is_empty(), ", ".join(PackedStringArray(hits)))


func _scan(dir: String, hits: Array) -> void:
	const EXT := ["gd", "tscn", "tres", "json", "csv", "md", "cfg", "godot", "py", "gdshader", "gdshaderinc", "txt"]
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with(".") or d in ["addons", "captures"]:
			continue
		_scan(dir.path_join(d), hits)
	for f in DirAccess.get_files_at(dir):
		var path := dir.path_join(f)
		if not f.get_extension() in EXT or path == "res://scripts/systems/save_manager.gd":
			continue
		if FileAccess.get_file_as_string(path).to_lower().contains(OLD):
			hits.append(path)


# --- Helpers -----------------------------------------------------------------------------------

func _go_host() -> Node:
	get_tree().change_scene_to_file(HOST)
	return await _scene(HOST)


## Waits for `path` to be the running scene with its player ready.
func _scene(path: String) -> Node:
	var ok := await _until(func():
		var c = get_tree().current_scene
		return c != null and c.scene_file_path == path and c.get("player") != null and c.player.is_inside_tree(), 15.0)
	await _frames(5)
	if not ok:
		_check("scene %s came up" % path, false)
	return get_tree().current_scene


func _saved_state(id: String) -> String:
	var d = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.slot_path(1)))
	return String(d["player"]["memories"].get(id, "")) if d is Dictionary else ""


func _saved_position() -> Vector3:
	var d = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.slot_path(1)))
	var p: Array = d["player"]["position"]
	return Vector3(p[0], p[1], p[2])


func _until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().create_timer(0.05, true, false, true).timeout
		t += 0.05
	return bool(cond.call())


func _seconds(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _wipe() -> void:
	var full := ProjectSettings.globalize_path(TEST_DIR)
	if DirAccess.dir_exists_absolute(full):
		for f in DirAccess.get_files_at(TEST_DIR):
			DirAccess.remove_absolute(full.path_join(f))
		DirAccess.remove_absolute(full)


func _check(label: String, ok: bool, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + label + ("" if detail == "" else "  (" + detail + ")"))
	if not ok:
		_fails += 1
