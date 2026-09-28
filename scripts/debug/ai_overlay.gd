extends Label
## F4 AI overlay (spec §15): the protagonist's defensive habits over the last minute and, for the
## nearest enemies, state, perception, AI LOD, the chosen action, top utility scores,
## token use and the adaptive counter weights of elites and bosses.

const STATES := ["doğuyor", "hareket", "hazırlık", "vuruş", "toparlanma", "blok", "yara", "sersem", "kırık", "infaz", "ölü", "kaçış", "teslim", "kaçıyor", "uyarı"]
const LODS := ["tam", "orta", "donmuş"]

var player: Node3D


func _ready() -> void:
	add_theme_font_size_override("font_size", 13)
	add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	add_theme_constant_override("shadow_offset_x", 1)
	add_theme_constant_override("shadow_offset_y", 1)
	position = Vector2(20, 130)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_ai"):
		visible = not visible


func _process(_delta: float) -> void:
	if not visible or not is_instance_valid(player):
		return
	var lines: PackedStringArray = ["AI (F4)"]
	if player.get("habits") != null:
		var c: Dictionary = player.habits.counts()
		var w: Dictionary = player.habits.weights()
		lines.append("Kahramanın alışkanlıkları (60 sn):  kaçış %d (%.0f%%)  ·  blok %d (%.0f%%)  ·  savuşturma %d (%.0f%%)  ·  mesafe %d (%.0f%%)" % [
			c["dodge"], w["dodge"] * 100.0, c["block"], w["block"] * 100.0, c["parry"], w["parry"] * 100.0, c["distance"], w["distance"] * 100.0])
		lines.append("tokenler: %d / %d" % [player.get("_tokens_used"), player.get("token_budget")])
	var foes: Array = []
	for f in get_tree().get_nodes_in_group("combatants"):
		if f.has_method("xp_value") and not f.dead:
			foes.append(f)
	foes.sort_custom(func(a, b): return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
	for f in foes.slice(0, 6):
		var d: float = f.global_position.distance_to(player.global_position)
		var per := "hep savaşta"
		if f.perception != null:
			per = "%s %.0f%%%s" % [f.perception.NAMES[f.perception.state], f.perception.awareness * 100.0, " (görüyor)" if f.perception.sees else (" (duyuyor)" if f.perception.hears else "")]
		lines.append("")
		lines.append("%s  [%s, L%d]  %.0f m  —  %s  ·  %s  ·  LOD %s%s" % [
			f.display_name, f.tier, f.level, d, STATES[f._state], per, LODS[f.lod], "  ·  TOKEN" if f._has_token else ""])
		var scores: Array = []
		for k in f.last_scores:
			scores.append([k, float(f.last_scores[k])])
		scores.sort_custom(func(a, b): return a[1] > b[1])
		var top: PackedStringArray = []
		for s in scores.slice(0, 4):
			top.append("%s %.2f" % [s[0], s[1]])
		lines.append("    eylem: %s   |   puanlar: %s" % [f._action, ", ".join(top)])
		if not f.adaptive_weights.is_empty():
			var aw: PackedStringArray = []
			for tag in f.adaptive_weights:
				aw.append("%s ×%.2f" % [tag, f.adaptive_weights[tag]])
			lines.append("    uyarlanan cevap: " + ", ".join(aw))
		if not f.affixes.is_empty():
			lines.append("    özellikler: " + ", ".join(f.affixes) + "   ·   XP %.0f" % f.xp_value(int(player.get("level"))))
	text = "\n".join(lines)
