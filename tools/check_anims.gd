extends SceneTree
## Dev tool: checks that every animation clip named in data/weapons and data/enemies
## (and Ayxan's hard-coded clips) exists in the model that plays it.
## Usage: godot --headless --path . -s tools/check_anims.gd

const AYXAN_MODEL := "res://assets/characters/adventurers/Rogue_Hooded.glb"
const AYXAN_CLIPS := [
	"Block_Attack", "Block_Hit", "Blocking", "Death_A", "Hit_A", "Hit_B", "Jump_Land",
	"Jump_Start", "Jump_Idle", "Lie_Down", "Lie_Idle", "Lie_StandUp", "Spellcast_Raise",
	"Spellcast_Shoot", "Use_Item", "Running_Strafe_Right", "Running_Strafe_Left",
	"Walking_A", "Walking_Backwards", "Running_A", "Idle", "Dodge_Forward",
	"Dodge_Backward", "Dodge_Left", "Dodge_Right",
]

var _missing := 0


func _init() -> void:
	var ayxan := _clips(AYXAN_MODEL)
	_expect("Ayxan", ayxan, AYXAN_CLIPS)
	for f in DirAccess.get_files_at("res://data/weapons"):
		var w: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons/" + f))
		var names := []
		_collect(w, names)
		_expect("weapon " + f, ayxan, names)
	for f in DirAccess.get_files_at("res://data/enemies"):
		var e: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies/" + f))
		var names := []
		_collect(e["anims"], names)
		_collect(e["attacks"], names)
		_expect("enemy " + f, _clips(e["model"]["path"]), names)
	print("ANIM CHECK DONE, missing: ", _missing)
	quit()


func _clips(path: String) -> PackedStringArray:
	var s: Node = load(path).instantiate()
	var ap: AnimationPlayer = s.find_children("*", "AnimationPlayer", true, false)[0]
	var out := ap.get_animation_list()
	s.free()
	return out


## Gathers every string under a key named clip/windup_clip or inside an anims block.
func _collect(v, out: Array, key := "") -> void:
	if v is Dictionary:
		for k in v:
			_collect(v[k], out, k)
	elif v is Array:
		for x in v:
			_collect(x, out, key)
	elif v is String and v != "" and (key.contains("clip") or key in ["idle", "walk", "run", "hit", "stagger", "recover", "death", "spawn", "block", "move", "strafe", "back"]):
		if not out.has(v):
			out.append(v)


func _expect(who: String, have: PackedStringArray, names: Array) -> void:
	for n in names:
		if not have.has(n):
			print("MISSING  ", who, ": ", n)
			_missing += 1
