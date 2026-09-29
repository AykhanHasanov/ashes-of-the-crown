extends Node
## The balance rule, checked (suite of scenes/tests/combat_test.tscn): every slice
## encounter is comfortably beatable at BASE values — 100 Köz, 2 Köz Darbesi, no burned
## memory, the starting flasks. A plain bot plays each encounter of
## data/balance/combat.json balance_check (with the allies listed there) on the test yard:
## it locks on the nearest enemy, walks in, attacks, dodges some windups, drinks when low and
## uses a Köz Darbesi when several enemies crowd it; blocked by an obstacle, it steps round. Every seed must end in a win with at
## least min_health left and at most max_flasks_used. Burning makes fights easier, never
## required. The story plays along: the mode's StoryDirector runs the act 1 beats, and a
## companion they bring in (move_npc:<id>:party — Rüfət in S2) joins the fight as in the
## game. run() returns the failure count.

const Encounter := preload("res://scripts/world/encounter.gd")
const Ally := preload("res://scripts/npc/ally.gd")
const NpcRegistry := preload("res://scripts/core/npc_registry.gd")
const BurnPower := preload("res://scripts/combat/burn_power.gd")

var mode      # combat_test_mode
var player
var _fails := 0
var _cfg: Dictionary
var _rng := RandomNumberGenerator.new()
var _target = null
var _dodged := {}             # foe -> the windup it was already judged for
var _allies: Array = []
var _running := false
var _elapsed := 0.0           # game seconds of the current fight
var _encounter: Node
var _joined: Array = []
var _tokens_back := true      # every freed enemy gave its attack token back
var _attack_cd := 0.0
var _stuck_t := 0.0           # pressing forward without moving (an obstacle between them)
var _side_t := 0.0            # walking round it
var _react := 0.0
var _hits_taken := 0
var _last_health := 0.0


func run() -> int:
	_cfg = DataDB.balance("combat")["balance_check"]
	_check("the story is on: the mode's StoryDirector has the S2 rescue beats", mode.story != null
		and not mode.story.beat("s2_rufet_joins").is_empty() and not mode.story.beat("s2_rufet_rescue").is_empty())
	for f in get_tree().get_nodes_in_group("enemies"):
		f.queue_free()   # nothing left over from the other suites
	await get_tree().create_timer(0.5).timeout
	WorldState.new_game()
	var t := BurnPower.total()
	_check("balance runs at base values: no burned memory, 100 Köz, 2 Köz Darbesi",
		WorldState.burned_memories().is_empty() and t["max"] == 0.0 and player.ember_max() == 100.0 and player.strike_charges() == 2)
	var old_scale := Engine.time_scale
	Engine.time_scale = 2.0
	for enc in _cfg["encounters"]:
		for sd in _cfg["seeds"]:
			var r: Dictionary = await _play(String(enc["id"]), enc.get("allies", []), int(sd))
			var ok: bool = r["won"] and r["health"] >= float(_cfg["min_health"]) and r["flasks_used"] <= int(_cfg["max_flasks_used"])
			_check("balance: %s (seed %d) is comfortably won at base values" % [enc["id"], sd], ok,
				"won %s, health %.0f%%, hits taken %d, flasks used %d, %.0f s, joined %s" % [r["won"], r["health"] * 100.0, r["hits"], r["flasks_used"], r["time"], r["joined"]])
	Engine.time_scale = old_scale
	_check("enemies freed mid-fight give their attack tokens back", _tokens_back)
	await _rescue_check()
	print("balance suite: %d failures" % _fails)
	return _fails


