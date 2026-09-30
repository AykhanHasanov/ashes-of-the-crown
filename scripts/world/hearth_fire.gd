extends Node3D
## How a hearth looks (a view: it holds no state). Two variants:
##   lit   a ring of stones, a bed of glowing embers, flames and sparks (GPUParticles) and a
##         warm OmniLight whose energy flickers (it never moves: see _process);
##   cold  the same stones round grey ash and two charred logs, with a thin thread of smoke.
## Parts can be left out where a prefab already has them (ring / bed / light).
## Use: const HearthFire := preload("res://scripts/world/hearth_fire.gd")
##      add_child(HearthFire.new().setup(false))   # Eşref's cold hearth

const Effects := preload("res://scripts/world/effects.gd")
const STONE := "res://assets/foliage/rock_small.scn"
const STONE_SIZE := 0.34          # metres across each ring stone

var lit := true
var radius := 0.75
var with_ring := true
var with_bed := true
var with_light := true
var light_energy := 2.2
var light_range := 7.0
var light: OmniLight3D            # the flickering fire light (lit, with_light)
var _t := 0.0
var _seed := 0.0


func setup(is_lit: bool, ring_radius := 0.75, ring := true, bed := true, own_light := true,
		energy := 2.2, light_reach := 7.0) -> Node3D:
	lit = is_lit
	light_energy = energy
	light_range = light_reach
	radius = ring_radius
	with_ring = ring
	with_bed = bed
	with_light = own_light
	return self


func _ready() -> void:
	_seed = randf() * 100.0
	if with_ring:
		_ring()
	if with_bed:
		_bed()
	_logs()
	if lit:
		var flames := Effects.hearth_flames(radius * 1.2, 40)
		flames.name = "Flames"
		flames.position.y = 0.15
		add_child(flames)
		var sparks := Effects.sparks(radius * 1.3, 16)
		sparks.name = "Sparks"
		sparks.position.y = 0.3
		add_child(sparks)
		if with_light:
			light = OmniLight3D.new()
			light.name = "FireLight"
			light.light_color = Color(1.0, 0.52, 0.22)
			light.light_energy = light_energy
			light.omni_range = light_range
			light.omni_attenuation = 1.4
			light.shadow_enabled = true
			light.position.y = 0.7
			add_child(light)
	else:
		var smoke := Effects.smoke_wisp()   # a thin thread, not a chimney
		smoke.name = "Smoke"
		smoke.position.y = 0.12
		add_child(smoke)
	set_process(lit and light != null)


## A fire never burns steady: the light's ENERGY wavers (two sines and a little noise). Its
## position never moves — a light that moves redraws its whole shadow cube every frame (365
## draw calls in the hub, docs/PERF_PROFILE.md); a change of energy costs nothing.
func _process(delta: float) -> void:
	_t += delta
	var f := 0.8 + 0.13 * sin(_t * 9.3 + _seed) + 0.08 * sin(_t * 23.1 + _seed * 2.0) + randf() * 0.06
	light.light_energy = light_energy * f


func _ring() -> void:
	if not ResourceLoader.exists(STONE):
		return
	var scene: PackedScene = load(STONE)
	var n := maxi(int(TAU * radius / (STONE_SIZE * 0.9)), 7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.08, 0.08)
		var stone: Node3D = scene.instantiate()
		var s := STONE_SIZE / maxf(_size_of(stone), 0.01) * rng.randf_range(0.8, 1.15)
		stone.scale = Vector3(s, s * rng.randf_range(0.7, 1.0), s)
		stone.position = Vector3(cos(a), 0, sin(a)) * radius
		stone.rotation.y = rng.randf() * TAU
		add_child(stone)


## Glowing embers (lit) or grey ash (cold), a low mound inside the ring.
func _bed() -> void:
	var bed := MeshInstance3D.new()
	bed.name = "Embers" if lit else "Ash"
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.78
	cyl.bottom_radius = radius * 0.85
	cyl.height = 0.08
	var m := StandardMaterial3D.new()
	var noise := NoiseTexture2D.new()
	noise.noise = FastNoiseLite.new()
	noise.noise.frequency = 0.08
	noise.width = 128
	noise.height = 128
	m.roughness = 1.0
	if lit:
		var g := Gradient.new()
		g.set_color(0, Color(0.05, 0.02, 0.01))
		g.set_color(1, Color(0.9, 0.25, 0.03))
		noise.color_ramp = g
		m.albedo_color = Color(0.08, 0.05, 0.04)
		m.emission_enabled = true
		m.emission_texture = noise
		m.emission_energy_multiplier = 1.2
	else:
		m.albedo_texture = noise
		m.albedo_color = Color(0.42, 0.41, 0.4)   # pale, dead ash
	cyl.material = m
	bed.mesh = cyl
	bed.position.y = 0.03
	add_child(bed)


func _logs() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.07, 0.05, 0.04)
	m.roughness = 0.95
	if lit:
		m.emission_enabled = true
		m.emission = Color(0.9, 0.25, 0.04)
		m.emission_energy_multiplier = 0.15   # glowing cracks in the charred wood
	for i in 2:
		var lg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.075
		cyl.height = radius * 1.2
		cyl.material = m
		lg.mesh = cyl
		lg.rotation = Vector3(PI * 0.5, 0.5 + i * 1.3, 0.08 if lit else 0.0)
		lg.position = Vector3(0, 0.1 + i * 0.07, 0)
		add_child(lg)


static func _size_of(n: Node) -> float:
	var box := AABB()
	var first := true
	var meshes: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		meshes.append(n)
	for mi in meshes:
		var b: AABB = (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return maxf(box.size.x, box.size.z)
