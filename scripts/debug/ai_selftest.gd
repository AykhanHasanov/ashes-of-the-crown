extends Node
## Automated checks for the V3 Faza C enemy framework, run in the arena with
## --demo=ai_selftest: perception and search, tokens, archers, bombers, shamans
## (raise + ward), affixes, adaptive AI, morale, level formulas, AI LOD, the
## leopard's stealth and phases, and territorial warnings.

const Foe := preload("res://scripts/enemies/foe.gd")
const Perception := preload("res://scripts/enemies/perception.gd")

var mode      # arena_mode
var player
var _fails := 0


func run() -> void:
	await _wait(1.0)
	await _perception()
	await _tokens()
	await _archer()
	await _bomber()
	await _shaman()
	await _affixes()
	await _adaptive()
	await _morale()
	_levels()
	await _lod()
	await _leopard()
	await _territorial()
	print("AI SELFTEST DONE, failures: ", _fails)
	get_tree().quit(_fails)


func run_bomber_loop() -> void:
	await _wait(1.0)
	for i in 8:
		await _bomber()
	get_tree().quit(_fails)


func _check(name: String, ok: bool, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + name + ("" if detail == "" else "  (" + detail + ")"))
	if not ok:
		_fails += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _clear() -> void:
	for e in get_tree().get_nodes_in_group("combatants"):
		if e != player:
			e.queue_free()
	for n in get_tree().get_nodes_in_group("enemies"):
		n.queue_free()
	for n in mode.get_children():
		var sc = n.get_script()
		if sc != null and (sc.resource_path.ends_with("projectile.gd") or sc.resource_path.ends_with("aoe.gd")):
			n.queue_free()
	Foe.corpses.clear()
	player.dead = false
	player.heal(player.max_health)
	player.stamina = player.max_stamina
	player.invulnerable_until = 0
	player._tokens_used = 0
	player.habits.clear()
	player.statuses.clear()
	player.input_locked = true   # a stray click on the window must not swing a sword
	player._enter(player.S.MOVE)
	player.global_position = Vector3(0, 0.1, 8)
	await _wait(0.3)


## An enemy with open-world perception (arena foes normally hunt from the start).
func _wild(id: String, pos: Vector3, opts := {}) -> Node:
	var f = Foe.new()
	var o: Dictionary = opts.duplicate()
	if not o.has("affixes"):
		o["roll"] = false
	f.configure(id, int(o.get("level", 1)), o)
	f.aggro_range = 16.0
	f.home = pos
	mode.add_child(f)
	f.global_position = pos
	f.target = player
	f.summon_requested.connect(func(eid: String, p: Vector3, lv: int, so: Dictionary):
		var o2 := so.duplicate()
		o2["level"] = lv
		mode.spawn_foe(eid, p, o2))
	return f


func _face_to(f, at: Vector3) -> void:
	var d: Vector3 = at - f.global_position
	f._model.rotation.y = atan2(-d.x, -d.z)


func _perception() -> void:
	await _clear()
	var f = _wild("ash_shade", Vector3(0, 0.1, -2))
	_face_to(f, player.global_position)
	await _wait(2.0)
	_check("an enemy facing Ayxan 10 m away notices him", f.perception.state == Perception.COMBAT and f.aggro,
		"%s %.2f" % [Perception.NAMES[f.perception.state], f.perception.awareness])
	f.queue_free()
	await _wait(0.2)
	var g = _wild("ash_shade", Vector3(6, 0.1, -10))
	_face_to(g, Vector3(6, 0, -40))   # looking away
	await _wait(2.0)
	_check("an enemy looking away stays calm", g.perception.state == Perception.CALM, Perception.NAMES[g.perception.state])
	player.last_noise_ms = Time.get_ticks_msec()
	await _wait(0.6)
	player.last_noise_ms = Time.get_ticks_msec()
	await _wait(0.6)
	_check("the sound of a fight is heard", g.perception.state != Perception.CALM, Perception.NAMES[g.perception.state])
	g.alarm(player.global_position)
	await _wait(0.3)
	# Ayxan slips away out of sight and earshot; step the brain by hand so the enemy
	# cannot chase him down meanwhile
	g.set_physics_process(false)
	g.global_position = Vector3(6, 0.1, -12)
	_face_to(g, Vector3(6, 0, -40))
	player.global_position = Vector3(0, 0.1, 17.5)
	player.last_noise_ms = -100000
	var searched := false
	for i in 20:
		g._perceive(0.25)
		if g.perception.state == Perception.SEARCH:
			searched = true
			break
	_check("losing him starts a search", searched, Perception.NAMES[g.perception.state])
	for i in 40:
		g._perceive(0.25)
	_check("after 8 s of searching it gives up", g.perception.state == Perception.CALM and not g.aggro, Perception.NAMES[g.perception.state])


