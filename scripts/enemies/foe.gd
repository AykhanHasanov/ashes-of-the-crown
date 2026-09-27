extends "res://scripts/combat/combatant.gd"
## A data-driven enemy (data/enemies/*.json) with a utility AI (spec V3 §4).
##
## Every 0.2–0.4 s the brain scores everything it could do — each attack in range and
## off cooldown, block, dodge, approach, circle, flank, hold the front line (tanks),
## keep range or seek high ground (archers), stay behind the line (shamans), fall
## back, break and run or surrender (bandit morale) — and commits to the best.
## Melee attacks need tokens from Ayxan's budget (normal 1, elite 2, boss 3); archers
## and bombers fire without one. Attacks telegraph with a ground ring (white = can't be
## interrupted, red = can't be parried).
##
## Special attack kinds: ranged (projectile), explode, slam (ground AoE), pounce (long
## leap), resurrect (a shaman raises a fallen shade once), ward (shields allies), buff
## (an ataman's war cry). Feints fake the swing and start again.
##
## Perception (scripts/enemies/perception.gd): calm → suspicious (?) → combat (!) →
## search; beasts growl a warning first. Elites and bosses adapt: they weight the
## counter to Ayxan's most used defence (dodge, block, parry, distance). Affixes
## (scripts/enemies/affixes.gd) and boss phases change stats and behaviour. AI LOD:
## full within 40 m, one decision a second and coarse animation to 120 m, frozen beyond.

signal killed(foe: Node)
signal summon_requested(enemy_id: String, pos: Vector3, enemy_level: int, opts: Dictionary)
signal engaged(foe: Node)

const CharacterModel := preload("res://scripts/characters/character_model.gd")
const Human := preload("res://scripts/characters/human.gd")
const Effects := preload("res://scripts/world/effects.gd")
const Melee := preload("res://scripts/combat/melee.gd")
const Perception := preload("res://scripts/enemies/perception.gd")
const Affixes := preload("res://scripts/enemies/affixes.gd")
const Projectile := preload("res://scripts/combat/projectile.gd")
const Aoe := preload("res://scripts/combat/aoe.gd")
const OVERLAY := preload("res://shaders/ash_overlay.gdshader")
const HP_BAR := preload("res://shaders/hp_bar.gdshader")

enum S { SPAWN, THINK_MOVE, WINDUP, STRIKE, RECOVER, BLOCK, HURT, STUNNED, BROKEN, EXECUTED, DEAD, DODGE, SURRENDER, FLEE, WARN }
enum LOD { FULL, MID, FROZEN }

## Fallen ash soldiers a shaman may raise: {id, pos, level, time}.
static var corpses: Array = []

var data: Dictionary = {}
var target            # usually Ayxan
var level := 1
var tier := "normal"
var role := "melee"
var affixes: Array = []
var risen := false

# Open world
var home := Vector3.ZERO
var aggro_range := 0.0       # 0 = always hunting (arena); >0 = perception on
var leash := 42.0
var aggro := true
var spawn_key := ""
var ground_query := Callable()
var world_visibility := Callable()
var perception
var surrendered := false
var voice := ""              # Barks profile (tools/gen_voices.py)
var _idle_bark_t := 0.0
var lod := LOD.FULL

# For the F4 overlay
var last_scores := {}
var adaptive_weights := {}

var _ai: Dictionary
var _cfg: Dictionary
var _state := S.SPAWN
var _t := 0.0
var _think_t := 0.0
var _perceive_dt := 0.0
var _action := "approach"
var _attack: Dictionary = {}
var _hit_done := false
var _feinted := false
var _cooldowns := {}
var _has_token := false
var _token_cost := 1
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
var _name_label: Label3D
var _icon: Label3D
var _icon_t := 0.0
var _speed := 3.0
var _run_speed := 4.0
var _atk_speed := 1.0
var _dmg_scale := 1.0
var _body_scale := 1.0
var _knock := Vector3.ZERO
var _flash := 0.0
var _shape: CollisionShape3D
var _executor = null
var _returning := false
var _vy := 0.0
var _stun_time := 1.2
var _engaged_once := false
var _help_t := 0.0
var _morale_checked := false
var _leader_lost := false
var _resurrects_left := 1
var _summoned := false
var _unshakable_used := false
var _trail_t := 0.0
var _phase := 0
var _attacks_done := 0
var _stealthed := false
var _stealth_t := 0.0
var _flee_t := 0.0
var _lod_t := 0.0
var _anim_acc := 0.0
var _high_spot := Vector3.ZERO
var _high_t := 0.0
var _rng := RandomNumberGenerator.new()


# --- Setup ---------------------------------------------------------------------------------

## opts: "affixes" (Array, skips the roll), "roll" (bool), "night" (bool), "risen" (bool)
func configure(id: String, enemy_level := 1, opts := {}) -> void:
	_ai = DataDB.balance("ai")
	data = DataDB.enemy(id)
	level = enemy_level
	tier = data.get("tier", "normal")
	role = data.get("role", "melee")
	risen = opts.get("risen", false)
	_rng.randomize()
	var st: Dictionary = data["stats"]
	var lv: Dictionary = _ai["levels"]
	max_health = float(st["health"]) * (1.0 + float(lv["hp_per_level"]) * (level - 1))
	_dmg_scale = 1.0 + float(lv["dmg_per_level"]) * (level - 1)
	max_stance = st["stance"]
	radius = st["radius"]
	_speed = st["speed"]
	_run_speed = st["run_speed"]
	faction = data["faction"]
	resist = data["resist"].duplicate()
	_token_cost = int(_ai["tokens"].get(tier, 1))
	# Ash grows stronger at night
	if opts.get("night", false) and _ai["factions"].has(faction) and _ai["factions"][faction].has("night_bonus"):
		var nb: float = _ai["factions"][faction]["night_bonus"]
		max_health *= 1.0 + nb
		_dmg_scale *= 1.0 + nb
	affixes = opts["affixes"] if opts.has("affixes") else (Affixes.roll(tier, _rng) if opts.get("roll", true) else [])
	for id_a in affixes:
		var d := Affixes.def(id_a)
		match id_a:
			"thick":
				max_health *= float(d["health"])
				max_stance *= float(d["stance"])
				_body_scale = float(d["scale"])
			"fast":
				_speed *= float(d["speed"])
				_run_speed *= float(d["speed"])
				_atk_speed = float(d["attack_speed"])
	health = max_health
	display_name = Affixes.full_name(data["name"], affixes)
	voice = Barks.voice_for(id, _rng.randi())
	_idle_bark_t = _rng.randf_range(8.0, 30.0)


