extends "res://scripts/chapter_base.gd"
## Chapter 1 "Birinci səhər" (also hosts the title screen): Ayxan rises from the
## ash → Rüfət → three waves of ash shades → three Kül əks-sədaları (ember echoes)
## that each reveal a trait of the hidden traitor → back to Rüfət → chapter end,
## from where Enter leads on to Chapter 2 (Son Ocaq).
##
## Checkpoints: start, waves, echoes, return, chapter_end.

const Kozqala := preload("res://scripts/world/kozqala.gd")
const AshShade := preload("res://scripts/enemies/ash_shade.gd")
const Companion := preload("res://scripts/npc/companion.gd")
const EchoSpot := preload("res://scripts/world/echo_spot.gd")
const CharacterModel := preload("res://scripts/characters/character_model.gd")
const MainMenu := preload("res://scripts/ui/main_menu.gd")
const RufetDialogue := preload("res://scripts/story/rufet_dialogue.gd")
const Conspiracy := preload("res://scripts/story/conspiracy.gd")
const GHOST_SHADER := preload("res://shaders/ghost.gdshader")
const GHOST_MODEL := "res://assets/characters/adventurers/Rogue_Hooded.glb"

enum Phase { MENU, INTRO, FIND_RUFET, DIALOGUE, WAVES, AFTERMATH, ECHOES, VISION, RETURN, CHAPTER_END, DEFEAT }

const WAVES := [
	{"normal": 4, "fast": 0, "elite": 0, "title": "Kül Kölgələri qalxır!"},
	{"normal": 3, "fast": 4, "elite": 0, "title": "Külün altından daha çoxu gəlir..."},
	{"normal": 3, "fast": 1, "elite": 1, "title": "Kül Cəngavəri — Tacın keçmiş keşikçisi"},
]
const ECHO_RANGE := 2.4
const NORMAL_SATURATION := 1.08

var phase := Phase.MENU
var rufet

var _echoes: Array = []
var _active_echo
var _ghost
var _ghost_mat: ShaderMaterial
var _wave := -1
var _alive := 0
var _next_wave_in := -1.0


func _make_level() -> Node3D:
	return Kozqala.new()


func _setup() -> void:
	Audio.music("ambient", 3.0)
	rufet = Companion.new()
	add_child(rufet)
	rufet.global_position = level.rufet_spot
	rufet.face(level.player_spawn)


func _begin(mode: String) -> void:
	if Settings.demo != "" and Settings.demo != "menu":
		GameState.new_game()
		set_controls(true)
	match Settings.demo:
		"menu":
			_menu()
		"pause", "settings":
			_find_rufet()
			process_mode = Node.PROCESS_MODE_ALWAYS  # keep counting frames for the capture
		"explore":
			_find_rufet()
		"dialogue":
			player.global_position = level.rufet_spot + Vector3(-2.4, 0, -1.2)
			_find_rufet()
			_talk(RufetDialogue.DATA)
		"combat", "fight":
			_resume("waves", true)
		"echoes", "echo":
			_resume("echoes")
		"journal":
			GameState.clues = GameState.echo_traits.slice(0, 2)
			_resume("echoes")
			process_mode = Node.PROCESS_MODE_ALWAYS
		"chapter_end", "victory":
			GameState.clues = GameState.echo_traits.duplicate()
			_resume("chapter_end")
		_:
			if mode == "checkpoint" and GameState.load_game():
				_continue_save()
			elif mode == "fresh":
				_start_new_game()
			else:
				_menu()


# --- Flow --------------------------------------------------------------------

## Title screen: the camera circles the ruins while Ayxan lies in the ash.
func _menu() -> void:
	phase = Phase.MENU
	hud.visible = false
	player.lie_down()
	rig.orbit(Vector3(0, 1.5, 0), 27.0)
	var menu = MainMenu.new()
	add_child(menu)
	menu.new_game.connect(_start_new_game)
	menu.continue_game.connect(func():
		if GameState.load_game():
			_leave_menu()
			_continue_save()
		else:
			_start_new_game())


