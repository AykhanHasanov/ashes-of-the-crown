extends "res://scripts/chapter_base.gd"
## Chapter 2 "Son Ocaq": the survivors' caravanserai.
##
## Interim state (V2 phase 1): Ayxan arrives, the eight survivors live their
## needs-driven lives around the hearth and greet him when spoken to. The day/night
## structure, hearth defence, bonds and quests arrive in phase 5.
##
## Checkpoints: c2_start.

const SonOcaq := preload("res://scripts/world/son_ocaq.gd")
const Survivor := preload("res://scripts/npc/survivor.gd")
const Survivors := preload("res://scripts/story/survivors.gd")

enum Phase { INTRO, EXPLORE, TALK, DEFEAT }

var phase := Phase.INTRO
var survivors := {}   # id -> Survivor

var _talking


func _make_level() -> Node3D:
	return SonOcaq.new()


func _setup() -> void:
	Audio.music("ambient", 3.0)
	for id in Survivors.ORDER:
		var s = Survivor.new()
		s.setup(id)
		s.hearth = level.hearth
		s.yard = level.YARD - 3.0
		s.hide_spot = level.hide_spots[survivors.size() % level.hide_spots.size()]
		add_child(s)
		survivors[id] = s


func _begin(mode: String) -> void:
	if Settings.demo != "":
		GameState.new_game()
		GameState.chapter = 2
		set_controls(true)
		player.wake()
		if Settings.demo == "c2_talk":
			var target = survivors["sabir"]
			player.global_position = target.global_position + Vector3(1.8, 0, 1.2)
			_explore()
			_talk_to(target)
		else:
			_explore()
		return
	if mode == "checkpoint":
		GameState.load_game()
	_intro()


func _intro() -> void:
	phase = Phase.INTRO
	set_controls(false)
	player.input_locked = true
	await hud.title_card("SON OCAK", "Kül Gecesi'nden dört gün sonra.", 3.0)
	player.input_locked = false
	set_controls(true)
	_explore()


func _explore() -> void:
	phase = Phase.EXPLORE
	hud.set_objective("Hayatta kalanlarla tanış")


func _tick(_delta: float) -> void:
	match phase:
		Phase.EXPLORE:
			var s = _nearest_survivor(TALK_RANGE)
			if s != null and near_prompt(s.global_position, TALK_RANGE, "[E]  %s ile konuş" % s.display_name):
				_talk_to(s)
			elif s == null:
				hud.set_prompt("")
		Phase.DEFEAT:
			if Input.is_action_just_pressed("restart"):
				restart_mode = "checkpoint"
				get_tree().reload_current_scene()


func _nearest_survivor(dist: float):
	var best = null
	var best_d := dist
	for s in survivors.values():
		if not is_instance_valid(s) or s.mode == Survivor.Mode.FLEE:
			continue
		var d: float = player.global_position.distance_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best


func _talk_to(s) -> void:
	phase = Phase.TALK
	_talking = s
	s.hold(true)
	hud.set_objective("")
	var p: Dictionary = Survivors.PEOPLE[s.id]
	var greet: String = p["greet"]
	if s.id == "rufet" and Memory.is_burned("rufet_face"):
		greet = "Ayxan. Yine beni tanımıyorsun, değil mi? Önemli değil. Ben buradayım."
	talk_with(s, {"start": {"speaker": s.display_name, "text": greet, "end": true, "event": "talk_end"}}, false)


func _on_dialogue_finished(_event: String) -> void:
	end_talk()
	if is_instance_valid(_talking):
		_talking.hold(false)
	_talking = null
	_explore()


func _on_player_died() -> void:
	phase = Phase.DEFEAT
	hud.set_objective("")
	Audio.music("", 1.0)
	Audio.play("sting_defeat", -2.0, 0.0)
	await get_tree().create_timer(1.2).timeout
	hud.show_card("KÖZ SÖNDÜ", "Son Ocak karanlığa gömüldü.", "[R] — son noktadan devam et   ·   [Esc] — menü", 0.75)
