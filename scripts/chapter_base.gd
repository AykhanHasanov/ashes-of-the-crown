extends Node3D
## Shared scaffolding for every chapter scene: the level, camera, Ayxan, HUD,
## dialogue box, pause menu, journal, checkpoints, prompts, the objective marker,
## hearth healing, scene changes between chapters and the debug capture.
##
## A chapter overrides: _make_level(), _setup(), _begin(mode), _tick(delta),
## _marker_target(), _on_dialogue_finished(event), _on_player_died(), and may swap in the
## V3 body and camera through _make_player() / _make_camera().

const Player := preload("res://scripts/player/player.gd")
const CameraRig := preload("res://scripts/camera/camera_rig.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const DialogueUI := preload("res://scripts/ui/dialogue_ui.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const Journal := preload("res://scripts/ui/journal.gd")
const RadialMenu := preload("res://scripts/ui/radial_menu.gd")
const AshOffer := preload("res://scripts/ui/ash_offer.gd")
const Balance := preload("res://scripts/systems/balance.gd")

const CHAPTER_SCENES := {1: "res://scenes/main.tscn", 2: "res://scenes/chapter2.tscn"}
const TALK_RANGE := 3.0

## How the next scene should start: "" = title screen, "checkpoint" = load the
## save and resume it, "fresh" = brand-new game.
static var restart_mode := ""

var level
var player
var rig
var hud
var dialogue
var pause_menu
var journal
var radial
var offer

var _frame := 0
var _fps_sum := 0.0
var _fps_count := 0
var _phys_sum := 0.0
var _proc_sum := 0.0
var _hearth_hint_shown := false


func _ready() -> void:
	Fx.reset_time()
	preload("res://scripts/characters/human.gd").warm_up()
	level = _make_level()
	add_child(level)
	level.build()

	rig = _make_camera()
	add_child(rig)
	player = _make_player()
	add_child(player)
	player.global_position = level.player_spawn
	player.camera = rig.camera
	if "rig" in player:
		player.rig = rig
	rig.target = player
	rig.snap()

	hud = Hud.new()
	add_child(hud)
	dialogue = DialogueUI.new()
	add_child(dialogue)
	dialogue.finished.connect(_on_dialogue_finished)
	dialogue.flag_set.connect(func(f): WorldState.set_flag(StringName(f)))
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.main_menu_requested.connect(to_main_menu)
	journal = Journal.new()
	add_child(journal)
	radial = RadialMenu.new()
	add_child(radial)
	offer = AshOffer.new()
	add_child(offer)
	player.radial = radial
	player.offer = offer

	Fx.camera_rig = rig
	Fx.world = self
	player.health_changed.connect(hud.set_health)
	player.ember_changed.connect(hud.set_ember)
	if player.has_signal("stamina_changed"):
		player.stamina_changed.connect(hud.set_stamina)
		player.flasks_changed.connect(hud.set_flasks)
		player.weapon_changed.connect(hud.set_weapon)
		player.lock_changed.connect(hud.set_lock)
	player.died.connect(_on_player_died)
	EventBus.saving.connect(_on_saving)
	Settings.changed.connect(_apply_quality)
	_apply_quality()
	_setup()
	var mode := restart_mode
	restart_mode = ""
	_begin(mode)


# --- Overridables ---------------------------------------------------------------

func _make_level() -> Node3D:
	return null


func _make_player() -> Node3D:
	return Player.new()


func _make_camera() -> Node3D:
	return CameraRig.new()


func _setup() -> void:
	pass


func _begin(_mode: String) -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _marker_target() -> Variant:
	return null


func _on_dialogue_finished(_event: String) -> void:
	pass


func _on_player_died() -> void:
	pass


# --- Frame loop -----------------------------------------------------------------

func _process(delta: float) -> void:
	_frame += 1
	if _frame > 30:
		_fps_sum += Engine.get_frames_per_second()
		_fps_count += 1
		_phys_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		_proc_sum += Performance.get_monitor(Performance.TIME_PROCESS)
	_update_hearths(delta)
	hud.set_marker(_marker_target(), rig.camera)
	_tick(delta)
	_demo_actions()
	if Settings.capture_path != "" and _frame == Settings.capture_frame:
		_capture()


# --- Helpers --------------------------------------------------------------------

## Loads another chapter scene. `mode` is passed on as restart_mode.
func go_to_chapter(n: int, mode := "checkpoint") -> void:
	restart_mode = mode
	get_tree().paused = false
	get_tree().change_scene_to_file(CHAPTER_SCENES[n])


func to_main_menu() -> void:
	go_to_chapter(1, "")


## Records the story checkpoint and asks for an autosave (SaveManager never writes during
## a debug --demo, so captures cannot overwrite the player's save).
func save_checkpoint(checkpoint: String) -> void:
	WorldState.set_checkpoint(checkpoint)
	EventBus.checkpoint_rested.emit(StringName(checkpoint))


## Just before a save is written: copy Ayxan's live values into WorldState.
func _on_saving(_slot: int) -> void:
	if not is_instance_valid(player):
		return
	var max_hp: Variant = player.get("max_health")
	var stats := {"health": player.health, "max_health": max_hp if max_hp != null else player.MAX_HEALTH, "fire": player.ember}
	if "flasks" in player:
		stats["flasks"] = player.flasks
		stats["max_flasks"] = player.max_flasks
	if "weapon" in player and player.weapon is Dictionary and player.weapon.has("id"):
		stats["weapon"] = player.weapon["id"]
	WorldState.set_player_stats(stats)
	WorldState.set_player_position(player.global_position)


func set_controls(on: bool) -> void:
	pause_menu.enabled = on
	journal.enabled = on


## Shows `text` while Ayxan is within `dist`; returns true when E is pressed there.
func near_prompt(point: Vector3, dist: float, text: String) -> bool:
	var near: bool = player.global_position.distance_to(point) < dist
	hud.set_prompt(text if near else "")
	return near and Input.is_action_just_pressed("interact")


## Frames Ayxan and `other` side-on and opens a dialogue.
func talk_with(other: Node3D, data: Dictionary, bring_closer := true) -> void:
	hud.set_prompt("")
	hud.visible = false
	player.input_locked = true
	var gap: Vector3 = other.global_position - player.global_position
	gap.y = 0.0
	if bring_closer and gap.length() > 4.0:
		other.global_position = player.global_position + gap.normalized() * 2.6
	player.face_towards(other.global_position)
	if other.has_method("face"):
		other.face(player.global_position)
	var a: Vector3 = player.global_position
	var b: Vector3 = other.global_position
	var line := b - a
	line.y = 0.0
	var side := Vector3(-line.z, 0.0, line.x).normalized()
	if side.dot(Vector3(1, 0, 1)) < 0.0:
		side = -side  # stay on the camera's usual south-east side
	rig.cinematic((a + b) * 0.5 + Vector3(0, 1.45, 0), rad_to_deg(atan2(side.x, side.z)) - 20.0)
	dialogue.start(data)


## Undo talk_with once the dialogue closes.
func end_talk() -> void:
	rig.release()
	hud.visible = true
	player.input_locked = false


## Hearths heal Ayxan — but not in the middle of a fight.
func _update_hearths(delta: float) -> void:
	if player.dead or player.health >= player.MAX_HEALTH:
		return
	if Time.get_ticks_msec() - player.last_hurt_ms < Balance.HEARTH_HIT_BLOCK * 1000.0:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if player.global_position.distance_to(e.global_position) < Balance.HEARTH_ENEMY_BLOCK:
			return
	for h in level.braziers:
		if player.global_position.distance_to(h) < Balance.HEARTH_RANGE:
			player.heal(Balance.HEARTH_HEAL * (5.0 / 9.0 if WorldState.has_burned(&"mother_name") else 1.0) * delta)
			if not _hearth_hint_shown:
				_hearth_hint_shown = true
				hud.banner("Ocağın sıcaklığı yaralarını iyileştiriyor")
			return


func _apply_quality() -> void:
	var high := Settings.is_high()
	level.apply_quality(high)
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if high else Viewport.SCALING_3D_MODE_FSR
	vp.scaling_3d_scale = 1.0 if high else 0.77
	vp.msaa_3d = Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if high else Viewport.SCREEN_SPACE_AA_FXAA


# --- Debug capture (see scripts/systems/settings.gd) ------------------------------

func _demo_actions() -> void:
	if Settings.demo in ["pause", "settings", "keys"] and _frame == 60:
		pause_menu.open()
	if Settings.demo in ["settings", "keys"] and _frame == 70:
		pause_menu._open_settings()
	if Settings.demo == "keys" and _frame == 80:
		pause_menu._settings._show_keys(true)
	if Settings.demo == "journal" and _frame == 60:
		journal.open()


func _capture() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(Settings.capture_path.get_base_dir())
	img.save_png(Settings.capture_path)
	var avg := _fps_sum / maxf(_fps_count, 1)
	print("CAPTURE saved=%s avg_fps=%.1f adapter=%s quality=%s" % [
		Settings.capture_path, avg, RenderingServer.get_video_adapter_name(), "high" if Settings.is_high() else "low"])
	# Profile for the phase reports (the F3 numbers)
	print("PROFILE draw_calls=%d primitives=%dk objects=%d vram=%dMB frame_ms=%.1f physics_ms=%.1f nodes=%d" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
		_proc_sum / maxf(_fps_count, 1) * 1000.0,
		_phys_sum / maxf(_fps_count, 1) * 1000.0,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	get_tree().quit()
