extends Node
## Headless checks for the story foundation (vertical slice, phase A1): the condition
## language, name tokens and the scene-level "all names known", echo KEEP revealing names,
## dialogue graphs (branches, conditional and disabled answers, "(…)" pauses, sfx, actions),
## barks with conditions and the name guard, items, and the story's door actions.
## Run: godot --headless --path . res://scenes/tests/story_test.tscn   (exit code = failures)

const Names := preload("res://scripts/core/names.gd")
const Conditions := preload("res://scripts/core/conditions.gd")
const DialogueGraphs := preload("res://scripts/story/dialogue_graphs.gd")
const EchoRegistry := preload("res://scripts/core/echo_registry.gd")
const EchoDirector := preload("res://scripts/echoes/echo_director.gd")
const ItemPickup := preload("res://scripts/world/item_pickup.gd")
const HOST := "res://scenes/tests/echo_host.tscn"
const HUB := "res://scenes/son_ocaq.tscn"
const TEST_DIR := "user://test_story_saves/"

var _fails := 0


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
	_fixture_lines()
	_conditions()
	_names()
	await _dialogue()
	_barks()
	await _items()
	await _door_actions()
	_wipe()
	print("STORY TESTS DONE, failures: ", _fails)
	get_tree().quit(_fails)


## Lines for the tests only (the script's own lines arrive with phase B).
func _fixture_lines() -> void:
	var t := Translation.new()
	t.locale = TranslationServer.get_locale()
	for pair in [["TEST_PAUSE", "Sağsın. (…) Gerçekten sağsın."], ["TEST_ASK", "Seni tanıyor muyum?"], ["TEST_A", "Birinci cevap."],
			["TEST_B", "Gizli cevap."], ["TEST_C", "Kilitli cevap."], ["TEST_LOST", "(…) Ben biliyorum."], ["TEST_GIRL", "Küçük kız"],
			["TEST_END", "Git uyu."], ["TEST_WHO", "Kim o?"]]:
		t.add_message(pair[0], pair[1])
	TranslationServer.add_translation(t)


# --- The condition language -----------------------------------------------------------------------

func _conditions() -> void:
	WorldState.new_game()
	var t := func(x): return x == "a" or x == "b"
	_check("conditions: & joins, ! negates, empty is true", Conditions.eval("a & b", t) and not Conditions.eval("a & c", t)
		and Conditions.eval("!c", t) and not Conditions.eval("!a", t) and Conditions.eval("", t) and Conditions.eval(" a &  !c ", t))
	_check("known:protagonist follows his own knowledge", not WorldState.check("known:protagonist"))
	WorldState.apply("reveal_name:protagonist")
	_check("... revealed", WorldState.check("known:protagonist") and WorldState.check("known:rufet") and not WorldState.check("known:sona"))
	WorldState.keep_memory(&"first_sword")
	WorldState.burn_memory(&"mother_name")
	_check("mem:<id>=KEPT / BURNED / UNKNOWN", WorldState.check("mem:first_sword=KEPT") and WorldState.check("mem:mother_name=BURNED")
		and WorldState.check("mem:father_voice=UNKNOWN") and not WorldState.check("mem:first_sword=BURNED"))
	_check("any_burned / any_kept", WorldState.check("any_burned") and WorldState.check("any_kept"))
	WorldState.new_game()
	_check("... none at the start", not WorldState.check("any_burned") and not WorldState.check("any_kept"))
	WorldState.apply("item:+sirin_yazmasi")
	_check("has_item / item actions", WorldState.check("has_item:sirin_yazmasi") and not WorldState.check("!has_item:sirin_yazmasi"))
	WorldState.apply("item:-sirin_yazmasi")
	_check("... given away", not WorldState.check("has_item:sirin_yazmasi"))
	_check("joined:rufet comes from move_npc (never a flag)", WorldState.apply("move_npc:rufet:party") and WorldState.check("joined:rufet")
		and not WorldState.has_flag(&"joined"))
	WorldState.apply("set:sona_seen")
	WorldState.apply("grief:esref")
	_check("set: and grief: actions; compound conditions", WorldState.check("flag:sona_seen & grief:esref & !dead:esref"))


