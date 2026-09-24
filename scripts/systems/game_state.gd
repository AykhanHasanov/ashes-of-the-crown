extends Node
## Everything that must survive a save: the hidden traitor, the clue behind each
## ember echo, discovered clues, dialogue flags, burned memories, how far each
## suspect trusts Ayxan, and the chapter checkpoint. Saved as JSON to user://save.json.
##
## Chapter 1 checkpoints: start → waves → echoes → return → chapter_end
## Chapter 2 checkpoints: c2_start → c2_after_attack → c2_end

signal clue_found(trait_id: String)
signal trust_changed(suspect: String, value: int)

const Conspiracy := preload("res://scripts/story/conspiracy.gd")
const PATH := "user://save.json"
const VERSION := 2

## Starting trust (0..100): old allies trust Ayxan, rivals do not.
const BASE_TRUST := {
	"sabir": 65, "anar": 40, "elvin": 25, "sahbaz": 55,
	"esref": 30, "rufet": 80, "ibrahim": 50, "ehliman": 35,
}

var chapter := 1
var traitor := ""
var echo_traits: Array = []
var clues: Array = []
var flags := {}
var checkpoint := ""
var trust := {}
var talked: Array = []
## Who was missing from the camp during the night attack (Chapter 2).
var absent: Array = []
var accused := ""


func new_game() -> void:
	chapter = 1
	traitor = Conspiracy.SUSPECTS.keys().pick_random()
	echo_traits = Conspiracy.SUSPECTS[traitor]["traits"].duplicate()
	echo_traits.shuffle()
	clues = []
	flags = {}
	checkpoint = "start"
	trust = BASE_TRUST.duplicate()
	talked = []
	absent = []
	accused = ""
	Memory.reset()


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


func save_game() -> void:
	var data := {
		"version": VERSION,
		"chapter": chapter,
		"traitor": traitor,
		"echo_traits": echo_traits,
		"clues": clues,
		"flags": flags,
		"checkpoint": checkpoint,
		"trust": trust,
		"talked": talked,
		"absent": absent,
		"accused": accused,
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
	traitor = data["traitor"]
	echo_traits = data["echo_traits"]
	clues = data["clues"]
	flags = data["flags"]
	checkpoint = data["checkpoint"]
	trust = {}
	for k in data["trust"]:
		trust[k] = int(data["trust"][k])
	talked = data["talked"]
	absent = data["absent"]
	accused = data["accused"]
	Memory.from_dict(data["memory"])
	return true


func add_clue(trait_id: String) -> void:
	if not clues.has(trait_id):
		clues.append(trait_id)
		clue_found.emit(trait_id)


func set_flag(flag: String) -> void:
	flags[flag] = true


func change_trust(suspect: String, delta: int) -> void:
	trust[suspect] = clampi(int(trust.get(suspect, 50)) + delta, 0, 100)
	trust_changed.emit(suspect, trust[suspect])


## Side effects attached to dialogue nodes and choices ("do": [...]):
## "trust:<suspect>:<delta>", "flag:<name>", "talked:<suspect>".
func apply(action: String) -> void:
	var kind := action.get_slice(":", 0)
	var arg := action.get_slice(":", 1)
	match kind:
		"trust":
			change_trust(arg, int(action.get_slice(":", 2)))
		"flag":
			set_flag(arg)
		"talked":
			if not talked.has(arg):
				talked.append(arg)


## Condition strings used by dialogue branches:
## "memory:<id>" (burned), "traitor:<suspect>", "flag:<name>", "clue:<trait>",
## "clues:<n>", "trust:<suspect>:<min>".
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
		"trust":
			return int(trust.get(arg, 0)) >= int(cond.get_slice(":", 2))
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
