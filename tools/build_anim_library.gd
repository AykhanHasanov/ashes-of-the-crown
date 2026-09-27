extends SceneTree
## Dev tool: merges Quaternius' Universal Animation Library 1 (Unreal FBX export) and
## Universal Animation Library 2 (Godot GLB) into one AnimationLibrary for the
## realistic characters (same UE-style skeleton: pelvis, spine_01, upperarm_l...).
## UAL1 comes in centimetres under a "Rig" node: tracks are re-pathed to
## "Armature/Skeleton3D:bone" and positions scaled to metres. Loops are marked.
## Output: res://assets/anims/ual_library.res
## Usage: godot --headless --path . -s tools/build_anim_library.gd

const OUT := "res://assets/anims/ual_library.res"
const LOOPS := ["Idle", "Idle_Talking", "Idle_Torch", "Walk", "Walk_Formal", "Jog_Fwd", "Sprint", "Crouch_Fwd", "Crouch_Idle",
	"Swim_Fwd", "Swim_Idle", "Sitting_Idle", "Sitting_Talking", "Sword_Idle", "Spell_Simple_Idle", "Pistol_Idle", "Driving",
	"Fixing_Kneeling", "Dance", "Zombie_Idle", "Zombie_Walk_Fwd", "Idle_FoldArms", "Idle_Lantern", "Idle_Rail", "Idle_Shield",
	"NinjaJump_Idle", "Walk_Carry", "Farm_Watering", "TreeChopping", "Farm_Harvest"]


func _init() -> void:
	var lib := AnimationLibrary.new()
	# Same rig as UAL2 but in centimetres: compare the two libraries directly
	var target_pelvis := _pelvis_height("res://assets/anims/UAL2.glb")
	# UAL2: same skeleton and paths already
	var n2 := _collect("res://assets/anims/UAL2.glb", lib, "", 1.0)
	# UAL1: re-path and rescale
	var fbx_pelvis := _pelvis_height("res://assets/anims/UAL1_UE.fbx")
	var scale := target_pelvis / fbx_pelvis if fbx_pelvis > 0.0001 else 1.0
	var n1 := _collect("res://assets/anims/UAL1_UE.fbx", lib, "Rig/Skeleton3D", scale)
	for a_name in lib.get_animation_list():
		if a_name in LOOPS:
			lib.get_animation(a_name).loop_mode = Animation.LOOP_LINEAR
	var err := ResourceSaver.save(lib, OUT)
	print("UAL2 %d + UAL1 %d animations (UAL1 position scale %.4f) → %s err=%d" % [n2, n1, scale, OUT, err])
	print(" ".join(lib.get_animation_list()))
	quit()


## Pelvis rest height in the model's own space (skeleton scale included).
func _pelvis_height(path: String) -> float:
	var s: Node3D = load(path).instantiate()
	var sk: Skeleton3D = s.find_children("*", "Skeleton3D", true, false)[0]
	var i := sk.find_bone("pelvis")
	var xf := Transform3D()
	var n: Node = sk
	while n != null and n != s:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	# Local rest offset length: independent of axis conventions (Z-up vs Y-up roots)
	var rest_y: float = sk.get_bone_rest(i).origin.length()
	var h: float = (xf * sk.get_bone_global_rest(i).origin).y
	print("  ", path.get_file(), " pelvis rest ", rest_y, " → model ", h, " (skeleton chain scale ", xf.basis.get_scale(), ")")
	s.free()
	return rest_y   # tracks live in skeleton space, so compare there


func _collect(path: String, lib: AnimationLibrary, from_prefix: String, pos_scale: float) -> int:
	var s: Node = load(path).instantiate()
	var ap: AnimationPlayer = s.find_children("*", "AnimationPlayer", true, false)[0]
	var n := 0
	for a_name in ap.get_animation_list():
		var clean: String = a_name.get_slice("|", a_name.get_slice_count("|") - 1)
		if clean == "A_TPose" or lib.has_animation(clean):
			continue
		var anim: Animation = ap.get_animation(a_name).duplicate(true)
		for t in range(anim.get_track_count() - 1, -1, -1):
			var p := String(anim.track_get_path(t))
			var bone := p.get_slice(":", 1)
			if bone.ends_with("_end_l") or bone.ends_with("_end_r") or bone == "root":
				anim.remove_track(t)   # leaf bones differ between exports; root stays still (in-place)
				continue
			if from_prefix != "":
				anim.track_set_path(t, NodePath("Armature/Skeleton3D:" + bone))
			if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and pos_scale != 1.0:
				for k in anim.track_get_key_count(t):
					anim.track_set_key_value(t, k, anim.track_get_key_value(t, k) * pos_scale)
		lib.add_animation(clean, anim)
		n += 1
	s.free()
	return n
