extends RefCounted
## The condition language (STORY_SLICE §0): leaves like "flag:x", "known:sona",
## "mem:hearth_lesson=KEPT", joined with "&" (and) and negated with a leading "!".
## "a & !b & c". Empty = true. The leaves themselves are evaluated by the caller
## (WorldState.check_leaf; a conversation adds its own, e.g. "door_mode").
## Use: const Conditions := preload("res://scripts/core/conditions.gd")


static func eval(expr: String, leaf: Callable) -> bool:
	var e := expr.strip_edges()
	if e == "":
		return true
	for part in e.split("&"):
		var p := String(part).strip_edges()
		var negate := false
		while p.begins_with("!"):
			negate = not negate
			p = p.substr(1).strip_edges()
		if bool(leaf.call(p)) == negate:
			return false
	return true
