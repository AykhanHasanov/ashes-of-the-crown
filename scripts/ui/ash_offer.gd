extends CanvasLayer
## Kül Şahının təklifi: at ≤ 15 health (once per fight) the world slows and greys and
## the Ash Shah whispers "give me a memory... and live". E accepts within 3 seconds:
## full health, but Kül Şahı picks which of Ayxan's own memories burns.

signal resolved(accepted: bool)

const Balance := preload("res://scripts/systems/balance.gd")
const UITheme := preload("res://scripts/ui/ui_theme.gd")

var is_open := false

var _root: Control
var _timer_bar: ColorRect
var _started := 0


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grey := ColorRect.new()
	grey.color = Color(0.12, 0.12, 0.13, 0.62)
	grey.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(grey)
	grey.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_root.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -360
	box.offset_right = 360
	box.offset_top = -80
	var whisper := UITheme.title("\"Bir hatıra ver... ve yaşa.\"", 34, Color(0.95, 0.35, 0.22))
	whisper.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(whisper)
	var hint := UITheme.title("[E] — kabul et   ·   Kül Şahı kendisi seçecek", 20, UITheme.TEXT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.6)
	back.custom_minimum_size = Vector2(360, 8)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	_timer_bar = ColorRect.new()
	_timer_bar.color = Color(0.95, 0.35, 0.22)
	_timer_bar.size = Vector2(360, 8)
	back.add_child(_timer_bar)
	_root.visible = false


func open() -> void:
	is_open = true
	_started = Time.get_ticks_msec()
	_root.visible = true
	Fx.hold_time("offer", Balance.OFFER_TIME_SCALE)
	Audio.play("whisper", -2.0, 0.0)


func _process(_delta: float) -> void:
	if not is_open:
		return
	var elapsed := (Time.get_ticks_msec() - _started) / 1000.0
	_timer_bar.size.x = 360.0 * clampf(1.0 - elapsed / Balance.OFFER_DURATION, 0.0, 1.0)
	if Input.is_action_just_pressed("interact"):
		_finish(true)
	elif elapsed >= Balance.OFFER_DURATION:
		_finish(false)


func _finish(accepted: bool) -> void:
	is_open = false
	_root.visible = false
	Fx.release_time("offer")
	resolved.emit(accepted)
