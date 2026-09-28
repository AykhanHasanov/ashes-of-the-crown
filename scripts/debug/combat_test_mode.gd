extends "res://scripts/chapter_base.gd"
## Headless test run for combat, enemy AI and encounters, on the test yard with the real
## The protagonist, TPCamera and Foe nodes. Runs the three suites one after another, prints
## PASS/FAIL per check and quits with the total failure count as exit code.
## Run: godot --headless --path . res://scenes/tests/combat_test.tscn
## (without --headless it opens a window, which is handy to watch a failing check).

const TestYard := preload("res://scripts/debug/test_yard.gd")
const Protagonist := preload("res://scripts/player_v3/protagonist.gd")
const TPCamera := preload("res://scripts/camera/third_person_camera.gd")
const Foe := preload("res://scripts/enemies/foe.gd")
const CombatSelfTest := preload("res://scripts/debug/combat_selftest.gd")
const AiSelfTest := preload("res://scripts/debug/ai_selftest.gd")
const EncounterSelfTest := preload("res://scripts/debug/encounter_selftest.gd")


func _make_level() -> Node3D:
	return TestYard.new()


func _make_player() -> Node3D:
	return Protagonist.new()


func _make_camera() -> Node3D:
	return TPCamera.new()


func _begin(_mode: String) -> void:
	WorldState.new_game()                   # in memory; there is no save slot here
	WorldState.set_flag(&"wave_confirmed")  # no "are you sure" dialog before a fire wave
	player.wake()
	_run.call_deferred()


func _run() -> void:
	var fails := 0
	for suite_script in [CombatSelfTest, AiSelfTest, EncounterSelfTest]:
		var suite = suite_script.new()
		suite.mode = self
		suite.player = player
		add_child(suite)
		fails += await suite.run()
		suite.queue_free()
	print("COMBAT TESTS DONE, failures: ", fails)
	get_tree().quit(fails)


## Spawns a foe that hunts the protagonist from the first frame (no perception) unless opts say
## otherwise; summoned helpers are spawned the same way.
func spawn_foe(id: String, at: Vector3, opts := {}):
	var f = Foe.new()
	f.configure(id, int(opts.get("level", 1)), opts)
	add_child(f)
	f.global_position = at
	f.target = player
	f.summon_requested.connect(func(eid: String, pos: Vector3, lv: int, o: Dictionary):
		var o2 := o.duplicate()
		o2["level"] = lv
		spawn_foe(eid, pos, o2))
	return f
