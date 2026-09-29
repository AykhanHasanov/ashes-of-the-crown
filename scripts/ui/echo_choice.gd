extends CanvasLayer
## The choice at the end of an echo: KEEP the memory (remember it, no power) or BURN it
## (fire power, the memory is gone for good). Shows the memory's title and the fire
## power it would give — never a list of consequences.
##
## KEEP: press E (echo_keep) or click. BURN: hold Q (echo_burn) or hold the button for
## burn_hold_seconds (data/balance/combat.json, ember; shared with the fire wheel), measured
## in real time; letting go early resets it, so a single press or tap can never burn a
## memory. Emits `chosen` once; the caller writes the result.

signal chosen(choice: StringName)   # &"keep" | &"burn"

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const MemoryRegistry := preload("res://scripts/core/memory_registry.gd")
const BurnPower := preload("res://scripts/combat/burn_power.gd")

var definition: Resource            # EchoDefinition
var power_text := ""                # what BURN would give, for good

var _hold_from_ms := -1
var _mouse_burn := false
var _done := false
var _progress: ProgressBar
var _burn_button: Button


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var memory: Resource = MemoryRegistry.get_def(definition.memory_id)
	var root := Control.new()
	root.theme = UITheme.build()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size = Vector2(620, 0)
	center.add_child(box)
	box.add_child(UITheme.title(tr(memory.display_name_key), 40))
	var prompt := Label.new()
	prompt.text = tr(definition.prompt_key)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(prompt)
	power_text = tr("ECHO_POWER_PERMANENT") % BurnPower.describe(BurnPower.preview(definition.memory_id))
	box.add_child(UITheme.title(power_text, 20, UITheme.EMBER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	var keep := Button.new()
	keep.name = "Keep"
	keep.text = "%s\n%s" % [tr(definition.keep_key), tr("ECHO_KEEP_HINT")]
	keep.custom_minimum_size = Vector2(280, 70)
	keep.pressed.connect(func(): _choose(&"keep"))
	row.add_child(keep)
	var burn_col := VBoxContainer.new()
	row.add_child(burn_col)
	_burn_button = Button.new()
	_burn_button.name = "Burn"
	_burn_button.text = "%s\n%s" % [tr(definition.burn_key), tr("ECHO_BURN_HINT")]
	_burn_button.custom_minimum_size = Vector2(280, 70)
	_burn_button.button_down.connect(func(): _mouse_burn = true)
	_burn_button.button_up.connect(func(): _mouse_burn = false)
	burn_col.add_child(_burn_button)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(280, 10)
	_progress.max_value = 1.0
	burn_col.add_child(_progress)
	keep.grab_focus()


func _process(_delta: float) -> void:
	if _done:
		return
	if Input.is_action_just_pressed("echo_keep"):
		_choose(&"keep")
		return
	var holding := Input.is_action_pressed("echo_burn") or _mouse_burn
	if not holding:
		_hold_from_ms = -1
		_progress.value = 0.0
		return
	if _hold_from_ms < 0:
		_hold_from_ms = Time.get_ticks_msec()
	var held := (Time.get_ticks_msec() - _hold_from_ms) / 1000.0
	_progress.value = clampf(held / hold_seconds(), 0.0, 1.0)
	if held >= hold_seconds():
		_choose(&"burn")


static func hold_seconds() -> float:
	return float(DataDB.balance("combat")["ember"].get("burn_hold_seconds", 1.5))


## How far the burn hold has got, 0..1 (0 when not holding; for the tests).
func burn_progress() -> float:
	return _progress.value


func _choose(choice: StringName) -> void:
	if _done:
		return
	_done = true
	Audio.play("memory_burn" if choice == &"burn" else "ui_select", -4.0, 0.0)
	chosen.emit(choice)
