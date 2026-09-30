extends Node
## Headless checks for the story foundation (vertical slice, phase A1): the condition
## language, name tokens and the scene-level "all names known", echo KEEP revealing names,
## dialogue graphs (branches, conditional and disabled answers, "(…)" pauses, sfx, actions),
## barks with conditions and the name guard, items, and the story's door actions.
## Phase A2: burn power (the curve, never zero, charges), the Közcü journal, StoryDirector
## beats, the hub night counter with the fairness rule, Aras's room, the New Game path,
## Kartal Yamacı and the save migration to v8.
## Run: godot --headless --path . res://scenes/tests/story_test.tscn   (exit code = failures)

const BurnPower := preload("res://scripts/combat/burn_power.gd")
const KozcuJournal := preload("res://scripts/ui/kozcu_journal.gd")
const StoryDirector := preload("res://scripts/story/story_director.gd")
const HubNights := preload("res://scripts/hub/hub_nights.gd")
const HubTravel := preload("res://scripts/hub/hub_travel.gd")
const MemoryRegistry := preload("res://scripts/core/memory_registry.gd")
const Main := preload("res://scripts/main.gd")
const KARTAL := "res://scenes/kartal_yamaci.tscn"
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
	_burn_power()
	_journal_content()
	_fairness()
	_new_game_path()
	_migration_v8()
	await _hub_a2()
	await _kartal()
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


# --- A2: burn power -------------------------------------------------------------------------------

func _burn_power() -> void:
	WorldState.new_game()
	var t := BurnPower.total()
	_check("burn power: nothing burned, nothing gained", t["max"] == 0.0 and t["hit"] == 0.0 and t["kill"] == 0.0)
	var lights: Array = []
	for def in MemoryRegistry.all():
		if def.combat_burnable and int(def.weight) < 2:
			lights.append(def.id)
	var totals: Array = []
	for id in lights:
		WorldState.burn_memory(id, &"combat")
		var tt := BurnPower.total()
		totals.append([tt["hit"], tt["kill"]])
	_check("weight 1: the 1st and 2nd burns +2 / +4, every later one +1 / +2 (diminishing)", lights.size() >= 4
		and totals[0] == [2.0, 4.0] and totals[1] == [4.0, 8.0] and totals[2] == [5.0, 10.0] and totals[3] == [6.0, 12.0], str(totals))
	var every_gain := BurnPower.gains().all(func(g): return float(g["max"]) + float(g["hit"]) + float(g["kill"]) > 0.0)
	_check("... no cap: burning never gives zero", every_gain and BurnPower.total()["max"] == 0.0)
	var pv := BurnPower.preview(&"hearth_lesson")
	_check("weight 2 (hearth_lesson) previews one more Köz Darbesi", pv["max"] == 50.0 and BurnPower.describe(pv) == "+1 Köz Darbesi")
	WorldState.burn_memory(&"hearth_lesson", &"combat")
	var strike := float(DataDB.balance("combat")["ember"]["strike_cost"])
	_check("... burned: max Köz 150 = 3 Köz Darbesi", int((100.0 + BurnPower.total()["max"]) / strike) == 3)
	var curve: Array = DataDB.balance("combat")["ember"]["burn_power"]["light_curve"]
	_check("the curve lives in combat.json", curve.map(func(st): return [int(st[0]), int(st[1])]) == [[2, 4], [2, 4], [1, 2]])
	WorldState.new_game()


# --- A2: the Közcü journal --------------------------------------------------------------------------

func _journal_content() -> void:
	WorldState.new_game()
	_check("journal: no thread yet", KozcuJournal.thread_text() == tr("JOURNAL_NO_THREAD"))
	WorldState.apply("thread:JOURNAL_ESREF_THREAD")
	_check("journal: the thread is one goal line (thread: action)", KozcuJournal.thread_text() == "Eşref'in ocağında bir yazma vardı.")
	_check("... nobody met yet", KozcuJournal.people().is_empty())
	WorldState.set_npc_flag(&"esref", &"met", true)
	WorldState.set_npc_flag(&"esref", &"last_line", "TEST_ASK")
	var p: Array = KozcuJournal.people()
	_check("journal: a met person, by epithet until the name is known, with the last thing said", p.size() == 1
		and p[0]["name"] == Names.npc(&"esref") and p[0]["last"] == "Seni tanıyor muyum?", str(p))
	WorldState.keep_memory(&"first_sword")
	WorldState.burn_memory(&"mother_name", &"combat")
	var m: Array = KozcuJournal.memories()
	var kept: Array = m.filter(func(x): return x["id"] == &"first_sword")
	var burned: Array = m.filter(func(x): return x["id"] == &"mother_name")
	_check("journal: a BURNED memory shows the power it gave", burned.size() == 1 and burned[0]["state"] == "burned"
		and burned[0]["power"] == BurnPower.describe({"max": 0.0, "hit": 2.0, "kill": 4.0}))
	_check("... a KEPT one never shows a future value", kept.size() == 1 and kept[0]["state"] == "kept" and kept[0]["power"] == "")
	_check("... unknown memories are not listed", m.size() == 2)
	WorldState.new_game()


