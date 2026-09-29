extends "res://scripts/chapter_base.gd"
## Base for every echo scene: a short, constrained, playable memory. The protagonist
## cannot die here (for now), nothing is saved, and when the concrete echo calls
## complete() the choice screen asks KEEP or BURN; EchoDirector writes the answer,
## autosaves and takes him back to where he was.
##
## A concrete echo (e.g. scripts/echoes/test_echo.gd) overrides _make_level() and
## _start() — its playable part — and calls complete() when the memory has played out.
## Future echoes (the fire night inside burning Közkale) are just more of these.

const Protagonist := preload("res://scripts/player_v3/protagonist.gd")
const TPCamera := preload("res://scripts/camera/third_person_camera.gd")
const EchoChoice := preload("res://scripts/ui/echo_choice.gd")
const EchoRegistry := preload("res://scripts/core/echo_registry.gd")
const Names := preload("res://scripts/core/names.gd")

var definition: Resource
var choice_screen: CanvasLayer
var _completed := false


func _make_player() -> Node3D:
	return Protagonist.new()


func _make_camera() -> Node3D:
	return TPCamera.new()


## Nothing in an echo is the protagonist's real state: no stats or position to save.
func _on_saving(_slot: int) -> void:
	pass


func _begin(_mode: String) -> void:
	Names.scene_all_known = true   # a memory from before: every name is known here
	definition = EchoDirector.definition()
	if definition == null:
		# Opened directly (editor / --demo): play it as the echo this scene belongs to
		for d in EchoRegistry.all():
			if d.scene_path == scene_file_path:
				definition = d
	player.make_invulnerable(1.0e9)   # echoes are not lethal
	player.wake()
	hud.title_card(tr(definition.title_key) if definition != null else "", "", 2.0)
	_start()
	if Settings.demo == "echo_choice":
		complete()


## The playable part of the echo; override.
func _start() -> void:
	pass


## The memory has played out: ask KEEP or BURN.
func complete() -> void:
	if _completed:
		return
	_completed = true
	player.input_locked = true
	hud.set_objective("")
	hud.set_prompt("")
	choice_screen = EchoChoice.new()
	choice_screen.definition = definition
	add_child(choice_screen)
	choice_screen.chosen.connect(func(c: StringName): EchoDirector.resolve(c, get_tree()))


func _tick(_delta: float) -> void:
	var free: bool = get_tree().paused or choice_screen != null
	var want := Input.MOUSE_MODE_VISIBLE if free or Settings.capture_path != "" else Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != want:
		Input.mouse_mode = want


func _exit_tree() -> void:
	Names.scene_all_known = false
	if EchoDirector.active:
		EchoDirector.abandon()   # left without choosing: the memory stays undecided
