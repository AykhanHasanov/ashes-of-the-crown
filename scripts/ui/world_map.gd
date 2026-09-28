extends CanvasLayer
## The map screen [M] (spec V3 §10): the parchment map drawn by the generator, fog over
## unexplored ground, icons for discovered places and lit hearths, the protagonist's arrow and a
## marker the player places with right click (it also shows on the compass). Opened
## from a lit hearth it is in travel mode: clicking another lit hearth travels there.

signal travel_requested(poi_id: String)
signal marker_changed(pos: Variant)
signal closed

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const MAP := "res://world/generated/map.png"
const PAPER := Color(0.86, 0.79, 0.64)

var is_open := false
var travel_mode := false
var pois: Array = []
var world_size := 512.0
var player: Node3D
var marker: Variant = null          # Vector3 or null
var fog_cell := 16.0
var fog := PackedByteArray()        # 1 = explored
var fog_n := 32

var _root: Control
var _canvas: Control
var _tex: Texture2D
var _fog_tex: ImageTexture
var _hover := ""


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tex = load(MAP)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.build()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.01, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_map)
	_canvas.gui_input.connect(_on_input)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_canvas)
	_root.visible = false


func setup(meta: Dictionary, cell: float) -> void:
	pois = meta["pois"]
	world_size = meta["size"]
	fog_cell = cell
	fog_n = int(ceil(world_size / fog_cell))
	fog.resize(fog_n * fog_n)
	fog.fill(0)


func open(travel := false) -> void:
	travel_mode = travel
	is_open = true
	_root.visible = true
	_update_fog_tex()
	get_tree().paused = true
	Audio.play("ui_click", -6.0, 0.0)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("map") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _process(_delta: float) -> void:
	if is_open:
		_canvas.queue_redraw()


# --- Exploration fog --------------------------------------------------------------------------

func reveal(pos: Vector3, radius: float) -> bool:
	var changed := false
	var r := int(ceil(radius / fog_cell))
	var cx := int(pos.x / fog_cell)
	var cz := int(pos.z / fog_cell)
	for z in range(cz - r, cz + r + 1):
		for x in range(cx - r, cx + r + 1):
			if x < 0 or z < 0 or x >= fog_n or z >= fog_n:
				continue
			if Vector2(x + 0.5, z + 0.5).distance_to(Vector2(pos.x, pos.z) / fog_cell) * fog_cell <= radius:
				var k := z * fog_n + x
				if fog[k] == 0:
					fog[k] = 1
					changed = true
	return changed


func fog_to_string() -> String:
	return Marshalls.raw_to_base64(fog.compress(FileAccess.COMPRESSION_DEFLATE))


func fog_from_string(s: String) -> void:
	if s == "":
		return
	var raw := Marshalls.base64_to_raw(s).decompress(fog_n * fog_n, FileAccess.COMPRESSION_DEFLATE)
	if raw.size() == fog_n * fog_n:
		fog = raw


func explored_fraction() -> float:
	var n := 0
	for b in fog:
		n += b
	return float(n) / fog.size()


func _update_fog_tex() -> void:
	var img := Image.create_empty(fog_n, fog_n, false, Image.FORMAT_LA8)
	for z in fog_n:
		for x in fog_n:
			img.set_pixel(x, z, Color(1, 1, 1, 0.0 if fog[z * fog_n + x] == 1 else 1.0))
	if _fog_tex == null:
		_fog_tex = ImageTexture.create_from_image(img)
	else:
		_fog_tex.update(img)


# --- Drawing ----------------------------------------------------------------------------------

func _map_rect() -> Rect2:
	var vp := _canvas.size
	var side := minf(vp.y - 150.0, vp.x - 360.0)
	return Rect2(Vector2((vp.x - side) * 0.5, 80.0), Vector2(side, side))


func _to_screen(p: Vector3) -> Vector2:
	var r := _map_rect()
	return r.position + Vector2(p.x, p.z) / world_size * r.size


func _to_world(s: Vector2) -> Vector3:
	var r := _map_rect()
	var t := (s - r.position) / r.size
	return Vector3(t.x * world_size, 0, t.y * world_size)