## One fight from full health; returns {won, health (fraction), flasks_used, time}.
func _play(id: String, ally_ids: Array, rng_seed: int) -> Dictionary:
	_rng.seed = rng_seed
	seed(rng_seed)
	WorldState.new_game()   # the beats play again; nobody in the party yet
	_reset_player()
	for a in ally_ids:
		_add_ally(StringName(a))
	var on_moved := func(npc_id: StringName, _from: String, to: String):
		if to == WorldState.PARTY and NpcRegistry.get_def(npc_id).companion:
			_add_ally(npc_id)
			_joined.append(String(npc_id))
	_joined.clear()
	EventBus.npc_moved.connect(on_moved)
	var e := Encounter.new()
	e.spawner = func(eid: String, pos: Vector3, lv: int, opts: Dictionary):
		pos.y = 0.1
		var o := opts.duplicate()
		o["level"] = lv
		return mode.spawn_foe(eid, pos, o)
	mode.add_child(e)
	var start_flasks: int = player.flasks
	_hits_taken = 0
	var on_health := func(cur: float, _m: float):
		if cur < _last_health:
			_hits_taken += 1
		_last_health = cur
	_last_health = player.health
	player.health_changed.connect(on_health)
	e.start(StringName(id), player.global_position)
	_encounter = e
	_running = true
	_elapsed = 0.0
	var limit := float(_cfg["time_limit"])
	while _elapsed < limit and is_instance_valid(e) and not player.dead:
		await get_tree().physics_frame
	var t := _elapsed
	_running = false
	player.health_changed.disconnect(on_health)
	EventBus.npc_moved.disconnect(on_moved)
	if is_instance_valid(e) and not player.dead:
		for f in get_tree().get_nodes_in_group("enemies"):
			print("  left: %s %s at %.1f m, state %s, pos %s" % [f.data["id"], "dead" if f.dead else "alive",
				f.global_position.distance_to(player.global_position), f.S.keys()[f._state], f.global_position])
		print("  player at %s, wave %d, alive %d, state %s, vel %s, target %s, react %.2f, move_up %.1f, stamina %.0f, tokens %s" % [
			player.global_position, e.wave, e.alive.size(), player.S.keys()[player._state], player.velocity,
			str(_target) if _target != null and is_instance_valid(_target) else "none", _react,
			Input.get_action_strength("move_up"), player.stamina, str(player.get("_tokens_used"))])
		print("  input_locked %s, wheel %s, move_dir %s, paused %s, dialogue %s, on_floor %s, rig %s, exhausted %s" % [player.input_locked,
			player.radial != null and player.radial.is_open, player._move_dir, get_tree().paused, mode.dialogue.is_active(),
			player.is_on_floor(), player.rig, player.is_exhausted()])
	_release_all()
	var won: bool = not is_instance_valid(e) and not player.dead
	var out := {"won": won, "health": player.health / player.max_health if not player.dead else 0.0,
		"flasks_used": start_flasks - player.flasks, "time": t, "hits": _hits_taken, "joined": _joined.duplicate()}
	if is_instance_valid(e):
		e.abort()
	for f in get_tree().get_nodes_in_group("enemies"):
		f.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_tokens_back = _tokens_back and int(player._tokens_used) == 0
	for al in _allies:
		if is_instance_valid(al):
			al.queue_free()
	_allies.clear()
	await get_tree().create_timer(0.3).timeout
	return out


## S2's safety net: below 30% health in wave 1, Rüfət comes at once (before wave 2).
func _rescue_check() -> void:
	WorldState.new_game()
	_reset_player()
	player.make_invulnerable(30.0)
	var e := Encounter.new()
	e.spawner = func(eid: String, pos: Vector3, lv: int, opts: Dictionary):
		pos.y = 0.1
		var o := opts.duplicate()
		o["level"] = lv
		return mode.spawn_foe(eid, pos, o)
	mode.add_child(e)
	e.start(&"slice_s2_first_fight", player.global_position)
	await _wait(func(): return e.alive.size() == 2, 5.0)
	var before: bool = WorldState.check("joined:rufet")
	player.health = player.max_health * 0.25
	player.health_changed.emit(player.health, player.max_health)
	await _wait(func(): return WorldState.check("joined:rufet"), 3.0)
	_check("S2 rescue: Aras under 30% in wave 1 — Rüfət arrives at once", not before and WorldState.check("joined:rufet") and e.wave == 1)
	e.abort()
	for f in get_tree().get_nodes_in_group("enemies"):
		f.queue_free()
	player.invulnerable_until = 0
	player.health = player.max_health


func _wait(cond: Callable, timeout: float) -> void:
	var t := 0.0
	while t < timeout and not cond.call():
		await get_tree().create_timer(0.1).timeout
		t += 0.1


func _add_ally(id: StringName) -> void:
	var al = Ally.new()
	al.setup(NpcRegistry.get_def(id), player)
	mode.add_child(al)
	al.global_position = player.global_position + Vector3(1.6, 0.3, 0.6)
	_allies.append(al)