func _tokens() -> void:
	await _clear()
	for i in 5:
		mode.spawn_foe("ash_shade", Vector3(-4 + i * 2, 0.1, 5), {"roll": false})
	var max_used := 0
	for i in 40:
		await _wait(0.1)
		max_used = maxi(max_used, player._tokens_used)
	_check("five attackers never hold more than 3 tokens", max_used <= 3 and max_used > 0, str(max_used))
	await _clear()
	var giant = mode.spawn_foe("ash_giant", Vector3(0, 0.1, 4), {"roll": false})
	_check("an elite costs 2 tokens", giant._token_cost == 2)


func _archer() -> void:
	await _clear()
	player.make_invulnerable(30.0)
	var a = mode.spawn_foe("ash_archer", Vector3(0, 0.1, -4), {"roll": false})
	var shot := false
	for i in 50:
		await _wait(0.1)
		for n in mode.get_children():
			if n.get_script() != null and n.get_script().resource_path.ends_with("projectile.gd"):
				shot = true
		if shot:
			break
	_check("the ash archer shoots from range", shot)
	_check("archers keep their distance", a.global_position.distance_to(player.global_position) > 5.0,
		"%.1f m" % a.global_position.distance_to(player.global_position))
	player.invulnerable_until = 0


func _bomber() -> void:
	await _clear()
	var hp: float = player.health
	var b = mode.spawn_foe("ash_bomber", Vector3(0, 0.1, 5.5), {"roll": false})
	await _wait(1.6)   # rises out of the ground
	player.global_position = b.global_position + Vector3(0, 0, 2.2)
	player.invulnerable_until = 0
	b._begin_attack(b._attack_by_id("explode"))
	var gone := false
	for i in 60:
		await _wait(0.1)
		if not is_instance_valid(b) or b.dead:
			gone = true
			break
	_check("the bomber runs in and blows itself up", gone)
	_check("the blast hurts and burns", player.health < hp, "%.0f → %.0f" % [hp, player.health])


func _shaman() -> void:
	await _clear()
	player.make_invulnerable(30.0)
	var sh = mode.spawn_foe("ash_shaman", Vector3(0, 0.1, -6), {"roll": false})
	var ally = mode.spawn_foe("ash_shade", Vector3(3, 0.1, -4), {"roll": false})
	var warded := false
	for i in 40:
		await _wait(0.1)
		if is_instance_valid(ally) and ally.ward > 0.0:
			warded = true
			break
	_check("the shaman wards an ally", warded)
	var victim = mode.spawn_foe("ash_shade", Vector3(-3, 0.1, -4), {"roll": false})
	await _wait(0.2)
	victim.receive_hit(victim.Hit.new().setup(player, 9999.0, "slash", 0.0, Vector3.ZERO))
	var raised := false
	for i in 80:
		await _wait(0.1)
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.risen:
				raised = true
		if raised:
			break
	_check("the shaman raises a fallen shade once", raised and sh._resurrects_left == 0)
	player.invulnerable_until = 0


