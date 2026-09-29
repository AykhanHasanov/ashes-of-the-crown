extends CanvasLayer
## In-game HUD: health, the memory list (Yaddaş Yanğını), objectives, Kül Şahı's
## whispers, banners, the boss bar and full-screen title/ending cards.

const Names := preload("res://scripts/core/names.gd")
const VIGNETTE := preload("res://shaders/vignette.gdshader")

const GOLD := Color(0.92, 0.74, 0.42)
const EMBER := Color(1.0, 0.5, 0.18)
const TEXT := Color(0.9, 0.86, 0.8)
const WHISPER := Color(0.95, 0.32, 0.2)

var _root: Control
var _name_label: Label
const NAME_FADE := 2.0        # his name fading in when he learns it
var _health_fill: ColorRect
var _ember_fill: ColorRect
var _ember_ratio := 0.0
var _health_ratio := 1.0
var _shown_ratio := 1.0
var _embers: Control
var _marker: Control
var _marker_target: Variant = null  # Vector3 world position or null
var _marker_camera: Camera3D
var _ember_pulse := 0.0
var _ember_back: ColorRect
var _stamina_back: ColorRect
var _stamina_fill: ColorRect
var _stamina_ratio := 1.0
var _flasks: Label
var _weapon: Label
var _lock = null
var _hint: Label
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
	_name_label = _label(Names.protagonist_label().to_upper(), 18, GOLD)
	_place(_name_label, Vector4(0, 0, 0, 0), Vector4(26, 16, 300, 40))
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

	# Memories: six ember diamonds under the health bar (names live in the journal)
	_embers = Control.new()
	_embers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_embers)
	_place(_embers, Vector4(0, 0, 0, 0), Vector4(24, 76, 260, 118))

	# Ember meter (Köz Zərbəsi fuel) right under the health bar
	var ember_back := ColorRect.new()
	_ember_back = ember_back
	ember_back.color = Color(0.05, 0.03, 0.03, 0.85)
	ember_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(ember_back)
	_place(ember_back, Vector4(0, 0, 0, 0), Vector4(24, 61, 264, 69))
	_ember_fill = ColorRect.new()
	_ember_fill.color = Color(1.0, 0.55, 0.15)
	_ember_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ember_back.add_child(_ember_fill)
	_ember_fill.position = Vector2(1, 1)
	_ember_fill.size = Vector2(0, 6)
	var cost_tick := ColorRect.new()
	cost_tick.color = Color(1, 1, 1, 0.5)
	cost_tick.position = Vector2(120, 0)
	cost_tick.size = Vector2(1, 8)
	ember_back.add_child(cost_tick)
	_embers.draw.connect(_draw_embers)

	# V3 only: stamina bar (shown once a stamina-using body reports in), flask count, weapon
	_stamina_back = ColorRect.new()
	_stamina_back.color = Color(0.05, 0.03, 0.03, 0.85)
	_stamina_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stamina_back)
	_place(_stamina_back, Vector4(0, 0, 0, 0), Vector4(24, 61, 304, 69))
	_stamina_fill = ColorRect.new()
	_stamina_fill.color = Color(0.72, 0.78, 0.35)
	_stamina_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_back.add_child(_stamina_fill)
	_stamina_fill.position = Vector2(1, 1)
	_stamina_fill.size = Vector2(278, 6)
	_stamina_back.visible = false
	_flasks = _label("", 20, Color(1.0, 0.55, 0.45))
	_place(_flasks, Vector4(0, 1, 0, 1), Vector4(24, -64, 400, -36))
	_weapon = _label("", 17, GOLD)
	_place(_weapon, Vector4(0, 1, 0, 1), Vector4(24, -92, 400, -66))

	# Objective marker: hovers over the target, or clings to the screen edge pointing at it
	_marker = Control.new()
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_marker)
	_marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marker.draw.connect(_draw_marker)

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

	_hint = _label("LMB / J — kılıç     RMB / Q — Köz Darbesi  ·  basılı tut — Alev Dalgası\nSpace — Kül adımı     E — konuş     Tab — günlük     Esc — duraklat", 14, Color(0.7, 0.66, 0.6, 0.85), HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_hint, Vector4(0.25, 1, 1, 1), Vector4(0, -60, -20, -12))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info = _label("", 14, Color(0.7, 0.66, 0.6, 0.85), HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_info, Vector4(1, 0, 1, 0), Vector4(-420, 16, -20, 60))

	# Boss bar
	_boss_box = Control.new()
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_boss_box)
	_place(_boss_box, Vector4(0.5, 1, 0.5, 1), Vector4(-300, -150, 300, -106))   # bottom (spec §4.5)
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

	EventBus.memory_burned.connect(_on_memory_burned)
	EventBus.state_replaced.connect(_refresh_memories)
	EventBus.flag_changed.connect(_on_flag_changed)
	Fx.notified.connect(show_whisper)
	_refresh_memories()


