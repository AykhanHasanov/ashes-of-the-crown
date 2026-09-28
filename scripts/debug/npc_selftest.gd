extends Node
## Headless checks for the NPC data model, NPC state, spawning from WorldState, name
## blanking (NPC names and the protagonist's name in subtitles), the companion ally (downed /
## help up / recover, never hurting the protagonist), burn contexts and the fire wheel's
## hold-to-confirm. Runs in the test host (scenes/tests/echo_host.tscn: test yard, the real
## protagonist). Uses its own save folder.
## Run: godot --headless --path . res://scenes/tests/npc_test.tscn   (exit code = failures)

const NpcRegistry := preload("res://scripts/core/npc_registry.gd")
const NpcSpawner := preload("res://scripts/npc/npc_spawner.gd")
const Names := preload("res://scripts/core/names.gd")
const Foe := preload("res://scripts/enemies/foe.gd")
const Hit := preload("res://scripts/combat/hit.gd")
const Melee := preload("res://scripts/combat/melee.gd")
const HOST := "res://scenes/tests/echo_host.tscn"
const TEST_DIR := "user://test_npc_saves/"
const PEOPLE := [&"anar", &"ehliman", &"elvin", &"esref", &"ibrahim", &"rufet", &"sabir", &"sahbaz"]
const YARD := Vector3(4, 0, 4)

var _fails := 0
var _events: Array = []
var host: Node
var spawner


func _ready() -> void:
	SaveManager.directory = TEST_DIR
	SaveManager.allow_in_demo = true
	var dummy := Node.new()
	get_tree().root.add_child.call_deferred(dummy)
	_start.call_deferred(dummy)


func _start(dummy: Node) -> void:
	get_tree().current_scene = dummy
	_run()


func _run() -> void:
	_wipe()
	EventBus.npc_moved.connect(func(id, a, b): _events.append(["moved", id, a, b]))
	EventBus.npc_rescued.connect(func(id): _events.append(["rescued", id]))
	EventBus.npc_died.connect(func(id, c): _events.append(["died", id, c]))
	EventBus.npc_relationship_changed.connect(func(id, a, b): _events.append(["rel", id, a, b]))
	WorldState.new_game()
	SaveManager.active_slot = 1
	_definitions()
	_state()
	_save_and_migration()
	get_tree().change_scene_to_file(HOST)
	await _until(func(): return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == HOST \
		and get_tree().current_scene.get("player") != null, 15.0)
	await _frames(5)
	host = get_tree().current_scene
	spawner = NpcSpawner.new()
	spawner.player = host.player
	spawner.place = func(loc: String) -> Variant: return YARD if loc == "yard" else null
	host.add_child(spawner)
	await _spawning()
	await _names()
	await _ally()
	await _wheel()
	_wipe()
	print("NPC TESTS DONE, failures: ", _fails)
	get_tree().quit(_fails)


# --- Data --------------------------------------------------------------------------------------

func _definitions() -> void:
	var ids: Array = NpcRegistry.all().filter(func(d): return not d.speaker_only).map(func(d): return d.id)
	_check("the registry holds the cast: 8 people (7 residents + Rüfət)", ids == PEOPLE, str(ids))
	var looks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/looks.json"))
	var ok := true
	for id in PEOPLE:
		var d: Resource = NpcRegistry.get_def(id)
		var name := tr(d.name_key)
		if name == d.name_key or name == "" or not looks.has(d.look_id) or d.personality_notes == "" \
				or not Barks.has_line(d.voice_profile, "greet"):
			ok = false
			print("   bad definition: ", id)
	_check("every NPC has a name key, a look, a voice and personality notes", ok)
	_check("Rüfət is the only companion", NpcRegistry.all().filter(func(d): return d.companion).map(func(d): return d.id) == [&"rufet"])
	var ks: Resource = NpcRegistry.get_def(&"kul_sahi")
	_check("Kül Şahı: a speaker that ignores burned names (data flag)", ks.speaker_only and ks.ignores_burned_names
		and NpcRegistry.all().filter(func(d): return d.ignores_burned_names).size() == 1)


