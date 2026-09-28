extends RefCounted
## Moves the protagonist into an echo scene and back out.
##
## enter()   remembers the scene, position, facing and clock he leaves from, then loads
##           the echo's scene. While `active`, nothing is saved (SaveManager asks).
## resolve() is called by the echo's choice screen: KEEP or BURN is written to WorldState
##           at once (EventBus.memory_kept / memory_burned — other systems react there),
##           the state is set to where he will stand on return, the game autosaves, and
##           the scene he came from is loaded again.
## The scene he returns to calls consume_return() (chapter_base does) to put him back
## exactly where he was, and releases the burned memory's fire.
## Nothing here is saved: an echo is always left before any save can happen.

const EchoRegistry := preload("res://scripts/core/echo_registry.gd")

static var active := false
static var returning := false
static var echo_id: StringName = &""
static var _ctx: Dictionary = {}


## Enters the echo `id` from `from` (the running mode scene). `hour` is the live clock
## (the world's day/night), restored exactly on return. False if the echo is unknown or
## its memory has already been decided.
static func enter(id: StringName, from: Node, player: Node3D, hour: float) -> bool:
	if active or not EchoRegistry.has(id):
		return false
	var def: Resource = EchoRegistry.get_def(id)
	if WorldState.get_memory_state(def.memory_id) != WorldState.MemoryState.UNKNOWN:
		return false
	var facing: Vector3 = player.facing() if player.has_method("facing") else Vector3.FORWARD
	_ctx = {"scene": from.scene_file_path, "position": player.global_position, "facing": facing,
		"hour": hour, "echo": id, "outcome": &""}
	WorldState.set_time_of_day(hour)
	echo_id = id
	active = true
	from.get_tree().paused = false
	from.get_tree().change_scene_to_file(def.scene_path)
	return true


static func definition() -> Resource:
	return EchoRegistry.get_def(echo_id) if EchoRegistry.has(echo_id) else null


## The choice screen's answer: &"keep" or &"burn". Final: written, saved, then back.
static func resolve(choice: StringName, tree: SceneTree) -> void:
	if not active:
		return
	var def: Resource = definition()
	if choice == &"burn":
		WorldState.burn_memory(def.memory_id, &"echo")
	else:
		WorldState.keep_memory(def.memory_id)
	_ctx["outcome"] = choice
	active = false
	# The save must hold the world he returns to, not the echo he leaves
	WorldState.set_player_position(_ctx["position"])
	WorldState.set_time_of_day(float(_ctx["hour"]))
	SaveManager.autosave()
	returning = true
	tree.paused = false
	tree.change_scene_to_file(String(_ctx["scene"]))


## Leaving an echo without choosing (quit to the menu): the memory stays undecided.
static func abandon() -> void:
	active = false
	returning = false
	_ctx = {}


## For the scene being returned to: {position, facing, hour, echo, outcome}, once.
static func consume_return() -> Dictionary:
	if not returning:
		return {}
	returning = false
	var ctx := _ctx
	_ctx = {}
	echo_id = &""
	return ctx
