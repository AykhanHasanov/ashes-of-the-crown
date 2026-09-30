extends Node
## The whole session, played for real in two launches on a CLEAN user profile (windowed; it
## uses the real save and settings files, so point APPDATA at an empty folder):
##   phase 1  title → New Game → the valley (the first-launch benchmark picks a preset) →
##            light Geçit Ocağı → the road to Son Ocak → change the preset in the settings
##            screen → save → quit;
##   phase 2  start again: the preset and the benchmark's "done" are remembered, Continue
##            comes back to the hub, the hearth is still lit in the valley.
## Run (Git Bash), from the project root:
##   P="$TEMP/aotc_flow"; rm -rf "$P"; mkdir -p "$P"
##   APPDATA="$P" FLOW_PHASE=1 "$G" --path . res://scenes/tests/flow_test.tscn
##   APPDATA="$P" FLOW_PHASE=2 "$G" --path . res://scenes/tests/flow_test.tscn
## Exit code = failures. Not part of the headless suites (the benchmark needs a window).

const HubTravel := preload("res://scripts/hub/hub_travel.gd")
const MAIN := "res://scenes/main.tscn"
const WORLD := "res://scenes/world.tscn"
const HUB := "res://scenes/son_ocaq.tscn"
const MARK := "user://flow_phase1.json"
const HEARTH := "hearth_west"

var _fails := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dummy := Node.new()
	get_tree().root.add_child.call_deferred(dummy)
	_start.call_deferred(dummy)


func _start(dummy: Node) -> void:
	get_tree().current_scene = dummy   # this node stays while the game's scenes come and go
	print("FLOW user data: ", OS.get_user_data_dir())
	if OS.get_environment("FLOW_PHASE") == "2":
		await _phase_2()
	else:
		await _phase_1()
	print("FLOW TEST DONE (phase %s), failures: %d" % [OS.get_environment("FLOW_PHASE"), _fails])
	get_tree().quit(_fails)


func _phase_1() -> void:
	_check("a clean profile: no saves, no settings file, preset not chosen yet", SaveManager.most_recent_slot() == 0
		and not FileAccess.file_exists(Settings.PATH) and not Settings.benchmark_done and Settings.quality == Settings.Quality.MEDIUM)
	var menu = await _title()
	_check("the title: Continue is off on a clean profile", menu != null and menu._continue.disabled)
	menu._on_new_game()
	var world = await _scene(WORLD)
	_check("New Game: the valley, slot 1", world != null and WorldState.get_region() == &"kur_vadisi" and SaveManager.active_slot == 1)
	# a clear result is final at once; a dead-zone one runs Medium and waits for the next launch
	var benched := func() -> bool: return Settings.benchmark_done or Settings.bench_candidate != ""
	await _until(benched, 40.0)
	_check("first launch: the benchmark measured and wrote its result", benched.call() and FileAccess.file_exists(Settings.PATH),
		"%s, final %s" % [Settings.quality_id(), Settings.benchmark_done])
	var it = await _hearth(world)
	_check("the hearth is there, cold (ash and smoke)", it != null and not it.is_used() and it._fire != null and not it._fire.lit)
	world._use(it)
	await _frames(5)
	_check("lighting it: marked in the world state, flames up", WorldState.has_world_entry("hearths", HEARTH) and it._fire != null and it._fire.lit)
	HubTravel.enter(world, world.player, world.level.day_night.hour)
	var hub = await _scene(HUB)
	_check("the road: Son Ocak, its hearth burning", hub != null and WorldState.get_region() == &"son_ocaq"
		and hub.level.hearth_light != null and hub.level.hearth_fire.get_node("Fire").lit)
	var target: int = Settings.Quality.LOW if Settings.quality == Settings.Quality.MEDIUM else Settings.Quality.MEDIUM
	hub.pause_menu.open()
	await _frames(3)
	hub.pause_menu._open_settings()
	await _frames(3)
	var options: Array = hub.pause_menu._settings.find_children("*", "OptionButton", true, false)
	_check("the settings screen offers the three presets", options.size() >= 1 and options[0].item_count == 3)
	if not options.is_empty():
		options[0].select(target)
		options[0].item_selected.emit(target)
	await _frames(5)
	_check("changing the preset in the settings: applied and written", Settings.quality == target
		and String(_cfg_value("video", "quality")) == Settings.QUALITY_IDS[target])
	hub.pause_menu._settings._close()
	hub.pause_menu.close()
	await _frames(3)
	_check("the game saves", SaveManager.save() and SaveManager.most_recent_slot() == 1)
	var f := FileAccess.open(MARK, FileAccess.WRITE)
	f.store_string(JSON.stringify({"quality": Settings.QUALITY_IDS[target]}))
	f.close()


