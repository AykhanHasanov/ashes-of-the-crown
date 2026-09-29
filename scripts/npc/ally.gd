extends "res://scripts/combat/combatant.gd"
## A companion fighting beside the protagonist (NpcDefinition.companion, WorldState location
## "party"). Built on the V3 combat systems: a Combatant on the protagonist's side, so his
## blows never land on the protagonist and the protagonist's never land on him (is_hostile).
##
## Ported from the V2 companion (scripts/npc/companion.gd, kept as reference) is only what
## worked: go for the nearest enemy, close in, swing on a cooldown, the blow landing at the
## clip's impact. New: he follows the protagonist, shares the fight's attack tokens, and
## sometimes draws an enemy off the protagonist (Foe.retarget) for a while.
##
## He is DOWNED, never killed, in ordinary combat: at 0 health he goes down and enemies
## lose interest. The protagonist helps him up (help_up(), within help_range), or he gets up
## alone once no enemy is near for recover_calm seconds. His permanent fate is the story's
## (WorldState.kill_npc) — this script never changes WorldState.
## Numbers: data/balance/allies.json, per NPC id.

signal downed_changed(is_downed: bool)

const Human := preload("res://scripts/characters/human.gd")
const Melee := preload("res://scripts/combat/melee.gd")
const Names := preload("res://scripts/core/names.gd")

enum S { FOLLOW, FIGHT, WINDUP, RECOVER, HURT, DOWNED, RISING, REST }

var npc_id: StringName
var def: Resource                 # NpcDefinition
var player: Node3D                # the protagonist
var height_at := Callable()       # (x, z) -> ground height; optional safety net on terrain

var _cfg: Dictionary
var _model: Node3D
var _state := S.FOLLOW
var _t := 0.0
var _cooldown := 0.0
var _foe: Node3D
var _hit_done := false
var _clip_i := 0
var _yaw := 0.0
var _vy := 0.0
var _knock := Vector3.ZERO
var _calm_t := 0.0
var _tokens_used := 0
var _drawn: Dictionary = {}       # foe -> ms when it goes back to the protagonist
var _fighting := false
var rest_spot: Variant = null     # Transform3D: resting there (his bed in the hub at night); null follows
var _idle_before := ""
const REST_CLIP := "Sit_Chair_Idle"   # awake on his bed's edge, listening (STORY_SLICE §S4: he does not sleep)


func setup(definition: Resource, protagonist: Node3D) -> void:
	def = definition
	npc_id = def.id
	player = protagonist


func _ready() -> void:
	_cfg = DataDB.balance("allies").get(String(npc_id), {})
	faction = "ally"
	display_name = Names.npc(npc_id)
	max_health = float(_cfg.get("health", 150))
	health = max_health
	radius = 0.42
	token_budget = int(_cfg.get("tokens", 2))
	add_to_group("combatants")
	add_to_group("player_side")
	add_to_group("npcs")
	add_to_group("allies")
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(npc_id))
	_model = Human.build(Human.spec_from_json({"look": def.look_id}, rng))
	add_child(_model)
	_model.move_anim = "Running_A"
	if def.weapon_path != "":
		_model.attach(def.weapon_path, "handslot.r")
	if def.shield_path != "":
		_model.attach(def.shield_path, "handslot.l", Vector3.ZERO, true)
	EventBus.memory_burned.connect(func(_id): display_name = Names.npc(npc_id))
	EventBus.npc_changed.connect(_on_npc_changed)
	EventBus.state_replaced.connect(func(): display_name = Names.npc(npc_id))


# --- What enemies ask of their target (Foe) ---------------------------------------------------

func request_token(cost: int) -> bool:
	if _tokens_used + cost > token_budget:
		return false
	_tokens_used += cost
	return true


func release_token(cost: int) -> void:
	_tokens_used = maxi(_tokens_used - cost, 0)


func facing() -> Vector3:
	return Vector3(sin(_yaw), 0, cos(_yaw))


## Rest at `spot` (a Transform3D: where, and facing its -Z like the model) until called with
## null — then he follows again. The hub sits him on his bed at night: awake, never asleep.
func rest_at(spot: Variant) -> void:
	if spot is Transform3D:
		rest_spot = spot
		global_position = (spot as Transform3D).origin + Vector3(0, 0.05, 0)
		var f: Vector3 = -(spot as Transform3D).basis.z
		_yaw = atan2(f.x, f.z)
		_model.rotation.y = _yaw + PI
		if _idle_before == "":
			_idle_before = _model.idle_anim
		_model.set_idle(REST_CLIP)
		velocity = Vector3.ZERO
		_enter(S.REST)
	elif rest_spot != null:
		rest_spot = null
		_model.set_idle(_idle_before if _idle_before != "" else _model.idle_anim)
		_idle_before = ""
		_enter(S.FOLLOW)


func is_resting() -> bool:
	return _state == S.REST


func is_down() -> bool:
	return _state == S.DOWNED


func is_attacking() -> bool:
	return _state == S.WINDUP


func state_name() -> String:
	return S.keys()[_state]