func _process(delta: float) -> void:
	_shown_ratio = lerpf(_shown_ratio, _health_ratio, 1.0 - exp(-10.0 * delta))
	_health_fill.size.x = 316.0 * _shown_ratio
	_ember_fill.size.x = lerpf(_ember_fill.size.x, 238.0 * _ember_ratio, 1.0 - exp(-12.0 * delta))
	_ember_fill.color = Color(1.0, 0.75, 0.3) if _ember_ratio >= 0.5 else Color(0.7, 0.3, 0.1)
	_damage = maxf(_damage - delta * 1.8, 0.0)
	_ember_pulse += delta
	_embers.queue_redraw()
	_marker.queue_redraw()
	if _stamina_back.visible:
		_stamina_fill.size.x = lerpf(_stamina_fill.size.x, 278.0 * _stamina_ratio, 1.0 - exp(-14.0 * delta))
		_stamina_fill.color = Color(0.72, 0.78, 0.35) if _stamina_ratio > 0.25 else Color(0.85, 0.35, 0.2)
	_vignette_mat.set_shader_parameter("damage", _damage)
	if _boss != null:
		if is_instance_valid(_boss) and _boss.health > 0.0:
			_boss_fill.size.x = 596.0 * clampf(_boss.health / _boss.max_health, 0.0, 1.0)
		else:
			_boss = null
			_boss_box.visible = false
	var quality := "Yüksek" if Settings.is_high() else "Düşük"
	_info.text = "Grafik: %s (F9)" % quality
	if Settings.show_fps:
		_info.text += "\nFPS: %d" % Engine.get_frames_per_second()


func set_stamina(current: float, maximum: float) -> void:
	if not _stamina_back.visible:
		# Make room: stamina sits under health, ember and memories move down
		_stamina_back.visible = true
		_ember_back.offset_top += 11
		_ember_back.offset_bottom += 11
		_embers.offset_top += 11
		_embers.offset_bottom += 11
	_stamina_ratio = current / maximum


func set_flasks(current: int, maximum: int) -> void:
	_flasks.text = "Nar Şerbeti  %d / %d   [R]" % [current, maximum]


func set_hint(text: String) -> void:
	_hint.text = text


func set_weapon(weapon_name: String) -> void:
	_weapon.text = weapon_name


func set_lock(target) -> void:
	_lock = target


func set_ember(current: float, maximum: float) -> void:
	_ember_ratio = current / maximum


func set_health(current: float, maximum: float) -> void:
	var ratio := current / maximum
	if ratio < _health_ratio - 0.001:
		_damage = 1.0
	_health_ratio = ratio


func set_objective(text: String) -> void:
	_objective.text = text


## Points the objective marker at `target` (Vector3) seen through `camera`; null hides it.
func set_marker(target: Variant, camera: Camera3D = null) -> void:
	_marker_target = target
	if camera:
		_marker_camera = camera
	_marker.queue_redraw()


func _draw_marker() -> void:
	_draw_lock()
	if _marker_target == null or _marker_camera == null:
		return
	var world: Vector3 = _marker_target + Vector3(0, 2.6, 0)
	var size := _marker.size
	var behind := _marker_camera.is_position_behind(world)
	var p := _marker_camera.unproject_position(world)
	var margin := 48.0
	var inside := not behind and p.x > margin and p.x < size.x - margin and p.y > margin and p.y < size.y - margin
	var col := Color(1.0, 0.6, 0.2, 0.55 + 0.35 * sin(_ember_pulse * 3.0))
	if inside:
		# Small downward chevron above the target
		var bob := sin(_ember_pulse * 3.0) * 4.0
		var tip := p + Vector2(0, bob)
		_marker.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-10, -14), tip + Vector2(10, -14)]), col)
		return
	var center := size * 0.5
	var dir := (p - center).normalized()
	if behind:
		dir = -dir
	var half := center - Vector2(margin, margin)
	var t := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	var pos := center + dir * t
	var side := Vector2(-dir.y, dir.x)
	_marker.draw_colored_polygon(PackedVector2Array([pos + dir * 16.0, pos - dir * 6.0 + side * 11.0, pos - dir * 6.0 - side * 11.0]), col)


