extends "res://scripts/combat/combatant.gd"
## A data-driven enemy (data/enemies/*.json) with a small utility AI.
##
## Every THINK seconds the brain scores its options — approach, circle at the
## waiting ring, flank (packs), each attack in its range and off cooldown, raise a
## shield, back off — and commits to the best. Attacking needs a token from the
## target's budget (Ayxan: 3); without one the enemy circles and waits its turn.
## Attacks telegraph with a ground ring that grows over the windup; the last
## `unstoppable` seconds burn white and cannot be interrupted; unparryable attacks
## glow red. Parries stun, heavy blows knock small foes down, a full stance bar
## collapses them for an execution.
##
## In the open world a foe has a home: it idles there until Ayxan comes within
## `aggro_range` (or hurts it / a packmate), and gives up the chase past `leash`
## metres from home, walking back and healing. aggro_range 0 = always hunting (arena).

signal killed(foe: Node)

const CharacterModel := preload("res://scripts/characters/character_model.gd")
const Effects := preload("res://scripts/world/effects.gd")
const Melee := preload("res://scripts/combat/melee.gd")
const OVERLAY := preload("res://shaders/ash_overlay.gdshader")
const HP_BAR := preload("res://shaders/hp_bar.gdshader")
const THINK := 0.25

enum S { SPAWN, THINK_MOVE, WINDUP, STRIKE, RECOVER, BLOCK, HURT, STUNNED, BROKEN, EXECUTED, DEAD }

var data: Dictionary = {}
var target            # usually Ayxan
var level := 1

var _cfg: Dictionary
var _state := S.SPAWN
var _t := 0.0
var _think_t := 0.0
var _action := "approach"
var _attack: Dictionary = {}
var _hit_done := false
var _cooldowns := {}
var _has_token := false
var _orbit := 1.0
var _flank_side := 1.0
var _model
var _overlay: ShaderMaterial
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _bar: MeshInstance3D
var _bar_mat: ShaderMaterial
var _bar_lag := 1.0
var _bar_hold := 0.0
var _speed := 3.0
var _run_speed := 4.0
var _knock := Vector3.ZERO
var _flash := 0.0
var _shape: CollisionShape3D
var _executor = null
var home := Vector3.ZERO
var aggro_range := 0.0
var leash := 42.0
var aggro := true
var spawn_key := ""          # set by the open world to remember kills
## Open world: terrain height at (x, z). Terrain colliders only exist near the camera,
## so far-off foes are held on the ground by this instead of falling through.
var ground_query := Callable()
var _returning := false
var _vy := 0.0


func configure(id: String, enemy_level := 1) -> void:
	data = DataDB.enemy(id)
	level = enemy_level
	var st: Dictionary = data["stats"]
	# Level formulas (spec 4.3) are applied in phase C; level 1 uses base values.
	max_health = st["health"] * (1.0 + 0.12 * (level - 1))
	health = max_health
	max_stance = st["stance"]
	radius = st["radius"]
	_speed = st["speed"]
	_run_speed = st["run_speed"]
	faction = data["faction"]
	display_name = data["name"]
	resist = data["resist"].duplicate()


func _ready() -> void:
	_cfg = DataDB.balance("combat")
	add_to_group("combatants")
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 5
	_orbit = 1.0 if randf() < 0.5 else -1.0
	_flank_side = _orbit
	var st: Dictionary = data["stats"]
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = maxf(st["height"], radius * 2.0 + 0.1)
	_shape.shape = cap
	_shape.position.y = cap.height * 0.5
	if data["id"] == "wolf":
		# Quadruped: a capsule lying along the body
		_shape.rotation.x = PI * 0.5
		cap.height = 1.3
		_shape.position.y = 0.45
	add_child(_shape)
	_build_model()
	_build_telegraph()
	_build_bar()
	if aggro_range > 0.0:
		aggro = false
		if home == Vector3.ZERO:
			home = global_position
	var spawn: String = data["anims"].get("spawn", "")
	if spawn != "":
		_model.play_action(spawn, 2.4, 0.0)
		_enter(S.SPAWN)
		_t = -1.4
	else:
		_enter(S.THINK_MOVE)