# --- Damage: downed, never dead ---------------------------------------------------------------

func receive_hit(hit) -> String:
	if _state in [S.DOWNED, S.RISING]:
		return "ignored"
	var r := super.receive_hit(hit)
	return "broken" if r == "killed" else r


func _on_hurt(hit, _amount: float) -> void:
	if _state in [S.FOLLOW, S.FIGHT, S.RECOVER]:
		_enter(S.HURT)
		_model.play_action("Hit_A" if randf() < 0.5 else "Hit_B", 1.6, 0.05)
		_knock = hit.knock * 0.3
		_say("hurt", 0.4)


func _on_stance_broken(hit) -> void:
	_on_hurt(hit, 0.0)


## Health reached 0 (a blow or burning): he goes down instead of dying.
func _on_died(_hit) -> void:
	dead = false
	health = 0.0
	statuses.clear()
	_go_down()


func _go_down() -> void:
	_enter(S.DOWNED)
	_calm_t = 0.0
	_foe = null
	_release_drawn(true)
	_model.cancel_action()
	_model.play_action("Lie_Down", 1.4, 0.05, true)
	_say("downed", 1.0)
	downed_changed.emit(true)


## The protagonist helps him up (the mode calls this on interact within help_range()).
func help_up() -> bool:
	if _state != S.DOWNED:
		return false
	_rise(float(_cfg["downed"]["help_health"]), "helped")
	return true


func help_range() -> float:
	return float(_cfg.get("downed", {}).get("help_range", 2.2))


func _rise(health_fraction: float, bark: String) -> void:
	health = max_health * health_fraction
	health_changed.emit(health, max_health)
	stance = 0.0
	make_invulnerable(float(_cfg["downed"]["invulnerable_after"]))
	_enter(S.RISING)
	_model.cancel_action()
	_model.play_action("Lie_StandUp", 1.4, 0.05)
	_say(bark, 1.0)
	downed_changed.emit(false)


# --- Brain ------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	_cooldown -= delta
	tick_stance(delta)
	tick_statuses(delta)
	_expire_drawn()
	var move := Vector3.ZERO
	if _state == S.REST:
		_model.set_locomotion(false)
		return
	match _state:
		S.FOLLOW, S.FIGHT:
			move = _think()
		S.WINDUP:
			_face_to(_foe)
			if not _hit_done and _t >= float(_cfg["windup"]):
				_hit_done = true
				_land()
			if _t >= float(_cfg["windup"]) + float(_cfg["recovery"]):
				_enter(S.FIGHT)
		S.HURT:
			if _t > 0.45:
				_enter(S.FIGHT)
		S.DOWNED:
			_calm_t = _calm_t + delta if not _enemy_near(float(_cfg["downed"]["calm_range"])) else 0.0
			if _calm_t >= float(_cfg["downed"]["recover_calm"]):
				_rise(float(_cfg["downed"]["recover_health"]), "recovered")
		S.RISING:
			if _t > 1.2:
				_model.cancel_action()
				_enter(S.FOLLOW)
	_vy = 0.0 if is_on_floor() else _vy - 22.0 * delta
	velocity = Vector3(move.x + _knock.x, _vy, move.z + _knock.z)
	_knock = _knock.lerp(Vector3.ZERO, 1.0 - exp(-8.0 * delta))
	move_and_slide()
	if height_at.is_valid():
		var ground: float = height_at.call(global_position.x, global_position.z)
		if global_position.y < ground - 0.5:
			global_position.y = ground
	_model.set_locomotion(move.length() > 0.2, clampf(move.length() / float(_cfg["run_speed"]), 0.5, 1.2))
	_model.rotation.y = lerp_angle(_model.rotation.y, _yaw + PI, 1.0 - exp(-10.0 * delta))   # the model faces -Z


func _think() -> Vector3:
	if player == null or not is_instance_valid(player):
		return Vector3.ZERO
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > float(_cfg["teleport_distance"]):
		global_position = follow_point()
		return Vector3.ZERO
	if not _foe_ok(_foe):
		_foe = _pick_foe()
	var fighting := _foe != null
	if fighting and not _fighting:
		_say("spot", 0.8)
	elif not fighting and _fighting:
		_say("victory", 0.5)
	_fighting = fighting
	if not fighting:
		# Beside and a little behind the protagonist as the camera sees him: never between the
		# camera and him, never in front of him
		_state = S.FOLLOW
		var to_spot := follow_point() - global_position
		to_spot.y = 0.0
		var d := to_spot.length()
		if d > float(_cfg["follow_slack"]):
			_yaw = atan2(to_spot.x, to_spot.z)
			var speed: float = float(_cfg["run_speed"]) if to_player.length() > float(_cfg["catch_up_distance"]) else float(_cfg["walk_speed"]) * 1.6
			return to_spot.normalized() * minf(speed, d * 4.0)
		if player.has_method("facing"):
			var f: Vector3 = player.facing()
			_yaw = atan2(f.x, f.z)
		return Vector3.ZERO
	_state = S.FIGHT
	var to: Vector3 = _foe.global_position - global_position
	to.y = 0.0
	_yaw = atan2(to.x, to.z)
	if to.length() > float(_cfg["reach"]) + float(_foe.get("radius")) - 0.2:
		return to.normalized() * float(_cfg["run_speed"])
	if _cooldown <= 0.0:
		_swing()
	return Vector3.ZERO


