extends Node
## Yaddaş Yanğını — the protagonist's memories are his fuel. The player chooses which one
## burns for each Alov Dalğası; only Kül Şahı's offer picks one at random.
## Burned memories never come back.
##
## This autoload is the rules layer only: the memories are defined as data
## (MemoryDefinition .tres files, looked up through MemoryRegistry) and which ones are
## burned is WorldState's (WorldState.burn_memory / has_burned, EventBus.memory_burned).
##
## `gifted` will hold memories given by survivors (V2 phase 5); nothing fills it yet.

const Names := preload("res://scripts/core/names.gd")
const MemoryRegistry := preload("res://scripts/core/memory_registry.gd")
const KUL_SAHI := &"kul_sahi"   # speaker id (data/npcs/kul_sahi.tres)

## Kül Şahı grows louder with every burned memory.
const WHISPERS := [
	"...biraz daha, küçük şah...",
	"...hatıralar sadece yüktür...",
	"...onların yüzü sana ne verdi ki?...",
	"...babanı da böyle yedim. Yavaş yavaş...",
	"...taç seni bekliyor. BEN seni bekliyorum...",
	"...{PROTAGONIST} kimdi?...",
]
const GIFT_WHISPER := "...başkasının acısı da lezzetli..."

var gifted: Array = []


## Every memory definition, in display order.
func all() -> Array:
	return MemoryRegistry.all()


## The memories the fire wheel and Kül Şahı's offer can burn (see combat_burnable).
func combat_memories() -> Array:
	return all().filter(func(d): return d.combat_burnable)


func unburned() -> Array:
	return combat_memories().filter(func(d): return not WorldState.has_burned(d.id))


func can_burn() -> bool:
	return not unburned().is_empty() or not gifted.is_empty()


func burned_count() -> int:
	return WorldState.burned_memories().size()


## Burns one of the protagonist's own memories by id. Returns its definition, or null if it was
## already gone or is unknown.
func burn(id: StringName) -> Resource:
	if not WorldState.burn_memory(id):
		return null
	return MemoryRegistry.get_def(id)


## Kül Şahı chooses: a random unburned memory of the protagonist's own.
func burn_random() -> Resource:
	var left := unburned()
	if left.is_empty():
		return null
	return burn(left.pick_random().id)


func whisper() -> String:
	return Names.fill(WHISPERS[clampi(burned_count() - 1, 0, WHISPERS.size() - 1)], KUL_SAHI)   # he never forgets a name
