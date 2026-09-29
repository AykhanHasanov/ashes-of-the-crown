extends RefCounted
## The project's material rule for models: what is not metal is not metallic
## (metallic 0) and not glossy (roughness >= MIN_ROUGHNESS). Quaternius exports give most
## surfaces metallic 0.4 / roughness 0.42, which read as wet plastic and turned chrome-white
## under global illumination. Applied at import (tools/import/material_policy_import.gd,
## set as the glTF import script) and to baked foliage (tools/fix_materials.gd).
## Texture-driven values are left alone: an ORM / metallic texture already says which few
## pixels are metal (buckles, rivets). Real metal and eyes keep their values (by name).
## Use: const MaterialPolicy := preload("res://scripts/core/material_policy.gd")

const MIN_ROUGHNESS := 0.7
const METAL_HINTS := ["metal", "iron", "steel", "sword", "blade", "axe", "gold", "silver", "copper", "bronze",
	"chain", "armor", "armour", "helmet", "nail", "lantern", "hinge", "ornament", "coin", "weapon", "anvil"]
const GLOSSY_HINTS := ["eye", "water", "glass"]


static func _has(name: String, hints: Array) -> bool:
	var n := name.to_lower()
	return hints.any(func(h): return n.contains(h))


## Fixes one material in place; returns true if it changed. Decided by the MATERIAL's name
## only: an atlas shared by a knight's cloth and his sword ("knight_texture") is not metal.
## Glass, water and eyes are not metal either, but they stay glossy.
static func fix_material(m: Material) -> bool:
	if not (m is BaseMaterial3D) or _has(m.resource_name, METAL_HINTS):
		return false
	var b := m as BaseMaterial3D
	var changed := false
	if b.metallic_texture == null and b.metallic > 0.0:
		b.metallic = 0.0
		changed = true
	if _has(m.resource_name, GLOSSY_HINTS):
		return changed
	if b.roughness_texture == null and b.roughness < MIN_ROUGHNESS:
		b.roughness = MIN_ROUGHNESS
		changed = true
	return changed


## Every surface material under `root` (overrides and the meshes' own). Returns how many
## distinct materials changed.
static func apply(root: Node) -> int:
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
				if fix_material(m):
					n += 1
	return n
