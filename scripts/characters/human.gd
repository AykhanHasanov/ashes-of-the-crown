extends Node3D
## A realistic human (V3 realism pass) and a drop-in replacement for CharacterModel:
## a Quaternius outfit character (Ranger/Peasant, male/female) with a head, eyes and
## brows from the Universal Base Characters, optional hair and beard, the merged
## Universal Animation Library, and the same API the combat code already uses
## (play_action, play_loop, cancel_action, set_locomotion, recolor, attach, borrow...).
##
## Clip names from the old KayKit rig are translated through CLIP_MAP. Each entry
## keeps the moment a blow lands: [new clip, impact in the old clip, impact in the new
## clip] — the play speed is scaled so the hit still lands when the game expects it.

signal action_finished(anim: StringName)

const LIB := "res://assets/anims/ual_library.res"
const OUTFITS := "res://assets/chars/outfits/%s.gltf"
const BASE := {"male": "res://assets/chars/base/Superhero_Male_FullBody.gltf", "female": "res://assets/chars/base/Superhero_Female_FullBody.gltf"}
const HAIR := "res://assets/chars/hair/%s.gltf"
const RECOLOR := preload("res://shaders/recolor.gdshader")

const CLIP_MAP := {
	# Locomotion and idles
	"Idle": ["Idle"], "Idle_B": ["Idle"], "Unarmed_Idle": ["Idle"], "Idle_Combat": ["Sword_Idle"], "2H_Melee_Idle": ["Sword_Idle"],
	"Running_A": ["Jog_Fwd"], "Running_B": ["Jog_Fwd"], "Running_C": ["Jog_Fwd"], "Walking_A": ["Walk"], "Walking_B": ["Walk"],
	"Walking_C": ["Walk"], "Walking_D_Skeletons": ["Zombie_Walk_Fwd"], "Walking_Backwards": ["Walk", 1.0, -1.0],
	"Running_Strafe_Left": ["Jog_Fwd"], "Running_Strafe_Right": ["Jog_Fwd"],
	"Jump_Start": ["Jump_Start"], "Jump_Idle": ["Jump"], "Jump_Land": ["Jump_Land"],
	"Dodge_Forward": ["Roll"], "Dodge_Backward": ["Roll"], "Dodge_Left": ["Roll"], "Dodge_Right": ["Roll"],
	# Sword and shield
	"1H_Melee_Attack_Slice_Diagonal": ["Sword_Regular_A", 0.45, 0.22],
	"1H_Melee_Attack_Slice_Horizontal": ["Sword_Regular_B", 0.45, 0.28],
	"1H_Melee_Attack_Chop": ["Sword_Attack", 0.55, 0.62],
	"1H_Melee_Attack_Stab": ["Sword_Dash", 0.42, 0.55],
	"1H_Melee_Attack_Jump_Chop": ["Sword_Attack", 0.55, 0.62],
	"2H_Melee_Attack_Chop": ["Sword_Attack", 0.55, 0.62],
	"2H_Melee_Attack_Slice": ["Sword_Regular_B", 0.5, 0.28],
	"2H_Melee_Attack_Spin": ["Sword_Regular_C", 0.5, 0.9],
	"2H_Melee_Attack_Spinning": ["Sword_Regular_C", 0.5, 0.9],
	"2H_Melee_Attack_Stab": ["Sword_Dash", 0.45, 0.55],
	"Dualwield_Melee_Attack_Slice": ["Sword_Regular_A", 0.4, 0.22],
	"Dualwield_Melee_Attack_Stab": ["Sword_Dash", 0.35, 0.55],
	"Dualwield_Melee_Attack_Chop": ["Sword_Attack", 0.45, 0.62],
	"Unarmed_Melee_Attack_Kick": ["Punch_Cross", 0.35, 0.35],
	"Unarmed_Melee_Attack_Punch_A": ["Punch_Jab", 0.3, 0.25],
	"Block_Attack": ["Shield_OneShot", 0.35, 0.32],
	"Blocking": ["Idle_Shield"], "Block": ["Idle_Shield"], "Block_Hit": ["Sword_Block", 1.0, 1.0],
	# Ranged and magic
	"1H_Ranged_Aiming": ["Pistol_Aim_Neutral"], "2H_Ranged_Aiming": ["Pistol_Aim_Neutral"],
	"1H_Ranged_Shoot": ["Pistol_Shoot", 0.1, 0.08], "2H_Ranged_Shoot": ["Pistol_Shoot", 0.1, 0.08],
	"Spellcasting": ["Spell_Simple_Idle"], "Spellcast_Raise": ["Spell_Simple_Enter", 0.6, 0.4],
	"Spellcast_Shoot": ["Spell_Simple_Shoot", 0.3, 0.2], "Spellcast_Long": ["OverhandThrow", 0.9, 0.65],
	"Spellcast_Summon": ["OverhandThrow", 0.8, 0.65], "Throw": ["OverhandThrow", 0.5, 0.65],
	# Reactions
	"Hit_A": ["Hit_Chest"], "Hit_B": ["Hit_Head"], "Death_A": ["Death01"], "Death_B": ["Death01"],
	"Death_C_Skeletons": ["Death01"], "Lie_Down": ["Hit_Knockback"], "Lie_Idle": ["Death01"],
	"Lie_StandUp": ["LayToIdle"], "Spawn_Ground_Skeletons": ["LayToIdle"], "Spawn_Ground": ["LayToIdle"],
	"Use_Item": ["Consume"], "Interact": ["Interact"], "PickUp": ["PickUp_Table"],
	"Cheer": ["Idle_Rail_Call"], "Taunt": ["Idle_Rail_Call"], "Taunt_Longer": ["Idle_Rail_Call"],
	"Sit_Floor_Down": ["Sitting_Enter"], "Sit_Floor_Idle": ["Sitting_Idle"], "Sit_Chair_Idle": ["Sitting_Idle"],
}
const LOOPING := ["Idle", "Sword_Idle", "Jog_Fwd", "Walk", "Sprint", "Zombie_Walk_Fwd", "Zombie_Idle", "Idle_Shield",
	"Spell_Simple_Idle", "Pistol_Aim_Neutral", "Sitting_Idle", "Swim_Fwd", "Swim_Idle", "Crouch_Idle", "Jump", "Idle_Lantern", "Idle_FoldArms"]
