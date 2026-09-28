extends RefCounted
## The control hints under the HUD, built from the live InputMap (so rebinding in the
## settings shows at once) and translation keys — one source for every V3 mode (the
## valley, Son Ocaq, echoes). The protagonist's controller asks for them
## (Protagonist.control_hint); chapter_base puts them on the HUD.

## [action, label key] per line.
const PROTAGONIST := [
	[["move_up", "HINT_MOVE"], ["sprint", "HINT_SPRINT"], ["dash", "HINT_DASH"], ["attack", "HINT_ATTACK"],
		["heavy", "HINT_HEAVY"], ["block", "HINT_BLOCK"], ["ember_power", "HINT_EMBER"]],
	[["lock_on", "HINT_LOCK"], ["interact", "HINT_INTERACT"], ["drink", "HINT_DRINK"], ["map", "HINT_MAP"],
		["journal", "HINT_JOURNAL"], ["pause", "HINT_PAUSE"]],
]
const MOUSE := {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB"}


static func build(lines: Array) -> String:
	var out: Array = []
	for line in lines:
		var parts: Array = []
		for pair in line:
			var keys: Array = Settings.pc_events(pair[0]).map(func(e): return _short(e))
			if pair[0] == "move_up":
				keys = ["WASD"]
			if keys.is_empty():
				continue
			parts.append("%s %s" % ["/".join(PackedStringArray(keys)), TranslationServer.translate(pair[1])])
		out.append(" · ".join(PackedStringArray(parts)))
	return "\n".join(PackedStringArray(out))


## A compact key name: LMB / RMB / MMB for the mouse, the key's own name otherwise.
static func _short(e: InputEvent) -> String:
	if e is InputEventMouseButton and MOUSE.has(e.button_index):
		return MOUSE[e.button_index]
	var label: String = Settings.event_label(e)
	return "Esc" if label == "Escape" else label


static func protagonist() -> String:
	return build(PROTAGONIST)
