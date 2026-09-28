extends Node
## Game-feel helpers shared by every actor: time control (hitstop and slow motion),
## camera shake and punch, floating damage numbers, notifications and one-shot
## visual effects (fire nova, sword slash, hit sparks, death bursts, dust).

signal notified(text: String)

const Effects := preload("res://scripts/world/effects.gd")

var camera_rig: Node
var world: Node3D

var _stop_until := 0
var _slow_until := 0
var _slow_scale := 1.0
## Open-ended slowdowns keyed by who asked (radial menu, Kül Şahı's offer).
var _holds := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	# Real-time clock so hitstop and slow motion never stretch themselves.
	var now := Time.get_ticks_msec()
	var scale := 1.0
	if now < _stop_until:
		scale = 0.03
	elif now < _slow_until:
		scale = _slow_scale
	for k in _holds:
		scale = minf(scale, _holds[k])
	Engine.time_scale = scale


func reset_time() -> void:
	_stop_until = 0
	_slow_until = 0
	_holds.clear()
	Engine.time_scale = 1.0


## Keeps time at `time_scale` until release_time(key).
func hold_time(key: String, time_scale: float) -> void:
	_holds[key] = time_scale


func release_time(key: String) -> void:
	_holds.erase(key)


## Freezes the game for `duration` real seconds — the weight of a hit.
func hitstop(duration: float) -> void:
	_stop_until = maxi(_stop_until, Time.get_ticks_msec() + int(duration * 1000.0))


## Slows time to `time_scale` for `duration` real seconds (kills, finishers).
func slowmo(time_scale: float, duration: float) -> void:
	_slow_scale = time_scale
	_slow_until = maxi(_slow_until, Time.get_ticks_msec() + int(duration * 1000.0))


func shake(amount: float) -> void:
	if is_instance_valid(camera_rig):
		camera_rig.add_trauma(amount * Settings.screen_shake)


## Quick zoom toward the action.
func punch(amount: float) -> void:
	if is_instance_valid(camera_rig):
		camera_rig.punch(amount * Settings.screen_shake)


func notify(text: String) -> void:
	notified.emit(text)


## Floating number above a hit. kind: "normal", "heavy", "ember".
func damage_number(pos: Vector3, amount: float, kind := "normal") -> void:
	if not is_instance_valid(world):
		return
	var label := Label3D.new()
	label.text = str(int(round(amount)))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0011
	label.font_size = 42 if kind == "normal" else 58
	label.outline_size = 12
	label.outline_modulate = Color(0.08, 0.02, 0.0, 0.9)
	match kind:
		"heavy":
			label.modulate = Color(1.0, 0.72, 0.3)
		"ember":
			label.modulate = Color(1.0, 0.42, 0.12)
		_:
			label.modulate = Color(1.0, 0.95, 0.88)
	var jitter := Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))
	_spawn_temp(label, pos + jitter, 1.0)
	var tw := label.create_tween().set_parallel()
	tw.tween_property(label, "position:y", label.position.y + 1.3, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	label.scale = Vector3.ONE * 1.6
	tw.tween_property(label, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.45)
	tw.tween_property(label, "outline_modulate:a", 0.0, 0.3).set_delay(0.45)


func fire_nova(pos: Vector3, radius: float) -> void:
	if not is_instance_valid(world):
		return
	var burst := Effects.burst(90, 16.0, 0.9, 0.45, true, Color(2.0, 0.8, 0.18))
	_spawn_temp(burst, pos + Vector3(0, 0.7, 0), 2.0)
	burst.emitting = true

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	ring.mesh = torus
	var ring_mat := Effects.additive_material(Color(1.0, 0.55, 0.15))
	ring.material_override = ring_mat
	_spawn_temp(ring, pos + Vector3(0, 0.3, 0), 1.0)
	ring.scale = Vector3(0.3, 0.3, 0.3)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(radius, 1.5, radius), 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring_mat, "albedo_color:a", 0.0, 0.5)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.18)
	light.omni_range = radius * 2.2
	light.light_energy = 12.0
	_spawn_temp(light, pos + Vector3(0, 1.5, 0), 1.0)
	light.create_tween().tween_property(light, "light_energy", 0.0, 0.7)


