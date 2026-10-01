extends SceneTree
## Retargets the Mixamo clips in assets/anims/mixamo/*.fbx onto this project's character rig
## and bakes them into one AnimationLibrary (assets/anims/mixamo_library.res).
##
## The two rigs differ in both naming (mixamorig_LeftArm vs upperarm_l) and rest pose (Mixamo
## is a T-pose, ours is an A-pose), so the clips cannot simply be renamed. For every bone and
## every sampled frame this takes the world-space rotation the clip applies to the SOURCE
## bone relative to its own rest, and applies that same world rotation to the TARGET bone's
## rest, then converts the result back into the target's local space:
##   delta  = pose_global_src * rest_global_src⁻¹            (in the SOURCE skeleton's space)
##   delta' = S · delta · S⁻¹                                 (S: source space → target space)
##   local  = (pose_global_tgt(parent))⁻¹ · delta' · rest_global_tgt
## S matters: the two skeletons do not share an orientation (ours is Z-up inside its armature,
## Mixamo's is Y-up), so without it every clip lands the character face down. It is measured
## from each rig's own rest: pelvis→head is "up", hand→hand is "right".
## The hips keep their motion, scaled by the height difference between the rigs; for clips
## marked in_place the horizontal part is dropped (the game moves the character itself).
##
## Run: godot --headless --path . -s tools/retarget_mixamo.gd
## v4 side-view test. Nothing else reads the library; see scripts/characters/human_tree.gd.

const SRC_DIR := "res://assets/anims/mixamo/"
const CHAR := "res://assets/chars/base/Superhero_Male_FullBody.gltf"
const OUT := "res://assets/anims/mixamo_library.res"
const FPS := 30.0
## How the shared library addresses the rig (scripts/characters/human.gd plays both).
const SK_PATH := "Armature/Skeleton3D:"

## Mixamo bone → our bone. Fingers included so a grip still reads.
const BONES := {
	"mixamorig_Hips": "pelvis", "mixamorig_Spine": "spine_01", "mixamorig_Spine1": "spine_02",
	"mixamorig_Spine2": "spine_03", "mixamorig_Neck": "neck_01", "mixamorig_Head": "Head",
	"mixamorig_LeftShoulder": "clavicle_l", "mixamorig_LeftArm": "upperarm_l",
	"mixamorig_LeftForeArm": "lowerarm_l", "mixamorig_LeftHand": "hand_l",
	"mixamorig_RightShoulder": "clavicle_r", "mixamorig_RightArm": "upperarm_r",
	"mixamorig_RightForeArm": "lowerarm_r", "mixamorig_RightHand": "hand_r",
	"mixamorig_LeftUpLeg": "thigh_l", "mixamorig_LeftLeg": "calf_l", "mixamorig_LeftFoot": "foot_l",
	"mixamorig_LeftToeBase": "ball_l",
	"mixamorig_RightUpLeg": "thigh_r", "mixamorig_RightLeg": "calf_r", "mixamorig_RightFoot": "foot_r",
	"mixamorig_RightToeBase": "ball_r",
	"mixamorig_LeftHandThumb1": "thumb_01_l", "mixamorig_LeftHandThumb2": "thumb_02_l", "mixamorig_LeftHandThumb3": "thumb_03_l",
	"mixamorig_LeftHandIndex1": "index_01_l", "mixamorig_LeftHandIndex2": "index_02_l", "mixamorig_LeftHandIndex3": "index_03_l",
	"mixamorig_LeftHandMiddle1": "middle_01_l", "mixamorig_LeftHandMiddle2": "middle_02_l", "mixamorig_LeftHandMiddle3": "middle_03_l",
	"mixamorig_LeftHandRing1": "ring_01_l", "mixamorig_LeftHandRing2": "ring_02_l", "mixamorig_LeftHandRing3": "ring_03_l",
	"mixamorig_LeftHandPinky1": "pinky_01_l", "mixamorig_LeftHandPinky2": "pinky_02_l", "mixamorig_LeftHandPinky3": "pinky_03_l",
	"mixamorig_RightHandThumb1": "thumb_01_r", "mixamorig_RightHandThumb2": "thumb_02_r", "mixamorig_RightHandThumb3": "thumb_03_r",
	"mixamorig_RightHandIndex1": "index_01_r", "mixamorig_RightHandIndex2": "index_02_r", "mixamorig_RightHandIndex3": "index_03_r",
	"mixamorig_RightHandMiddle1": "middle_01_r", "mixamorig_RightHandMiddle2": "middle_02_r", "mixamorig_RightHandMiddle3": "middle_03_r",
	"mixamorig_RightHandRing1": "ring_01_r", "mixamorig_RightHandRing2": "ring_02_r", "mixamorig_RightHandRing3": "ring_03_r",
	"mixamorig_RightHandPinky1": "pinky_01_r", "mixamorig_RightHandPinky2": "pinky_02_r", "mixamorig_RightHandPinky3": "pinky_03_r",
}

