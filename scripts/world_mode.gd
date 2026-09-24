extends "res://scripts/chapter_base.gd"
## V3 Faza B: the Kür Vadisi slice as an open world. Ayxan starts by the western pass
## next to a cold hearth. Places are discovered by walking near them, hearths are
## lit to become rest and fast-travel points, chests hold nar toxumu (+1 flask), echo
## stones tell the valley's story, enemies guard their homes and return when you
## rest. [M] map, compass on top, F10 debug (teleport, time, weather), F6 streaming.

const OpenWorld := preload("res://scripts/world/open_world.gd")
const Ayxan := preload("res://scripts/player_v3/ayxan.gd")
const TPCamera := preload("res://scripts/camera/third_person_camera.gd")
const Foe := preload("res://scripts/enemies/foe.gd")
const DebugMenu := preload("res://scripts/debug/debug_menu.gd")
const Compass := preload("res://scripts/ui/compass.gd")
const WorldMap := preload("res://scripts/ui/world_map.gd")
const HearthMenu := preload("res://scripts/ui/hearth_menu.gd")
const Interactable := preload("res://scripts/world/interactable.gd")

const HINT := "WASD hərəkət · Shift qaçış · Space yayınma · LMB/F zərbə · RMB blok · C kilid\nE istifadə · R şərbət · M xəritə · F10 debug · F6 streaming · F3 FPS"
const AUTOSAVE_SECONDS := 300.0

var debug
var compass
var world_map
var hearth_menu
var _stream_label: Label
var _foes := {}                   # spawn key -> Foe
var _last_hearth := ""
var _discover_t := 0.0
var _autosave_t := 0.0
var _was_night := false
var _travelling := false
var _dead_handled := false


func _make_level() -> Node3D:
	return OpenWorld.new()


func _make_player() -> Node3D:
	return Ayxan.new()


func _make_camera() -> Node3D:
	return TPCamera.new()


func _setup() -> void:
	level.attach_camera(rig.camera)
	level.streamer.focus = player
	player.water_query = level.water.surface_at
	level.streamer.actor_requested.connect(_on_actor_requested)
	level.streamer.actors_released.connect(_on_actors_released)
	hud.set_hint(HINT)
	hud._place(hud._objective, Vector4(0.5, 0, 0.5, 0), Vector4(-420, 64, 420, 96))
	compass = Compass.new()
	hud._root.add_child(compass)
	world_map = WorldMap.new()
	add_child(world_map)
	world_map.setup(level.meta, DataDB.balance("world")["map"]["fog_cell"])
	world_map.player = player
	world_map.travel_requested.connect(_travel_to)
	hearth_menu = HearthMenu.new()
	add_child(hearth_menu)
	hearth_menu.rest_requested.connect(_rest)
	hearth_menu.travel_requested.connect(_travel_to)
	hearth_menu.map_requested.connect(func(): world_map.open(true))
	debug = DebugMenu.new()
	add_child(debug)
	_build_debug()
	_stream_label = Label.new()
	_stream_label.add_theme_font_size_override("font_size", 14)
	_stream_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.8))
	_stream_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_stream_label.position = Vector2(20, 130)
	_stream_label.visible = false
	hud._root.add_child(_stream_label)
	level.day_night.hour_changed.connect(_on_hour)
	Audio.music("ambient", 3.0)


func _begin(_mode: String) -> void:
	var continuing := Settings.demo == "" and GameState.load_game(GameState.WORLD_TEST_PATH)
	if not continuing:
		GameState.new_game()
	var w: Dictionary = GameState.world
	world_map.fog_from_string(w.get("fog", ""))
	if w.has("max_flasks"):
		player.max_flasks = int(w["max_flasks"])
		player.refill_flasks()
	if w.has("hour"):
		level.day_night.set_hour(float(w["hour"]))
	_last_hearth = w.get("last_hearth", "")
	if continuing and _last_hearth != "":
		_place_at_hearth(_last_hearth)
	level.refresh_braziers()
	set_controls(true)
	player.wake()
	if GameState.world_has("hearths", "hearth_west"):
		hud.set_objective("")
	else:
		hud.set_objective("Aşırım ocağını yandır [E]")
	hud.title_card("KÜR VADİSİ", "Közqaladan o yana — Faza B", 2.2)
	_demo_setup()


# --- Frame -------------------------------------------------------------------------------------

