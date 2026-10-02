extends "res://scripts/chapter_base.gd"
## The 2.5D side-view test (v4, scenes/side_test.tscn). One strip, no loading, about four
## minutes long: the ash-valley edge → an abandoned village → two Küllüler at a brazier → a
## caravan wreck → two bandits → the gate and the hub's courtyard (scripts/world/side_strip.gd),
## watched square-on by a long lens that rides the lane (scripts/camera/side_camera.gd).
##
## Every Human here blends through an AnimationTree (Human.tree_driven) on retargeted Mixamo
## clips. The fight is the shared combat system with its windows retimed to those clips
## (data/weapons/iron_bar.json), plus what a side view needs:
##   · both sides are held on the lane, so nothing walks out of the picture
##   · only one enemy may attack at a time (the protagonist's token budget is 1)
##   · a landed blow throws its target back ALONG the lane and kicks up dust
##   · the blow that ends a fight drops the world into slow motion for a moment
##
## The two enemy kinds answer differently (STORY_BIBLE §2):
##   KÜLLÜ   iron only scatters it — it bursts into ash and re-forms where it fell after
##           REFORM_AFTER seconds. Fire ends it: the Köz Darbesi, or being driven into a fire
##           that is already burning. The brazier of fight one stands IN the road for exactly
##           that reason, so a blow along the lane pushes one into it.
##   BANDIT  at low health he throws his weapon down and kneels. The player may spare him
##           (walk away, or E) or finish him; the choice is kept in WorldState.
##
## Nothing here is canon and nothing else reads it. Numbers: data/balance/side_view.json.
## Run: "$G" --path . res://scenes/side_test.tscn

const SideStrip := preload("res://scripts/world/side_strip.gd")
const SideCamera := preload("res://scripts/camera/side_camera.gd")
const Protagonist := preload("res://scripts/player_v3/protagonist.gd")
const Human := preload("res://scripts/characters/human.gd")
const Foe := preload("res://scripts/enemies/foe.gd")
const Effects := preload("res://scripts/world/effects.gd")
const Hit := preload("res://scripts/combat/hit.gd")
const OVERLAY := preload("res://shaders/ash_overlay.gdshader")

const WEAPON := "iron_bar"
const KULLU := "kullu"
## The two bandits of the second fight: fast and weak, slow and heavy.
const BANDITS := [["bandit_knife", -1.6], ["bandit_club", 1.7]]
const WAKE_RANGE := 13.0      # he wakes a fight walking into this
const REFORM_AFTER := 4.5     # how long scattered ash takes to stand up again
const FIRE_DPS := 90.0        # what standing in a fire costs a Küllü, per second
const MERCY_AT := 0.22        # a bandit gives up below this much health
const SPARE_RANGE := 3.2      # how close he has to be to press E
const WALK_AWAY := 14.0       # or how far he has to walk off for it to count as mercy
const HOUR := 20.2            # dusk going over into night: fire is the strongest colour

var fights: Array = []        # [{"at": Vector3, "kind": String, "foes": Array, "woken": bool}]
var _cfg: Dictionary
var _hit_cfg: Dictionary
var _health: Dictionary = {}  # foe → last seen health, to notice a landed blow
var _kneeling = null          # the bandit waiting to be spared or finished
var _away := 0.0
var _auto := ""               # test only: the bot fights while a fight is being filmed
var _bot_cd := 0.0
## Test-only frame grabber (see _process). A _gif demo shows no title card, so this only has
## to let the first frames settle; the count then covers a whole fight.
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
	cam.occluders = level.occluders
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
	hud.slim_hud()
	player.global_position = level.player_spawn
	player.equip(WEAPON)
	player.token_budget = 1     # one enemy swings at a time; the rest circle
	player.offer = null         # Kül Şahı's bargain belongs in the story, not in a strip test
	player.face_towards(player.global_position + Vector3(0, 0, -1))
	rig.snap()
	player.wake()
	set_controls(true)
	_village_shades()
	_arm_fight(level.fight1_at, "kullu")
	_arm_fight(level.fight2_at, "bandit")
	if not Settings.demo.ends_with("_gif"):
		hud.title_card(tr("SIDE_TEST_TITLE"), "", 2.5)
		hud.hint_once("move", tr("SIDE_HINT_MOVE"))
	_demo_setup()


