extends RefCounted
## One blow landing on a Combatant: who struck, how hard, what kind of damage,
## how much it hurts stance, where it came from and whether it can be parried.

var attacker: Node3D
var damage := 0.0
var damage_type := "slash"     # slash | crush | pierce | fire
var stance := 0.0
var knock := Vector3.ZERO
var heavy := false             # knocks small foes down, bigger hit reactions
var parryable := true
var blockable := true
var execution := false


## Fills the common fields; returns self so it chains: Hit.new().setup(...).
func setup(from: Node3D, amount: float, kind: String, stance_damage: float, push: Vector3) -> RefCounted:
	attacker = from
	damage = amount
	damage_type = kind
	stance = stance_damage
	knock = push
	return self


## Direction the blow travels (attacker → victim), flattened.
func direction(victim: Node3D) -> Vector3:
	if not is_instance_valid(attacker):
		return Vector3.FORWARD
	var d := victim.global_position - attacker.global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD
