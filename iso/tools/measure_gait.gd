extends SceneTree
## Measures how fast each locomotion clip actually travels over the ground, so the iso
## controller can move the body at exactly that speed (or scale the clip to match) and the
## feet never slide. The clips are baked in place, so travel is read off the feet: while a
## foot is planted it moves backwards under the hips at ground speed. Per clip, this prints
## the median backward speed of the lower foot over the cycle.
##
## Run: godot --headless --path . -s iso/tools/measure_gait.gd

const LIB := "res://assets/anims/mixamo_library.res"
const CHAR := "res://assets/chars/base/Superhero_Male_FullBody.gltf"
const CLIPS := ["walk", "walk_sad", "walk_hurt", "run"]

var _names: Array = []
var _parent: Array = []
var _rest: Array = []


func _init() -> void:
	var n: Node = (load(CHAR) as PackedScene).instantiate()
	var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
	for i in sk.get_bone_count():
		_names.append(sk.get_bone_name(i))
		_parent.append(sk.get_bone_parent(i))
		_rest.append(sk.get_bone_rest(i))
	n.free()
	var lib: AnimationLibrary = load(LIB)
	for clip in CLIPS:
		var a: Animation = lib.get_animation(clip)
		var speeds: Array = []
		var step := 1.0 / 60.0
		var t := 0.0
		var prev := {}
		while t + step <= a.length:
			var g := _globals(a, t)
			var g2 := _globals(a, t + step)
			for foot in ["foot_l", "foot_r"]:
				var i: int = _names.find(foot)
				var p1: Vector3 = (g[i] as Transform3D).origin
				var p2: Vector3 = (g2[i] as Transform3D).origin
				# the planted foot is the lower one; skeleton space here is Y-up, forward -Z or +Z
				var other: Vector3 = (g[_names.find("foot_r" if foot == "foot_l" else "foot_l")] as Transform3D).origin
				if p1.y <= other.y:
					var v := (p2 - p1) / step
					speeds.append(Vector2(v.x, v.z).length())
			t += step
		speeds.sort()
		var med: float = speeds[speeds.size() / 2] if not speeds.is_empty() else 0.0
		print("GAIT %-10s len=%.2f s  ground=%.2f m/s" % [clip, a.length, med])
	quit()


func _globals(a: Animation, t: float) -> Array:
	var local: Array = []
	for i in _names.size():
		local.append(_rest[i])
	for tr in a.get_track_count():
		var i: int = _names.find(String(a.track_get_path(tr)).get_slice(":", 1))
		if i < 0:
			continue
		var xf: Transform3D = local[i]
		if a.track_get_type(tr) == Animation.TYPE_ROTATION_3D:
			xf.basis = Basis(a.rotation_track_interpolate(tr, t))
		elif a.track_get_type(tr) == Animation.TYPE_POSITION_3D:
			xf.origin = a.position_track_interpolate(tr, t)
		local[i] = xf
	var g: Array = []
	for i in _names.size():
		g.append(local[i] if _parent[i] < 0 else (g[_parent[i]] as Transform3D) * (local[i] as Transform3D))
	return g
