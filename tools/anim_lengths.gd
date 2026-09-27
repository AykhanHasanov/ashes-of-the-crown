extends SceneTree
func _init() -> void:
	var lib: AnimationLibrary = load("res://assets/anims/ual_library.res")
	var out := []
	for a in lib.get_animation_list():
		out.append("%s=%.2f" % [a, lib.get_animation(a).length])
	print(" ".join(out))
	quit()