## Where he walks with the protagonist: to the side and slightly behind, measured in the
## camera's frame (so he stays out of the view), on the side he is already on.
func follow_point() -> Vector3:
	var right := Vector3.RIGHT
	var back := Vector3.BACK
	var cam = player.get("camera")
	if cam != null and is_instance_valid(cam):
		right = (cam.global_basis.x * Vector3(1, 0, 1)).normalized()
		back = (cam.global_basis.z * Vector3(1, 0, 1)).normalized()
	elif player.has_method("facing"):
		back = -player.facing()
		right = back.cross(Vector3.UP).normalized() * -1.0
	var side := 1.0 if (global_position - player.global_position).dot(right) >= 0.0 else -1.0
	return player.global_position + right * side * float(_cfg["follow_side"]) + back * float(_cfg["follow_back"])


func _swing() -> void:
	_cooldown = float(_cfg["cooldown"])
	_hit_done = false
	var clips: Array = _cfg["clips"]
	_clip_i = (_clip_i + 1) % clips.size()
	_model.play_action(clips[_clip_i], 1.0, 0.06)
	Audio.play("swing", -12.0, 0.1, global_position, 3)
	_say("attack", 0.25)
	_enter(S.WINDUP)


## The blow lands on whoever is in the arc — enemies only (Melee skips his own side).
func _land() -> void:
	for t in Melee.targets(self, facing(), float(_cfg["reach"]), float(_cfg["arc"])):
		var dir: Vector3 = (t.global_position - global_position).normalized()
		var hit = Hit.new().setup(self, float(_cfg["damage"]) * damage_mult, "slash", float(_cfg["stance"]) * stance_mult, dir * 4.0)
		var r: String = t.receive_hit(hit)
		if r != "ignored":
			Audio.play("hit", -8.0, 0.1, t.global_position, 3)
		if t == _foe and r in ["hit", "broken"]:
			_maybe_draw(t)


## Sometimes the enemy he hits turns on him, off the protagonist — for a while.
func _maybe_draw(foe: Node3D) -> void:
	if not foe.has_method("retarget") or foe.get("target") != player or randf() > float(_cfg["draw_aggro_chance"]):
		return
	foe.retarget(self)
	_drawn[foe] = Time.get_ticks_msec() + int(float(_cfg["draw_aggro_seconds"]) * 1000.0)


func _expire_drawn() -> void:
	if _drawn.is_empty():
		return
	var now := Time.get_ticks_msec()
	for f in _drawn.keys():
		if not is_instance_valid(f):
			_drawn.erase(f)
		elif now >= int(_drawn[f]):
			_drawn.erase(f)
			if f.get("target") == self:
				f.retarget(player)


## Everyone he drew off goes back to the protagonist (he is down, or leaving).
func _release_drawn(all := false) -> void:
	for f in _drawn.keys():
		if is_instance_valid(f) and f.get("target") == self:
			f.retarget(player)
	_drawn.clear()
	if all:
		for f in get_tree().get_nodes_in_group("enemies"):
			if f.get("target") == self and f.has_method("retarget"):
				f.retarget(player)


func _exit_tree() -> void:
	if is_inside_tree():
		_release_drawn(true)


func _pick_foe() -> Node3D:
	var best: Node3D = null
	var best_d := float(_cfg["engage_range"])
	for f in get_tree().get_nodes_in_group("enemies"):
		if not _foe_ok(f):
			continue
		var d: float = global_position.distance_to(f.global_position)
		# Enemies on the protagonist first
		if player != null and f.global_position.distance_to(player.global_position) < 4.0:
			d *= 0.6
		if d < best_d:
			best_d = d
			best = f
	return best


func _foe_ok(f) -> bool:
	return f != null and is_instance_valid(f) and not f.dead and f.is_in_group("enemies") \
		and (not f.has_method("is_engaged") or f.is_engaged()) \
		and global_position.distance_to(f.global_position) < float(_cfg["engage_range"]) * 1.5


func _enemy_near(dist: float) -> bool:
	for f in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(f) and not f.dead and global_position.distance_to(f.global_position) < dist \
				and (not f.has_method("is_engaged") or f.is_engaged()):
			return true
	return false


func _face_to(n) -> void:
	if is_instance_valid(n):
		var to: Vector3 = n.global_position - global_position
		_yaw = atan2(to.x, to.z)


func _enter(s: int) -> void:
	_state = s
	_t = 0.0


func _say(event: String, chance: float) -> void:
	if def != null and def.voice_profile != "":
		Barks.say(self, def.voice_profile, event, chance, 1.85)


## A revealed name shows at once.
func _on_npc_changed(id: StringName) -> void:
	if id == npc_id:
		display_name = Names.npc(npc_id)