# --- A2: hub nights and the fairness rule ------------------------------------------------------------

func _night() -> void:
	WorldState.set_time_of_day(21.0)
	HubNights.on_nightfall()


func _morning() -> void:
	HubNights.resolve_morning()
	WorldState.set_time_of_day(7.0)


func _fairness() -> void:
	WorldState.new_game()
	_night()
	_check("nights count in the hub only: Eşref on the mountain counts none", HubNights.hub_nights(&"esref") == 0)
	_morning()
	WorldState.rescue_npc(&"esref")
	_night()
	_check("hub night 1: no warning", HubNights.hub_nights(&"esref") == 1 and not HubNights.is_warned(&"esref"))
	HubNights.on_nightfall()
	_check("... a night counts once, however often night is announced", HubNights.hub_nights(&"esref") == 1)
	_morning()
	_night()
	_check("hub night 2: the warning", HubNights.is_warned(&"esref") and not HubNights.was_heard(&"esref"))
	_morning()
	_check("fairness: not heard, nobody dies", WorldState.is_npc_alive(&"esref"))
	HubNights.mark_heard(&"esref")   # the day after: Domrul's line 3
	_night()
	_morning()
	_check("Domrul's line 3 counts as heard: the next hub night is the fourth knock", not WorldState.is_npc_alive(&"esref")
		and WorldState.get_npc_death_cause(&"esref") == "door")
	# Resolving his grief in time cancels the warning for good
	WorldState.new_game()
	WorldState.rescue_npc(&"esref")
	_night()
	_morning()
	_night()
	HubNights.mark_heard(&"esref")
	_morning()
	WorldState.resolve_grief(&"esref")
	_night()
	_morning()
	_night()
	_morning()
	_check("grief resolved (the yazma): the warning ends, he lives", WorldState.is_npc_alive(&"esref") and not HubNights.is_warned(&"esref"))
	WorldState.new_game()


# --- A2: New Game, saves ------------------------------------------------------------------------------

func _new_game_path() -> void:
	WorldState.set_region(&"kozqala")
	Main.prepare_new_game()
	_check("New Game starts the slice in Kür Vadisi (the open world)", WorldState.get_region() == &"kur_vadisi"
		and Main.REGION_SCENES[WorldState.get_region()] == "res://scenes/world.tscn" and WorldState.get_chapter() == 1)
	_check("Continue on a save made on Kartal Yamacı comes back there", Main.REGION_SCENES[&"kartal_yamaci"] == KARTAL)


func _migration_v8() -> void:
	var v7 := WorldState.default_state()
	v7["meta"]["save_version"] = 7
	v7["story"].erase("beats")
	v7["npcs"]["esref"]["flags"]["door_warned_day"] = 3
	var clean: Dictionary = SaveManager.migrate(v7)
	_check("save v7 -> v8: story beats added, the old day-based warning dropped", int(clean["meta"]["save_version"]) == WorldState.SAVE_VERSION
		and clean["story"]["beats"] == [] and not clean["npcs"]["esref"]["flags"].has("door_warned_day"))


# --- A2: the hub — StoryDirector, journal, Aras's room ---------------------------------------------------