func _continue_save() -> void:
	if GameState.chapter != 1:
		go_to_chapter(GameState.chapter)
		return
	_resume(GameState.checkpoint)


func _leave_menu() -> void:
	rig.release()
	hud.visible = true


func _start_new_game() -> void:
	_leave_menu()
	GameState.new_game()
	save_checkpoint("start")
	_intro()


func _resume(checkpoint: String, close_spawns := false) -> void:
	hud.visible = true
	if checkpoint == "start":
		_intro()
		return
	player.wake()
	set_controls(true)
	match checkpoint:
		"waves":
			phase = Phase.WAVES
			rufet.in_combat = true
			_start_wave(0, close_spawns)
		"echoes":
			_start_echoes()
		"return":
			_spawn_echoes()
			_begin_return()
		"chapter_end":
			_spawn_echoes()
			_chapter_end()
		_:
			_intro()


func _intro() -> void:
	phase = Phase.INTRO
	set_controls(false)
	player.lie_down()
	await hud.title_card("ASHES OF THE CROWN", "Közqala. Kül Gecəsindən üç gün sonra.", 3.2)
	await player.stand_up()
	set_controls(true)
	_find_rufet()


func _find_rufet() -> void:
	phase = Phase.FIND_RUFET
	hud.set_objective("Rüfəti tap — o, cənub darvazasındakı ocağın yanındadır")


func _tick(delta: float) -> void:
	match phase:
		Phase.FIND_RUFET:
			if near_prompt(rufet.global_position, TALK_RANGE, "[E]  Rüfətlə danış"):
				_talk(RufetDialogue.DATA)
		Phase.RETURN:
			if near_prompt(rufet.global_position, TALK_RANGE, "[E]  Rüfətə gördüklərini danış"):
				_talk(RufetDialogue.AFTER_ECHOES)
		Phase.ECHOES:
			var spot = _nearest_echo()
			if spot != null and near_prompt(spot.global_position, ECHO_RANGE, "[E]  Kül əks-sədasına toxun"):
				_play_echo(spot)
			elif spot == null:
				hud.set_prompt("")
		Phase.WAVES:
			if _alive <= 0 and _next_wave_in < 0.0:
				_next_wave_in = 2.5
			elif _next_wave_in >= 0.0:
				_next_wave_in -= delta
				if _next_wave_in < 0.0:
					_start_wave(_wave + 1)
		Phase.DEFEAT:
			if Input.is_action_just_pressed("restart"):
				restart_mode = "checkpoint"
				get_tree().reload_current_scene()
		Phase.CHAPTER_END:
			if Input.is_action_just_pressed("continue"):
				GameState.chapter = 2
				save_checkpoint("c2_start")
				go_to_chapter(2)
			elif Input.is_action_just_pressed("restart"):
				restart_mode = "fresh"
				get_tree().reload_current_scene()


func _marker_target() -> Variant:
	match phase:
		Phase.FIND_RUFET, Phase.RETURN:
			return rufet.global_position
		Phase.ECHOES:
			var spot = _nearest_echo()
			if spot != null:
				return spot.global_position
	return null


# --- Dialogue -------------------------------------------------------------------

func _talk(data: Dictionary) -> void:
	phase = Phase.DIALOGUE
	hud.set_objective("")
	talk_with(rufet, data)


func _on_dialogue_finished(event: String) -> void:
	end_talk()
	match event:
		"start_waves":
			save_checkpoint("waves")
			phase = Phase.WAVES
			rufet.in_combat = true
			_start_wave(0)
		"start_echoes":
			_start_echoes()
		"echo_done":
			_finish_echo()
		"chapter_end":
			_chapter_end()


# --- Waves ---------------------------------------------------------------------

func _start_wave(i: int, close := false) -> void:
	_wave = i
	_next_wave_in = -1.0
	if i >= WAVES.size():
		_after_waves()
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