func slash(pos: Vector3, dir: Vector3, side: float, heavy := false) -> void:
	if not is_instance_valid(world):
		return
	var arc := MeshInstance3D.new()
	arc.mesh = Effects.arc_mesh(0.7, 2.9 if heavy else 2.5, 150.0 if heavy else 120.0)
	var mat := Effects.additive_material(Color(1.0, 0.55, 0.2) if heavy else Color(1.0, 0.7, 0.4))
	arc.material_override = mat
	_spawn_temp(arc, pos, 0.5)
	arc.rotation.y = atan2(-dir.x, -dir.z)
	arc.rotation.z = 0.25 * side
	var tw := arc.create_tween().set_parallel()
	tw.tween_property(arc, "rotation:y", arc.rotation.y - 0.5 * side, 0.16)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.2)


func hit_spark(pos: Vector3, heavy := false) -> void:
	if not is_instance_valid(world):
		return
	var p := Effects.burst(34 if heavy else 18, 9.0 if heavy else 7.0, 0.4, 0.2, false, Color(5.0, 2.2, 0.5))
	_spawn_temp(p, pos, 1.0)
	p.emitting = true
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.6, 0.3)
	flash.light_energy = 4.0 if heavy else 2.0
	flash.omni_range = 4.0
	_spawn_temp(flash, pos, 0.3)
	flash.create_tween().tween_property(flash, "light_energy", 0.0, 0.15)


func death_burst(pos: Vector3, size: float) -> void:
	if not is_instance_valid(world):
		return
	var ash := Effects.smoke_burst(int(40 * size), 3.5 * size, 1.4, 0.7 * size)
	_spawn_temp(ash, pos + Vector3(0, 1.0 * size, 0), 2.5)
	ash.emitting = true
	var sparks := Effects.burst(int(30 * size), 6.0, 0.8, 0.2, false, Color(5.0, 1.8, 0.4))
	_spawn_temp(sparks, pos + Vector3(0, 1.0 * size, 0), 2.0)
	sparks.emitting = true


## Köz Zərbəsi: a short cone of fire in front of the protagonist.
func ember_cone(pos: Vector3, dir: Vector3, reach: float) -> void:
	if not is_instance_valid(world):
		return
	var arc := MeshInstance3D.new()
	arc.mesh = Effects.arc_mesh(0.4, reach, 120.0, 20)
	var mat := Effects.additive_material(Color(1.0, 0.45, 0.12))
	arc.material_override = mat
	_spawn_temp(arc, pos + Vector3(0, 0.6, 0), 0.6)
	arc.rotation.y = atan2(-dir.x, -dir.z)
	arc.scale = Vector3(0.4, 1, 0.4)
	var tw := arc.create_tween().set_parallel()
	tw.tween_property(arc, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	var burst := Effects.burst(40, 10.0, 0.5, 0.35, true, Color(2.4, 1.0, 0.25))
	_spawn_temp(burst, pos + Vector3(0, 0.8, 0) + dir * 1.2, 1.2)
	burst.emitting = true


## Perfect dodge: a trail of ash where the protagonist was.
func ash_trail(pos: Vector3) -> void:
	if not is_instance_valid(world):
		return
	for i in 3:
		var p := Effects.smoke_burst(12, 1.2, 0.8, 0.6)
		_spawn_temp(p, pos + Vector3(randf_range(-0.3, 0.3), 0.8, randf_range(-0.3, 0.3)), 1.5)
		p.emitting = true


func ash_puff(pos: Vector3) -> void:
	if not is_instance_valid(world):
		return
	var p := Effects.smoke_burst(16, 2.0, 0.6, 0.5)
	_spawn_temp(p, pos + Vector3(0, 0.6, 0), 1.5)
	p.emitting = true


func _spawn_temp(node: Node3D, pos: Vector3, lifetime: float) -> void:
	world.add_child(node)
	node.global_position = pos
	get_tree().create_timer(lifetime, false).timeout.connect(node.queue_free)
