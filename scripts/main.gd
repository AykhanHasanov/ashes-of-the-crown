extends "res://scripts/chapter_base.gd"
## Chapter 1 "İlk sabah" (also hosts the title screen): the protagonist rises from the
## ash → Rüfət → three waves of ash shades → three Kül əks-sədaları (ember echoes)
## that replay the king's last night → back to Rüfət → chapter end,
## from where Enter leads on to Chapter 2 (Son Ocaq).
##
## Checkpoints: start, waves, echoes, return, chapter_end.

const Names := preload("res://scripts/core/names.gd")
const Kozqala := preload("res://scripts/world/kozqala.gd")
const AshShade := preload("res://scripts/enemies/ash_shade.gd")
const Companion := preload("res://scripts/npc/companion.gd")
const EchoSpot := preload("res://scripts/world/echo_spot.gd")
const CharacterModel := preload("res://scripts/characters/character_model.gd")
const MainMenu := preload("res://scripts/ui/main_menu.gd")
const RufetDialogue := preload("res://scripts/story/rufet_dialogue.gd")
const KingEchoes := preload("res://scripts/story/king_echoes.gd")
const GHOST_SHADER := preload("res://shaders/ghost.gdshader")
const GHOST_MODEL := "res://assets/characters/adventurers/Rogue_Hooded.glb"

enum Phase { MENU, INTRO, FIND_RUFET, DIALOGUE, WAVES, AFTERMATH, ECHOES, VISION, RETURN, CHAPTER_END, DEFEAT }

