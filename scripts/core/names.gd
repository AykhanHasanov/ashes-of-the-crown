extends RefCounted
## Display names of people, resolved through here and never read directly. A name can be
## tied to a memory: once that memory is BURNED, every text — UI labels, dialogue text,
## subtitles — shows a blank placeholder (NAME_FORGOTTEN) instead of the name. Voices
## still say it (the protagonist hears the name but can no longer hold it).
##
## Exception, per speaker: a speaker whose NpcDefinition sets ignores_burned_names (Kül
## Şahı — the one who never forgets) always shows the real name, subtitles included.
##
## The protagonist's name is the translation key PROTAGONIST_NAME ("Aras"); in text it
## is written as the token {PROTAGONIST} and filled by fill().
## Use: const Names := preload("res://scripts/core/names.gd")

const NpcRegistry := preload("res://scripts/core/npc_registry.gd")

const PROTAGONIST_KEY := "PROTAGONIST_NAME"
## The memory the protagonist's own name lives in (placeholder memory until the story
## decides; see data/memories/own_name.tres).
const PROTAGONIST_MEMORY := &"own_name"
const TOKEN := "{PROTAGONIST}"
## {NPC:<id>} in text: an NPC's name through npc() — known-name and burned-name rules apply.
const NPC_TOKEN := "{NPC:"


## A name for display: tr(name_key), or the blank placeholder if `memory_id` is burned.
static func resolve(name_key: String, memory_id: StringName = &"") -> String:
	if memory_id != &"" and WorldState.has_burned(memory_id):
		return TranslationServer.translate("NAME_FORGOTTEN")
	return TranslationServer.translate(name_key)


## The protagonist's name as text shows it (blank once the name memory burned).
static func protagonist() -> String:
	return resolve(PROTAGONIST_KEY, PROTAGONIST_MEMORY)


## The protagonist's real name — for voices (tools/gen_voices.py) and for speakers that
## ignore burned names. Never for ordinary text.
static func protagonist_known() -> String:
	return TranslationServer.translate(PROTAGONIST_KEY)


## An NPC's display name: until Aras knows it (WorldState.is_name_known) their epithet,
## capitalised ("Dokumacı"); once known, NpcDefinition.name_key — blank once its
## name_memory_id burned (burning cannot take a name he never had: the epithet stays).
static func npc(npc_id: StringName) -> String:
	if not NpcRegistry.has(npc_id):
		return ""
	var def: Resource = NpcRegistry.get_def(npc_id)
	if not WorldState.is_name_known(npc_id):
		return capitalize(npc_epithet(npc_id))
	return resolve(def.name_key, def.name_memory_id)


## Upper-cases the first letter the Turkish way (i → İ, ı → I).
static func capitalize(text: String) -> String:
	if text == "":
		return text
	var first := text.substr(0, 1)
	match first:
		"i":
			first = "İ"
		"ı":
			first = "I"
		_:
			first = first.to_upper()
	return first + text.substr(1)


## An NPC's epithet: the first NpcDefinition.epithet_rules entry whose condition holds,
## else epithet_key. Never blanked: it names them when the name is gone. "" if none.
static func npc_epithet(npc_id: StringName) -> String:
	if not NpcRegistry.has(npc_id):
		return ""
	var def: Resource = NpcRegistry.get_def(npc_id)
	for rule in def.epithet_rules:
		var parts := String(rule).split("=>")
		if parts.size() == 2 and WorldState.check(parts[0].strip_edges()):
			return TranslationServer.translate(parts[1].strip_edges())
	return TranslationServer.translate(def.epithet_key) if def.epithet_key != "" else ""


## Whether `speaker` (an NPC id) always shows real names, burned or not.
static func ignores_burned(speaker: StringName) -> bool:
	return speaker != &"" and NpcRegistry.has(speaker) and NpcRegistry.get_def(speaker).ignores_burned_names


## Replaces {PROTAGONIST} in text spoken by `speaker` (an NPC id; empty for the protagonist,
## narration and UI). Blank once the name burned, unless the speaker ignores burned names.
static func fill(text: String, speaker: StringName = &"") -> String:
	if text.contains(NPC_TOKEN):
		text = _fill_npcs(text)
	if not text.contains(TOKEN):
		return text
	var called := what_speaker_calls_him(speaker)
	if called != "":
		return text.replace(TOKEN, called)
	return text.replace(TOKEN, protagonist_known() if ignores_burned(speaker) else protagonist())


static var _npc_re: RegEx


static func _fill_npcs(text: String) -> String:
	if _npc_re == null:
		_npc_re = RegEx.create_from_string("\\{NPC:([a-z_]+)\\}")
	var out := text
	for m in _npc_re.search_all(text):
		out = out.replace(m.get_string(0), npc(StringName(m.get_string(1))))
	return out


## Whether Aras himself knows his name (he wakes without it; the story tells him — [TBD:
## Rüfət]). A world flag set by the dialogue action "reveal_name:protagonist".
static func protagonist_self_known() -> bool:
	return WorldState.has_flag(&"protagonist_name_known")


## His name on the HUD: empty while he does not know it; the blank ("———", reserved for
## burned names) once it is burned; otherwise the name.
static func protagonist_label() -> String:
	if WorldState.has_burned(PROTAGONIST_MEMORY):
		return TranslationServer.translate("NAME_FORGOTTEN")
	return protagonist() if protagonist_self_known() else ""


## What Aras can say when asked his name: the name; "Bilmiyorum..." while he does not know
## it; the blank once it is burned.
static func protagonist_answer() -> String:
	if WorldState.has_burned(PROTAGONIST_MEMORY):
		return TranslationServer.translate("NAME_FORGOTTEN")
	if not protagonist_self_known():
		return TranslationServer.translate("HUB_NAME_UNKNOWN_ANSWER")
	return protagonist()


## Another name `speaker` uses for the protagonist right now (NpcDefinition.
## calls_protagonist_rules, e.g. Sabir calling him "Kür"), or "" for his own.
static func what_speaker_calls_him(speaker: StringName) -> String:
	if speaker == &"" or not NpcRegistry.has(speaker):
		return ""
	for rule in NpcRegistry.get_def(speaker).calls_protagonist_rules:
		var parts := String(rule).split("=>")
		if parts.size() == 2 and WorldState.check(parts[0].strip_edges()):
			return TranslationServer.translate(parts[1].strip_edges())
	return ""