func _hub_a2() -> void:
	WorldState.new_game()
	SaveManager.active_slot = 1
	WorldState.rescue_npc(&"esref")
	var hub := await _go(HUB)
	await _frames(4)
	var story = hub.story
	_check("a V3 mode has a StoryDirector and the Közcü journal", story != null and story.get_script() == StoryDirector
		and hub.journal.get_script() == KozcuJournal)
	_check("act 1 data: entering the hub with Eşref rescued and the yazma left behind sets the thread",
		WorldState.get_world_value(&"thread", "") == "JOURNAL_ESREF_THREAD" and WorldState.is_beat_done("esref_yazma_thread"))
	hub.dialogue.line_shown.emit({"speaker_id": "sona", "text_key": "TEST_A"})
	_check("a line spoken to him: met, and remembered as the last thing said", WorldState.get_npc_flag(&"sona", &"met", false) == true
		and WorldState.get_npc_flag(&"sona", &"last_line", "") == "TEST_A")
	hub.journal.enabled = true
	hub.journal.open()
	await _frames(2)
	_check("the journal opens (Tab) and lists what it knows", hub.journal.visible and hub.journal._people.get_child_count() >= 1)
	hub.journal.close()
	await _frames(1)
	# Beats: trigger, condition, once, repeat, region, actions in order, dialogue awaited
	var gpath := "res://data/story/dialogue/slice_test_beat.json"
	var f := FileAccess.open(gpath, FileAccess.WRITE)
	f.store_string(JSON.stringify({"id": "slice_test_beat", "nodes": {"start": {"speaker": "sona", "key": "TEST_END", "end": true, "event": "test_over"}}}))
	f.close()
	story._beats = [
		{"id": "t_once", "on": "flag", "arg": "test_go", "if": "!flag:test_block", "do": ["dialogue:slice_test_beat", "set:test_after", "item:+sirin_yazmasi"]},
		{"id": "t_repeat", "on": "interact", "arg": "bell", "repeat": true, "do": ["thread:TEST_A"]},
		{"id": "t_elsewhere", "on": "interact", "arg": "bell", "where": "kur_vadisi", "do": ["set:test_wrong_region"]},
		{"id": "t_after", "on": "dialogue_end", "arg": "test_over", "do": ["set:test_chained"]}]
	WorldState.set_flag(&"test_go")
	await _frames(2)
	_check("beat: a trigger plays its dialogue first ...", hub.dialogue.is_active() and not WorldState.has_flag(&"test_after") and story.is_busy())
	await _typed(hub.dialogue)
	hub.dialogue._advance()
	await _frames(3)
	_check("... then the rest of its actions, in order", WorldState.has_flag(&"test_after") and WorldState.check("has_item:sirin_yazmasi") and not story.is_busy())
	_check("... and a dialogue's end event triggers the next beat", WorldState.has_flag(&"test_chained"))
	WorldState.clear_flag(&"test_go")
	WorldState.remove_item(&"sirin_yazmasi")
	WorldState.set_flag(&"test_go")
	await _frames(2)
	_check("beats play once (story.beats)", not hub.dialogue.is_active() and not WorldState.check("has_item:sirin_yazmasi") and WorldState.is_beat_done("t_once"))
	story.fire("interact", "bell")
	WorldState.set_world_value(&"thread", "")
	story.fire("interact", "bell")
	await _frames(1)
	_check("repeat beats play every time; 'where' keeps a beat to its region", WorldState.get_world_value(&"thread", "") == "TEST_A"
		and not WorldState.has_flag(&"test_wrong_region") and not WorldState.is_beat_done("t_repeat"))
	SaveManager.save(1)
	WorldState.new_game()
	_check("... a new game forgets the played beats", not WorldState.is_beat_done("t_once"))
	SaveManager.load_slot(1)
	_check("... a load remembers them", WorldState.is_beat_done("t_once") and WorldState.is_beat_done("esref_yazma_thread"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gpath))
	story._beats = StoryDirector.load_beats()
	hub.door_talk.on_action("warning_heard:esref")
	_check("warning_heard: only counts for a warned NPC", not HubNights.was_heard(&"esref"))
	# Aras's room
	var lvl = hub.level
	var own = lvl.doors["door_protagonist"]
	hub.wait_until(10.0)
	await _frames(3)
	_check("Aras's room: by day his door is open and the room is hollow (two beds, a lamp)", own.is_open
		and lvl.room_spots.has("bed_protagonist") and lvl.room_spots.has("bed_rufet") and lvl.room_lamp != null
		and lvl.in_room(lvl.room_spots["inside_door"].origin) and not lvl.in_room(hub.door_front(own)))
	WorldState.move_npc(&"rufet", WorldState.PARTY)
	await _frames(4)
	hub.wait_until(21.0)
	await _frames(4)
	var rufet = hub.npcs.bodies.get(&"rufet")
	_check("at night Rüfət rests on his bed", rufet != null and rufet.is_resting()
		and rufet.global_position.distance_to(lvl.room_spots["bed_rufet"].origin) < 0.6)
	hub.player.global_position = hub.door_front(own) + Vector3(0, 0.1, 0)
	await _frames(2)
	_check("at night his closed door: he can go in", not own.is_open and hub.hud._prompt.text == tr("HUB_PROMPT_ENTER_ROOM"))
	_check("the room lamp casts no shadows while he is outside", not lvl.room_lamp.shadow_enabled)
	hub.enter_room()
	await _frames(2)
	_check("... and he is inside", lvl.in_room(hub.player.global_position))
	_check("... where the lamp's shadows are on", lvl.room_lamp.shadow_enabled)
	hub.room_door_choice()
	await _typed(hub.dialogue)
	_check("inside at night: the choice Dinle / Dışarı çık", hub.dialogue.choice_texts() == [tr("HUB_ROOM_LISTEN"), tr("HUB_ROOM_OUT")])
	hub.dialogue.choose(0)
	await _frames(3)
	_check("... Dinle: the small shade's knock at his door", hub.door_talk.last_outcome == "listen" and lvl.in_room(hub.player.global_position))
	hub.room_door_choice()
	await _typed(hub.dialogue)
	hub.dialogue.choose(1)
	await _frames(3)
	_check("... Dışarı çık: back in the courtyard", not lvl.in_room(hub.player.global_position)
		and hub.player.global_position.distance_to(hub.door_front(own)) < 1.0)
	hub.wait_until(7.0)
	await _frames(3)
	_check("by day Rüfət follows again", rufet != null and is_instance_valid(rufet) and not rufet.is_resting())


