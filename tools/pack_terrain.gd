extends SceneTree
## Dev tool: packs the Poly Haven source textures (assets/terrain/src, CC0, 1K) into
## the two images Terrain3D wants per ground type:
##   <id>_albedo_height.png  (RGB albedo, A height)
##   <id>_normal_rough.png   (RGB OpenGL normal, A roughness)
## and writes .import files (VRAM compressed + mipmaps). The list comes from
## data/balance/world.json → terrain.textures.
## Usage: godot --headless --path . -s tools/pack_terrain.gd   (then run --import)

const SRC := "res://assets/terrain/src/"
const OUT := "res://assets/terrain/"
const SIZE := 1024

const IMPORT := """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/high_quality=false
compress/normal_map=2
mipmaps/generate=true
detect_3d/compress_to=0
"""


func _init() -> void:
	var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/world.json"))
	for t in cfg["terrain"]["textures"]:
		var src: String = t["src"]
		var albedo := _load(src + "_albedo")
		var height := _load(src + "_height")
		var normal := _load(src + "_normal")
		var rough := _load(src + "_rough")
		var ah: Image = Terrain3DUtil.pack_image(albedo, height, false, false, true, 0)
		var nr: Image = Terrain3DUtil.pack_image(normal, rough, false, false, false, 0)
		_save(ah, "%s_albedo_height" % t["id"])
		_save(nr, "%s_normal_rough" % t["id"])
		print("packed ", t["id"])
	quit()


func _load(base: String) -> Image:
	for ext in [".jpg", ".png"]:
		var path := ProjectSettings.globalize_path(SRC + base + ext)
		if FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			img.convert(Image.FORMAT_RGBA8)
			if img.get_width() != SIZE:
				img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
			return img
	push_error("missing texture " + base)
	return Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)


func _save(img: Image, name: String) -> void:
	var path := ProjectSettings.globalize_path(OUT + name + ".png")
	img.save_png(path)
	var f := FileAccess.open(path + ".import", FileAccess.WRITE)
	f.store_string(IMPORT)
