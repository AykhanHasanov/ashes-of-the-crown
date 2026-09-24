extends RefCounted
## Finds who a swing connects with: everyone the attacker is hostile to inside `range`
## (plus their radius) and within the swing's arc around `forward`.

static func targets(attacker: Node3D, forward: Vector3, reach: float, arc_deg: float, group := "combatants") -> Array:
	var result := []
	var half_cos := cos(deg_to_rad(minf(arc_deg, 360.0) * 0.5))
	for c in attacker.get_tree().get_nodes_in_group(group):
		if c == attacker or c.dead or not attacker.is_hostile(c):
			continue
		var to: Vector3 = c.global_position - attacker.global_position
		to.y = 0.0
		var dist := to.length()
		if dist > reach + c.radius:
			continue
		if arc_deg >= 360.0 or dist < 0.6 or to.normalized().dot(forward) >= half_cos:
			result.append(c)
	return result
