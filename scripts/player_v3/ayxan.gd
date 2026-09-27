extends "res://scripts/combat/combatant.gd"
## Ayxan in the V3 open-world combat system (souls-lite).
##
## Movement: walk/run on the stick or keys, Shift sprint (stamina), jump from a sprint.
## Stamina gates every action; presses made without enough stamina wait in a short buffer.
## Weapons are data (data/weapons/*.json): a light combo chain, a heavy blow that charges
## while held, a running attack and an attack out of a dodge.
## Block (right mouse): the first moments are a parry window. Hits drain stamina while
## blocking; running dry breaks the guard.
## Enemies whose stance breaks collapse for two seconds — E executes them.
## Nar şərbəti (R) heals 40% over a vulnerable drink.
## V2 fire stays: Q tap = Köz Zərbəsi, Q hold = memory wheel + Alov Dalğası,
## perfect dodges, and Kül Şahı's offer at low health.
## Open world (data/balance/world.json → movement): swimming costs stamina and then
## health, slopes steeper than slide_angle slide you down, falls above fall_safe hurt
## (fall_lethal kills), and low obstacles up to vault_height are vaulted while running.

signal ember_changed(current: float, maximum: float)
signal flasks_changed(current: int, maximum: int)
signal weapon_changed(weapon_name: String)
signal lock_changed(target)

const CharacterModel := preload("res://scripts/characters/character_model.gd")
const Human := preload("res://scripts/characters/human.gd")
## Ayxan: a hooded ranger in ash-stained crimson (realistic V3 look)
const LOOK := {"outfit": "Male_Ranger", "hood": true, "beard": true, "hair": "Hair_SimpleParted",
	"hair_color": Color(0.11, 0.08, 0.06), "cloth_hue": [0.18, 0.55, 0.985, 1.05, 0.62]}
const Effects := preload("res://scripts/world/effects.gd")
const Melee := preload("res://scripts/combat/melee.gd")
const OVERLAY := preload("res://shaders/ash_overlay.gdshader")
const PlayerHabits := preload("res://scripts/combat/player_habits.gd")
const MODEL_PATH := "res://assets/characters/adventurers/Rogue_Hooded.glb"
const HIDDEN := ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable"]
const MAX_HEALTH := 120.0

enum S { MOVE, AIR, DODGE, ATTACK, CHARGE, BLOCK, DRINK, HURT, KNOCKDOWN, EXECUTE, STRIKE, CAST, DEAD, SWIM, SLIDE, VAULT }

var camera: Camera3D
var rig                     # third-person camera node
var radial                  # memory wheel UI
var offer                   # Kül Şahı's offer UI
var input_locked := false
var ember := 0.0
var flasks := 4
var max_flasks := 4
var weapon: Dictionary = {}
var weapon_slots := ["sword", "sword_shield", "mace"]
var lock_target = null
var last_hurt_ms := -100000
## Open world: returns the water surface height at a point, or -1000 when dry.
var water_query := Callable()
## Adaptive AI reads these (spec §4.1); noise wakes enemies that hear the fight.
var habits := PlayerHabits.new()
var level := 1
var last_noise_ms := -100000

var _cfg: Dictionary
var _state := S.MOVE
var _state_t := 0.0
var _model
var _overlay: ShaderMaterial
var _cloth: Array = []
var _weapon_nodes: Array = []
var _ember_node: Node3D
var _ember_light: OmniLight3D
var _facing := Vector3.FORWARD
var _move_dir := Vector3.ZERO

var _combo := -1
var _attack: Dictionary = {}
var _attack_kind := "light"
var _impact_done := false
var _charge_t := 0.0
var _charge_level := 0.0
var _last_dodge_end_ms := -100000
var _dodge_dir := Vector3.FORWARD
var _block_start_ms := 0
var _stamina_last_use_ms := 0
var _exhausted_until_ms := 0
var _buffer := ""
var _buffer_ms := 0
var _heal_done := false
var _exec_target = null
var _fire_down_ms := -1
var _last_ember_ms := -100000
var _strike_cd := 0.0
var _wave_cd := 0.0
var _cast_memory := ""
var _offer_used := false
var _step_dist := 0.0
var _flash := 0.0
var _tokens_used := 0
var _move_cfg: Dictionary = {}
var _fall_from := NAN
var _vault_from := Vector3.ZERO
var _vault_to := Vector3.ZERO
var _slide_t := 0.0
var _water_level := -1000.0
var _habit_t := 0.0
var _burn_fx: Node3D


func _ready() -> void:
	_cfg = DataDB.balance("combat")
	add_to_group("player")
	add_to_group("player_side")
	add_to_group("combatants")
	faction = "ayxan"
	display_name = "Ayxan"
	max_health = MAX_HEALTH
	health = max_health
	max_stamina = _cfg["stamina"]["max"]
	stamina = max_stamina
	max_stance = _cfg["player"]["hidden_stance"]
	radius = 0.4
	token_budget = int(_cfg["tokens"]["player_budget"])
	max_flasks = int(_cfg["flask"]["charges"])
	flasks = max_flasks
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(52.0)
	_move_cfg = DataDB.balance("world").get("movement", {})
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)

	_model = Human.build(LOOK)
	add_child(_model)
	_cloth = _model.recolor(0.18, 0.55, 0.985, 1.05, 0.62)
	_overlay = ShaderMaterial.new()
	_overlay.shader = OVERLAY
	_overlay.set_shader_parameter("intensity", 0.0)
	_overlay.set_shader_parameter("scale", 9.0)
	_overlay.set_shader_parameter("flash_color", Color(0.6, 0.05, 0.02))
	_model.set_overlay(_overlay)
	_make_ember()
	equip("sword")
	EventBus.memory_burned.connect(func(_id: StringName): _refresh_burn_look())
	EventBus.state_replaced.connect(_refresh_burn_look)
	_emit_all.call_deferred()


func _emit_all() -> void:
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)
	ember_changed.emit(ember, _cfg["ember"]["max"])
	flasks_changed.emit(flasks, max_flasks)


func _make_ember() -> void:
	_ember_node = Node3D.new()
	_ember_node.top_level = true
	add_child(_ember_node)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.1)
	mat.emission_energy_multiplier = 3.0
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	core.mesh = sphere
	core.material_override = mat
	_ember_node.add_child(core)
	_ember_light = OmniLight3D.new()
	_ember_light.light_color = Color(1.0, 0.5, 0.2)
	_ember_light.light_energy = 1.0
	_ember_light.omni_range = 3.0
	_ember_node.add_child(_ember_light)


# --- Weapons -------------------------------------------------------------------------------

