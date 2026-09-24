extends PanelContainer
## Settings screen shared by the main menu and the pause menu.
## Every change is applied and saved immediately.

signal closed

const UITheme := preload("res://scripts/ui/ui_theme.gd")


func _ready() -> void:
	theme = UITheme.build()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	var heading := UITheme.title("PARAMETRLƏR", 30)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)

	_slider(grid, "Musiqi", Settings.music_volume, func(v: float): Settings.music_volume = v)
	_slider(grid, "Səs effektləri", Settings.sfx_volume, func(v: float): Settings.sfx_volume = v)
	_slider(grid, "Ekran silkələnməsi", Settings.screen_shake, func(v: float): Settings.screen_shake = v)
	_choice(grid, "Qrafika", ["Aşağı (noutbuk)", "Yüksək"], 1 if Settings.is_high() else 0,
		func(i: int): Settings.quality = Settings.Quality.HIGH if i == 1 else Settings.Quality.LOW)
	_toggle(grid, "Tam ekran", Settings.fullscreen, func(on: bool): Settings.fullscreen = on)
	_toggle(grid, "Zərbə rəqəmləri", Settings.damage_numbers, func(on: bool): Settings.damage_numbers = on)

	var back := Button.new()
	back.text = "Geri"
	back.custom_minimum_size = Vector2(220, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_close)
	box.add_child(back)


func open() -> void:
	visible = true
	var first := find_children("*", "HSlider", true, false)
	if not first.is_empty():
		first[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	Audio.play("ui_click", -8.0, 0.0)
	visible = false
	closed.emit()


func _commit() -> void:
	Settings.save()
	Settings.apply()


func _label(grid: GridContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	grid.add_child(l)


func _slider(grid: GridContainer, text: String, value: float, setter: Callable) -> void:
	_label(grid, text)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(300, 28)
	s.value_changed.connect(func(v: float):
		setter.call(v)
		_commit()
		Audio.play("ui_click", -10.0, 0.0))
	grid.add_child(s)


func _choice(grid: GridContainer, text: String, items: Array, selected: int, setter: Callable) -> void:
	_label(grid, text)
	var o := OptionButton.new()
	for item in items:
		o.add_item(item)
	o.selected = selected
	o.custom_minimum_size = Vector2(300, 44)
	o.item_selected.connect(func(i: int):
		setter.call(i)
		_commit())
	grid.add_child(o)


func _toggle(grid: GridContainer, text: String, on: bool, setter: Callable) -> void:
	_label(grid, text)
	var c := CheckButton.new()
	c.button_pressed = on
	c.toggled.connect(func(v: bool):
		setter.call(v)
		_commit()
		Audio.play("ui_click", -8.0, 0.0))
	grid.add_child(c)
