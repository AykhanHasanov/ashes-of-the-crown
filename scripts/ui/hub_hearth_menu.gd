extends CanvasLayer
## Son Ocaq's hearth: time moves only here (or by the story). Wait until night, wait until
## morning, or stand up. The hub mode does the waiting (and the autosave).

signal wait_requested(hour: float)
signal closed

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const NIGHT_HOUR := 21.0
const MORNING_HOUR := 7.0

var is_open := false
var _panel: PanelContainer
var _box: VBoxContainer


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.build()
	add_child(root)
	_panel = PanelContainer.new()
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = 60
	_panel.offset_top = -120
	_panel.offset_right = 420
	_panel.offset_bottom = 120
	root.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	_panel.add_child(_box)
	_box.add_child(UITheme.title(tr("HUB_TITLE"), 26))
	_button(tr("HUB_REST_NIGHT"), func(): _wait(NIGHT_HOUR))
	_button(tr("HUB_REST_MORNING"), func(): _wait(MORNING_HOUR))
	_button(tr("HUB_CLOSE"), close)
	_panel.visible = false


func open() -> void:
	is_open = true
	_panel.visible = true
	get_tree().paused = true
	(_box.get_child(1) as Button).grab_focus()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_panel.visible = false
	get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _wait(hour: float) -> void:
	close()
	wait_requested.emit(hour)


func _button(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 44)
	b.pressed.connect(action)
	_box.add_child(b)
