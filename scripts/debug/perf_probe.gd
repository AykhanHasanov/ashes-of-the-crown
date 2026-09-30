extends Node
## Measuring tool (no game code): loads one game scene and measures it, vsync off.
##   - frame rate: mean, median, 1 % low;  draw calls, visible objects, primitives, VRAM;
##   - CPU vs GPU: process / physics time, the viewport's measured render time (CPU and GPU),
##     and the frame rate at half 3D resolution (a fill-rate test);
##   - what costs what: every category (sun shadows, point lights, particles, characters,
##     terrain, water, streamed places, screen effects...) and every big child of the level is
##     hidden or switched off in turn and the median frame time is measured again;
##   - what is in the scene: mesh instances, MultiMesh instances, lights, particle systems,
##     materials, triangles;
##   - the first seconds after the scene comes up: every hitch (a frame over 50 ms) with its
##     time, and whether it comes back on a second entry (PERF_REENTER=1).
## One scene and preset per run; it prints one line "PERF_JSON {...}" (docs/PERF_PROFILE.md
## is written from those). Run on a clean profile so nothing is saved over the player's files:
##   APPDATA="<empty folder>" PERF_SCENE=world|hub|kartal [PERF_SPOT=village] [PERF_REENTER=1] [PERF_FAST=1] \
##     "$G" --path . res://scenes/tests/perf_probe.tscn -- --demo=perf --quality=low|medium

const SCENES := {"world": "res://scenes/world.tscn", "hub": "res://scenes/son_ocaq.tscn", "kartal": "res://scenes/kartal_yamaci.tscn"}
const SETTLE := 4.0
const MEASURE := 8.0
const TOGGLE_SETTLE := 0.8
const TOGGLE_MEASURE := 2.5
const HITCH_MS := 50.0

var out := {}
var _rid: RID


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dummy := Node.new()
	get_tree().root.add_child.call_deferred(dummy)
	_start.call_deferred(dummy)


func _start(dummy: Node) -> void:
	get_tree().current_scene = dummy
	# No keyboard or mouse at all: the window takes the focus, and keys typed elsewhere must
	# not walk him away or press [E] at a gate in the middle of a measurement
	for action in InputMap.get_actions():
		InputMap.action_erase_events(action)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_rid, true)
	var key := OS.get_environment("PERF_SCENE")
	var path: String = SCENES.get(key, SCENES["world"])
	out = {"scene": key, "preset": Settings.quality_id(), "spot": OS.get_environment("PERF_SPOT"),
		"gpu": RenderingServer.get_video_adapter_name()}
	var entry := await _enter(path)
	out["entry"] = entry
	var mode = get_tree().current_scene
	if OS.get_environment("PERF_REENTER") == "1":
		# leave and come back in the same session: is the entry hitch there again?
		await _enter(SCENES["hub"] if key != "hub" else SCENES["kartal"])
		out["reentry"] = await _enter(path)
		print("PERF_JSON ", JSON.stringify(out))   # an entry run: no steady-state measuring
		get_tree().quit()
		return
	mode.player.input_locked = true
	_spot(mode, key)
	await _seconds(SETTLE)
	if OS.get_environment("PERF_DIAG") == "1":
		await _diag(mode)
		get_tree().quit()
		return
	out["base"] = await _measure(MEASURE)
	out["counts"] = _counts(mode)
	out["monitors"] = _monitors()
	if OS.get_environment("PERF_FAST") != "1":   # PERF_FAST=1: the baseline only (a quick before / after)
		out["toggles"] = await _toggles(mode, float(out["base"]["median_ms"]))
	print("PERF_JSON ", JSON.stringify(out))
	get_tree().quit()


# --- Entering a scene: load time and hitches --------------------------------------------------

