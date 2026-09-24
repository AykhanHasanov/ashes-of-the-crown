extends RefCounted
## Shared Terrain3D setup for the generator tool and the game: texture assets from
## data/balance/world.json, vegetation mesh assets from data/world/vegetation.json
## (their order is the instancer mesh id), material and collision settings.

const TEX_DIR := "res://assets/terrain/"
const DATA_DIR := "res://world/terrain"
const FOLIAGE_SHADER := preload("res://shaders/foliage.gdshader")


## `world` = data/balance/world.json, `veg` = data/world/vegetation.json (passed in so the
## headless generator can use this without autoloads).
static func create(high_quality: bool, world: Dictionary, veg: Dictionary) -> Terrain3D:
	var terrain := Terrain3D.new()
	terrain.name = "Terrain3D"
	terrain.region_size = 256
	terrain.vertex_spacing = 1.0
	terrain.mesh_size = 48 if high_quality else 32
	terrain.mesh_lods = 7
	terrain.assets = make_assets(high_quality, world, veg)
	var m := terrain.material
	m.world_background = Terrain3DMaterial.NONE
	m.auto_shader = false
	m.texture_filtering = Terrain3DMaterial.LINEAR
	m.set_shader_param("blend_sharpness", 0.82)
	m.set_shader_param("height_blending", true)
	m.set_shader_param("macro_variation1", Color(0.93, 0.96, 0.88))
	m.set_shader_param("macro_variation2", Color(1.0, 0.95, 0.86))
	return terrain


static func make_assets(high_quality: bool, world: Dictionary, veg: Dictionary) -> Terrain3DAssets:
	var assets := Terrain3DAssets.new()
	var i := 0
	for t in world["terrain"]["textures"]:
		var ta := Terrain3DTextureAsset.new()
		ta.name = t["id"]
		ta.albedo_texture = load(TEX_DIR + t["id"] + "_albedo_height.png")
		ta.normal_texture = load(TEX_DIR + t["id"] + "_normal_rough.png")
		ta.uv_scale = t["uv_scale"]
		var tint: Array = t["tint"]
		ta.albedo_color = Color(tint[0], tint[1], tint[2])
		ta.detiling_rotation = 0.12
		ta.normal_depth = 0.8
		assets.set_texture(i, ta)
		i += 1
	i = 0
	for item in veg["items"]:
		var ma := Terrain3DMeshAsset.new()
		ma.name = item["id"]
		# Baked Y-up, metre-scale copy (tools/bake_foliage.gd); the raw glTF mesh is 1/100
		var baked := "res://assets/foliage/%s.scn" % item["id"]
		ma.scene_file = load(baked if ResourceLoader.exists(baked) else item["model"])
		var r: Array = item["range"]
		ma.lod0_range = r[1] if high_quality else r[0]
		ma.fade_margin = 0.0
		ma.cast_shadows = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if item["shadows"] and (high_quality or item.has("collide")) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not item["shadows"] and ma.get_mesh(0) != null and ma.get_mesh(0).get_surface_count() == 1:
			# Small foliage sways in the wind and bends away from Ayxan
			ma.material_override = _foliage_material(ma, item.get("color", []))
		assets.set_mesh_asset(i, ma)
		i += 1
	return assets


static func _foliage_material(ma: Terrain3DMeshAsset, tint: Array) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = FOLIAGE_SHADER
	var mesh: Mesh = ma.get_mesh(0)
	var color := Color(0.4, 0.6, 0.25)
	var top := 1.0
	if mesh != null:
		top = maxf(mesh.get_aabb().end.y, 0.1)
		var m := mesh.surface_get_material(0)
		if m is StandardMaterial3D:
			color = m.albedo_color
	if tint.size() == 3:
		color = Color(tint[0], tint[1], tint[2])
	sm.set_shader_parameter("albedo", color)
	sm.set_shader_parameter("mesh_height", top)
	return sm


static func configure_collision(terrain: Terrain3D, radius: int) -> void:
	terrain.collision.mode = Terrain3DCollision.DYNAMIC_GAME
	terrain.collision.radius = radius
	terrain.collision.layer = 1
