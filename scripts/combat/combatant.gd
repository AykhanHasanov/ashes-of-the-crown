extends CharacterBody3D
## Shared body for everyone who fights — the protagonist, enemies and (later) soldiers.
## Health, stamina, stance (poise) with break and recovery, damage-type
## resistances, a faction and the attack-token budget used by the AI director.
##
## Subclasses implement _on_hurt(), _on_stance_broken() and _on_died() and decide
## how blocking/parrying works through _defend(hit).
##
## Faza C adds statuses (burning: damage over time), a ward (a shaman's shield that
## soaks damage) and timed buffs (an ataman's war cry) that scale damage and stance.

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
## The damage type of the last blow that got through. A Kullu is only gone for good when
## that is fire; iron merely scatters it (scripts/side_mode.gd).
var last_hit_type := ""
var invulnerable_until := 0     # real-time ms
## Attack tokens currently held from other combatants' budgets.
var tokens_held := 0
var token_budget := 0

## Damage soaked before health, and when it fades (ms).
var ward := 0.0
var ward_until := 0
## Multipliers from buffs; buff_until in ms.
var damage_mult := 1.0
var stance_mult := 1.0
var buff_until := 0
## Status name -> seconds left ("burn").
var statuses := {}
const BURN_DPS := 5.0

var _last_stance_hit_ms := 0
var _stance_recover_delay := 3.0
var _stance_recover_rate := 0.15


## Whether this combatant's blows should land on `other`. the protagonist's side vs everyone else;
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
	last_hit_type = hit.damage_type        # what finally felled him, for whoever cares
	var amount: float = hit.damage * float(resist.get(hit.damage_type, 1.0))
	if ward > 0.0 and Time.get_ticks_msec() < ward_until:
		var soak := minf(ward, amount)
		ward -= soak
		amount -= soak
		_on_ward_hit(ward <= 0.0)
	if hit.burn > 0.0:
		apply_status("burn", hit.burn)
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


# --- Statuses, wards, buffs ------------------------------------------------------------------

func apply_status(status: String, seconds: float) -> void:
	statuses[status] = maxf(statuses.get(status, 0.0), seconds * float(resist.get("fire", 1.0) if status == "burn" else 1.0))


func has_status(status: String) -> bool:
	return statuses.get(status, 0.0) > 0.0


func grant_ward(amount: float, seconds: float) -> void:
	ward = maxf(ward, amount)
	ward_until = Time.get_ticks_msec() + int(seconds * 1000.0)


func grant_buff(dmg: float, stance_factor: float, seconds: float) -> void:
	damage_mult = dmg
	stance_mult = stance_factor
	buff_until = Time.get_ticks_msec() + int(seconds * 1000.0)


## Call from _physics_process: burning damage, fading wards and buffs.
func tick_statuses(delta: float) -> void:
	if Time.get_ticks_msec() > buff_until and buff_until != 0:
		damage_mult = 1.0
		stance_mult = 1.0
		buff_until = 0
	if ward > 0.0 and Time.get_ticks_msec() > ward_until:
		ward = 0.0
		_on_ward_hit(true)
	if statuses.is_empty() or dead:
		return
	for k in statuses.keys():
		statuses[k] -= delta
		if statuses[k] <= 0.0:
			statuses.erase(k)
	if has_status("burn"):
		health = maxf(health - BURN_DPS * delta, 0.0)
		health_changed.emit(health, max_health)
		if health <= 0.0:
			dead = true
			_on_died(null)
			died.emit()


# --- Overridables -------------------------------------------------------------------------

## The ward took a blow (broken = it is gone).
func _on_ward_hit(_broken: bool) -> void:
	pass



## Return a non-empty result ("parried"/"blocked") to stop the hit here.
func _defend(_hit) -> String:
	return ""


func _on_hurt(_hit, _amount: float) -> void:
	pass


func _on_stance_broken(_hit) -> void:
	pass


func _on_died(_hit) -> void:
	pass