# --- A2: Kartal Yamacı ------------------------------------------------------------------------------------

func _kartal() -> void:
	WorldState.new_game()
	_check("Eşref lives on Kartal Yamacı at the start", WorldState.get_npc_location(&"esref") == "kartal_yamaci")
	var k := await _go(KARTAL)
	await _frames(6)
	var lvl = k.level
	_check("Kartal Yamacı: its own region, him at the top of the trail", WorldState.get_region() == &"kartal_yamaci"
		and k.player.global_position.distance_to(lvl.player_spawn) < 1.5)
	var esref = k.npcs.bodies.get(&"esref")
	_check("... Eşref at his hut's door", esref != null and esref.global_position.distance_to(lvl.hut_door) < 1.5)
	_check("... the cold hearth (no fire) with the yazma on its stones", lvl.yazma != null and not lvl.yazma.is_taken()
		and lvl.yazma.global_position.distance_to(lvl.hearth_pos) < 1.2 and not lvl.hearth.lit and lvl.hearth.light == null
		and lvl.hearth.find_children("Flames", "", true, false).is_empty())
	_check("... story spots for the beats", k.story_spot("hearth") == lvl.hearth_pos and k.story_spot("hut") == lvl.hut_door)
	k.player.global_position = lvl.yazma.global_position + Vector3(0.6, 0.2, 0.6)
	await _frames(3)
	_check("... the yazma's prompt", k.hud._prompt.text == lvl.yazma.prompt(), "'%s' / '%s', %.2f m" % [k.hud._prompt.text, lvl.yazma.prompt(),
		k.player.global_position.distance_to(lvl.yazma.global_position)])
	lvl.yazma.take()
	_check("... in his hands", WorldState.check("has_item:sirin_yazmasi"))
	var e = k.start_encounter(&"slice_s8_hut", lvl.arena_center)
	await _until(func(): return e != null and is_instance_valid(e) and e.alive.size() == 3, 5.0)
	_check("the S8 encounter runs here (3 shades round the hut first)", e != null and is_instance_valid(e) and e.alive.size() == 3)
	if e != null and is_instance_valid(e):
		e.abort()
	for foe in get_tree().get_nodes_in_group("enemies"):
		foe.queue_free()
	HubTravel._ctx = {"scene": KARTAL}
	_check("the trail leads back down to the valley", HubTravel.return_scene() == HubTravel.VALLEY_SCENE)
	HubTravel._ctx = {}
	var trail: Array = DataDB.prefab("hearth")["interact"].filter(func(d): return d["kind"] == "trail")
	_check("the valley's trail sign stands at Karaağaç Ocağı only", trail.size() == 1 and trail[0]["only"] == "hearth_north" and trail[0]["to"] == "kartal_yamaci")


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