# --- State -------------------------------------------------------------------------------------

func _state() -> void:
	WorldState.new_game()
	var all_ok := true
	for id in PEOPLE:
		var r := WorldState.get_npc(id)
		all_ok = all_ok and r == {"alive": true, "location_id": NpcRegistry.get_def(id).home_location_id, "rescued": false,
			"relationship": 0, "death_cause": "", "flags": {}}
	_check("a new game has every NPC alive, at home, not rescued, relationship 0", all_ok)
	_events.clear()
	_check("move_npc", WorldState.move_npc(&"sabir", "kurkend") and WorldState.get_npc_location(&"sabir") == "kurkend"
		and _events == [["moved", &"sabir", "", "kurkend"]])
	_events.clear()
	_check("rescue moves the NPC to son_ocaq (npc_rescued, npc_moved)", WorldState.rescue_npc(&"sabir")
		and WorldState.get_npc_location(&"sabir") == WorldState.SON_OCAQ and WorldState.is_npc_rescued(&"sabir")
		and _events == [["rescued", &"sabir"], ["moved", &"sabir", "kurkend", "son_ocaq"]])
	_check("a rescued NPC cannot be rescued again", not WorldState.rescue_npc(&"sabir"))
	_events.clear()
	WorldState.change_npc_relationship(&"elvin", 3)
	WorldState.change_npc_relationship(&"elvin", -5)
	_check("relationship changes (npc_relationship_changed old → new)", WorldState.get_npc_relationship(&"elvin") == -2
		and _events == [["rel", &"elvin", 0, 3], ["rel", &"elvin", 3, -2]])
	_events.clear()
	_check("death is recorded with its cause (npc_died)", WorldState.kill_npc(&"esref", "fell at the gate")
		and not WorldState.is_npc_alive(&"esref") and WorldState.get_npc_death_cause(&"esref") == "fell at the gate"
		and _events == [["died", &"esref", "fell at the gate"]])
	_check("the dead stay dead: no second death, no moving, no rescue", not WorldState.kill_npc(&"esref")
		and not WorldState.move_npc(&"esref", "kurkend") and not WorldState.rescue_npc(&"esref"))
	_check("dialogue conditions alive / dead / rescued", WorldState.check("alive:sabir") and not WorldState.check("dead:sabir")
		and WorldState.check("dead:esref") and not WorldState.check("alive:esref") and WorldState.check("rescued:sabir")
		and not WorldState.check("rescued:elvin") and not WorldState.check("dead:nobody"))
	WorldState.set_npc_flag(&"elvin", &"met", true)
	_check("per-NPC flags", WorldState.get_npc_flag(&"elvin", &"met") == true and WorldState.get_npc_flag(&"elvin", &"x", 7) == 7)


