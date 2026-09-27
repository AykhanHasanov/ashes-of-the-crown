extends RefCounted
## Elite affixes (spec §4.4, data/balance/affixes.json): rolled per spawn (normal 6%,
## elite 30%, 1–2 of them), they rename the enemy ("Alovlu Sürətli Canavar") and
## change how it fights. The Foe asks has(id) / get(id) at the right moments.


## Rolls affix ids for an enemy of `tier`.
static func roll(tier: String, rng: RandomNumberGenerator) -> Array:
	var cfg: Dictionary = DataDB.balance("affixes")
	var chance: float = cfg["chance"].get(tier, 0.0)
	if rng.randf() >= chance:
		return []
	var pool: Array = cfg["affixes"].map(func(a): return a["id"])
	var out: Array = [pool[rng.randi() % pool.size()]]
	if rng.randf() < float(cfg["second_chance"]):
		var second: String = pool[rng.randi() % pool.size()]
		if second != out[0]:
			out.append(second)
	return out


static func def(id: String) -> Dictionary:
	for a in DataDB.balance("affixes")["affixes"]:
		if a["id"] == id:
			return a
	return {}


## "Alovlu Sürətli Canavar", or "Canavar — Kül Şahının Gözü".
static func full_name(base: String, ids: Array) -> String:
	var prefix := ""
	var suffix := ""
	for id in ids:
		var d := def(id)
		if d.has("prefix"):
			prefix += d["prefix"] + " "
		if d.has("suffix"):
			suffix = " — " + d["suffix"]
	return prefix + base + suffix


static func color(ids: Array) -> Color:
	if ids.is_empty():
		return Color(0.95, 0.9, 0.82)
	var c: Array = def(ids[0]).get("color", [1, 0.8, 0.4])
	return Color(c[0], c[1], c[2])
