extends "res://scripts/chapter_base.gd"
## Chapter 2 "Son Ocaq": the survivors' caravanserai. Ayxan questions the eight
## suspects (alibis, clues, what they saw). After four conversations the gate is
## opened from inside and shades flood the camp — and two people are missing while
## it happens. Then, at the hearth, Ayxan names the traitor:
##   right  → the traitor confesses, burns into ash and rises as a boss;
##   wrong  → an innocent is exiled and the real traitor's final assault follows.
##
## Checkpoints: c2_start, c2_after_attack, c2_end.

const SonOcaq := preload("res://scripts/world/son_ocaq.gd")
const Survivor := preload("res://scripts/npc/survivor.gd")
const AshShade := preload("res://scripts/enemies/ash_shade.gd")
const Interrogation := preload("res://scripts/story/interrogation.gd")
const Conspiracy := preload("res://scripts/story/conspiracy.gd")

enum Phase { INTRO, INVESTIGATE, TALK, ATTACK, AFTER_ATTACK, COUNCIL, BOSS, FINAL_ASSAULT, END, DEFEAT }

const TALKS_BEFORE_ATTACK := 4
const HEARTH_TALK_RANGE := 3.4

var phase := Phase.INTRO
var survivors := {}   # id -> Survivor

var _talking
var _alive := 0
var _waves: Array = []
var _good_ending := false


func _make_level() -> Node3D:
	return SonOcaq.new()


func _setup() -> void:
	Audio.music("ambient", 3.0)
	for id in Conspiracy.SUSPECTS:
		var s = Survivor.new()
		s.setup(id)
		s.hearth = level.hearth
		s.yard = level.YARD - 3.0
		s.hide_spot = level.hide_spots[survivors.size() % level.hide_spots.size()]
		s.gate_inside = level.gate_inside
		s.gate_outside = level.gate_outside
		add_child(s)
		survivors[id] = s


func _begin(mode: String) -> void:
	if Settings.demo != "":
		GameState.new_game()
		GameState.chapter = 2
		GameState.clues = GameState.echo_traits.duplicate()
		set_controls(true)
		player.wake()
		match Settings.demo:
			"c2_talk":
				var target = survivors["sabir"]
				player.global_position = target.global_position + Vector3(1.8, 0, 1.2)
				_investigate()
				_talk_to(target)
			"c2_attack":
				_investigate()
				_night_attack()
			"c2_council":
				GameState.flags["attack_done"] = true
				_investigate()
				player.global_position = level.hearth + Vector3(0, 0, 2.6)
				_open_council()
			"c2_boss":
				GameState.flags["attack_done"] = true
				_accuse(GameState.traitor)
			"c2_bossfight":
				GameState.flags["attack_done"] = true
				player.global_position = survivors[GameState.traitor].global_position + Vector3(3, 0, 3)
				_traitor_boss()
			_:
				_investigate()
		return
	if mode == "checkpoint" and GameState.load_game():
		_resume(GameState.checkpoint)
	else:
		_resume("c2_start")


func _resume(checkpoint: String) -> void:
	match checkpoint:
		"c2_after_attack":
			player.wake()
			set_controls(true)
			_hide_exiled()
			_investigate()
		"c2_end":
			player.wake()
			_chapter_end()
		_:
			_intro()


func _intro() -> void:
	phase = Phase.INTRO
	set_controls(false)
	player.input_locked = true
	await hud.title_card("SON OCAQ", "Köhnə karvansara. Kül Gecəsindən dörd gün sonra.", 3.0)
	player.input_locked = false
	set_controls(true)
	hud.banner("Satqın bu insanların arasındadır")
	_investigate()


func _investigate() -> void:
	phase = Phase.INVESTIGATE
	_update_objective()


func _update_objective() -> void:
	var n: int = GameState.talked.size()
	if GameState.flags.has("attack_done"):
		hud.set_objective("Sağ qalanları sorğu-suala tut (%d / 8)   ·   Hazır olanda Ocaqda divan qur" % n)
	else:
		hud.set_objective("Sağ qalanları sorğu-suala tut   (%d / 8)" % n)


