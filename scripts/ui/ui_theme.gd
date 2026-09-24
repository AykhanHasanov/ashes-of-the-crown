extends RefCounted
## Shared look for menus: dark ash panels, gold borders, ember highlights.

const GOLD := Color(0.92, 0.74, 0.42)
const EMBER := Color(1.0, 0.55, 0.22)
const TEXT := Color(0.92, 0.88, 0.82)
const MUTED := Color(0.62, 0.57, 0.52)

static var _theme: Theme


static func build() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 20

	t.set_stylebox("normal", "Button", _box(Color(0.07, 0.045, 0.035, 0.92), Color(0.42, 0.3, 0.15), 1))
	t.set_stylebox("hover", "Button", _box(Color(0.17, 0.07, 0.03, 0.95), EMBER, 2))
	t.set_stylebox("pressed", "Button", _box(Color(0.26, 0.1, 0.04, 0.95), EMBER, 2))
	t.set_stylebox("focus", "Button", _box(Color(0.17, 0.07, 0.03, 0.0), GOLD, 2))
	t.set_stylebox("disabled", "Button", _box(Color(0.05, 0.04, 0.035, 0.8), Color(0.25, 0.2, 0.15), 1))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", EMBER)
	t.set_font_size("font_size", "Button", 22)
	for state in ["normal", "hover", "pressed", "focus"]:
		t.set_stylebox(state, "OptionButton", t.get_stylebox(state, "Button"))
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_color("font_hover_color", "OptionButton", GOLD)

	var panel := _box(Color(0.04, 0.03, 0.025, 0.95), Color(0.62, 0.45, 0.22, 0.9), 2, 6)
	panel.set_content_margin_all(30)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.8))
	t.set_constant("shadow_offset_x", "Label", 2)
	t.set_constant("shadow_offset_y", "Label", 2)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.12, 0.08, 0.06)
	track.set_corner_radius_all(3)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := track.duplicate()
	fill.bg_color = Color(0.78, 0.36, 0.1)
	var fill_hi := track.duplicate()
	fill_hi.bg_color = EMBER
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill_hi)
	t.set_color("font_color", "CheckButton", TEXT)
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		t.set_stylebox(state, "CheckButton", StyleBoxEmpty.new())
	_theme = t
	return t


static func _box(bg: Color, border: Color, width: int, radius := 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func title(text: String, size: int, color := GOLD) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