const WAVES := [
	{"normal": 4, "fast": 0, "elite": 0, "title": "Kül Gölgeleri kalkıyor!"},
	{"normal": 3, "fast": 4, "elite": 0, "title": "Külün altından daha fazlası geliyor..."},
	{"normal": 3, "fast": 1, "elite": 1, "title": "Kül Şövalyesi — Tacın eski muhafızı"},
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
		WorldState.new_game()   # in memory only: SaveManager never writes during a --demo
		set_controls(true)
	match Settings.demo:
		"menu":
			_menu()
		"pause", "settings", "keys":
			_find_rufet()
			process_mode = Node.PROCESS_MODE_ALWAYS  # keep counting frames for the capture
		"explore", "radial", "offer", "whirl", "unstoppable":
			_find_rufet()
		"strike":
			_resume("waves", true)
		"dialogue":
			player.global_position = level.rufet_spot + Vector3(-2.4, 0, -1.2)
			_find_rufet()
			_talk(RufetDialogue.DATA)
		"combat", "fight":
			_resume("waves", true)
		"echoes", "echo":
			_resume("echoes")
		"journal":
			WorldState.set_echoes_seen([0, 1])
			_resume("echoes")
			process_mode = Node.PROCESS_MODE_ALWAYS
		"chapter_end", "victory":
			WorldState.set_echoes_seen([0, 1, 2])
			_resume("chapter_end")
		_:
			if mode == "checkpoint" and SaveManager.load_slot(SaveManager.active_slot if SaveManager.active_slot > 0 else SaveManager.most_recent_slot()):
				_continue_save()
			elif mode == "fresh":
				_start_v2()   # V2's own restart after its chapter end, and the dev menu's V2 entry
			else:
				_menu()


# --- Flow --------------------------------------------------------------------

## Title screen: the camera circles the ruins while the protagonist lies in the ash.
func _menu() -> void:
	phase = Phase.MENU
	hud.visible = false
	WorldState.session_active = false
	SaveManager.import_legacy_saves()   # once: folds the old two-file saves into slot 1
	player.lie_down()
	rig.orbit(Vector3(0, 1.5, 0), 27.0)
	var menu = MainMenu.new()
	add_child(menu)
	menu.new_game.connect(_start_new_game)
	menu.continue_game.connect(func():   # the menu has already loaded the slot
		_leave_menu()
		_continue_save())


## Regions that have their own scene; any other region is a V2 chapter.
const NEW_GAME_REGION := &"kur_vadisi"
const REGION_SCENES := {&"kur_vadisi": "res://scenes/world.tscn", &"son_ocaq": "res://scenes/son_ocaq.tscn",
	&"kartal_yamaci": "res://scenes/kartal_yamaci.tscn"}


func _continue_save() -> void:
	if REGION_SCENES.has(WorldState.get_region()):
		restart_mode = "checkpoint"
		get_tree().change_scene_to_file(REGION_SCENES[WorldState.get_region()])
		return
	if WorldState.get_chapter() != 1:
		go_to_chapter(WorldState.get_chapter())
		return
	_resume(WorldState.get_checkpoint())


func _leave_menu() -> void:
	rig.release()
	hud.visible = true


## New Game: the slice starts in Kür Vadisi (the cold open S0 comes before it in phase C).
func _start_new_game() -> void:
	prepare_new_game()
	restart_mode = "new"
	get_tree().change_scene_to_file(REGION_SCENES[WorldState.get_region()])


## The state of a new game (the menu has already chosen SaveManager.active_slot). The region
## change autosaves into that slot.
static func prepare_new_game() -> void:
	WorldState.new_game()
	WorldState.set_region(NEW_GAME_REGION)


## V2's Chapter 1 (legacy; reached only from the world's F10 menu).
func _start_v2() -> void:
	_leave_menu()
	WorldState.new_game()
	WorldState.set_region(&"kozqala")
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
	await hud.title_card("ASHES OF THE CROWN", "Közkale. Kül Gecesi'nden üç gün sonra.", 3.2)
	await player.stand_up()
	set_controls(true)
	_find_rufet()


func _find_rufet() -> void:
	phase = Phase.FIND_RUFET
	hud.set_objective("Rüfet'i bul — güney kapısındaki ocağın yanında")


func _tick(delta: float) -> void:
	match phase:
		Phase.FIND_RUFET:
			if near_prompt(rufet.global_position, TALK_RANGE, "[E]  Rüfet'le konuş"):
				_talk(RufetDialogue.DATA)
		Phase.RETURN:
			if near_prompt(rufet.global_position, TALK_RANGE, "[E]  Rüfet'e gördüklerini anlat"):
				_talk(RufetDialogue.AFTER_ECHOES)
		Phase.ECHOES:
			var spot = _nearest_echo()
			if spot != null and near_prompt(spot.global_position, ECHO_RANGE, "[E]  Kül yankısına dokun"):
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
				WorldState.set_chapter(2)
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
	if i == 0:
		player.begin_encounter()  # the wave block is one fight for Kül Şahı's offer
	hud.set_objective("Dalga %d / %d" % [i + 1, WAVES.size()])
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
	hud.banner("Kül dindi. Közkale susuyor.")
	save_checkpoint("echoes")
	await get_tree().create_timer(2.5).timeout
	if phase == Phase.AFTERMATH:
		_talk(RufetDialogue.AFTER_WAVES)


# --- Ember echoes (the king's last night) ---------------------------------------------------------

func _start_echoes() -> void:
	phase = Phase.ECHOES
	_spawn_echoes()
	_update_echo_objective()


func _spawn_echoes() -> void:
	if not _echoes.is_empty():
		return
	for i in KingEchoes.ECHOES.size():
		var spot = EchoSpot.new()
		spot.index = i
		spot.place = KingEchoes.ECHOES[i]["place"]
		add_child(spot)
		spot.global_position = KingEchoes.ECHOES[i]["pos"]
		if i in WorldState.echoes_seen():
			spot.extinguish()
		_echoes.append(spot)


func _update_echo_objective() -> void:
	var found := 0
	for s in _echoes:
		if s.done:
			found += 1
	hud.set_objective("Kül yankılarını araştır   (%d / 3)" % found)


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
	var info: Dictionary = KingEchoes.ECHOES[spot.index]
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
	var words: String = KingEchoes.SILENT if WorldState.has_burned(&"father_voice") else "Kral: \"%s\"" % info["words"]
	dialogue.start({
		"start": {"speaker": "Kül yankısı · " + spot.place, "text": info["scene"], "next": "t"},
		"t": {"speaker": "Kül yankısı · " + spot.place, "text": words, "end": true, "event": "echo_done"},
	})


func _finish_echo() -> void:
	var spot = _active_echo
	WorldState.mark_echo_seen(spot.index)
	spot.extinguish()
	var ghost = _ghost
	var tw := create_tween()
	tw.tween_method(func(v: float): _ghost_mat.set_shader_parameter("alpha", v), 1.0, 0.0, 1.0)
	tw.tween_callback(ghost.queue_free)
	create_tween().tween_property(level.env, "adjustment_saturation", NORMAL_SATURATION, 1.5)
	Audio.play("memory_burn", -8.0, 0.1)
	hud.banner("%s — kralın son gecesinden bir an" % spot.place)
	set_controls(true)
	if WorldState.echoes_seen().size() >= KingEchoes.ECHOES.size():
		save_checkpoint("return")
		_begin_return()
	else:
		phase = Phase.ECHOES
		save_checkpoint("echoes")
		_update_echo_objective()


func _begin_return() -> void:
	phase = Phase.RETURN
	hud.set_objective("Rüfet'in yanına dön")


# --- Endings -----------------------------------------------------------------------

func _on_player_died() -> void:
	phase = Phase.DEFEAT
	rufet.in_combat = false
	hud.set_objective("")
	Audio.music("", 1.0)
	Audio.play("sting_defeat", -2.0, 0.0)
	await get_tree().create_timer(1.2).timeout
	hud.show_card("KÖZ SÖNDÜ", Names.fill("{PROTAGONIST} külün içine yığıldı."), "[R] — son noktadan devam et   ·   [Esc] — menü", 0.75)


func _chapter_end() -> void:
	phase = Phase.CHAPTER_END
	save_checkpoint("chapter_end")
	player.input_locked = true
	hud.set_objective("")
	hud.set_prompt("")
	Audio.music("ambient", 4.0)
	Audio.play("sting_victory", -2.0, 0.0)

	var lines := PackedStringArray()
	lines.append("Görülen yankılar: %d / %d" % [WorldState.echoes_seen().size(), KingEchoes.ECHOES.size()])
	var burned: int = Memory.burned_count()
	lines.append("Yanan hatıralar: %d / %d" % [burned, Memory.combat_memories().size()])
	if WorldState.has_burned(&"rufet_face"):
		lines.append("Rüfet'i tanımıyorsun, ama o seni tanıyor.")
	else:
		lines.append("Rüfet yanında. Yüzünü hâlâ hatırlıyorsun.")
	if burned >= 4:
		lines.append(Names.fill("\"...yaklaşıyorsun, {PROTAGONIST}. Taç seni bekliyor...\"  — Kül Şahı", &"kul_sahi"))
	lines.append("")
	lines.append("[Enter] — Bölüm 2: Son Ocak   ·   [R] — yeni oyun   ·   [Esc] — menü")
	await get_tree().create_timer(1.2).timeout
	hud.show_card("BÖLÜM 1 SONA ERDİ", "İlk sabah", "\n".join(lines), 0.82)


# --- Debug capture -----------------------------------------------------------------

func _demo_actions() -> void:
	super._demo_actions()
	if Settings.demo == "echo" and _frame == 30:
		player.global_position = _echoes[0].global_position + Vector3(1.6, 0, 1.6)
		_play_echo(_echoes[0])
	match Settings.demo:
		"radial":
			if _frame == 40:
				player._open_wheel()
			if _frame == 70:
				radial.selected = "first_sword"
		"offer":
			if _frame == 40:
				player.begin_encounter()
				player.take_damage(90.0)
		"strike":
			if _frame == Settings.capture_frame - 12:
				player.gain_ember(100.0)
				player.ember_strike()
		"whirl", "unstoppable":
			if _frame == 5:
				var e = AshShade.new()
				e.configure("elite" if Settings.demo == "whirl" else "normal")
				add_child(e)
				e.global_position = player.global_position + Vector3(0, 0, -2.2)
				e.target = player
			if Settings.demo == "whirl" and _frame in [100, 106, 112]:
				for e in get_tree().get_nodes_in_group("enemies"):
					e.take_damage(5.0)
			if Settings.demo == "unstoppable":
				_check_unstoppable_and_perfect()
	if Settings.demo != "combat" or Settings.capture_path == "":
		return
	if _frame == Settings.capture_frame - 60:
		player.attack()
	elif _frame == Settings.capture_frame - 30:
		player.cast_wave(Memory.unburned()[0]["id"])


var _checked_unstoppable := false
var _checked_perfect := false


## Debug self-test: a hit during the white-hot windup must not stagger; a dodge
## started just before the blow lands must count as perfect.
func _check_unstoppable_and_perfect() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		var tts: float = e.time_to_strike()
		if not _checked_unstoppable and tts < 0.3 and tts > 0.15:
			_checked_unstoppable = true
			var hp_before: float = e.health
			e.take_damage(1.0)
			print("SELFTEST unstoppable: still attacking=%s (health %.0f -> %.0f)" % [e.is_attacking(), hp_before, e.health])
		if _checked_unstoppable and not _checked_perfect and tts <= 0.1:
			_checked_perfect = true
			var ember_before: float = player.ember
			player.dash(Vector3.RIGHT)
			print("SELFTEST perfect dodge: ember %.0f -> %.0f" % [ember_before, player.ember])
			await get_tree().process_frame
			await get_tree().process_frame
			print("SELFTEST perfect dodge slow motion: time_scale=%.2f" % Engine.time_scale)