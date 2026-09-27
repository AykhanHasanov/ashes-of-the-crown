extends CanvasLayer
## Pause menu (Esc / P): resume, settings, back to the title screen, quit.
## Pauses the scene tree while open; runs with PROCESS_MODE_ALWAYS itself.

signal main_menu_requested

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")

## Main turns this off during the title screen and cutscene cards.
var enabled := false

var _root: Control
var _panel: PanelContainer
var _buttons: VBoxContainer
var _settings: PanelContainer


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UITheme.build()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = PanelContainer.new()
	center.add_child(_panel)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	_panel.add_child(_buttons)
	var heading := UITheme.title("DURAKLATILDI", 34)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buttons.add_child(heading)
	_button("Devam et", close)
	_button("Ayarlar", _open_settings)
	_button("Ana menü", func():
		close()
		main_menu_requested.emit())
	_button("Oyundan çık", func(): get_tree().quit())

	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(func():
		_panel.visible = true
		_focus_first())
	center.add_child(_settings)
	visible = false


func open() -> void:
	if not enabled or visible:
		return
	visible = true
	_panel.visible = true
	_settings.visible = false
	get_tree().paused = true
	Audio.play("ui_select", -8.0, 0.0)
	_focus_first()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	Audio.play("ui_click", -8.0, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if visible and _settings.visible:
		return  # the settings panel handles its own Esc
	get_viewport().set_input_as_handled()
	if visible:
		close()
	else:
		open()


func _button(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 52)
	b.pressed.connect(action)
	_buttons.add_child(b)


func _open_settings() -> void:
	_panel.visible = false
	_settings.open()


func _focus_first() -> void:
	for c in _buttons.get_children():
		if c is Button:
			c.grab_focus()
			return
