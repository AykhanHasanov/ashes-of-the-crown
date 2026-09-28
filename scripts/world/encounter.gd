extends Node
## A scripted encounter: waves of enemies from data/encounters/<id>.json rising around a
## point, one wave after the other. The encounter only runs the fight; how it looks and
## sounds (banners, music) is the active mode's business, driven by the EventBus signals
## encounter_started / encounter_wave_started / encounter_finished. What a finished
## encounter means for the story is the caller's business too (write WorldState there).
##
## Data: {"id", "spawn": {"radius": [min, max]},
##        "waves": [{"banner_key", "delay", "enemies": [{"id", "count", "level"}]}]}
##
## Use: var e := Encounter.new(); e.spawner = <Callable(id, pos, level, opts) -> foe>;
##      add_child(e); e.start(&"test_ash_rising", center)
## The spawner places and wires the enemy (the world gives it ground height, perception,
## summons); the encounter asks for opts {"hunt": true, "roll": false} so it attacks at once.
## Frees itself when the last wave falls or on abort().

signal finished

var spawner: Callable
var encounter_id: StringName
var wave := 0          # 1-based once running
var alive: Array = []

var _data: Dictionary
var _center := Vector3.ZERO
var _running := false
var _spawning := false   # a wave still rising: an early kill must not start the next one


## Starts the encounter; false (and nothing happens) for an unknown id or no spawner.
func start(id: StringName, center: Vector3) -> bool:
	_data = DataDB.encounter(String(id))
	if _data.is_empty() or (_data.get("waves", []) as Array).is_empty():
		push_error("Encounter: unknown or empty encounter '%s'" % id)
		return false
	if not spawner.is_valid():
		push_error("Encounter: no spawner set for '%s'" % id)
		return false
	encounter_id = id
	_center = center
	_running = true
	EventBus.encounter_started.emit(encounter_id)
	_next_wave.call_deferred()
	return true


func total_waves() -> int:
	return (_data.get("waves", []) as Array).size()


func is_running() -> bool:
	return _running


## Stops spawning (the enemies already up stay and fight on).
func abort() -> void:
	_running = false
	queue_free()


func _next_wave() -> void:
	if not _running or not is_inside_tree():
		return
	var waves: Array = _data["waves"]
	if wave >= waves.size():
		_running = false
		EventBus.encounter_finished.emit(encounter_id)
		finished.emit()
		queue_free()
		return
	var w: Dictionary = waves[wave]
	wave += 1
	await get_tree().create_timer(float(w.get("delay", 1.0))).timeout
	if not _running or not is_inside_tree():   # aborted, or the scene is closing
		return
	EventBus.encounter_wave_started.emit(encounter_id, wave, waves.size(), String(w.get("banner_key", "")))
	var ids: Array = []
	for e in w.get("enemies", []):
		for n in int(e.get("count", 1)):
			ids.append([String(e["id"]), int(e.get("level", 1))])
	var r: Array = _data.get("spawn", {}).get("radius", [7.0, 11.0])
	var a0 := randf() * TAU
	_spawning = true
	for i in ids.size():
		var ang := a0 + TAU * i / ids.size() + randf_range(-0.25, 0.25)
		var pos := _center + Vector3(cos(ang), 0.0, sin(ang)) * randf_range(float(r[0]), float(r[1]))
		var foe = spawner.call(ids[i][0], pos, ids[i][1], {"hunt": true, "roll": false})
		if foe != null:
			alive.append(foe)
			foe.killed.connect(_on_gone.bind(foe))
			foe.tree_exited.connect(_on_gone.bind(null, foe))   # freed without dying (unload, debug)
		await get_tree().create_timer(0.3).timeout   # they rise one by one
		if not _running or not is_inside_tree():
			return
	_spawning = false
	if alive.is_empty():
		_next_wave()


func _on_gone(_x = null, foe = null) -> void:
	var f = foe if foe != null else _x
	if not _running or not (f in alive):
		return
	alive.erase(f)
	if alive.is_empty() and not _spawning:
		# The last one of the wave falls in slow motion
		Fx.slowmo(0.25, 0.8)
		_next_wave()