func equip(id: String) -> void:
	var w := DataDB.weapon(id)
	if w.is_empty():
		return
	for n in _weapon_nodes:
		if is_instance_valid(n):
			(n.get_parent().get_parent() if _model is Human else n.get_parent()).queue_free()
	_weapon_nodes.clear()
	weapon = w
	var m: Dictionary = w["model"]
	if m.has("donor"):
		_weapon_nodes.append(_model.borrow(m["donor"], m["node"], "handslot.r"))
	else:
		var item: Node3D = _model.attach(m["path"], "handslot.r", _vec(m.get("rotation", [0, 0, 0])))
		_fit_item(item, float(m.get("length", 1.0)))
		_weapon_nodes.append(item)
	if w["shield"] is Dictionary:
		if w["shield"].has("path"):
			_weapon_nodes.append(_model.attach(w["shield"]["path"], "handslot.l", Vector3.ZERO, true))
		else:
			_weapon_nodes.append(_model.borrow(w["shield"]["donor"], w["shield"]["node"], "handslot.l"))
	_combo = -1
	weapon_changed.emit(w["name"])


func _fit_item(item: Node3D, length: float) -> void:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in item.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()
		var n: Node = mi
		while n != item and n != null:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b: AABB = xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if longest > 0.0001:
		item.scale = Vector3.ONE * (length / longest)