func _build_model() -> void:
	var m: Dictionary = data["model"]
	_model = CharacterModel.new()
	add_child(_model)
	_model.setup(m["path"], m.get("hidden", []), float(m.get("scale", 1.0)), m.get("loop", []))
	if m.has("length"):
		_model.fit_length(m["length"])
	if m.has("tint"):
		var c: Array = m["tint"]
		_model.tint(Color(c[0], c[1], c[2]))
	if m.has("recolor") and m["recolor"].size() == 5:
		var r: Array = m["recolor"]
		_model.recolor(r[0], r[1], r[2], r[3], r[4])
	if m.has("weapon"):
		_model.attach(m["weapon"], "handslot.r")
	_overlay = ShaderMaterial.new()
	_overlay.shader = OVERLAY
	_overlay.set_shader_parameter("intensity", float(m.get("ash_overlay", 0.0)))
	_overlay.set_shader_parameter("flash_color", Color(1.0, 0.7, 0.45))
	_model.set_overlay(_overlay)
	if m.get("glow_eyes", false):
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(1.0, 0.45, 0.1)
		glow.emission_enabled = true
		glow.emission = Color(1.0, 0.45, 0.1)
		glow.emission_energy_multiplier = 8.0
		for mi in _model.scene.find_children("*Eyes*", "MeshInstance3D", true, false):
			mi.material_override = glow
			mi.material_overlay = null
	var a: Dictionary = data["anims"]
	_model.idle_anim = a["idle"]
	_model.move_anim = a["run"]


func _build_telegraph() -> void:
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 40
	torus.ring_segments = 4
	_ring.mesh = torus
	_ring_mat = Effects.additive_material(Color(1.0, 0.25, 0.05, 0.0))
	_ring.material_override = _ring_mat
	_ring.position.y = 0.05
	_ring.visible = false
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func _build_bar() -> void:
	_bar = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.1, 0.19)
	_bar.mesh = quad
	_bar_mat = ShaderMaterial.new()
	_bar_mat.shader = HP_BAR
	_bar_mat.set_shader_parameter("with_stance", true)
	_bar.material_override = _bar_mat
	_bar.position.y = float(data["stats"]["height"]) + 0.45
	_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.visible = false
	add_child(_bar)


func _enter(s: int) -> void:
	_state = s
	_t = 0.0


