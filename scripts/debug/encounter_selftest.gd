extends Node
## Checks for the encounter system (suite of scenes/tests/combat_test.tscn), using the
## placeholder data/encounters/test_ash_rising.json: start/refuse, the EventBus signal
## order, waves rising around the point and hunting at once, a cleared wave (killed or
## freed) bringing the next, finishing, and abort. run() returns the failure count.

const Encounter := preload("res://scripts/world/encounter.gd")

var mode      # combat_test_mode
var player
var _fails := 0
var _events: Array = []


func run() -> int:
	player.make_invulnerable(120.0)
	var rec_start := func(id: StringName): _events.append(["start", id])
	var rec_wave := func(id: StringName, w: int, total: int, key: String): _events.append(["wave", id, w, total, key])
	var rec_done := func(id: StringName): _events.append(["done", id])
	EventBus.encounter_started.connect(rec_start)
	EventBus.encounter_wave_started.connect(rec_wave)
	EventBus.encounter_finished.connect(rec_done)

	var bad := _encounter()
	_check("an unknown encounter id is refused", not bad.start(&"no_such_encounter", Vector3.ZERO))
	bad.queue_free()
	var no_spawner := Encounter.new()
	mode.add_child(no_spawner)
	_check("an encounter without a spawner is refused", not no_spawner.start(&"test_ash_rising", Vector3.ZERO))
	no_spawner.queue_free()
	_check("refused encounters emit nothing", _events.is_empty())

	var center: Vector3 = player.global_position
	var e := _encounter()
	_check("the test encounter starts", e.start(&"test_ash_rising", center) and e.total_waves() == 3)
	await _until(func(): return e.alive.size() == 3, 5.0)
	_check("encounter_started, then wave 1 of 3 with its banner key",
		_events.size() == 2 and _events[0] == ["start", &"test_ash_rising"] and _events[1] == ["wave", &"test_ash_rising", 1, 3, "ENC_TEST_WAVE_1"])
	_check("wave 1 raises its three shades", e.alive.size() == 3 and e.alive.all(func(f): return f.data["id"] == "ash_shade"))
	_check("they rise 7-11 m around the point", e.alive.all(func(f):
		var d: float = Vector2(f.global_position.x - center.x, f.global_position.z - center.z).length()
		return d > 6.5 and d < 11.5))
	_check("encounter enemies hunt at once", e.alive.all(func(f): return f.aggro_range <= 0.0))
	_kill_all(e)
	await _until(func(): return e.alive.size() == 4, 6.0)
	_check("clearing a wave brings the next (2 shades + 2 runners)", e.wave == 2 and e.alive.size() == 4
		and _events.back() == ["wave", &"test_ash_rising", 2, 3, "ENC_TEST_WAVE_2"])
	_kill_all(e)
	await _until(func(): return e.wave == 3 and e.alive.size() == 2, 6.0)
	_check("the last wave rises (giant + archer)", e.alive.size() == 2)
	_kill_all(e)
	await _until(func(): return not is_instance_valid(e), 4.0)
	_check("encounter_finished once the last wave falls", _events.back() == ["done", &"test_ash_rising"] and _events.size() == 5)
	_check("a finished encounter frees itself", not is_instance_valid(e))

	# Enemies freed without dying (unloaded, debug) also clear a wave; abort stops it
	_events.clear()
	var e2 := _encounter()
	e2.start(&"test_ash_rising", center)
	await _until(func(): return e2.alive.size() == 3, 5.0)
	for f in e2.alive.duplicate():
		f.queue_free()
	await _until(func(): return e2.wave == 2 and e2.alive.size() == 4, 6.0)
	_check("enemies freed without dying still clear the wave", e2.wave == 2 and e2.alive.size() == 4)
	var before := _events.size()
	e2.abort()
	await get_tree().create_timer(3.0).timeout
	_check("abort stops the waves (no more signals, node freed)", _events.size() == before and not is_instance_valid(e2))

	EventBus.encounter_started.disconnect(rec_start)
	EventBus.encounter_wave_started.disconnect(rec_wave)
	EventBus.encounter_finished.disconnect(rec_done)
	for f in get_tree().get_nodes_in_group("enemies"):
		f.queue_free()
	player.invulnerable_until = 0
	print("encounter suite: %d failures" % _fails)
	return _fails


func _encounter() -> Node:
	var e := Encounter.new()
	e.spawner = func(id: String, pos: Vector3, lv: int, opts: Dictionary):
		pos.y = 0.1
		var o := opts.duplicate()
		o["level"] = lv
		return mode.spawn_foe(id, pos, o)
	mode.add_child(e)
	return e


func _kill_all(e: Node) -> void:
	for f in e.alive.duplicate():
		if is_instance_valid(f) and not f.dead:
			f.receive_hit(f.Hit.new().setup(player, 99999.0, "slash", 0.0, Vector3.ZERO))


## Waits until `cond` is true or `timeout` seconds pass.
func _until(cond: Callable, timeout: float) -> void:
	var t := 0.0
	while t < timeout and not cond.call():
		await get_tree().create_timer(0.1).timeout
		t += 0.1


func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1
