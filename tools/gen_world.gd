extends SceneTree
## Builds the open world from its text sources (spec V3 §6.1):
##   data/world/world_layout.json + poi_rules.json + vegetation.json
##   → world/terrain/*.res      (Terrain3D regions: height, control, colour, instances)
##   → world/generated/world_meta.json   (POIs, roads, bridges, water, tree colliders)
##   → world/generated/map.png           (parchment map for the M screen)
## Usage: godot --headless --path . -s tools/gen_world.gd

const Generator := preload("res://scripts/world/gen/world_generator.gd")
const TerrainSetup := preload("res://scripts/world/terrain_setup.gd")
const GEN_DIR := "res://world/generated/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var veg := _json("res://data/world/vegetation.json")
	var gen = Generator.new(_json("res://data/world/world_layout.json"), _json("res://data/world/poi_rules.json"), veg)
	gen.generate()

	var terrain: Terrain3D = TerrainSetup.create(true, _json("res://data/balance/world.json"), veg)
	var assets: Terrain3DAssets = terrain.assets
	root.add_child(terrain)
	await process_frame
	terrain.assets = assets  # Terrain3D resets its asset list when it enters the tree
	print("[worldgen] mesh assets: ", terrain.assets.get_mesh_count())
	# Start from a clean directory so stale regions never survive a regeneration
	var abs_dir := ProjectSettings.globalize_path(TerrainSetup.DATA_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	for f in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(f))
	var t0 := Time.get_ticks_msec()
	terrain.data.import_images([gen.height_image(), gen.control_image(), gen.color_image()], Vector3.ZERO, 0.0, 1.0)
	print("[worldgen] imported maps in %d ms, regions: %d" % [Time.get_ticks_msec() - t0, terrain.data.get_region_count()])
	t0 = Time.get_ticks_msec()
	for i in gen.instances.size():
		var list: Array[Transform3D] = gen.instances[i]
		if not list.is_empty():
			terrain.instancer.add_transforms(i, list, [], false)
	terrain.instancer.update_mmis()
	print("[worldgen] instances added in %d ms" % (Time.get_ticks_msec() - t0))
	for loc in terrain.data.get_region_locations():
		terrain.data.set_region_modified(loc, true)
	terrain.data.save_directory(TerrainSetup.DATA_DIR)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GEN_DIR))
	var meta: Dictionary = gen.meta()
	var f := FileAccess.open(GEN_DIR + "world_meta.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	gen.map_image().save_png(ProjectSettings.globalize_path(GEN_DIR + "map.png"))
	print("[worldgen] saved: %s, %s" % [TerrainSetup.DATA_DIR, GEN_DIR])
	for p in meta["pois"]:
		print("  POI %-14s %-22s at (%.0f, %.1f, %.0f)" % [p["type"], p["name"], p["pos"][0], p["pos"][1], p["pos"][2]])
	quit()


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
