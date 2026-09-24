extends CanvasLayer
## In-game HUD: health, the memory list (Yaddaş Yanğını), objectives, Kül Şahı's
## whispers, banners, the boss bar and full-screen title/ending cards.

const VIGNETTE := preload("res://shaders/vignette.gdshader")

const GOLD := Color(0.92, 0.74, 0.42)
const EMBER := Color(1.0, 0.5, 0.18)
const TEXT := Color(0.9, 0.86, 0.8)
const WHISPER := Color(0.95, 0.32, 0.2)

var _root: Control
var _health_fill: ColorRect
var _health_ratio := 1.0
var _shown_ratio := 1.0
var _memory_label: RichTextLabel
var _objective: Label
var _banner: Label
var _whisper: Label
var _prompt: Label
var _info: Label
var _boss_box: Control
var _boss_fill: ColorRect
var _boss_name: Label
var _boss
var _card: ColorRect
var _card_title: Label
var _card_sub: Label
var _card_body: Label
var _vignette_mat: ShaderMaterial
var _damage := 0.0
var _whisper_tween: Tween
var _banner_tween: Tween


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vig := ColorRect.new()
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = VIGNETTE
	vig.material = _vignette_mat
	_root.add_child(vig)
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Health
	var name_label := _label("AYXAN", 18, GOLD)
	_place(name_label, Vector4(0, 0, 0, 0), Vector4(26, 16, 300, 40))
	var back := ColorRect.new()
	back.color = Color(0.05, 0.03, 0.03, 0.85)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(back)
	_place(back, Vector4(0, 0, 0, 0), Vector4(24, 44, 344, 58))
	_health_fill = ColorRect.new()
	_health_fill.color = Color(0.78, 0.16, 0.08)
	_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(_health_fill)
	_health_fill.position = Vector2(2, 2)
	_health_fill.size = Vector2(316, 10)

	# Memories
	_memory_label = RichTextLabel.new()
	_memory_label.bbcode_enabled = true
	_memory_label.scroll_active = false
	_memory_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_memory_label.add_theme_font_size_override("normal_font_size", 17)
	_memory_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_memory_label.add_theme_constant_override("shadow_offset_x", 2)
	_memory_label.add_theme_constant_override("shadow_offset_y", 2)
	_root.add_child(_memory_label)
	_place(_memory_label, Vector4(0, 1, 0, 1), Vector4(24, -236, 460, -16))

	_objective = _label("", 22, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_objective, Vector4(0.5, 0, 0.5, 0), Vector4(-420, 18, 420, 50))
	_banner = _label("", 30, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_banner, Vector4(0.5, 0, 0.5, 0), Vector4(-520, 110, 520, 150))
	_banner.modulate.a = 0.0
	_whisper = _label("", 26, WHISPER, HORIZONTAL_ALIGNMENT_CENTER)
	_whisper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_whisper, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-520, -200, 520, -120))
	_whisper.modulate.a = 0.0
	_prompt = _label("", 22, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_prompt, Vector4(0.5, 1, 0.5, 1), Vector4(-300, -130, 300, -100))

	var hint := _label("LMB / J — qılınc     RMB / Q — Alov Dalğası (xatirə yandırır)\nSpace — Kül addımı     E — danış     F9 — qrafika     F11 — tam ekran", 14, Color(0.7, 0.66, 0.6, 0.85), HORIZONTAL_ALIGNMENT_RIGHT)
	_place(hint, Vector4(1, 1, 1, 1), Vector4(-640, -60, -20, -12))
	_info = _label("", 14, Color(0.7, 0.66, 0.6, 0.85), HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_info, Vector4(1, 0, 1, 0), Vector4(-420, 16, -20, 60))

	# Boss bar
	_boss_box = Control.new()
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_boss_box)
	_place(_boss_box, Vector4(0.5, 0, 0.5, 0), Vector4(-300, 60, 300, 104))
	_boss_name = _label("", 18, WHISPER, HORIZONTAL_ALIGNMENT_CENTER, _boss_box)
	_boss_name.position = Vector2(0, 0)
	_boss_name.size = Vector2(600, 24)
	var boss_back := ColorRect.new()
	boss_back.color = Color(0.05, 0.03, 0.03, 0.85)
	boss_back.position = Vector2(0, 28)
	boss_back.size = Vector2(600, 12)
	_boss_box.add_child(boss_back)
	_boss_fill = ColorRect.new()
	_boss_fill.color = Color(1.0, 0.42, 0.1)
	_boss_fill.position = Vector2(2, 2)
	_boss_fill.size = Vector2(596, 8)
	boss_back.add_child(_boss_fill)
	_boss_box.visible = false

	# Full-screen card
	_card = ColorRect.new()
	_card.color = Color(0, 0, 0, 1)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_card)
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)
	_card_title = _label("", 56, GOLD, HORIZONTAL_ALIGNMENT_CENTER, vbox)
	_card_sub = _label("", 24, EMBER, HORIZONTAL_ALIGNMENT_CENTER, vbox)
	_card_body = _label("", 20, TEXT, HORIZONTAL_ALIGNMENT_CENTER, vbox)
	_card_body.custom_minimum_size = Vector2(900, 0)
	_card_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.visible = false

	Memory.memory_burned.connect(_on_memory_burned)
	Memory.memories_reset.connect(_refresh_memories)
	Fx.notified.connect(show_whisper)
	_refresh_memories()


