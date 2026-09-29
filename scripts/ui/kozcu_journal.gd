extends CanvasLayer
## The Közcü's journal (Tab) — STORY_BIBLE §9: Aras forgets; the world remembers for him.
##   People    everyone he has met: a placeholder portrait, the name as Names resolves it
##             (the epithet until he knows it, the blank once it burned), the epithet, a
##             one-line relation (when the story has written one) and the last thing they
##             said to him.
##   Thread    always exactly one current goal line (WorldState world value "thread").
##   Memories  the KEPT and BURNED memories; a burned one shows the power it gave. Nothing
##             about what a kept memory might give later.
## Everything through translation keys and WorldState; it holds no state of its own.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const Names := preload("res://scripts/core/names.gd")
const NpcRegistry := preload("res://scripts/core/npc_registry.gd")
const MemoryRegistry := preload("res://scripts/core/memory_registry.gd")
const BurnPower := preload("res://scripts/combat/burn_power.gd")

var enabled := false
var _people: VBoxContainer
var _thread: Label
var _memories: VBoxContainer


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.theme = UITheme.build()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.012, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 56)
	root.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	box.add_child(UITheme.title(tr("JOURNAL_TITLE"), 30))
	var thread_row := HBoxContainer.new()
	thread_row.add_theme_constant_override("separation", 14)
	box.add_child(thread_row)
	thread_row.add_child(UITheme.title(tr("JOURNAL_THREAD"), 18, UITheme.MUTED))
	_thread = UITheme.title("", 20, UITheme.EMBER)
	thread_row.add_child(_thread)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(cols)
	_people = _column(cols, tr("JOURNAL_PEOPLE"), 2.0)
	_memories = _column(cols, tr("JOURNAL_MEMORIES"), 1.0)
	var hint := UITheme.title(tr("JOURNAL_CLOSE"), 15, UITheme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(hint)
	visible = false


func _column(parent: Control, heading: String, ratio: float) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = ratio
	col.add_theme_constant_override("separation", 10)
	parent.add_child(col)
	col.add_child(UITheme.title(heading, 22))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	return list


func open() -> void:
	if not enabled or visible or get_tree().paused:
		return
	refresh()
	visible = true
	get_tree().paused = true
	Audio.play("ui_select", -8.0, 0.0)


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	Audio.play("ui_click", -8.0, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		get_viewport().set_input_as_handled()
		if visible:
			close()
		else:
			open()
	elif visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


# --- Content (also read by the tests) --------------------------------------------------------------

## The people Aras has met, in the order the registry keeps: [{id, name, epithet, relation, last}].
static func people() -> Array:
	var out: Array = []
	for def in NpcRegistry.all():
		if WorldState.get_npc_flag(def.id, &"met", false) != true:
			continue
		var last_key := String(WorldState.get_npc_flag(def.id, &"last_line", ""))
		out.append({"id": def.id, "name": Names.npc(def.id), "epithet": Names.capitalize(Names.npc_epithet(def.id)),
			"relation": Names.fill(TranslationServer.translate(def.relation_key)) if def.relation_key != "" else "",
			"last": Names.fill(TranslationServer.translate(last_key).replace("(…)", "…"), def.id) if last_key != "" else ""})
	return out


static func thread_text() -> String:
	var key := String(WorldState.get_world_value(&"thread", ""))
	return Names.fill(TranslationServer.translate(key)) if key != "" else TranslationServer.translate("JOURNAL_NO_THREAD")


## Kept and burned memories: [{id, title, state: "kept" | "burned", power: "" or its gain}].
static func memories() -> Array:
	var gains := {}
	for g in BurnPower.gains():
		gains[g["id"]] = BurnPower.describe(g)
	var out: Array = []
	for def in MemoryRegistry.all():
		var st: int = WorldState.get_memory_state(def.id)
		if st == WorldState.MemoryState.UNKNOWN:
			continue
		var burned: bool = st == WorldState.MemoryState.BURNED
		out.append({"id": def.id, "title": TranslationServer.translate(def.display_name_key),
			"state": "burned" if burned else "kept", "power": gains.get(def.id, "") if burned else ""})
	return out


func refresh() -> void:
	_thread.text = thread_text()
	for c in _people.get_children():
		c.queue_free()
	for p in people():
		_people.add_child(_person_card(p))
	for c in _memories.get_children():
		c.queue_free()
	for m in memories():
		var row := VBoxContainer.new()
		var title := UITheme.title(m["title"], 19, UITheme.TEXT if m["state"] == "kept" else UITheme.MUTED)
		row.add_child(title)
		var state := tr("JOURNAL_KEPT") if m["state"] == "kept" else tr("JOURNAL_BURNED")
		if m["power"] != "":
			state += "  ·  " + m["power"]
		row.add_child(UITheme.title(state, 15, UITheme.EMBER if m["state"] == "burned" else UITheme.MUTED))
		_memories.add_child(row)


func _person_card(p: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	# Placeholder portrait: a framed tile with the first letter of what he calls them
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(64, 64)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.11, 0.08)
	style.border_color = Color(0.62, 0.45, 0.22, 0.8)
	style.set_border_width_all(2)
	portrait.add_theme_stylebox_override("panel", style)
	var initial := UITheme.title(String(p["name"]).substr(0, 1) if p["name"] != "" else "·", 28, UITheme.GOLD)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait.add_child(initial)
	row.add_child(portrait)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var head: String = p["name"]
	if p["epithet"] != "" and p["epithet"] != p["name"]:
		head += "  —  " + p["epithet"]
	text.add_child(UITheme.title(head, 19))
	if p["relation"] != "":
		text.add_child(UITheme.title(p["relation"], 15, UITheme.MUTED))
	if p["last"] != "":
		var last := Label.new()
		last.text = tr("JOURNAL_LAST_SAID") % p["last"]
		last.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		last.add_theme_font_size_override("font_size", 15)
		last.add_theme_color_override("font_color", UITheme.MUTED)
		text.add_child(last)
	return row
