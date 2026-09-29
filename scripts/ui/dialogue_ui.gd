extends CanvasLayer
## Cinematic dialogue box with letterbox bars, typewriter text and numbered choices.
##
## Dialogue data is a Dictionary of nodes keyed by id. A node may have:
##   speaker, text           — the line to show
##   speaker_id, text_key    — the same through an NPC id and a translation key
##   next                    — id of the following node (continue with E / click)
##   choices                 — [{text, next?, set?, event?, disabled?}] the protagonist's answers
##                             (1-3 / click); a disabled one is shown but cannot be chosen
##   auto                    — {after: seconds, next: id}: moves on by itself (no input)
##   branch                  — {memory, burned, intact}: jump depending on Yaddaş Yanğını, or
##                             {if, then, else} with a condition (check(): WorldState's, plus
##                             the conversation's own, e.g. "door_mode")
##   type "name_challenge"   — the speaker asks who is there (text_key); the only answer is the
##                             protagonist's name as he can say it (Names.protagonist_answer):
##                             known → "pass"; not yet known → "Bilmiyorum..." → "unknown";
##                             burned → the blank, cannot be chosen: after a moment "fail".
##   set                     — flag emitted through flag_set when the node is shown
##   do                      — [WorldState.apply() actions] run when a node is shown or a choice taken
##   end + event             — closes the dialogue and emits finished(event)

const Names := preload("res://scripts/core/names.gd")
signal finished(event: String)
signal flag_set(flag: String)
signal line_shown(node: Dictionary)      # after a node's text is set (voices, door shadows)
signal started

const CHALLENGE_WAIT := 1.8              # a blank name hangs in the air this long

const GOLD := Color(0.92, 0.74, 0.42)
const EMBER := Color(1.0, 0.55, 0.22)
const BAR_HEIGHT := 84.0

var _data: Dictionary
var _node: Dictionary
var node_id := ""
var context: Dictionary = {}             # this conversation's own conditions (door_mode...)
var _auto_t := -1.0
var subtitles_only := false
var _box_style: StyleBoxFlat
var _plain_style: StyleBoxEmpty
var _active := false
var _typing := false
var _cooldown := 0.0
var _top: ColorRect
var _bottom: ColorRect
var _panel: PanelContainer
var _name: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _continue: Label
var _type_tween: Tween


func _ready() -> void:
	layer = 20
	_top = _bar(true)
	_bottom = _bar(false)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.035, 0.03, 0.9)
	style.border_color = Color(0.62, 0.45, 0.22, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(22)
	_panel.add_theme_stylebox_override("panel", style)
	_box_style = style
	_plain_style = StyleBoxEmpty.new()
	_plain_style.set_content_margin_all(4)
	add_child(_panel)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -470
	_panel.offset_right = 470
	_panel.offset_top = -BAR_HEIGHT - 16
	_panel.offset_bottom = -BAR_HEIGHT - 16
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_name)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", 21)
	_text.add_theme_color_override("default_color", Color(0.93, 0.9, 0.85))
	vbox.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 4)
	vbox.add_child(_choices)
	_continue = Label.new()
	_continue.text = "E — devam"
	_continue.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue.add_theme_font_size_override("font_size", 15)
	_continue.add_theme_color_override("font_color", Color(0.7, 0.64, 0.56))
	vbox.add_child(_continue)
	_panel.visible = false


func start(data: Dictionary, start_id := "start", ctx: Dictionary = {}) -> void:
	_data = data
	context = ctx
	_subtitle_style(bool(ctx.get("door_mode", false)))
	started.emit()
	_active = true
	_panel.visible = true
	_panel.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_top, "offset_bottom", BAR_HEIGHT, 0.6)
	tw.tween_property(_bottom, "offset_top", -BAR_HEIGHT, 0.6)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.5).set_delay(0.3)
	_show(start_id)


func is_active() -> bool:
	return _active


## A condition in this conversation: its own context ("door_mode"), else WorldState's.
func check(cond: String) -> bool:
	if context.has(cond):
		return bool(context[cond])
	return WorldState.check(cond)


## Through a door there is only a voice: the words sit as subtitles on the lower letterbox bar
## (no panel), so the picture above stays clear. Otherwise the usual dialogue panel.
func _subtitle_style(on: bool) -> void:
	subtitles_only = on
	_panel.add_theme_stylebox_override("panel", _plain_style if on else _box_style)
	_panel.offset_top = -12.0 if on else -BAR_HEIGHT - 16
	_panel.offset_bottom = -12.0 if on else -BAR_HEIGHT - 16
	_name.add_theme_font_size_override("font_size", 16 if on else 22)
	_text.add_theme_font_size_override("normal_font_size", 19 if on else 21)


## For tests and tools: the answers on screen and whether each can be taken.
func choice_texts() -> Array:
	return (_node.get("choices", []) as Array).map(func(c): return Names.fill(c["text"]))


func choice_enabled(i: int) -> bool:
	return not bool(_node["choices"][i].get("disabled", false))


