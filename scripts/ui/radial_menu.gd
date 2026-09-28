extends CanvasLayer
## Alov Dalğası memory wheel. While Q / right mouse is held the world slows down and
## The protagonist's unburned memories (large) and gifted memories (small) circle the screen.
## Point with the mouse or WASD; releasing burns the highlighted one, releasing on
## nothing cancels. Also hosts the one-time "are you sure" confirmation.

signal confirmed(ok: bool)

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const RADIUS := 190.0
const DEADZONE := 40.0

var is_open := false
var selected := ""

var _items: Array = []     # [{id, title, cost, gifted}]
var _canvas: Control
var _confirm: PanelContainer
var _open_time := 0


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_wheel)
	_canvas.visible = false
	_build_confirm()


func open() -> void:
	_items.clear()
	for m in Memory.unburned():
		_items.append({"id": m.id, "title": tr(m.display_name_key), "cost": tr(m.cost_key), "gifted": false})
	for g in Memory.gifted:
		_items.append({"id": g["id"], "title": g["title"], "cost": g.get("cost", ""), "gifted": true})
	is_open = true
	selected = ""
	_open_time = Time.get_ticks_msec()
	_canvas.visible = true
	Audio.play("ui_select", -8.0, 0.0)


## Closes the wheel and returns the chosen memory id ("" = cancelled).
func close() -> String:
	is_open = false
	_canvas.visible = false
	return selected


func _process(_delta: float) -> void:
	if not is_open:
		return
	var center := _canvas.size * 0.5
	var aim := Vector2.ZERO
	var mouse := _canvas.get_local_mouse_position() - center
	if mouse.length() > DEADZONE:
		aim = mouse
	var keys := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if keys.length() > 0.3:
		aim = keys
	var before := selected
	if aim != Vector2.ZERO and not _items.is_empty():
		var best := -2.0
		for i in _items.size():
			var d := _slot(i).normalized().dot(aim.normalized())
			if d > best:
				best = d
				selected = _items[i]["id"]
	if selected != before and selected != "":
		Audio.play("ui_click", -12.0, 0.05)
	_canvas.queue_redraw()


func _slot(i: int) -> Vector2:
	var a := -PI * 0.5 + TAU * i / maxf(_items.size(), 1)
	return Vector2(cos(a), sin(a)) * RADIUS


func _draw_wheel() -> void:
	var center := _canvas.size * 0.5
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), Color(0.05, 0.02, 0.01, 0.55))
	_canvas.draw_arc(center, RADIUS, 0, TAU, 96, Color(1.0, 0.5, 0.2, 0.25), 2.0)
	var font := ThemeDB.fallback_font
	var pulse := 0.5 + 0.5 * sin((Time.get_ticks_msec() - _open_time) * 0.008)
	for i in _items.size():
		var it: Dictionary = _items[i]
		var pos := center + _slot(i)
		var r := 20.0 if it["gifted"] else 34.0
		var on: bool = it["id"] == selected
		if on:
			_canvas.draw_circle(pos, r + 10.0 + pulse * 4.0, Color(1.0, 0.45, 0.1, 0.35))
		_canvas.draw_circle(pos, r, Color(1.0, 0.55, 0.18) if on else Color(0.55, 0.22, 0.08))
		_canvas.draw_arc(pos, r, 0, TAU, 40, Color(1.0, 0.85, 0.5, 0.9 if on else 0.4), 2.0)
		var size := 17 if not it["gifted"] else 14
		var w := font.get_string_size(it["title"], HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
		_canvas.draw_string_outline(font, pos + Vector2(-w * 0.5, r + 22.0), it["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, 0.9))
		_canvas.draw_string(font, pos + Vector2(-w * 0.5, r + 22.0), it["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, size, UITheme.GOLD if on else UITheme.TEXT)
	# Centre: what the chosen memory will cost
	var head := "Bir hatıra seç" if selected == "" else "Yak: " + _title_of(selected)
	var sub := "Bırakırsan — iptal" if selected == "" else _cost_of(selected)
	_centered(font, center + Vector2(0, -6), head, 24, UITheme.GOLD)
	_centered(font, center + Vector2(0, 24), sub, 17, UITheme.MUTED)


func _centered(font: Font, pos: Vector2, text: String, size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	_canvas.draw_string_outline(font, pos + Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, 0.9))
	_canvas.draw_string(font, pos + Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _title_of(id: String) -> String:
	for it in _items:
		if it["id"] == id:
			return it["title"]
	return ""


func _cost_of(id: String) -> String:
	for it in _items:
		if it["id"] == id:
			return it["cost"]
	return ""


# --- One-time confirmation ----------------------------------------------------------------

## Pauses the game and asks before the first memory ever burns. Await `confirmed`.
func ask_confirm() -> void:
	get_tree().paused = true
	_confirm.visible = true
	_confirm.find_children("*", "Button", true, false)[1].grab_focus()


func _build_confirm() -> void:
	var root := Control.new()
	root.theme = UITheme.build()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm = PanelContainer.new()
	center.add_child(_confirm)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_confirm.add_child(box)
	var text := UITheme.title("Bu güç seçtiğin hatırayı sonsuza dek yakacak.\nDevam mı?", 24)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	for pair in [["Evet, yak", true], ["Yox", false]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(180, 48)
		var ok: bool = pair[1]
		b.pressed.connect(func():
			_confirm.visible = false
			get_tree().paused = false
			confirmed.emit(ok))
		row.add_child(b)
	_confirm.visible = false