func _vec(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


# --- Input -----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if input_locked or dead:
		return
	if event.is_action_pressed("ember_power") and not event.is_echo():
		_fire_down_ms = Time.get_ticks_msec() if _state in [S.MOVE, S.ATTACK, S.BLOCK] else -1
	elif event.is_action_released("ember_power") and _fire_down_ms >= 0:
		var held := (Time.get_ticks_msec() - _fire_down_ms) / 1000.0
		_fire_down_ms = -1
		if radial != null and radial.is_open:
			_release_wheel()
		elif held < _cfg["ember"]["tap_threshold"]:
			_request("strike")
	elif event.is_action_pressed("lock_on"):
		_toggle_lock()
	elif event.is_action_pressed("lock_next"):
		_switch_lock(1)
	elif event.is_action_pressed("lock_prev"):
		_switch_lock(-1)
	for i in 3:
		if event.is_action_pressed("skill_%d" % (i + 1)) and i < weapon_slots.size():
			if _state == S.MOVE:
				equip(weapon_slots[i])


func _request(action: String) -> void:
	_buffer = action
	_buffer_ms = Time.get_ticks_msec()


func _physics_process(delta: float) -> void:
	_state_t += delta
	_strike_cd -= delta
	_wave_cd -= delta
	tick_stance(delta)
	tick_statuses(delta)
	_update_burn_fx()
	_sample_distance_habit(delta)
	_flash = maxf(_flash - delta * 4.0, 0.0)
	_overlay.set_shader_parameter("hit_flash", _flash)
	_tick_stamina(delta)
	_tick_ember(delta)
	if dead:
		velocity = Vector3(0, velocity.y - 22.0 * delta, 0)
		move_and_slide()
		return

	var input := Vector2.ZERO
	var wheel_open: bool = radial != null and radial.is_open
	if not input_locked and not wheel_open:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if Input.is_action_just_pressed("attack"):
			_request("sprint_attack" if _is_sprinting() else "light")
		if Input.is_action_just_pressed("dash"):
			_request("jump" if _is_sprinting() and is_on_floor() else "dodge")
		if Input.is_action_just_pressed("jump"):
			_request("jump")
		if Input.is_action_just_pressed("heavy"):
			_request("heavy")
		if Input.is_action_just_pressed("drink"):
			_request("drink")
		if Input.is_action_just_pressed("interact"):
			_request("execute")
	_move_dir = _camera_relative(input)
	_check_water()
	_try_buffer()

	match _state:
		S.MOVE:
			_do_move(delta)
		S.AIR:
			_do_air(delta)
		S.DODGE:
			_do_dodge(delta)
		S.ATTACK:
			_do_attack(delta)
		S.CHARGE:
			_do_charge(delta)
		S.BLOCK:
			_do_block(delta)
		S.DRINK:
			_do_drink(delta)
		S.HURT, S.KNOCKDOWN:
			_do_hurt(delta)
		S.EXECUTE:
			_do_execute(delta)
		S.STRIKE:
			_slow_to_stop(delta)
			if _state_t > 0.45:
				_enter(S.MOVE)
		S.CAST:
			_do_cast(delta)
		S.SWIM:
			_do_swim(delta)
		S.SLIDE:
			_do_slide(delta)
		S.VAULT:
			_do_vault(delta)

	if not is_on_floor() and _state not in [S.AIR, S.DODGE, S.SWIM, S.VAULT]:
		velocity.y -= _cfg["player"]["gravity"] * delta
	elif is_on_floor() and velocity.y < 0.0:
		velocity.y = -0.5
	if _state != S.VAULT:
		move_and_slide()
	_check_fall()
	_update_facing(delta)
	if rig:
		rig.in_combat = _enemies_near(14.0)
		rig.lock_target = lock_target if _lock_valid() else null
	if lock_target != null and not _lock_valid():
		_set_lock(null)


func _process(_delta: float) -> void:
	var fwd: Vector3 = -_model.global_basis.z
	_ember_node.global_position = _model.bone_position("chest") + fwd * 0.3 + Vector3(0, 0.05, 0)
	if _fire_down_ms >= 0 and radial != null and not radial.is_open:
		if (Time.get_ticks_msec() - _fire_down_ms) / 1000.0 >= _cfg["ember"]["tap_threshold"]:
			_open_wheel()


# --- State machine ---------------------------------------------------------------------------

func _enter(s: int) -> void:
	_state = s
	_state_t = 0.0


## Starts a buffered action as soon as the state and stamina allow it.
func _try_buffer() -> void:
	if _buffer == "":
		return
	if Time.get_ticks_msec() - _buffer_ms > _cfg["stamina"]["input_buffer"] * 1000.0:
		_buffer = ""
		return
	var st: Dictionary = _cfg["stamina"]
	match _buffer:
		"light", "sprint_attack":
			var can: bool = _state in [S.MOVE, S.BLOCK] or (_state == S.ATTACK and _attack_kind == "light" and _state_t >= _attack["cancel"] * 0.8) \
				or (_state == S.DODGE and _state_t > 0.18)
			if can and _spend(st["light_cost"]):
				_buffer = _begin_light()
		"heavy":
			if (_state in [S.MOVE, S.BLOCK] or (_state == S.ATTACK and _state_t >= _attack["cancel"] * 0.8)) and stamina > 1.0:
				_buffer = ""
				_begin_charge()
		"dodge":
			if _state in [S.MOVE, S.BLOCK, S.CHARGE] or (_state == S.ATTACK and _state_t >= _attack.get("impact", 0.0)) or (_state == S.HURT and _state_t > 0.2):
				if _spend(st["dodge_cost"]):
					_buffer = ""
					_begin_dodge()
		"jump":
			if _state == S.MOVE and is_on_floor():
				_buffer = ""
				_begin_jump()
		"drink":
			if _state == S.MOVE and flasks > 0:
				_buffer = ""
				_begin_drink()
		"execute":
			_buffer = ""
			if _state in [S.MOVE, S.BLOCK]:
				_try_execute()
		"strike":
			if _state in [S.MOVE, S.BLOCK] and _strike_cd <= 0.0:
				_buffer = ""
				_ember_strike()


func _do_move(delta: float) -> void:
	var p: Dictionary = _cfg["player"]
	if Input.is_action_pressed("block") and not input_locked:
		_begin_block()
		return
	var sprint := _is_sprinting()
	var speed: float = p["sprint_speed"] if sprint else (p["run_speed"] if _move_dir.length() > 0.6 else p["walk_speed"])
	var want: Vector3 = _move_dir * speed
	velocity.x = move_toward(velocity.x, want.x, p["accel"] * delta)
	velocity.z = move_toward(velocity.z, want.z, p["accel"] * delta)
	if sprint:
		_drain_stamina(_cfg["stamina"]["sprint_cost_per_sec"] * delta)
	if not is_on_floor():
		_enter(S.AIR)
	_locomotion_anim(speed, sprint)
	_footsteps(delta)
	if not _move_cfg.is_empty():
		_check_slope()
		if speed >= _cfg["player"]["run_speed"] - 0.1 and _state == S.MOVE:
			_try_vault()


func _do_air(delta: float) -> void:
	var p: Dictionary = _cfg["player"]
	velocity.y -= p["gravity"] * delta
	var want: Vector3 = _move_dir * (p["sprint_speed"] * 0.9)
	velocity.x = move_toward(velocity.x, want.x, 8.0 * delta)
	velocity.z = move_toward(velocity.z, want.z, 8.0 * delta)
	if is_on_floor() and _state_t > 0.1:
		_model.play_action("Jump_Land", 2.0, 0.05)
		_enter(S.MOVE)


func _begin_jump() -> void:
	velocity.y = _cfg["player"]["jump_velocity"]
	_model.play_action("Jump_Start", 1.6, 0.05)
	_enter(S.AIR)


func _begin_dodge() -> void:
	var d: Dictionary = _cfg["dodge"]
	_end_attack()
	_dodge_dir = _move_dir.normalized() if _move_dir.length() > 0.1 else -_facing
	make_invulnerable(d["invuln"])
	if _enemies_near(12.0):
		habits.record("dodge")
	var clip := "Dodge_Forward"
	if _lock_valid():
		var local := _dodge_dir.dot(_facing)
		var side := _dodge_dir.dot(_facing.cross(Vector3.UP))
		clip = "Dodge_Forward" if local > 0.5 else ("Dodge_Backward" if local < -0.5 else ("Dodge_Right" if side < 0.0 else "Dodge_Left"))
	else:
		_facing = _dodge_dir
	_model.play_action(clip, 1.3, 0.04)
	Fx.ash_puff(global_position)
	Audio.play("dash", -6.0, 0.1)
	_enter(S.DODGE)
	if _is_perfect_dodge():
		_perfect_dodge()


func _do_dodge(_delta: float) -> void:
	var d: Dictionary = _cfg["dodge"]
	var k := clampf(1.0 - _state_t / d["time"], 0.0, 1.0)
	velocity.x = _dodge_dir.x * d["speed"] * (0.35 + 0.65 * k)
	velocity.z = _dodge_dir.z * d["speed"] * (0.35 + 0.65 * k)
	if _state_t >= d["time"]:
		_last_dodge_end_ms = Time.get_ticks_msec()
		_model.cancel_action()
		_enter(S.MOVE)


# --- Attacks ---------------------------------------------------------------------------------

func _light_chain() -> Array:
	var mastery := 1  # weapon mastery arrives in phase D
	return weapon["light"].filter(func(a): return int(a.get("mastery", 1)) <= mastery)


## Returns "" when started (clears the buffer).
func _begin_light() -> String:
	var dodge_attack: bool = Time.get_ticks_msec() - _last_dodge_end_ms < _cfg["dodge"]["attack_window"] * 1000.0 or _state == S.DODGE
	if _state == S.DODGE:
		_model.cancel_action()
	if _buffer == "sprint_attack" and weapon.has("running"):
		_start_attack(weapon["running"], "running")
	elif dodge_attack and weapon.has("dodge_attack"):
		_start_attack(weapon["dodge_attack"], "dodge")
	else:
		var chain := _light_chain()
		_combo = (_combo + 1) % chain.size() if _state == S.ATTACK and _attack_kind == "light" else 0
		_start_attack(chain[_combo], "light")
	return ""


func _begin_charge() -> void:
	_end_attack()
	_charge_t = 0.0
	var windup: String = weapon["charged"].get("windup_clip", "")
	if windup != "":
		_model.play_action(windup, 1.0, 0.1, true)
	_enter(S.CHARGE)


func _do_charge(delta: float) -> void:
	_slow_to_stop(delta)
	_charge_t += delta
	var c: Dictionary = _cfg["charge"]
	var held := Input.is_action_pressed("heavy") and not input_locked
	if not held or _charge_t >= c["full_charge"]:
		_model.cancel_action()
		var st: Dictionary = _cfg["stamina"]
		if _charge_t < c["hold_to_charge"]:
			_spend(st["heavy_cost"], true)
			_start_attack(weapon["heavy"], "heavy")
		else:
			_spend(st["charged_cost"], true)
			_charge_level = clampf((_charge_t - c["hold_to_charge"]) / (c["full_charge"] - c["hold_to_charge"]), 0.0, 1.0)
			_start_attack(weapon["charged"], "charged")


func _start_attack(a: Dictionary, kind: String) -> void:
	last_noise_ms = Time.get_ticks_msec()
	_attack = a
	_attack_kind = kind
	_impact_done = false
	if kind != "light":
		_combo = -1
	_aim_at_target()
	_model.play_action(a["clip"], a["speed"], 0.05)
	Audio.play("swing", -3.0 if kind in ["heavy", "charged"] else -7.0, 0.1, null, 3)
	_enter(S.ATTACK)


func _do_attack(_delta: float) -> void:
	var a := _attack
	# Step into the swing unless someone is already in the face
	if _state_t < 0.16 and not _enemies_near(1.3):
		var lunge: float = a.get("lunge", 6.0)
		velocity.x = _facing.x * lunge
		velocity.z = _facing.z * lunge
	else:
		velocity.x = move_toward(velocity.x, 0.0, 60.0 * _delta)
		velocity.z = move_toward(velocity.z, 0.0, 60.0 * _delta)
	if not _impact_done and _state_t >= a["impact"]:
		_impact_done = true
		_impact(a)
	var cancel: float = a["cancel"] * float(weapon.get("recovery_factor", 1.0))
	if _state_t >= cancel + 0.35 or (_state_t >= cancel and _move_dir.length() > 0.2 and _buffer == ""):
		_end_attack()
		_enter(S.MOVE)


func _impact(a: Dictionary) -> void:
	var stance_mults: Dictionary = _cfg["stance"]
	var kind_mult: float = stance_mults["light_mult"]
	var dmg: float = a["damage"]
	if _attack_kind in ["heavy", "running"]:
		kind_mult = stance_mults["heavy_mult"]
	elif _attack_kind == "charged":
		kind_mult = stance_mults["charged_mult"]
		dmg = lerpf(weapon["heavy"]["damage"], a["damage"], _charge_level)
	var stance_dmg: float = dmg * kind_mult * float(weapon.get("stance_factor", 1.0)) * float(a.get("stance_bonus", 1.0))
	var dtype: String = a.get("damage_type", weapon["damage_type"])
	Fx.slash(global_position + Vector3(0, 1.0, 0), _facing, 1.0 if _combo % 2 == 0 else -1.0, _attack_kind != "light")
	var hits := 0
	var blocked := false
	for t in Melee.targets(self, _facing, a["range"], a["arc"]):
		var hit = Hit.new().setup(self, dmg * randf_range(0.93, 1.07), dtype, stance_dmg, _facing * (10.0 if _attack_kind != "light" else 5.0))
		hit.heavy = _attack_kind in ["heavy", "charged"]
		var result: String = t.receive_hit(hit)
		match result:
			"blocked":
				blocked = true
			"hit", "broken", "killed":
				hits += 1
	var weight: String = weapon.get("hitstop", "light")
	if hits > 0:
		gain_ember(_cfg["ember"]["on_hit"])
		var heavy_blow := _attack_kind in ["heavy", "charged"]
		Audio.play("hit_heavy" if heavy_blow or weight == "heavy" else "hit", -2.0 if heavy_blow else -3.0, 0.08, null, 0 if heavy_blow or weight == "heavy" else 3)
		Fx.hitstop(_cfg["hitstop"]["heavy" if heavy_blow or weight == "heavy" else "light"] * (1.3 if _attack_kind == "charged" else 1.0))
		Fx.shake(a.get("shake", 0.25))
		if heavy_blow:
			Fx.punch(1.0)
	elif blocked:
		Audio.play("block", -2.0, 0.1)
		Fx.shake(0.2)
		if _attack_kind == "light":
			_end_attack()
			_model.play_action("Block_Hit", 1.6, 0.05)
			_enter(S.HURT)


func _end_attack() -> void:
	if _state == S.ATTACK or _state == S.CHARGE:
		_model.cancel_action()
	_attack = {}


# --- Block and parry -------------------------------------------------------------------------

func _begin_block() -> void:
	_block_start_ms = Time.get_ticks_msec()
	_model.play_loop("Blocking", 1.0, 0.08)
	_enter(S.BLOCK)


func _do_block(delta: float) -> void:
	_slow_to_stop(delta, 0.35)
	var want: Vector3 = _move_dir * _cfg["player"]["walk_speed"] * 0.6
	velocity.x = move_toward(velocity.x, want.x, 20.0 * delta)
	velocity.z = move_toward(velocity.z, want.z, 20.0 * delta)
	_model.play_loop("Blocking", 1.0, 0.08)
	if not Input.is_action_pressed("block") or input_locked:
		_enter(S.MOVE)


func _parry_window() -> float:
	var p: Dictionary = _cfg["parry"]
	var w: float = p["shield_window"] if weapon.get("shield") is Dictionary else p["window"]
	w += float(weapon.get("parry_window_bonus", 0.0))
	if WorldState.has_burned(&"sabir_lesson"):
		w *= 0.5
	return w


func _defend(hit) -> String:
	if _state != S.BLOCK or not hit.blockable:
		return ""
	var from: Vector3 = -hit.direction(self)
	if from.dot(_facing) < 0.2:
		return ""  # hit from behind
	var since := (Time.get_ticks_msec() - _block_start_ms) / 1000.0
	if since <= _parry_window() and hit.parryable:
		_parry(hit)
		return "parried"
	var st: Dictionary = _cfg["stamina"]
	var factor: float = st["shield_block_cost_factor"] if weapon.get("shield") is Dictionary else st["block_cost_factor"]
	habits.record("block")
	if hit.guard_break:
		_drain_stamina(999.0)   # a guard-breaker empties the guard in one blow
		Fx.notify("Savunma kırıldı!")
	else:
		_drain_stamina(hit.damage * factor * 1.6)
	Audio.play("block", -2.0, 0.1)
	Fx.hit_spark(global_position + Vector3(0, 1.2, 0) + _facing * 0.5)
	velocity += hit.knock * 0.4
	if stamina <= 0.0:
		# Guard broken
		_model.play_action("Hit_B", 1.2, 0.05)
		_enter(S.HURT)
		Fx.shake(0.4)
		return ""
	_model.play_action("Block_Hit", 1.8, 0.03)
	return "blocked"


func _parry(hit) -> void:
	var p: Dictionary = _cfg["parry"]
	habits.record("parry")
	Audio.play("parry", 0.0, 0.05)
	Fx.hit_spark(global_position + Vector3(0, 1.3, 0) + _facing * 0.7, true)
	Fx.slowmo(p["slowmo_scale"], p["slowmo_time"])
	Fx.shake(0.3)
	_model.play_action("Block_Attack", 2.2, 0.03)
	if is_instance_valid(hit.attacker) and hit.attacker.has_method("on_parried"):
		hit.attacker.on_parried(p["stun_time"], p["stance_bonus"])
	gain_ember(4.0)


# --- Execution -------------------------------------------------------------------------------

func _try_execute() -> void:
	var best = null
	var best_d: float = _cfg["stance"]["execution_range"]
	for c in get_tree().get_nodes_in_group("combatants"):
		if c == self or c.dead or not is_hostile(c) or not c.has_method("is_executable") or not c.is_executable():
			continue
		var d: float = global_position.distance_to(c.global_position)
		if d < best_d:
			best_d = d
			best = c
	if best == null:
		return
	_exec_target = best
	var to: Vector3 = best.global_position - global_position
	to.y = 0.0
	_facing = to.normalized()
	_model.rotation.y = atan2(-_facing.x, -_facing.z)
	make_invulnerable(2.0)
	best.begin_execution(self)
	var e: Dictionary = weapon["execution"]
	_model.play_action(e["clip"], e["speed"], 0.05)
	Fx.punch(1.6)
	Audio.play("swing", -2.0, 0.05, null, 3)
	_impact_done = false
	_enter(S.EXECUTE)


func _do_execute(delta: float) -> void:
	_slow_to_stop(delta)
	var e: Dictionary = weapon["execution"]
	if not _impact_done and _state_t >= e["impact"]:
		_impact_done = true
		if is_instance_valid(_exec_target):
			var dmg: float = weapon["heavy"]["damage"] * _cfg["stance"]["execution_mult"]
			_exec_target.finish_execution(dmg, weapon["damage_type"])
		Audio.play("execute", 0.0, 0.05)
		Fx.hitstop(_cfg["hitstop"]["execution"])
		Fx.shake(0.8)
		Fx.punch(1.8)
		gain_ember(15.0)
	if _state_t >= e["cancel"]:
		_model.cancel_action()
		_enter(S.MOVE)


# --- Drinking --------------------------------------------------------------------------------

func _begin_drink() -> void:
	_heal_done = false
	_model.play_action("Use_Item", 1.0, 0.1)
	Audio.play("drink", -4.0, 0.05)
	_enter(S.DRINK)


func _do_drink(delta: float) -> void:
	_slow_to_stop(delta, 0.3)
	var f: Dictionary = _cfg["flask"]
	if not _heal_done and _state_t >= f["drink_time"] * 0.65:
		_heal_done = true
		flasks -= 1
		var frac: float = f["heal_fraction"]
		if WorldState.has_burned(&"mother_name"):
			frac = 0.3
		heal(max_health * frac)
		flasks_changed.emit(flasks, max_flasks)
		Fx.fire_nova(global_position, 1.2)
	if _state_t >= f["drink_time"]:
		_model.cancel_action()
		_enter(S.MOVE)


func refill_flasks() -> void:
	flasks = max_flasks
	flasks_changed.emit(flasks, max_flasks)


# --- Taking hits -----------------------------------------------------------------------------

func _on_hurt(hit, _amount: float) -> void:
	last_hurt_ms = Time.get_ticks_msec()
	last_noise_ms = last_hurt_ms
	_flash = 1.0
	Audio.play("player_hurt", -2.0, 0.08)
	Fx.shake(0.4)
	Fx.hitstop(0.05)
	velocity += hit.knock
	make_invulnerable(0.3)
	var armored: bool = _state == S.ATTACK and _attack.get("hyper_armor", false) and not _impact_done
	armored = armored or (_state == S.CHARGE)
	if not armored and _state not in [S.EXECUTE, S.CAST]:
		_end_attack()
		_model.play_action("Hit_A", 1.6, 0.05)
		_enter(S.HURT)
	_check_offer()


func _on_stance_broken(hit) -> void:
	_on_hurt(hit, 0.0)
	_end_attack()
	_model.play_action("Lie_Down", 1.6, 0.05, true)
	_enter(S.KNOCKDOWN)


func _do_hurt(delta: float) -> void:
	_slow_to_stop(delta, 0.4)
	if _state == S.HURT and _state_t > 0.35:
		_model.cancel_action()
		_enter(S.MOVE)
	elif _state == S.KNOCKDOWN:
		if _state_t > 0.9 and _state_t - delta <= 0.9:
			_model.play_action("Lie_StandUp", 1.8, 0.05)
		if _state_t > 1.6:
			_model.cancel_action()
			_enter(S.MOVE)


func _on_died(_hit) -> void:
	_end_attack()
	_set_lock(null)
	if radial != null and radial.is_open:
		radial.close()
		Fx.release_time("radial")
	_model.play_action("Death_A", 1.0, 0.1, true)
	_enter(S.DEAD)


# --- Stamina -----------------------------------------------------------------------------------

## Spends stamina if there is any; `force` lets a committed heavy blow dip to zero.
func _spend(cost: float, force := false) -> bool:
	if stamina <= 0.0 or (Time.get_ticks_msec() < _exhausted_until_ms and not force):
		return false
	if stamina < cost * 0.5 and not force:
		return false
	_drain_stamina(cost)
	return true


func _drain_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_stamina_last_use_ms = Time.get_ticks_msec()
	if stamina <= 0.0:
		_exhausted_until_ms = Time.get_ticks_msec() + int(_cfg["stamina"]["exhaust_time"] * 1000.0)
	stamina_changed.emit(stamina, max_stamina)


func _tick_stamina(delta: float) -> void:
	var st: Dictionary = _cfg["stamina"]
	if _state in [S.ATTACK, S.DODGE, S.CHARGE, S.SWIM] or _is_sprinting():
		return
	if Time.get_ticks_msec() - _stamina_last_use_ms < st["regen_delay"] * 1000.0:
		return
	var rate: float = st["regen"]
	if Time.get_ticks_msec() < _exhausted_until_ms:
		rate *= st["exhaust_regen_factor"]
	if _state == S.BLOCK:
		rate *= 0.4
	if stamina < max_stamina:
		stamina = minf(stamina + rate * delta, max_stamina)
		stamina_changed.emit(stamina, max_stamina)


func is_exhausted() -> bool:
	return Time.get_ticks_msec() < _exhausted_until_ms


func is_attacking() -> bool:
	return _state in [S.ATTACK, S.CHARGE]


func is_drinking() -> bool:
	return _state == S.DRINK


# --- Ember, Köz Zərbəsi, memory wheel (V2) ------------------------------------------------------

func gain_ember(amount: float) -> void:
	_last_ember_ms = Time.get_ticks_msec()
	ember = clampf(ember + amount, 0.0, _cfg["ember"]["max"])
	ember_changed.emit(ember, _cfg["ember"]["max"])


func on_enemy_killed() -> void:
	gain_ember(_cfg["ember"]["on_kill"])


func _tick_ember(delta: float) -> void:
	var e: Dictionary = _cfg["ember"]
	if ember > 0.0 and Time.get_ticks_msec() - _last_ember_ms > e["decay_delay"] * 1000.0:
		ember = maxf(ember - e["decay"] * delta, 0.0)
		ember_changed.emit(ember, e["max"])


func _ember_strike() -> void:
	var e: Dictionary = _cfg["ember"]
	if ember < e["strike_cost"]:
		Fx.notify("Köz yetmiyor...")
		return
	_end_attack()
	_strike_cd = e["strike_cooldown"]
	ember -= e["strike_cost"]
	ember_changed.emit(ember, e["max"])
	_aim_at_target()
	_model.play_action("Spellcast_Shoot", 2.2, 0.04)
	Fx.ember_cone(global_position, _facing, e["strike_range"])
	Fx.shake(0.3)
	Audio.play("nova", -8.0, 0.12)
	for t in Melee.targets(self, _facing, e["strike_range"], 120.0):
		var hit = Hit.new().setup(self, e["strike_damage"], "fire", e["strike_damage"] * 1.5, _facing * e["strike_knock"])
		t.receive_hit(hit)
	Fx.hitstop(0.05)
	_enter(S.STRIKE)


func _open_wheel() -> void:
	if _wave_cd > 0.0 or _state not in [S.MOVE, S.BLOCK, S.ATTACK]:
		_fire_down_ms = -1
		return
	if not Memory.can_burn():
		_fire_down_ms = -1
		_model.play_action("Spellcast_Raise", 2.8, 0.05)
		Audio.play("whisper", -2.0, 0.0)
		Fx.notify("...he he... hiçbir şey kalmadı, küçük şah...")
		return
	_end_attack()
	_enter(S.MOVE)
	radial.open()
	Fx.hold_time("radial", 0.2)


func _release_wheel() -> void:
	var id: String = radial.close()
	Fx.release_time("radial")
	if id == "":
		return
	if not WorldState.has_flag(&"wave_confirmed"):
		radial.ask_confirm()
		var ok: bool = await radial.confirmed
		if not ok:
			return
		WorldState.set_flag(&"wave_confirmed")
	cast_wave(id)


func cast_wave(memory_id: String) -> void:
	if dead or _state == S.CAST:
		return
	_wave_cd = _cfg["ember"]["wave_cooldown"]
	_cast_memory = memory_id
	make_invulnerable(0.5)
	_model.play_action("Spellcast_Raise", 2.8, 0.05)
	_impact_done = false
	_enter(S.CAST)


func _do_cast(delta: float) -> void:
	_slow_to_stop(delta)
	if not _impact_done and _state_t >= 0.26:
		_impact_done = true
		var e: Dictionary = _cfg["ember"]
		Memory.burn(_cast_memory)
		Fx.fire_nova(global_position, e["wave_radius"])
		Fx.shake(0.8)
		Fx.punch(1.0)
		Fx.hitstop(0.1)
		Audio.play("nova", 0.0, 0.04)
		Audio.play("memory_burn", -4.0, 0.0)
		for t in Melee.targets(self, _facing, e["wave_radius"], 360.0):
			var d: float = global_position.distance_to(t.global_position)
			var dmg: float = e["wave_damage"] * lerpf(1.0, e["wave_edge_falloff"], clampf(d / e["wave_radius"], 0.0, 1.0))
			var away: Vector3 = (t.global_position - global_position).normalized()
			var hit = Hit.new().setup(self, dmg, "fire", dmg * 2.0, away * 16.0)
			hit.heavy = true
			hit.blockable = false
			t.receive_hit(hit)
	if _state_t >= 0.5:
		_model.cancel_action()
		_enter(S.MOVE)


func _is_perfect_dodge() -> bool:
	var window: float = _cfg["dodge"]["perfect_window"]
	if WorldState.has_burned(&"sabir_lesson"):
		window *= 0.5
	for c in get_tree().get_nodes_in_group("combatants"):
		if c == self or c.dead or not is_hostile(c) or not c.has_method("time_to_strike"):
			continue
		if global_position.distance_to(c.global_position) > 5.0 + c.radius:
			continue
		if c.time_to_strike() <= window:
			return true
	return false


func _perfect_dodge() -> void:
	var d: Dictionary = _cfg["dodge"]
	Fx.slowmo(d["perfect_slowmo_scale"], d["perfect_slowmo_time"])
	Fx.ash_trail(global_position)
	gain_ember(d["perfect_ember"])
	Audio.play("perfect_dodge", -4.0, 0.05)
	Fx.notify("Kusursuz kaçış")


func begin_encounter() -> void:
	_offer_used = false


func _check_offer() -> void:
	if health > max_health * _cfg["ember"]["offer_health_fraction"] or dead:
		return
	if _offer_used or offer == null or offer.is_open or Memory.unburned().is_empty():
		return
	_offer_used = true
	offer.open()
	var accepted: bool = await offer.resolved
	if accepted and not dead:
		var m := Memory.burn_random()
		health = max_health
		health_changed.emit(health, max_health)
		Fx.fire_nova(global_position, 3.0)
		Audio.play("memory_burn", -2.0, 0.0)
		if m != null:
			Fx.notify("Kül Şahı «%s» hatırasını seçti." % tr(m.display_name_key))


func _refresh_burn_look() -> void:
	var n := Memory.burned_count()
	var t := float(n) / maxi(Memory.all().size(), 1)
	_ember_light.light_energy = 1.0 + n * 0.45
	_overlay.set_shader_parameter("intensity", t * 0.9)
	for m in _cloth:
		m.set_shader_parameter("ash", t * 0.6)


# --- Lock-on ---------------------------------------------------------------------------------

func _lock_valid() -> bool:
	return lock_target != null and is_instance_valid(lock_target) and not lock_target.dead \
		and global_position.distance_to(lock_target.global_position) < _cfg["camera"]["lock_range"] * 1.3


func _set_lock(t) -> void:
	lock_target = t
	lock_changed.emit(t)


func _toggle_lock() -> void:
	if _lock_valid():
		_set_lock(null)
		return
	_set_lock(_best_lock_target(null, 0))


func _switch_lock(dir: int) -> void:
	if not _lock_valid():
		return
	var next = _best_lock_target(lock_target, dir)
	if next != null:
		_set_lock(next)


## Picks the enemy nearest the screen centre (dir 0) or the next one to the right/left.
func _best_lock_target(current, dir: int):
	if rig == null:
		return null
	var cam_fwd: Vector3 = rig.flat_forward()
	var cam_right: Vector3 = rig.flat_right()
	var best = null
	var best_score := INF
	var cur_side := 0.0
	if current != null:
		cur_side = (current.global_position - global_position).normalized().dot(cam_right)
	for c in get_tree().get_nodes_in_group("combatants"):
		if c == self or c == current or c.dead or not is_hostile(c):
			continue
		var to: Vector3 = c.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > _cfg["camera"]["lock_range"]:
			continue
		var n := to.normalized()
		var side := n.dot(cam_right)
		if dir == 0:
			if n.dot(cam_fwd) < 0.2:
				continue
			var score := (1.0 - n.dot(cam_fwd)) * 10.0 + dist * 0.2
			if score < best_score:
				best_score = score
				best = c
		else:
			var delta_side := (side - cur_side) * dir
			if delta_side <= 0.02:
				continue
			if delta_side < best_score:
				best_score = delta_side
				best = c
	return best


# --- Helpers -----------------------------------------------------------------------------------

func _camera_relative(v: Vector2) -> Vector3:
	if v == Vector2.ZERO or rig == null:
		return Vector3.ZERO
	var m: Vector3 = rig.flat_right() * v.x - rig.flat_forward() * v.y
	return m.limit_length(1.0)


func _is_sprinting() -> bool:
	return _state == S.MOVE and Input.is_action_pressed("sprint") and _move_dir.length() > 0.3 \
		and stamina > 0.0 and not is_exhausted() and not input_locked


func _update_facing(delta: float) -> void:
	if _state in [S.DODGE, S.EXECUTE, S.KNOCKDOWN, S.DEAD]:
		pass
	elif _lock_valid() and not _is_sprinting():
		var to: Vector3 = lock_target.global_position - global_position
		to.y = 0.0
		if to.length() > 0.1:
			_facing = to.normalized()
	elif _state in [S.MOVE, S.AIR] and _move_dir.length() > 0.1:
		_facing = _move_dir.normalized()
	var turn: float = _cfg["player"]["turn_rate"] * (0.4 if _state == S.ATTACK and _state_t > 0.1 else 1.0)
	_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-_facing.x, -_facing.z), 1.0 - exp(-turn * delta))