func _exit_tree() -> void:
	Human.tree_driven = false   # the rest of the game keeps its own animation driver


# --- The village: three of them, standing out in the ash ---------------------------------------

## Not enemies and not props: bodies with the ash look, standing where the lamp light does not
## reach, each on its own idle and its own clock. They never come closer. That is the point of
## the stretch — the player learns what a Küllü looks like before one ever touches him.
func _village_shades() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for at in level.village_shades:
		var body = Human.build({"outfit": "Male_Peasant", "hood": false, "beard": false,
			"idle": Human.pick_idle(rng),
			"skin_tint": Color(0.30, 0.28, 0.29), "tint": Color(0.34, 0.33, 0.35)})
		add_child(body)
		body.global_position = at
		body.scatter_timing(rng)
		var ash := ShaderMaterial.new()
		ash.shader = OVERLAY
		ash.set_shader_parameter("intensity", 0.5)
		ash.set_shader_parameter("ember_color", Color(1.0, 0.3, 0.05))
		body.set_overlay(ash)
		body.look_at(at + Vector3(1, 0, 0.25), Vector3.UP)   # turned towards the road
		body.set_locomotion(false)


# --- The fights ---------------------------------------------------------------------------------

## A fight waiting to be walked into. The foes exist from the start, so nothing pops in, but
## they do not think until he is close.
func _arm_fight(at: Vector3, kind: String) -> void:
	var fight := {"at": at, "kind": kind, "foes": [], "woken": false}
	var spots: Array = [[KULLU, -0.6], [KULLU, 1.7]] if kind == "kullu" else BANDITS
	for spot in spots:
		# spread them ALONG the lane, not towards the lens: a foe standing between the camera
		# and the fight fills a third of the picture
		var side := float(spot[1])
		fight["foes"].append(_make_foe(String(spot[0]), at + Vector3(side * 0.35, 0, side * 1.6)))
	fights.append(fight)


func _make_foe(id: String, at: Vector3):
	var f = Foe.new()
	f.configure(id, 1, {"roll": false, "ground_tell": false})
	f.voice = ""                # no shouted lines in the test: the fight speaks for itself
	f.aggro_range = 0.0         # woken by the mode, not by their own eyes
	f.home = at
	add_child(f)
	f.global_position = at
	f.target = player
	f.killed.connect(_on_killed.bind(f))
	f.process_mode = Node.PROCESS_MODE_DISABLED
	_health[f] = f.max_health
	if String(f.data["faction"]) == "ash":
		_ember_inside(f)
	return f


## The ember a Küllü carries where its heart was: a small warm light inside a grey body, so it
## reads as something hollow with a fire still in it rather than as a grey man.
func _ember_inside(f) -> void:
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.38, 0.1)
	glow.light_energy = 1.6
	glow.omni_range = 2.4
	glow.shadow_enabled = false
	glow.position = Vector3(0, 1.15, 0)
	f.add_child(glow)


func _wake_fight(fight: Dictionary) -> void:
	fight["woken"] = true
	hud.wake()
	Audio.music("battle", 1.0)
	Fx.shake(float(_hit_cfg["shake"]))
	hud.hint_once("fight", tr("SIDE_HINT_FIGHT"))
	if String(fight["kind"]) == "kullu":
		hud.hint_once("kullu", tr("SIDE_HINT_KULLU"))
	for f in fight["foes"]:
		if is_instance_valid(f):
			f.process_mode = Node.PROCESS_MODE_INHERIT
			f.alarm(player.global_position)


## A blow has landed: throw the target back ALONG the lane and kick up what it is made of —
## dust off a man, ash out of a Küllü. The freeze, the shake and the sound are the shared
## combat system's; this is the part a side-on camera can actually see.
func _on_hurt(f, lost: float) -> void:
	var along: Vector3 = rig.flat_right()
	if (f.global_position - player.global_position).dot(along) < 0.0:
		along = -along
	f.push(along * (float(_hit_cfg["knock_light"]) + float(_hit_cfg["knock_per_damage"]) * lost))
	var ash: bool = String(f.data["faction"]) == "ash"
	var puff := Effects.smoke_burst(10 if ash else 8, 1.6 if ash else 1.4, 0.7 if ash else 0.5, 0.26)
	puff.position = f.global_position + Vector3(0, 0.9 if ash else 0.12, 0)
	add_child(puff)
	puff.emitting = true
	get_tree().create_timer(1.6).timeout.connect(puff.queue_free)


