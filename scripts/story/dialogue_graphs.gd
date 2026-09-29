extends RefCounted
## Dialogue graphs as data (res://data/story/dialogue/<id>.json) — the script's lines by
## translation key, turned into the node dictionaries DialogueUI plays.
##
## A graph: {"id", "start", "nodes": {id: node}}. A node:
##   speaker      "protagonist" or an NPC id (the label resolves through Names), optional
##   label_key    a label of its own (e.g. "Küçük kız"); tokens allowed
##   key          the line's translation key ("(…)" inside a line is a pause, not text)
##   next / end + event
##   choices      [{key, next, if?, disabled_if?, do?}] — Aras's answers
##   branch       [{if?, next}] — the first whose condition holds (no "if" = otherwise)
##   type "name_challenge" + key, pass, unknown, fail — who is there? (see DialogueUI)
##   if           the whole node is skipped (to next) unless the condition holds
##   do           actions (WorldState.apply; others go to the mode: silence_door, lights_out)
##   sfx          a sound when the line shows;  context conditions come from the caller
## Use: const DialogueGraphs := preload("res://scripts/story/dialogue_graphs.gd")

const DIR := "res://data/story/dialogue/"
const PROTAGONIST := "protagonist"

static var _cache := {}


static func has(id: String) -> bool:
	return _cache.has(id) or FileAccess.file_exists(DIR + id + ".json")


## The DialogueUI data for graph `id` ({node id: node}); its start node is "start" unless
## the graph names another (use start_of()).
static func load_graph(id: String) -> Dictionary:
	if not _cache.has(id):
		var raw = JSON.parse_string(FileAccess.get_file_as_string(DIR + id + ".json"))
		if not (raw is Dictionary):
			push_error("DialogueGraphs: cannot read %s" % id)
			return {}
		_cache[id] = compile(raw)
	return _cache[id]


static func start_of(id: String) -> String:
	return String(JSON.parse_string(FileAccess.get_file_as_string(DIR + id + ".json")).get("start", "start"))


## Turns a graph's nodes into DialogueUI's node format.
static func compile(graph: Dictionary) -> Dictionary:
	var out := {}
	var nodes: Dictionary = graph.get("nodes", {})
	for nid in nodes:
		var n: Dictionary = nodes[nid]
		var d := {}
		for k in n:
			match k:
				"speaker":
					if n[k] == PROTAGONIST:
						d["speaker"] = "{PROTAGONIST}"
					else:
						d["speaker_id"] = n[k]
				"key":
					d["text_key"] = n[k]
				"branch":
					d["switch"] = n[k]
				"choices":
					var cs: Array = []
					for c in n[k]:
						var cc: Dictionary = (c as Dictionary).duplicate()
						if cc.has("key"):
							cc["text_key"] = cc["key"]
							cc.erase("key")
						cs.append(cc)
					d["choices"] = cs
				_:
					d[k] = n[k]
		out[nid] = d
	return out