func _aim_at_target() -> void:
	if _lock_valid():
		var to: Vector3 = lock_target.global_position - global_position
		to.y = 0.0
		_facing = to.normalized()
	elif _move_dir.length() > 0.2:
		_facing = _move_dir.normalized()
	else:
		# Soft assist toward the nearest enemy in front
		var best: Vector3 = _facing
		var best_dot := 0.5
		for c in get_tree().get_nodes_in_group("combatants"):
			if c == self or c.dead or not is_hostile(c):
				continue
			var to: Vector3 = c.global_position - global_position
			to.y = 0.0
			if to.length() > 4.5:
				continue
			var d := to.normalized().dot(_facing)
			if d > best_dot:
				best_dot = d
				best = to.normalized()
		_facing = best
	_model.rotation.y = atan2(-_facing.x, -_facing.z)


func _locomotion_anim(speed: float, sprint: bool) -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.4
	var loco: Dictionary = weapon.get("locomotion", {"idle": "Idle", "run": "Running_A"})
	if not moving:
		_model.play_loop(loco["idle"])
		return
	if _lock_valid() and not sprint:
		var local_f := _move_dir.dot(_facing)
		var local_r := _move_dir.dot(-_facing.cross(Vector3.UP))
		if local_f < -0.4:
			_model.play_loop("Walking_Backwards", 1.2)
		elif absf(local_r) > 0.6:
			_model.play_loop("Running_Strafe_Right" if local_r > 0.0 else "Running_Strafe_Left", 1.0)
		else:
			_model.play_loop(loco["run"], speed / 6.0)
		return
	if speed <= _cfg["player"]["walk_speed"] + 0.1:
		_model.play_loop("Walking_A", 1.0)
	else:
		_model.play_loop(loco["run"], 1.35 if sprint else speed / 6.0)


