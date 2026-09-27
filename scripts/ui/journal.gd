extends CanvasLayer
## Ayxan's journal (Tab). For now it holds his memories — burned ones crossed out —
## and the king's words from the ember echoes. Pauses the game while open.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const KingEchoes := preload("res://scripts/story/king_echoes.gd")

## Main turns this on once the player has control.
var enabled := false

var _memories: RichTextLabel
var _echoes: RichTextLabel


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.theme = UITheme.build()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var heading := UITheme.title("GÜNLÜK", 32)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	box.add_child(cols)
	_memories = _column(cols, 420)
	_echoes = _column(cols, 440)

	var hint := UITheme.title("Tab / Esc — kapat", 15, UITheme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(hint)
	visible = false


func open() -> void:
	if not enabled or visible or get_tree().paused:
		return
	_refresh()
	visible = true
	get_tree().paused = true
	Audio.play("ui_select", -8.0, 0.0)


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	Audio.play("ui_click", -8.0, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		get_viewport().set_input_as_handled()
		if visible:
			close()
		else:
			open()
	elif visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _column(parent: Control, width: float) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size = Vector2(width, 0)
	r.add_theme_font_size_override("normal_font_size", 18)
	r.add_theme_color_override("default_color", UITheme.TEXT)
	parent.add_child(r)
	return r


func _refresh() -> void:
	var m := "[color=#e8b870][font_size=22]HATIRALAR[/font_size][/color]\n"
	for mem in Memory.all():
		if WorldState.has_burned(mem.id):
			m += "[color=#5f5852][s]%s[/s] — kül[/color]\n" % tr(mem.display_name_key)
		else:
			m += "%s\n[color=#9a9088][i]%s[/i][/color]\n[color=#c07a50]Yanarsa: %s[/color]\n" % [tr(mem.display_name_key), tr(mem.description_key), tr(mem.cost_key)]
	_memories.text = m

	var e := "[color=#e8b870][font_size=22]YANKILAR[/font_size][/color]\n"
	if WorldState.echoes_seen().is_empty():
		e += "[color=#9a9088]Henüz hiçbir yankı görmedin.[/color]\n"
	for i in WorldState.echoes_seen():
		var echo: Dictionary = KingEchoes.ECHOES[i]
		e += "[color=#ffb070]• %s[/color]\n[color=#b8aea4][i]%s[/i][/color]\n" % [echo["place"], echo["scene"]]
		if WorldState.has_burned(&"father_voice"):
			e += "[color=#7a716a]%s[/color]\n" % KingEchoes.SILENT
		else:
			e += "[color=#e8d8c8]Kral: \"%s\"[/color]\n" % echo["words"]
	_echoes.text = e
