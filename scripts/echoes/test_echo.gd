extends "res://scripts/echoes/echo_mode.gd"
## PLACEHOLDER echo (data/echoes/test_echo.tres → memory "first_sword"): follow three
## embers across a remembered training yard; the last one ends the memory and the choice
## screen asks KEEP or BURN. Exists to exercise the echo system; the story writes the
## real echoes later.

const MemoryYard := preload("res://scripts/echoes/memory_yard.gd")
const Effects := preload("res://scripts/world/effects.gd")
const MARKERS := [Vector3(-5, 0, 1), Vector3(5, 0, -4), Vector3(0, 0, -8)]
const REACH := 1.6

var _marker := -1
var _marker_node: Node3D


func _make_level() -> Node3D:
	return MemoryYard.new()


func _start() -> void:
	hud.set_objective(tr("ECHO_TEST_OBJECTIVE"))
	_next_marker()


func marker_position() -> Vector3:
	return MARKERS[_marker] if _marker >= 0 and _marker < MARKERS.size() else Vector3.INF


func _next_marker() -> void:
	if _marker_node:
		_marker_node.queue_free()
		_marker_node = null
	_marker += 1
	if _marker >= MARKERS.size():
		Fx.slowmo(0.35, 0.6)
		complete()
		return
	_marker_node = Node3D.new()
	_marker_node.position = MARKERS[_marker]
	var embers := Effects.ember_field(Vector3(0.5, 0.8, 0.5), 14)
	embers.position.y = 0.8
	_marker_node.add_child(embers)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.2)
	light.light_energy = 2.5
	light.omni_range = 5.0
	light.position.y = 1.0
	_marker_node.add_child(light)
	add_child(_marker_node)


func _tick(delta: float) -> void:
	super._tick(delta)
	if _marker >= 0 and _marker < MARKERS.size():
		var at: Vector3 = MARKERS[_marker]
		if Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length() < REACH:
			_next_marker()


func _marker_target() -> Variant:
	return marker_position() if _marker >= 0 and _marker < MARKERS.size() else null