func _tick(delta: float) -> void:
	_update_mouse()
	RenderingServer.global_shader_parameter_set("player_position", player.global_position)
	if player.dead:
		if not _dead_handled:
			_dead_handled = true
		if Input.is_action_just_pressed("restart"):
			_respawn()
		return
	if Input.is_action_just_pressed("map") and not hearth_menu.is_open and not get_tree().paused:
		world_map.open(false)
	if Input.is_action_just_pressed("debug_stream"):
		_stream_label.visible = not _stream_label.visible
	_discover_t -= delta
	if _discover_t <= 0.0:
		_discover_t = 0.4
		_discover()
	_interact()
	_update_compass()
	if _stream_label.visible:
		_update_stream_label()
	_autosave_t += delta
	if _autosave_t > AUTOSAVE_SECONDS and not _in_combat():
		_autosave_t = 0.0
		_save()


func _update_mouse() -> void:
	var free: bool = get_tree().paused or radial.is_open or debug.is_open() or dialogue.is_active() \
		or player.dead or world_map.is_open or hearth_menu.is_open
	var want := Input.MOUSE_MODE_VISIBLE if free else Input.MOUSE_MODE_CAPTURED
	if Settings.capture_path != "":
		want = Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want
	pause_menu.enabled = not (world_map.is_open or hearth_menu.is_open)


func _in_combat() -> bool:
	for f in _foes.values():
		if is_instance_valid(f) and f.is_engaged() and f.global_position.distance_to(player.global_position) < 25.0:
			return true
	return false


# --- Discovery ---------------------------------------------------------------------------------

func _discover() -> void:
	var pos: Vector3 = player.global_position
	if world_map.reveal(pos, DataDB.balance("world")["map"]["reveal_radius"]):
		GameState.world["fog"] = world_map.fog_to_string()
	for p in level.meta["pois"]:
		if GameState.world_has("discovered", p["id"]):
			continue
		var prefab: Dictionary = DataDB.prefab(p["type"])
		var r: float = prefab.get("discover_radius", 35.0)
		var pp := Vector3(p["pos"][0], p["pos"][1], p["pos"][2])
		if Vector2(pos.x, pos.z).distance_to(Vector2(pp.x, pp.z)) < r:
			GameState.world_add("discovered", p["id"])
			Fx.notify("Kəşf edildi: " + p["name"])
			Audio.play("memory_burn", -14.0, 0.0)


# --- Interaction -------------------------------------------------------------------------------

func _interact() -> void:
	var best = null
	var best_d := 1e9
	for it in get_tree().get_nodes_in_group("interactables"):
		var d: float = player.global_position.distance_to(it.global_position)
		if d < it.use_range and d < best_d:
			best = it
			best_d = d
	var exec := _execution_prompt()
	if exec != "":
		hud.set_prompt(exec)
		return
	if best == null:
		hud.set_prompt("")
		return
	var text: String = best.prompt()
	hud.set_prompt(text)
	if text != "" and Input.is_action_just_pressed("interact") and not _in_combat_close():
		_use(best)


func _execution_prompt() -> String:
	for c in get_tree().get_nodes_in_group("enemies"):
		if c.has_method("is_executable") and c.is_executable() and player.global_position.distance_to(c.global_position) < 2.8:
			return "[E]  Köz İnfazı"
	return ""


func _in_combat_close() -> bool:
	for f in _foes.values():
		if is_instance_valid(f) and f.is_engaged() and f.global_position.distance_to(player.global_position) < 10.0:
			return true
	return false


func _use(it) -> void:
	match it.kind:
		"hearth":
			var id: String = it.hearth_id()
			if not GameState.world_has("hearths", id):
				GameState.world_add("hearths", id)
				GameState.world_add("discovered", id)
				it.refresh()
				level.refresh_braziers()
				Fx.fire_nova(it.global_position, 3.0)
				Fx.shake(0.3)
				Audio.play("memory_burn", -4.0, 0.0)
				hud.banner("Ocaq yandı — " + it.poi["name"])
				if hud._objective.text != "":
					hud.set_objective("")
				_last_hearth = id
				_save()
			else:
				_last_hearth = id
				var others: Array = level.hearth_pois().filter(func(p): return p["id"] != id and GameState.world_has("hearths", p["id"]))
				hearth_menu.open(it.poi, others)
		"chest":
			GameState.world_add("chests", it.key)
			it.open_chest()
			Audio.play("drink", -6.0, 0.0)
			match it.data.get("reward", "ember"):
				"flask_seed":
					player.max_flasks = mini(player.max_flasks + 1, int(DataDB.balance("combat")["flask"]["max_charges"]))
					player.refill_flasks()
					GameState.world["max_flasks"] = player.max_flasks
					Fx.notify("Nar toxumu: nar şərbəti +1 (%d)" % player.max_flasks)
				_:
					player.gain_ember(40.0)
					Fx.notify("Köz qırıntıları: köz +40")
			_save()
		"echo":
			GameState.world_add("echoes", it.key)
			hud.show_whisper(it.data["text"])
			Audio.play("memory_burn", -10.0, 0.0)


