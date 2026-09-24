extends Node3D
## Wraps an imported KayKit character (glTF): hides unused equipment, recolors parts,
## attaches extra weapons to hand bones, loops locomotion clips and plays one-shot
## actions with cross-fades. Faces -Z like every other actor in the game.

signal action_finished(anim: StringName)

const RECOLOR := preload("res://shaders/recolor.gdshader")

const LOOPING := [
	"Idle", "Idle_B", "Idle_Combat", "2H_Melee_Idle", "Unarmed_Idle",
	"Running_A", "Running_B", "Running_C", "Walking_A", "Walking_B", "Walking_C",
	"Walking_D_Skeletons", "Blocking", "Spellcasting", "Lie_Idle",
]

var anim: AnimationPlayer
var skeleton: Skeleton3D
var scene: Node3D
var idle_anim := "Idle"
var move_anim := "Running_A"
## Name of the one-shot currently playing, or "" while in locomotion.
var action := ""
## Set when the action should freeze on its last frame (death).
var hold_last := false

var _locomotion := ""


func setup(path: String, hidden: Array, model_scale: float) -> void:
	scene = load(path).instantiate()
	scene.scale = Vector3.ONE * model_scale
	scene.rotation.y = PI  # glTF faces +Z, the game faces -Z
	add_child(scene)
	anim = scene.find_children("*", "AnimationPlayer", true, false)[0]
	skeleton = scene.find_children("*", "Skeleton3D", true, false)[0]
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		if mi.name in hidden:
			mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for n in LOOPING:
		if anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	anim.animation_finished.connect(_on_finished)
	set_locomotion(false)


func mesh(mesh_name: String) -> MeshInstance3D:
	var found := scene.find_children(mesh_name, "MeshInstance3D", true, false)
	return found[0] if not found.is_empty() else null


## Multiplies the albedo of every mesh (or only `only`) by `color`, using per-instance
## material copies. Returns [[material, base_color], ...] for later recoloring.
func tint(color: Color, only: Array = []) -> Array:
	var result := []
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if not only.is_empty() and not (mi.name in only):
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m is StandardMaterial3D:
				var copy: StandardMaterial3D = m.duplicate()
				copy.albedo_color = copy.albedo_color * color
				mi.set_surface_override_material(s, copy)
				result.append([copy, copy.albedo_color])
	return result


## Replaces every textured surface with the recolor shader (hue range → `to_hue`).
## Returns the ShaderMaterials so callers can animate "ash" or "tint".
func recolor(from_min: float, from_max: float, to_hue: float, sat_scale := 1.0, val_scale := 0.8) -> Array:
	var result := []
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if not (m is StandardMaterial3D) or m.albedo_texture == null:
				continue
			var sm := ShaderMaterial.new()
			sm.shader = RECOLOR
			sm.set_shader_parameter("albedo_tex", m.albedo_texture)
			sm.set_shader_parameter("from_min", from_min)
			sm.set_shader_parameter("from_max", from_max)
			sm.set_shader_parameter("to_hue", to_hue)
			sm.set_shader_parameter("sat_scale", sat_scale)
			sm.set_shader_parameter("val_scale", val_scale)
			mi.set_surface_override_material(s, sm)
			result.append(sm)
	return result


## Draws `material` on top of every visible mesh (glow, rim, hit flash).
func set_overlay(material: Material) -> void:
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = material


## Attaches the first mesh of a glTF file to a bone (e.g. "handslot.r").
func attach(path: String, bone: String, rot_deg := Vector3.ZERO) -> Node3D:
	var holder := BoneAttachment3D.new()
	holder.bone_name = bone
	skeleton.add_child(holder)
	var item: Node3D = load(path).instantiate()
	item.rotation_degrees = rot_deg
	holder.add_child(item)
	return item


## Copies a named mesh node out of another character file (e.g. the Knight's sword)
## onto one of this model's bones, keeping its local offset from the hand slot.
func borrow(path: String, node_name: String, bone: String) -> Node3D:
	var donor: Node = load(path).instantiate()
	var found := donor.find_children(node_name, "", true, false)
	if found.is_empty():
		donor.free()
		return null
	var item: Node3D = found[0].duplicate()
	donor.free()
	var holder := BoneAttachment3D.new()
	holder.bone_name = bone
	skeleton.add_child(holder)
	holder.add_child(item)
	return item


func bone_position(bone: String) -> Vector3:
	var idx := skeleton.find_bone(bone)
	if idx < 0:
		return global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(idx).origin


## Switches between idle and move clips. `speed_scale` adjusts the move clip rate.
func set_locomotion(moving: bool, speed_scale := 1.0) -> void:
	if action != "":
		return
	var want := move_anim if moving else idle_anim
	anim.speed_scale = speed_scale if moving else 1.0
	if want != _locomotion:
		_locomotion = want
		anim.play(want, 0.18)


## Plays a one-shot. Returns to locomotion when it ends unless `hold` is set.
func play_action(clip: String, speed := 1.0, blend := 0.08, hold := false) -> void:
	if not anim.has_animation(clip):
		return
	action = clip
	hold_last = hold
	_locomotion = ""
	anim.speed_scale = speed
	anim.play(clip, blend)
	anim.seek(0.0, true)


## Ends the current one-shot early (combo cancel, stagger).
func cancel_action() -> void:
	action = ""
	hold_last = false


func _on_finished(clip: StringName) -> void:
	if clip != action:
		return
	action_finished.emit(clip)
	if hold_last:
		return
	action = ""
	set_locomotion(false)
