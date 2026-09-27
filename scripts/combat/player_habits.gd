extends RefCounted
## Ayxan's defensive habits over the last `window` seconds (spec §4.1 adaptive AI):
## dodges, blocks, parries and time spent keeping his distance. Elites and bosses
## read weights() and lean on the counter to whatever he relies on most.

const KINDS := ["dodge", "block", "parry", "distance"]

var window := 60.0
var min_events := 3
var _events := {"dodge": [], "block": [], "parry": [], "distance": []}


func record(kind: String) -> void:
	_events[kind].append(Time.get_ticks_msec() / 1000.0)


func counts() -> Dictionary:
	var now := Time.get_ticks_msec() / 1000.0
	var out := {}
	for k in KINDS:
		var list: Array = _events[k]
		while not list.is_empty() and now - float(list[0]) > window:
			list.pop_front()
		out[k] = list.size()
	return out


## Share of each habit (0..1, sums to 1) once there is enough to go on.
func weights() -> Dictionary:
	var c := counts()
	var total := 0
	for k in c:
		total += c[k]
	var out := {}
	for k in KINDS:
		out[k] = float(c[k]) / total if total >= min_events else 0.0
	return out


func dominant() -> String:
	var w := weights()
	var best := ""
	var best_v := 0.34
	for k in w:
		if w[k] > best_v:
			best_v = w[k]
			best = k
	return best


func clear() -> void:
	for k in KINDS:
		_events[k].clear()
