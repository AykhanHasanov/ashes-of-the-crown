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
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 0.04, 0.35) if look.get("shape", "") == "cloth" else Vector3(0.25, 0.25, 0.25)
	box.material = mat
	mi.mesh = box
	mi.position.y = 0.03
	add_child(mi)
	visible = not is_taken()
	EventBus.state_replaced.connect(func(): visible = not is_taken())


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
