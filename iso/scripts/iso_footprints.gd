extends Node3D
## Footprints in the ash. Every step Aras takes on open ground presses a print into it — a
## decal of darker earth showing through — and the prints fade over half a minute as the ash
## keeps falling. A fixed pool, reused oldest first. Nothing is printed on the courtyard's
## flagstones (they are swept).

const POOL := 60
const LIFE := 30.0

var paved := Rect2()          # x/z of the flagged court: no prints there
var _decals: Array = []
var _born: Array = []
var _next := 0
var _tex: Texture2D


func _ready() -> void:
	_tex = _print_texture()
	for i in POOL:
		var d := Decal.new()
		d.size = Vector3(0.17, 0.4, 0.3)
		d.texture_albedo = _tex
		d.modulate = Color(0.14, 0.12, 0.11, 0.0)
		d.albedo_mix = 0.85
		d.upper_fade = 0.3
		d.lower_fade = 0.3
		d.visible = false
		add_child(d)
		_decals.append(d)
		_born.append(-1000.0)


## A print where a foot came down, turned the way he was walking.
func press(at: Vector3, facing: Vector3) -> void:
	if paved.has_point(Vector2(at.x, at.z)):
		return
	var d: Decal = _decals[_next]
	d.global_position = Vector3(at.x, 0.05, at.z)
	d.rotation = Vector3(0, atan2(-facing.x, -facing.z), 0)
	d.visible = true
	_born[_next] = Time.get_ticks_msec() / 1000.0
	_next = (_next + 1) % POOL


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for i in POOL:
		var d: Decal = _decals[i]
		if not d.visible:
			continue
		var age: float = now - float(_born[i])
		if age > LIFE:
			d.visible = false
			continue
		d.modulate.a = 0.75 * (1.0 - age / LIFE)


## A boot print: a rounded sole and a separate heel, soft at the edges.
func _print_texture() -> Texture2D:
	var w := 32
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u := (x + 0.5) / w - 0.5
			var v := (y + 0.5) / h
			var sole := 1.0 - smoothstep(0.85, 1.0, pow(u / 0.42, 2.0) + pow((v - 0.33) / 0.3, 2.0))
			var heel := 1.0 - smoothstep(0.8, 1.0, pow(u / 0.36, 2.0) + pow((v - 0.8) / 0.16, 2.0))
			var a := maxf(sole, heel)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
