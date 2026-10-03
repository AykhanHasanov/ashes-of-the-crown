extends RefCounted
## The iso world's building kit, generated in code so that everything in it is one style:
## flat-roofed stone, pointed (sivri) arches, deep doorways, protruding roof beams — the
## Xınalıq / Lahıc vocabulary from the art direction, and nothing from a European kit.
##
## Every piece is plain geometry wearing an IsoPalette material; the look comes from the
## shared surface shader and the lighting, not from detail in the meshes. Walls with openings
## are a 2D outline (the wall minus its pointed openings) extruded through the wall's
## thickness, so a whole arcade is one mesh. Static pieces get a matching collision body.
##
## Units are metres. A wall is built along +X from its origin, standing on y = 0, with its
## thickness centred on z = 0; rotate and place the returned node.

const IsoPalette := preload("res://iso/scripts/world/iso_palette.gd")

const ARCH_SEGMENTS := 9


# --- Shapes --------------------------------------------------------------------------------

## A pointed arch opening `w` wide whose sides rise straight to `spring` and then close in two
## arcs to a point (the equilateral sivri arch: each arc is centred on the far springing
## point). Points run anticlockwise from the bottom left; the bottom edge is open ground.
static func pointed_opening(x: float, w: float, spring: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var half := w * 0.5
	var cx := x + half
	pts.append(Vector2(cx + half, -0.01))
	pts.append(Vector2(cx + half, spring))
	# right arc: centred on the left springing point, from the right springing up to the apex
	var r := w
	var a0 := 0.0
	var a1 := deg_to_rad(60.0)
	for i in range(1, ARCH_SEGMENTS + 1):
		var a := lerpf(a0, a1, float(i) / ARCH_SEGMENTS)
		pts.append(Vector2(cx - half + cos(a) * r, spring + sin(a) * r))
	# left arc: centred on the right springing point, from the apex down to the left springing
	for i in range(1, ARCH_SEGMENTS + 1):
		var a := lerpf(deg_to_rad(120.0), deg_to_rad(180.0), float(i) / ARCH_SEGMENTS)
		pts.append(Vector2(cx + half + cos(a) * r, spring + sin(a) * r))
	pts.append(Vector2(cx - half, -0.01))
	return pts


## How tall a pointed opening of width `w` is, from the ground to its apex.
static func opening_height(w: float, spring: float) -> float:
	return spring + w * sin(deg_to_rad(60.0))


# --- Meshes --------------------------------------------------------------------------------

## A flat 2D outline (no holes) extruded `depth` metres along Z, centred on z = 0.
static func extrude(outline: PackedVector2Array, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := Geometry2D.triangulate_polygon(outline)
	var hz := depth * 0.5
	# front (+z) and back (-z)
	for side in [1.0, -1.0]:
		st.set_normal(Vector3(0, 0, side))
		var i := 0
		while i + 2 < tris.size():
			var a := outline[tris[i]]
			var b := outline[tris[i + 1]]
			var c := outline[tris[i + 2]]
			# Godot's front faces wind clockwise as seen from outside; the triangulation comes
			# back in the outline's own (anticlockwise) order, so the +z cap is reversed
			var ccw_tri := Geometry2D.is_polygon_clockwise(PackedVector2Array([a, b, c])) == false
			var p0 := a
			var p1 := c if ccw_tri else b
			var p2 := b if ccw_tri else c
			if side > 0.0:
				st.add_vertex(Vector3(p0.x, p0.y, hz))
				st.add_vertex(Vector3(p1.x, p1.y, hz))
				st.add_vertex(Vector3(p2.x, p2.y, hz))
			else:
				st.add_vertex(Vector3(p0.x, p0.y, -hz))
				st.add_vertex(Vector3(p2.x, p2.y, -hz))
				st.add_vertex(Vector3(p1.x, p1.y, -hz))
			i += 3
	# the sides: one quad per outline edge
	var ccw := not Geometry2D.is_polygon_clockwise(outline)
	for k in outline.size():
		var p := outline[k]
		var q := outline[(k + 1) % outline.size()]
		var e := (q - p)
		if e.length() < 0.0001:
			continue
		var n2 := Vector2(e.y, -e.x).normalized() if ccw else Vector2(-e.y, e.x).normalized()
		var n := Vector3(n2.x, n2.y, 0.0)
		st.set_normal(n)
		var v0 := Vector3(p.x, p.y, hz)
		var v1 := Vector3(q.x, q.y, hz)
		var v2 := Vector3(q.x, q.y, -hz)
		var v3 := Vector3(p.x, p.y, -hz)
		# wound so the outward normal side is the front (clockwise from outside)
		if ccw:
			st.add_vertex(v0); st.add_vertex(v1); st.add_vertex(v2)
			st.add_vertex(v0); st.add_vertex(v2); st.add_vertex(v3)
		else:
			st.add_vertex(v0); st.add_vertex(v3); st.add_vertex(v2)
			st.add_vertex(v0); st.add_vertex(v2); st.add_vertex(v1)
	return st.commit()


## A wall `length` long and `height` tall with pointed openings cut through it. Each opening
## is {"x": left edge, "w": width, "spring": height where the arch starts}.
static func arch_wall(length: float, height: float, thickness: float, openings: Array, mat: String) -> Node3D:
	var outline := PackedVector2Array([Vector2(0, 0), Vector2(length, 0), Vector2(length, height), Vector2(0, height)])
	for o in openings:
		var hole := pointed_opening(float(o["x"]), float(o["w"]), float(o["spring"]))
		var cut := Geometry2D.clip_polygons(outline, hole)
		if cut.is_empty():
			continue
		# keep the biggest piece: an opening at the ground never leaves a hole, so there is one
		var best: PackedVector2Array = cut[0]
		for c in cut:
			if absf(_area(c)) > absf(_area(best)):
				best = c
		outline = best
	return mesh_node(extrude(outline, thickness), mat, true)


static func _area(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


## A mesh in a node, with a collision body made from the same mesh when `solid`.
static func mesh_node(mesh: Mesh, mat: String, solid: bool) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = IsoPalette.get_mat(mat)
	root.add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		body.add_child(cs)
		root.add_child(body)
	return root


## A box, solid unless told otherwise. Position is its centre.
static func box(size: Vector3, mat: String, pos: Vector3, solid := true) -> Node3D:
	var bm := BoxMesh.new()
	bm.size = size
	var root := Node3D.new()
	root.position = pos
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = IsoPalette.get_mat(mat)
	root.add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
		root.add_child(body)
	return root


## A faceted low-poly rock: a coarse sphere, squashed, pushed about per vertex and flat
## shaded, so it has the same hard-edged simplicity as the buildings. Different every seed.
static func rock(size: Vector3, seed: int, mat := "rubble") -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var sm := SphereMesh.new()
	sm.radial_segments = 7
	sm.rings = 4
	sm.radius = 0.5
	sm.height = 1.0
	var arrays := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# the same jitter for vertices that share a position, or the faceting tears open
	var moved := {}
	for i in verts.size():
		var key := Vector3i(roundi(verts[i].x * 1000.0), roundi(verts[i].y * 1000.0), roundi(verts[i].z * 1000.0))
		if not moved.has(key):
			moved[key] = verts[i] * rng.randf_range(0.78, 1.18)
		var v: Vector3 = moved[key]
		verts[i] = Vector3(v.x * size.x, maxf(v.y, -0.15) * size.y, v.z * size.z)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in idx.size():
		st.add_vertex(verts[idx[i]])
	st.generate_normals()      # flat: no smoothing groups, every face its own
	var mesh := st.commit()
	var n := mesh_node(mesh, mat, true)
	n.rotation.y = rng.randf() * TAU
	return n


# --- Pieces ----------------------------------------------------------------------------------

## A flat-roofed stone house: plastered walls on a dark stone plinth, an earth roof with a low
## parapet, roof beams poking out of the wall under it, a deep pointed doorway on its front
## (+Z) face and a couple of small dark windows. `open` leaves the door gaping.
static func house(w: float, d: float, h: float, door_at := 0.5, windows := 2, ruined := false) -> Node3D:
	var root := Node3D.new()
	var t := 0.45
	var door_w := 1.15
	var door_x := clampf(w * door_at - door_w * 0.5, 0.6, w - door_w - 0.6)
	var wall_h := h if not ruined else h * 0.62
	# front wall with the doorway; back and sides plain
	var front := arch_wall(w, wall_h, t, [{"x": door_x, "w": door_w, "spring": 1.55}], "plaster")
	front.position = Vector3(-w * 0.5, 0, d * 0.5 - t * 0.5)
	root.add_child(front)
	root.add_child(box(Vector3(w, wall_h, t), "plaster", Vector3(0, wall_h * 0.5, -d * 0.5 + t * 0.5)))
	for side in [-1.0, 1.0]:
		var sh := wall_h if not ruined or side < 0.0 else wall_h * 0.6
		root.add_child(box(Vector3(t, sh, d - t * 2.0), "plaster", Vector3(side * (w * 0.5 - t * 0.5), sh * 0.5, 0)))
	# the plinth and the lower walls: dressed stone to the sill, as the Lahıc houses are
	root.add_child(box(Vector3(w + 0.16, 0.55, d + 0.16), "stone_dark", Vector3(0, 0.27, 0), false))
	for zf in [1.0, -1.0]:
		root.add_child(box(Vector3(w + 0.06, 1.25, 0.08), "stone", Vector3(0, 0.62, zf * (d * 0.5 + 0.02)), false))
	for xf in [1.0, -1.0]:
		root.add_child(box(Vector3(0.08, 1.25, d + 0.06), "stone", Vector3(xf * (w * 0.5 + 0.02), 0.62, 0), false))
	# what is inside the doorway: dark
	var void_h := opening_height(door_w, 1.55) - 0.05
	root.add_child(box(Vector3(door_w - 0.04, void_h, 0.06), "void", Vector3(door_x + door_w * 0.5 - w * 0.5, void_h * 0.5, d * 0.5 - t + 0.02), false))
	if not ruined:
		# the flat roof, its parapet, and the ends of the beams it rests on
		root.add_child(box(Vector3(w + 0.3, 0.32, d + 0.3), "roof", Vector3(0, h + 0.16, 0)))
		root.add_child(box(Vector3(w + 0.3, 0.32, 0.18), "roof", Vector3(0, h + 0.48, d * 0.5 + 0.06), false))
		root.add_child(box(Vector3(w + 0.3, 0.32, 0.18), "roof", Vector3(0, h + 0.48, -d * 0.5 - 0.06), false))
		var n := int(w / 0.75)
		for i in n:
			var x := -w * 0.5 + 0.4 + i * (w - 0.8) / maxf(n - 1, 1)
			root.add_child(box(Vector3(0.14, 0.14, 0.5), "wood", Vector3(x, h - 0.12, d * 0.5 + 0.1), false))
	else:
		# a fallen roof: beams down inside, rubble against the walls
		root.add_child(box(Vector3(0.16, 0.16, d * 0.9), "wood", Vector3(-w * 0.15, wall_h * 0.5, 0), false))
		root.get_child(-1).rotation_degrees = Vector3(28, 0, 9)
		for i in 5:
			root.add_child(box(Vector3(0.6, 0.35, 0.5), "rubble", Vector3(-w * 0.4 + i * w * 0.2, 0.18, d * 0.3 - i * 0.2), false))
	for i in windows:
		var wx := -w * 0.5 + (i + 1) * w / (windows + 1)
		if absf(wx - (door_x + door_w * 0.5 - w * 0.5)) < 1.0:
			continue
		root.add_child(box(Vector3(0.45, 0.6, 0.06), "void", Vector3(wx, wall_h * 0.62, d * 0.5 + 0.01), false))
	return root


## A carved wooden door in a deep stone frame: a plank leaf with a raised lozenge pattern,
## under a pointed stone tympanum. Built facing +Z; the leaf is the first child named "Leaf"
## (hinged on its left edge) so a door view can swing it.
static func carved_door(w := 1.1, h := 2.1) -> Node3D:
	var root := Node3D.new()
	var hinge := Node3D.new()
	hinge.name = "Leaf"
	hinge.position = Vector3(-w * 0.5, 0, 0)
	root.add_child(hinge)
	var leaf := box(Vector3(w, h, 0.09), "wood_carved", Vector3(w * 0.5, h * 0.5, 0), false)
	hinge.add_child(leaf)
	# the carving: two lozenges and a frame of studs, raised a finger off the planks
	for y in [h * 0.32, h * 0.7]:
		var lz := box(Vector3(0.34, 0.34, 0.04), "wood", Vector3(w * 0.5, y, 0.06), false)
		lz.rotation_degrees = Vector3(0, 0, 45)
		hinge.add_child(lz)
	for y in [0.15, h - 0.15]:
		hinge.add_child(box(Vector3(w - 0.12, 0.07, 0.04), "wood", Vector3(w * 0.5, y, 0.06), false))
	hinge.add_child(box(Vector3(0.05, 0.05, 0.06), "iron", Vector3(w * 0.82, h * 0.48, 0.08), false))
	# the stone frame and the pointed tympanum over the lintel
	var frame_w := w + 0.5
	var tym := arch_wall(frame_w, h + 0.9, 0.5, [{"x": 0.25, "w": w, "spring": h}], "stone")
	tym.position = Vector3(-frame_w * 0.5, 0, -0.18)
	root.add_child(tym)
	# the pointed space over the leaf is dark: the room behind, not daylight through a hole
	var top := opening_height(w, h) - h
	root.add_child(box(Vector3(w, top + 0.05, 0.05), "void", Vector3(0, h + top * 0.5, -0.36), false))
	return root