func choose(i: int) -> void:
	_choose(i)


func _process(delta: float) -> void:
	if not _active:
		return
	if _auto_t >= 0.0:
		_auto_t -= delta
		if _auto_t < 0.0:
			_show(_node["auto"]["next"])
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack"):
		if _typing:
			_finish_typing()
		elif not _node.has("choices"):
			_advance()
		return
	if _typing or not _node.has("choices"):
		return
	var count: int = _node["choices"].size()
	for i in mini(count, 9):
		if Input.is_action_just_pressed("choice_%d" % (i + 1)):
			_choose(i)
			return


func _show(id: String) -> void:
	var node: Dictionary = _data[id]
	if node.has("branch"):
		var b: Dictionary = node["branch"]
		if b.has("if"):
			_show(b["then"] if check(b["if"]) else b["else"])
		else:
			_show(b["burned"] if WorldState.has_burned(StringName(b["memory"])) else b["intact"])
		return
	if node.get("type", "") == "name_challenge":
		node = _name_challenge(node)
	if node.has("set"):
		flag_set.emit(node["set"])
	for action in node.get("do", []):
		WorldState.apply(action)
	_node = node
	node_id = id
	_auto_t = float(node["auto"]["after"]) if node.has("auto") else -1.0
	Audio.play("ui_click", -12.0, 0.05)
	# "speaker_id" (an NPC id) names the speaker through Names; old trees give "speaker" text.
	# Burned names are blank in all text, unless the speaker ignores burned names.
	var speaker: String = node.get("speaker", "")
	var speaker_id := StringName(node.get("speaker_id", ""))
	var own_line := speaker == Names.TOKEN
	_name.text = Names.npc(speaker_id) if speaker_id != &"" else Names.fill(speaker)
	_name.add_theme_color_override("font_color", EMBER if own_line else GOLD)
	var text: String = tr(node["text_key"]) if node.has("text_key") else node.get("text", "")
	_text.text = Names.fill(text, speaker_id)
	_text.visible_ratio = 0.0
	for c in _choices.get_children():
		c.queue_free()
	_choices.visible = false
	_continue.visible = false
	_typing = true
	_cooldown = 0.15
	if _type_tween:
		_type_tween.kill()
	_type_tween = create_tween()
	_type_tween.tween_property(_text, "visible_ratio", 1.0, maxf(0.3, _text.text.length() * 0.022))
	_type_tween.tween_callback(_finish_typing)
	line_shown.emit(node)


## "Who is there?" — answered only by the protagonist's name as the UI shows it. A burned
## name is the blank: it cannot be said, and the node moves on to "fail".
func _name_challenge(node: Dictionary) -> Dictionary:
	var n := node.duplicate()
	var burned := WorldState.has_burned(Names.PROTAGONIST_MEMORY)
	var known := Names.protagonist_self_known()
	var next: String = node["pass"] if known else node.get("unknown", node["fail"])
	n["choices"] = [{"text": Names.protagonist_answer(), "next": next, "disabled": burned, "own": true}]
	if burned:
		n["auto"] = {"after": CHALLENGE_WAIT, "next": node["fail"]}
	return n


func _finish_typing() -> void:
	if _type_tween:
		_type_tween.kill()
	_text.visible_ratio = 1.0
	_typing = false
	if _node.has("choices"):
		var choices: Array = _node["choices"]
		for i in choices.size():
			var btn := Button.new()
			btn.text = "%d.  %s" % [i + 1, Names.fill(choices[i]["text"])]
			btn.flat = true
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_font_size_override("font_size", 19)
			btn.add_theme_color_override("font_color", Color(0.95, 0.72, 0.45))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.6))
			btn.pressed.connect(_choose.bind(i))
			btn.disabled = bool(choices[i].get("disabled", false))
			_choices.add_child(btn)
		_choices.visible = true
	else:
		_continue.visible = true


func _advance() -> void:
	if _node.has("next"):
		_show(_node["next"])
	else:
		_end(_node.get("event", ""))


func _choose(i: int) -> void:
	if not _active or _typing:
		return
	var c: Dictionary = _node["choices"][i]
	if bool(c.get("disabled", false)):
		return
	Audio.play("ui_select", -10.0, 0.0)
	if c.has("set"):
		flag_set.emit(c["set"])
	for action in c.get("do", []):
		WorldState.apply(action)
	if c.has("next"):
		_show(c["next"])
	else:
		_end(c.get("event", ""))


func _end(event: String) -> void:
	_active = false
	_auto_t = -1.0
	context = {}
	var tw := create_tween().set_parallel()
	tw.tween_property(_top, "offset_bottom", 0.0, 0.5)
	tw.tween_property(_bottom, "offset_top", 0.0, 0.5)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(func(): _panel.visible = false)
	finished.emit(event)


func _bar(top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	r.anchor_top = 0.0 if top else 1.0
	r.anchor_bottom = 0.0 if top else 1.0
	r.offset_top = 0.0
	r.offset_bottom = 0.0
	return r