func _ready() -> void:
	_cfg = DataDB.balance("combat")
	if _ai.is_empty():
		_ai = DataDB.balance("ai")
	add_to_group("combatants")
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 5
	_orbit = 1.0 if randf() < 0.5 else -1.0
	_flank_side = _orbit
	var st: Dictionary = data["stats"]
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius * _body_scale
	cap.height = maxf(float(st["height"]) * _body_scale, cap.radius * 2.0 + 0.1)
	_shape.shape = cap
	_shape.position.y = cap.height * 0.5
	if data["model"].has("length"):
		# Quadruped: a capsule lying along the body
		_shape.rotation.x = PI * 0.5
		cap.height = float(data["model"]["length"]) * 0.85
		_shape.position.y = float(st["height"]) * 0.5
	add_child(_shape)
	_build_model()
	_build_telegraph()
	_build_bar()
	_build_labels()
	if aggro_range > 0.0:
		aggro = false
		if home == Vector3.ZERO:
			home = global_position
		perception = Perception.new(self, _ai["perception"])
		perception.visibility = world_visibility
		perception.always_sees = affixes.has("ash_eye")
	if aggro_range <= 0.0:
		# The arena: hunting from the first frame
		_engaged_once = true
		engaged.emit.call_deferred(self)
	var spawn: String = data["anims"].get("spawn", "")
	if spawn != "":
		_model.play_action(spawn, 2.4, 0.0)
		_enter(S.SPAWN)
		_t = -1.4
	else:
		_enter(S.THINK_MOVE)


func _build_model() -> void:
	var m: Dictionary = data["model"]
	if m.has("human"):
		# Realistic human (V3 realism): look, outfit and colours come from data/looks.json
		_model = Human.build(Human.spec_from_json(m["human"], _rng))
		add_child(_model)
	else:
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
	for w in m.get("weapons", []):
		var item: Node3D
		if w.has("donor"):
			item = _model.borrow(w["donor"], w["node"], w.get("bone", "handslot.r"))
		else:
			var rot: Array = w.get("rotation", [0, 0, 0])
			if _model is Human:
				item = _model.attach(w["path"], w.get("bone", "handslot.r"), Vector3(rot[0], rot[1], rot[2]), w.get("shield", false))
			else:
				item = _model.attach(w["path"], w.get("bone", "handslot.r"), Vector3(rot[0], rot[1], rot[2]))
			if w.has("length"):
				CharacterModel.fit_item(item, float(w["length"]))
		if item != null and w.has("scale"):
			item.scale *= float(w["scale"])
	_model.scale = Vector3.ONE * _body_scale
	_overlay = ShaderMaterial.new()
	_overlay.shader = OVERLAY
	var intensity: float = m.get("ash_overlay", 0.0)
	if not affixes.is_empty():
		intensity = maxf(intensity, 0.45)
		_overlay.set_shader_parameter("ember_color", Affixes.color(affixes))
	_overlay.set_shader_parameter("intensity", intensity)
	_overlay.set_shader_parameter("flash_color", Color(1.0, 0.7, 0.45))
	_model.set_overlay(_overlay)
	if m.get("spots", false):
		var spots := ShaderMaterial.new()
		spots.shader = preload("res://shaders/spots.gdshader")
		var mesh_size := 1.0
		for mi: MeshInstance3D in _model.scene.find_children("*", "MeshInstance3D", true, false):
			mesh_size = maxf(mi.get_aabb().size.x, maxf(mi.get_aabb().size.y, mi.get_aabb().size.z))
		spots.set_shader_parameter("scale", 16.0 / maxf(mesh_size, 0.0001))
		_overlay.next_pass = spots
	if m.get("glow_eyes", false) or affixes.has("ash_eye"):
		var glow := StandardMaterial3D.new()
		var eye := Color(1.0, 0.2, 0.05) if affixes.has("ash_eye") else Color(1.0, 0.45, 0.1)
		glow.albedo_color = eye
		glow.emission_enabled = true
		glow.emission = eye
		glow.emission_energy_multiplier = 8.0
		for mi in _model.scene.find_children("*Eyes*", "MeshInstance3D", true, false):
			mi.material_override = glow
			mi.material_overlay = null
	if m.get("ember_core", false):
		var core := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.22
		sph.height = 0.44
		core.mesh = sph
		core.material_override = Effects.additive_material(Color(1.0, 0.45, 0.1, 1.0))
		core.position = Vector3(0, 1.0, -0.1)
		add_child(core)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.45, 0.15)
		l.light_energy = 1.4
		l.omni_range = 4.0
		l.position = core.position
		add_child(l)
	if affixes.has("flaming"):
		var f := Effects.ember_field(Vector3(0.4, 0.8, 0.4), 12)
		f.position = Vector3(0, 1.0, 0)
		add_child(f)
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
	quad.size = Vector2(1.1, 0.19) * (1.4 if tier != "normal" else 1.0)
	_bar.mesh = quad
	_bar_mat = ShaderMaterial.new()
	_bar_mat.shader = HP_BAR
	_bar_mat.set_shader_parameter("with_stance", true)
	_bar.material_override = _bar_mat
	_bar.position.y = float(data["stats"]["height"]) * _body_scale + 0.45
	_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.visible = false
	add_child(_bar)


## Name plate for elites, bosses, affixed and dangerous (skull) enemies; state icon.
func _build_labels() -> void:
	var top: float = float(data["stats"]["height"]) * _body_scale
	var skull := is_deadly()
	if tier != "normal" or not affixes.is_empty() or skull:
		_name_label = Label3D.new()
		_name_label.text = display_name + ("  ☠" if skull else "")
		_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_name_label.font_size = 40
		_name_label.pixel_size = 0.005
		_name_label.outline_size = 10
		_name_label.modulate = Affixes.color(affixes) if not affixes.is_empty() else (Color(1.0, 0.6, 0.35) if tier != "normal" else Color(0.95, 0.9, 0.85))
		_name_label.position.y = top + 0.8
		_name_label.visible = tier != "boss"
		add_child(_name_label)
	_icon = Label3D.new()
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.font_size = 96
	_icon.pixel_size = 0.006
	_icon.outline_size = 16
	_icon.position.y = top + (1.25 if _name_label else 0.9)
	_icon.visible = false
	add_child(_icon)


func _enter(s: int) -> void:
	_state = s
	_t = 0.0


## Where the enemy faces (its model's -Z).
func forward() -> Vector3:
	return -_model.global_basis.z


