extends PanelContainer
## Settings screen shared by the main menu and the pause menu.
## Every change is applied and saved immediately.

signal closed

const UITheme := preload("res://scripts/ui/ui_theme.gd")

var _main: Control          # sliders and toggles
var _keys: Control          # the "Tuşlar" page
var _key_buttons := {}      # action -> Button
var _waiting := ""          # action waiting for a new input


func _ready() -> void:
	theme = UITheme.build()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	var heading := UITheme.title("AYARLAR", 30)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)
	_main = grid

	_slider(grid, "Müzik", Settings.music_volume, func(v: float): Settings.music_volume = v)
	_slider(grid, "Ses efektleri", Settings.sfx_volume, func(v: float): Settings.sfx_volume = v)
	_slider(grid, "Konuşma sesi", Settings.voice_volume, func(v: float): Settings.voice_volume = v)
	_slider(grid, "Ekran sarsıntısı", Settings.screen_shake, func(v: float): Settings.screen_shake = v)
	_choice(grid, "Qrafika", [tr("QUALITY_LOW"), tr("QUALITY_MEDIUM"), tr("QUALITY_HIGH")], int(Settings.quality),
		func(i: int): Settings.quality = i as Settings.Quality)
	_toggle(grid, tr("SETTINGS_GI"), Settings.global_illumination, func(on: bool): Settings.global_illumination = on)
	_toggle(grid, "Tam ekran", Settings.fullscreen, func(on: bool): Settings.fullscreen = on)
	_toggle(grid, "Hasar sayıları", Settings.damage_numbers, func(on: bool): Settings.damage_numbers = on)
	_toggle(grid, "Altyazılar", Settings.subtitles, func(on: bool): Settings.subtitles = on)
	_label(grid, "Kontroller")
	var keys_button := Button.new()
	keys_button.text = "Tuşlar…"
	keys_button.custom_minimum_size = Vector2(300, 44)
	keys_button.pressed.connect(func(): _show_keys(true))
	grid.add_child(keys_button)
	_keys = _build_keys()
	_keys.visible = false
	box.add_child(_keys)

	var back := Button.new()
	back.text = "Geri"
	back.custom_minimum_size = Vector2(220, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func():
		if _keys.visible:
			_show_keys(false)
		else:
			_close())
	box.add_child(back)


func open() -> void:
	visible = true
	var first := find_children("*", "HSlider", true, false)
	if not first.is_empty():
		first[0].grab_focus()


func _input(event: InputEvent) -> void:
	if not visible or _waiting == "":
		return
	var usable: bool = (event is InputEventKey and event.pressed and not event.echo) 		or (event is InputEventMouseButton and event.pressed)
	if not usable:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
		_waiting = ""  # cancel
	else:
		var ev: InputEvent
		if event is InputEventKey:
			ev = InputEventKey.new()
			ev.physical_keycode = event.physical_keycode
		else:
			ev = InputEventMouseButton.new()
			ev.button_index = event.button_index
		Settings.rebind(_waiting, ev)
		_waiting = ""
		Audio.play("ui_click", -8.0, 0.0)
	_refresh_keys()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _keys.visible:
			_show_keys(false)
		else:
			_close()


# --- Düymələr ----------------------------------------------------------------------------------

func _build_keys() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	var note := Label.new()
	note.text = "Değiştirmek için bir tuşa tıklayın, sonra yeni tuşa basın (Esc — iptal).
Gamepad tuşları ayrı çalışır ve değişmez."
	note.add_theme_font_size_override("font_size", 15)
	note.modulate = Color(1, 1, 1, 0.7)
	page.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for pair in Settings.REBINDABLE:
		var action: String = pair[0]
		var l := Label.new()
		l.text = pair[1]
		l.add_theme_font_size_override("font_size", 18)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(240, 38)
		b.pressed.connect(func():
			_waiting = action
			_refresh_keys())
		grid.add_child(b)
		_key_buttons[action] = b
	var reset := Button.new()
	reset.text = "Varsayılana dön"
	reset.custom_minimum_size = Vector2(260, 42)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(func():
		Settings.reset_bindings()
		Audio.play("ui_click", -8.0, 0.0)
		_refresh_keys())
	page.add_child(reset)
	return page


func _refresh_keys() -> void:
	for action in _key_buttons:
		var b: Button = _key_buttons[action]
		if action == _waiting:
			b.text = "…bir tuşa basın…"
			continue
		var names := []
		for e in Settings.pc_events(action):
			names.append(Settings.event_label(e))
		b.text = " / ".join(names) if not names.is_empty() else "—"


func _show_keys(on: bool) -> void:
	_waiting = ""
	_refresh_keys()
	_main.visible = not on
	_keys.visible = on
	Audio.play("ui_click", -8.0, 0.0)
	if on and not _key_buttons.is_empty():
		_key_buttons[Settings.REBINDABLE[0][0]].grab_focus()


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
