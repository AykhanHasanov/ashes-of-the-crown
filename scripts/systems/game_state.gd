extends Node
## Everything that must survive a save: chapter and checkpoint, which ember echoes
## Ayxan has seen, dialogue flags, burned memories and the open world's state
## (lit hearths, opened chests, discovered places, map fog, time and position).
## Saved as JSON to user://save.json. Version 3 saves load with an empty world.
##
## Chapter 1 checkpoints: start → waves → echoes → return → chapter_end
## Chapter 2 checkpoints: c2_start

const PATH := "user://save.json"
## The V3 open-world test keeps its own file until Faza H joins it to the story.
const WORLD_TEST_PATH := "user://world_test.json"
const VERSION := 4

var chapter := 1
var checkpoint := ""
var flags := {}
## Indices of the king's echoes already seen (Chapter 1).
var echoes_seen: Array = []
## Open world (V3): lists "hearths", "chests", "echoes", "discovered", "killed" plus
## "fog" (base64 bit field), "hour", "pos", "max_flasks".
var world := {}


func new_game() -> void:
	chapter = 1
	checkpoint = "start"
	flags = {}
	echoes_seen = []
	world = {}
	Memory.reset()


func has_save(path := PATH) -> bool:
	return FileAccess.file_exists(path)


func save_game(path := PATH) -> void:
	var data := {
		"version": VERSION,
		"chapter": chapter,
		"checkpoint": checkpoint,
		"flags": flags,
		"echoes_seen": echoes_seen,
		"memory": Memory.to_dict(),
		"world": world,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func load_game(path := PATH) -> bool:
	if not has_save(path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary) or int(data.get("version", 0)) not in [3, VERSION]:
		return false
	chapter = int(data["chapter"])
	checkpoint = data["checkpoint"]
	flags = data["flags"]
	echoes_seen = data["echoes_seen"].map(func(i): return int(i))
	Memory.from_dict(data["memory"])
	world = data.get("world", {})
	return true


func world_has(list: String, id: String) -> bool:
	return id in world.get(list, [])


func world_add(list: String, id: String) -> void:
	if not world.has(list):
		world[list] = []
	if not id in world[list]:
		world[list].append(id)


func set_flag(flag: String) -> void:
	flags[flag] = true


## Side effects attached to dialogue nodes and choices ("do": [...]): "flag:<name>".
func apply(action: String) -> void:
	if action.get_slice(":", 0) == "flag":
		set_flag(action.get_slice(":", 1))


## Condition strings used by dialogue branches: "memory:<id>" (burned), "flag:<name>".
func check(cond: String) -> bool:
	var arg := cond.get_slice(":", 1)
	match cond.get_slice(":", 0):
		"memory":
			return Memory.is_burned(arg)
		"flag":
			return flags.has(arg)
	return false