func body_scale() -> float:
	return float(data["stats"]["height"]) * _body_scale / 1.8


## Level 5+ above Ayxan: a skull by the name.
func is_deadly() -> bool:
	var pl: int = int(target.get("level")) if target != null and target.get("level") != null else int(_ai["levels"]["player_level"])
	return level >= pl + int(_ai["levels"]["skull_gap"])


## XP for Faza D: base × L × clamp(1 + 0.1 (L − L_player), 0.2, 2), doubled by affixes.
func xp_value(player_level: int) -> float:
	var base: float = data.get("xp", 10)
	var xp := base * level * clampf(1.0 + 0.1 * (level - player_level), 0.2, 2.0)
	return xp * (float(DataDB.balance("affixes")["xp_mult"]) if not affixes.is_empty() else 1.0)


# --- Loop ----------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_lod_t -= delta
	if _lod_t <= 0.0:
		_lod_t = 0.5
		_update_lod()
	if lod == LOD.FROZEN and _state != S.DEAD:
		return
	if lod == LOD.MID:
		_anim_acc += delta
		if _anim_acc >= 0.1:
			_model.anim.advance(_anim_acc)
			_anim_acc = 0.0
	_t += delta
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_overlay.set_shader_parameter("hit_flash", _flash * 0.5)
	_knock = _knock.move_toward(Vector3.ZERO, 30.0 * delta)
	for k in _cooldowns:
		_cooldowns[k] -= delta
	if _state not in [S.BROKEN, S.EXECUTED, S.DEAD]:
		tick_stance(delta)
		tick_statuses(delta)
		if dead:
			return
	_update_bar(delta)
	_update_icon(delta)
	_tick_affixes(delta)
	_tick_stealth(delta)
	_help_t -= delta
	if not aggro and not dead and not surrendered:
		_idle_bark_t -= delta
		if _idle_bark_t <= 0.0:
			_idle_bark_t = randf_range(18.0, 40.0)
			if _target_ok() and global_position.distance_to(target.global_position) < 35.0:
				bark("idle", 0.7)
	var move := Vector3.ZERO
	var to := _to_target()
	var dist := to.length()

	match _state:
		S.SPAWN:
			if _t >= 0.0:
				_model.cancel_action()
				_enter(S.THINK_MOVE)
		S.THINK_MOVE:
			if perception != null:
				_perceive_dt += delta
				if _perceive_dt >= (0.25 if lod == LOD.FULL else 1.0):
					_perceive(_perceive_dt)
					_perceive_dt = 0.0
			if not aggro:
				move = _calm_behaviour(dist, delta)
			else:
				_think_t -= delta
				if _think_t <= 0.0:
					var th: Array = _ai["think"]["full"]
					_think_t = randf_range(th[0], th[1]) if lod == LOD.FULL else float(_ai["think"]["mid"])
					_think(to, dist)
					_check_leash(dist)
				move = _steer(to, dist)
				var look: Vector3 = to if dist > 0.1 else forward()
				if _action == "flee":
					look = -to
				_face(look, delta, 9.0)
		S.WINDUP:
			if _attack.get("kind", "melee") not in ["ward", "buff", "resurrect"]:
				_face(to, delta, 5.0)
			_update_ring()
			var windup := float(_attack["windup"]) / _atk_speed
			if _attack.get("feint", false) and not _feinted and _t > windup * 0.55:
				_try_feint(windup)
			elif _t >= windup:
				_ring.visible = false
				_enter(S.STRIKE)
				_on_strike_start()
		S.STRIKE:
			move = _do_strike(delta)
		S.RECOVER:
			if _t >= float(_attack.get("recovery", 0.5)) / _atk_speed:
				_release_token()
				_enter(S.THINK_MOVE)
		S.BLOCK:
			_face(to, delta, 8.0)
			if _t >= 0.9:
				_model.cancel_action()
				_enter(S.THINK_MOVE)
		S.DODGE:
			var away: Vector3 = -to.normalized() if dist > 0.1 else -forward()
			move = (away + Vector3(-away.z, 0, away.x) * _orbit * 0.6).normalized() * 9.0 * clampf(1.0 - _t / 0.4, 0.2, 1.0)
			if _t >= 0.4:
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
		S.FLEE:
			var away: Vector3 = -to.normalized() if dist > 0.1 else forward()
			move = away * _run_speed
			_face(away, delta, 8.0)
			_model.play_loop(data["anims"]["run"], 1.1)
			if _t > 7.0 or dist > 45.0:
				_vanish()
		S.WARN:
			_face(to, delta, 6.0)
			_update_warn(dist)
		S.SURRENDER, S.EXECUTED, S.DEAD:
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


func _update_lod() -> void:
	if not _target_ok():
		return
	var d: float = global_position.distance_to(target.global_position)
	var lods: Dictionary = _ai["lod"]
	var want := LOD.FULL if d < float(lods["full"]) else (LOD.MID if d < float(lods["mid"]) else LOD.FROZEN)
	if aggro and want == LOD.FROZEN:
		want = LOD.MID   # an enemy in a fight never freezes
	if want == lod:
		return
	lod = want
	if lod == LOD.FULL:
		_model.anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	else:
		_model.anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_anim_acc = 0.0


# --- Perception and calm behaviour ---------------------------------------------------------

func _perceive(dt: float) -> void:
	var before: int = perception.state
	perception.update(dt)
	var now: int = perception.state
	if now == Perception.COMBAT and not aggro:
		var d: float = global_position.distance_to(target.global_position) if _target_ok() else 0.0
		if data["behavior"].get("territorial", false) and not _engaged_once and d > float(_ai["territorial"]["attack_range"]):
			# Beasts only warn inside their territory; beyond it they just watch
			if d <= float(_ai["territorial"]["warn_range"]):
				_begin_warn()
		else:
			_set_aggro(true)
	elif now != Perception.COMBAT and aggro:
		aggro = false
		_release_token()
		_ring.visible = false
	if now != before:
		if now == Perception.SUSPICIOUS:
			bark("suspicious", 0.8)
		elif now == Perception.SEARCH:
			bark("search", 0.9)
		elif now == Perception.CALM and before == Perception.SEARCH:
			bark("give_up", 0.8)
		if now in [Perception.SUSPICIOUS, Perception.SEARCH]:
			_show_icon("?", Color(1.0, 0.85, 0.2))
		elif now == Perception.CALM:
			_icon.visible = false
			_returning = global_position.distance_to(home) > 2.0


