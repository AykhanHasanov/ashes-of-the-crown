extends Node3D
## The iso game's root (iso/scenes/iso_game.tscn, the main scene on the iso-main branch).
## Milestone 1 — look and move: the world, its light, the camera, Aras and Rüfət.
##
## Keys for now (Milestone 4 replaces them with a debug panel):
##   WASD / left stick  move (screen-relative)      Shift / LT  walk ↔ run
##   Space / B          dash                         Z / wheel   zoom: explore ↔ close
##   N                  day ↔ night                  V           perspective ↔ orthographic
##   F9                 quality                      F3          FPS
## Capture: --demo=iso_capture saves the standard framings to captures/iso/ (iso_capture.gd).

const Human := preload("res://scripts/characters/human.gd")
const IsoWorld := preload("res://iso/scripts/world/iso_world.gd")
const IsoLighting := preload("res://iso/scripts/iso_lighting.gd")
const IsoCamera := preload("res://iso/scripts/iso_camera.gd")
const IsoPlayer := preload("res://iso/scripts/iso_player.gd")
const IsoFollower := preload("res://iso/scripts/iso_follower.gd")
const IsoKozkale := preload("res://iso/scripts/iso_kozkale.gd")
const IsoFootprints := preload("res://iso/scripts/iso_footprints.gd")
const IsoCapture := preload("res://iso/scripts/iso_capture.gd")
const IsoPerf := preload("res://iso/scripts/iso_perf.gd")
const Effects := preload("res://scripts/world/effects.gd")

var world
var lighting
var rig
var player
var rufet
var kozkale
var footprints
var _ash: GPUParticles3D
var _was_inside := true
var _fps_label: Label


func _ready() -> void:
	Human.tree_driven = true
	Human.warm_up()
	lighting = IsoLighting.new()
	add_child(lighting)
	world = IsoWorld.new()
	add_child(world)
	world.build()
	rig = IsoCamera.new()
	add_child(rig)
	rig.occluders = world.occluders
	rig.cutaway = world.cutaway
	rig.cut_roofs = world.cut_roofs
	player = IsoPlayer.new()
	add_child(player)
	player.global_position = world.player_spawn
	player.camera_rig = rig
	player.world = world
	player.face_towards(player.global_position + Vector3(-0.5, 0, -1))
	rig.target = player
	rig.snap()
	var cl := OmniLight3D.new()
	cl.name = "CharacterLight"
	cl.position = Vector3(0, 2.6, 0.4)
	cl.shadow_enabled = false
	cl.omni_attenuation = 1.4
	cl.light_specular = 0.2
	player.add_child(cl)
	lighting.character_light = cl
	rufet = IsoFollower.new()
	add_child(rufet)
	rufet.leader = player
	rufet.snap_behind()
	kozkale = IsoKozkale.new()
	add_child(kozkale)
	footprints = IsoFootprints.new()
	footprints.paved = Rect2(-IsoWorld.HALF, -IsoWorld.HALF, IsoWorld.HALF * 2, IsoWorld.HALF * 2)
	add_child(footprints)
	player.step.connect(func(at: Vector3, _r: bool): footprints.press(at, player.facing()))
	_ash = Effects.ash_fall(Vector3(26, 8, 26), 240)
	add_child(_ash)
	_fps_label = Label.new()
	_fps_label.position = Vector2(12, 8)
	_fps_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78, 0.8))
	var ui := CanvasLayer.new()
	ui.add_child(_fps_label)
	add_child(ui)
	Settings.changed.connect(_apply_quality)
	_apply_quality()
	_set_night(false)
	if Settings.demo == "iso_capture" or Settings.demo.begins_with("iso_shot") or Settings.demo == "iso_gif":
		var cap = IsoCapture.new()
		cap.game = self
		add_child(cap)
	elif Settings.demo == "iso_perf":
		var probe = IsoPerf.new()
		probe.game = self
		add_child(probe)


func _apply_quality() -> void:
	var high: bool = lighting.high()
	for f in world.fires:
		f.set_shadow(high or f == world.hearth)
	_ash.amount = 240 if high else 90


func _set_night(on: bool) -> void:
	lighting.set_night(on)
	world.set_night(on)
	kozkale.night = on
	for f in world.fires:
		f.daylight = not on


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_N:
				_set_night(not lighting.night)
			KEY_V:
				rig.toggle_projection()
			KEY_Z:
				rig.toggle_zoom()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			rig.set_zoom("close")
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rig.set_zoom("explore")


func _process(_delta: float) -> void:
	kozkale.reveal = rig.get("_pull")
	_ash.global_position = rig.get("_focus") + Vector3(0, 9, 0)
	# out through the gate: the lens pulls back and Közkale's glow comes up
	var inside: bool = world.calm_zone.has_point(player.global_position + Vector3(0, 0.5, 0))
	rig.cut_active = inside
	if _was_inside and not inside and player.global_position.z > IsoWorld.HALF:
		rig.pull_out()
	_was_inside = inside
	_fps_label.visible = Settings.show_fps
	if Settings.show_fps:
		_fps_label.text = "%d fps  ·  %s  ·  %s" % [Engine.get_frames_per_second(), Settings.quality_name(),
			"gece" if lighting.night else "gündüz"]
