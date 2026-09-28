extends Resource
## A person of the world (res://data/npcs/*.tres): who they are, how they look and sound.
## What happens to them — alive, where they are, rescued, relationship — is WorldState's
## (WorldState.npcs), never stored here. Text fields are translation keys.
##
## Identities only: roles, quest lines and dialogue are written later by the story.

@export var id: StringName                # permanent
@export var name_key: String              # NPC_<ID>_NAME, shown through Names.npc(id)
## NPC_<ID>_EPITHET ("Sabir, the old teacher"): always shown with the name, never blanked,
## so the epithet identifies them even when the name slips (STORY_BIBLE §9.4).
@export var epithet_key: String
## Epithets that follow the story: "condition=>KEY" (a WorldState.check condition, e.g.
## "flag:narin_revealed=>NPC_NARIN_EPITHET_REVEALED"). The first rule whose condition
## holds wins; with none, epithet_key.
@export var epithet_rules: PackedStringArray = PackedStringArray()
## Optional: the name is blank in all text once this memory is BURNED.
@export var name_memory_id: StringName
@export var look_id: String               # data/looks.json entry (scripts/characters/human.gd)
@export var weapon_path: String           # right hand (companions), optional
@export var shield_path: String           # left hand (companions), optional
@export var voice_profile: String         # data/voices/voices.json profile ("" = silent)
## Dev-only notes on base personality. Never shown to the player.
@export_multiline var personality_notes: String
## Where a new game puts them: a POI id, "party" (with the protagonist), or "" (not in the
## world yet; the story places them).
@export var home_location_id: String
## The loved one they lost (STORY_BIBLE §7): the shade that knocks on their door at night
## and, in a door death, the one they open it to. Either another NPC (lost_one_npc, e.g.
## Sona -> Narin) or a placeholder name key and look.
@export var lost_one_npc: StringName
@export var lost_one_name_key: String
@export var lost_one_look_id: String
## What this NPC calls the protagonist, story permitting: "condition=>NAME_KEY" (first match
## wins; with none, his own name). E.g. Sabir sometimes calls Aras "Kür".
@export var calls_protagonist_rules: PackedStringArray = PackedStringArray()
## Opens the door at night: the conversation is face to face (Peri Nene, who recognises
## shades by their voice — the only one who can open safely).
@export var allows_night_open := false
## Fights beside the protagonist when with him (scripts/npc/ally.gd).
@export var companion := false
## Their lines always show real names, even burned ones (Kül Şahı never forgets).
@export var ignores_burned_names := false
## What they are (STORY_BIBLE §7): "human", "shade" (appears only in echoes / at doors), or
## "voice_only" (speaks, never has a body — Kül Şahı).
@export_enum("human", "shade", "voice_only") var npc_kind := "human"
## Where the bible puts them: "hub" (Son Ocaq), "world", or "" (core cast, not stated).
@export var presence := ""
## Other markers from the bible: "boss", "hidden".
@export var tags: PackedStringArray = PackedStringArray()
## Placeholder data (look, voice, text) until the story/art decides.
@export var placeholder := false