func _set_aggro(on: bool) -> void:
	aggro = on
	if not on:
		return
	_returning = false
	_show_icon("!", Color(1.0, 0.2, 0.1), 1.5)
	if not _engaged_once:
		_engaged_once = true
		engaged.emit(self)
		if data["behavior"].get("leader", false) or _allies_near(20.0) > 1 and randf() < 0.4:
			bark("call_help") or bark("spot")
		else:
			bark("spot")
		_call_help()


## "Kömək çağırmaq": wakes allies of the same faction within earshot.
func _call_help() -> void:
	if _help_t > 0.0:
		return
	_help_t = float(_ai["group"]["help_cooldown"])
	var r: float = _ai["group"]["call_help_radius"]
	for other in get_tree().get_nodes_in_group("enemies"):
		if other != self and other.has_method("alarm") and other.faction == faction \
				and other.global_position.distance_to(global_position) < r:
			other.alarm(target.global_position if _target_ok() else global_position)


## Someone called for help or this enemy got hurt: straight into the fight.
func alarm(at: Vector3) -> void:
	if dead or surrendered:
		return
	if perception != null:
		perception.alarm(at)
	if not aggro:
		if _state == S.WARN:
			_model.cancel_action()
			_enter(S.THINK_MOVE)
		_set_aggro(true)


## Kept for callers from Faza B (packmates alert each other when one is hurt).
func _alert() -> void:
	if not aggro and _target_ok():
		alarm(target.global_position)


func _calm_behaviour(dist: float, delta: float) -> Vector3:
	if perception != null:
		match perception.state:
			Perception.SUSPICIOUS:
				var to_seen: Vector3 = perception.last_known - global_position
				to_seen.y = 0.0
				_face(to_seen, delta, 4.0)
				return to_seen.normalized() * _speed * 0.45 if to_seen.length() > 4.0 else Vector3.ZERO
			Perception.SEARCH:
				var to_last: Vector3 = perception.last_known - global_position
				to_last.y = 0.0
				if to_last.length() > 1.5:
					_face(to_last, delta, 6.0)
					return to_last.normalized() * _speed * 0.8
				_model.rotation.y += delta * 1.2   # looking around
				return Vector3.ZERO
	elif _target_ok() and dist < aggro_range and not _returning:
		alarm(target.global_position)
		return Vector3.ZERO
	var to_home := home - global_position
	to_home.y = 0.0
	if to_home.length() > 1.5 and (_returning or to_home.length() > 4.0):
		_face(to_home, delta, 6.0)
		return to_home.normalized() * (_run_speed if _returning else _speed * 0.6)
	if _returning:
		_returning = false
		health = max_health
		stance = 0.0
		health_changed.emit(health, max_health)
		_bar.visible = false
	return Vector3.ZERO


func _check_leash(dist: float) -> void:
	if aggro_range <= 0.0 or affixes.has("ash_eye") or tier == "boss":
		return
	var from_home := global_position.distance_to(home)
	if from_home > leash or (_target_ok() and dist > maxf(aggro_range, 25.0) * 2.0):
		aggro = false
		_returning = true
		_release_token()
		_ring.visible = false
		if perception != null:
			perception.state = Perception.CALM
			perception.awareness = 0.0
		_icon.visible = false


func is_engaged() -> bool:
	return aggro and not dead and not surrendered


# --- Territorial warning (beasts) ----------------------------------------------------------

func _begin_warn() -> void:
	_show_icon("!", Color(1.0, 0.6, 0.1), 2.5)
	bark("warn")
	var clip: String = data["anims"].get("warn", "")
	if clip != "":
		_model.play_loop(clip)
	Audio.play("shade_windup", -8.0, 0.2, global_position)
	_enter(S.WARN)


func _update_warn(dist: float) -> void:
	var tcfg: Dictionary = _ai["territorial"]
	if dist < float(tcfg["attack_range"]) or (_t > float(tcfg["warn_time"]) and dist < float(tcfg["warn_range"])):
		_enter(S.THINK_MOVE)
		_set_aggro(true)
	elif dist > float(tcfg["warn_range"]) + 3.0:
		# He backed off: the pack lets him go
		_enter(S.THINK_MOVE)
		if perception != null:
			perception.state = Perception.CALM
			perception.awareness = 0.0
		_icon.visible = false


# --- Utility AI -------------------------------------------------------------------------------

