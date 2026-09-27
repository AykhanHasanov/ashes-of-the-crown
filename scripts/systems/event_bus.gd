extends Node
## EventBus (autoload): the game's cross-system signals. Signals only — no state, no logic.
## Systems announce what happened here; anyone may listen. Emit only from the owner listed.
##
## State changes (emitted by WorldState, after the change is applied):
##   flag_changed(key, old_value, new_value)  WorldState.set_flag / clear_flag
##   memory_burned(memory_id)                 WorldState.burn_memory
##   player_stats_changed()                   WorldState.set_player_stats
##   inventory_changed(item_id, count)        WorldState.add_item / remove_item (count = new total)
##   time_of_day_changed(phase)               WorldState.set_time_of_day, when dawn/day/dusk/night changes
##   region_changed(region)                   WorldState.set_region (SaveManager autosaves on it)
##   story_changed(field)                     WorldState chapter / checkpoint / echoes setters
##   world_changed(key)                       WorldState world-section setters (hearths, chests, fog, hub_stage...)
##   npc_changed(npc_id)                      WorldState.set_npc (reserved for the NPC model)
##   state_replaced()                         WorldState: new game or load — re-read everything
##
## Moments (emitted by gameplay / mode scripts):
##   checkpoint_rested(checkpoint_id)         the mode, when Ayxan rests at an ocaq or reaches a story
##                                            checkpoint (SaveManager autosaves on it)
##
## Saving (emitted by SaveManager):
##   saving(slot)                             just before writing: the active mode copies live values
##                                            (player stats, position, time) into WorldState
##   game_saved(slot), game_loaded(slot)      after a successful write / load

signal flag_changed(key: StringName, old_value: Variant, new_value: Variant)
signal memory_burned(memory_id: StringName)
signal player_stats_changed
signal inventory_changed(item_id: StringName, count: int)
signal time_of_day_changed(phase: StringName)
signal region_changed(region: StringName)
signal story_changed(field: StringName)
signal world_changed(key: StringName)
signal npc_changed(npc_id: StringName)
signal state_replaced

signal checkpoint_rested(checkpoint_id: StringName)

signal saving(slot: int)
signal game_saved(slot: int)
signal game_loaded(slot: int)