const BONE_ALIAS := {"handslot.r": "hand_r", "handslot.l": "hand_l", "chest": "spine_03", "head": "Head", "Head": "Head"}

var anim: AnimationPlayer
var skeleton: Skeleton3D
var scene: Node3D                 # the outfit body (CharacterModel called it scene)
var idle_anim := "Idle"
var move_anim := "Running_A"
var action := ""
var hold_last := false
var _locomotion := ""


## spec: outfit ("Male_Ranger"...), gender, hair ("Hair_SimpleParted"...), beard (bool),
## hood (bool), hair_color, cloth_hue ([from_min, from_max, to_hue, sat, val]) or tint (Color)
static func build(spec: Dictionary) -> Node3D:
	var h = load("res://scripts/characters/human.gd").new()
	h.setup_human(spec)
	return h


static var _looks: Dictionary = {}
static var _warm: Array = []


## Loads every file a human can need (outfits, heads, hair, the animation library and
## the enemies' weapons) once, at level start, and keeps them cached: the first bandit
## to appear mid-fight would otherwise stall the game while its textures load from disk.
static func warm_up() -> void:
	if not _warm.is_empty():
		return
	var paths: Array = [LIB, BASE["male"], BASE["female"]]
	for o in ["Male_Ranger", "Male_Peasant", "Female_Ranger", "Female_Peasant"]:
		paths.append(OUTFITS % o)
	for g in ["male", "female"]:
		paths.append("res://assets/chars/heads/%s_head.res" % g)
		paths.append("res://assets/chars/heads/%s_skin.res" % g)
	for f in DirAccess.get_files_at("res://assets/chars/hair"):
		if f.ends_with(".gltf"):
			paths.append("res://assets/chars/hair/" + f)
	paths.append("res://assets/chars/base/T_Eye_Brown.png")
	for f in DirAccess.get_files_at("res://data/enemies"):
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies/" + f))
		if d is Dictionary and d.get("model", {}).has("human"):
			for w in d["model"].get("weapons", []):
				if w.has("path"):
					paths.append(w["path"])
	for p in paths:
		if ResourceLoader.exists(p):
			_warm.append(load(p))


