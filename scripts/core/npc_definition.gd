extends Resource
## A person of the world (res://data/npcs/*.tres): who they are, how they look and sound.
## What happens to them — alive, where they are, rescued, relationship — is WorldState's
## (WorldState.npcs), never stored here. Text fields are translation keys.
##
## Identities only: roles, quest lines and dialogue are written later by the story.

@export var id: StringName                # permanent
@export var name_key: String              # display name, shown through Names.npc(id)
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
## Fights beside the protagonist when with him (scripts/npc/ally.gd).
@export var companion := false
## Their lines always show real names, even burned ones (Kül Şahı never forgets).
@export var ignores_burned_names := false
## Speaks but never appears as a body in the world (a voice, a vision).
@export var speaker_only := false
