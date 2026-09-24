extends CharacterBody3D
## Shared body for everyone who fights — Ayxan, enemies and (later) soldiers.
## Health, stamina, stance (poise) with break and recovery, damage-type
## resistances, a faction and the attack-token budget used by the AI director.
##
## Subclasses implement _on_hurt(), _on_stance_broken() and _on_died() and decide
## how blocking/parrying works through _defend(hit).

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal stance_changed(current: float, maximum: float)
signal died

const Hit := preload("res://scripts/combat/hit.gd")

var faction := "neutral"
var display_name := ""
var max_health := 100.0
var health := 100.0
var max_stamina := 100.0
var stamina := 100.0
var max_stance := 50.0
var stance := 0.0
var radius := 0.45
var resist := {"slash": 1.0, "crush": 1.0, "pierce": 1.0, "fire": 1.0}
var dead := false
var invulnerable_until := 0     # real-time ms
## Attack tokens currently held from other combatants' budgets.
var tokens_held := 0
var token_budget := 0

var _last_stance_hit_ms := 0
var _stance_recover_delay := 3.0
var _stance_recover_rate := 0.15


## Whether this combatant's blows should land on `other`. Ayxan's side vs everyone else;
## enemy factions never hurt each other.
func is_hostile(other) -> bool:
	var mine := is_in_group("player_side")
	return mine != other.is_in_group("player_side")


func is_invulnerable() -> bool:
	return Time.get_ticks_msec() < invulnerable_until


func make_invulnerable(seconds: float) -> void:
	invulnerable_until = maxi(invulnerable_until, Time.get_ticks_msec() + int(seconds * 1000.0))


## Resolves a blow. Returns "ignored", "parried", "blocked", "hit", "broken" or "killed".
func receive_hit(hit) -> String:
	if dead or is_invulnerable():
		return "ignored"
	var defended := _defend(hit)
	if defended != "":
		return defended
	var amount: float = hit.damage * float(resist.get(hit.damage_type, 1.0))
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		dead = true
		_on_died(hit)
		died.emit()
		return "killed"
	if add_stance(hit.stance):
		_on_stance_broken(hit)
		return "broken"
	_on_hurt(hit, amount)
	return "hit"


## Adds stance damage; returns true when this breaks the stance.
func add_stance(amount: float) -> bool:
	if amount <= 0.0 or max_stance <= 0.0:
		return false
	_last_stance_hit_ms = Time.get_ticks_msec()
	stance = minf(stance + amount, max_stance)
	stance_changed.emit(stance, max_stance)
	if stance >= max_stance:
		stance = 0.0
		stance_changed.emit(stance, max_stance)
		return true
	return false


func heal(amount: float) -> void:
	if dead:
		return
	health = minf(health + amount, max_health)
	health_changed.emit(health, max_health)


## Stance drains after a few quiet seconds (call from _physics_process).
func tick_stance(delta: float) -> void:
	if stance <= 0.0:
		return
	if Time.get_ticks_msec() - _last_stance_hit_ms > _stance_recover_delay * 1000.0:
		stance = maxf(stance - max_stance * _stance_recover_rate * delta, 0.0)
		stance_changed.emit(stance, max_stance)


# --- Overridables -------------------------------------------------------------------------

## Return a non-empty result ("parried"/"blocked") to stop the hit here.
func _defend(_hit) -> String:
	return ""


func _on_hurt(_hit, _amount: float) -> void:
	pass


func _on_stance_broken(_hit) -> void:
	pass


func _on_died(_hit) -> void:
	pass
