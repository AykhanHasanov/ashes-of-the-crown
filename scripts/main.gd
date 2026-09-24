extends Node3D
## Prototype entry point: builds Közqala, spawns Ayxan and Rüfət and runs
## Chapter 1 "Birinci səhər" — find Rüfət, talk, survive three waves of ash shades.

const Kozqala := preload("res://scripts/world/kozqala.gd")
const Player := preload("res://scripts/player/player.gd")
const AshShade := preload("res://scripts/enemies/ash_shade.gd")
const Companion := preload("res://scripts/npc/companion.gd")
const CameraRig := preload("res://scripts/camera/camera_rig.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const DialogueUI := preload("res://scripts/ui/dialogue_ui.gd")
const RufetDialogue := preload("res://scripts/story/rufet_dialogue.gd")

enum Phase { INTRO, FIND_RUFET, DIALOGUE, WAVES, VICTORY, DEFEAT }

const WAVES := [
	{"normal": 4, "fast": 0, "elite": 0, "title": "Kül Kölgələri qalxır!"},
	{"normal": 3, "fast": 4, "elite": 0, "title": "Külün altından daha çoxu gəlir..."},
	{"normal": 3, "fast": 1, "elite": 1, "title": "Kül Cəngavəri — Tacın keçmiş keşikçisi"},
]
const TALK_RANGE := 3.0
const HEARTH_RANGE := 2.8
const HEARTH_HEAL := 9.0

var phase := Phase.INTRO
var level
var player
var rufet
var rig
var hud
var dialogue
var flags := {}

var _wave := -1
var _alive := 0
var _next_wave_in := -1.0
var _frame := 0
var _fps_sum := 0.0
var _fps_count := 0
var _hearth_hint_shown := false


func _ready() -> void:
	Fx.reset_time()
	Memory.reset()
	Audio.music("ambient", 3.0)

	level = Kozqala.new()
	add_child(level)
	level.build()

	rig = CameraRig.new()
	add_child(rig)

	player = Player.new()
	add_child(player)
	player.global_position = level.player_spawn
	player.camera = rig.camera
	rig.target = player
	rig.snap()

	rufet = Companion.new()
	add_child(rufet)
	rufet.global_position = level.rufet_spot
	rufet.face(level.player_spawn)

	hud = Hud.new()
	add_child(hud)
	dialogue = DialogueUI.new()
	add_child(dialogue)
	dialogue.finished.connect(_on_dialogue_finished)
	dialogue.flag_set.connect(func(f: String): flags[f] = true)

	Fx.camera_rig = rig
	Fx.world = self
	player.health_changed.connect(hud.set_health)
	player.died.connect(_on_player_died)
	Settings.quality_changed.connect(_apply_quality)
	_apply_quality()
	_begin()


func _begin() -> void:
	match Settings.demo:
		"explore":
			_find_rufet()
		"dialogue":
			player.global_position = level.rufet_spot + Vector3(-2.4, 0, -1.2)
			_find_rufet()
			_start_dialogue()
		"combat", "fight":
			phase = Phase.WAVES
			rufet.in_combat = true
			_start_wave(0, true)
		"victory":
			_victory()
		_:
			_intro()


func _intro() -> void:
	phase = Phase.INTRO
	player.input_locked = true
	await hud.title_card("ASHES OF THE CROWN", "Közqala. Kül Gecəsindən üç gün sonra.", 3.2)
	player.input_locked = false
	_find_rufet()


func _find_rufet() -> void:
	phase = Phase.FIND_RUFET
	hud.set_objective("Rüfəti tap — o, cənub darvazasındakı ocağın yanındadır")


func _process(delta: float) -> void:
	_frame += 1
	if _frame > 30:
		_fps_sum += Engine.get_frames_per_second()
		_fps_count += 1
	_update_hearths(delta)

	match phase:
		Phase.FIND_RUFET:
			var near: bool = player.global_position.distance_to(rufet.global_position) < TALK_RANGE
			hud.set_prompt("[E]  Rüfətlə danış" if near else "")
			if near and Input.is_action_just_pressed("interact"):
				_start_dialogue()
		Phase.WAVES:
			if _alive <= 0 and _next_wave_in < 0.0:
				_next_wave_in = 2.5
			elif _next_wave_in >= 0.0:
				_next_wave_in -= delta
				if _next_wave_in < 0.0:
					_start_wave(_wave + 1)
		Phase.VICTORY, Phase.DEFEAT:
			if Input.is_action_just_pressed("restart"):
				get_tree().reload_current_scene()

	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
	_demo_actions()
	if Settings.capture_path != "" and _frame == Settings.capture_frame:
		_capture()


func _start_dialogue() -> void:
	phase = Phase.DIALOGUE
	hud.set_prompt("")
	hud.set_objective("")
	hud.visible = false
	player.input_locked = true
	player.face_towards(rufet.global_position)
	rufet.face(player.global_position)
	var a: Vector3 = player.global_position
	var b: Vector3 = rufet.global_position
	var line := b - a
	line.y = 0.0
	var side := Vector3(-line.z, 0.0, line.x).normalized()
	if side.dot(Vector3(1, 0, 1)) < 0.0:
		side = -side  # stay on the camera's usual south-east side
	var yaw := rad_to_deg(atan2(side.x, side.z)) - 20.0
	rig.cinematic((a + b) * 0.5 + Vector3(0, 1.45, 0), yaw)
	dialogue.start(RufetDialogue.DATA)


func _on_dialogue_finished(event: String) -> void:
	rig.release()
	hud.visible = true
	player.input_locked = false
	if event == "start_waves":
		phase = Phase.WAVES
		rufet.in_combat = true
		_start_wave(0)


func _start_wave(i: int, close := false) -> void:
	_wave = i
	_next_wave_in = -1.0
	if i >= WAVES.size():
		_victory()
		return
	var w: Dictionary = WAVES[i]
	hud.set_objective("Dalğa %d / %d" % [i + 1, WAVES.size()])
	hud.banner(w["title"])
	Fx.shake(0.35)
	Audio.play("horn", -3.0, 0.0)
	Audio.music("battle", 1.2)
	var kinds: Array[String] = []
	for k in ["elite", "normal", "fast"]:
		for n in int(w[k]):
			kinds.append(k)
	_alive = kinds.size()
	for k in kinds:
		_spawn(k, close)
		await get_tree().create_timer(0.3).timeout
		if phase != Phase.WAVES:
			return


func _spawn(kind: String, close: bool) -> void:
	var e = AshShade.new()
	e.configure(kind)
	add_child(e)
	e.global_position = _spawn_point(close)
	e.target = player
	e.killed.connect(_on_enemy_killed)
	if kind == "elite":
		hud.track_boss(e)


func _spawn_point(close: bool) -> Vector3:
	var p: Vector3 = player.global_position
	if close:
		var a := randf() * TAU
		return p + Vector3(cos(a), 0, sin(a)) * randf_range(4.0, 7.0)
	var points: Array[Vector3] = level.spawn_points.duplicate()
	points.shuffle()
	for s in points:
		if s.distance_to(p) > 8.0:
			return s
	return points[0]


func _on_enemy_killed(_e: Node) -> void:
	_alive -= 1
	if _alive <= 0 and phase == Phase.WAVES:
		# Last shade of the wave falls in slow motion
		Fx.slowmo(0.25, 0.8)
		Fx.punch(0.8)


func _update_hearths(delta: float) -> void:
	if player.dead or phase == Phase.VICTORY or player.health >= Player.MAX_HEALTH:
		return
	for h in level.braziers:
		if player.global_position.distance_to(h) < HEARTH_RANGE:
			player.heal(HEARTH_HEAL * delta)
			if not _hearth_hint_shown:
				_hearth_hint_shown = true
				hud.banner("Ocağın istisi yaralarını sağaldır")
			return


func _on_player_died() -> void:
	phase = Phase.DEFEAT
	rufet.in_combat = false
	hud.set_objective("")
	Audio.music("", 1.0)
	Audio.play("sting_defeat", -2.0, 0.0)
	await get_tree().create_timer(1.2).timeout
	hud.show_card("KÖZ SÖNDÜ", "Ayxan külün içində yıxıldı.", "[R] — yenidən başla", 0.75)


func _victory() -> void:
	phase = Phase.VICTORY
	rufet.in_combat = false
	player.input_locked = true
	hud.set_objective("")
	Audio.music("ambient", 4.0)
	Audio.play("sting_victory", -2.0, 0.0)
	var burned: int = Memory.burned.size()
	var lines := PackedStringArray()
	lines.append("Yanmış xatirələr: %d / %d" % [burned, Memory.MEMORIES.size()])
	if Memory.is_burned("rufet_face"):
		lines.append("Rüfət darvazanın ağzında dayanıb sənə baxır — tanımadığın bir üzlə.")
	elif flags.has("clue_letter"):
		lines.append("Rüfət qılıncını silir. Sabirin möhürlü məktubu isə ağlından çıxmır.")
	else:
		lines.append("Rüfət əlini çiyninə qoyur: \"Qardaşım hələ də buradadır.\"")
	if burned >= 4:
		lines.append("\"...yaxınlaşırsan, Ayxan. Tac səni gözləyir...\"  — Kül Şahı")
	elif burned == 0:
		lines.append("Közü bir dəfə də olsun oyatmadın. Kül Şahı səbirlə gözləyir.")
	lines.append("")
	lines.append("PROTOTİP SONU   ·   [R] — yenidən başla")
	await get_tree().create_timer(1.5).timeout
	hud.show_card("KÖZQALA SAĞ QALDI", "Hələlik.", "\n".join(lines), 0.8)


func _apply_quality() -> void:
	var high := Settings.is_high()
	level.apply_quality(high)
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if high else Viewport.SCALING_3D_MODE_FSR
	vp.scaling_3d_scale = 1.0 if high else 0.77
	vp.msaa_3d = Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if high else Viewport.SCREEN_SPACE_AA_FXAA


# --- Debug capture (see scripts/systems/settings.gd) -------------------------

func _demo_actions() -> void:
	if Settings.demo != "combat" or Settings.capture_path == "":
		return
	if _frame == Settings.capture_frame - 60:
		player.attack()
	elif _frame == Settings.capture_frame - 30:
		player.ember_power()


func _capture() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(Settings.capture_path.get_base_dir())
	img.save_png(Settings.capture_path)
	var avg := _fps_sum / maxf(_fps_count, 1)
	print("CAPTURE saved=%s avg_fps=%.1f adapter=%s quality=%s" % [
		Settings.capture_path, avg, RenderingServer.get_video_adapter_name(), "high" if Settings.is_high() else "low"])
	get_tree().quit()
