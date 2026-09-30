extends RefCounted
## The project's material rule for models: what is not metal is not metallic
## (metallic 0) and not glossy (roughness >= min_roughness). Quaternius exports give most
## surfaces metallic 0.4 / roughness 0.42, which read as wet plastic. Applied at import
## (tools/import/material_policy_import.gd, set as the glTF import script) and to baked
## foliage (tools/fix_materials.gd).
## Texture-driven values are left alone: an ORM / metallic texture already says which few
## pixels are metal (buckles, rivets).
## EXCEPTIONS (data/art/material_policy.json) — a material is left exactly as authored if
##   its name ends with the keep suffix ("Steel_keep": the artist's "do not touch" mark),
##   its name is listed in keep_materials, its model matches a keep_models pattern, or
##   its name contains a metal word (sword, armor, lantern...).
## Glass, water and eyes lose metallic but stay glossy.
## Use: const MaterialPolicy := preload("res://scripts/core/material_policy.gd")

const CONFIG := "res://data/art/material_policy.json"

static var _cfg: Dictionary = {}


## The rule's data (read straight from the file: this also runs at import and in -s tools,
## where the DataDB autoload does not exist).
static func config() -> Dictionary:
	if _cfg.is_empty():
		var raw = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
		_cfg = raw if raw is Dictionary else {}
	return _cfg


static func _has(name: String, hints: Array) -> bool:
	var n := name.to_lower()
	return hints.any(func(h): return n.contains(String(h)))


## Why a material is exempt from the rule ("" = it is not): "keep" (the suffix or the
## lists) or "metal" (its name says so). `model_path`: the model file it came from.
static func exemption(material_name: String, model_path := "") -> String:
	var c := config()
	var n := material_name.to_lower()
	if n.ends_with(String(c.get("keep_suffix", "_keep"))) or (c.get("keep_materials", []) as Array).has(material_name):
		return "keep"
	for pattern in c.get("keep_models", []):
		if model_path.match(String(pattern)):
			return "keep"
	if _has(material_name, c.get("metal_hints", [])):
		return "metal"
	return ""


static func is_glossy(material_name: String) -> bool:
	return _has(material_name, config().get("glossy_hints", []))


## Fixes one material in place; returns true if it changed. Decided by the MATERIAL's name
## (an atlas shared by a knight's cloth and his sword, "knight_texture", is not metal) and
## the exceptions above.
static func fix_material(m: Material, model_path := "") -> bool:
	if not (m is BaseMaterial3D) or exemption(m.resource_name, model_path) != "":
		return false
	var b := m as BaseMaterial3D
	var min_rough := float(config().get("min_roughness", 0.7))
	var changed := false
	if b.metallic_texture == null and b.metallic > 0.0:
		b.metallic = 0.0
		changed = true
	if is_glossy(m.resource_name):
		return changed
	if b.roughness_texture == null and b.roughness < min_rough:
		b.roughness = min_rough
		changed = true
	return changed


## Every surface material under `root` (overrides and the meshes' own). Returns how many
## distinct materials changed.
static func apply(root: Node, model_path := "") -> int:
	var done := {}
	var n := 0
	var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for mi in meshes:
		var mats: Array = [mi.material_override]
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				mats.append(mi.get_surface_override_material(i))
				mats.append(mi.mesh.surface_get_material(i))
		for m in mats:
			if m != null and not done.has(m):
				done[m] = true
				if fix_material(m, model_path):
					n += 1
	return n
