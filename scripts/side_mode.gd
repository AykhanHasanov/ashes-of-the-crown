extends "res://scripts/chapter_base.gd"
## The 2.5D side-view test (v4, scenes/side_test.tscn). One strip, no loading: the ash-valley
## edge → the road → the Son Ocaq courtyard (scripts/world/side_strip.gd), watched from the
## side by a long lens that rides the lane (scripts/camera/side_camera.gd).
##
## What it is testing: whether the game feels alive from the side, with blended animation
## (every Human here is driven by an AnimationTree — Human.tree_driven) and one grounded fight
## on the road: Aras with an improvised iron bar against two bandits, hit-stop and a camera
## kick on every landed blow.
##
## Nothing here is canon and nothing else reads it. Numbers: data/balance/side_view.json.
## Run: "$G" --path . res://scenes/side_test.tscn

const SideStrip := preload("res://scripts/world/side_strip.gd")
const SideCamera := preload("res://scripts/camera/side_camera.gd")
const Protagonist := preload("res://scripts/player_v3/protagonist.gd")
const Human := preload("res://scripts/characters/human.gd")
const Foe := preload("res://scripts/enemies/foe.gd")

const WEAPON := "iron_bar"
const BANDIT := "bandit_sword"
const FIGHT_RANGE := 14.0     # he wakes them walking into this
const HOUR := 20.2            # dusk going over into night: fire is the strongest colour

var bandits: Array = []
var fight_started := false
var _cfg: Dictionary
const GIF_FROM := 70          # test-only frame grabber (see _process)
const GIF_EVERY := 3
const GIF_COUNT := 60
var _gif_frame := 0
var _gif_shots := 0
var _auto_fight := false
var _bot_cd := 0.0
var _hit_cfg: Dictionary


func _make_level() -> Node3D:
	Human.tree_driven = true    # every Human in this scene blends through an AnimationTree
	return SideStrip.new()


func _make_player() -> Node3D:
	return Protagonist.new()


func _make_camera() -> Node3D:
	var cam := SideCamera.new()
	cam.lane = level.lane       # the level is already built when this runs
	cam.zones = level.camera_zones
	return cam


func _setup() -> void:
	_cfg = DataDB.balance("side_view")
	_hit_cfg = _cfg["fight"]
	Audio.music("ambient", 3.0)


func _begin(_mode: String) -> void:
	WorldState.new_game()       # the test runs in memory; SaveManager never writes in a --demo
	WorldState.set_time_of_day(HOUR)
	level.day_night.set_hour(HOUR)
	level.day_night.paused = true
	player.global_position = level.player_spawn
	player.equip(WEAPON)
	player.face_towards(player.global_position + Vector3(0, 0, -1))
	rig.snap()
	player.wake()
	set_controls(true)
	_spawn_bandits()
	hud.title_card(tr("SIDE_TEST_TITLE"), "", 2.5)
	_demo_setup()


func _exit_tree() -> void:
	Human.tree_driven = false   # the rest of the game keeps its own animation driver


# --- The fight ---------------------------------------------------------------------------------

## Two bandits waiting on the road, asleep until he comes close.
func _spawn_bandits() -> void:
	for side in [-1.4, 1.2]:
		var f = Foe.new()
		f.configure(BANDIT, 1, {"roll": false})
		f.aggro_range = 0.0     # woken by the mode, not by their own eyes
		f.home = level.fight_at + Vector3(side, 0, side * 0.8)
		add_child(f)
		f.global_position = f.home
		f.target = player
		f.engaged.connect(_on_engaged)
		f.killed.connect(func(_x): _on_bandit_down())
		f.process_mode = Node.PROCESS_MODE_DISABLED
		bandits.append(f)


func _wake_bandits() -> void:
	fight_started = true
	Audio.music("battle", 1.0)
	Fx.shake(float(_hit_cfg["shake"]))
	for f in bandits:
		if is_instance_valid(f):
			f.process_mode = Node.PROCESS_MODE_INHERIT
			f.alarm(player.global_position)


func _on_engaged(_f) -> void:
	pass


func _on_bandit_down() -> void:
	Fx.hitstop(float(_hit_cfg["hit_stop_heavy"]))
	Fx.shake(float(_hit_cfg["shake_heavy"]))
	for f in bandits:
		if is_instance_valid(f) and not f.dead:
			return
	Audio.music("ambient", 2.5)


# --- Frame -------------------------------------------------------------------------------------

func _tick(delta: float) -> void:
	_update_mouse()
	if player.dead:
		if Input.is_action_just_pressed("restart"):
			_restart()
		return
	_hold_lane(delta)
	if _auto_fight:
		_fight_bot(delta)
	if not fight_started and player.global_position.distance_to(level.fight_at) < FIGHT_RANGE:
		_wake_bandits()