func _affixes() -> void:
	await _clear()
	var base: float = DataDB.enemy("ash_shade")["stats"]["health"]
	var thick = mode.spawn_foe("ash_shade", Vector3(-6, 0.1, -6), {"affixes": ["thick"]})
	_check("Qalın: +60% health", absf(thick.max_health - base * 1.6) < 0.1, "%.0f" % thick.max_health)
	_check("affix names are prefixed", thick.display_name.begins_with("Kalın"), thick.display_name)
	var fast = mode.spawn_foe("ash_shade", Vector3(-3, 0.1, -6), {"affixes": ["fast"]})
	_check("Sürətli: +25% speed", absf(fast._speed - float(DataDB.enemy("ash_shade")["stats"]["speed"]) * 1.25) < 0.01)
	var hard = mode.spawn_foe("ash_shade", Vector3(0, 0.1, -6), {"affixes": ["unshakable"]})
	hard.set_physics_process(false)
	var r1: String = hard.receive_hit(hard.Hit.new().setup(player, 1.0, "slash", hard.max_stance + 1.0, Vector3.ZERO))
	var first_ok: bool = not hard.is_executable()
	hard.receive_hit(hard.Hit.new().setup(player, 1.0, "slash", hard.max_stance + 1.0, Vector3.ZERO))
	_check("Sarsılmaz: the first stance break glances off, the second lands", first_ok and hard.is_executable(), r1)
	var caller = mode.spawn_foe("ash_shade", Vector3(3, 0.1, -6), {"affixes": ["summoner"]})
	var count_before := get_tree().get_nodes_in_group("enemies").size()
	caller.receive_hit(caller.Hit.new().setup(player, caller.max_health * 0.6, "slash", 0.0, Vector3.ZERO))
	await _wait(0.3)
	_check("Çağıran: at half health it calls two helpers", get_tree().get_nodes_in_group("enemies").size() >= count_before + 2)
	var eye = _wild("ash_shade", Vector3(8, 0.1, -12), {"affixes": ["ash_eye"]})
	await _wait(1.6)   # rises out of the ground first
	_face_to(eye, Vector3(8, 0, -40))
	await _wait(0.6)
	_check("Kül Şahının gözü: sees Ayxan even looking away", eye.perception.state == Perception.COMBAT)
	await _clear()
	var hot = mode.spawn_foe("ash_shade", Vector3(0, 0.1, 2), {"affixes": ["flaming"]})
	var patches := false
	for i in 30:
		await _wait(0.1)
		for n in mode.get_children():
			if n.get_script() != null and n.get_script().resource_path.ends_with("aoe.gd"):
				patches = true
	_check("Alovlu: leaves burning ground", patches)
	await _clear()
	var hp: float = player.health
	var ven = mode.spawn_foe("ash_shade", Vector3(0, 0.1, 6.5), {"affixes": ["vengeful"]})
	ven.set_physics_process(false)
	ven.receive_hit(ven.Hit.new().setup(player, 9999.0, "slash", 0.0, Vector3.ZERO))
	await _wait(2.6)
	_check("Qisasçı: the corpse bursts 2 s later", player.health < hp, "%.0f → %.0f" % [hp, player.health])


func _adaptive() -> void:
	await _clear()
	var giant = mode.spawn_foe("ash_giant", Vector3(0, 0.1, -2), {"roll": false})
	giant.set_physics_process(false)
	for i in 8:
		player.habits.record("dodge")
	giant._update_adaptive()
	var sweep: float = giant.adaptive_weights.get("sweep", 1.0)
	var guard: float = giant.adaptive_weights.get("guard_break", 1.0)
	_check("dodge spam makes the giant favour sweeps", sweep > 2.0 and sweep > guard, "sweep ×%.2f, guard_break ×%.2f" % [sweep, guard])
	player.habits.clear()
	for i in 8:
		player.habits.record("block")
	giant._update_adaptive()
	_check("blocking makes it favour guard breakers", giant.adaptive_weights.get("guard_break", 1.0) > 2.0)
	var shade = mode.spawn_foe("ash_shade", Vector3(4, 0.1, -2), {"roll": false})
	shade._update_adaptive()
	_check("normal enemies do not adapt", shade.adaptive_weights.is_empty())