func _think(to: Vector3, dist: float) -> void:
	if not _target_ok():
		_action = "idle"
		return
	var b: Dictionary = data["behavior"]
	var scores := {}
	var t_attacking: bool = target.has_method("is_attacking") and target.is_attacking()
	var t_weak: bool = (target.has_method("is_drinking") and target.is_drinking()) or (target.has_method("is_exhausted") and target.is_exhausted())
	var t_down: bool = target.has_method("is_down") and target.is_down()
	var t_blocking: bool = target.has_method("is_blocking") and target.is_blocking()
	var punish: float = float(_ai["punish"]) if t_weak and float(b["aggression"]) >= 1.0 else 1.0
	if t_weak or target.health < target.max_health * 0.3:
		bark("taunt", 0.12)
	_update_adaptive()
	var allies := _allies_near(14.0)

	# Attacks in range and off cooldown
	for a in data["attacks"]:
		var id: String = a["id"]
		if _cooldowns.get(id, 0.0) > 0.0:
			continue
		var kind: String = a.get("kind", "melee")
		if not _special_ready(a):
			continue
		var self_centred: bool = kind in ["ward", "buff", "resurrect"]   # range is to allies/corpses, checked above
		var reach: float = float(a["range"]) + (0.0 if kind == "ranged" else radius + target.radius)
		if not self_centred and (dist > reach or dist < float(a.get("min_range", 0.0))):
			continue
		var w: float = float(a["weight"]) * float(b["aggression"]) * punish * (1.0 + randf() * 0.3)
		if t_down:
			w *= 1.3
		if a.get("guard_break", false) and t_blocking:
			w *= 2.0
		for tag in a.get("tags", []):
			w *= adaptive_weights.get(tag, 1.0)
		if kind in ["ward", "buff", "resurrect"]:
			w *= 1.6   # support magic comes first when it has a use
		if _stealthed:
			w = w * 3.0 if kind == "pounce" and _stealth_t <= 0.4 else 0.0
		if w > 0.0:
			scores["attack:" + id] = w
	# Defence
	if float(b.get("block_chance", 0.0)) > 0.0 and t_attacking and dist < 3.5:
		scores["block"] = float(b["block_chance"]) * 1.4
	if float(b.get("can_dodge", 0.0)) > 0.0 and t_attacking and dist < 3.2 and not _stealthed:
		scores["dodge"] = float(b["can_dodge"]) * 1.25
	# Movement by role
	var pref: float = b["preferred_range"]
	var wait: float = b["wait_range"]
	match role:
		"ranged", "support":
			var kr: Array = b.get("keep_range", [pref * 0.6, pref * 1.4])
			scores["kite"] = 0.95 if dist < float(kr[0]) else 0.0
			scores["approach"] = 0.6 if dist > float(kr[1]) else 0.02
			scores["circle"] = 0.25
			if role == "support" and allies > 0:
				scores["keep_back"] = 0.5
			if b.get("high_ground", false) and _find_high_spot():
				scores["seek_high"] = 0.35
		"tank":
			scores["approach"] = 0.5 if dist > pref + 0.3 else 0.05
			scores["hold_front"] = 0.45 if allies > 0 and dist < wait + 3.0 else 0.0
			scores["circle"] = 0.2
		_:
			scores["approach"] = 0.5 if dist > pref + 0.3 else 0.05
			scores["circle"] = 0.35 if dist < wait + 1.5 else 0.1
			if b.get("flank", false):
				scores["flank"] = 0.45
	if _stealthed:
		for k in scores.keys():
			if not k.begins_with("attack:"):
				scores.erase(k)
		scores["circle"] = 0.5
	if health < max_health * 0.25 and faction == "beast" and tier == "normal":
		scores["retreat"] = 0.3
	# Morale: bandits break when hurt and alone, or when their ataman falls
	if _ai["factions"].get(faction, {}).get("morale", false) and not b.get("never_flee", false) and not _morale_checked:
		var m: Dictionary = _ai["morale"]
		if health < max_health * float(m["flee_below"]) and (allies < 2 or _leader_lost):
			scores["morale"] = 3.0
	var best := "approach"
	var best_score := -1.0
	for k in scores:
		if scores[k] > best_score:
			best_score = scores[k]
			best = k
	last_scores = scores
	if best == "morale":
		_morale_break()
		return
	if best.begins_with("attack:"):
		var attack := _attack_by_id(best.substr(7))
		var kind: String = attack.get("kind", "melee")
		var free: bool = kind in ["ranged", "ward", "buff", "resurrect", "explode"] or data["behavior"].get("ignores_tokens", false)
		if not free and target.has_method("request_token") and not target.request_token(_token_cost):
			best = "flank" if b.get("flank", false) else "circle"
		else:
			_has_token = not free
			_begin_attack(attack)
			return
	if best == "block":
		_begin_block()
		return
	if best == "dodge":
		var clip: String = data["anims"].get("dodge", "")
		if clip != "":
			_model.play_action(clip, 1.4, 0.05)
		_enter(S.DODGE)
		return
	_action = best


## Whether a special attack has something to work on right now.
func _special_ready(a: Dictionary) -> bool:
	match a.get("kind", "melee"):
		"resurrect":
			return _resurrects_left > 0 and _nearest_corpse(float(a["range"])) != {}
		"ward":
			for o in get_tree().get_nodes_in_group("enemies"):
				if o != self and o.faction == faction and o.ward <= 0.0 and o.global_position.distance_to(global_position) < float(a["range"]):
					return true
			return false
		"buff":
			return _allies_near(float(a.get("radius", 12.0))) > 0
	return true


func _steer(to: Vector3, dist: float) -> Vector3:
	if not _target_ok() or _action == "idle":
		return Vector3.ZERO
	var dir := to.normalized() if dist > 0.01 else forward()
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
		"retreat", "kite":
			return (-dir + tangent * 0.5 + _separation()).normalized() * (_run_speed if _action == "kite" else _speed)
		"keep_back":
			# Stay behind the allies' line, away from Ayxan
			var c := _allies_center(16.0)
			var goal2: Vector3 = c + (c - target.global_position).normalized() * 6.0
			var g2 := goal2 - global_position
			g2.y = 0.0
			return g2.normalized() * _speed if g2.length() > 1.0 else Vector3.ZERO
		"hold_front":
			# Stand between Ayxan and the rest of the group
			var c2 := _allies_center(16.0)
			var goal3: Vector3 = target.global_position + (c2 - target.global_position).normalized() * (float(b["preferred_range"]) + 0.6)
			var g3 := goal3 - global_position
			g3.y = 0.0
			return (g3.normalized() + _separation()).normalized() * _speed if g3.length() > 0.8 else Vector3.ZERO
		"seek_high":
			var g4 := _high_spot - global_position
			g4.y = 0.0
			return g4.normalized() * _run_speed if g4.length() > 1.0 else Vector3.ZERO
	return Vector3.ZERO


## Archers look for a nearby spot at least 1.5 m higher that still sees Ayxan.
func _find_high_spot() -> bool:
	if not ground_query.is_valid():
		return false
	_high_t -= 1.0
	if _high_t > 0.0 and _high_spot != Vector3.ZERO:
		return _high_spot.distance_to(global_position) > 1.5
	_high_t = 6.0
	var here: float = ground_query.call(global_position.x, global_position.z)
	var best := Vector3.ZERO
	var best_h := here + 1.5
	for i in 12:
		var ang := TAU * i / 12.0
		for r: float in [6.0, 10.0]:
			var p: Vector3 = global_position + Vector3(cos(ang), 0, sin(ang)) * r
			var h: float = ground_query.call(p.x, p.z)
			var d := Vector2(p.x - target.global_position.x, p.z - target.global_position.z).length()
			if h > best_h and d > 8.0 and d < 24.0:
				best_h = h
				best = Vector3(p.x, h, p.z)
	_high_spot = best
	return best != Vector3.ZERO


func _attack_by_id(id: String) -> Dictionary:
	for a in data["attacks"]:
		if a["id"] == id:
			return a
	return data["attacks"][0]


## Elites and bosses lean on the counter to Ayxan's favourite defence.
func _update_adaptive() -> void:
	adaptive_weights.clear()
	if tier == "normal" or not data.has("counters") or not _target_ok() or target.get("habits") == null:
		return
	var w: Dictionary = target.habits.weights()
	var boost: float = _ai["adaptive"]["boost"]
	var counters: Dictionary = data["counters"]
	for habit in counters:
		for tag in counters[habit]:
			adaptive_weights[tag] = adaptive_weights.get(tag, 1.0) + boost * float(w.get(habit, 0.0))


# --- Attacking --------------------------------------------------------------------------------

