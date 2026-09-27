extends CanvasLayer
## Menu shown while sitting at a lit hearth: rest (heal, refill flasks, enemies return,
## save), travel to another lit hearth, open the map, or stand up.

signal rest_requested
signal travel_requested(poi_id: String)
signal map_requested
signal closed

const UITheme := preload("res://scripts/ui/ui_theme.gd")

var is_open := false
var _panel: PanelContainer
var _box: VBoxContainer
var _title: Label
var _sub: Label


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.build()
	add_child(root)
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = 60
	_panel.offset_top = -210
	_panel.offset_right = 420
	_panel.offset_bottom = 210
	root.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	_panel.add_child(_box)
	_panel.visible = false


func open(hearth: Dictionary, others: Array) -> void:
	for c in _box.get_children():
		c.queue_free()
	_title = UITheme.title(hearth["name"], 28)
	_box.add_child(_title)
	_sub = Label.new()
	_sub.text = "Ocağın sıcaklığı. Kül burada uyuyor."
	_sub.add_theme_color_override("font_color", UITheme.MUTED)
	_sub.add_theme_font_size_override("font_size", 16)
	_box.add_child(_sub)
	var first := _button("Dinlen", func():
		close()
		rest_requested.emit())
	if not others.is_empty():
		var travel_label := Label.new()
		travel_label.text = "Yolculuk:"
		travel_label.add_theme_font_size_override("font_size", 18)
		travel_label.add_theme_color_override("font_color", UITheme.GOLD)
		_box.add_child(travel_label)
		for o in others:
			var id: String = o["id"]
			_button("  → " + o["name"], func():
				close()
				travel_requested.emit(id))
	_button("Harita", func():
		close()
		map_requested.emit())
	_button("Kalk", close)
	is_open = true
	_panel.visible = true
	get_tree().paused = true
	first.grab_focus()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_panel.visible = false
	get_tree().paused = false
	closed.emit()


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 46)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func():
		Audio.play("ui_click", -8.0, 0.0)
		action.call())
	_box.add_child(b)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
