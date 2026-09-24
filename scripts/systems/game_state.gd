extends Node
## Everything that must survive a save: chapter and checkpoint, which ember echoes
## Ayxan has seen, dialogue flags and burned memories. Saved as JSON to user://save.json.
##
## Chapter 1 checkpoints: start → waves → echoes → return → chapter_end
## Chapter 2 checkpoints: c2_start

const PATH := "user://save.json"
const VERSION := 3

var chapter := 1
var checkpoint := ""
var flags := {}
## Indices of the king's echoes already seen (Chapter 1).
var echoes_seen: Array = []


func new_game() -> void:
	chapter = 1
	checkpoint = "start"
	flags = {}
	echoes_seen = []
	Memory.reset()


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


func save_game() -> void:
	var data := {
		"version": VERSION,
		"chapter": chapter,
		"checkpoint": checkpoint,
		"flags": flags,
		"echoes_seen": echoes_seen,
		"memory": Memory.to_dict(),
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func load_game() -> bool:
	if not has_save():
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (data is Dictionary) or int(data.get("version", 0)) != VERSION:
		return false
	chapter = int(data["chapter"])
	checkpoint = data["checkpoint"]
	flags = data["flags"]
	echoes_seen = data["echoes_seen"].map(func(i): return int(i))
	Memory.from_dict(data["memory"])
	return true


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