func _begin_attack(a: Dictionary) -> void:
	_attack = a
	_hit_done = false
	_feinted = false
	_cooldowns[a["id"]] = float(a["cooldown"])
	var windup := float(a["windup"]) / _atk_speed
	if a.has("windup_clip"):
		_model.play_action(a["windup_clip"], 1.0, 0.08, true)
	else:
		_model.play_action(a["clip"], float(a["clip_impact"]) / windup, 0.06)
	var kind: String = a.get("kind", "melee")
	_ring.visible = kind not in ["ranged", "ward", "buff", "resurrect"]
	_ring.scale = Vector3(0.4, 0.3, 0.4)
	Audio.play("shade_windup", -12.0, 0.15, global_position)
	if _stealthed:
		_unstealth()
	match kind:
		"explode":
			bark("explode")
		"buff":
			bark("war_cry")
		"resurrect":
			bark("resurrect")
		"ward":
			bark("ward")
		_:
			bark("attack", 0.55 if faction == "beast" else 0.3)
	_enter(S.WINDUP)


func _update_ring() -> void:
	var windup := float(_attack["windup"]) / _atk_speed
	var k := clampf(_t / windup, 0.0, 1.0)
	var reach: float = float(_attack.get("radius", float(_attack["range"]) + radius))
	var r := lerpf(0.4, reach, k)
	_ring.scale = Vector3(r, 0.3, r)
	var left := windup - _t
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


## A feint: the swing stops short and starts again. Parry-happy players see it more.
func _try_feint(windup: float) -> void:
	_feinted = true
	var chance := 0.45
	if _target_ok() and target.get("habits") != null:
		chance += 0.45 * float(target.habits.weights().get("parry", 0.0))
	if randf() >= chance:
		return
	_t = windup * 0.12
	_model.cancel_action()
	_model.play_action(_attack["clip"], float(_attack["clip_impact"]) / windup, 0.04)
	_flash = 0.8


func _on_strike_start() -> void:
	var kind: String = _attack.get("kind", "melee")
	if _attack.has("windup_clip"):
		_model.play_action(_attack["clip"], 1.2, 0.04)
	match kind:
		"ranged":
			_shoot()
			_hit_done = true
		"explode":
			_explode()
		"resurrect":
			_resurrect()
			_hit_done = true
		"ward":
			_cast_ward()
			_hit_done = true
		"buff":
			_war_cry()
			_hit_done = true


func _do_strike(_delta: float) -> Vector3:
	var kind: String = _attack.get("kind", "melee")
	var dir: Vector3 = forward()
	var move := Vector3.ZERO
	var lunge_time := 0.32 if kind == "pounce" else (0.22 if kind == "slam" else 0.14)
	if kind in ["melee", "pounce", "slam"] and _t < lunge_time:
		move = dir * float(_attack.get("lunge", 6.0))
	if not _hit_done and _t >= (0.2 if kind == "slam" else 0.06):
		_hit_done = true
		if kind == "slam":
			Aoe.blast(global_position + dir * 1.2, float(_attack["radius"]), _dmg(), _attack.get("damage_type", "crush"),
				float(_attack.get("stance", 30.0)) * stance_mult, float(_attack.get("burn", 0.0)), self, get_tree())
		else:
			_deal_hit(dir)
	if _t >= lunge_time + 0.04:
		_attacks_done += 1
		_enter(S.RECOVER)
		_maybe_stealth()
	return move


func _dmg() -> float:
	return float(_attack["damage"]) * _dmg_scale * damage_mult


func _deal_hit(dir: Vector3) -> void:
	if not _target_ok():
		return
	var a := _attack
	var reach := float(a["range"]) + 0.3
	for t in Melee.targets(self, dir, reach, float(a.get("arc", 90.0))):
		var hit = Hit.new().setup(self, _dmg(), a.get("damage_type", "slash"), float(a.get("stance", 10.0)) * stance_mult, dir * 7.0)
		hit.parryable = not a.get("unparryable", false)
		hit.heavy = float(a.get("stance", 0.0)) >= 35.0
		hit.guard_break = a.get("guard_break", false)
		hit.burn = float(a.get("burn", 0.0))
		if affixes.has("flaming"):
			hit.burn = maxf(hit.burn, float(Affixes.def("flaming")["burn"]))
		t.receive_hit(hit)


func _shoot() -> void:
	if not _target_ok():
		return
	var a := _attack
	var spec: Dictionary = a.get("projectile", {})
	var from: Vector3 = global_position + Vector3(0, 1.35 * body_scale(), 0) + forward() * 0.5
	var aim: Vector3 = target.global_position + Vector3(0, 1.1, 0)
	# Lead the target a little
	var flight: float = from.distance_to(aim) / float(spec.get("speed", 20.0))
	aim += target.velocity * flight * 0.6
	var info := {"damage": _dmg(), "damage_type": a.get("damage_type", "pierce"), "stance": float(a.get("stance", 8.0)),
		"burn": float(a.get("burn", 0.0)), "parryable": not a.get("unparryable", false)}
	Projectile.launch(get_parent(), from, aim, self, info, spec)
	Audio.play("swing", -8.0, 0.1, global_position, 3)


func _explode() -> void:
	var a := _attack
	Aoe.blast(global_position, float(a["radius"]), _dmg(), a.get("damage_type", "fire"), float(a.get("stance", 40.0)),
		float(a.get("burn", 0.0)), self, get_tree())
	Fx.death_burst(global_position, 1.6)
	if not dead:
		dead = true
		health = 0.0
		_on_died(null)
		died.emit()


func _resurrect() -> void:
	var c := _nearest_corpse(float(_attack["range"]))
	if c.is_empty():
		return
	corpses.erase(c)
	_resurrects_left -= 1
	Fx.fire_nova(c["pos"], 2.0)
	Audio.play("shade_spawn", -4.0, 0.1, c["pos"])
	summon_requested.emit(c["id"], c["pos"], int(c["level"]), {"risen": true, "roll": false})


func _nearest_corpse(max_d: float) -> Dictionary:
	var now := Time.get_ticks_msec() / 1000.0
	var best := {}
	var best_d := max_d
	for c in corpses:
		if now - float(c["time"]) > 60.0:
			continue
		var d := global_position.distance_to(c["pos"])
		if d < best_d:
			best_d = d
			best = c
	return best


func _cast_ward() -> void:
	var a := _attack
	for o in get_tree().get_nodes_in_group("enemies"):
		if o != self and o.faction == faction and o.global_position.distance_to(global_position) < float(a["range"]):
			o.grant_ward(float(a["ward"]), float(a["ward_time"]))
			o._on_ward_hit(false)
	Fx.fire_nova(global_position, 1.5)


