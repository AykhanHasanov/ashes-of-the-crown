extends Node3D
## A Son Ocaq door: a stable id, the place (room) it belongs to, and whether it is open.
## A view of derived state (HubData.door_open): it re-reads WorldState whenever time,
## people or overrides change, swings its leaf and announces EventBus.door_changed.
## The leaf hinges on the door's left edge and swings out; closed, it blocks the doorway.

const HubData := preload("res://scripts/hub/hub_data.gd")
const LEAF := "res://assets/village_mk/Door_1_Round.gltf"
const OPEN_ANGLE := 100.0
const WIDTH := 1.1

var door_id: StringName
var place_id := ""
var is_open := false

var _hinge: Node3D
var _blocker: CollisionShape3D
var _tween: Tween


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
	EventBus.time_of_day_changed.connect(func(_p): refresh())
	EventBus.npc_moved.connect(func(_a, _b, _c): refresh())
	EventBus.npc_died.connect(func(_a, _b): refresh())
	EventBus.world_changed.connect(_on_world_changed)
	EventBus.flag_changed.connect(func(_k, _o, _n): refresh())
	EventBus.state_replaced.connect(refresh)
	is_open = HubData.door_open(String(door_id))
	_apply(false)


func _on_world_changed(key: StringName) -> void:
	if key == &"doors":
		refresh()


func refresh() -> void:
	var want := HubData.door_open(String(door_id))
	if want == is_open:
		return
	is_open = want
	_apply(true)
	EventBus.door_changed.emit(door_id, is_open)


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