# --- Hearths: rest, travel, death --------------------------------------------------------------

func _rest() -> void:
	player.heal(player.max_health)
	player.refill_flasks()
	# Everything you killed comes back, like the ash always does
	GameState.world["killed"] = []
	for f in _foes.values():
		if is_instance_valid(f):
			f.queue_free()
	_foes.clear()
	for p in level.meta["pois"]:
		if level.streamer.is_full(p["id"]):
			level.streamer.spawn_actors(p)
	hud.banner("Dincəldin. Kül yenə qalxdı.")
	Fx.fire_nova(player.global_position, 2.0)
	_save()


func _travel_to(id: String) -> void:
	if _travelling:
		return
	_travelling = true
	player.input_locked = true
	hud.title_card("", "", 0.6)
	await get_tree().create_timer(0.35).timeout
	_place_at_hearth(id)
	_last_hearth = id
	for f in _foes.values():
		if is_instance_valid(f) and f.global_position.distance_to(player.global_position) > 80.0:
			f.queue_free()
	player.input_locked = false
	_travelling = false
	_save()


func _place_at_hearth(id: String) -> void:
	var p: Dictionary = level.streamer.poi_by_id(id)
	if p.is_empty():
		return
	var pos := Vector3(p["pos"][0] + 2.5, p["pos"][1] + 0.6, p["pos"][2] + 3.0)
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.face_towards(Vector3(p["pos"][0], pos.y, p["pos"][2]))
	rig.snap()
	level.streamer.refresh()


func _on_player_died() -> void:
	Audio.music("", 1.0)
	Audio.play("sting_defeat", -2.0, 0.0)
	await get_tree().create_timer(1.2).timeout
	hud.show_card("KÖZ SÖNDÜ", "Son ocağında oyanacaqsan.", "[R] — oyan", 0.75)


func _respawn() -> void:
	_dead_handled = false
	hud._card.visible = false
	player.dead = false
	player.health = player.max_health
	player.health_changed.emit(player.health, player.max_health)
	player.stamina = player.max_stamina
	player._enter(player.S.MOVE)
	player._model.cancel_action()
	player.refill_flasks()
	var at := _last_hearth if _last_hearth != "" else "hearth_west"
	_place_at_hearth(at)
	_rest()
	Audio.music("ambient", 2.0)


func _save() -> void:
	GameState.world["hour"] = level.day_night.hour
	GameState.world["last_hearth"] = _last_hearth
	GameState.world["fog"] = world_map.fog_to_string()
	if Settings.demo == "":
		GameState.save_game(GameState.WORLD_TEST_PATH)


# --- Enemies -----------------------------------------------------------------------------------

func _on_actor_requested(_poi: Dictionary, actor: Dictionary, key: String, pos: Vector3) -> void:
	if GameState.world_has("killed", key):
		return
	if actor.get("night_only", false) and not level.day_night.is_night():
		return
	if _foes.has(key) and is_instance_valid(_foes[key]):
		return
	var f = Foe.new()
	f.configure(actor["enemy"], int(actor.get("level", 1)))
	f.aggro_range = 16.0
	f.home = pos
	f.spawn_key = key
	f.ground_query = level.height_at
	add_child(f)
	f.global_position = pos
	f.target = player
	_foes[key] = f
	f.killed.connect(func(_x): _on_foe_killed(key))


func _on_foe_killed(key: String) -> void:
	GameState.world_add("killed", key)
	_foes.erase(key)


func _on_actors_released(poi_id: String) -> void:
	for key in _foes.keys():
		if key.begins_with(poi_id + "@"):
			var f = _foes[key]
			if is_instance_valid(f) and not f.is_engaged():
				f.queue_free()
				_foes.erase(key)