func _process(delta: float) -> void:
	_shown_ratio = lerpf(_shown_ratio, _health_ratio, 1.0 - exp(-10.0 * delta))
	_health_fill.size.x = 316.0 * _shown_ratio
	_damage = maxf(_damage - delta * 1.8, 0.0)
	_vignette_mat.set_shader_parameter("damage", _damage)
	if _boss != null:
		if is_instance_valid(_boss) and _boss.health > 0.0:
			_boss_fill.size.x = 596.0 * clampf(_boss.health / _boss.max_health, 0.0, 1.0)
		else:
			_boss = null
			_boss_box.visible = false
	var quality := "Yüksək" if Settings.is_high() else "Aşağı"
	_info.text = "Qrafika: %s (F9)" % quality
	if Settings.show_fps:
		_info.text += "\nFPS: %d" % Engine.get_frames_per_second()


func set_health(current: float, maximum: float) -> void:
	var ratio := current / maximum
	if ratio < _health_ratio - 0.001:
		_damage = 1.0
	_health_ratio = ratio


func set_objective(text: String) -> void:
	_objective.text = text


func set_prompt(text: String) -> void:
	_prompt.text = text


func track_boss(boss) -> void:
	_boss = boss
	_boss_name.text = boss.display_name.to_upper()
	_boss_box.visible = true


func banner(text: String) -> void:
	_banner.text = text
	if _banner_tween:
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.35)
	_banner_tween.tween_interval(2.2)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.8)


func show_whisper(text: String) -> void:
	_whisper.text = text
	if _whisper_tween:
		_whisper_tween.kill()
	_whisper.modulate.a = 0.0
	_whisper_tween = create_tween()
	_whisper_tween.tween_property(_whisper, "modulate:a", 1.0, 0.4)
	_whisper_tween.tween_interval(2.6)
	_whisper_tween.tween_property(_whisper, "modulate:a", 0.0, 1.2)


## Black title card that fades out after `hold` seconds. Await it.
func title_card(title: String, sub: String, hold: float) -> void:
	_set_card(title, sub, "", 1.0)
	_card.modulate.a = 1.0
	await get_tree().create_timer(hold).timeout
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 0.0, 1.4)
	await tw.finished
	_card.visible = false


## Card that fades in and stays (defeat / ending).
func show_card(title: String, sub: String, body: String, darkness: float) -> void:
	_set_card(title, sub, body, darkness)
	_card.modulate.a = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, 1.2)


func _set_card(title: String, sub: String, body: String, darkness: float) -> void:
	_card_title.text = title
	_card_sub.text = sub
	_card_body.text = body
	_card_body.visible = body != ""
	_card.color = Color(0, 0, 0, darkness)
	_card.visible = true


func _on_memory_burned(memory: Dictionary) -> void:
	_refresh_memories()
	show_whisper("«%s» yandı.\n%s" % [memory["title"], Memory.whisper()])


func _refresh_memories() -> void:
	var s := "[color=#e8b870]XATİRƏLƏR[/color]   [color=#8a817a]Yaddaş Yanğını[/color]\n"
	var next := Memory.next_memory()
	for m in Memory.MEMORIES:
		var id: String = m["id"]
		if Memory.is_burned(id):
			s += "[color=#5f5852][s]%s[/s]   — kül[/color]\n" % m["title"]
		elif not next.is_empty() and next["id"] == id:
			s += "[color=#ff8a3d]» %s   (növbəti)[/color]\n" % m["title"]
		else:
			s += "[color=#d8cfc4]%s[/color]\n" % m["title"]
	_memory_label.text = s


func _label(text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	(parent if parent != null else _root).add_child(l)
	return l


func _place(c: Control, anchors: Vector4, offsets: Vector4) -> void:
	c.anchor_left = anchors.x
	c.anchor_top = anchors.y
	c.anchor_right = anchors.z
	c.anchor_bottom = anchors.w
	c.offset_left = offsets.x
	c.offset_top = offsets.y
	c.offset_right = offsets.z
	c.offset_bottom = offsets.w
