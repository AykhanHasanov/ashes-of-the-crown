extends CanvasLayer
## Title screen shown over the slowly orbiting courtyard: new game, settings, quit.

signal new_game
signal continue_game

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")

var _root: Control
var _menu: VBoxContainer
var _settings: PanelContainer
var _starting := false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UITheme.build()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Darken the left side so the title reads over the scene
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.85), Color(0, 0, 0, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	shade.texture = tex
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	shade.anchor_right = 0.6
	shade.anchor_bottom = 1.0

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 14)
	_root.add_child(_menu)
	_menu.position = Vector2(90, 150)

	_menu.add_child(UITheme.title("ASHES OF THE CROWN", 60))
	_menu.add_child(UITheme.title("Tacın Külleri", 28, UITheme.EMBER))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	_menu.add_child(gap)
	if GameState.has_save():
		_button("Devam et", _on_continue)
	_button("Yeni oyun", _on_new_game)
	_button("Kür Vadisi (açık dünya, V3 test)", func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/world.tscn"))
	_button("Savaş arenası (V3 test)", func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/arena.tscn"))
	_button("Ayarlar", _on_settings)
	_button("Çıkış", func(): get_tree().quit())

	var footer := UITheme.title("Prototip · Bölüm 1: İlk sabah", 15, UITheme.MUTED)
	_root.add_child(footer)
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_left = 90
	footer.offset_top = -50

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(_on_settings_closed)
	center.add_child(_settings)

	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 1.5)
	_focus_first.call_deferred()


func _button(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(340, 54)
	b.pressed.connect(action)
	b.focus_entered.connect(func(): Audio.play("ui_click", -14.0, 0.05))
	_menu.add_child(b)


func _focus_first() -> void:
	for c in _menu.get_children():
		if c is Button:
			c.grab_focus()
			return


func _on_new_game() -> void:
	_leave(new_game)


func _on_continue() -> void:
	_leave(continue_game)


func _leave(result: Signal) -> void:
	if _starting:
		return
	_starting = true
	Audio.play("ui_select", -6.0, 0.0)
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.8)
	await tw.finished
	result.emit()
	queue_free()


func _on_settings() -> void:
	Audio.play("ui_select", -8.0, 0.0)
	_menu.visible = false
	_settings.open()


func _on_settings_closed() -> void:
	_menu.visible = true
	_focus_first()
