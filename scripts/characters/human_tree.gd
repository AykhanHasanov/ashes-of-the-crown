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

## The Mixamo set (tools/retarget_mixamo.gd bakes it): the game's clip names on the left, the
## retargeted clips on the right. THIS TABLE IS THE SWAP POINT — the tree, its states and its
## transitions never change. Anything not listed falls back to the Quaternius library.
const MIXAMO_LIB := "res://assets/anims/mixamo_library.res"
const MIXAMO := {
	"Idle": "idle", "Idle_B": "idle", "Unarmed_Idle": "idle",
	"Idle_Combat": "idle_combat", "1H_Melee_Idle": "idle_combat", "Idle_Shield": "idle_combat",
	"Walking_A": "walk", "Walking_B": "walk", "Walking_C": "walk", "Walk": "walk",
	"Walking_Hurt": "walk_hurt", "Walking_Sad": "walk_sad",
	"Idle_Upright": "idle_upright", "Idle_Waiting": "idle_waiting",
	"Running_A": "run", "Running_B": "run", "Running_C": "run", "Jog_Fwd": "run", "Sprint": "run",
	"Jump_Start": "jump", "Jump": "jump", "Jump_Full_Short": "jump", "Jump_Land": "jump",
	"Dodge_Forward": "dodge", "Dodge_Backward": "dodge", "Dodge_Left": "dodge", "Dodge_Right": "dodge",
	"Dodge_Roll": "dodge", "Roll": "dodge",
	"Block_Attack": "block", "Block_Hit": "block", "Blocking": "block", "1H_Melee_Block": "block",
	# the two light blows and the heavy thrust, cut out of the combo and the stab take
	"1H_Melee_Attack_Slice_Diagonal": "light_1", "1H_Melee_Attack_Slice_Horizontal": "light_2",
	"1H_Melee_Attack_Chop": "heavy", "1H_Melee_Attack_Stab": "attack_stab",
	"2H_Melee_Attack_Slice": "light_2", "2H_Melee_Attack_Chop": "heavy", "2H_Melee_Attack_Spin": "heavy",
	"2H_Melee_Idle": "charge_hold",   # the cocked pose a heavy blow is held in
	"Unarmed_Melee_Attack_Punch_A": "light_1", "Unarmed_Melee_Attack_Punch_B": "light_2", "Punch": "punch",
	"Hit_A": "hit_a", "Hit_B": "hit_b", "Hit_Knockback": "hit_b",
	"Death_A": "death", "Death01": "death", "Death": "death",
	# down but not fallen: the surrender pose, and getting up out of it
	"Sit_Floor_Down": "kneel", "Sit_Floor_Idle": "kneel", "Kneel": "kneel",
	"Lie_Down": "kneel", "Lie_StandUp": "idle",
}
## Rüfət's limp and anything else that wants its own walk ("Walking_Hurt" is the Injured Walk).
var walk_clip := "Walking_A"
var use_mixamo := true

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
var _phase := -1.0            # a scattered start, applied on the first frame in the tree


static func build_tree(spec: Dictionary) -> Node3D:
	var h = load("res://scripts/characters/human_tree.gd").new()
	h.setup_human(spec)
	h.walk_clip = spec.get("walk", h.walk_clip)   # a body's own walk (Rüfət's limp) goes in before the tree is wired
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
	_loco.sync = true    # walk and run keep the same phase while they blend: no double steps
	_add_mixamo_library()
	_set_loco_clips()
	_action_node = AnimationNodeAnimation.new()
	_action_node.animation = _loop_clip(idle_anim)
	_machine = AnimationNodeStateMachine.new()
	_machine.add_node("Locomotion", _loco, Vector2(0, 0))
	_machine.add_node("Action", _action_node, Vector2(300, 0))
	# A state machine starts on its Start node and stays there until something travels, which
	# for a body nobody drives (an idling villager, a Küllü standing in the ash) means the
	# skeleton never leaves its rest pose. This transition walks it straight into Locomotion.
	_machine.add_transition("Start", "Locomotion", _transition(0.0, AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE, true))
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
	tree.anim_player = tree.get_path_to(anim)
	tree.active = true
	_playback = tree.get("parameters/machine/playback")
	_apply_blend(0.0)


## A body built before it is put in the scene (every NPC: Human.build runs first, add_child
## second) has its AnimationTree wired up while it is outside the SceneTree, and an inactive
## tree leaves the skeleton sitting in its rest pose. Wiring it again on the way in fixes that
## and costs nothing for a body that was already inside.
func _ready() -> void:
	if tree == null:
		return
	tree.anim_player = tree.get_path_to(anim)
	tree.active = true
	_playback = tree.get("parameters/machine/playback")
	_playback.travel("Locomotion")
	_apply_blend(_blend_now)


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
	_add_point(walk_clip, WALK_AT)
	_add_point(move_anim, 1.0)


## The retargeted clips live in their own library, beside the Quaternius one.
func _add_mixamo_library() -> void:
	if anim == null or anim.has_animation_library("mx"):
		return
	var lib = load(MIXAMO_LIB) if ResourceLoader.exists(MIXAMO_LIB) else null
	if lib != null:
		anim.add_animation_library("mx", lib)


## A Mixamo clip when the set has one, else whatever the Quaternius library offers.
func _map(clip: String) -> Array:
	if use_mixamo and MIXAMO.has(clip):
		var name: String = "mx/" + String(MIXAMO[clip])
		if anim != null and anim.has_animation(name):
			return [name, 1.0, 1.0]
	return super._map(clip)


func _add_point(clip: String, at: float) -> void:
	var name := _loop_clip(clip)
	if name == "":
		return
	var node := AnimationNodeAnimation.new()
	node.animation = name
	_loco.add_blend_point(node, at, -1, clip)


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
	_want_scale = anim_rate * (1.0 if not moving else clampf(speed_scale * 1.1, 0.75, 1.4))


## For a controller that knows its real ground speed (the iso game): where on the idle → walk
## → run line the body is, and how fast its clip plays, set directly. The caller matches
## `rate` to the clip's own ground speed so the feet do not slide.
func set_gait(blend: float, rate: float) -> void:
	if tree == null:
		set_locomotion(blend > 0.01, rate)
		return
	_want_blend = clampf(blend, 0.0, 1.0)
	_want_scale = rate * anim_rate


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
	_want_scale = speed * float(m[1]) * anim_rate
	_playback.travel("Action")


## The tree owns the clock here, so a phase offset is a seek on the tree, not on the player.
func seek_random(fraction: float) -> void:
	if tree == null or not is_inside_tree():
		_phase = fraction          # the tree can only be advanced once it is running
		return
	tree.advance(fraction * 2.5)


func cancel_action() -> void:
	super.cancel_action()
	if tree != null and _playback != null:
		_want_scale = 1.0
		_playback.travel("Locomotion")


func _process(delta: float) -> void:
	if tree == null:
		return
	if _phase >= 0.0:
		tree.advance(_phase * 2.5)
		_phase = -1.0
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