# --- Loop ----------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_overlay.set_shader_parameter("hit_flash", _flash * 0.5)
	_knock = _knock.move_toward(Vector3.ZERO, 30.0 * delta)
	for k in _cooldowns:
		_cooldowns[k] -= delta
	if _state not in [S.BROKEN, S.EXECUTED, S.DEAD]:
		tick_stance(delta)
	_update_bar(delta)
	var move := Vector3.ZERO
	var to := _to_target()
	var dist := to.length()

	match _state:
		S.SPAWN:
			if _t >= 0.0:
				_model.cancel_action()
				_enter(S.THINK_MOVE)
		S.THINK_MOVE:
			if not aggro:
				move = _home_behaviour(dist, delta)
			else:
				_think_t -= delta
				if _think_t <= 0.0:
					_think_t = THINK * randf_range(0.8, 1.2)
					_think(to, dist)
					_check_leash(dist)
				move = _steer(to, dist)
				_face(to if dist > 0.1 else -_model.global_basis.z, delta, 9.0)
		S.WINDUP:
			_face(to, delta, 5.0)
			_update_ring()
			if _t >= _attack["windup"]:
				_ring.visible = false
				_enter(S.STRIKE)
		S.STRIKE:
			var dir: Vector3 = -_model.global_basis.z
			if _t < 0.14:
				move = dir * float(_attack.get("lunge", 6.0))
			if not _hit_done and _t >= 0.06:
				_hit_done = true
				_deal_hit(dir)
			if _t >= 0.18:
				_enter(S.RECOVER)
		S.RECOVER:
			if _t >= float(_attack.get("recovery", 0.5)):
				_release_token()
				_enter(S.THINK_MOVE)
		S.BLOCK:
			_face(to, delta, 8.0)
			if _t >= 0.9:
				_model.cancel_action()
				_enter(S.THINK_MOVE)
		S.HURT:
			if _t >= 0.35:
				_enter(S.THINK_MOVE)
		S.STUNNED:
			if _t >= _stun_time:
				_model.cancel_action()
				_enter(S.THINK_MOVE)
		S.BROKEN:
			if _t >= _cfg["stance"]["break_time"]:
				_recover_from_break()
		S.EXECUTED, S.DEAD:
			pass

	if is_on_floor():
		_vy = -1.0
	else:
		_vy = maxf(_vy - 22.0 * delta, -40.0)
	velocity = Vector3(move.x + _knock.x, _vy, move.z + _knock.z)
	move_and_slide()
	if ground_query.is_valid():
		var gy: float = ground_query.call(global_position.x, global_position.z)
		if global_position.y < gy - 0.3:
			global_position.y = gy + 0.05
			_vy = 0.0
	if _state == S.THINK_MOVE:
		var moving := move.length() > 0.3
		var a: Dictionary = data["anims"]
		if not moving:
			_model.play_loop(a["idle"])
		elif move.length() > _speed * 1.2:
			_model.play_loop(a["run"], 1.0)
		else:
			_model.play_loop(a["walk"], 1.0)


var _stun_time := 1.2


# --- Utility AI -------------------------------------------------------------------------------

func _think(to: Vector3, dist: float) -> void:
	if not _target_ok():
		_action = "idle"
		return
	var b: Dictionary = data["behavior"]
	var scores := {}
	var punish := 1.5 if (target.has_method("is_drinking") and target.is_drinking()) or (target.has_method("is_exhausted") and target.is_exhausted()) else 1.0
	# Attacks in range and off cooldown
	for a in data["attacks"]:
		var id: String = a["id"]
		if _cooldowns.get(id, 0.0) > 0.0:
			continue
		var reach: float = a["range"] + radius + target.radius
		if dist > reach or dist < float(a.get("min_range", 0.0)):
			continue
		scores["attack:" + id] = float(a["weight"]) * float(b["aggression"]) * punish * (1.0 + randf() * 0.3)
	# Shield users raise the guard against an incoming swing
	if float(b.get("block_chance", 0.0)) > 0.0 and target.has_method("is_attacking") and target.is_attacking() and dist < 3.5:
		scores["block"] = float(b["block_chance"]) * 1.4
	scores["approach"] = 0.5 if dist > float(b["preferred_range"]) + 0.3 else 0.05
	scores["circle"] = 0.35 if dist < float(b["wait_range"]) + 1.5 else 0.1
	if b.get("flank", false):
		scores["flank"] = 0.45
	if health < max_health * 0.25:
		scores["retreat"] = 0.25 if data["faction"] != "ash" else 0.0
	var best := "approach"
	var best_score := -1.0
	for k in scores:
		if scores[k] > best_score:
			best_score = scores[k]
			best = k
	if best.begins_with("attack:"):
		var attack := _attack_by_id(best.substr(7))
		var cost := int(data["stats"]["token_cost"])
		if target.has_method("request_token") and not target.request_token(cost):
			best = "flank" if b.get("flank", false) else "circle"
		else:
			_has_token = true
			_begin_attack(attack)
			return
	if best == "block":
		_begin_block()
		return
	_action = best


