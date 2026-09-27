extends Node
## Automated checks for the V3 open world, run with --demo=world_selftest on
## scenes/world.tscn: discovery, hearths, chests, swimming, fall damage, slope sliding,
## streaming + enemy spawns, aggro/leash, fast travel and save data. Prints PASS/FAIL
## per check and quits with the failure count as exit code.

var mode      # world_mode
var player
var _fails := 0


func run() -> void:
	await _wait(1.5)
	await _discovery_and_hearth()
	await _chest()
	await _swim()
	await _fall()
	await _slide()
	await _streaming_and_enemies()
	await _travel()
	_save_data()
	print("WORLD SELFTEST DONE, failures: ", _fails)
	get_tree().quit(_fails)


func _check(name: String, ok: bool, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + name + ("" if detail == "" else "  (" + detail + ")"))
	if not ok:
		_fails += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _reset() -> void:
	player.dead = false
	player.heal(player.max_health)
	player.stamina = player.max_stamina
	player._exhausted_until_ms = 0
	player.invulnerable_until = 0
	player._model.position.y = 0.0
	player._enter(player.S.MOVE)
	player.velocity = Vector3.ZERO


func _put(pos: Vector3, above := 1.0) -> void:
	pos.y = mode.level.height_at(pos.x, pos.z) + above
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player._fall_from = NAN
	mode.rig.snap()
	mode.level.streamer.refresh()


func _interactable(kind: String, poi_id: String):
	for it in get_tree().get_nodes_in_group("interactables"):
		if it.kind == kind and it.poi["id"] == poi_id:
			return it
	return null


func _discovery_and_hearth() -> void:
	_reset()
	var h: Dictionary = mode.level.streamer.poi_by_id("hearth_west")
	_put(Vector3(h["pos"][0] + 2.0, 0, h["pos"][2] + 2.0))
	await _wait(1.5)
	_check("walking up to a place discovers it", GameState.world_has("discovered", "hearth_west"))
	var it = _interactable("hearth", "hearth_west")
	_check("the hearth streams in with its interactable", it != null)
	if it == null:
		return
	_check("a cold hearth asks to be lit", it.prompt().contains("yak"), it.prompt())
	mode._use(it)
	_check("lighting marks it lit and saved in the world state", GameState.world_has("hearths", "hearth_west"))
	_check("a lit hearth heals like a brazier", mode.level.braziers.size() == 1)
	_check("the prompt now offers a seat", it.prompt().contains("otur"), it.prompt())


func _chest() -> void:
	_reset()
	var p: Dictionary = mode.level.streamer.poi_by_id("nar_bagi")
	_put(Vector3(p["pos"][0] + 12.0, 0, p["pos"][2] + 6.0))
	await _wait(1.5)
	var it = _interactable("chest", "nar_bagi")
	_check("the grove chest streams in", it != null)
	if it == null:
		return
	var before: int = player.max_flasks
	mode._use(it)
	_check("nar toxumu adds a flask charge", player.max_flasks == before + 1 and player.flasks == player.max_flasks, "%d → %d" % [before, player.max_flasks])
	_check("an opened chest stays opened", it.is_used() and it.prompt() == "")


func _swim() -> void:
	_reset()
	var lake: Dictionary = mode.level.meta["lakes"][0]
	var c := Vector3(lake["center"][0] - 20.0, 0, lake["center"][1])
	player.global_position = Vector3(c.x, float(lake["level"]) - 0.5, c.z)
	player.velocity = Vector3.ZERO
	player._fall_from = NAN
	mode.rig.snap()
	await _wait(0.6)
	_check("deep water makes Ayxan swim", player._state == player.S.SWIM, str(player._state))
	var st: float = player.stamina
	await _wait(1.0)
	_check("swimming drains stamina", player.stamina < st - 3.0, "%.0f → %.0f" % [st, player.stamina])
	player._drain_stamina(999.0)
	var hp: float = player.health
	await _wait(1.0)
	_check("with no stamina the water takes health", player.health < hp, "%.0f → %.0f" % [hp, player.health])
	_reset()


func _fall() -> void:
	_reset()
	var spot := Vector3(300, 0, 230)
	_put(spot, 10.0)
	var hp: float = player.health
	await _wait(2.0)
	_check("a 10 m fall hurts", player.health < hp and not player.dead, "%.0f → %.0f" % [hp, player.health])
	_reset()
	_put(spot, 18.0)
	await _wait(2.5)
	_check("an 18 m fall kills", player.dead)
	mode._respawn()
	await _wait(0.5)
	_check("death wakes Ayxan at his last hearth", not player.dead and player.global_position.distance_to(Vector3(128, player.global_position.y, 298)) < 12.0)


