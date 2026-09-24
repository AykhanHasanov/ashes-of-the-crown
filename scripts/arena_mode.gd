extends "res://scripts/chapter_base.gd"
## V3 phase A test arena: the new third-person combat against the three test
## enemies (Kül Kölgəsi, Qalxanlı quldur, Canavar). Waves keep coming; resting at
## the hearth (E) refills flasks, heals and starts the next wave. F10 opens the
## debug panel: spawn any enemy, switch weapons, burn or restore memories.

const Arena := preload("res://scripts/world/arena.gd")
const Ayxan := preload("res://scripts/player_v3/ayxan.gd")
const TPCamera := preload("res://scripts/camera/third_person_camera.gd")
const Foe := preload("res://scripts/enemies/foe.gd")
const SelfTest := preload("res://scripts/debug/combat_selftest.gd")
const DebugMenu := preload("res://scripts/debug/debug_menu.gd")

const WAVES := [
	["ash_shade", "ash_shade"],
	["wolf", "wolf", "wolf"],
	["bandit_shield", "ash_shade", "ash_shade"],
	["bandit_shield", "wolf", "wolf", "ash_shade"],
	["bandit_shield", "bandit_shield", "ash_shade", "wolf", "wolf"],
]
const HINT := "LMB yüngül · F ağır · RMB blok/parry · Space yayınma · Shift qaçış · C kilid\nE infaz/ocaq · R şərbət · Q köz · 1-3 silah · F10 debug"

var debug
var _wave := 0
var _alive := 0
var _resting := true


func _make_level() -> Node3D:
	return Arena.new()


func _make_player() -> Node3D:
	return Ayxan.new()


func _make_camera() -> Node3D:
	return TPCamera.new()


func _setup() -> void:
	Audio.music("ambient", 2.0)
	hud.set_hint(HINT)
	debug = DebugMenu.new()
	add_child(debug)
	_build_debug()


func _begin(_mode: String) -> void:
	GameState.new_game()
	GameState.set_flag("wave_confirmed")
	set_controls(true)
	player.wake()
	hud.set_objective("Test arenası — ocaqda [E] ilə növbəti dalğanı başlat")
	hud.banner("Döyüş nüvəsi · Faza A")
	match Settings.demo:
		"arena_fight":
			_start_wave()
		"arena_lock":
			_spawn("bandit_shield", player.global_position + Vector3(0, 0, -5))
			_spawn("ash_shade", player.global_position + Vector3(4, 0, -8))
			get_tree().create_timer(0.5).timeout.connect(player._toggle_lock)
		"arena_selftest":
			var t = SelfTest.new()
			t.mode = self
			t.player = player
			add_child(t)
			t.run()
		"arena_wolves":
			for i in 3:
				_spawn("wolf", player.global_position + Vector3(-4 + i * 4, 0, -7))


func _tick(_delta: float) -> void:
	_update_mouse()
	if player.dead:
		if Input.is_action_just_pressed("restart"):
			restart_mode = ""
			get_tree().reload_current_scene()
		return
	if _resting and near_prompt(level.hearth, 3.0, "[E]  Ocaqda dincəl — şərbət dolur, növbəti dalğa"):
		_rest()
	elif not _resting:
		hud.set_prompt(_execution_prompt())


func _execution_prompt() -> String:
	for c in get_tree().get_nodes_in_group("enemies"):
		if c.has_method("is_executable") and c.is_executable() and player.global_position.distance_to(c.global_position) < 2.8:
			return "[E]  Köz İnfazı"
	return ""


## Mouse is captured for the camera unless a menu or the memory wheel needs it.
func _update_mouse() -> void:
	var free: bool = get_tree().paused or radial.is_open or debug.is_open() or dialogue.is_active() or player.dead
	var want := Input.MOUSE_MODE_VISIBLE if free else Input.MOUSE_MODE_CAPTURED
	if Settings.capture_path != "":
		want = Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want


func _rest() -> void:
	player.refill_flasks()
	player.heal(player.max_health)
	Audio.play("memory_burn", -10.0, 0.0)
	Fx.fire_nova(level.hearth, 2.5)
	_start_wave()


func _start_wave() -> void:
	_resting = false
	player.begin_encounter()
	var kinds: Array = WAVES[_wave % WAVES.size()]
	_wave += 1
	hud.set_objective("Dalğa %d" % _wave)
	hud.banner("Dalğa %d" % _wave)
	Audio.play("horn", -4.0, 0.0)
	Audio.music("battle", 1.0)
	var points: Array = level.spawn_points.duplicate()
	points.shuffle()
	for i in kinds.size():
		_spawn(kinds[i], points[i % points.size()])


func _spawn(id: String, at: Vector3) -> void:
	spawn_foe(id, at)


func spawn_foe(id: String, at: Vector3):
	var f = Foe.new()
	f.configure(id)
	add_child(f)
	f.global_position = at
	f.target = player
	_alive += 1
	f.killed.connect(func(_x): _on_killed())
	return f


func _on_killed() -> void:
	_alive -= 1
	if _alive <= 0 and not _resting:
		_resting = true
		Fx.slowmo(0.25, 0.8)
		Audio.music("ambient", 3.0)
		hud.set_objective("Dalğa təmizləndi — ocaqda [E] ilə dincəl")


func _marker_target() -> Variant:
	return level.hearth if _resting else null


func _on_player_died() -> void:
	Audio.music("", 1.0)
	Audio.play("sting_defeat", -2.0, 0.0)
	await get_tree().create_timer(1.2).timeout
	hud.show_card("KÖZ SÖNDÜ", "Arenada yıxıldın (dalğa %d)." % _wave, "[R] — yenidən   ·   [Esc] — menyu", 0.75)


func _build_debug() -> void:
	debug.section("Düşmən çağır")
	for id in ["ash_shade", "bandit_shield", "wolf"]:
		debug.button(DataDB.enemy(id)["name"], func():
			_resting = false
			_spawn(id, player.global_position + player.facing() * 6.0 + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))))
	debug.button("Hamısını öldür", func():
		for e in get_tree().get_nodes_in_group("enemies"):
			var h = e.Hit.new().setup(player, 9999.0, "slash", 0.0, Vector3.ZERO)
			e.receive_hit(h))
	debug.section("Silah")
	for id in ["sword", "sword_shield", "mace"]:
		debug.button(DataDB.weapon(id)["name"], func(): player.equip(id))
	debug.section("Oyunçu")
	debug.button("Tam can + şərbət", func():
		player.heal(player.max_health)
		player.refill_flasks())
	debug.button("Köz 100", func(): player.gain_ember(100.0))
	debug.button("Canı 10-a endir", func():
		player.health = 10.0
		player.health_changed.emit(player.health, player.max_health))
	debug.section("Xatirələr")
	for m in Memory.MEMORIES:
		debug.button("Yandır: " + m["title"], func(): Memory.burn(m["id"]))
	debug.button("Hamısını bərpa et", func(): Memory.reset())