## Lock-on reticle on the target's chest.
func _draw_lock() -> void:
	if _lock == null or not is_instance_valid(_lock) or _lock.dead or _marker_camera == null:
		return
	var p3: Vector3 = _lock.global_position + Vector3(0, 1.1, 0)
	if _marker_camera.is_position_behind(p3):
		return
	var p := _marker_camera.unproject_position(p3)
	var r := 13.0 + sin(_ember_pulse * 5.0) * 1.5
	_marker.draw_arc(p, r, 0, TAU, 32, Color(1.0, 0.85, 0.55, 0.9), 2.0)
	for i in 4:
		var a := i * PI * 0.5 + PI * 0.25
		var d := Vector2(cos(a), sin(a))
		_marker.draw_line(p + d * (r + 3.0), p + d * (r + 9.0), Color(1.0, 0.6, 0.25, 0.95), 2.0)


func set_prompt(text: String) -> void:
	_prompt.text = text


func track_boss(boss) -> void:
	_boss = boss
	_boss_name.text = boss.display_name.to_upper()
	_boss_box.visible = true


## While a conversation is open nothing else speaks over it: title cards, banners, burn
## notices and whispers wait in a queue and come one at a time after it closes.
var dialogue                      # DialogueUI (set by the mode)
var _queue: Array = []            # [method name, args]
var _flushing := false


func _busy() -> bool:
	return dialogue != null and is_instance_valid(dialogue) and dialogue.is_active()


func queued() -> Array:
	return _queue.map(func(q): return q[0])


## A conversation begins: whatever is on screen (a title card still fading, a banner, a
## whisper) gives way at once.
func hide_transients() -> void:
	_card.visible = false
	for n in [_banner, _whisper]:
		n.modulate.a = 0.0
	for t in [_banner_tween, _whisper_tween]:
		if t:
			t.kill()


## After the conversation: the waiting messages, one at a time.
func flush_queue() -> void:
	if _flushing:
		return
	_flushing = true
	while not _queue.is_empty() and not _busy():
		var item: Array = _queue.pop_front()
		callv(item[0], item[1])
		var wait := 3.4
		match item[0]:
			"show_whisper":
				wait = 4.2
			"title_card":
				wait = float(item[1][2]) + 1.4
		await get_tree().create_timer(wait, false).timeout
	_flushing = false


func banner(text: String) -> void:
	if _busy():
		_queue.append(["banner", [text]])
		return
	_banner.text = text
	if _banner_tween:
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.35)
	_banner_tween.tween_interval(2.2)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.8)


func show_whisper(text: String) -> void:
	if _busy():
		_queue.append(["show_whisper", [text]])
		return
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
	if _busy():
		_queue.append(["title_card", [title, sub, hold]])
		return
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


func _on_memory_burned(id: StringName) -> void:
	_refresh_memories()
	show_whisper("«%s» yandı.\n%s" % [tr(Memory.MemoryRegistry.get_def(id).display_name_key), Memory.whisper()])


## He learns his own name: it fades in on the HUD.
func _on_flag_changed(key: StringName, _old: Variant, value: Variant) -> void:
	_refresh_memories()
	if key == &"protagonist_name_known" and value == true and _name_label:
		_name_label.modulate.a = 0.0
		create_tween().tween_property(_name_label, "modulate:a", 1.0, NAME_FADE)


func _refresh_memories() -> void:
	if _name_label:
		_name_label.text = Names.protagonist_label().to_upper()   # empty until he knows it; "———" once it burned
	_embers.queue_redraw()


## The protagonist's own memories as large ember diamonds (burned ones are grey ash) and the
## memories gifted by survivors as a smaller row underneath.
func _draw_embers() -> void:
	var x := 10.0
	for m in Memory.combat_memories():
		_diamond(Vector2(x, 12), 9.0, Color(0.3, 0.28, 0.27, 0.9) if WorldState.has_burned(m.id) else Color(0.95, 0.42, 0.12))
		x += 24.0
	x = 8.0
	for g in Memory.gifted:
		_diamond(Vector2(x, 34), 5.5, Color(1.0, 0.7, 0.35))
		x += 15.0


func _diamond(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, 0), c + Vector2(0, r), c + Vector2(-r * 0.7, 0)])
	_embers.draw_colored_polygon(pts, col)
	_embers.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.7), 1.5)

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
