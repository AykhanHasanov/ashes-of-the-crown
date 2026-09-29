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
const LINE_H := 0.012         # the gap under the door: a thin line of light, not a slot
const STRIP_ENERGY := 0.8
const AJAR_ANGLE := 22.0

var door_id: StringName
var place_id := ""
var is_open := false
var is_lit := false
var speaking := false
var held_open := false
var is_ajar := false                # someone of this room opened it to a shade: it never closes again

var _hinge: Node3D
var _blocker: CollisionShape3D
var _tween: Tween
var _strip: MeshInstance3D
var _strip_light: OmniLight3D
var _shadow: MeshInstance3D
var _shadow_tween: Tween
var _glow: MeshInstance3D
var _hidden_by_scene := false


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
		leaf.position = Vector3(0, -0.012, 0)   # the leaf's origin is its hinge side; it sits on the threshold
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
	is_ajar = HubData.is_door_death_place(place_id)
	_apply(false)
	_update_strip()


## Light under the door: a thin bright line at the threshold, a soft warm glow spilling onto
## the floor, a low light — and a soft shadow that crosses the glow when someone moves inside.
func _build_strip() -> void:
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(1.0, 0.72, 0.4)
	_strip = MeshInstance3D.new()
	_strip.name = "LightStrip"
	var line := QuadMesh.new()
	line.size = Vector2(WIDTH - 0.12, LINE_H)
	line.material = line_mat
	_strip.mesh = line
	_strip.position = Vector3(0, 0.02 + LINE_H * 0.5, 0.066)
	add_child(_strip)
	_glow = MeshInstance3D.new()
	_glow.name = "LightSpill"
	var glow := QuadMesh.new()
	glow.size = Vector2(WIDTH + 1.3, 1.6)
	glow.material = _soft_material(Color(1.0, 0.55, 0.22, 0.85), true)
	_glow.mesh = glow
	_glow.rotation.x = -PI * 0.5
	_glow.position = Vector3(0, 0.024, 0.066 + 0.8)
	add_child(_glow)
	_strip_light = OmniLight3D.new()
	_strip_light.light_color = Color(1.0, 0.55, 0.22)
	_strip_light.light_energy = STRIP_ENERGY
	_strip_light.omni_range = 1.5
	_strip_light.omni_attenuation = 2.0
	_strip_light.position = Vector3(0, 0.03, 0.14)   # from under the door: it lights the floor, not the wall
	add_child(_strip_light)
	_shadow = MeshInstance3D.new()
	_shadow.name = "StripShadow"
	var sq := QuadMesh.new()
	sq.size = Vector2(0.9, 1.6)
	sq.material = _soft_material(Color(0.0, 0.0, 0.0, 0.8), false)
	_shadow.mesh = sq
	_shadow.rotation.x = -PI * 0.5
	_shadow.position = Vector3(-WIDTH * 0.35, 0.027, 0.066 + 0.8)
	_shadow.visible = false
	add_child(_shadow)


## A soft spot, brightest at the door edge and fading into the floor. Additive for light,
## blended for shadow.
static func _soft_material(color: Color, additive: bool) -> StandardMaterial3D:
	# Fully faded at half the quad's depth, so the quad's own edges never show
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	g.set_offset(1, 0.5)
	g.add_point(0.22, Color(color.r, color.g, color.b, color.a * 0.45))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_texture = tex
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m


## The door scene: this strip is the scene's key light (brighter); `on` = false restores it.
func set_key_light(on: bool) -> void:
	_strip_light.light_energy = STRIP_ENERGY * (1.4 if on else 1.0)


## Hidden while another door's scene plays (the only warm light is that door's).
func set_strip_hidden(hidden: bool) -> void:
	_hidden_by_scene = hidden
	_update_strip()


func _on_world_changed(key: StringName) -> void:
	if key == &"doors":
		refresh()


func _wants_open() -> bool:
	return held_open or HubData.door_open(String(door_id))


func refresh() -> void:
	_update_strip()
	var want := _wants_open()
	var ajar := HubData.is_door_death_place(place_id)
	if want == is_open and ajar == is_ajar:
		return
	is_open = want
	is_ajar = ajar
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
	var shown := is_lit and not _hidden_by_scene
	_strip.visible = shown
	_glow.visible = shown
	_strip_light.visible = shown
	if not is_lit and speaking:
		set_speaking(false)


func _apply(animate: bool) -> void:
	var angle := deg_to_rad(-OPEN_ANGLE if is_open else (-AJAR_ANGLE if is_ajar else 0.0))
	_blocker.set_deferred("disabled", is_open)
	if _tween:
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween()
		_tween.tween_property(_hinge, "rotation:y", angle, 0.6).set_trans(Tween.TRANS_SINE)
	else:
		_hinge.rotation.y = angle


func strip_light_energy() -> float:
	return _strip_light.light_energy if _strip_light.visible else 0.0