## Someone is down. A Küllü only stays down if fire did it; otherwise it scatters and comes
## back. A bandit is simply dead, and if he was the one kneeling, the choice is recorded.
func _on_killed(_x, f) -> void:
	Fx.hitstop(float(_hit_cfg["hit_stop_heavy"]))
	Fx.shake(float(_hit_cfg["shake_heavy"]))
	if f == _kneeling:
		WorldState.set_flag(&"side_test_mercy", "killed")
		_kneeling = null
		hud.set_prompt("")
	var ash: bool = String(f.data["faction"]) == "ash"
	var by_fire: bool = f.last_hit_type == "fire" or _in_fire(f.global_position)
	if ash and not by_fire:
		_scatter(f)
		return
	if ash:
		_burn_out(f.global_position)
	_check_fight_over()


## Iron scattered it: it bursts, the body goes, and the same thing stands up again where it
## fell once the ash has had time to gather.
func _scatter(f) -> void:
	var at: Vector3 = f.global_position
	var burst := Effects.burst(44, 3.4, 1.1, 0.3, false, Color(0.75, 0.72, 0.7))
	burst.position = at + Vector3(0, 0.9, 0)
	add_child(burst)
	burst.emitting = true
	get_tree().create_timer(2.5).timeout.connect(burst.queue_free)
	_health.erase(f)
	f.queue_free()
	for fight in fights:
		if f in fight["foes"]:
			fight["foes"].erase(f)
			get_tree().create_timer(REFORM_AFTER).timeout.connect(_reform.bind(fight, at))
			return


func _reform(fight: Dictionary, at: Vector3) -> void:
	if not is_inside_tree() or player.dead:
		return
	var f = _make_foe(KULLU, at)
	fight["foes"].append(f)
	f.process_mode = Node.PROCESS_MODE_INHERIT
	f.alarm(player.global_position)
	var rise := Effects.ember_column(0.7, 26)
	rise.position = at
	add_child(rise)
	rise.emitting = true
	get_tree().create_timer(2.5).timeout.connect(rise.queue_free)


## Fire finished one for good: it goes up rather than falls down.
func _burn_out(at: Vector3) -> void:
	Fx.fire_nova(at + Vector3(0, 0.9, 0), 1.6)


func _in_fire(at: Vector3) -> bool:
	for fire in level.fires:
		var p: Vector3 = fire["pos"]
		if Vector2(at.x - p.x, at.z - p.z).length() < float(fire["radius"]) + 0.5:
			return true
	return false


func _check_fight_over() -> void:
	for fight in fights:
		if not fight["woken"]:
			continue
		for f in fight["foes"]:
			if is_instance_valid(f) and not f.dead and not f.surrendered:
				return
	# everything that was awake is down: the world leans back for a moment
	Fx.slowmo(float(_hit_cfg["kill_slowmo"]), float(_hit_cfg["kill_slowmo_time"]))
	Audio.music("ambient", 2.5)


# --- The mercy moment ----------------------------------------------------------------------------

## A bandit who has had enough: he throws the weapon down, goes to his knees and says the only
## line in the fight. From here the player decides — and walking away decides too.
func _kneel(f) -> void:
	_kneeling = f
	_away = 0.0
	f.drop_weapon()
	hud.set_prompt(tr("SIDE_MERCY_PROMPT"))
	hud.banner(tr("SIDE_BANDIT_MERCY"))


func _tick_mercy(delta: float) -> void:
	if _kneeling == null:
		return
	if not is_instance_valid(_kneeling) or _kneeling.dead:
		_kneeling = null
		hud.set_prompt("")
		return
	var d: float = player.global_position.distance_to(_kneeling.global_position)
	if d < SPARE_RANGE and Input.is_action_just_pressed("interact"):
		_spare()
		return
	_away = _away + delta if d > WALK_AWAY else 0.0
	if _away > 2.0:
		_spare()


func _spare() -> void:
	if _kneeling == null:
		return
	WorldState.set_flag(&"side_test_mercy", "spared")
	if is_instance_valid(_kneeling):
		_kneeling.spare()
	_kneeling = null
	hud.set_prompt("")
	_check_fight_over()