## file (without .fbx) → [library name, loops, in place (drop the travel)]
const CLIPS := {
	"Sad Idle": ["idle", true, true],
	"Ninja Idle": ["idle_combat", true, true],
	"Sad Walk": ["walk", true, true],
	"Drunk Walk": ["walk_hurt", true, true],
	"Drunk Run Forward": ["run", true, true],
	"Jumping": ["jump", false, true],
	"Dodging Back": ["dodge", false, true],
	"Blocking": ["block", true, true],
	"Punch Combo": ["punch", false, true],
	"Stabbing": ["attack_stab", false, true],
	"Standing Melee Attack 360 High": ["attack_spin", false, true],
	"Paladin WProp J Nordstrom": ["attack_swing", false, true],
	"Hit Reaction": ["hit_a", false, true],
	"Reaction": ["hit_b", false, true],
	"Dying": ["death", false, false],
}

var _tgt_rest := {}      # our bone name → global rest Transform3D
var _tgt_parent := {}    # our bone name → parent bone name ("" at the root)
var _tgt_local := {}     # our bone name → local rest


func _init() -> void:
	if not _load_target():
		quit(1)
		return
	var lib := AnimationLibrary.new()
	var made := 0
	for file in CLIPS:
		var path: String = SRC_DIR + file + ".fbx"
		if not ResourceLoader.exists(path):
			print("MISSING  ", path)
			continue
		var spec: Array = CLIPS[file]
		var anim := _retarget(path, bool(spec[1]), bool(spec[2]))
		if anim == null:
			print("FAILED   ", file)
			continue
		lib.add_animation(String(spec[0]), anim)
		made += 1
		print("ok  %-32s → %-12s %5.2f s, %d tracks" % [file, spec[0], anim.length, anim.get_track_count()])
	var err := ResourceSaver.save(lib, OUT)
	print("RETARGET DONE: %d clips → %s (err %d)" % [made, OUT, err])
	quit(0 if err == OK and made > 0 else 1)


## Our rig's rest pose, by bone name.
func _load_target() -> bool:
	var ps = load(CHAR)
	if ps == null:
		print("no character at ", CHAR)
		return false
	var n: Node = ps.instantiate()
	var sk: Skeleton3D = null
	for s in n.find_children("*", "Skeleton3D", true, false):
		sk = s
		break
	if sk == null:
		n.free()
		return false
	for i in sk.get_bone_count():
		var bone := sk.get_bone_name(i)
		_tgt_rest[bone] = sk.get_bone_global_rest(i)
		_tgt_local[bone] = sk.get_bone_rest(i)
		var p := sk.get_bone_parent(i)
		_tgt_parent[bone] = sk.get_bone_name(p) if p >= 0 else ""
	n.free()
	return true


