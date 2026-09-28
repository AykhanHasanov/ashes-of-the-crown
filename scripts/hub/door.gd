extends Node3D
## A Son Ocaq door: a stable id, the place (room) it belongs to, and whether it is open.
## A view of derived state (HubData.door_open): it re-reads WorldState whenever time,
## people or overrides change, swings its leaf and announces EventBus.door_changed.
## The leaf hinges on the door's left edge and swings out; closed, it blocks the doorway.
##
## At night an occupied room shows a warm strip of light under its closed door; while the
## person inside speaks, a shadow moves across it (set_speaking). Empty or dead rooms stay
## dark. hold_open: a conversation keeps the door open for a moment (Peri Nene at night).

const HubData := preload("res://scripts/hub/hub_data.gd")
const LEAF := "res://assets/village_mk/Door_1_Round.gltf"
const OPEN_ANGLE := 100.0
const WIDTH := 1.1

var door_id: StringName
var place_id := ""
var is_open := false
var is_lit := false
var speaking := false
var held_open := false

var _hinge: Node3D
var _blocker: CollisionShape3D
var _tween: Tween
var _strip: MeshInstance3D
var _strip_light: OmniLight3D
var _shadow: MeshInstance3D
var _shadow_tween: Tween


func setup(id: StringName, place: String) -> void:
	door_id = id
	place_id = place


func _ready() -> void:
	add_to_group("hub_doors")
	_hinge = Node3D.new()
	_hinge.name = "Hinge"
	_hinge.position = Vector3(-WIDTH * 0.5, 0, 0)
	add_child(_hinge)
	if ResourceLoader.exists(LEAF):
		var leaf: Node3D = load(LEAF).instantiate()
		leaf.position = Vector3.ZERO   # the leaf's origin is its hinge side (as tools/build_houses.gd places it)
		_hinge.add_child(leaf)
	var body := StaticBody3D.new()
	_blocker = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, 2.2, 0.15)
	_blocker.shape = box
	_blocker.position = Vector3(0, 1.1, 0)
	body.add_child(_blocker)
	add_child(body)
	_build_strip()
	EventBus.time_of_day_changed.connect(func(_p): refresh())
	EventBus.npc_moved.connect(func(_a, _b, _c): refresh())
	EventBus.npc_died.connect(func(_a, _b): refresh())
	EventBus.world_changed.connect(_on_world_changed)
	EventBus.flag_changed.connect(func(_k, _o, _n): refresh())
	EventBus.state_replaced.connect(refresh)
	is_open = _wants_open()
	_apply(false)
	_update_strip()


## Light under the door: a thin warm strip on the ground at the threshold, a faint glow,
## and the shadow that crosses it when someone moves inside.
func _build_strip() -> void:
	var warm := StandardMaterial3D.new()
	warm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	warm.albedo_color = Color(1.0, 0.62, 0.28)
	_strip = MeshInstance3D.new()
	_strip.name = "LightStrip"
	var q := QuadMesh.new()
	q.size = Vector2(WIDTH - 0.1, 0.12)
	q.material = warm
	_strip.mesh = q
	_strip.rotation.x = -PI * 0.5
	_strip.position = Vector3(0, 0.02, 0.08)
	add_child(_strip)
	_strip_light = OmniLight3D.new()
	_strip_light.light_color = Color(1.0, 0.55, 0.22)
	_strip_light.light_energy = 0.6
	_strip_light.omni_range = 1.8
	_strip_light.position = Vector3(0, 0.12, 0.3)
	add_child(_strip_light)
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.03, 0.02, 0.015)
	_shadow = MeshInstance3D.new()
	_shadow.name = "StripShadow"
	var sq := QuadMesh.new()
	sq.size = Vector2(0.28, 0.14)
	sq.material = dark
	_shadow.mesh = sq
	_shadow.rotation.x = -PI * 0.5
	_shadow.position = Vector3(-WIDTH * 0.35, 0.025, 0.08)
	_shadow.visible = false
	add_child(_shadow)


func _on_world_changed(key: StringName) -> void:
	if key == &"doors":
		refresh()


func _wants_open() -> bool:
	return held_open or HubData.door_open(String(door_id))


func refresh() -> void:
	_update_strip()
	var want := _wants_open()
	if want == is_open:
		return
	is_open = want
	_apply(true)
	_update_strip()
	EventBus.door_changed.emit(door_id, is_open)


## Keeps the door open, or lets it follow its state again (a night conversation face to face).
func hold_open(on: bool) -> void:
	held_open = on
	refresh()


## Someone inside is speaking: their shadow moves back and forth across the light.
func set_speaking(on: bool) -> void:
	speaking = on
	if _shadow_tween:
		_shadow_tween.kill()
		_shadow_tween = null
	_shadow.visible = on and is_lit
	if _shadow.visible:
		_shadow_tween = create_tween().set_loops()
		_shadow_tween.tween_property(_shadow, "position:x", WIDTH * 0.35, 1.1).set_trans(Tween.TRANS_SINE)
		_shadow_tween.tween_property(_shadow, "position:x", -WIDTH * 0.35, 1.3).set_trans(Tween.TRANS_SINE)


func shadow_x() -> float:
	return _shadow.position.x


func _update_strip() -> void:
	is_lit = not _wants_open() and WorldState.get_phase() == &"night" and HubData.is_lived_in(place_id)
	_strip.visible = is_lit
	_strip_light.visible = is_lit
	if not is_lit and speaking:
		set_speaking(false)


func _apply(animate: bool) -> void:
	var angle := deg_to_rad(-OPEN_ANGLE if is_open else 0.0)
	_blocker.set_deferred("disabled", is_open)
	if _tween:
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween()
		_tween.tween_property(_hinge, "rotation:y", angle, 0.6).set_trans(Tween.TRANS_SINE)
	else:
		_hinge.rotation.y = angle
