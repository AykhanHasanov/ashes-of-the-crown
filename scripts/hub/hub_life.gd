extends Node3D
## What makes Son Ocaq feel lived in — a view over WorldState and the clock, holding no state
## of its own (data: data/hub/son_ocaq.json `life`):
##   sound      birds by day, crickets at night, a thread of wind always, the fire at the hearth;
##   smoke      a chimney over every place someone is home in;
##   cloth      laundry on a rope in the west gallery, swaying;
##   market     stalls, crates and a bench in the courtyard (where people stand by day);
##   windows    the lit windows only glow from dusk to dawn;
##   birds      flocks wheeling over the caravanserai by day (scripts/world/birds.gd).
## Where people stand by hour is the routine, read from the same data by HubData and used by
## hub_mode._npc_spot.
## Use: the level builds one (scripts/hub/hub_level.gd).

const HubData := preload("res://scripts/hub/hub_data.gd")
const Effects := preload("res://scripts/world/effects.gd")
const Visuals := preload("res://scripts/world/visuals.gd")
const Birds := preload("res://scripts/world/birds.gd")
const PROPS := "res://assets/props_mk/%s.gltf"

var level                      # HubLevel
var _cfg: Dictionary
var _day: AudioStreamPlayer
var _night: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _smoke := {}               # place id -> GPUParticles3D
var _cloths: Array = []        # [MeshInstance3D, phase]
var _t := 0.0


func _ready() -> void:
	_cfg = HubData.data().get("life", {})
	if _cfg.is_empty():
		return
	_ambience()
	_hearth_sound()
	_smoke_stacks()
	_laundry()
	_market()
	var birds := Birds.new()
	birds.name = "Birds"
	birds.clock = level.day_night
	birds.flocks = int(_cfg.get("birds", {}).get("flocks", 2))
	add_child(birds)
	EventBus.npc_moved.connect(_on_people_changed)
	EventBus.npc_died.connect(_on_people_died)
	EventBus.state_replaced.connect(refresh)
	EventBus.time_of_day_changed.connect(_on_phase)
	refresh()


func _on_people_changed(_id: StringName, _from: String, _to: String) -> void:
	refresh()


func _on_people_died(_id: StringName, _cause: String) -> void:
	refresh()


func _on_phase(_phase: StringName) -> void:
	refresh()


## Smoke only where someone is home; the rest follows the clock every frame (_process).
func refresh() -> void:
	if not is_inside_tree():
		return
	for id in _smoke:
		(_smoke[id] as GPUParticles3D).emitting = _someone_home(id)


func _process(delta: float) -> void:
	_t += delta
	var n: float = level.day_night.night_amount()
	# Lit windows are lit at night, dark by day (the level decides which rooms may glow at all)
	level.set_window_glow(n)
	if _cfg.is_empty():
		return
	var amb: Dictionary = _cfg["ambience"]
	var step := float(amb["fade_per_second"]) * delta
	_fade(_day, (1.0 - n) * db_to_linear(float(amb["day"]["db"])), step)
	_fade(_night, n * db_to_linear(float(amb["night"]["db"])), step)
	var sway: Dictionary = _cfg["laundry"]
	for c in _cloths:
		var pivot: Node3D = c[0]
		pivot.rotation.z = sin(_t * float(sway["speed"]) + float(c[1])) * float(sway["sway"])


func _fade(p: AudioStreamPlayer, want: float, step: float) -> void:
	if p == null:
		return
	var cur := db_to_linear(p.volume_db)
	p.volume_db = linear_to_db(maxf(move_toward(cur, want, step), 0.00005))


# --- Sound ---------------------------------------------------------------------------------------

func _ambience() -> void:
	var amb: Dictionary = _cfg["ambience"]
	_day = _loop(String(amb["day"]["sound"]), -60.0)
	_night = _loop(String(amb["night"]["sound"]), -60.0)
	_wind = _loop(String(amb["wind"]["sound"]), float(amb["wind"]["db"]))


func _loop(sound: String, db: float) -> AudioStreamPlayer:
	var s := Audio.stream(sound)
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.name = sound
	p.stream = s
	p.bus = "SFX"
	p.volume_db = db
	add_child(p)
	p.play()
	return p


