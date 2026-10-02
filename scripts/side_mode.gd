extends "res://scripts/chapter_base.gd"
## The 2.5D side-view test (v4, scenes/side_test.tscn). One strip, no loading: the ash-valley
## edge → the road → the Son Ocaq courtyard (scripts/world/side_strip.gd), watched square-on
## by a long lens that rides the lane (scripts/camera/side_camera.gd).
##
## What it is testing: whether the game feels alive from the side, with blended Mixamo
## animation (every Human here runs through an AnimationTree — Human.tree_driven) and one
## grounded fight on the road: Aras with an improvised iron bar against a knife bandit and a
## club bandit. The fight is the shared combat system with its windows retimed to the Mixamo
## clips (data/weapons/iron_bar.json) and four things added for the side view:
##   · both sides are held on the lane, so nothing can walk out of the picture
##   · only one bandit may attack at a time (the protagonist's token budget is set to 1)
##   · a landed blow throws the foe back ALONG the lane and kicks up dust at his feet
##   · the blow that ends the fight drops the world into slow motion for a moment
## The bandits tell their attacks with the clip's own wind-up and a sound; the ground ring and
## the body tint that go with it are switched off (foe.configure "ground_tell"), because a
## side-on camera reads a pose.
##
## Nothing here is canon and nothing else reads it. Numbers: data/balance/side_view.json.
## Run: "$G" --path . res://scenes/side_test.tscn

const SideStrip := preload("res://scripts/world/side_strip.gd")
const SideCamera := preload("res://scripts/camera/side_camera.gd")
const Protagonist := preload("res://scripts/player_v3/protagonist.gd")
const Human := preload("res://scripts/characters/human.gd")
const Foe := preload("res://scripts/enemies/foe.gd")
const Effects := preload("res://scripts/world/effects.gd")

const WEAPON := "iron_bar"
## The two bandits of the test: fast and weak, slow and heavy.
const BANDITS := [["bandit_knife", -1.5], ["bandit_club", 1.6]]
const FIGHT_RANGE := 13.0     # he wakes them walking into this
const HOUR := 20.2            # dusk going over into night: fire is the strongest colour

var bandits: Array = []
var fight_started := false
var _cfg: Dictionary
var _hit_cfg: Dictionary
var _health: Array = []       # last seen health per bandit, to notice a landed blow
var _auto_fight := false
var _bot_cd := 0.0
## Test-only frame grabber (see _process). A _gif demo shows no title card at all, so this
## only has to let the first frames settle; the count then covers the whole fight.
const GIF_FROM := 45
const GIF_EVERY := 4
const GIF_COUNT := 72
var _gif_frame := 0
var _gif_shots := 0


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
	player.token_budget = 1     # one bandit swings at a time; the other circles
	player.face_towards(player.global_position + Vector3(0, 0, -1))
	rig.snap()
	player.wake()
	set_controls(true)
	_spawn_bandits()
	if not Settings.demo.ends_with("_gif"):
		hud.title_card(tr("SIDE_TEST_TITLE"), "", 2.5)
	_demo_setup()


func _exit_tree() -> void:
	Human.tree_driven = false   # the rest of the game keeps its own animation driver


# --- The fight ---------------------------------------------------------------------------------

## Two bandits waiting on the road, asleep until he comes close.
func _spawn_bandits() -> void:
	for b in BANDITS:
		var f = Foe.new()
		f.configure(String(b[0]), 1, {"roll": false, "ground_tell": false})
		f.voice = ""            # no shouted lines in the test: the fight speaks for itself
		f.aggro_range = 0.0     # woken by the mode, not by their own eyes
		f.home = level.fight_at + Vector3(float(b[1]), 0, float(b[1]) * 0.6)
		add_child(f)
		f.global_position = f.home
		f.target = player
		f.killed.connect(func(_x): _on_bandit_down())
		f.process_mode = Node.PROCESS_MODE_DISABLED
		bandits.append(f)
		_health.append(f.max_health)


func _wake_bandits() -> void:
	fight_started = true
	Audio.music("battle", 1.0)
	Fx.shake(float(_hit_cfg["shake"]))
	for f in bandits:
		if is_instance_valid(f):
			f.process_mode = Node.PROCESS_MODE_INHERIT
			f.alarm(player.global_position)