func _steer(to: Vector3, dist: float) -> Vector3:
	if not _target_ok() or _action == "idle":
		return Vector3.ZERO
	var dir := to.normalized()
	var tangent := Vector3(-dir.z, 0.0, dir.x) * _orbit
	var b: Dictionary = data["behavior"]
	var wait: float = b["wait_range"]
	match _action:
		"approach":
			var fast := dist > 6.0
			return (dir + _separation()).normalized() * (_run_speed if fast else _speed)
		"circle":
			var radial := dir * clampf(dist - wait, -1.0, 1.0)
			return (radial + tangent * 0.8 + _separation()).limit_length(1.0) * _speed * 0.7
		"flank":
			# Swing round to the target's side or back
			var t_fwd: Vector3 = -target.global_basis.z if not target.has_method("facing") else target.facing()
			var goal: Vector3 = target.global_position + (t_fwd.cross(Vector3.UP) * _flank_side - t_fwd * 0.6).normalized() * wait
			var g := goal - global_position
			g.y = 0.0
			return (g.normalized() + _separation()).normalized() * _run_speed if g.length() > 0.6 else Vector3.ZERO
		"retreat":
			return (-dir + tangent * 0.5).normalized() * _speed
	return Vector3.ZERO


func _attack_by_id(id: String) -> Dictionary:
	for a in data["attacks"]:
		if a["id"] == id:
			return a
	return data["attacks"][0]


# --- Attacking --------------------------------------------------------------------------------

func _begin_attack(a: Dictionary) -> void:
	_attack = a
	_hit_done = false
	_cooldowns[a["id"]] = float(a["cooldown"])
	_model.play_action(a["clip"], float(a["clip_impact"]) / float(a["windup"]), 0.06)
	_ring.visible = true
	_ring.scale = Vector3(0.4, 0.3, 0.4)
	Audio.play("shade_windup", -12.0, 0.15, global_position)
	_enter(S.WINDUP)


func _update_ring() -> void:
	var k := clampf(_t / float(_attack["windup"]), 0.0, 1.0)
	var r := lerpf(0.4, float(_attack["range"]) + radius, k)
	_ring.scale = Vector3(r, 0.3, r)
	var left := float(_attack["windup"]) - _t
	if _attack.get("unparryable", false):
		# Red glow: cannot be parried, only dodged
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
		_ring_mat.albedo_color = Color(1.0, 0.05, 0.02, 0.6 + 0.4 * pulse)
		_overlay.set_shader_parameter("flash_color", Color(1.0, 0.05, 0.02))
		_flash = maxf(_flash, 0.6 * pulse)
	elif left <= float(_attack.get("unstoppable", 0.0)):
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.04)
		_ring_mat.albedo_color = Color(1.0, 0.9, 0.75).lerp(Color.WHITE, pulse)
	else:
		_ring_mat.albedo_color = Color(1.0, 0.25, 0.05, 0.25 + 0.6 * k)


func _deal_hit(dir: Vector3) -> void:
	if not _target_ok():
		return
	var a := _attack
	for t in Melee.targets(self, dir, float(a["range"]) + 0.3, float(a.get("arc", 90.0))):
		var dmg: float = float(a["damage"]) * (1.0 + 0.08 * (level - 1))
		var hit = Hit.new().setup(self, dmg, "slash", float(a.get("stance", 10.0)), dir * 7.0)
		hit.parryable = not a.get("unparryable", false)
		hit.heavy = float(a.get("stance", 0.0)) >= 35.0
		t.receive_hit(hit)


## Seconds until this enemy's blow lands (for perfect dodges); INF when not attacking.
func time_to_strike() -> float:
	if _state == S.WINDUP:
		return maxf(float(_attack["windup"]) - _t, 0.0)
	if _state == S.STRIKE and not _hit_done:
		return 0.0
	return INF


func is_attacking() -> bool:
	return _state in [S.WINDUP, S.STRIKE]


func _release_token() -> void:
	if _has_token and _target_ok() and target.has_method("release_token"):
		target.release_token(int(data["stats"]["token_cost"]))
	_has_token = false


# --- Defending and reacting -------------------------------------------------------------------