## Night-only foes rise at dusk and sink back at dawn.
func _on_hour(_h: int) -> void:
	var night: bool = level.day_night.is_night()
	if night == _was_night:
		return
	_was_night = night
	if night:
		Fx.notify("Gecə düşdü. Kölgələr qalxır.")
		for p in level.meta["pois"]:
			if level.streamer.is_full(p["id"]):
				level.streamer.spawn_actors(p)
	else:
		for key in _foes.keys():
			var f = _foes[key]
			if is_instance_valid(f) and not f.is_engaged() and f.level >= 1 and _is_night_only(key):
				f.queue_free()
				_foes.erase(key)


func _is_night_only(key: String) -> bool:
	var parts := key.split("@")
	var p: Dictionary = level.streamer.poi_by_id(parts[0])
	if p.is_empty():
		return false
	var actors: Array = DataDB.prefab(p["type"]).get("actors", [])
	var i := int(parts[1])
	return i < actors.size() and actors[i].get("night_only", false)


# --- Compass and overlays ----------------------------------------------------------------------

func _update_compass() -> void:
	var f: Vector3 = rig.flat_forward()
	compass.heading = atan2(f.x, -f.z)
	var pos: Vector3 = player.global_position
	var list: Array = []
	for p in level.meta["pois"]:
		var pp := Vector3(p["pos"][0], p["pos"][1], p["pos"][2])
		var dist := Vector2(pos.x, pos.z).distance_to(Vector2(pp.x, pp.z))
		var is_hearth: bool = p["type"] == "hearth"
		var known := GameState.world_has("discovered", p["id"])
		if is_hearth and (known or GameState.world_has("hearths", p["id"])):
			list.append({"bearing": Compass.bearing(pos, pp), "dist": dist, "label": p["name"],
				"kind": "hearth" if GameState.world_has("hearths", p["id"]) else "hearth_cold"})
		elif known and dist < 400.0 and dist > 12.0:
			list.append({"bearing": Compass.bearing(pos, pp), "dist": dist, "label": p["name"], "kind": "place"})
	if world_map.marker != null:
		var m: Vector3 = world_map.marker
		list.append({"bearing": Compass.bearing(pos, m), "dist": Vector2(pos.x, pos.z).distance_to(Vector2(m.x, m.z)), "label": "İşarə", "kind": "marker"})
	if not GameState.world_has("hearths", "hearth_west"):
		var h: Dictionary = level.streamer.poi_by_id("hearth_west")
		var hp := Vector3(h["pos"][0], 0, h["pos"][2])
		list.append({"bearing": Compass.bearing(pos, hp), "dist": Vector2(pos.x, pos.z).distance_to(Vector2(hp.x, hp.z)), "label": "Ocaq", "kind": "objective"})
	compass.markers = list


func _update_stream_label() -> void:
	var c: Dictionary = level.streamer.loaded_count()
	var st: Dictionary = level.streamer.stats
	var cell: Vector2i = level.streamer.cell_of(player.global_position)
	_stream_label.text = "STREAMING (F6)\nhüceyrə %d,%d  ·  tam %d  ·  vizual %d  ·  ağac kolliziyası %d  ·  gözləyən %d\nson yükləmə: thread %.1f ms, əsas %.1f ms, növbə %d, cəmi %d\nFPS %d  ·  draw calls %d  ·  primitivlər %dk  ·  obyektlər %d\nsaat %s  ·  hava: %s  ·  düşmən %d  ·  mövqe (%.0f, %.1f, %.0f)" % [
		cell.x, cell.y, c["full"], c["visual"], c["trees"], c["pending"],
		st["worker_ms"], st["last_ms"], st["jobs"], st["loads"],
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		level.day_night.clock_text(), level.weather.label(), _foes.size(),
		player.global_position.x, player.global_position.y, player.global_position.z]


# --- Debug (F10) -------------------------------------------------------------------------------