func _slow_to_stop(delta: float, keep := 0.0) -> void:
	velocity.x = move_toward(velocity.x, _move_dir.x * keep, 40.0 * delta)
	velocity.z = move_toward(velocity.z, _move_dir.z * keep, 40.0 * delta)


func _enemies_near(dist: float) -> bool:
	for c in get_tree().get_nodes_in_group("combatants"):
		if c != self and not c.dead and is_hostile(c) and global_position.distance_to(c.global_position) < dist + c.radius:
			return true
	return false


func _footsteps(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.6 or not is_on_floor():
		_step_dist = 0.0
		return
	_step_dist += speed * delta
	if _step_dist > 1.7:
		_step_dist = 0.0
		Audio.play("footstep", -15.0, 0.15, null, 3)


# --- Open-world movement: swim, slide, fall, vault -----------------------------------------------

func _check_water() -> void:
	if not water_query.is_valid() or dead or _move_cfg.is_empty():
		return
	_water_level = water_query.call(global_position)
	var depth: float = _move_cfg["swim_depth"]
	if _state != S.SWIM:
		if _water_level > -999.0 and global_position.y < _water_level - depth and _state in [S.MOVE, S.AIR, S.DODGE, S.SLIDE, S.HURT]:
			_end_attack()
			_model.cancel_action()
			_fall_from = NAN
			velocity.y *= 0.2
			Audio.play("splash", -4.0, 0.1)
			_enter(S.SWIM)


func _do_swim(delta: float) -> void:
	var m := _move_cfg
	var depth: float = m["swim_depth"]
	if _water_level < -999.0 or (is_on_floor() and global_position.y > _water_level - depth + 0.3):
		_model.position.y = 0.0
		_enter(S.MOVE)
		return
	var fast: bool = Input.is_action_pressed("sprint") and stamina > 0.0 and not input_locked
	var speed: float = m["swim_sprint_speed"] if fast else m["swim_speed"]
	var want := _move_dir * speed
	velocity.x = move_toward(velocity.x, want.x, 10.0 * delta)
	velocity.z = move_toward(velocity.z, want.z, 10.0 * delta)
	velocity.y = clampf((_water_level - depth - global_position.y) * 5.0, -3.0, 3.0)
	# Swimming always tires; out of stamina the water takes health
	_drain_stamina(float(m["swim_stamina"]) * (2.0 if fast else 1.0) * delta)
	if stamina <= 0.0:
		health = maxf(health - max_health * float(m["drown_damage_fraction"]) * delta, 0.0)
		health_changed.emit(health, max_health)
		_flash = maxf(_flash, 0.3)
		if health <= 0.0 and not dead:
			dead = true
			_on_died(null)
			died.emit()
			return
	_model.position.y = lerpf(_model.position.y, -0.55, 1.0 - exp(-6.0 * delta))
	var moving := _move_dir.length() > 0.1
	_model.play_loop("Running_A" if moving else "Idle", 0.55 if moving else 0.6)
	_step_dist += Vector2(velocity.x, velocity.z).length() * delta
	if _step_dist > 2.2:
		_step_dist = 0.0
		Audio.play("swim_stroke", -12.0, 0.15)


func _check_slope() -> void:
	if not is_on_floor() or _state != S.MOVE:
		return
	var angle := rad_to_deg(get_floor_normal().angle_to(Vector3.UP))
	if angle > float(_move_cfg["slide_angle"]):
		_slide_t = 0.0
		_enter(S.SLIDE)


func _do_slide(delta: float) -> void:
	var n := get_floor_normal() if is_on_floor() else Vector3.UP
	var angle := rad_to_deg(n.angle_to(Vector3.UP))
	var down := Vector3(n.x, 0.0, n.z)
	if down.length() > 0.01:
		down = down.normalized()
		velocity.x = move_toward(velocity.x, down.x * 9.0 + _move_dir.x * 1.5, float(_move_cfg["slide_accel"]) * delta)
		velocity.z = move_toward(velocity.z, down.z * 9.0 + _move_dir.z * 1.5, float(_move_cfg["slide_accel"]) * delta)
		_facing = down
	_model.play_loop("Jump_Idle", 1.0)
	_slide_t = _slide_t + delta if angle < float(_move_cfg["slide_angle"]) - 4.0 or not is_on_floor() else 0.0
	if _slide_t > 0.18:
		_enter(S.MOVE if is_on_floor() else S.AIR)


## Falls above fall_safe hurt; fall_lethal and more kill.
func _check_fall() -> void:
	if _move_cfg.is_empty() or dead:
		return
	if _state == S.SWIM:
		_fall_from = NAN
		return
	if not is_on_floor():
		if is_nan(_fall_from) or global_position.y > _fall_from:
			_fall_from = global_position.y
		return
	if is_nan(_fall_from):
		return
	var fall := _fall_from - global_position.y
	_fall_from = NAN
	var safe: float = _move_cfg["fall_safe"]
	var lethal: float = _move_cfg["fall_lethal"]
	if fall <= safe:
		return
	var dmg := max_health * clampf((fall - safe) / (lethal - safe), 0.0, 1.0)
	if fall >= lethal:
		dmg = health + 1.0
	var hit = Hit.new().setup(null, dmg, "crush", 0.0, Vector3.ZERO)
	hit.blockable = false
	invulnerable_until = 0
	receive_hit(hit)
	Fx.shake(0.5)


## A low wall or fence ahead while running: hop over it.
func _try_vault() -> void:
	if _move_dir.length() < 0.5 or not is_on_floor():
		return
	var space := get_world_3d().direct_space_state
	var fwd := _move_dir.normalized()
	var base := global_position
	var low := PhysicsRayQueryParameters3D.create(base + Vector3(0, 0.45, 0), base + Vector3(0, 0.45, 0) + fwd * 0.75, 1, [get_rid()])
	if space.intersect_ray(low).is_empty():
		return
	var top_h: float = _move_cfg["vault_height"]
	var high := PhysicsRayQueryParameters3D.create(base + Vector3(0, top_h + 0.25, 0), base + Vector3(0, top_h + 0.25, 0) + fwd * 1.1, 1, [get_rid()])
	if not space.intersect_ray(high).is_empty():
		return
	var probe := base + fwd * 1.05 + Vector3(0, top_h + 0.3, 0)
	var down := PhysicsRayQueryParameters3D.create(probe, probe - Vector3(0, top_h + 0.6, 0), 1, [get_rid()])
	var hit := space.intersect_ray(down)
	if hit.is_empty():
		return
	var rise: float = hit["position"].y - base.y
	if rise < 0.35 or rise > top_h:
		return
	_vault_from = base
	_vault_to = hit["position"] + fwd * 0.9
	_model.play_action("Jump_Start", 1.8, 0.05)
	Audio.play("dash", -10.0, 0.1)
	_enter(S.VAULT)


func _do_vault(_delta: float) -> void:
	var t := clampf(_state_t / 0.34, 0.0, 1.0)
	var p := _vault_from.lerp(_vault_to, t)
	p.y += sin(t * PI) * 0.55
	global_position = p
	velocity = Vector3.ZERO
	if t >= 1.0:
		_model.cancel_action()
		_fall_from = NAN
		_enter(S.MOVE)


func is_swimming() -> bool:
	return _state == S.SWIM


## Heard up to hear_sprint metres away.
func is_sprinting_now() -> bool:
	return _is_sprinting()


func is_down() -> bool:
	return _state in [S.KNOCKDOWN, S.DEAD]


func is_blocking() -> bool:
	return _state == S.BLOCK


## Keeping his distance while enemies are after him counts as a habit, once a second.
func _sample_distance_habit(delta: float) -> void:
	_habit_t -= delta
	if _habit_t > 0.0:
		return
	_habit_t = 1.0
	var nearest := INF
	var engaged := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("is_engaged") and e.is_engaged():
			engaged = true
			nearest = minf(nearest, global_position.distance_to(e.global_position))
	if engaged and nearest > 6.0 and nearest < 30.0:
		habits.record("distance")


func _update_burn_fx() -> void:
	var burning := has_status("burn")
	if burning and _burn_fx == null:
		_burn_fx = Effects.fire(0.6, 14)
		_burn_fx.position = Vector3(0, 0.9, 0)
		add_child(_burn_fx)
	elif not burning and _burn_fx != null:
		_burn_fx.queue_free()
		_burn_fx = null
	if burning:
		_flash = maxf(_flash, 0.25)


# --- Attack tokens (budget others draw from) -------------------------------------------------------

func request_token(cost: int) -> bool:
	if _tokens_used + cost > token_budget:
		return false
	_tokens_used += cost
	return true


func release_token(cost: int) -> void:
	_tokens_used = maxi(_tokens_used - cost, 0)


## Where Ayxan is facing (enemies use it to flank).
func facing() -> Vector3:
	return _facing


## Compatibility with the chapter scaffolding (hearths, dialogue).
func face_towards(point: Vector3) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length() > 0.01:
		_facing = d.normalized()
		_model.rotation.y = atan2(-_facing.x, -_facing.z)


func lie_down() -> void:
	input_locked = true
	_model.play_action("Lie_Idle", 1.0, 0.0, true)


func wake() -> void:
	_model.cancel_action()
	input_locked = false


func stand_up() -> void:
	_model.play_action("Lie_StandUp", 1.3, 0.1)
	await get_tree().create_timer(1.4).timeout
	_model.cancel_action()
	input_locked = false