func _retarget(path: String, loops: bool, in_place: bool) -> Animation:
	var ps = load(path)
	if ps == null:
		return null
	var n: Node = ps.instantiate()
	var sk: Skeleton3D = null
	for s in n.find_children("*", "Skeleton3D", true, false):
		sk = s
		break
	var ap: AnimationPlayer = null
	for a in n.find_children("*", "AnimationPlayer", true, false):
		ap = a
		break
	if sk == null or ap == null or ap.get_animation_list().is_empty():
		n.free()
		return null
	var src: Animation = ap.get_animation(ap.get_animation_list()[0])
	# the source's own rest, and the height ratio for the hips' travel
	var src_rest := {}
	var src_parent := {}
	for i in sk.get_bone_count():
		var bone := sk.get_bone_name(i)
		src_rest[bone] = sk.get_bone_global_rest(i)
		var p := sk.get_bone_parent(i)
		src_parent[bone] = sk.get_bone_name(p) if p >= 0 else ""
	var scale := 1.0
	if src_rest.has("mixamorig_Hips") and _tgt_rest.has("pelvis"):
		var sh: float = (src_rest["mixamorig_Hips"] as Transform3D).origin.y
		var th: float = (_tgt_rest["pelvis"] as Transform3D).origin.y
		if sh > 0.001:
			scale = th / sh
	var out := Animation.new()
	out.length = src.length
	out.loop_mode = Animation.LOOP_LINEAR if loops else Animation.LOOP_NONE
	out.step = 1.0 / FPS
	# one rotation track per mapped bone, plus the hips' position
	var tracks := {}
	for src_bone in BONES:
		if sk.find_bone(src_bone) < 0 or not _tgt_rest.has(BONES[src_bone]):
			continue
		var t := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(t, NodePath("Armature/Skeleton3D:" + String(BONES[src_bone])))
		out.track_set_interpolation_type(t, Animation.INTERPOLATION_LINEAR)
		tracks[src_bone] = t
	# the pelvis' parent, so its global travel can be written as the local track Godot plays
	var hips_space := Transform3D()
	var hips_parent: String = _tgt_parent.get("pelvis", "")
	if _tgt_rest.has(hips_parent):
		hips_space = (_tgt_rest[hips_parent] as Transform3D).affine_inverse()
	var hips_track := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(hips_track, NodePath("Armature/Skeleton3D:pelvis"))
	var frames := maxi(int(src.length * FPS), 1)
	var first_flat := Vector3.ZERO
	for f in frames + 1:
		var time := minf(float(f) / FPS, src.length)
		var pose := _sample_pose(src, sk, time)          # source local poses this frame
		var src_global := _globals(sk, pose, src_parent)  # source global poses
		var tgt_global := {}
		for src_bone in BONES:
			var tgt_bone: String = BONES[src_bone]
			if not tracks.has(src_bone):
				continue
			# the world rotation the clip puts on this bone, relative to its own rest
			var delta: Basis = (src_global[src_bone] as Transform3D).basis * (src_rest[src_bone] as Transform3D).basis.inverse()
			var want: Basis = delta * (_tgt_rest[tgt_bone] as Transform3D).basis
			var parent: String = _tgt_parent[tgt_bone]
			var parent_basis: Basis = tgt_global.get(parent, (_tgt_rest[parent] as Transform3D).basis if _tgt_rest.has(parent) else Basis())
			var local: Basis = parent_basis.inverse() * want
			tgt_global[tgt_bone] = want
			out.rotation_track_insert_key(tracks[src_bone], time, local.orthonormalized().get_rotation_quaternion())
		# the hips: their travel in our scale, flattened for in-place clips, then taken out of
		# skeleton space into the pelvis' parent (a rotated `root` bone on this rig) — a track
		# Godot plays is local, and a global position written straight in tips him over
		var hips: Vector3 = (src_global["mixamorig_Hips"] as Transform3D).origin * scale
		if f == 0:
			first_flat = Vector3(hips.x, 0.0, hips.z)
		if in_place:
			hips -= first_flat
			hips.x = 0.0
			hips.z = 0.0
		out.position_track_insert_key(hips_track, time, hips_space * hips)
	n.free()
	return out


## The source skeleton's local pose at `time` (rest where a bone has no track).
func _sample_pose(src: Animation, sk: Skeleton3D, time: float) -> Dictionary:
	var pose := {}
	for i in sk.get_bone_count():
		pose[sk.get_bone_name(i)] = sk.get_bone_rest(i)
	for t in src.get_track_count():
		var path := String(src.track_get_path(t))
		var bone := path.get_slice(":", 1)
		if not pose.has(bone):
			continue
		var xf: Transform3D = pose[bone]
		match src.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				xf.basis = Basis(src.rotation_track_interpolate(t, time)).scaled(xf.basis.get_scale())
			Animation.TYPE_POSITION_3D:
				xf.origin = src.position_track_interpolate(t, time)
			_:
				continue
		pose[bone] = xf
	return pose


## Local poses → global, walking the hierarchy in skeleton order (parents come first).
func _globals(sk: Skeleton3D, pose: Dictionary, parents: Dictionary) -> Dictionary:
	var out := {}
	for i in sk.get_bone_count():
		var bone := sk.get_bone_name(i)
		var parent: String = parents[bone]
		var local: Transform3D = pose[bone]
		out[bone] = (out[parent] as Transform3D) * local if out.has(parent) else local
	return out
