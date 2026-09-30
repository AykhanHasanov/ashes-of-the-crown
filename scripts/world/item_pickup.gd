extends Node3D
## Something lying in the world that Aras can take (data/items/<id>.json): a placeholder
## look from the item's data, a prompt, and take(). Taken once for good: the pickup's stable
## key goes into WorldState's "pickups" list and the item into the inventory, so after a
## load it is gone from the ground and still in his hands. The mode shows the prompt and
## calls take() on interact.

const Names := preload("res://scripts/core/names.gd")

var key := ""                      # stable id of this spot, e.g. "kartal_yamaci/yazma"
var item_id := ""
var use_range := 1.8


func setup(pickup_key: String, item: String) -> void:
	key = pickup_key
	item_id = item


func _ready() -> void:
	add_to_group("pickups")
	var look: Dictionary = DataDB.item(item_id).get("look", {})
	var col: Array = look.get("color", [0.6, 0.6, 0.6])
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col[0], col[1], col[2])
	mat.roughness = 0.9
	match look.get("shape", ""):
		"rolled_cloth":
			_rolled_cloth(mat, look)
		_:
			var mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.45, 0.04, 0.35) if look.get("shape", "") == "cloth" else Vector3(0.25, 0.25, 0.25)
			box.material = mat
			mi.mesh = box
			mi.position.y = 0.03
			add_child(mi)
	visible = not is_taken()
	EventBus.state_replaced.connect(func(): visible = not is_taken())


## A cloth rolled up like a scroll (a folded headscarf): the roll, two embroidered bands and
## a loose end lying on the stone. Placeholder look from data ("look": {"shape": "rolled_cloth"}).
func _rolled_cloth(mat: StandardMaterial3D, look: Dictionary) -> void:
	var r := 0.055
	var length := 0.36
	var roll := MeshInstance3D.new()
	roll.name = "Roll"
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = length
	cyl.radial_segments = 14
	cyl.material = mat
	roll.mesh = cyl
	roll.rotation.z = PI * 0.5   # lying on its side
	roll.position.y = r
	add_child(roll)
	var band_col: Array = look.get("band_color", [0.85, 0.62, 0.22])
	var band := StandardMaterial3D.new()
	band.albedo_color = Color(band_col[0], band_col[1], band_col[2])
	band.roughness = 0.8
	for x in [-0.12, 0.12]:
		var b := MeshInstance3D.new()
		var bc := CylinderMesh.new()
		bc.top_radius = r + 0.004
		bc.bottom_radius = r + 0.004
		bc.height = 0.025
		bc.radial_segments = 14
		bc.material = band
		b.mesh = bc
		b.rotation.z = PI * 0.5
		b.position = Vector3(x, r, 0)
		add_child(b)
	var tail := MeshInstance3D.new()
	tail.name = "LooseEnd"
	var tb := BoxMesh.new()
	tb.size = Vector3(length * 0.8, 0.008, 0.16)
	tb.material = mat
	tail.mesh = tb
	tail.position = Vector3(0.02, 0.005, r + 0.07)
	tail.rotation.y = 0.12
	add_child(tail)


func is_taken() -> bool:
	return WorldState.has_world_entry("pickups", key)


func name_text() -> String:
	return tr(DataDB.item(item_id).get("name_key", item_id))


func prompt() -> String:
	return "" if is_taken() else tr("ITEM_PROMPT_TAKE") % name_text()


func take() -> bool:
	if is_taken():
		return false
	WorldState.add_world_entry("pickups", key)
	WorldState.add_item(StringName(item_id))
	Audio.play("ui_select", -6.0, 0.0)
	visible = false
	return true