## Builds a spec from JSON: {"look": "bandit", ...overrides}. A look with variants picks
## one with `rng`; [r, g, b] colour arrays become Colors.
static func spec_from_json(d: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if _looks.is_empty():
		_looks = JSON.parse_string(FileAccess.get_file_as_string("res://data/looks.json"))
	var looks := _looks
	var spec := {}
	if d.has("look"):
		var look = looks[d["look"]]
		if look is Array:
			look = look[rng.randi() % look.size()]
		spec.merge(look, true)
	spec.merge(d, true)
	spec.erase("look")
	for k in ["hair_color", "tint", "skin_tint"]:
		if spec.get(k) is Array:
			var c: Array = spec[k]
			spec[k] = Color(c[0], c[1], c[2])
	return spec


func setup_human(spec: Dictionary) -> void:
	var outfit: String = spec.get("outfit", "Male_Ranger")
	var gender: String = spec.get("gender", "female" if outfit.begins_with("Female") else "male")
	scene = load(OUTFITS % outfit).instantiate()
	scene.scale = Vector3.ONE * float(spec.get("scale", 1.0))
	add_child(scene)
	scene.rotation.y = PI   # glTF faces +Z; the game faces -Z
	skeleton = scene.find_children("*", "Skeleton3D", true, false)[0]
	var hood_on: bool = spec.get("hood", true) and outfit.ends_with("Ranger")
	if not hood_on:
		for mi in scene.find_children("*Hood*", "MeshInstance3D", true, false):
			mi.free()
	if not spec.get("pauldron", true):
		for mi in scene.find_children("*Pauldron*", "MeshInstance3D", true, false):
			mi.free()
	var head := MeshInstance3D.new()
	head.name = "HeadMesh"
	head.mesh = load("res://assets/chars/heads/%s_head.res" % gender)
	head.skin = load("res://assets/chars/heads/%s_skin.res" % gender)
	skeleton.add_child(head)
	head.skeleton = NodePath("..")
	var base: Node = load(BASE[gender]).instantiate()
	for part in ["Eyes", "Eyebrows"]:
		var src: MeshInstance3D = base.find_child(part, true, false)
		if src:
			var mi := MeshInstance3D.new()
			mi.name = part
			mi.mesh = src.mesh
			mi.skin = src.skin
			skeleton.add_child(mi)
			mi.skeleton = NodePath("..")
			if part == "Eyes":
				var em := StandardMaterial3D.new()   # explicit: the gltf may import before its textures
				em.albedo_texture = load("res://assets/chars/base/T_Eye_Brown.png")
				em.roughness = 0.2
				mi.material_override = em
	base.free()
	var hair_color: Color = spec.get("hair_color", Color(0.14, 0.1, 0.07))
	for hair_name in [spec.get("hair", ""), "Hair_Beard" if spec.get("beard", false) else ""]:
		if hair_name == "" or (hood_on and hair_name != "Hair_Beard"):
			continue
		var att := BoneAttachment3D.new()
		att.bone_name = "Head"
		skeleton.add_child(att)
		var hair: Node3D = load(HAIR % hair_name).instantiate()
		att.add_child(hair)
		hair.transform = skeleton.get_bone_global_rest(skeleton.find_bone("Head")).affine_inverse()
		_multiply(hair, hair_color * 2.2)
	var brows: MeshInstance3D = skeleton.get_node_or_null("Eyebrows")
	if brows:
		_multiply(brows, hair_color * 2.0)
	if spec.has("cloth_hue"):
		var r: Array = spec["cloth_hue"]
		recolor(r[0], r[1], r[2], r[3], r[4], true)
	elif spec.has("tint"):
		tint(spec["tint"], [], true)
	if spec.has("skin_tint"):
		for n in ["HeadMesh"]:
			_multiply(skeleton.get_node(n), spec["skin_tint"])
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	anim = AnimationPlayer.new()
	scene.add_child(anim)
	anim.root_node = NodePath("..")
	anim.add_animation_library("", load(LIB))
	anim.animation_finished.connect(_on_finished)
	set_locomotion(false)


# --- Materials ---------------------------------------------------------------------------------

func _cloth_meshes() -> Array:
	return scene.find_children("*", "MeshInstance3D", true, false).filter(func(m): return m.name.begins_with("Male_") or m.name.begins_with("Female_"))


func _multiply(root: Node, c: Color) -> void:
	var list: Array = [root] if root is MeshInstance3D else root.find_children("*", "MeshInstance3D", true, false)
	for mi: MeshInstance3D in list:
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m is StandardMaterial3D:
				var copy: StandardMaterial3D = m.duplicate()
				copy.albedo_color = copy.albedo_color * c
				mi.set_surface_override_material(s, copy)


func tint(color: Color, _only: Array = [], cloth_only := false) -> Array:
	var out := []
	for mi: MeshInstance3D in (_cloth_meshes() if cloth_only else scene.find_children("*", "MeshInstance3D", true, false)):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m is StandardMaterial3D:
				var copy: StandardMaterial3D = m.duplicate()
				copy.albedo_color = copy.albedo_color * color
				mi.set_surface_override_material(s, copy)
				out.append([copy, copy.albedo_color])
	return out


## Hue-range recolour of the outfit (e.g. the ranger's green into Ayxan's crimson).
func recolor(from_min: float, from_max: float, to_hue: float, sat_scale := 1.0, val_scale := 0.8, _cloth := true) -> Array:
	var out := []
	for mi: MeshInstance3D in _cloth_meshes():
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m is ShaderMaterial and m.shader == RECOLOR:
				# Already recoloured (spec at build time): just retune it
				for k in [["from_min", from_min], ["from_max", from_max], ["to_hue", to_hue], ["sat_scale", sat_scale], ["val_scale", val_scale]]:
					m.set_shader_parameter(k[0], k[1])
				out.append(m)
				continue
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
			out.append(sm)
	return out


func set_material_all(material: Material) -> void:
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mi.material_override = material
		mi.material_overlay = null


func set_overlay(material: Material) -> void:
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = material


# --- Bones and attachments ---------------------------------------------------------------------

func _bone(name: String) -> String:
	return BONE_ALIAS.get(name, name)


func bone_position(bone: String) -> Vector3:
	var i := skeleton.find_bone(_bone(bone))
	return skeleton.global_transform * skeleton.get_bone_global_pose(i).origin if i >= 0 else global_position


## Real-scale props (the Fantasy Props MegaKit) go in unscaled; `shield` faces out of the hand.
func attach(path: String, bone: String, rot_deg := Vector3.ZERO, shield := false) -> Node3D:
	var item: Node3D = load(path).instantiate()
	_grip(bone, shield, 1.0).add_child(item)
	item.rotation_degrees = rot_deg
	return item


## Copies a mesh node out of another file (the KayKit knight's sword) into a hand.
func borrow(path: String, node_name: String, bone: String) -> Node3D:
	var donor: Node = load(path).instantiate()
	var found := donor.find_children(node_name, "", true, false)
	if found.is_empty():
		donor.free()
		return null
	var item: Node3D = found[0].duplicate()
	donor.free()
	_grip(bone, "Shield" in node_name).add_child(item)
	item.transform = Transform3D.IDENTITY
	return item


## Scale of KayKit props (sized for chunky toy characters) on a realistic body.
const PROP_SCALE := 0.72

## A pivot inside the fist. Measured on this rig: fingers run along the hand bone's +Y,
## the thumb side is +Z and the palm faces -X (right) / +X (left). KayKit weapons point
## along +Y out of the fist, so +Y is turned onto +Z and the pivot sits in the palm.
## A shield instead faces out from the back of the hand (KayKit shields face +Z).
func _grip(bone: String, shield := false, prop_scale := PROP_SCALE) -> Node3D:
	var holder := BoneAttachment3D.new()
	holder.bone_name = _bone(bone)
	skeleton.add_child(holder)
	var pivot := Node3D.new()
	if bone == "handslot.r" or bone == "handslot.l":
		var side := -1.0 if bone == "handslot.r" else 1.0
		if shield:
			pivot.position = Vector3(-0.07 * side, 0.02, 0.0)
			pivot.rotation_degrees = Vector3(0, -90 * side, 0)
		else:
			pivot.position = Vector3(0.03 * side, 0.085, 0.0)
			pivot.rotation_degrees = Vector3(90, 0, 0)
		pivot.scale = Vector3.ONE * prop_scale
	holder.add_child(pivot)
	return pivot


## Compatibility: height-based fitting is not needed for humans.
func fit_length(_length: float) -> void:
	pass


func bounds() -> AABB:
	return AABB(Vector3(-0.4, 0, -0.3), Vector3(0.8, 1.85, 0.6))


# --- Animation ---------------------------------------------------------------------------------

## [clip, speed factor, direction] for an old or new clip name.
func _map(clip: String) -> Array:
	if anim.has_animation(clip) and not CLIP_MAP.has(clip):
		return [clip, 1.0, 1.0]
	var e: Array = CLIP_MAP.get(clip, [])
	if e.is_empty() or not anim.has_animation(e[0]):
		return ["", 1.0, 1.0]
	var factor := 1.0
	var dir := 1.0
	if e.size() == 3 and float(e[1]) > 0.0 and e[0] != "Walk":
		factor = float(e[2]) / float(e[1])
	if e.size() == 3 and e[0] == "Walk":
		dir = float(e[2])
	return [e[0], factor, dir]


func has(clip: String) -> bool:
	return _map(clip)[0] != ""


func play_loop(clip: String, speed := 1.0, blend := 0.18) -> void:
	var m := _map(clip)
	if action != "" or m[0] == "":
		return
	anim.speed_scale = speed * float(m[2])
	if _locomotion != m[0]:
		_locomotion = m[0]
		var clip_name: String = m[0]
		if clip_name in LOOPING:
			clip_name = _with_loop(clip_name, Animation.LOOP_LINEAR)
		anim.play(clip_name, blend)


func set_locomotion(moving: bool, speed_scale := 1.0) -> void:
	play_loop(move_anim if moving else idle_anim, speed_scale if moving else 1.0)


func set_idle(clip: String) -> void:
	if idle_anim == clip:
		return
	idle_anim = clip
	if action == "":
		_locomotion = ""
		set_locomotion(false)


func play_action(clip: String, speed := 1.0, blend := 0.08, hold := false) -> void:
	var m := _map(clip)
	if m[0] == "":
		return
	action = _with_loop(m[0], Animation.LOOP_NONE)
	hold_last = hold
	_locomotion = ""
	anim.speed_scale = speed * float(m[1])
	anim.play(action, blend)
	anim.seek(0.0, true)


## The animation library is one resource shared by every human, so its clips are never
## edited here. When this character needs a clip with another loop mode than the shared
## one, it gets its own copy of just that clip (in a per-instance "local" library).
func _with_loop(clip: String, mode: Animation.LoopMode) -> String:
	var a := anim.get_animation(clip)
	if a == null or a.loop_mode == mode:
		return clip
	if not anim.has_animation_library("local"):
		anim.add_animation_library("local", AnimationLibrary.new())
	var lib := anim.get_animation_library("local")
	var key := clip + ("_once" if mode == Animation.LOOP_NONE else "_loop")
	if not lib.has_animation(key):
		var copy: Animation = a.duplicate()   # per-instance copy: only its loop mode differs
		copy.loop_mode = mode
		lib.add_animation(key, copy)
	return "local/" + key


func cancel_action() -> void:
	action = ""
	hold_last = false


func _on_finished(clip: StringName) -> void:
	if String(clip) != action:
		return
	action_finished.emit(clip)
	if hold_last:
		return
	action = ""
	set_locomotion(false)