func _phase_2() -> void:
	var mark = JSON.parse_string(FileAccess.get_file_as_string(MARK)) if FileAccess.file_exists(MARK) else null
	_check("phase 1 ran on this profile", mark is Dictionary)
	if not (mark is Dictionary):
		return
	_check("after a restart the preset is the one chosen in the settings", Settings.quality_id() == String(mark["quality"]),
		Settings.quality_id())
	_check("... and the benchmark does not run again", Settings.benchmark_done and not Settings.needs_benchmark())
	var menu = await _title()
	_check("the title: Continue is on", menu != null and not menu._continue.disabled)
	menu._on_continue()
	var hub = await _scene(HUB)
	_check("Continue comes back to Son Ocak", hub != null and WorldState.get_region() == &"son_ocaq")
	_check("the lit hearth survived the restart (world state)", WorldState.has_world_entry("hearths", HEARTH))
	await _seconds(3.0)
	_check("the preset was not changed behind the player's back", Settings.quality_id() == String(mark["quality"]))
	HubTravel.leave(get_tree())
	var world = await _scene(WORLD)
	var it = await _hearth(world)
	_check("back in the valley the hearth is burning", it != null and it.is_used() and it._fire != null and it._fire.lit)


# --- Helpers --------------------------------------------------------------------------------------

func _title():
	get_tree().change_scene_to_file(MAIN)
	var found: Array = []   # (a lambda captures locals by value: the menu comes back in an array)
	var has_menu := func() -> bool:
		var c = get_tree().current_scene
		if c == null or c.scene_file_path != MAIN:
			return false
		for ch in c.get_children():
			if ch.has_signal("new_game"):
				found.append(ch)
				return true
		return false
	await _until(has_menu, 30.0)
	await _frames(5)
	return found[0] if not found.is_empty() else null


func _scene(path: String):
	var up := func() -> bool:
		var cur = get_tree().current_scene
		return cur != null and cur.scene_file_path == path and cur.get("player") != null and cur.player.is_inside_tree()
	await _until(up, 90.0)
	var c = get_tree().current_scene
	if c == null or c.scene_file_path != path:
		_check("scene %s came up" % path, false)
		return null
	await _seconds(1.5)
	return c


## Stands him by Geçit Ocağı and returns its hearth interactable once it has streamed in.
func _hearth(world):
	var p: Dictionary = world.level.streamer.poi_by_id(HEARTH)
	var at := Vector3(float(p["pos"][0]) + 2.0, 0, float(p["pos"][2]) + 2.0)
	at.y = world.level.height_at(at.x, at.z) + 1.0
	world.player.global_position = at
	world.player.velocity = Vector3.ZERO
	world.level.streamer.refresh()
	var found: Array = []
	var streamed := func() -> bool:
		for it in get_tree().get_nodes_in_group("interactables"):
			if it.kind == "hearth" and it.poi["id"] == HEARTH:
				found.append(it)
				return true
		return false
	await _until(streamed, 15.0)
	await _frames(5)
	return found[0] if not found.is_empty() else null


func _cfg_value(section: String, key: String) -> Variant:
	var cfg := ConfigFile.new()
	return cfg.get_value(section, key, null) if cfg.load(Settings.PATH) == OK else null


func _until(cond: Callable, timeout: float) -> bool:
	var start := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) / 1000.0 < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


func _seconds(s: float) -> void:
	var start := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) / 1000.0 < s:
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(label: String, ok: bool, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + label + ("" if detail == "" else "  [%s]" % detail))
	if not ok:
		_fails += 1