func _war_cry() -> void:
	var a := _attack
	for o in get_tree().get_nodes_in_group("enemies"):
		if o.faction == faction and o.global_position.distance_to(global_position) < float(a["radius"]):
			o.grant_buff(float(a["damage_mult"]), float(a["stance_mult"]), float(a["buff_time"]))
			o._flash = 1.0
	Audio.play("horn", -6.0, 0.05, global_position)
	Fx.notify(display_name + " savaş narası attı!")


## Seconds until this enemy's blow lands (for perfect dodges); INF when not attacking.
func time_to_strike() -> float:
	if _state == S.WINDUP:
		return maxf(float(_attack["windup"]) / _atk_speed - _t, 0.0)
	if _state == S.STRIKE and not _hit_done:
		return 0.0
	return INF


func is_attacking() -> bool:
	return _state in [S.WINDUP, S.STRIKE]


func _release_token() -> void:
	if _has_token and _target_ok() and target.has_method("release_token"):
		target.release_token(_token_cost)
	_has_token = false


# --- Stealth and phases (Qafqaz bəbiri) ----------------------------------------------------

func _maybe_stealth() -> void:
	var st: Dictionary = data["behavior"].get("stealth", {})
	if st.is_empty() or _attacks_done < int(st["after_attacks"]):
		return
	_attacks_done = 0
	var tr: Array = st["phase2_time"] if _phase > 0 else st["time"]
	_stealth_t = randf_range(tr[0], tr[1])
	_stealthed = true
	_set_alpha(1.0 - float(st["alpha"]))
	_bar.visible = false
	Audio.play("dash", -6.0, 0.1, global_position)


func _tick_stealth(delta: float) -> void:
	if _stealthed:
		_stealth_t -= delta


func _unstealth() -> void:
	_stealthed = false
	_set_alpha(0.0)


func _set_alpha(transparency_value: float) -> void:
	for mi: MeshInstance3D in _model.scene.find_children("*", "MeshInstance3D", true, false):
		mi.transparency = transparency_value


func _check_phase() -> void:
	var phases: Array = data["behavior"].get("phases", [])
	if _phase >= phases.size():
		return
	var ph: Dictionary = phases[_phase]
	if health > max_health * float(ph["at"]):
		return
	_phase += 1
	_speed *= float(ph.get("speed", 1.0))
	_run_speed *= float(ph.get("speed", 1.0))
	_atk_speed *= float(ph.get("attack_speed", 1.0))
	Fx.notify(ph.get("banner", display_name + " öfkelendi!"))
	bark("phase")
	Fx.shake(0.5)
	_flash = 1.0


# --- Affixes at run time -------------------------------------------------------------------

func _tick_affixes(delta: float) -> void:
	if affixes.has("flaming") and aggro and velocity.length() > 1.0 and not dead:
		_trail_t -= delta
		if _trail_t <= 0.0:
			var d := Affixes.def("flaming")
			_trail_t = float(d["trail_every"])
			Aoe.fire_patch(get_parent(), global_position, self, 1.2, float(d["trail_dps"]), float(d["trail_life"]))


func _check_summoner() -> void:
	if not affixes.has("summoner") or _summoned:
		return
	var d := Affixes.def("summoner")
	if health > max_health * float(d["at"]):
		return
	_summoned = true
	var id: String = DataDB.balance("affixes")["summon_by_faction"].get(faction, "ash_shade")
	for i in int(d["count"]):
		var ang := TAU * i / float(d["count"]) + randf()
		summon_requested.emit(id, global_position + Vector3(cos(ang), 0, sin(ang)) * 2.5, level, {"roll": false})
	var clip: String = data["anims"].get("taunt", "")
	if clip != "":
		_model.play_action(clip, 1.4, 0.05)
	Fx.notify(display_name + " yardım çağırdı!")


# --- Morale -----------------------------------------------------------------------------------

func _morale_break() -> void:
	_morale_checked = true
	_release_token()
	if randf() < float(_ai["morale"]["surrender_chance"]):
		_surrender()
	else:
		Fx.notify(display_name + " kaçıyor!")
		bark("flee")
		_enter(S.FLEE)


func _surrender() -> void:
	surrendered = true
	aggro = false
	remove_from_group("enemies")
	_ring.visible = false
	var a: Dictionary = data["anims"]
	_model.cancel_action()
	if a.get("surrender", "") != "":
		_model.play_action(a["surrender"], 1.0, 0.1, true)
	_show_icon("🏳", Color(0.95, 0.95, 0.9), 9999.0)
	Fx.notify(display_name + " teslim oldu")
	bark("surrender")
	_enter(S.SURRENDER)


## Ayxan lets a surrendered bandit go: he gets up and leaves.
func spare() -> void:
	if not surrendered:
		return
	_model.cancel_action()
	_model.play_action(data["anims"]["recover"], 1.4, 0.1)
	bark("spared")
	_enter(S.FLEE)
	_t = -1.0


## Left the fight for good (fled): counts as gone for the world, no reward.
func _vanish() -> void:
	if dead:
		return
	dead = true
	_release_token()
	remove_from_group("enemies")
	killed.emit(self)
	queue_free()


func _leader_fell() -> void:
	_leader_lost = true
	_morale_checked = false


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
	if from.dot(forward()) < 0.3:
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
		_on_stance_broken(null)
		return
	_stun_time = stun_time
	var hits: Array = data["anims"]["hit"]
	_model.play_action(hits[hits.size() - 1], 0.8, 0.04)
	_enter(S.STUNNED)


func _unstoppable() -> bool:
	if _state == S.WINDUP:
		return float(_attack["windup"]) / _atk_speed - _t <= float(_attack.get("unstoppable", 0.0))
	return _state == S.STRIKE


func _on_ward_hit(broken: bool) -> void:
	_overlay.set_shader_parameter("flash_color", Color(0.5, 0.8, 1.0))
	_flash = 0.8 if not broken else 0.3