func _save_and_migration() -> void:
	# The state from _state(), plus burns from both places
	Memory.burn(&"father_voice")
	WorldState.burn_memory(&"first_sword", &"echo")
	_check("burn context: fire wheel / offer → combat, echo → echo", WorldState.get_burn_context(&"father_voice") == &"combat"
		and WorldState.get_burn_context(&"first_sword") == &"echo" and WorldState.get_burn_context(&"mother_name") == &"")
	var before := WorldState.to_dict()
	SaveManager.save(1)
	WorldState.new_game()
	SaveManager.load_slot(1)
	var after := WorldState.to_dict()
	_check("save/load keeps every NPC record", after["npcs"] == before["npcs"], str(after["npcs"].get("esref")))
	_check("save/load keeps burn contexts", after["player"]["burn_context"] == {"father_voice": "combat", "first_sword": "echo"})
	# A v2 save: burned memories without a context, and the reserved free-form NPC records
	var v2 := {"meta": {"save_version": 2}, "player": {"stats": {}, "memories": {"rufet_face": "burned", "sabir_lesson": "kept"}},
		"story": {}, "world": {}, "flags": {}, "npcs": {"sabir": {"alive": false, "trust": 2}, "ghost": {"alive": true}}}
	var clean := WorldState.normalize(SaveManager.migrate(JSON.parse_string(JSON.stringify(v2))))
	_check("migration v2 → v3: old burns get context combat", clean["player"]["burn_context"] == {"rufet_face": "combat"}
		and int(clean["meta"]["save_version"]) == 3)
	_check("migration v2 → v3: NPC records filled, old fields kept as flags, unknown ids dropped",
		clean["npcs"]["sabir"]["alive"] == false and clean["npcs"]["sabir"]["flags"] == {"trust": 2}
		and clean["npcs"]["rufet"]["alive"] == true and not clean["npcs"].has("ghost") and clean["npcs"].size() == NpcRegistry.all().size())
	var legacy := {"version": 4, "chapter": 1, "checkpoint": "", "flags": {}, "echoes_seen": [], "memory": {"burned": ["mother_name"]}, "world": {}}
	var from_legacy := WorldState.normalize(SaveManager.migrate(legacy))
	_check("the whole chain v0 → v3 still works", from_legacy["player"]["burn_context"] == {"mother_name": "combat"}
		and from_legacy["npcs"].size() == NpcRegistry.all().size())


# --- Spawning from WorldState --------------------------------------------------------------------

func _spawning() -> void:
	WorldState.new_game()
	await _frames(3)
	_check("nobody is spawned where WorldState puts nobody", spawner.body(&"rufet") == null and spawner.body(&"sabir") == null)
	WorldState.move_npc(&"sabir", "yard")
	WorldState.move_npc(&"anar", "yard")
	WorldState.move_npc(&"rufet", WorldState.PARTY)
	await _frames(3)
	var sabir = spawner.body(&"sabir")
	_check("an NPC at a loaded place gets a body there", sabir != null and sabir.global_position.distance_to(YARD) < 6.0)
	_check("a companion in the party fights beside the protagonist", spawner.body(&"rufet") != null and spawner.body(&"rufet").has_method("help_up")
		and spawner.body(&"rufet").global_position.distance_to(host.player.global_position) < 5.0)
	WorldState.move_npc(&"elvin", "far_away_village")
	await _frames(3)
	_check("an NPC at a place that is not loaded has no body", spawner.body(&"elvin") == null)
	WorldState.kill_npc(&"sabir", "test")
	await _frames(3)
	_check("death removes the body", spawner.body(&"sabir") == null)
	spawner.refresh()
	await _frames(2)
	_check("the dead are never spawned again (refresh)", spawner.body(&"sabir") == null)
	SaveManager.save(1)
	SaveManager.load_slot(1)
	await _frames(3)
	_check("... nor after a save and load", spawner.body(&"sabir") == null and spawner.body(&"anar") != null)
	WorldState.rescue_npc(&"anar")
	await _frames(3)
	_check("rescue: the NPC leaves (to son_ocaq, the hub is not built)", spawner.body(&"anar") == null
		and WorldState.get_npc_location(&"anar") == "son_ocaq" and WorldState.is_npc_rescued(&"anar"))


# --- Names ---------------------------------------------------------------------------------------

