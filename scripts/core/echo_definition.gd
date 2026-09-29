extends Resource
## An echo: one of the protagonist's lost memories, played as a short scene
## (res://data/echoes/*.tres). When the scene ends the player decides the memory's fate
## on the choice screen — KEEP it (remember, no power) or BURN it (fire power, the
## memory is gone). Text fields are translation keys; show them with tr().

@export var id: StringName                # permanent
@export var memory_id: StringName         # the MemoryDefinition this echo decides
@export_file("*.tscn") var scene_path: String
@export var title_key: String             # shown when the echo begins
@export var prompt_key: String            # choice screen: the question
@export var keep_key: String              # choice screen: KEEP label
@export var burn_key: String              # choice screen: BURN label (hold to confirm)
## NPCs named inside this echo: KEEP makes their names known (BURN leaves them unknown).
@export var reveals_on_keep: PackedStringArray = PackedStringArray()
## Placeholder content: not written by the story yet.
@export var placeholder := false