func _begin_block() -> void:
	var clip: String = data["anims"].get("block", "")
	if clip == "":
		return
	_model.play_loop(clip)
	_model.play_action(clip, 1.0, 0.08, true)
	_enter(S.BLOCK)


func _defend(hit) -> String:
	if _state != S.BLOCK or hit.heavy or not hit.blockable:
		return ""
	var from: Vector3 = -hit.direction(self)
	if from.dot(-_model.global_basis.z) < 0.3:
		return ""
	add_stance(hit.stance * 0.5)
	Fx.hit_spark(global_position + Vector3(0, 1.2, 0) + from * 0.5)
	return "blocked"


## Called by the attacker's parry: stagger and lose stance.
func on_parried(stun_time: float, stance_bonus: float) -> void:
	if _state in [S.DEAD, S.EXECUTED, S.BROKEN]:
		return
	_ring.visible = false
	_release_token()
	if add_stance(max_stance * stance_bonus):
		_break()
		return
	_stun_time = stun_time
	var hits: Array = data["anims"]["hit"]
	_model.play_action(hits[hits.size() - 1], 0.8, 0.04)
	_enter(S.STUNNED)


func _unstoppable() -> bool:
	if _state == S.WINDUP:
		return float(_attack["windup"]) - _t <= float(_attack.get("unstoppable", 0.0))
	return _state == S.STRIKE


func _on_hurt(hit, amount: float) -> void:
	_alert()
	_flash = 1.0
	_bar.visible = true
	_bar_hold = 0.45
	_knock += hit.knock * (0.5 if data["id"] == "bandit_shield" else 1.0)
	Fx.hit_spark(global_position + Vector3(0, float(data["stats"]["height"]) * 0.6, 0), hit.heavy)
	if Settings.damage_numbers:
		Fx.damage_number(global_position + Vector3(0, 2.0, 0), amount, "heavy" if hit.heavy else "normal")
	_lean(hit)
	if _unstoppable() or _state in [S.BROKEN, S.EXECUTED]:
		return
	_ring.visible = false
	if _state in [S.WINDUP, S.STRIKE]:
		_release_token()
	if hit.heavy and max_stance <= 60.0:
		# Small foes are knocked off their feet by heavy blows
		_model.play_action(data["anims"]["stagger"], 1.6, 0.05, true)
		_stun_time = 1.0
		_enter(S.STUNNED)
		get_tree().create_timer(0.6, false).timeout.connect(func():
			if _state == S.STUNNED and not dead:
				_model.play_action(data["anims"]["recover"], 1.8, 0.1))
		return
	var hits: Array = data["anims"]["hit"]
	_model.play_action(hits[randi() % hits.size()], 1.7, 0.04)
	_enter(S.HURT)


## Lean away from the blow for a directional reaction.
func _lean(hit) -> void:
	var d: Vector3 = hit.direction(self)
	var local: Vector3 = _model.global_basis.inverse() * d
	var tw: Tween = _model.create_tween()
	tw.tween_property(_model, "rotation:x", -local.z * 0.25, 0.06)
	tw.parallel().tween_property(_model, "rotation:z", local.x * 0.25, 0.06)
	tw.tween_property(_model, "rotation:x", 0.0, 0.25)
	tw.parallel().tween_property(_model, "rotation:z", 0.0, 0.25)


func _on_stance_broken(hit) -> void:
	_lean(hit)
	_break()


func _break() -> void:
	_ring.visible = false
	_release_token()
	var a: Dictionary = data["anims"]
	_model.play_action(a["stagger"], 1.5, 0.05, true)
	if a.has("stagger_hold_at"):
		get_tree().create_timer(float(a["stagger_hold_at"]), false).timeout.connect(func():
			if _state == S.BROKEN:
				_model.anim.speed_scale = 0.0)
	Audio.play("hit_heavy", -4.0, 0.1, global_position)
	Fx.notify("Duruşu qırıldı — [E] infaz")
	_enter(S.BROKEN)