## The fire heard from across the courtyard, loudest at the hearth.
func _hearth_sound() -> void:
	var cfg: Dictionary = _cfg["hearth_sound"]
	var s := Audio.stream(String(cfg["sound"]))
	if s == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.name = "HearthFireSound"
	p.stream = s
	p.bus = "SFX"
	p.volume_db = float(cfg["db"])
	p.unit_size = float(cfg["unit_size"])
	p.max_distance = float(cfg["max_distance"])
	p.position = level.hearth_pos + Vector3(0, 0.6, 0)
	add_child(p)
	p.play()


# --- Smoke, cloth, market --------------------------------------------------------------------------

func _smoke_stacks() -> void:
	var cfg: Dictionary = _cfg["smoke"]
	for id in cfg["places"]:
		var place_id := String(id)
		if not level.fronts.has(place_id):
			continue
		var front: Transform3D = level.fronts[place_id]["door"]
		var smoke := Effects.chimney_smoke()
		smoke.name = "Smoke_" + place_id
		smoke.amount = int(cfg["amount"])
		smoke.scale = Vector3.ONE * float(cfg.get("scale", 1.0))
		smoke.position = front.origin - front.basis.z * float(cfg["back"]) + Vector3(0, float(cfg["height"]), 0)
		smoke.emitting = false
		add_child(smoke)
		_smoke[place_id] = smoke


## Washing on a rope in the gallery: the cloths sway (see _process).
func _laundry() -> void:
	var cfg: Dictionary = _cfg["laundry"]
	var a := _vec(cfg["from"]) + Vector3(0, float(cfg["height"]), 0)
	var b := _vec(cfg["to"]) + Vector3(0, float(cfg["height"]), 0)
	var rope := MeshInstance3D.new()
	rope.name = "Rope"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.012
	cyl.height = a.distance_to(b)
	cyl.radial_segments = 5
	cyl.material = Visuals.mat(Color(0.45, 0.4, 0.33), 1.0)
	rope.mesh = cyl
	rope.position = (a + b) * 0.5
	rope.rotation.x = PI * 0.5   # the rope runs along Z here
	add_child(rope)
	var n := int(cfg["cloths"])
	var colors: Array = cfg["colors"]
	for i in n:
		var t := (float(i) + 0.8) / (n + 0.6)
		var at := a.lerp(b, t)
		var pivot := Node3D.new()
		pivot.name = "Cloth_%d" % i
		pivot.position = at
		add_child(pivot)
		var cloth := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.5, 0.62 + 0.12 * sin(float(i) * 2.1))
		var col: Array = colors[i % colors.size()]
		var m := Visuals.mat(Color(col[0], col[1], col[2]), 1.0)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		q.material = m
		cloth.mesh = q
		cloth.position = Vector3(0, -q.size.y * 0.5, 0)   # hangs from the rope
		cloth.rotation.y = PI * 0.5
		cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(cloth)
		_cloths.append([pivot, float(i) * 1.7])


## Stalls, crates and a bench: the courtyard reads as a market by day.
func _market() -> void:
	var root := Node3D.new()
	root.name = "Market"
	add_child(root)
	for p in _cfg["market"]["props"]:
		var path: String = PROPS % String(p["m"])
		if not ResourceLoader.exists(path):
			push_warning("HubLife: missing " + path)
			continue
		var node: Node3D = (load(path) as PackedScene).instantiate()
		var at: Array = p["at"]
		node.position = Vector3(float(at[0]), 0.0, float(at[1]))
		node.rotation.y = deg_to_rad(float(p.get("r", 0.0)))
		Visuals.no_small_shadows(node)
		root.add_child(node)


# --- Helpers ---------------------------------------------------------------------------------------

## Someone lives (or works) there and is home: their chimney smokes.
func _someone_home(place_id: String) -> bool:
	if HubData.is_lived_in(place_id):
		return true
	for w in HubData.place(place_id).get("workers", []):
		if HubData.is_home(String(w)):
			return true
	return false


static func _vec(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
