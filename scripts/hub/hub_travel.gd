extends RefCounted
## The road between the valley (world.tscn) and Son Ocaq (son_ocaq.tscn). Static state,
## so it survives the scene change (like EchoDirector).
##
## enter() writes the valley's live clock to WorldState (the hub's clock does not run on
## its own), remembers where the protagonist stood and the scene he came from, and
## loads the hub. leave() loads that scene again (the valley when the game was continued
## inside the hub) and the scene puts him back through consume_return(): where he stood,
## or — when nothing was remembered — the valley gate from data/hub/son_ocaq.json.

const HUB_SCENE := "res://scenes/son_ocaq.tscn"
const VALLEY_SCENE := "res://scenes/world.tscn"

static var returning := false
static var _ctx: Dictionary = {}


static func enter(from: Node, player: Node3D, hour: float) -> void:
	WorldState.set_time_of_day(hour)
	_ctx = {"scene": from.scene_file_path, "position": player.global_position,
		"facing": player.facing() if player.has_method("facing") else Vector3.FORWARD}
	returning = false
	from.get_tree().paused = false
	from.get_tree().change_scene_to_file(HUB_SCENE)


static func leave(tree: SceneTree) -> void:
	var scene := return_scene()
	if scene != _ctx.get("scene", ""):
		_ctx = {"scene": scene}
	returning = true
	tree.paused = false
	tree.change_scene_to_file(scene)


## Where the road out of the hub leads: the scene he came from, else the valley.
static func return_scene() -> String:
	var scene: String = _ctx.get("scene", "")
	return VALLEY_SCENE if scene == "" or scene == HUB_SCENE else scene


## For the scene being returned to: {scene, position?, facing?}, once. {} if not returning.
static func consume_return() -> Dictionary:
	if not returning:
		return {}
	returning = false
	var ctx := _ctx
	_ctx = {}
	return ctx
