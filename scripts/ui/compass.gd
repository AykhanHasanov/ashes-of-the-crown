extends Control
## Compass strip at the top of the screen (spec V3 §10): cardinal directions, ticks,
## and markers for discovered places, lit hearths, the player's own map marker and
## the current objective. Bearings: 0 = north (-Z), 90 = east (+X).

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const WIDTH := 620.0
const HEIGHT := 40.0
const SPAN := deg_to_rad(110.0)     # visible arc
const CARDINALS := [[0.0, "KUZEY"], [90.0, "DOĞU"], [180.0, "GÜNEY"], [270.0, "BATI"]]
const COLORS := {
	"hearth": Color(1.0, 0.55, 0.22), "hearth_cold": Color(0.6, 0.5, 0.42),
	"place": Color(0.92, 0.84, 0.66), "marker": Color(0.45, 0.8, 1.0),
	"objective": Color(1.0, 0.85, 0.35), "danger": Color(0.95, 0.3, 0.25),
}

var heading := 0.0                  # radians, camera bearing
var markers: Array = []             # {bearing: float (rad), dist: float, kind: String, label: String}


func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	offset_top = 8
	offset_bottom = 8 + HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func bearing(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(d.x, -d.z)


func _process(_delta: float) -> void:
	queue_redraw()


func _x_for(b: float) -> float:
	var delta := wrapf(b - heading, -PI, PI)
	if absf(delta) > SPAN * 0.5:
		return -1.0
	return WIDTH * 0.5 + delta / SPAN * WIDTH


func _draw() -> void:
	var font := get_theme_default_font()
	# Backing with faded ends
	var steps := 24
	for i in steps:
		var t0 := float(i) / steps
		var edge := 1.0 - absf(t0 * 2.0 - 1.0)
		draw_rect(Rect2(t0 * WIDTH, 6, WIDTH / steps + 1, HEIGHT - 12), Color(0.03, 0.02, 0.015, 0.55 * minf(edge * 2.5, 1.0)))
	draw_line(Vector2(WIDTH * 0.5, 2), Vector2(WIDTH * 0.5, 9), UITheme.GOLD, 2.0)
	# Ticks every 15°
	for deg in range(0, 360, 15):
		var x := _x_for(deg_to_rad(deg))
		if x < 0.0:
			continue
		var a := _fade(x)
		var major := deg % 45 == 0
		draw_line(Vector2(x, HEIGHT - 12), Vector2(x, HEIGHT - (20 if major else 15)), Color(0.85, 0.78, 0.65, 0.7 * a), 1.5 if major else 1.0)
	for c in CARDINALS:
		var x := _x_for(deg_to_rad(c[0]))
		if x < 0.0:
			continue
		var a := _fade(x)
		var fs := 15
		var w := font.get_string_size(c[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(x - w * 0.5, 22), c[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UITheme.GOLD, a) if c[0] == 0.0 else Color(0.9, 0.86, 0.78, a))
	# Markers
	for m in markers:
		var x := _x_for(m["bearing"])
		if x < 0.0:
			continue
		var a := _fade(x)
		var col: Color = COLORS.get(m["kind"], Color.WHITE)
		col.a = a
		var y := HEIGHT - 6.0
		match m["kind"]:
			"hearth", "hearth_cold":
				draw_colored_polygon(PackedVector2Array([Vector2(x, y - 12), Vector2(x + 5, y - 3), Vector2(x, y), Vector2(x - 5, y - 3)]), col)
			"marker":
				draw_circle(Vector2(x, y - 6), 5.0, col)
				draw_circle(Vector2(x, y - 6), 2.0, Color(0, 0, 0, a))
			"objective":
				draw_colored_polygon(PackedVector2Array([Vector2(x - 6, y - 12), Vector2(x + 6, y - 12), Vector2(x, y - 2)]), col)
			_:
				draw_rect(Rect2(x - 3.5, y - 10, 7, 7), col)
		if m.get("dist", 0.0) > 0.0 and absf(x - WIDTH * 0.5) < 60.0:
			var label := "%s  %d m" % [m.get("label", ""), int(m["dist"])]
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(font, Vector2(x - w * 0.5, HEIGHT + 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.92, 0.88, 0.8, a))


func _fade(x: float) -> float:
	var e := 1.0 - absf(x / WIDTH * 2.0 - 1.0)
	return clampf(e * 3.0, 0.0, 1.0)
