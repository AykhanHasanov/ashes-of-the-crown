extends SceneTree
## Dev tool: assembles village houses from the Medieval Village MegaKit modules
## (data/world/houses.json): walls on a 2 m grid, a door and windows with open
## shutters, brick corners, a tiled roof with brick gables, a chimney. The pieces are
## then merged into one mesh per material (≈8 draw calls a house instead of ~60) with
## automatic LODs, and saved to assets/buildings/<id>.scn.
## Usage: godot --headless --path . -s tools/build_houses.gd

const KIT := "res://assets/village_mk/%s.gltf"
const OUT := "res://assets/buildings/"
const STOREY := 3.0
var WINDOW: ShaderMaterial
## Wall modules per family: [plain, door, wide window, thin window]
const FAMILY := {
	"UnevenBrick": ["Wall_UnevenBrick_Straight", "Wall_UnevenBrick_Door_Round", "Wall_UnevenBrick_Window_Wide_Round", "Wall_UnevenBrick_Window_Thin_Round"],
	"Plaster": ["Wall_Plaster_Straight", "Wall_Plaster_Door_Round", "Wall_Plaster_Window_Wide_Round", "Wall_Plaster_Window_Thin_Round"],
	"WoodGrid": ["Wall_Plaster_WoodGrid", "Wall_Plaster_Door_Round", "Wall_Plaster_Window_Wide_Round", "Wall_Plaster_Window_Thin_Round"],
}

var rng := RandomNumberGenerator.new()
var _cache := {}


func _init() -> void:
	WINDOW = ShaderMaterial.new()
	WINDOW.shader = load("res://shaders/window_glow.gdshader")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/houses.json"))
	for id in data["houses"]:
		var house := _assemble(data["houses"][id])
		var mesh := _merge(house)
		_save(id, mesh, house.get_meta("chimney", null))
		house.free()
	for k in _cache:
		(_cache[k] as Node).free()
	quit()


func _assemble(cfg: Dictionary) -> Node3D:
	rng.seed = int(cfg.get("seed", 1))
	var root := Node3D.new()
	var w: int = cfg["w"]
	var d: int = cfg["d"]
	var floors: int = cfg["floors"]
	var hw := float(w)   # half width in metres (w modules × 2 m / 2)
	var hd := float(d)
	var door_at := rng.randi_range(0, w - 1)
	for f in floors:
		var fam: Array = FAMILY[cfg["lower"] if f == 0 else cfg["upper"]]
		var y := f * STOREY
		# [side, count, centre of segment i, rotation]: +Z of a wall module faces outside
		var sides := [
			[w, func(i): return Vector3(-hw + 1 + 2 * i, y, hd), 0.0, true],
			[w, func(i): return Vector3(hw - 1 - 2 * i, y, -hd), PI, false],
			[d, func(i): return Vector3(hw, y, hd - 1 - 2 * i), PI * 0.5, false],
			[d, func(i): return Vector3(-hw, y, -hd + 1 + 2 * i), -PI * 0.5, false],
		]
		for side in sides:
			for i in int(side[0]):
				var pos: Vector3 = side[1].call(i)
				var rot: float = side[2]
				var kind := 0
				if f == 0 and side[3] and i == door_at:
					kind = 1
				elif rng.randf() < (0.55 if f > 0 else 0.4):
					kind = 2 if rng.randf() < 0.65 else 3
				_put(root, fam[kind], pos, rot)
				if kind == 1:
					_put(root, "Door_1_Round", pos + Vector3(-0.55, 0, 0).rotated(Vector3.UP, rot), rot)
				elif kind >= 2:
					var sz := "Wide" if kind == 2 else "Thin"
					_put(root, "Window_%s_Round1" % sz, pos, rot)
					_put(root, "WindowShutters_%s_Round_%s" % [sz, "Open" if rng.randf() < 0.7 else "Closed"], pos, rot)
		# Quoins: stone on the ground storey (and all of a stone tower), timber posts
		# above; the stone corner is ~3k triangles, so it goes only where it shows
		var stone: bool = f == 0 or cfg["upper"] == "UnevenBrick"
		for c in [Vector3(hw, y, hd), Vector3(-hw, y, hd), Vector3(-hw, y, -hd), Vector3(hw, y, -hd)]:
			_put(root, "Corner_Exterior_Brick" if stone else "Corner_Exterior_Wood", c, atan2(c.x, c.z) - PI * 0.25)
	var top := floors * STOREY
	# Roof: ridge along Z, gables at the two short ends
	_put(root, "Roof_RoundTiles_%dx%d" % [w * 2, d * 2], Vector3(0, top, 0), 0.0)
	_put(root, "Roof_Front_Brick%d" % (w * 2), Vector3(0, top, hd), 0.0)
	_put(root, "Roof_Front_Brick%d" % (w * 2), Vector3(0, top, -hd), PI)
	if cfg.get("chimney", false):
		_put(root, "Prop_Chimney", Vector3(hw * 0.45, top + 0.6, -hd * 0.45), 0.0)
		root.set_meta("chimney", Vector3(hw * 0.45, top + 0.6 + 3.1, -hd * 0.45))
	return root


func _put(root: Node3D, piece: String, pos: Vector3, rot_y: float) -> void:
	if not _cache.has(piece):
		var path := KIT % piece
		if not ResourceLoader.exists(path):
			push_warning("missing kit piece " + piece)
			return
		_cache[piece] = load(path).instantiate()
	var n: Node3D = (_cache[piece] as Node3D).duplicate()
	n.position = pos
	n.rotation.y = rot_y
	root.add_child(n)


## One surface per material across every piece.
func _merge(house: Node3D) -> ArrayMesh:
	var tools := {}   # material name → SurfaceTool (every glTF brings its own copy of MI_Brick...)
	var mats := {}
	for mi: MeshInstance3D in house.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()
		var n: Node = mi
		while n != house:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			var key: String = mat.resource_name if mat != null and mat.resource_name != "" else str(mat)
			if not tools.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[key] = st
				mats[key] = mat
			(tools[key] as SurfaceTool).append_from(mi.mesh, s, xf)
	var im := ImporterMesh.new()
	for mat in tools:
		var st: SurfaceTool = tools[mat]
		st.index()
		var m: Material = mats[mat]
		if mat == "MI_WindowGlass":
			m = WINDOW   # lit from inside at night
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays(), [], {}, m)
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()


func _save(id: String, mesh: ArrayMesh, chimney) -> void:
	var root := MeshInstance3D.new()
	root.name = id
	root.mesh = mesh
	if chimney != null:
		root.set_meta("chimney", chimney)   # the world puts hearth smoke here
	var scene := PackedScene.new()
	scene.pack(root)
	var err := ResourceSaver.save(scene, OUT + id + ".scn")
	var tris := 0
	for s in mesh.get_surface_count():
		tris += mesh.surface_get_array_index_len(s) / 3
	print("%-12s %s  %d surfaces, %d tris (err %d)" % [id, mesh.get_aabb().size.snapped(Vector3.ONE * 0.1), mesh.get_surface_count(), tris, err])
	root.free()
