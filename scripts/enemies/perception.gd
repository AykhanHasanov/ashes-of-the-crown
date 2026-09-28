extends RefCounted
## How an enemy notices the protagonist (spec §4.1): a 120° view cone (25 m by day, 12 m at night
## or in fog) with line of sight, hearing (sprinting 15 m, fighting 30 m), and an
## awareness meter that walks the states calm → suspicious (yellow ?) → combat (red !).
## When the protagonist is lost the enemy searches his last known spot for 8 s, then gives up.

enum { CALM, SUSPICIOUS, COMBAT, SEARCH }
const NAMES := ["sakit", "şüpheli", "savaş", "arıyor"]

var foe                       # the Foe that owns this
var cfg: Dictionary           # data/balance/ai.json → perception
var state := CALM
var awareness := 0.0
var last_known := Vector3.ZERO
var sees := false
var hears := false
var always_sees := false      # "Kül Şahı'nın gözü"
var visibility := Callable()  # world light/fog 0..1 (1 = clear day)
var _lost_t := 0.0
var _search_t := 0.0


func _init(owner_foe, perception_cfg: Dictionary) -> void:
	foe = owner_foe
	cfg = perception_cfg


func sight_range() -> float:
	var v := 1.0
	if visibility.is_valid():
		v = clampf(visibility.call(), 0.0, 1.0)
	return lerpf(float(cfg["sight_dark"]), float(cfg["sight"]), v)


## Advances by `dt` seconds (called at the enemy's think rate). Returns true when the
## state changed.
func update(dt: float) -> bool:
	var before := state
	var t = foe.target
	if t == null or not is_instance_valid(t) or t.dead:
		sees = false
		hears = false
		if state == COMBAT:
			state = SEARCH
			_search_t = 0.0
	else:
		var d: float = foe.global_position.distance_to(t.global_position)
		sees = always_sees or _can_see(t, d)
		hears = _can_hear(t, d)
		if always_sees:
			awareness = 1.0   # Kül Şahının gözü: nothing escapes it
		if sees or hears:
			last_known = t.global_position
		var rise: float = cfg["rise_rate"]
		if sees:
			var close := clampf(1.0 - d / maxf(sight_range(), 1.0), 0.0, 1.0)
			awareness += rise * (1.0 + float(cfg["close_bonus"]) * close * close) * dt
		elif hears:
			awareness += rise * 0.9 * dt
		else:
			awareness -= float(cfg["fall_rate"]) * dt
		awareness = clampf(awareness, 0.0, 1.0)
	match state:
		CALM, SUSPICIOUS:
			if awareness >= 1.0:
				state = COMBAT
				_lost_t = 0.0
			elif awareness >= float(cfg["suspicious"]):
				state = SUSPICIOUS
			elif awareness < float(cfg["suspicious"]) * 0.5:
				state = CALM
		COMBAT:
			if sees or hears:
				_lost_t = 0.0
			else:
				_lost_t += dt
				if _lost_t > 1.5:
					state = SEARCH
					_search_t = 0.0
		SEARCH:
			if sees:
				state = COMBAT
				awareness = 1.0
				_lost_t = 0.0
			else:
				_search_t += dt
				if _search_t > float(cfg["search_time"]):
					state = CALM
					awareness = 0.0
	return state != before


## Being hurt or called for help puts an enemy straight into the fight.
func alarm(at: Vector3) -> void:
	last_known = at
	awareness = 1.0
	state = COMBAT
	_lost_t = 0.0


func _can_see(t: Node3D, d: float) -> bool:
	if d > sight_range():
		return false
	var fwd: Vector3 = foe.forward()
	var to: Vector3 = t.global_position - foe.global_position
	to.y = 0.0
	if to.length() > 1.5 and fwd.dot(to.normalized()) < cos(deg_to_rad(float(cfg["fov"]) * 0.5)):
		return false
	var eye: Vector3 = foe.global_position + Vector3(0, float(cfg["eye_height"]) * foe.body_scale(), 0)
	var chest := t.global_position + Vector3(0, 1.2, 0)
	var q := PhysicsRayQueryParameters3D.create(eye, chest, 1, [foe.get_rid(), t.get_rid()])
	return foe.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _can_hear(t: Node3D, d: float) -> bool:
	if t.has_method("is_sprinting_now") and t.is_sprinting_now() and d < float(cfg["hear_sprint"]):
		return true
	var noise: int = t.get("last_noise_ms") if t.get("last_noise_ms") != null else -100000
	return Time.get_ticks_msec() - noise < 1500 and d < float(cfg["hear_combat"])
