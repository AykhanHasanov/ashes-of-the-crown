extends Node
## Everything that must survive a save: the hidden traitor, the clue behind each
## ember echo, discovered clues, dialogue flags, burned memories and the chapter
## checkpoint. Saved as JSON to user://save.json.
##
## Checkpoints (Chapter 1): "start" → "echoes" (waves won) → "return" (all echoes
## seen, go back to Rüfət) → "chapter_end".

signal clue_found(trait_id: String)

const Conspiracy := preload("res://scripts/story/conspiracy.gd")
const PATH := "user://save.json"
const VERSION := 1

var traitor := ""
var echo_traits: Array = []
var clues: Array = []
var flags := {}
var checkpoint := ""


func new_game() -> void:
	traitor = Conspiracy.SUSPECTS.keys().pick_random()
	echo_traits = Conspiracy.SUSPECTS[traitor]["traits"].duplicate()
	echo_traits.shuffle()
	clues = []
	flags = {}
	checkpoint = "start"
	Memory.reset()


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


func save_game() -> void:
	var data := {
		"version": VERSION,
		"traitor": traitor,
		"echo_traits": echo_traits,
		"clues": clues,
		"flags": flags,
		"checkpoint": checkpoint,
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
	traitor = data["traitor"]
	echo_traits = data["echo_traits"]
	clues = data["clues"]
	flags = data["flags"]
	checkpoint = data["checkpoint"]
	Memory.from_dict(data["memory"])
	return true


func add_clue(trait_id: String) -> void:
	if not clues.has(trait_id):
		clues.append(trait_id)
		clue_found.emit(trait_id)


func set_flag(flag: String) -> void:
	flags[flag] = true


## Condition strings used by dialogue branches:
## "memory:<id>" (burned), "traitor:<suspect>", "flag:<name>", "clue:<trait>", "clues:<n>".
func check(cond: String) -> bool:
	var kind := cond.get_slice(":", 0)
	var arg := cond.get_slice(":", 1)
	match kind:
		"memory":
			return Memory.is_burned(arg)
		"traitor":
			return traitor == arg
		"flag":
			return flags.has(arg)
		"clue":
			return clues.has(arg)
		"clues":
			return clues.size() >= int(arg)
	return false


## Suspects whose traits contain every clue found so far.
func suspects_matching() -> Array:
	var result := []
	for id in Conspiracy.SUSPECTS:
		var traits: Array = Conspiracy.SUSPECTS[id]["traits"]
		var ok := true
		for c in clues:
			if not traits.has(c):
				ok = false
				break
		if ok:
			result.append(id)
	return result