func _build_debug() -> void:
	debug.section("Teleport")
	for p in level.meta["pois"]:
		var id: String = p["id"]
		debug.button(p["name"], func(): _teleport(id))
	debug.section("Vaxt")
	for pair in [["Səhər 06:00", 6.0], ["Günorta 12:00", 12.0], ["Axşam 19:00", 19.0], ["Gecə 00:00", 0.0]]:
		var h: float = pair[1]
		debug.button(pair[0], func(): level.day_night.set_hour(h))
	debug.button("Vaxtı dayandır / davam", func(): level.day_night.paused = not level.day_night.paused)
	debug.section("Hava")
	for s in ["clear", "cloudy", "rain", "fog"]:
		var state: String = s
		debug.button(level.weather.NAMES[s], func(): level.weather.set_state(state, true))
	debug.section("Dünya")
	debug.button("Bütün ocaqları yandır", func():
		for p in level.hearth_pois():
			GameState.world_add("hearths", p["id"])
		level.refresh_braziers()
		for it in get_tree().get_nodes_in_group("interactables"):
			it.refresh())
	debug.button("Xəritəni tam aç", func():
		for p in level.meta["pois"]:
			GameState.world_add("discovered", p["id"])
		world_map.fog.fill(1))
	debug.button("Dincəl (düşmənlər qayıdır)", _rest)
	debug.section("Oyunçu")
	debug.button("Tam can + şərbət", func():
		player.heal(player.max_health)
		player.refill_flasks())
	debug.button("Köz 100", func(): player.gain_ember(100.0))
	for id in ["sword", "sword_shield", "mace"]:
		debug.button(DataDB.weapon(id)["name"], func(): player.equip(id))


func _teleport(id: String) -> void:
	var p: Dictionary = level.streamer.poi_by_id(id)
	var pos := Vector3(p["pos"][0] + 4.0, 0, p["pos"][2] + 6.0)
	pos.y = level.height_at(pos.x, pos.z) + 1.0
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player._fall_from = NAN
	rig.snap()
	level.streamer.refresh()


# --- Capture demos -----------------------------------------------------------------------------

## world_start | world_village | world_castle | world_lake | world_night | world_rain | world_map |
## world_meadow | world_forest | world_dusk | world_hearth | world_selftest (automated checks)
func _demo_setup() -> void:
	match Settings.demo:
		"world_selftest":
			var t = load("res://scripts/debug/world_selftest.gd").new()
			t.mode = self
			t.player = player
			add_child(t)
			t.run()
		"world_village":
			_demo_view(Vector3(290, 0, 380), Vector3(304, 14, 342), 12.0)
		"world_castle":
			_demo_view(Vector3(318, 0, 168), Vector3(395, 40, 106), 11.0)
		"world_hearth":
			GameState.world_add("hearths", "hearth_west")
			level.day_night.set_hour(20.2)
			_demo_view(Vector3(118, 0, 318), Vector3(128, 12, 298), 11.0)
			get_tree().create_timer(0.8).timeout.connect(func():
				for it in get_tree().get_nodes_in_group("interactables"):
					it.refresh())
		"world_lake":
			_demo_view(Vector3(345, 0, 350), Vector3(400, 7, 400), 15.0)
		"world_night":
			level.day_night.set_hour(23.0)
			_demo_view(Vector3(300, 0, 300), Vector3(304, 16, 342), 12.0)
		"world_rain":
			level.weather.set_state("rain", true)
			_demo_view(Vector3(200, 0, 300), Vector3(258, 20, 224), 11.0)
		"world_meadow":
			_demo_view(Vector3(292, 0, 250), Vector3(258, 20, 224), 11.0)
		"world_forest":
			_demo_view(Vector3(400, 0, 470), Vector3(446, 20, 468), 11.0)
		"world_dusk":
			level.day_night.set_hour(19.0)
			_demo_view(Vector3(160, 0, 260), Vector3(258, 25, 224), 11.0)
		"world_map":
			for p in level.meta["pois"]:
				GameState.world_add("discovered", p["id"])
			GameState.world_add("hearths", "hearth_west")
			world_map.reveal(Vector3(256, 0, 256), 200.0)
			process_mode = Node.PROCESS_MODE_ALWAYS
			get_tree().create_timer(1.0).timeout.connect(func(): world_map.open(false))
	if Settings.demo.begins_with("world"):
		level.day_night.paused = Settings.demo != "world_start"


func _demo_view(at: Vector3, look: Vector3, h := 10.0) -> void:
	var pos := Vector3(at.x, level.height_at(at.x, at.z) + 1.0, at.z)
	player.global_position = pos
	player.face_towards(look)
	var to := look - pos
	rig.yaw = atan2(-to.x, -to.z)
	rig.pitch = deg_to_rad(-8.0)
	rig.snap()
	rig.yaw = atan2(-to.x, -to.z)
	level.streamer.refresh()