func _reset_player() -> void:
	player.input_locked = false   # the AI suite locks it against stray clicks; the bot walks
	if player.dead:
		player.dead = false
		player._model.cancel_action()
	player.global_position = Vector3(0, 0.2, 0)
	player.velocity = Vector3.ZERO
	player.health = player.max_health
	player.health_changed.emit(player.health, player.max_health)
	player.stamina = player.max_stamina
	player.refill_flasks()
	player.ember = 0.0
	player.ember_changed.emit(player.ember, player.ember_max())
	player.invulnerable_until = 0
	player._enter(player.S.MOVE)
	player._set_lock(null)
	_target = null
	_attack_cd = 0.0
	_react = 0.0
	_stuck_t = 0.0
	_side_t = 0.0
	_dodged.clear()


# --- The bot -------------------------------------------------------------------------------------

func _ready() -> void:
	process_physics_priority = -10   # decides before the protagonist reads its input


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if not _running or player.dead:
		_release_all()
		return
	var bot: Dictionary = _cfg["bot"]
	if _encounter == null or not is_instance_valid(_encounter):
		_release_all()
		return
	var foes: Array = _encounter.alive.filter(func(f): return is_instance_valid(f) and not f.dead)
	if foes.is_empty():
		_release_all()
		return
	_attack_cd -= delta
	if _target == null or not is_instance_valid(_target) or _target.dead:
		if _react <= 0.0:
			_react = float(bot["reaction"])   # a moment to pick the next one
			_release_all()
			return
		_react -= delta
		if _react > 0.0:
			return
		_target = _nearest(foes)
		player._set_lock(_target)
	var to: Vector3 = (_target.global_position - player.global_position) * Vector3(1, 0, 1)
	var dist := to.length()
	var near := foes.filter(func(f): return f.global_position.distance_to(player.global_position) < 3.2)
	# Low: back off from the fight and drink
	if player.health / player.max_health < float(bot["drink_below"]) and player.flasks > 0 and near.size() <= 1:
		_release_all()
		player._request("drink")
		return
	# A windup about to land within reach: sometimes dodge it (an average player)
	for f in near:
		var tts: float = f.time_to_strike()
		if tts < 0.3 and not _dodged.has(f.get_instance_id()):
			_dodged[f.get_instance_id()] = true
			if _rng.randf() < float(bot["dodge_chance"]):
				_face_camera(-to)
				Input.action_press("move_up")
				player._request("dodge")
				return
	for f in foes:
		if not f.is_attacking():
			_dodged.erase(f.get_instance_id())
	# Crowded with Köz enough: a Köz Darbesi
	if near.size() >= int(bot["strike_when_near"]) and player.ember >= float(DataDB.balance("combat")["ember"]["strike_cost"]):
		player._request("strike")
	_face_camera(to)
	if dist > 2.0:
		Input.action_press("move_up")
		# Blocked (the yard's low barrier): step round it like a player would
		_stuck_t = _stuck_t + delta if (player.velocity * Vector3(1, 0, 1)).length() < 0.5 else 0.0
		if _stuck_t > 0.4:
			_stuck_t = 0.0
			_side_t = 0.9
		if _side_t > 0.0:
			_side_t -= delta
			Input.action_press("move_left")
		else:
			Input.action_release("move_left")
	else:
		Input.action_release("move_left")
		Input.action_release("move_up")
		if _attack_cd <= 0.0 and player.stamina > float(DataDB.balance("combat")["stamina"]["light_cost"]):
			_attack_cd = float(bot["attack_interval"])
			player._request("light")


func _face_camera(dir: Vector3) -> void:
	if dir.length() > 0.01 and mode.rig != null:
		mode.rig.yaw = atan2(-dir.x, -dir.z)


func _nearest(foes: Array):
	var best = null
	var best_d := INF
	for f in foes:
		var d: float = f.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = f
	return best


func _release_all() -> void:
	Input.action_release("move_up")
	Input.action_release("move_left")


func _check(name: String, ok: bool, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + name + ("" if detail == "" else "  [%s]" % detail))
	if not ok:
		_fails += 1