func _slide() -> void:
	_reset()
	# Find a steep spot on the border mountains
	var steep := Vector3.ZERO
	for z in range(100, 400, 6):
		for x in range(20, 60, 3):
			var h0: float = mode.level.height_at(x, z)
			var h1: float = mode.level.height_at(x + 2, z)
			if absf(h1 - h0) / 2.0 > tan(deg_to_rad(44.0)) and absf(h1 - h0) / 2.0 < tan(deg_to_rad(50.0)):
				steep = Vector3(x + 1, 0, z)
				break
		if steep != Vector3.ZERO:
			break
	if steep == Vector3.ZERO:
		_check("found a steep slope to test sliding", false)
		return
	_put(steep, 0.3)
	var slid := false
	for i in 20:
		await _wait(0.1)
		if player._state == player.S.SLIDE:
			slid = true
			break
	_check("slopes steeper than 40° slide", slid, "at %s" % steep)
	_reset()


func _streaming_and_enemies() -> void:
	_reset()
	var fort: Dictionary = mode.level.streamer.poi_by_id("qaragac_fort")
	_put(Vector3(fort["pos"][0] - 60.0, 0, fort["pos"][2] + 30.0))
	await _wait(2.5)
	_check("the castle streams in fully nearby", mode.level.streamer.is_full("qaragac_fort"))
	var guards: Array = mode._foes.keys().filter(func(k): return k.begins_with("qaragac_fort@"))
	_check("its garrison spawns", guards.size() >= 3, str(guards.size()))
	var any_aggro := false
	var grounded := true
	for k in guards:
		var f = mode._foes[k]
		any_aggro = any_aggro or f.aggro
		grounded = grounded and absf(f.global_position.y - mode.level.height_at(f.global_position.x, f.global_position.z)) < 3.0
	_check("guards stay calm while Ayxan is far", not any_aggro)
	_check("far guards stay on the ground (no terrain collider there)", grounded)
	if guards.size() > 0:
		var g = mode._foes[guards[0]]
		player.global_position = g.global_position + g.forward() * 4.0 + Vector3(0, 1, 0)
		await _wait(1.0)
		_check("coming close wakes the guard", g.aggro, "state %d dist %.1f y %.1f/%.1f" % [g._state, g.global_position.distance_to(player.global_position), g.global_position.y, player.global_position.y])
		g.global_position = g.home + Vector3(60, 0, 0)
		await _wait(2.2)   # it finishes its swing first
		_check("a guard dragged past its leash gives up", not g.aggro and g._returning)
	_reset()
	_put(Vector3(40, 0, 470), 1.0)
	await _wait(2.5)
	_check("far away the castle drops to visuals only", not mode.level.streamer.is_full("qaragac_fort"))
	var c: Dictionary = mode.level.streamer.loaded_count()
	_check("streaming keeps a 3×3 full ring", c["full"] >= 1 and c["full"] < mode.level.meta["pois"].size(), str(c))


func _travel() -> void:
	_reset()
	GameState.world_add("hearths", "hearth_north")
	await mode._travel_to("hearth_north")
	await _wait(0.5)
	var h: Dictionary = mode.level.streamer.poi_by_id("hearth_north")
	_check("fast travel puts Ayxan at the hearth", player.global_position.distance_to(Vector3(h["pos"][0], player.global_position.y, h["pos"][2])) < 8.0)
	await _wait(1.5)
	_check("the destination streams in", mode.level.streamer.is_full("hearth_north"))


func _save_data() -> void:
	mode._save()
	var w: Dictionary = GameState.world
	_check("world state holds hearths, chests and fog", w.get("hearths", []).size() >= 2 and w.get("chests", []).size() >= 1 and w.get("fog", "") != "")
	var fresh = load("res://scripts/ui/world_map.gd").new()
	fresh.setup(mode.level.meta, 16.0)
	fresh.fog_from_string(w["fog"])
	_check("map fog survives a save round trip", fresh.explored_fraction() > 0.0 and absf(fresh.explored_fraction() - mode.world_map.explored_fraction()) < 0.001)
	fresh.free()
