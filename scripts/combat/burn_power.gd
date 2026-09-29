extends RefCounted
## The permanent power of burned memories (the slice's stand-in for İbrahim's ash upgrades,
## STORY_SLICE §2). Derived from WorldState's burned memories every time — never stored —
## so it is always in step with the save. Numbers: data/balance/combat.json ember.burn_power.
##   weight >= charge_weight (hearth_lesson): +charge_ember max Köz = one more Köz Darbesi.
##   weight 1: faster Köz — per hit / per kill from light_curve by the order of the burn
##   (diminishing, never zero: past the end of the curve its last step repeats).
## Use: const BurnPower := preload("res://scripts/combat/burn_power.gd")

const MemoryRegistry := preload("res://scripts/core/memory_registry.gd")


static func _cfg() -> Dictionary:
	return DataDB.balance("combat")["ember"]["burn_power"]


## The step a burn of `weight` gives when `lights_before` weight-1 burns came before it.
static func step(weight: int, lights_before: int) -> Dictionary:
	var c := _cfg()
	if weight >= int(c["charge_weight"]):
		return {"max": float(c["charge_ember"]), "hit": 0.0, "kill": 0.0}
	var curve: Array = c["light_curve"]
	var s: Array = curve[mini(lights_before, curve.size() - 1)]
	return {"max": 0.0, "hit": float(s[0]), "kill": float(s[1])}


## Every burned memory's gain, in burn order: [{id, max, hit, kill}].
static func gains() -> Array:
	var out: Array = []
	var lights := 0
	for id in WorldState.burned_memories():
		if not MemoryRegistry.has(id):
			continue
		var w: int = int(MemoryRegistry.get_def(id).weight)
		var g := step(w, lights)
		if w < int(_cfg()["charge_weight"]):
			lights += 1
		g["id"] = id
		out.append(g)
	return out


## The sum: {max, hit, kill} to add to the base Köz values.
static func total() -> Dictionary:
	var t := {"max": 0.0, "hit": 0.0, "kill": 0.0}
	for g in gains():
		for k in t:
			t[k] += float(g[k])
	return t


## What burning `memory_id` now would add (for the echo's choice screen).
static func preview(memory_id: StringName) -> Dictionary:
	var lights := 0
	for g in gains():
		if float(g["max"]) == 0.0:
			lights += 1
	return step(int(MemoryRegistry.get_def(memory_id).weight), lights)


## A gain as the player reads it: "+1 Köz Darbesi" or "Köz daha hızlı dolar (+2 / +4)".
static func describe(g: Dictionary) -> String:
	if float(g["max"]) > 0.0:
		var charges := int(round(float(g["max"]) / float(DataDB.balance("combat")["ember"]["strike_cost"])))
		return TranslationServer.translate("POWER_CHARGE") % charges
	return TranslationServer.translate("POWER_REGEN") % [int(g["hit"]), int(g["kill"])]