func _draw_map() -> void:
	var font := _canvas.get_theme_default_font()
	var r := _map_rect()
	# Frame and parchment
	_canvas.draw_rect(r.grow(14), Color(0.3, 0.2, 0.12))
	_canvas.draw_rect(r.grow(10), Color(0.72, 0.62, 0.45))
	_canvas.draw_texture_rect(_tex, r, false)
	# Fog of the unexplored
	_canvas.draw_texture_rect(_fog_tex, r, false, PAPER)
	_canvas.draw_rect(r, Color(0.3, 0.2, 0.12), false, 2.0)
	# Title and legend
	var title := "KÜR VADİSİ"
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	_canvas.draw_string(font, Vector2(r.get_center().x - tw * 0.5, 58), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UITheme.GOLD)
	var help := "[M] kapat   ·   Sağ tık — işaret koy / sil" + ("   ·   Yanan ocağa tıkla — yolculuk" if travel_mode else "")
	var hw := font.get_string_size(help, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_canvas.draw_string(font, Vector2(r.get_center().x - hw * 0.5, r.end.y + 38), help, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UITheme.MUTED)
	var pct := "Keşif: %d%%" % int(explored_fraction() * 100.0)
	_canvas.draw_string(font, Vector2(r.end.x - 110, 58), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UITheme.MUTED)

	_hover = ""
	var mouse := _canvas.get_local_mouse_position()
	for p in pois:
		var known := WorldState.has_world_entry("discovered", p["id"])
		var is_hearth: bool = p["type"] == "hearth"
		var lit := is_hearth and WorldState.has_world_entry("hearths", p["id"])
		if not known and not lit:
			continue
		var s := _to_screen(Vector3(p["pos"][0], 0, p["pos"][2]))
		var col := Color(0.25, 0.14, 0.07)
		if is_hearth:
			col = Color(0.95, 0.45, 0.12) if lit else Color(0.4, 0.3, 0.22)
			_canvas.draw_colored_polygon(PackedVector2Array([s + Vector2(0, -11), s + Vector2(7, 2), s + Vector2(0, 7), s + Vector2(-7, 2)]), col)
			if lit:
				_canvas.draw_circle(s, 3.0, Color(1, 0.9, 0.5))
		else:
			_canvas.draw_rect(Rect2(s - Vector2(5, 5), Vector2(10, 10)), col)
			_canvas.draw_rect(Rect2(s - Vector2(3, 3), Vector2(6, 6)), Color(0.86, 0.72, 0.45))
		var over := mouse.distance_to(s) < 12.0
		if over:
			_hover = p["id"]
		var fs := 15 if over else 13
		var name_col := Color(0.18, 0.1, 0.05) if not over else Color(0.55, 0.15, 0.02)
		_canvas.draw_string(font, s + Vector2(10, 5), p["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, name_col)
	# Player marker
	if marker != null:
		var ms := _to_screen(marker)
		_canvas.draw_circle(ms, 7.0, Color(0.1, 0.35, 0.6))
		_canvas.draw_circle(ms, 3.0, Color(0.8, 0.95, 1.0))
	# The protagonist
	if is_instance_valid(player):
		var ps := _to_screen(player.global_position)
		var f: Vector3 = player.facing() if player.has_method("facing") else Vector3.FORWARD
		var ang := atan2(f.x, -f.z)
		var pts := PackedVector2Array()
		for v in [Vector2(0, -12), Vector2(7, 8), Vector2(0, 4), Vector2(-7, 8)]:
			pts.append(ps + v.rotated(ang))
		_canvas.draw_colored_polygon(pts, Color(0.75, 0.08, 0.05))
	# Travel hint under the cursor
	if travel_mode and _hover != "" and WorldState.has_world_entry("hearths", _hover):
		_canvas.draw_string(font, mouse + Vector2(14, -10), "Yolculuk et", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UITheme.EMBER)


func _on_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		var w := _to_world(event.position)
		if marker != null and _to_screen(marker).distance_to(event.position) < 12.0:
			marker = null
		elif _map_rect().has_point(event.position):
			marker = w
		marker_changed.emit(marker)
		Audio.play("ui_click", -8.0, 0.0)
	elif event.button_index == MOUSE_BUTTON_LEFT and travel_mode and _hover != "":
		if WorldState.has_world_entry("hearths", _hover):
			var id := _hover
			close()
			travel_requested.emit(id)
