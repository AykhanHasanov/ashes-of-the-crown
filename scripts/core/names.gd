extends RefCounted
## Display names of people, resolved through here and never read directly. A name can be
## tied to a memory: once that memory is BURNED, the UI shows a blank placeholder
## (NAME_FORGOTTEN) instead of the name, while the people of the world still know it
## and say it in their own lines.
##
## The protagonist's name is the translation key PROTAGONIST_NAME ("Aras"); in text it
## is written as the token {PROTAGONIST} and filled by fill().
## Use: const Names := preload("res://scripts/core/names.gd")

const PROTAGONIST_KEY := "PROTAGONIST_NAME"
## The memory the protagonist's own name lives in (placeholder memory until the story
## decides; see data/memories/own_name.tres).
const PROTAGONIST_MEMORY := &"own_name"
const TOKEN := "{PROTAGONIST}"


## A name for the UI: tr(name_key), or the blank placeholder if `memory_id` is burned.
static func resolve(name_key: String, memory_id: StringName = &"") -> String:
	if memory_id != &"" and WorldState.has_burned(memory_id):
		return TranslationServer.translate("NAME_FORGOTTEN")
	return TranslationServer.translate(name_key)


## The protagonist's name as the UI shows it (blank once the name memory burned).
static func protagonist() -> String:
	return resolve(PROTAGONIST_KEY, PROTAGONIST_MEMORY)


## The protagonist's name as other people know it (never blanked).
static func protagonist_known() -> String:
	return TranslationServer.translate(PROTAGONIST_KEY)


## Replaces {PROTAGONIST} in `text`. Lines spoken by other people (npc_line) keep the
## real name; the protagonist's own UI and narration use the resolved one.
static func fill(text: String, npc_line := true) -> String:
	if not text.contains(TOKEN):
		return text
	return text.replace(TOKEN, protagonist_known() if npc_line else protagonist())