func _after_waves() -> void:
	phase = Phase.AFTERMATH
	rufet.in_combat = false
	hud.set_objective("")
	Audio.music("ambient", 4.0)
	Audio.play("sting_victory", -2.0, 0.0)
	hud.banner("Kül yatdı. Közqala susur.")
	save_checkpoint("echoes")
	await get_tree().create_timer(2.5).timeout
	if phase == Phase.AFTERMATH:
		_talk(RufetDialogue.AFTER_WAVES)


# --- Ember echoes (clues) ---------------------------------------------------------

func _start_echoes() -> void:
	phase = Phase.ECHOES
	_spawn_echoes()
	_update_echo_objective()


func _spawn_echoes() -> void:
	if not _echoes.is_empty():
		return
	for i in Conspiracy.ECHO_SPOTS.size():
		var spot = EchoSpot.new()
		spot.index = i
		spot.trait_id = GameState.echo_traits[i]
		spot.place = Conspiracy.ECHO_SPOTS[i]["place"]
		add_child(spot)
		spot.global_position = Conspiracy.ECHO_SPOTS[i]["pos"]
		if GameState.clues.has(spot.trait_id):
			spot.extinguish()
		_echoes.append(spot)


func _update_echo_objective() -> void:
	var found := 0
	for s in _echoes:
		if s.done:
			found += 1
	hud.set_objective("Kül əks-sədalarını araşdır   (%d / 3)" % found)


func _nearest_echo():
	var best = null
	var best_d := INF
	for s in _echoes:
		if s.done:
			continue
		var d: float = player.global_position.distance_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best


## The world drains to grey and a figure of glowing ash replays one moment of the Night of Ash.
func _play_echo(spot) -> void:
	phase = Phase.VISION
	_active_echo = spot
	set_controls(false)
	hud.set_prompt("")
	hud.visible = false
	player.input_locked = true
	var info: Dictionary = Conspiracy.TRAITS[spot.trait_id]
	Audio.play("echo", -2.0, 0.0)

	var toward: Vector3 = player.global_position - spot.global_position
	toward.y = 0.0
	if toward.length() < 0.1:
		toward = Vector3(1, 0, 1)
	# Film from the side so neither figure hides the other; favour the apparition
	var side := Vector3(-toward.z, 0.0, toward.x).normalized()
	if side.dot(Vector3(1, 0, 1)) < 0.0:
		side = -side
	var focus: Vector3 = spot.global_position.lerp(player.global_position, 0.3) + Vector3(0, 1.2, 0)
	rig.cinematic(focus, rad_to_deg(atan2(side.x, side.z)))
	create_tween().tween_property(level.env, "adjustment_saturation", 0.12, 1.2)

	_ghost = CharacterModel.new()
	add_child(_ghost)
	_ghost.setup(GHOST_MODEL, Player.HIDDEN, 0.82)
	_ghost_mat = ShaderMaterial.new()
	_ghost_mat.shader = GHOST_SHADER
	_ghost_mat.set_shader_parameter("alpha", 0.0)
	_ghost.set_material_all(_ghost_mat)
	_ghost.global_position = spot.global_position
	_ghost.rotation.y = atan2(toward.x, toward.z) + PI * 0.6
	var clip: String = info["anim"]
	_ghost.play_action(clip, 0.8, 0.0)
	_ghost.action_finished.connect(func(_a): _ghost.play_action(clip, 0.8, 0.2))
	create_tween().tween_method(func(v: float): _ghost_mat.set_shader_parameter("alpha", v), 0.0, 1.0, 1.2)

	await get_tree().create_timer(1.4).timeout
	dialogue.start({
		"start": {"speaker": "Kül əks-sədası · " + spot.place, "text": info["echo"], "next": "t"},
		"t": {"speaker": "Ayxan", "text": "(%s... Bunu unutmamalıyam.)" % info["title"], "end": true, "event": "echo_done"},
	})