# --- Names --------------------------------------------------------------------------------------

func _names() -> void:
	WorldState.new_game()
	_check("{NPC_LOST:esref} always shows the name (Şirin)", Names.fill("{NPC_LOST:esref} kilim dokurdu.") == "Şirin kilim dokurdu.")
	_check("... Sona's lost one is Narin", Names.fill("{NPC_LOST:sona}") == "Narin")
	_check("outside echoes an unknown name is the epithet", Names.fill("{NPC:sahbaz}") == "Serdar")
	Names.scene_all_known = true
	_check("in an echo (scene override) every name is known — his own too", Names.fill("{NPC:sahbaz} / {NPC:kur}") == "Şahbaz / Kür"
		and Names.protagonist_label() == "Aras" and Names.fill("Küçük {PROTAGONIST}") == "Küçük Aras")
	WorldState.burn_memory(&"own_name", &"echo")
	_check("... but a burned name is still the blank", Names.fill("Küçük {PROTAGONIST}") == "Küçük " + tr("NAME_FORGOTTEN"))
	Names.scene_all_known = false
	# An echo KEPT reveals the names in it
	WorldState.new_game()
	var def: Resource = EchoRegistry.get_def(&"test_echo")
	var saved: PackedStringArray = def.reveals_on_keep
	def.reveals_on_keep = PackedStringArray(["sahbaz", "kur"])
	EchoDirector.apply_choice(def, &"burn")
	_check("echo BURNED: its names stay unknown", not WorldState.is_name_known(&"sahbaz") and not WorldState.is_name_known(&"kur"))
	WorldState.new_game()
	EchoDirector.apply_choice(def, &"keep")
	_check("echo KEPT: the names inside it become known (reveals_on_keep)", WorldState.is_name_known(&"sahbaz") and WorldState.is_name_known(&"kur"))
	def.reveals_on_keep = saved


# --- Dialogue graphs ------------------------------------------------------------------------------

func _dialogue() -> void:
	WorldState.new_game()
	var host := await _go(HOST)
	var dlg = host.dialogue
	var graph := DialogueGraphs.compile({"id": "t", "nodes": {
		"start": {"speaker": "rufet", "key": "TEST_PAUSE", "next": "who"},
		"who": {"speaker": "protagonist", "key": "TEST_ASK", "next": "c", "sfx": "ui_select"},
		"c": {"speaker": "protagonist", "choices": [
			{"key": "TEST_A", "next": "a", "do": ["set:chose_a"]},
			{"key": "TEST_B", "next": "b", "if": "flag:never"},
			{"key": "TEST_C", "next": "b", "disabled_if": "!flag:allowed"}]},
		"a": {"branch": [{"if": "flag:chose_a & !known:protagonist", "next": "lost"}, {"next": "b"}]},
		"lost": {"speaker": "sona", "key": "TEST_LOST", "do": ["reveal_name:sona", "silence_door:door_sona"], "end": true, "event": "done"},
		"b": {"speaker": "sona", "label_key": "TEST_GIRL", "key": "TEST_END", "end": true}}})
	_check("a graph compiles: speakers, keys, branches, choices", graph["start"]["speaker_id"] == "rufet" and graph["start"]["text_key"] == "TEST_PAUSE"
		and graph["who"]["speaker"] == "{PROTAGONIST}" and graph["a"].has("switch") and graph["c"]["choices"][0]["text_key"] == "TEST_A")
	var pauses: Array = []
	var actions: Array = []
	dlg.pause_changed.connect(func(p): pauses.append(p))
	dlg.action_requested.connect(func(a): actions.append(a))
	dlg.start(graph, "start", {"door_mode": false})
	await _frames(2)
	_check("\"(…)\" is a pause, not text", not dlg.shown_text().contains("(…)") and dlg.shown_text() == "Sağsın. Gerçekten sağsın.", dlg.shown_text())
	await _until(func(): return not dlg._typing, 6.0)
	_check("... the typing stops for it (pause_changed true, then false)", pauses == [true, false], str(pauses))
	_check("the speaker label: Rüfət is known", dlg._name.text == "Rüfet")
	dlg._advance()
	await _typed(dlg)
	_check("Aras's own line: no name label until he knows it", dlg._name.text == "" and dlg.node_id == "who")
	dlg._advance()
	await _typed(dlg)
	_check("answers: a false `if` hides one; `disabled_if` greys one", dlg.choice_texts().size() == 2 and dlg.choice_enabled(0) and not dlg.choice_enabled(1))
	dlg.choose(1)
	await _frames(2)
	_check("... a greyed answer cannot be taken", dlg.node_id == "c")
	dlg.choose(0)
	await _typed(dlg)
	_check("branch: the first entry whose condition holds; actions run", dlg.node_id == "lost" and WorldState.has_flag(&"chose_a")
		and WorldState.is_name_known(&"sona"))
	_check("the label follows the reveal at once", dlg._name.text == "Sona")
	_check("a door action goes to the mode (silence_door)", actions == ["silence_door:door_sona"])
	dlg._advance()
	await _frames(3)
	_check("the dialogue ends", not dlg.is_active())