# --- Frame ---------------------------------------------------------------------------------------

func _tick(delta: float) -> void:
	_update_mouse()
	if player.dead:
		if Input.is_action_just_pressed("restart"):
			_restart()
		return
	_hold_lane(player, delta, float(_cfg["lane"]["depth"]))
	for fight in fights:
		if not fight["woken"] and player.global_position.distance_to(fight["at"]) < WAKE_RANGE:
			_wake_fight(fight)
		for f in fight["foes"]:
			if is_instance_valid(f):
				_tick_foe(f, delta)
	_tick_mercy(delta)
	if _auto != "":
		_fight_bot(delta)


## Everything a live foe needs that the shared AI does not do here: stay on the lane, report a
## landed blow, burn while it stands in a fire, and give up when it has had enough.
func _tick_foe(f, delta: float) -> void:
	_hold_lane(f, delta, float(_cfg["lane"]["foe_depth"]))
	if f.dead:
		return
	var was: float = _health.get(f, f.max_health)
	if f.health < was - 0.01:
		_on_hurt(f, was - f.health)
	_health[f] = f.health
	var faction := String(f.data["faction"])
	if faction == "ash" and _in_fire(f.global_position):
		# it is standing in a fire: that is the end of it, and it is meant to look like one
		f.receive_hit(Hit.new().setup(player, FIRE_DPS * delta, "fire", 0.0, Vector3.ZERO))
		if randf() < delta * 8.0:
			Fx.hit_spark(f.global_position + Vector3(0, 1.0, 0), true)
	elif faction == "bandit" and not f.surrendered and f.health < f.max_health * MERCY_AT:
		f._morale_break()
		if f.surrendered:
			_kneel(f)


## Everyone walks a lane: free along it, but only `depth` metres towards or away from the lens,
## and eased back when they stray. Everything else about movement is the usual controller.
func _hold_lane(who: Node3D, delta: float, depth: float) -> void:
	var lane: Dictionary = rig.lane_at(who.global_position)
	var to_lane: Vector3 = (lane["pos"] - who.global_position) * Vector3(1, 0, 1)
	if to_lane.length() <= depth:
		return
	var pull: Vector3 = to_lane.normalized() * (to_lane.length() - depth)
	who.global_position += pull * clampf(float(_cfg["lane"]["pull"]) * delta, 0.0, 1.0)


## Test only: fights the nearest enemy so a fight can be filmed without a player.
func _fight_bot(delta: float) -> void:
	_bot_cd -= delta
	var near = null
	var best := 99.0
	for fight in fights:
		for f in fight["foes"]:
			if is_instance_valid(f) and not f.dead and not f.surrendered:
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
		# the light combo mostly, the heavy now and then, a backstep in between: every move
		# the test is about shows up inside one take
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


## Test only: a demo whose name ends in _gif saves a frame every few frames, so a stretch can
## be turned into a GIF (tools/make_gif.py). Nothing else uses it.
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


# --- Capture demos ---------------------------------------------------------------------------------

## One demo per stretch of the strip. A negative z means "just outside the gate".
const SPOTS := {
	"side_valley": 230.0, "side_village": 190.0, "side_fight1": 152.0,
	"side_caravan": 106.0, "side_fight2": 72.0, "side_gate": -1.0,
}


func _demo_setup() -> void:
	if SPOTS.has(Settings.demo):
		_put_at(float(SPOTS[Settings.demo]))
		return
	match Settings.demo:
		"side_fight1_gif":
			_put_at(154.0)
			_wake_fight(fights[0])
			_auto = "kullu"
		"side_fight2_gif":
			_put_at(74.5)
			_wake_fight(fights[1])
			_auto = "bandit"
		"side_gate_gif":
			_put_at(26.0)
			Input.action_press("move_right")
		"side_village_gif":
			_put_at(204.0)
			Input.action_press("move_right")


func _put_at(z: float) -> void:
	if z < 0.0:
		player.global_position = level.lane.sample_baked(level.lane.get_baked_length() - 2.5) + Vector3(0, 0.3, 0)
	else:
		player.global_position = Vector3(0, 0.3, z)
	player.face_towards(player.global_position + Vector3(0, 0, -1))
	rig.snap()