func _names() -> void:
	var rufet = spawner.body(&"rufet")
	var blank := tr("NAME_FORGOTTEN")
	_check("NPC names come from their keys", Names.npc(&"rufet") == "Rüfet" and rufet.display_name == "Rüfet")
	WorldState.burn_memory(&"rufet_face")
	await _frames(1)
	_check("an NPC's name is blank once its name memory burned", Names.npc(&"rufet") == blank and rufet.display_name == blank)
	_check("other NPC names are untouched", Names.npc(&"sahbaz") == "Şahbaz")
	# The protagonist's name, burned
	WorldState.burn_memory(Names.PROTAGONIST_MEMORY, &"echo")
	_check("burned name: blank in NPC text and subtitles", Names.fill("Yardım et, {PROTAGONIST}!", &"rufet") == "Yardım et, %s!" % blank)
	_check("... but Kül Şahı always shows it (ignores_burned_names)", Names.fill("{PROTAGONIST} kimdi?", &"kul_sahi") == "Aras kimdi?")
	WorldState.burn_memory(&"rufet_face") # (already burned: no-op)
	var whisper := Memory.WHISPERS[Memory.WHISPERS.size() - 1] as String
	_check("Kül Şahı's whisper keeps the name", Names.fill(whisper, Memory.KUL_SAHI).contains("Aras"))
	# A real subtitle under Rüfət: the voice says the name, the text does not
	var said := Barks.say(rufet, "npc_rufet", "downed", 1.0, 1.85)
	await _frames(1)
	var sub = rufet.get_node_or_null("BarkSubtitle")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/voices/manifest.json"))
	var voiced: Array = manifest["profiles"]["npc_rufet"]["downed"].filter(func(e): return String(e["text"]).contains(Names.TOKEN))
	_check("Rüfət's subtitle blanks the burned name", said and sub != null and not sub.text.contains("Aras"), sub.text if sub else "no subtitle")
	_check("... while his voice lines still say it (token lines are voiced with the name)", not voiced.is_empty())
	# The dialogue box: speaker ids name the speaker and choose the rule
	host.dialogue.start({"start": {"speaker_id": "kul_sahi", "text": "...{PROTAGONIST}...", "end": true}})
	await _frames(2)
	var ks_line: String = host.dialogue._text.text
	host.dialogue.start({"start": {"speaker_id": "rufet", "text": "{PROTAGONIST}!", "end": true}})
	await _frames(2)
	_check("dialogue: Kül Şahı's line shows the name, Rüfət's shows the blank",
		ks_line == "...Aras..." and host.dialogue._text.text == blank + "!" and host.dialogue._name.text == blank)


# --- The ally ------------------------------------------------------------------------------------

func _ally() -> void:
	var p = host.player
	var rufet = spawner.body(&"rufet")
	p.global_position = Vector3(0, 0.1, 8)
	rufet.global_position = Vector3(0, 0.1, 5)
	await _frames(10)
	_check("the ally and the protagonist are on the same side", not rufet.is_hostile(p) and not p.is_hostile(rufet))
	_check("the protagonist's blows never find the ally, nor the ally's him",
		not Melee.targets(p, Vector3.FORWARD, 30.0, 360.0).has(rufet) and not Melee.targets(rufet, Vector3.FORWARD, 30.0, 360.0).has(p))
	# A real fight: a bandit set on Rüfət; the protagonist stands back and must stay untouched
	var f = Foe.new()
	f.configure("bandit_sword", 1, {"roll": false})
	host.add_child(f)
	f.global_position = Vector3(0, 0.1, -3)
	f.target = p
	f.retarget(rufet)
	var start_hp: float = p.health
	var foe_hp: float = f.health
	await _until(func(): return f.dead or f.health < foe_hp - 20.0, 15.0)
	_check("Rüfət fights: the bandit is hurt", f.health < foe_hp, "%.0f / %.0f" % [f.health, foe_hp])
	_check("the fight never hurt the protagonist", p.health == start_hp)
	# Downed, not dead
	f.retarget(rufet)
	var big = Hit.new().setup(f, 9999.0, "slash", 0.0, Vector3.ZERO)
	rufet.receive_hit(big)
	await _frames(2)
	_check("at 0 health he is DOWNED, not dead", rufet.is_down() and not rufet.dead and is_instance_valid(rufet))
	_check("... WorldState still has him alive", WorldState.is_npc_alive(&"rufet"))
	_check("... enemies turn back to the protagonist", f.target == p)
	_check("... and a downed man takes no more blows", rufet.receive_hit(Hit.new().setup(f, 10.0, "slash", 0.0, Vector3.ZERO)) == "ignored")
	await _seconds(2.0)
	_check("with an enemy near he stays down", rufet.is_down())
	_check("the protagonist helps him up", rufet.help_range() > 1.0 and rufet.help_up() and not rufet.is_down()
		and is_equal_approx(rufet.health, rufet.max_health * 0.5))
	await _seconds(float(DataDB.balance("allies")["rufet"]["downed"]["invulnerable_after"]) + 0.3)
	# Down again, the fight over: he gets up alone
	f.queue_free()
	await _frames(3)
	rufet.receive_hit(Hit.new().setup(p, 9999.0, "slash", 0.0, Vector3.ZERO))
	_check("down again", rufet.is_down())
	var calm: float = DataDB.balance("allies")["rufet"]["downed"]["recover_calm"]
	await _until(func(): return not rufet.is_down(), calm + 3.0)
	_check("with no enemy near he gets up by himself", not rufet.is_down()
		and is_equal_approx(rufet.health, rufet.max_health * 0.3))
	_check("ordinary combat never killed him", WorldState.is_npc_alive(&"rufet") and spawner.body(&"rufet") == rufet)


