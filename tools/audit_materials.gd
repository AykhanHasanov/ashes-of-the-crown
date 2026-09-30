extends SceneTree
## Material audit: every model under assets/ (glb, gltf, scn, tscn), every surface's
## BaseMaterial3D metallic and roughness. Prints one line per unique material and a summary
## of the non-metals that break the rule (a scalar metallic > 0 or roughness < 0.7; values
## driven by an ORM / metallic texture are reported as (tex) and left to the texture).
## Run: godot --headless --path . -s tools/audit_materials.gd
## (Autoloads do not exist in -s mode; this script needs none.)

const ROOTS := ["res://assets/chars", "res://assets/characters", "res://assets/foliage", "res://assets/props_mk",
	"res://assets/village_mk", "res://assets/quaternius", "res://assets/nature", "res://assets/buildings",
	"res://assets/environment"]
const EXT := ["glb", "gltf", "scn", "tscn"]
## Names that are really metal (weapons, armour plates, fittings): they may stay metallic.
const METAL_HINTS := ["metal", "iron", "steel", "sword", "blade", "axe", "gold", "silver", "copper", "bronze",
	"chain", "armor", "armour", "helmet", "nail", "lantern", "hinge", "ornament", "coin", "weapon", "shield_metal"]

var _seen := {}
var _bad: Array = []


func _init() -> void:
	for root in ROOTS:
		_scan(root)
	print("---- %d unique materials, %d non-metals breaking the rule ----" % [_seen.size(), _bad.size()])
	for b in _bad:
		print("FIX  ", b)
	quit()


func _scan(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_scan(dir.path_join(sub))
	for f in d.get_files():
		if f.get_extension() in EXT:
			_file(dir.path_join(f))


func _file(path: String) -> void:
	var res = load(path)
	if not (res is PackedScene):
		return
	var n: Node = res.instantiate()
	var meshes: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		meshes.append(n)
	for mi in meshes:
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m: Material = mi.get_surface_override_material(i)
			if m == null:
				m = mesh.surface_get_material(i)
			if mi.material_override != null:
				m = mi.material_override
			_material(path, m)
	n.free()


func _material(path: String, m: Material) -> void:
	if not (m is BaseMaterial3D):
		return
	var key := "%s|%s" % [path.get_file(), m.resource_name]
	if _seen.has(key):
		return
	_seen[key] = true
	var bm := m as BaseMaterial3D
	var name_l := m.resource_name.to_lower()   # the material's own name decides (an atlas is not metal)
	var metal_ok := METAL_HINTS.any(func(h): return name_l.contains(h))
	var line := "%s  mat=%s  metallic=%.2f%s  roughness=%.2f%s%s" % [path.trim_prefix("res://assets/"), m.resource_name,
		bm.metallic, " (tex)" if bm.metallic_texture else "", bm.roughness, " (tex)" if bm.roughness_texture else "",
		"  (metal)" if metal_ok else ""]
	print(line)
	# texture-driven values are the texture's business (an ORM map marks the few metal pixels)
	var bad_metal := bm.metallic > 0.0 and bm.metallic_texture == null
	var bad_rough := bm.roughness < 0.699 and bm.roughness_texture == null
	var glossy := ["eye", "glass", "water"].any(func(h): return name_l.contains(h))
	if not metal_ok and (bad_metal or (bad_rough and not glossy)):
		_bad.append(line)
