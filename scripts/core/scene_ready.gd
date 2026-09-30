extends RefCounted
## "Is the scene ready to be looked at?" — shared by the first-launch benchmark and the
## loading screen. A mode (a chapter_base scene) is ready when its _ready has run (it sets
## `begun` after _begin()) and, if its level streams places in, nothing is pending.
## Use: const SceneReady := preload("res://scripts/core/scene_ready.gd")


## The same for any scene: one that is not a mode (no `begun`: a test scene, a plain scene)
## is ready as soon as it is there.
static func is_ready_or_plain(scene: Node) -> bool:
	if scene == null or not is_instance_valid(scene):
		return false
	return is_ready(scene) if "begun" in scene else true


static func is_ready(mode: Node) -> bool:
	if mode == null or not is_instance_valid(mode) or mode.get("begun") != true:
		return false
	var level = mode.get("level")
	if level == null or not is_instance_valid(level):
		return true
	var streamer = level.get("streamer")
	if streamer != null and is_instance_valid(streamer) and streamer.has_method("pending_count"):
		return streamer.pending_count() == 0
	return true