# --- The fire wheel: hold to confirm -------------------------------------------------------------

func _wheel() -> void:
	WorldState.new_game()
	WorldState.set_flag(&"wave_confirmed")   # the one-time "are you sure" dialog is not under test
	WorldState.keep_memory(&"first_sword")
	await _frames(3)
	var p = host.player
	var radial = host.radial
	# A tap is a strike, never a burn
	_press("ember_power", true)
	await _seconds(0.1)
	_press("ember_power", false)
	await _seconds(0.4)
	_check("a single press of the fire key burns nothing", WorldState.burned_memories().is_empty() and not radial.is_open)
	# Open, point, let go early
	_press("ember_power", true)
	await _until(func(): return radial.is_open, 2.0)
	var ids: Array = radial._items.map(func(i): return i["id"])
	_check("the wheel offers kept memories but never own_name", ids.has(&"first_sword") and not ids.has(Names.PROTAGONIST_MEMORY))
	radial.select("mother_name")
	await _seconds(0.7)
	_check("time is slowed while holding", Engine.time_scale < 0.5, str(Engine.time_scale))
	_check("the hold ring fills", radial.hold_progress() > 0.2 and radial.hold_progress() < 1.0)
	_press("ember_power", false)
	await _seconds(0.3)
	_check("letting go before the hold completes burns nothing", WorldState.burned_memories().is_empty() and not radial.is_open)
	await _seconds(1.2)   # wave cooldown
	# Changing the choice restarts the hold
	_press("ember_power", true)
	await _until(func(): return radial.is_open, 2.0)
	radial.select("mother_name")
	await _seconds(1.0)
	radial.select("first_sword")
	await _seconds(0.8)
	_check("changing the choice restarts the hold", WorldState.burned_memories().is_empty() and radial.is_open)
	# The full hold burns the kept memory, in combat
	await _until(func(): return not radial.is_open, 2.0)
	_press("ember_power", false)
	await _until(func(): return WorldState.has_burned(&"first_sword"), 2.0)
	_check("a full hold burns the chosen memory — a KEPT one too", WorldState.has_burned(&"first_sword")
		and WorldState.get_burn_context(&"first_sword") == &"combat" and WorldState.burned_memories().size() == 1)
	await _seconds(0.6)
	_check("time runs normally again", is_equal_approx(Engine.time_scale, 1.0))


# --- Helpers -------------------------------------------------------------------------------------

func _press(action: String, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	Input.parse_input_event(e)


func _until(cond: Callable, timeout: float) -> bool:
	var start := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) / 1000.0 < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


func _seconds(s: float) -> void:
	var start := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) / 1000.0 < s:
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wipe() -> void:
	var full := ProjectSettings.globalize_path(TEST_DIR)
	if DirAccess.dir_exists_absolute(full):
		for f in DirAccess.get_files_at(TEST_DIR):
			DirAccess.remove_absolute(full.path_join(f))
		DirAccess.remove_absolute(full)


func _check(label: String, ok: bool, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + label + ("" if detail == "" else "  (" + detail + ")"))
	if not ok:
		_fails += 1
