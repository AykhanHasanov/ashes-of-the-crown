extends Node
## EventBus (autoload): the game's cross-system signals. Signals only — no state, no logic.
## Systems announce what happened here; anyone may listen. Emit only from the owner listed.
##
## State changes (emitted by WorldState, after the change is applied):
##   flag_changed(key, old_value, new_value)  WorldState.set_flag / clear_flag
##   memory_kept(memory_id)                   WorldState.keep_memory (an echo's KEEP choice)
##   memory_burned(memory_id)                 WorldState.burn_memory (echo BURN, fire wheel, offer;
##                                            WorldState.get_burn_context says which)
##   player_stats_changed()                   WorldState.set_player_stats
##   inventory_changed(item_id, count)        WorldState.add_item / remove_item (count = new total)
##   time_of_day_changed(phase)               WorldState.set_time_of_day, when dawn/day/dusk/night changes
##   region_changed(region)                   WorldState.set_region (SaveManager autosaves on it)
##   story_changed(field)                     WorldState chapter / checkpoint / echoes setters
##   world_changed(key)                       WorldState world-section setters (hearths, chests, fog, doors...)
##   npc_moved(npc_id, from, to)              WorldState.move_npc / rescue_npc (location ids)
##   npc_rescued(npc_id)                      WorldState.rescue_npc (then npc_moved to son_ocaq)
##   npc_died(npc_id, cause)                  WorldState.kill_npc — permanent
##   npc_relationship_changed(npc_id, old, new)  WorldState.change_npc_relationship
##   npc_changed(npc_id)                      WorldState.set_npc_flag (an NPC's own flags)
##   state_replaced()                         WorldState: new game or load — re-read everything
##
## Moments (emitted by gameplay / mode scripts):
##   checkpoint_rested(checkpoint_id)         the mode, when the protagonist rests at an ocaq or reaches a story
##                                            checkpoint (SaveManager autosaves on it)
##
## Son Ocaq (emitted by scripts/hub/door.gd — a view of derived state):
##   door_changed(door_id, is_open)           a hub door opened or closed
##
## Encounters (emitted by scripts/world/encounter.gd; the active mode shows banners/music):
##   encounter_started(id)                    the first wave is about to rise
##   encounter_wave_started(id, wave, total, banner_key)   wave is 1-based; banner_key → tr()
##   encounter_finished(id)                   the last enemy of the last wave fell
##
## Saving (emitted by SaveManager):
##   saving(slot)                             just before writing: the active mode copies live values
##                                            (player stats, position, time) into WorldState
##   game_saved(slot), game_loaded(slot)      after a successful write / load

signal flag_changed(key: StringName, old_value: Variant, new_value: Variant)
signal memory_kept(memory_id: StringName)
signal memory_burned(memory_id: StringName)
signal player_stats_changed
signal inventory_changed(item_id: StringName, count: int)
signal time_of_day_changed(phase: StringName)
signal region_changed(region: StringName)
signal story_changed(field: StringName)
signal world_changed(key: StringName)
signal npc_changed(npc_id: StringName)
signal npc_moved(npc_id: StringName, from_location: String, to_location: String)
signal npc_rescued(npc_id: StringName)
signal npc_died(npc_id: StringName, cause: String)
signal npc_relationship_changed(npc_id: StringName, old_value: int, new_value: int)
signal state_replaced

signal checkpoint_rested(checkpoint_id: StringName)

signal door_changed(door_id: StringName, is_open: bool)

signal encounter_started(encounter_id: StringName)
signal encounter_wave_started(encounter_id: StringName, wave: int, total: int, banner_key: String)
signal encounter_finished(encounter_id: StringName)

signal saving(slot: int)
signal game_saved(slot: int)
signal game_loaded(slot: int)
