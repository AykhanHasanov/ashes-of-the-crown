extends CanvasLayer
## F10 debug panel (spec V3 §15). Scenes register sections and buttons:
##   debug.section("Düşmən")
##   debug.button("Kurt", func(): ...)
## It does not pause the game, so effects can be watched live.

const UITheme := preload("res://scripts/ui/ui_theme.gd")

var _panel: PanelContainer
var _box: VBoxContainer
var _row: HFlowContainer


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.theme = UITheme.build()
	add_child(_panel)
	_panel.position = Vector2(16, 130)
	_panel.custom_minimum_size = Vector2(430, 0)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 520)
	_panel.add_child(scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_box)
	var head := UITheme.title("DEBUG (F10)", 20)
	_box.add_child(head)
	visible = false


func section(title: String) -> void:
	var l := UITheme.title(title, 16, UITheme.EMBER)
	_box.add_child(l)
	_row = HFlowContainer.new()
	_row.add_theme_constant_override("h_separation", 6)
	_row.add_theme_constant_override("v_separation", 6)
	_box.add_child(_row)


func button(label: String, action: Callable) -> void:
	if _row == null:
		section("Genel")
	var b := Button.new()
	b.text = label
	b.add_theme_font_size_override("font_size", 14)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	_row.add_child(b)


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_menu"):
		visible = not visible
		get_viewport().set_input_as_handled()
