extends "res://scripts/characters/human.gd"
## A Human driven by an AnimationTree instead of direct AnimationPlayer calls (v4 side-view
## test): every change crossfades, and walking blends through a 1D space instead of snapping.
##
## Structure (built in code, so a new clip set only changes the names, never the shape):
##   root BlendTree
##     "machine"  StateMachine
##        "Locomotion"  BlendSpace1D   idle (0) → walk (0.5) → run (1)
##        "Action"      Animation      the clip of the moment (attack, dodge, hit, death...)
##     "scale"    TimeScale            one knob for playback speed
## Locomotion → Action is immediate with a short crossfade; Action → Locomotion happens at the
## end of the clip (or on cancel_action) with a longer one.
##
## It keeps Human's interface exactly (`set_locomotion`, `play_action`, `cancel_action`,
## `set_idle`, `action`), so the protagonist, enemies and allies need no change. SWAPPING IN
## MIXAMO: retarget the clips into the same AnimationPlayer and point CLIP_MAP (or a per-set
## map) at them — the tree, the states and the transitions stay as they are.

const WALK_AT := 0.5          # where the walk clip sits on the blend line
const XFADE_IN := 0.09        # into an action
const XFADE_OUT := 0.16       # back to walking
const XFADE_LOCO := 0.12

var tree: AnimationTree
var blend_speed := 7.0        # how fast the idle → walk → run blend follows the real speed

var _machine: AnimationNodeStateMachine
var _loco: AnimationNodeBlendSpace1D
var _action_node: AnimationNodeAnimation
var _playback: AnimationNodeStateMachinePlayback
var _want_blend := 0.0
var _blend_now := 0.0
var _want_scale := 1.0


static func build_tree(spec: Dictionary) -> Node3D:
	var h = load("res://scripts/characters/human_tree.gd").new()
	h.setup_human(spec)
	h.build_anim_tree()
	return h


## Builds the tree over the AnimationPlayer the Human already has.
func build_anim_tree() -> void:
	if anim == null or tree != null:
		return
	_loco = AnimationNodeBlendSpace1D.new()
	_loco.min_space = 0.0
	_loco.max_space = 1.0
	_loco.blend_mode = AnimationNodeBlendSpace1D.BLEND_MODE_INTERPOLATED
	_set_loco_clips()
	_action_node = AnimationNodeAnimation.new()
	_action_node.animation = _loop_clip(idle_anim)
	_machine = AnimationNodeStateMachine.new()
	_machine.add_node("Locomotion", _loco, Vector2(0, 0))
	_machine.add_node("Action", _action_node, Vector2(300, 0))
	_machine.add_transition("Locomotion", "Action", _transition(XFADE_IN, AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE, false))
	_machine.add_transition("Action", "Locomotion", _transition(XFADE_OUT, AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END, true))
	var scale := AnimationNodeTimeScale.new()
	var root := AnimationNodeBlendTree.new()
	root.add_node("machine", _machine, Vector2(0, 0))
	root.add_node("scale", scale, Vector2(300, 0))
	root.connect_node("scale", 0, "machine")
	root.connect_node("output", 0, "scale")
	tree = AnimationTree.new()
	tree.name = "AnimTree"
	tree.tree_root = root
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	add_child(tree)
	tree.anim_player = tree.get_path_to(anim)   # both are in the tree now, so the path resolves
	tree.active = true
	_playback = tree.get("parameters/machine/playback")
	_apply_blend(0.0)


func _transition(xfade: float, mode: int, auto: bool) -> AnimationNodeStateMachineTransition:
	var t := AnimationNodeStateMachineTransition.new()
	t.xfade_time = xfade
	t.switch_mode = mode
	t.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO if auto else AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
	t.reset = false
	return t


## idle at 0, walk at WALK_AT, run at 1 — the names come from the shared clip map, so a new
## set of clips slots straight in.
func _set_loco_clips() -> void:
	for i in range(_loco.get_blend_point_count() - 1, -1, -1):
		_loco.remove_blend_point(i)
	_add_point(idle_anim, 0.0)
	_add_point("Walking_A", WALK_AT)
	_add_point(move_anim, 1.0)


func _add_point(clip: String, at: float) -> void:
	var name := _loop_clip(clip)
	if name == "":
		return
	var node := AnimationNodeAnimation.new()
	node.animation = name
	_loco.add_blend_point(node, at)


## The clip's real name in the player, looped (locomotion clips must cycle).
func _loop_clip(clip: String) -> String:
	var m := _map(clip)
	if m[0] == "":
		return ""
	return _with_loop(String(m[0]), Animation.LOOP_LINEAR)


# --- Human's interface, driven through the tree -----------------------------------------------

func set_locomotion(moving: bool, speed_scale := 1.0) -> void:
	if tree == null:
		super.set_locomotion(moving, speed_scale)
		return
	# speed_scale is 0.5 … 1.2 of the run speed; map it onto idle → walk → run
	_want_blend = 0.0 if not moving else clampf(speed_scale, 0.0, 1.0)
	_want_scale = 1.0 if not moving else clampf(speed_scale * 1.1, 0.75, 1.4)


func set_idle(clip: String) -> void:
	if idle_anim == clip:
		return
	idle_anim = clip
	if tree == null:
		super.set_idle(clip)
		return
	_set_loco_clips()


func play_action(clip: String, speed := 1.0, blend := 0.08, hold := false) -> void:
	if tree == null:
		super.play_action(clip, speed, blend, hold)
		return
	var m := _map(clip)
	if m[0] == "":
		return
	action = String(m[0])
	hold_last = hold
	_action_node.animation = _with_loop(String(m[0]), Animation.LOOP_NONE)
	_want_scale = speed * float(m[1])
	_playback.travel("Action")


func cancel_action() -> void:
	super.cancel_action()
	if tree != null and _playback != null:
		_want_scale = 1.0
		_playback.travel("Locomotion")


func _process(delta: float) -> void:
	if tree == null:
		return
	# the action is over once the machine is back on its feet (the transition is automatic)
	if action != "" and not hold_last and _playback.get_current_node() == "Locomotion":
		var done := action
		action = ""
		action_finished.emit(done)
	_blend_now = lerpf(_blend_now, _want_blend, 1.0 - exp(-blend_speed * delta))
	_apply_blend(_blend_now)
	tree.set("parameters/scale/scale", _want_scale)


func _apply_blend(v: float) -> void:
	tree.set("parameters/machine/Locomotion/blend_position", v)