func _finish_echo() -> void:
	var spot = _active_echo
	GameState.add_clue(spot.trait_id)
	spot.extinguish()
	var ghost = _ghost
	var tw := create_tween()
	tw.tween_method(func(v: float): _ghost_mat.set_shader_parameter("alpha", v), 1.0, 0.0, 1.0)
	tw.tween_callback(ghost.queue_free)
	create_tween().tween_property(level.env, "adjustment_saturation", NORMAL_SATURATION, 1.5)
	Audio.play("memory_burn", -8.0, 0.1)
	hud.banner("Yeni sübut: %s   ·   Tab — jurnal" % Conspiracy.TRAITS[spot.trait_id]["title"])
	set_controls(true)
	if GameState.clues.size() >= Conspiracy.ECHO_SPOTS.size():
		save_checkpoint("return")
		_begin_return()
	else:
		phase = Phase.ECHOES
		save_checkpoint("echoes")
		_update_echo_objective()


func _begin_return() -> void:
	phase = Phase.RETURN
	hud.set_objective("Rüfətin yanına qayıt")


# --- Endings -----------------------------------------------------------------------

func _on_player_died() -> void:
	phase = Phase.DEFEAT
	rufet.in_combat = false
	hud.set_objective("")
	Audio.music("", 1.0)
	Audio.play("sting_defeat", -2.0, 0.0)
	await get_tree().create_timer(1.2).timeout
	hud.show_card("KÖZ SÖNDÜ", "Ayxan külün içində yıxıldı.", "[R] — son nöqtədən davam et   ·   [Esc] — menyu", 0.75)


func _chapter_end() -> void:
	phase = Phase.CHAPTER_END
	save_checkpoint("chapter_end")
	player.input_locked = true
	hud.set_objective("")
	hud.set_prompt("")
	Audio.music("ambient", 4.0)
	Audio.play("sting_victory", -2.0, 0.0)

	var lines := PackedStringArray()
	var titles := PackedStringArray()
	for t in GameState.clues:
		titles.append(Conspiracy.TRAITS[t]["title"])
	lines.append("Sübutlar: " + (", ".join(titles) if not titles.is_empty() else "yoxdur"))
	var matching := GameState.suspects_matching()
	if matching.size() == 1:
		lines.append("Bütün izlər bir nəfərə aparır. Amma sübut hökm deyil — hələ yox.")
	else:
		lines.append("Şübhəlilər: %d nəfər." % matching.size())
	var burned: int = Memory.burned.size()
	lines.append("Yanmış xatirələr: %d / %d" % [burned, Memory.MEMORIES.size()])
	if Memory.is_burned("rufet_face"):
		lines.append("Rüfət yanında addımlayır — tanımadığın bir üzlə.")
	elif GameState.flags.has("rufet_deflected"):
		lines.append("Rüfətin gözləri sənin gözlərindən qaçır.")
	elif GameState.flags.has("clue_letter"):
		lines.append("Sabirin möhürlü məktubu hələ də ağlından çıxmır.")
	if burned >= 4:
		lines.append("\"...yaxınlaşırsan, Ayxan. Tac səni gözləyir...\"  — Kül Şahı")
	lines.append("")
	lines.append("[Enter] — Fəsil 2: Son Ocaq   ·   [R] — yeni oyun   ·   [Esc] — menyu")
	await get_tree().create_timer(1.2).timeout
	hud.show_card("FƏSİL 1 BİTDİ", "Birinci səhər", "\n".join(lines), 0.82)


# --- Debug capture -----------------------------------------------------------------

func _demo_actions() -> void:
	super._demo_actions()
	if Settings.demo == "echo" and _frame == 30:
		player.global_position = _echoes[0].global_position + Vector3(1.6, 0, 1.6)
		_play_echo(_echoes[0])
	if Settings.demo != "combat" or Settings.capture_path == "":
		return
	if _frame == Settings.capture_frame - 60:
		player.attack()
	elif _frame == Settings.capture_frame - 30:
		player.ember_power()