func _tick(_delta: float) -> void:
	match phase:
		Phase.INVESTIGATE:
			var s = _nearest_survivor(TALK_RANGE)
			if s != null and near_prompt(s.global_position, TALK_RANGE, "[E]  %s ilə danış" % s.display_name):
				_talk_to(s)
			elif s == null and GameState.flags.has("attack_done"):
				if near_prompt(level.hearth, HEARTH_TALK_RANGE, "[E]  Divan qur — satqını ittiham et"):
					_open_council()
			elif s == null:
				hud.set_prompt("")
		Phase.DEFEAT:
			if Input.is_action_just_pressed("restart"):
				restart_mode = "checkpoint"
				get_tree().reload_current_scene()
		Phase.END:
			if Input.is_action_just_pressed("restart"):
				go_to_chapter(1, "fresh")
	if phase in [Phase.ATTACK, Phase.BOSS, Phase.FINAL_ASSAULT] and _alive <= 0 and not _waves.is_empty():
		_next_wave()


func _marker_target() -> Variant:
	if phase == Phase.INVESTIGATE and GameState.flags.has("attack_done") and GameState.talked.size() >= TALKS_BEFORE_ATTACK:
		return level.hearth
	return null


func _nearest_survivor(dist: float):
	var best = null
	var best_d := dist
	for s in survivors.values():
		if not is_instance_valid(s) or s.mode != Survivor.Mode.LIVE and s.mode != Survivor.Mode.HOLD:
			continue
		var d: float = player.global_position.distance_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best


# --- Conversations ------------------------------------------------------------------

func _talk_to(s) -> void:
	phase = Phase.TALK
	_talking = s
	s.hold(true)
	hud.set_objective("")
	talk_with(s, Interrogation.build(s.id), false)


func _open_council() -> void:
	phase = Phase.COUNCIL
	hud.set_objective("")
	# Everyone gathers round the hearth
	var i := 0
	var present := survivors.values().filter(func(s): return is_instance_valid(s) and s.visible)
	for s in present:
		var a := TAU * i / present.size()
		s.global_position = level.hearth + Vector3(cos(a), 0, sin(a)) * 3.6
		s.face(level.hearth)
		s.hold(true)
		i += 1
	player.global_position = level.hearth + Vector3(0, 0, 4.6)
	player.face_towards(level.hearth)
	hud.visible = false
	player.input_locked = true
	rig.cinematic(level.hearth + Vector3(0, 1.4, 0), 25.0)
	dialogue.start(Interrogation.accusation())


func _on_dialogue_finished(event: String) -> void:
	end_talk()
	if is_instance_valid(_talking):
		_talking.hold(false)
	_talking = null
	if event.begins_with("accuse:"):
		_accuse(event.get_slice(":", 1))
		return
	match event:
		"talk_end":
			_investigate()
			if GameState.talked.size() >= TALKS_BEFORE_ATTACK and not GameState.flags.has("attack_started"):
				_night_attack()
		"accuse_cancel":
			_release_council()
			_investigate()
		"attack_report":
			_investigate()
		"traitor_revealed":
			_traitor_boss()
		"wrong_verdict":
			_final_assault()
		_:
			_investigate()


func _release_council() -> void:
	for s in survivors.values():
		if is_instance_valid(s):
			s.hold(false)


# --- The night attack ------------------------------------------------------------------

## Someone opens the gate from inside. The traitor and one innocent are missing while it happens.
func _night_attack() -> void:
	phase = Phase.ATTACK
	GameState.set_flag("attack_started")
	var innocents := Conspiracy.SUSPECTS.keys().filter(func(id): return id != GameState.traitor)
	GameState.absent = [GameState.traitor, innocents.pick_random()]
	GameState.absent.shuffle()
	for id in survivors:
		var s = survivors[id]
		if GameState.absent.has(id):
			s.slip_away()
		else:
			s.flee()
	hud.set_prompt("")
	hud.set_objective("Düşərgəni qoru!")
	hud.banner("Darvaza içəridən açıldı! Kölgələr düşərgədədir!")
	Audio.play("horn", -2.0, 0.0)
	Audio.music("battle", 1.0)
	Fx.shake(0.5)
	_waves = [["normal", "normal", "fast", "normal"], ["fast", "fast", "normal", "normal", "fast"]]
	_next_wave()