## Changes to `path`; returns {load_s (the call until the scene's _ready has run), first_frame_ms
## (the first frame after that: the rest of the start-up and the first draw), hitches (every
## later frame over 50 ms in the first 10 s: [{t, ms, new_nodes, process_ms}]), worst_ms,
## hitch_total_ms}.
func _enter(path: String) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	get_tree().change_scene_to_file(path)
	while true:
		await get_tree().process_frame
		var c = get_tree().current_scene
		if c != null and c.scene_file_path == path and c.get("player") != null and c.player.is_inside_tree():
			break
	var up := Time.get_ticks_usec()
	var hitches: Array = []
	var last := up
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var worst := 0.0
	var total := 0.0
	var frames := 0
	var first_ms := 0.0
	while (Time.get_ticks_usec() - up) / 1000000.0 < 10.0:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		frames += 1
		var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		if frames == 1:
			first_ms = ms
		elif ms > HITCH_MS:
			hitches.append({"t": snappedf((now - up) / 1000000.0, 0.01), "ms": snappedf(ms, 0.1), "new_nodes": nodes - nodes_before,
				"process_ms": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.1),
				"physics_ms": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.1)})
			worst = maxf(worst, ms)
			total += ms
		nodes_before = nodes
	return {"load_s": snappedf((up - t0) / 1000000.0, 0.01), "first_frame_ms": snappedf(first_ms, 0.1), "hitches": hitches, "worst_ms": snappedf(worst, 0.1),
		"hitch_total_ms": snappedf(total, 0.1), "frames_10s": frames}


# --- Where he stands ---------------------------------------------------------------------------

func _spot(mode, key: String) -> void:
	var lvl = mode.level
	if lvl.get("day_night") != null:
		WorldState.set_time_of_day(10.5)
		lvl.day_night.set_hour(10.5)
		lvl.day_night.paused = true
	if key == "world" and OS.get_environment("PERF_SPOT") == "village":
		mode._demo_view(Vector3(290, 0, 380), Vector3(304, 14, 342), 12.0)   # Kürköy, as --demo=world_village
	elif key == "world":
		mode.rig.snap()
	out["position"] = str(mode.player.global_position)


# --- Measuring ---------------------------------------------------------------------------------

func _measure(seconds: float) -> Dictionary:
	var us := PackedInt64Array()
	var cpu := 0.0
	var gpu := 0.0
	var proc := 0.0
	var phys := 0.0
	var start := Time.get_ticks_usec()
	var last := start
	while (Time.get_ticks_usec() - start) / 1000000.0 < seconds:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		us.append(now - last)
		last = now
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(_rid)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(_rid)
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var sorted := Array(us)
	sorted.sort()
	var n := sorted.size()
	var median_us: float = float(sorted[n / 2])
	var worst := maxi(n / 100, 1)
	var low_us := 0.0
	for i in worst:
		low_us += float(sorted[n - 1 - i])
	low_us /= worst
	var total := 0.0
	for v in sorted:
		total += float(v)
	return {"frames": n, "mean_fps": snappedf(n * 1000000.0 / total, 0.1), "median_fps": snappedf(1000000.0 / median_us, 0.1),
		"low1_fps": snappedf(1000000.0 / low_us, 0.1), "median_ms": snappedf(median_us / 1000.0, 0.01),
		"render_cpu_ms": snappedf(cpu / n, 0.01), "render_gpu_ms": snappedf(gpu / n, 0.01),
		"process_ms": snappedf(proc / n, 0.01), "physics_ms": snappedf(phys / n, 0.01)}