# --- Barks ----------------------------------------------------------------------------------------

func _barks() -> void:
	WorldState.new_game()
	var spot: Array = Barks.playable("npc_rufet", "spot")
	_check("barks: before Aras knows his name no line says it", not spot.is_empty()
		and spot.all(func(e): return not String(e["text"]).contains("{PROTAGONIST}")))
	_check("... Rüfət's name-free variants play instead", spot.any(func(e): return e.get("key", "") == "BARK_RUFET_SPOT_1_PRE"))
	var villager: Array = Barks.playable("villager_m", "greet")
	_check("... villagers greet the prince without the name", villager.any(func(e): return e.get("key", "") == "BARK_VILLAGER_PRE_01")
		and not villager.any(func(e): return e.get("key", "") == "BARK_VILLAGER_POST_01"))
	WorldState.apply("reveal_name:protagonist")
	spot = Barks.playable("npc_rufet", "spot")
	_check("after the reveal the name comes back and the stand-ins go", spot.any(func(e): return e.get("key", "") == "BARK_RUFET_SPOT_1")
		and not spot.any(func(e): return e.get("key", "") == "BARK_RUFET_SPOT_1_PRE"))
	_check("Ehliman's barks follow Aras's choices (any_burned / any_kept, by day)", not Barks.playable("npc_ehliman", "greet").any(func(e): return e.get("key", "") == "BARK_EHLIMAN_01"))
	WorldState.set_time_of_day(10.0)
	WorldState.burn_memory(&"mother_name")
	_check("... after a BURN: 'Hafifle, evlat.'", Barks.playable("npc_ehliman", "greet").any(func(e): return e.get("key", "") == "BARK_EHLIMAN_01")
		and not Barks.playable("npc_ehliman", "greet").any(func(e): return e.get("key", "") == "BARK_EHLIMAN_02"))
	WorldState.set_time_of_day(22.0)
	_check("Gülçin's and Kemal's day barks are silent at night", Barks.playable("npc_gulcin", "greet").is_empty() and Barks.playable("npc_kemal", "greet").is_empty())
	WorldState.set_time_of_day(10.0)
	_check("... and play by day (voiced, keyed)", Barks.playable("npc_gulcin", "greet").size() == 1 and Barks.playable("npc_kemal", "greet")[0]["key"] == "BARK_KEMAL_01")


# --- Items ----------------------------------------------------------------------------------------