func _next_wave() -> void:
	if _waves.is_empty():
		return
	var kinds: Array = _waves.pop_front()
	_alive = kinds.size()
	for k in kinds:
		_spawn(k)
		await get_tree().create_timer(0.35).timeout
	if _waves.is_empty():
		_waves_done_check()


func _waves_done_check() -> void:
	while _alive > 0:
		await get_tree().process_frame
		if phase == Phase.DEFEAT:
			return
	match phase:
		Phase.ATTACK:
			_after_attack()
		Phase.BOSS:
			_good_ending = true
			_chapter_end()
		Phase.FINAL_ASSAULT:
			_good_ending = false
			_chapter_end()


func _spawn(kind: String, name_override := "") -> void:
	var e = AshShade.new()
	e.configure(kind)
	if name_override != "":
		e.display_name = name_override
		e.max_health = 420.0
		e.health = 420.0
	add_child(e)
	var points: Array = level.spawn_points
	e.global_position = points.pick_random() + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))
	e.target = player
	e.killed.connect(func(_x): _on_killed())
	if kind == "elite":
		hud.track_boss(e)


func _on_killed() -> void:
	_alive -= 1
	if _alive <= 0:
		Fx.slowmo(0.25, 0.8)
		Fx.punch(0.8)


func _after_attack() -> void:
	phase = Phase.AFTER_ATTACK
	Audio.music("ambient", 3.0)
	Audio.play("sting_victory", -2.0, 0.0)
	for s in survivors.values():
		s.return_to_camp()
	GameState.set_flag("attack_done")
	save_checkpoint("c2_after_attack")
	hud.banner("Kölgələr geri çəkildi")
	await get_tree().create_timer(2.0).timeout
	# A witness who stayed in the camp reports who was missing
	var witness = null
	for id in ["rufet", "sahbaz", "sabir", "esref"]:
		if not GameState.absent.has(id):
			witness = survivors[id]
			break
	var a: String = Interrogation.display_name(GameState.absent[0])
	var b: String = Interrogation.display_name(GameState.absent[1])
	_talking = witness
	witness.hold(true)
	talk_with(witness, {
		"start": {"speaker": witness.display_name, "text": "Ayxan! Darvazanın cəftəsi içəridən qaldırılıb. Kimsə onları özü içəri buraxdı.", "next": "b"},
		"b": {"speaker": witness.display_name, "text": "Hücum başlayanda hamı ocağın ətrafında idi... %s və %s istisna olmaqla. İkisi də yox idi." % [a, b], "next": "c"},
		"c": {"speaker": "Ayxan", "text": "(İki ad. Biri satqındır, biri isə sadəcə qorxub qaçıb. İzlərlə tutuşdurmalıyam.)", "end": true, "event": "attack_report"},
	})


func _hide_exiled() -> void:
	if GameState.accused != "" and survivors.has(GameState.accused):
		survivors[GameState.accused].queue_free()
		survivors.erase(GameState.accused)


# --- The verdict -----------------------------------------------------------------------

func _accuse(id: String) -> void:
	GameState.accused = id
	if id == GameState.traitor:
		_talking = survivors[id]
		talk_with(survivors[id], Interrogation.confession(id), false)
	else:
		_talking = survivors[id]
		talk_with(survivors[id], Interrogation.wrong_verdict(id), false)


