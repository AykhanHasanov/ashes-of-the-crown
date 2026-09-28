extends CanvasLayer
## Title screen shown over the slowly orbiting courtyard: Continue, New Game, Settings
## (the pause menu's settings screen) and Quit. The two ways into the game:
##   Continue — loads the most recently written save slot (SaveManager falls back to its
##              .bak); greyed out when there is no save. If loading fails the menu stays
##              and says so — it never starts a new game in the player's place.
##   New Game — the first empty slot; with every slot full it asks before overwriting the
##              one played longest ago (naming it and its last-played time).
## All text comes from translation keys (localization/strings.csv).

signal new_game
signal continue_game   # emitted after the slot has been loaded into WorldState

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")

var _root: Control
var _menu: VBoxContainer
var _continue: Button
var _new: Button
var _status: Label
var _settings: PanelContainer
var _confirm: PanelContainer
var _confirm_text: Label
var _confirm_slot := 0
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

	_menu.add_child(UITheme.title(tr("MENU_TITLE"), 60))
	_menu.add_child(UITheme.title(tr("MENU_SUBTITLE"), 28, UITheme.EMBER))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	_menu.add_child(gap)
	_continue = _button(tr("MENU_CONTINUE"), _on_continue)
	_new = _button(tr("MENU_NEW_GAME"), _on_new_game)
	_button(tr("MENU_SETTINGS"), _on_settings)
	_button(tr("MENU_QUIT"), func(): get_tree().quit())
	_status = UITheme.title("", 17, UITheme.EMBER)
	_status.visible = false
	_menu.add_child(_status)
	refresh()

	var footer := UITheme.title(tr("MENU_FOOTER"), 15, UITheme.MUTED)
	_root.add_child(footer)
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_left = 90
	footer.offset_top = -50

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The same settings screen the pause menu opens
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(_on_settings_closed)
	center.add_child(_settings)
	_build_confirm(center)

	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 1.5)
	_focus_first.call_deferred()


## Greys out Continue when no slot can be read.
func refresh() -> void:
	_continue.disabled = SaveManager.most_recent_slot() == 0


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(340, 54)
	b.pressed.connect(action)
	b.focus_entered.connect(func(): Audio.play("ui_click", -14.0, 0.05))
	_menu.add_child(b)
	return b


func _focus_first() -> void:
	for c in _menu.get_children():
		if c is Button and not c.disabled:
			c.grab_focus()
			return


func _on_continue() -> void:
	if _starting or _continue.disabled:
		return
	if not SaveManager.load_slot(SaveManager.most_recent_slot()):
		_status.text = tr("MENU_LOAD_FAILED")
		_status.visible = true
		refresh()
		_focus_first()
		return
	_leave(continue_game)


## A new game takes the first empty slot. With every slot full it asks before
## overwriting the one played longest ago — a save is never replaced silently.
func _on_new_game() -> void:
	if _starting:
		return
	var slot := SaveManager.first_empty_slot()
	if slot > 0:
		SaveManager.active_slot = slot
		_leave(new_game)
		return
	_confirm_slot = SaveManager.oldest_slot()
	var info := SaveManager.slot_info(_confirm_slot)
	_confirm_text.text = tr("MENU_OVERWRITE_BODY") % [tr("MENU_SLOT_NAME") % _confirm_slot, SaveManager.format_time(int(info["last_saved_timestamp"]))]
	_menu.visible = false
	_confirm.visible = true
	_confirm.get_node("Box/Buttons/Cancel").grab_focus()


func _build_confirm(parent: Control) -> void:
	_confirm = PanelContainer.new()
	_confirm.visible = false
	parent.add_child(_confirm)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 18)
	_confirm.add_child(box)
	box.add_child(UITheme.title(tr("MENU_OVERWRITE_TITLE"), 30))
	_confirm_text = Label.new()
	_confirm_text.custom_minimum_size = Vector2(520, 0)
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_confirm_text)
	var row := HBoxContainer.new()
	row.name = "Buttons"
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var ok := Button.new()
	ok.text = tr("MENU_OVERWRITE_CONFIRM")
	ok.custom_minimum_size = Vector2(200, 50)
	ok.pressed.connect(func():
		_confirm.visible = false
		SaveManager.active_slot = _confirm_slot
		_leave(new_game))
	row.add_child(ok)
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.text = tr("MENU_CANCEL")
	cancel.custom_minimum_size = Vector2(200, 50)
	cancel.pressed.connect(_cancel_confirm)
	row.add_child(cancel)


func _cancel_confirm() -> void:
	_confirm.visible = false
	_menu.visible = true
	_focus_first()


func _on_settings() -> void:
	if _starting:
		return
	Audio.play("ui_select", -8.0, 0.0)
	_menu.visible = false
	_settings.open()


func _on_settings_closed() -> void:
	_menu.visible = true
	_focus_first()


## True while the overwrite question is on screen (for the tests).
func is_confirming() -> bool:
	return _confirm.visible


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