## A blow has landed on `f`: throw him back along the lane and kick dust off the road. The
## freeze, the shake and the sound are the shared combat system's; this is what the side view
## adds, because a knockback in any other direction cannot be seen at all from here.
func _on_bandit_hurt(f, lost: float) -> void:
	var along: Vector3 = rig.flat_right()
	if (f.global_position - player.global_position).dot(along) < 0.0:
		along = -along
	f.push(along * (float(_hit_cfg["knock_light"]) + float(_hit_cfg["knock_per_damage"]) * lost))
	var dust := Effects.smoke_burst(8, 1.4, 0.5, 0.22)
	dust.position = f.global_position + Vector3(0, 0.12, 0)
	add_child(dust)
	dust.emitting = true
	get_tree().create_timer(1.4).timeout.connect(dust.queue_free)


func _on_bandit_down() -> void:
	Fx.hitstop(float(_hit_cfg["hit_stop_heavy"]))
	Fx.shake(float(_hit_cfg["shake_heavy"]))
	for f in bandits:
		if is_instance_valid(f) and not f.dead:
			return
	# the last one down: the world leans back for a moment
	Fx.slowmo(float(_hit_cfg["kill_slowmo"]), float(_hit_cfg["kill_slowmo_time"]))
	Audio.music("ambient", 2.5)


# --- Frame -------------------------------------------------------------------------------------

func _tick(delta: float) -> void:
	_update_mouse()
	if player.dead:
		if Input.is_action_just_pressed("restart"):
			_restart()
		return
	_hold_lane(player, delta, float(_cfg["lane"]["depth"]))
	for i in bandits.size():
		var f = bandits[i]
		if not is_instance_valid(f):
			continue
		_hold_lane(f, delta, float(_cfg["lane"]["foe_depth"]))
		if not f.dead and f.health < _health[i] - 0.01:
			_on_bandit_hurt(f, _health[i] - f.health)
		_health[i] = f.health
	if _auto_fight:
		_fight_bot(delta)
	if not fight_started and player.global_position.distance_to(level.fight_at) < FIGHT_RANGE:
		_wake_bandits()


## Everyone walks a lane: free along it, but only `depth` metres towards or away from the lens,
## and eased back when they stray. Everything else about movement is the usual controller.
func _hold_lane(who: Node3D, delta: float, depth: float) -> void:
	var lane: Dictionary = rig.lane_at(who.global_position)
	var to_lane: Vector3 = (lane["pos"] - who.global_position) * Vector3(1, 0, 1)
	if to_lane.length() <= depth:
		return
	var pull: Vector3 = to_lane.normalized() * (to_lane.length() - depth)
	who.global_position += pull * clampf(float(_cfg["lane"]["pull"]) * delta, 0.0, 1.0)


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
	Input.action_release("move_right")
	Input.action_release("move_left")
	if near == null:
		return
	var to: Vector3 = (near.global_position - player.global_position) * Vector3(1, 0, 1)
	var along: float = to.normalized().dot(rig.flat_right())
	if best > 2.1:
		Input.action_press("move_right" if along > 0.0 else "move_left")
	elif _bot_cd <= 0.0:
		# the light combo mostly, the heavy now and then, and a backstep in between: every
		# move the test is about shows up inside one take
		_bot_cd = 0.9
		var roll := randf()
		if roll < 0.18:
			player._request("dodge")
		elif roll < 0.42:
			player._request("heavy")
		else:
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
			player.global_position = level.lane.sample_baked(5.0) + Vector3(0, 0.3, 0)
			rig.snap()
		"side_gate":
			player.global_position = level.lane.sample_baked(level.lane.get_baked_length() - 2.5) + Vector3(0, 0.3, 0)
			rig.snap()
		"side_walk_gif", "side_gate_gif":
			# he walks the strip on his own: the lane's direction is "right" for the controller
			player.global_position = level.lane.sample_baked(4.0 if Settings.demo == "side_walk_gif" else level.lane.get_baked_length() - 24.0) + Vector3(0, 0.3, 0)
			rig.snap()
			Input.action_press("move_right")
		"side_fight_gif":
			player.global_position = level.fight_at + Vector3(0, 0.3, 6.5)
			rig.snap()
			_wake_bandits()
			_auto_fight = true
		"side_fight":
			player.global_position = level.fight_at + Vector3(0, 0.3, 5.0)
			rig.snap()
			_wake_bandits()