## He walks a lane: free along it, but only `depth` metres towards or away from the lens, and
## eased back when he strays. Everything else about his movement is the usual controller.
func _hold_lane(delta: float) -> void:
	var lane: Dictionary = rig.lane_at(player.global_position)
	var to_lane: Vector3 = (lane["pos"] - player.global_position) * Vector3(1, 0, 1)
	var cfg: Dictionary = _cfg["lane"]
	var depth := float(cfg["depth"])
	if to_lane.length() <= depth:
		return
	var pull: Vector3 = to_lane.normalized() * (to_lane.length() - depth)
	player.global_position += pull * clampf(float(cfg["pull"]) * delta, 0.0, 1.0)


## Test only: swings at the nearest bandit so the fight can be filmed without a player.
func _fight_bot(delta: float) -> void:
	_bot_cd -= delta
	var near = null
	var best := 99.0
	for f in bandits:
		if is_instance_valid(f) and not f.dead:
			var d: float = player.global_position.distance_to(f.global_position)
			if d < best:
				best = d
				near = f
	if near == null:
		Input.action_release("move_right")
		return
	var to: Vector3 = (near.global_position - player.global_position) * Vector3(1, 0, 1)
	var along: float = to.normalized().dot(rig.flat_right())
	Input.action_release("move_right")
	Input.action_release("move_left")
	if best > 2.2:
		Input.action_press("move_right" if along > 0.0 else "move_left")
	elif _bot_cd <= 0.0:
		_bot_cd = 0.75
		player._request("light")


func _update_mouse() -> void:
	var free: bool = get_tree().paused or debug_open() or dialogue.is_active()
	var want := Input.MOUSE_MODE_VISIBLE if free or Settings.capture_path != "" else Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != want:
		Input.mouse_mode = want


func debug_open() -> bool:
	return false


func _on_player_died() -> void:
	await get_tree().create_timer(1.0).timeout
	hud.show_card(tr("DEATH_TITLE"), "", tr("DEATH_RETRY"), 0.8)


func _restart() -> void:
	hud._card.visible = false
	player.dead = false
	player.health = player.max_health
	player.health_changed.emit(player.health, player.max_health)
	player.stamina = player.max_stamina
	player._enter(player.S.MOVE)
	player._model.cancel_action()
	player.refill_flasks()
	player.global_position = level.player_spawn
	rig.snap()


## Test only: a demo whose name ends in _gif saves a frame every few frames, so the walk and
## the fight can be turned into a GIF (tools/make_gif.py). Nothing else uses it.
func _process(delta: float) -> void:
	super._process(delta)
	if not Settings.demo.ends_with("_gif"):
		return
	_gif_frame += 1
	if _gif_frame >= GIF_FROM and (_gif_frame - GIF_FROM) % GIF_EVERY == 0 and _gif_shots < GIF_COUNT:
		_gif_shots += 1
		_save_gif_frame(_gif_shots)
	if _gif_shots >= GIF_COUNT:
		get_tree().quit()


func _save_gif_frame(n: int) -> void:
	await RenderingServer.frame_post_draw
	var dir := "captures/gif_" + Settings.demo
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + dir))
	get_viewport().get_texture().get_image().save_png("%s/%03d.png" % [dir, n])


# --- Capture demos -------------------------------------------------------------------------------

## side_walk (the road), side_gate (walking into the courtyard), side_fight (the two bandits)
func _demo_setup() -> void:
	match Settings.demo:
		"side_walk":
			player.global_position = level.lane.sample_baked(14.0) + Vector3(0, 0.3, 0)
			rig.snap()
		"side_gate":
			player.global_position = level.lane.sample_baked(level.lane.get_baked_length() - 2.5) + Vector3(0, 0.3, 0)
			rig.snap()
		"side_walk_gif", "side_gate_gif":
			# he walks the strip on his own: the lane's direction is "right" for the controller
			player.global_position = level.lane.sample_baked(10.0 if Settings.demo == "side_walk_gif" else level.lane.get_baked_length() - 26.0) + Vector3(0, 0.3, 0)
			rig.snap()
			Input.action_press("move_right")
		"side_fight_gif":
			player.global_position = level.fight_at + Vector3(0, 0.3, 7.0)
			rig.snap()
			_wake_bandits()
			_auto_fight = true
		"side_fight":
			player.global_position = level.fight_at + Vector3(0, 0.3, 6.0)
			rig.snap()
			_wake_bandits()