func _recover_from_break() -> void:
	_model.anim.speed_scale = 1.0
	_model.play_action(data["anims"]["recover"], 1.6, 0.1)
	_enter(S.HURT)
	_t = -0.6


func is_executable() -> bool:
	return _state == S.BROKEN and not dead


func begin_execution(by) -> void:
	_executor = by
	_enter(S.EXECUTED)


func finish_execution(damage: float, damage_type: String) -> void:
	var hit = Hit.new().setup(_executor, damage, damage_type, 0.0, Vector3.ZERO)
	hit.execution = true
	hit.blockable = false
	_state = S.THINK_MOVE  # let the blow land
	var result := receive_hit(hit)
	if result != "killed":
		_recover_from_break()
	if is_instance_valid(_executor) and _executor.has_method("gain_ember"):
		_executor.gain_ember(5.0)


func _on_died(_hit) -> void:
	_enter(S.DEAD)
	_release_token()
	remove_from_group("enemies")
	_shape.set_deferred("disabled", true)
	_ring.visible = false
	_bar.visible = false
	_model.anim.speed_scale = 1.0
	_model.play_action(data["anims"]["death"], 1.3, 0.05, true)
	Fx.death_burst(global_position, 1.0)
	Audio.play("shade_death" if data["faction"] == "ash" else "hit_heavy", -3.0, 0.12, global_position)
	if _target_ok() and target.has_method("on_enemy_killed"):
		target.on_enemy_killed()
	killed.emit(self)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(_model, "position:y", -1.8, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


# --- Home, aggro and leash (open world) -------------------------------------------------------

func _home_behaviour(dist: float, delta: float) -> Vector3:
	if _target_ok() and dist < aggro_range and not _returning:
		_alert()
		return Vector3.ZERO
	var to_home := home - global_position
	to_home.y = 0.0
	if to_home.length() > 1.5:
		_face(to_home, delta, 6.0)
		return to_home.normalized() * (_run_speed if _returning else _speed * 0.6)
	if _returning:
		_returning = false
		health = max_health
		stance = 0.0
		health_changed.emit(health, max_health)
		_bar.visible = false
	return Vector3.ZERO


## Wakes this foe and its packmates nearby.
func _alert() -> void:
	if aggro or _returning:
		return
	aggro = true
	for other in get_tree().get_nodes_in_group("enemies"):
		if other != self and other.has_method("_alert") and other.global_position.distance_to(global_position) < 14.0:
			other._alert()


func _check_leash(dist: float) -> void:
	if aggro_range <= 0.0:
		return
	var from_home := global_position.distance_to(home)
	if from_home > leash or (_target_ok() and dist > aggro_range * 2.6):
		aggro = false
		_returning = true
		_release_token()
		_ring.visible = false


func is_engaged() -> bool:
	return aggro and not dead


# --- Helpers ----------------------------------------------------------------------------------

func _target_ok() -> bool:
	return target != null and is_instance_valid(target) and not target.dead


func _to_target() -> Vector3:
	if not _target_ok():
		return Vector3.ZERO
	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	return to


func _face(dir: Vector3, delta: float, rate: float) -> void:
	if dir.length() > 0.01:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-rate * delta))


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		var d: Vector3 = global_position - other.global_position
		d.y = 0.0
		var l := d.length()
		if l < 1.5 and l > 0.001:
			push += d / l * (1.5 - l)
	return push


func _update_bar(delta: float) -> void:
	if not _bar.visible:
		return
	var ratio := clampf(health / max_health, 0.0, 1.0)
	_bar_hold -= delta
	if _bar_hold <= 0.0:
		_bar_lag = move_toward(_bar_lag, ratio, delta * 1.5)
	_bar_mat.set_shader_parameter("ratio", ratio)
	_bar_mat.set_shader_parameter("lag", maxf(_bar_lag, ratio))
	_bar_mat.set_shader_parameter("stance", stance / max_stance if max_stance > 0.0 else 0.0)
