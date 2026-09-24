extends CanvasLayer
## Ayxan's journal (Tab): the eight suspects measured against the clues found so
## far, the clues themselves, and his memories — burned ones crossed out.
## Pauses the game while open.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Conspiracy := preload("res://scripts/story/conspiracy.gd")

## Main turns this on once the player has control.
var enabled := false

var _suspects: RichTextLabel
var _clues: RichTextLabel
var _memories: RichTextLabel


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
	var heading := UITheme.title("JURNAL", 32)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	box.add_child(cols)
	_suspects = _column(cols, 470)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 16)
	cols.add_child(right)
	_clues = _column(right, 420)
	_memories = _column(right, 420)

	var hint := UITheme.title("Tab / Esc — bağla", 15, UITheme.MUTED)
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
	var clues: Array = GameState.clues
	var matching := GameState.suspects_matching()

	var s := "[color=#e8b870][font_size=22]ŞÜBHƏLİLƏR[/font_size][/color]\n"
	if clues.is_empty():
		s += "[color=#9a9088]Hələ heç bir iz yoxdur. Kül əks-sədalarını axtar.[/color]\n\n"
	for id in Conspiracy.SUSPECTS:
		var sus: Dictionary = Conspiracy.SUSPECTS[id]
		var hits := 0
		for c in clues:
			if sus["traits"].has(c):
				hits += 1
		var dots := ""
		for i in 3:
			dots += "●" if i < hits else "○"
		if matching.has(id):
			s += "[color=#ffb070]%s[/color]  [color=#9a9088]%s[/color]\n   [color=#ff8a3d]%s[/color]\n" % [sus["name"], sus["role"], dots]
		else:
			s += "[color=#5f5852][s]%s[/s]  %s — izlər uyğun gəlmir[/color]\n" % [sus["name"], sus["role"]]
	if clues.size() >= 3 and matching.size() == 1:
		var who: String = Conspiracy.SUSPECTS[matching[0]]["name"]
		s += "\n[color=#ff6a3d]Bütün izlər bir nəfərə aparır: %s.[/color]" % who
	_suspects.text = s

	var c := "[color=#e8b870][font_size=22]SÜBUTLAR[/font_size][/color]  [color=#9a9088](%d / 3)[/color]\n" % clues.size()
	for t in clues:
		var tr: Dictionary = Conspiracy.TRAITS[t]
		c += "[color=#ffb070]• %s[/color]\n[color=#b8aea4][i]%s[/i][/color]\n" % [tr["title"], tr["echo"]]
	_clues.text = c

	var m := "[color=#e8b870][font_size=22]XATİRƏLƏR[/font_size][/color]\n"
	var next := Memory.next_memory()
	for mem in Memory.MEMORIES:
		if Memory.is_burned(mem["id"]):
			m += "[color=#5f5852][s]%s[/s] — kül[/color]\n" % mem["title"]
		elif not next.is_empty() and next["id"] == mem["id"]:
			m += "[color=#ff8a3d]%s[/color]  [color=#9a9088](köz bunu növbəti alacaq)[/color]\n" % mem["title"]
		else:
			m += "%s\n" % mem["title"]
	_memories.text = m