func _items() -> void:
	WorldState.new_game()
	SaveManager.active_slot = 1
	var host := await _go(HOST)
	var p = ItemPickup.new()
	p.setup("test_spot/yazma", "sirin_yazmasi")
	host.add_child(p)
	await _frames(2)
	_check("items: a pickup names its item from data", p.name_text() == "Şirin'in yazması" and p.prompt().contains("Şirin'in yazması"))
	_check("... taking it puts it in the inventory, off the ground", p.take() and WorldState.check("has_item:sirin_yazmasi") and not p.visible and not p.take())
	SaveManager.save(1)
	WorldState.new_game()
	await _frames(2)
	_check("... a new game has it back on the ground", p.visible and not WorldState.check("has_item:sirin_yazmasi"))
	SaveManager.load_slot(1)
	await _frames(2)
	_check("... and a load keeps it taken and carried", not p.visible and WorldState.check("has_item:sirin_yazmasi"))


# --- The story's door actions ----------------------------------------------------------------------

func _door_actions() -> void:
	WorldState.new_game()
	WorldState.set_flag(&"protagonist_name_known")
	var hub := await _go(HUB)
	hub.wait_until(21.0)
	await _frames(4)
	var lvl = hub.level
	var talk = hub.door_talk
	var ehliman = lvl.doors["door_ehliman"]
	_check("tonight-light: a lit door ...", ehliman.is_lit)
	talk.on_action("lights_out:door_ehliman")
	await _frames(2)
	_check("... goes dark on the story's lights_out", not ehliman.is_lit)
	talk.on_action("silence_door:door_sona")
	_check("silence_door: the door stays silent until morning", hub.knock(lvl.doors["door_sona"]) == "silent")
	hub.wait_until(7.0)
	hub.wait_until(21.0)
	await _frames(4)
	_check("... both last only the night", ehliman.is_lit and not talk.is_silenced(&"door_sona"))
	# A scripted conversation at a door: the story's graph instead of the pool
	var ok := DialogueGraphs.has("_never_") == false
	talk.set_script_for(&"sona", "slice_test_door")
	var gpath := "res://data/story/dialogue/slice_test_door.json"
	var f := FileAccess.open(gpath, FileAccess.WRITE)
	f.store_string(JSON.stringify({"id": "slice_test_door", "start": "ask", "nodes": {
		"ask": {"type": "name_challenge", "speaker": "sona", "key": "TEST_WHO", "pass": "p", "unknown": "p", "fail": "p"},
		"p": {"speaker": "sona", "key": "TEST_LOST", "end": true}}}))
	f.close()
	hub.player.global_position = hub.door_front(lvl.doors["door_sona"])
	hub.knock(lvl.doors["door_sona"])
	await _typed(hub.dialogue)
	_check("a scripted door conversation plays the story's graph", ok and hub.dialogue.node_id == "ask" and hub.dialogue._node.get("text_key", "") == "TEST_WHO")
	hub.dialogue.choose(0)
	await _until(func(): return hub.dialogue.node_id == "p", 3.0)
	var sona_door = lvl.doors["door_sona"]
	var x0: float = 0.0
	await _until(func(): return hub.dialogue.paused, 3.0)
	x0 = sona_door.shadow_x()
	await _seconds(0.5)
	_check("\"(…)\" at a door: the shadow under it stops moving", hub.dialogue.paused and is_equal_approx(sona_door.shadow_x(), x0))
	await _typed(hub.dialogue)
	hub.dialogue._advance()
	await _frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gpath))
	talk.clear_script(&"sona")


# --- Helpers --------------------------------------------------------------------------------------

func _go(path: String) -> Node:
	get_tree().change_scene_to_file(path)
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 20000:
		var c = get_tree().current_scene
		if c != null and c.scene_file_path == path and c.get("player") != null and c.player.is_inside_tree():
			await _frames(5)
			return get_tree().current_scene
		await get_tree().process_frame
	_check("scene %s came up" % path, false)
	return null


func _typed(dlg) -> void:
	await _until(func(): return not dlg._typing, 6.0)
	await _frames(2)


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