func _on_hurt(hit, amount: float) -> void:
	if surrendered:
		return
	if _target_ok():
		alarm(target.global_position)
	for other in get_tree().get_nodes_in_group("enemies"):
		if other != self and other.has_method("alarm") and other.global_position.distance_to(global_position) < 14.0:
			other.alarm(global_position)
	if _stealthed:
		_unstealth()
	_flash = 1.0
	_overlay.set_shader_parameter("flash_color", Color(1.0, 0.7, 0.45))
	_bar.visible = tier != "boss"
	_bar_hold = 0.45
	_knock += hit.knock * (0.5 if role == "tank" else (0.2 if tier != "normal" else 1.0))
	Fx.hit_spark(global_position + Vector3(0, float(data["stats"]["height"]) * _body_scale * 0.6, 0), hit.heavy)
	if Settings.damage_numbers:
		Fx.damage_number(global_position + Vector3(0, 2.0, 0), amount, "heavy" if hit.heavy else "normal")
	_lean(hit)
	_check_summoner()
	_check_phase()
	bark("hurt", 0.6 if faction == "beast" else 0.35)
	if _unstoppable() or _state in [S.BROKEN, S.EXECUTED, S.FLEE]:
		return
	if tier != "normal" and not hit.heavy:
		return   # elites and bosses shrug off light blows
	_ring.visible = false
	if _state in [S.WINDUP, S.STRIKE]:
		_release_token()
	if hit.heavy and max_stance <= 60.0 and not data["behavior"].get("knockdown_immune", false):
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
	if hit == null:
		return
	var d: Vector3 = hit.direction(self)
	var local: Vector3 = _model.global_basis.inverse() * d
	var tw: Tween = _model.create_tween()
	tw.tween_property(_model, "rotation:x", -local.z * 0.25, 0.06)
	tw.parallel().tween_property(_model, "rotation:z", local.x * 0.25, 0.06)
	tw.tween_property(_model, "rotation:x", 0.0, 0.25)
	tw.parallel().tween_property(_model, "rotation:z", 0.0, 0.25)


func _on_stance_broken(hit) -> void:
	if affixes.has("unshakable") and not _unshakable_used:
		# Sarsılmaz: the first break just glances off
		_unshakable_used = true
		stance = 0.0
		_overlay.set_shader_parameter("flash_color", Color(0.85, 0.85, 1.0))
		_flash = 1.0
		Fx.hit_spark(global_position + Vector3(0, 1.4, 0), true)
		return
	if hit != null:
		_lean(hit)
	_break()


func _break() -> void:
	_ring.visible = false
	_release_token()
	if _stealthed:
		_unstealth()
	var a: Dictionary = data["anims"]
	_model.play_action(a["stagger"], 1.5, 0.05, true)
	if a.has("stagger_hold_at"):
		get_tree().create_timer(float(a["stagger_hold_at"]), false).timeout.connect(func():
			if _state == S.BROKEN:
				_model.anim.speed_scale = 0.0)
	Audio.play("hit_heavy", -4.0, 0.1, global_position)
	Fx.notify("Duruşu kırıldı — [E] infaz")
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
	_icon.visible = false
	if _name_label:
		_name_label.visible = false
	if _stealthed:
		_unstealth()
	_model.anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	_model.anim.speed_scale = 1.0
	_model.play_action(data["anims"]["death"], 1.3, 0.05, true)
	Fx.death_burst(global_position, 1.0 * _body_scale)
	Audio.play("shade_death" if faction == "ash" else "hit_heavy", -3.0, 0.12, global_position)
	if faction == "ash" and not risen and data["id"] in ["ash_shade", "ash_runner", "ash_archer"]:
		corpses.append({"id": data["id"], "pos": global_position, "level": level, "time": Time.get_ticks_msec() / 1000.0})
	if data["behavior"].get("leader", false):
		for o in get_tree().get_nodes_in_group("enemies"):
			if o.faction == faction and o.global_position.distance_to(global_position) < 30.0 and o.has_method("_leader_fell"):
				o._leader_fell()
		Fx.notify("Reis düştü! Haydutlar sarsıldı.")
	bark("death", 0.9)
	var mourners: Array = get_tree().get_nodes_in_group("enemies").filter(func(o): return o.faction == faction and o.global_position.distance_to(global_position) < 18.0)
	if not mourners.is_empty():
		mourners.pick_random().bark("ally_died", 0.6)
	if affixes.has("vengeful"):
		_vengeance()
	if _target_ok() and target.has_method("on_enemy_killed"):
		target.on_enemy_killed()
	killed.emit(self)
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(_model, "position:y", -1.8, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


## Qisasçı: the corpse glows and bursts two seconds later.
func _vengeance() -> void:
	var d := Affixes.def("vengeful")
	var pos := global_position
	_ring.visible = true
	_ring.scale = Vector3(float(d["radius"]), 0.3, float(d["radius"]))
	var tw := create_tween().set_loops(8)
	tw.tween_callback(func(): _ring_mat.albedo_color = Color(1.0, 0.1, 0.05, 0.9))
	tw.tween_interval(0.12)
	tw.tween_callback(func(): _ring_mat.albedo_color = Color(1.0, 0.4, 0.1, 0.3))
	tw.tween_interval(0.12)
	get_tree().create_timer(float(d["delay"]), false).timeout.connect(func():
		if is_instance_valid(self):
			_ring.visible = false
			Aoe.blast(pos, float(d["radius"]), float(d["damage"]) * _dmg_scale, "fire", 40.0, 2.0, self, get_tree()))


# --- Voice ------------------------------------------------------------------------------------

## Says something for `event` if this enemy's voice has a line for it.
func bark(event: String, chance := 1.0) -> bool:
	if voice == "" or lod == LOD.FROZEN:
		return false
	return Barks.say(self, voice, event, chance, float(data["stats"]["height"]) * _body_scale)


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
		var min_gap: float = radius + other.radius + 0.6
		if l < min_gap and l > 0.001:
			push += d / l * (min_gap - l)
	return push


func _allies_near(r: float) -> int:
	var n := 0
	for o in get_tree().get_nodes_in_group("enemies"):
		if o != self and o.faction == faction and o.global_position.distance_to(global_position) < r:
			n += 1
	return n


func _allies_center(r: float) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for o in get_tree().get_nodes_in_group("enemies"):
		if o != self and o.faction == faction and o.global_position.distance_to(global_position) < r:
			sum += o.global_position
			n += 1
	return sum / n if n > 0 else global_position


func _show_icon(text: String, color: Color, seconds := 3.0) -> void:
	_icon.text = text
	_icon.modulate = color
	_icon.visible = true
	_icon_t = seconds


func _update_icon(delta: float) -> void:
	if not _icon.visible:
		return
	_icon_t -= delta
	if _icon_t <= 0.0 and perception != null and perception.state in [Perception.SUSPICIOUS, Perception.SEARCH]:
		_icon_t = 0.5   # stays while suspicious
	elif _icon_t <= 0.0:
		_icon.visible = false


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