func _monitors() -> Dictionary:
	return {"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"vram_mb": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))}


# --- What is in the scene ------------------------------------------------------------------------

func _counts(mode) -> Dictionary:
	var meshes: Array = mode.find_children("*", "MeshInstance3D", true, false)
	var mmis: Array = mode.find_children("*", "MultiMeshInstance3D", true, false)
	var mats := {}
	var tris := 0
	for mi in meshes:
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		tris += _tris(mi.mesh)
		for i in mi.mesh.get_surface_count():
			var m = mi.get_active_material(i)
			if m != null:
				mats[m] = true
	var inst := 0
	var mm_tris := 0
	for mm in mmis:
		if mm.multimesh == null or not mm.is_visible_in_tree():
			continue
		var count: int = mm.multimesh.visible_instance_count if mm.multimesh.visible_instance_count >= 0 else mm.multimesh.instance_count
		inst += count
		if mm.multimesh.mesh != null:
			mm_tris += _tris(mm.multimesh.mesh) * count
	var omni: Array = mode.find_children("*", "OmniLight3D", true, false).filter(func(l): return l.is_visible_in_tree())
	var spot: Array = mode.find_children("*", "SpotLight3D", true, false).filter(func(l): return l.is_visible_in_tree())
	var parts: Array = mode.find_children("*", "GPUParticles3D", true, false).filter(func(p): return p.is_visible_in_tree())
	var amount := 0
	for p in parts:
		amount += p.amount
	return {"mesh_instances": meshes.size(), "mesh_triangles": tris, "multimesh_nodes": mmis.size(), "multimesh_instances": inst,
		"multimesh_triangles": mm_tris, "materials": mats.size(), "omni_lights": omni.size(),
		"omni_with_shadows": omni.filter(func(l): return l.shadow_enabled).size(), "spot_lights": spot.size(),
		"spot_with_shadows": spot.filter(func(l): return l.shadow_enabled).size(), "particle_systems": parts.size(),
		"particles": amount, "characters": mode.find_children("*", "CharacterBody3D", true, false).size()}


func _tris(mesh: Mesh) -> int:
	var t := 0
	for s in mesh.get_surface_count():
		var arr_len := 0
		if mesh is ArrayMesh:
			var idx: int = (mesh as ArrayMesh).surface_get_array_index_len(s)
			arr_len = idx if idx > 0 else (mesh as ArrayMesh).surface_get_array_len(s)
		else:
			var arrays := mesh.surface_get_arrays(s)
			if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
				arr_len = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
			elif arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
				arr_len = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		t += arr_len / 3
	return t


# --- What costs what: switch one thing off, measure, put it back ------------------------------------

func _toggles(mode, base_ms: float) -> Array:
	var res: Array = []
	var lvl = mode.level
	var env: Environment = lvl.day_night.env if lvl.get("day_night") != null else null
	var sun = lvl.day_night.light if lvl.get("day_night") != null else null
	var vp := get_viewport()
	var tests: Array = []
	if sun != null:
		tests.append(["sun shadows", func(): sun.shadow_enabled = false, func(): sun.shadow_enabled = true])
	var point: Array = mode.find_children("*", "OmniLight3D", true, false) + mode.find_children("*", "SpotLight3D", true, false)
	point = point.filter(func(l): return l.visible)
	tests.append(["point lights (%d)" % point.size(), func(): _show(point, false), func(): _show(point, true)])
	var shadowed: Array = point.filter(func(l): return l.shadow_enabled)
	if not shadowed.is_empty():
		tests.append(["point-light shadows (%d)" % shadowed.size(), func(): _shadows(shadowed, false), func(): _shadows(shadowed, true)])
	var parts: Array = mode.find_children("*", "GPUParticles3D", true, false).filter(func(p): return p.visible)
	tests.append(["particle systems (%d)" % parts.size(), func(): _show(parts, false), func(): _show(parts, true)])
	var chars: Array = mode.find_children("*", "CharacterBody3D", true, false).filter(func(c): return c.visible)
	tests.append(["characters (%d)" % chars.size(), func(): _show(chars, false), func(): _show(chars, true)])
	var mmis: Array = mode.find_children("*", "MultiMeshInstance3D", true, false).filter(func(m): return m.visible)
	if not mmis.is_empty():
		tests.append(["MultiMesh nodes (%d)" % mmis.size(), func(): _show(mmis, false), func(): _show(mmis, true)])
	if env != null:
		if env.ssao_enabled:
			tests.append(["SSAO", func(): env.ssao_enabled = false, func(): env.ssao_enabled = true])
		if env.volumetric_fog_enabled:
			tests.append(["volumetric fog", func(): env.volumetric_fog_enabled = false, func(): env.volumetric_fog_enabled = true])
		if env.glow_enabled:
			tests.append(["glow", func(): env.glow_enabled = false, func(): env.glow_enabled = true])
		tests.append(["distance fog", func(): env.fog_enabled = false, func(): env.fog_enabled = true])
	var scale3d := vp.scaling_3d_scale
	tests.append(["half 3D resolution (fill-rate test)", func(): vp.scaling_3d_scale = scale3d * 0.5, func(): vp.scaling_3d_scale = scale3d])
	var hud = mode.get("hud")
	if hud != null:
		tests.append(["HUD", func(): hud.visible = false, func(): hud.visible = true])
	# every child of the level (and of its streamer: the streamed places) on its own
	var kids: Array = lvl.get_children()
	if lvl.get("streamer") != null:
		kids += lvl.streamer.get_children()
	for k in kids:
		if k is Node3D and k.visible and not (k is Light3D) and k != lvl.get("day_night"):
			var node: Node3D = k
			var n_mesh: int = node.find_children("*", "MeshInstance3D", true, false).size() + node.find_children("*", "MultiMeshInstance3D", true, false).size()
			if n_mesh == 0 and not (node is MeshInstance3D) and node.get_class() != "Terrain3D":
				continue
			var script_name: String = (node.get_script() as Script).resource_path.get_file() if node.get_script() != null else node.get_class()
			tests.append(["node: %s [%s, %d meshes]" % [node.name, script_name, n_mesh], func(): _show([node], false), func(): _show([node], true)])
	for t in tests:
		if String(t[0]).begins_with("node: ") and get_tree().current_scene != mode:
			break
		(t[1] as Callable).call()
		await _seconds(TOGGLE_SETTLE)
		var m := await _measure(TOGGLE_MEASURE)
		(t[2] as Callable).call()
		res.append({"what": t[0], "median_ms": m["median_ms"], "saved_ms": snappedf(base_ms - float(m["median_ms"]), 0.01),
			"median_fps": m["median_fps"], "draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))})
		await _frames(3)
	# the baseline again at the end: how far it drifted while testing (the noise of the numbers above)
	await _seconds(TOGGLE_SETTLE)
	out["base_again"] = await _measure(TOGGLE_MEASURE)
	return res


func _shadows(lights: Array, on: bool) -> void:
	for l in lights:
		if is_instance_valid(l):
			l.shadow_enabled = on


func _show(nodes: Array, on: bool) -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.visible = on


func _seconds(s: float) -> void:
	var start := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) / 1000.0 < s:
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Diagnostic: draw calls over time while one small node is hidden and shown again, and
## with each shadowed point light's shadow off (what do the hub's draw calls consist of?).
func _diag(mode) -> void:
	var lvl = mode.level
	var victim: Node3D = null
	for k in lvl.get_children():
		if k is MeshInstance3D and k.visible:
			victim = k
			break
	var steps: Array = [["baseline", func(): pass], ["hide one mesh (%s)" % victim.name, func(): victim.visible = false],
		["show it again", func(): victim.visible = true]]
	for l in mode.find_children("*", "OmniLight3D", true, false):
		if l.visible and l.shadow_enabled:
			var light: OmniLight3D = l
			steps.append(["shadow off: %s (parent %s)" % [light.name, light.get_parent().name], func(): light.shadow_enabled = false])
			steps.append(["shadow on again: %s" % light.name, func(): light.shadow_enabled = true])
	for st in steps:
		(st[1] as Callable).call()
		var line := "PERF_DIAG %s:" % st[0]
		for i in 8:
			await _seconds(0.4)
			line += " %d" % int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		print(line)
	# every child of the level hidden in turn: draw calls while hidden, and after it is back
	for k in lvl.get_children():
		if not (k is Node3D) or not k.visible or k is Light3D:
			continue
		k.visible = false
		await _seconds(0.6)
		var hidden := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		k.visible = true
		await _seconds(0.6)
		print("PERF_DIAG child %s [%s]: hidden %d, back %d" % [k.name, k.get_class(), hidden,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