func _morale() -> void:
	await _clear()
	var b = mode.spawn_foe("bandit_sword", Vector3(0, 0.1, 4), {"roll": false})
	b.health = b.max_health * 0.15
	b._think_t = 0.0
	var broke := false
	for i in 20:
		await _wait(0.1)
		if b.surrendered or b._state == b.S.FLEE or not is_instance_valid(b):
			broke = true
			break
	_check("a hurt bandit alone breaks: surrenders or flees", broke)
	var ash = mode.spawn_foe("ash_shade", Vector3(3, 0.1, 4), {"roll": false})
	ash.health = ash.max_health * 0.1
	await _wait(1.0)
	_check("the ash never break", not ash.surrendered and ash._state != ash.S.FLEE)


func _levels() -> void:
	var f = Foe.new()
	f.configure("ash_shade", 5, {"roll": false})
	_check("HP = base × (1 + 0.12 (L−1))", absf(f.max_health - 60.0 * 1.48) < 0.01, "%.1f" % f.max_health)
	_check("damage = base × (1 + 0.08 (L−1))", absf(f._dmg_scale - 1.32) < 0.001)
	f.target = player
	var g = Foe.new()
	g.configure("ash_shade", 6, {"roll": false})
	g.target = player
	_check("5+ levels above Ayxan shows a skull", g.is_deadly() and not f.is_deadly())
	var n = Foe.new()
	n.configure("ash_shade", 1, {"night": true, "roll": false})
	_check("ash are 20% stronger at night", absf(n.max_health - 72.0) < 0.01)
	_check("XP = base × L × clamp(1 + 0.1 ΔL, 0.2, 2)", absf(f.xp_value(1) - 12.0 * 5 * 1.4) < 0.01, "%.1f" % f.xp_value(1))
	for x in [f, g, n]:
		x.free()


func _lod() -> void:
	await _clear()
	var far = _wild("ash_shade", Vector3(0, 0.1, -80))
	await _wait(1.2)
	far.global_position = Vector3(0, 0.1, -80)
	far._update_lod()
	_check("60–120 m: simplified AI", far.lod == Foe.LOD.MID, str(far.lod))
	far.global_position = Vector3(0, 0.1, -160)
	far._update_lod()
	_check("beyond 120 m: frozen", far.lod == Foe.LOD.FROZEN, str(far.lod))
	far.global_position = Vector3(0, 0.1, -10)
	far._update_lod()
	_check("close again: full AI", far.lod == Foe.LOD.FULL)


func _leopard() -> void:
	await _clear()
	var cat = mode.spawn_foe("leopard", Vector3(0, 0.1, -3), {"roll": false})
	await _wait(0.3)
	cat.set_physics_process(false)
	cat._attacks_done = 3
	cat._maybe_stealth()
	var mi: MeshInstance3D = cat._model.scene.find_children("*", "MeshInstance3D", true, false)[0]
	_check("the leopard melts into the shadows", cat._stealthed and mi.transparency > 0.5)
	cat.receive_hit(cat.Hit.new().setup(player, 1.0, "slash", 0.0, Vector3.ZERO))
	_check("a blow breaks its stealth", not cat._stealthed and mi.transparency == 0.0)
	cat.receive_hit(cat.Hit.new().setup(player, cat.max_health * 0.55, "slash", 0.0, Vector3.ZERO))
	_check("at half health it enters phase 2", cat._phase == 1 and cat._atk_speed > 1.0)
	_check("bosses carry a 3-token cost", cat._token_cost == 3)


func _territorial() -> void:
	await _clear()
	var w = _wild("wolf", Vector3(7, 0.1, -1))   # clear line of sight past the barrier
	_face_to(w, player.global_position)
	var warned := false
	for i in 30:
		await _wait(0.1)
		if w._state == w.S.WARN:
			warned = true
			break
	_check("a wolf growls a warning first", warned, "state %d, %s %.2f, aggro %s, engaged %s" % [w._state, Perception.NAMES[w.perception.state], w.perception.awareness, w.aggro, w._engaged_once])
	player.global_position = Vector3(0, 0.1, 17.5)
	await _wait(1.5)
	_check("backing off calms it down", w._state != w.S.WARN and not w.aggro)