## The traitor burns into ash and rises as the Külün Xaini.
func _traitor_boss() -> void:
	phase = Phase.BOSS
	_release_council()
	for s in survivors.values():
		if is_instance_valid(s) and s.id != GameState.traitor:
			s.flee()
	var t = survivors[GameState.traitor]
	var pos: Vector3 = t.global_position
	Fx.death_burst(pos, 1.6)
	Fx.fire_nova(pos, 4.0)
	Audio.play("boss_roar", 0.0, 0.0)
	t.queue_free()
	survivors.erase(GameState.traitor)
	hud.set_objective("")
	hud.banner("%s — Külün Xaini" % Interrogation.display_name(GameState.traitor))
	Audio.music("battle", 0.5)
	_alive = 1
	var boss = AshShade.new()
	boss.configure("elite")
	boss.display_name = "%s — Külün Xaini" % Interrogation.display_name(GameState.traitor)
	boss.max_health = 420.0
	boss.health = 420.0
	add_child(boss)
	boss.global_position = pos
	boss.target = player
	boss.killed.connect(func(_x): _on_killed())
	hud.track_boss(boss)
	_waves = []
	# Ash servants join the fight shortly after
	await get_tree().create_timer(4.0).timeout
	if phase == Phase.BOSS and _alive > 0:
		_alive += 3
		for k in ["normal", "fast", "normal"]:
			_spawn(k)
	_waves_done_check()


## An innocent is exiled; the real traitor answers with everything they have left.
func _final_assault() -> void:
	phase = Phase.FINAL_ASSAULT
	var exiled = survivors[GameState.accused]
	exiled.exile()
	survivors.erase(GameState.accused)
	for id in survivors:
		GameState.change_trust(id, -10)
	_release_council()
	save_checkpoint("c2_after_attack")
	await get_tree().create_timer(3.0).timeout
	for s in survivors.values():
		s.flee()
	hud.banner("Gecənin sonu: kül yenidən qalxır!")
	Audio.play("horn", -2.0, 0.0)
	Audio.music("battle", 1.0)
	_waves = [["normal", "normal", "fast", "fast"], ["elite", "normal", "fast"]]
	_next_wave()


# --- Endings -----------------------------------------------------------------------------

func _on_player_died() -> void:
	phase = Phase.DEFEAT
	hud.set_objective("")
	Audio.music("", 1.0)
	Audio.play("sting_defeat", -2.0, 0.0)
	await get_tree().create_timer(1.2).timeout
	hud.show_card("KÖZ SÖNDÜ", "Son Ocaq qaranlığa qərq oldu.", "[R] — son nöqtədən davam et   ·   [Esc] — menyu", 0.75)


func _chapter_end() -> void:
	phase = Phase.END
	if GameState.checkpoint != "c2_end":
		GameState.flags["c2_good"] = _good_ending
	_good_ending = GameState.flags.get("c2_good", false)
	save_checkpoint("c2_end")
	player.input_locked = true
	hud.set_objective("")
	hud.set_prompt("")
	Audio.music("ambient", 4.0)
	Audio.play("sting_victory" if _good_ending else "sting_defeat", -2.0, 0.0)
	var traitor_name := Interrogation.display_name(GameState.traitor)
	var lines := PackedStringArray()
	if _good_ending:
		lines.append("Satqın %s idi. Kül onu qəbul etdi və geri qaytarmadı." % traitor_name)
		lines.append("Ölməzdən əvvəl pıçıldadı: \"Kral... özü istəyirdi... Kül Şahı səni gözləyir...\"")
	else:
		lines.append("Günahsız %s sürgün edildi." % Interrogation.display_name(GameState.accused))
		lines.append("Satqın isə hələ də Son Ocağın ətrafında oturub. Sənə gülümsəyir.")
	lines.append("Yanmış xatirələr: %d / %d" % [Memory.burned.size(), Memory.MEMORIES.size()])
	lines.append("")
	lines.append("FƏSİL 3 — tezliklə")
	lines.append("[R] — yeni oyun   ·   [Esc] — menyu")
	await get_tree().create_timer(1.2).timeout
	hud.show_card("FƏSİL 2 BİTDİ", "Son Ocaq" + ("" if _good_ending else " — satqın qaçdı"), "\n".join(lines), 0.82)
