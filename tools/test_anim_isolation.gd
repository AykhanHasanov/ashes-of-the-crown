extends SceneTree
## Regression test: characters that share a model (and so its animation resources) must
## not affect each other's animation. Six humans and six wolves loop the same clip; one
## of each then plays that clip as a one-shot, another plays a one-shot clip as a loop.
## The shared clips must keep their loop mode and the other instances must keep looping.
## Usage: godot --headless --path . -s tools/test_anim_isolation.gd   (exit code = failures)

const Human := preload("res://scripts/characters/human.gd")
const CharacterModel := preload("res://scripts/characters/character_model.gd")
const WOLF := "res://assets/quaternius/animals_pack/Wolf.glb"

var _fails := 0


func _init() -> void:
	_humans()
	_wolves()
	print("ANIM ISOLATION DONE, failures: ", _fails)
	quit(_fails)


func _humans() -> void:
	var list: Array = []
	for i in 6:
		var h: Node3D = Human.build({"outfit": "Male_Peasant"})
		root.add_child(h)
		h.play_loop("Idle")
		list.append(h)
	var shared_idle: Animation = list[0].anim.get_animation("Idle")
	var once_clip := _first_non_looping(list[0].anim, ["Jump", "Idle_Shield", "Sitting_Idle", "Idle_Lantern"])
	var once_mode: int = list[0].anim.get_animation(once_clip).loop_mode if once_clip != "" else -1
	# Instance 0: the looping clip as a one-shot. Instance 1: a one-shot clip as a loop.
	# Held one-shot (as death poses are): the old code set the shared clip to LOOP_NONE and
	# nothing put it back, so every other human froze at the end of its current cycle
	list[0].play_action("Idle", 1.0, 0.08, true)
	if once_clip != "":
		list[1].play_loop(once_clip)
	_run(list, shared_idle.length * 3.0)
	_check("human: shared 'Idle' still loops", shared_idle.loop_mode == Animation.LOOP_LINEAR)
	_check("human: held one-shot stopped on its last frame", not list[0].anim.is_playing())
	for i in range(2, 6):
		_check("human %d still looping 'Idle'" % i, list[i].anim.is_playing() and list[i].anim.current_animation == "Idle")
	if once_clip != "":
		_check("human: shared '%s' kept its loop mode" % once_clip, list[0].anim.get_animation(once_clip).loop_mode == once_mode)
		_check("human 1 loops its own copy", list[1].anim.is_playing())
	for h in list:
		h.free()


func _wolves() -> void:
	var gallop := "AnimalArmature|Gallop"
	var list: Array = []
	for i in 6:
		var m: Node3D = CharacterModel.new()
		root.add_child(m)
		m.setup(WOLF, [], 1.0, [gallop])
		m.play_loop(gallop)
		list.append(m)
	var shared: Animation = list[0].anim.get_animation(gallop)
	var imported_mode := shared.loop_mode
	list[0].play_action(gallop)
	_run(list, shared.length * 3.0)
	_check("wolf: shared Gallop keeps its imported loop mode", shared.loop_mode == imported_mode)
	_check("wolf: one-shot instance finished its action", list[0].action == "")
	for i in range(1, 6):
		var cur: String = list[i].anim.current_animation
		_check("wolf %d still galloping" % i, list[i].anim.is_playing() and (cur == gallop or cur == "local/" + gallop + "_loop"))
	for m in list:
		m.free()


func _run(list: Array, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		for c in list:
			c.anim.advance(1.0 / 30.0)
		t += 1.0 / 30.0


func _first_non_looping(ap: AnimationPlayer, names: Array) -> String:
	for n in names:
		if ap.has_animation(n) and ap.get_animation(n).loop_mode == Animation.LOOP_NONE:
			return n
	return ""


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_fails += 1
