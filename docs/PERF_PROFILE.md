# Performance profile (before art part 2)

Measured 2026-09-30 on the dev machine: **Intel(R) UHD Graphics** (integrated), 1280×720 window, Godot 4.7.2
Forward+, `main` at tag `v3-lighting-p2`. **No game code was changed for this report** — it only measures.
Target for part 2: **Medium ≥ 45 fps in the valley and in Son Ocak** on this GPU (a 22.2 ms frame).

## How it was measured

`scenes/tests/perf_probe.tscn` (`scripts/debug/perf_probe.gd`, a measuring tool, not part of the game) loads one
scene, erases every input binding (so keys typed into the focused window cannot move him), sets 10:30, waits 4 s, then:

- times every frame for 8 s with **vsync off** → mean, median, 1 % low (the mean frame rate of the slowest 1 % of frames);
- reads the engine's monitors (draw calls, visible objects, primitives) and the viewport's measured render time on the
  CPU and on the GPU, plus process and physics time;
- switches one thing off at a time (a category, or one child of the level), measures the median frame time for 2.5 s,
  and puts it back → "saved ms";
- on entry, records the load time, the first frame and every later frame over 50 ms in the first 10 s.

One scene and preset per process, each on a clean user profile (`APPDATA` pointed at an empty folder).
Command: `APPDATA=<empty> PERF_SCENE=world|hub|kartal [PERF_SPOT=village] [PERF_REENTER=1] "$G" --path . res://scenes/tests/perf_probe.tscn -- --demo=perf --quality=low|medium`.

**How far to trust the numbers.** The baseline measured again at the end of a run differs from the first one by
0.3–2.7 ms (warm-up, drift), so a "saved" value under ~1 ms is noise. The per-node results of the hub and Kartal runs
are **not used**: a state leak in the probe left fewer draw calls for the rest of those runs (a separate draw-call
diagnostic, `PERF_DIAG=1`, was used for the hub instead). The valley's per-node results are consistent with its
draw-call counts and are used. The first version of two valley runs was thrown away and measured again (keys typed
into the window had walked him into Son Ocak).

## 1. Frame rate, draw calls, where the time goes

| Place | Preset | Median fps | Mean fps | 1 % low | Frame (ms) | GPU render (ms) | CPU render (ms) | Process / physics (ms) | Draw calls | Visible objects | Primitives |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Valley, start (Geçit Ocağı) | Low | **52.0** | 51.4 | 29.5 | 19.2 | 18.0 | 2.5 | 19.1 / 2.7 | 528 | 896 | 692 k |
| Valley, start | Medium | **38.4** | 38.3 | 32.9 | 26.0 | 24.5 | 3.1 | 25.7 / 3.3 | 662 | 1002 | 791 k |
| Valley, Kürköy (village) | Low | **44.6** | 44.6 | 38.6 | 22.4 | 21.3 | 4.7 | 21.5 / 2.8 | 689 | 1433 | 924 k |
| Valley, Kürköy | Medium | **28.6** | 28.6 | 24.5 | 35.0 | 33.8 | 4.4 | 33.1 / 3.5 | 727 | 1443 | 956 k |
| Son Ocak (day) | Low | **47.6** | 47.6 | 42.7 | 21.0 | 20.2 | 3.8 | 21.0 / 1.7 | 1115 | 1885 | 534 k |
| Son Ocak (day) | Medium | **36.4** | 36.4 | 33.0 | 27.5 | 26.5 | 4.4 | 27.3 / 1.6 | 1119 | 1891 | 537 k |
| Kartal Yamacı | Low | **82.4** | 83.1 | 67.3 | 12.1 | 11.2 | 1.5 | 12.8 / 1.8 | 125 | 649 | 346 k |
| Kartal Yamacı | Medium | **62.6** | 62.8 | 55.7 | 16.0 | 15.0 | 2.0 | 15.9 / 1.9 | 223 | 796 | 551 k |

("Process" is the whole frame as the engine reports it, waiting for the GPU included; it is not CPU work.)

**The bottleneck is the GPU, everywhere.** GPU render time is 92–97 % of the frame; CPU render time is 1.5–4.7 ms and
physics 1.6–3.5 ms. It is mostly **pixel cost (fill rate)**: at half the 3D resolution the frame gets shorter by

| Place | Low | Medium |
|---|---|---|
| Valley, start | −5.8 ms (52 → 75 fps) | −9.0 ms (38 → 59 fps) |
| Valley, Kürköy | −8.2 ms (45 → 71 fps) | −13.6 ms (29 → 47 fps) |
| Son Ocak | −6.1 ms (48 → 67 fps) | −8.8 ms (36 → 53 fps) |
| Kartal Yamacı | −3.1 ms (82 → 111 fps) | −5.8 ms (63 → 98 fps) |

So draw calls are not the limit on this machine (the hub's 1119 draw calls cost the CPU only 4.4 ms); what each pixel
costs is — the terrain shader, SSAO, shadow sampling, overdraw.

### What is in each scene

| | Valley, start | Valley, Kürköy | Son Ocak | Kartal Yamacı |
|---|---|---|---|---|
| Mesh instances / triangles in them | 444 / 1.63 M | 402 / 1.50 M | 374 / 0.20 M | 130 / 0.76 M |
| MultiMesh nodes / visible instances / triangles | 1291 (242 visible) / 11 201 / 1.96 M | 1291 (179 visible) / 2 297 / 1.25 M | 0 | 0 |
| Unique materials in use | 375 | 338 | 108 | 45 |
| Point lights (with shadows) | 12 (0) | 11 (0) | 4 (2) | 1 (0) |
| Particle systems / particles | 19 / 2 762 | 20 / 2 732 | 4 / 156 | 5 / 444 |
| Characters | 16 | 17 | 7 | 2 |
| Nodes in the tree | 3044 | 3365 | 1114 | 456 |

## 2. The five heaviest sources per place (Medium)

"Saved" = how much shorter the median frame gets with that one thing off.

**Valley, start — 26.0 ms (38.4 fps)**

| # | Source | Saved | Note |
|---|---|---|---|
| 1 | **Terrain3D** (the ground and its instanced vegetation: 1288 MultiMesh nodes) | **12.5 ms** | the vegetation MultiMeshes alone are ≈ 1–2 ms (242 visible nodes, 11 k instances, 1.96 M triangles); the rest, ≈ 10 ms, is the **ground surface's shader** |
| 2 | Sun shadows (2 splits, 90 m) | 5.1 ms | 173 draw calls |
| 3 | SSAO | 4.2 ms | Medium only |
| 4 | 12 point lights (no shadows) | 1.5 ms | hearth, lanterns, the protagonist's ember |
| 5 | Characters (16) / vegetation MultiMeshes | 1.0 ms each | |

**Valley, Kürköy — 35.0 ms (28.6 fps)**

| # | Source | Saved | Note |
|---|---|---|---|
| 1 | **Streamed places** (`cell_streamer.gd`: 225 meshes — houses, props) | **12.4 ms** | Kürköy's near set alone 5.5 ms, its far set 2.2 ms; 286 draw calls; 338 materials in view |
| 2 | **SSAO** | **10.1 ms** | 2.4× its cost at the start spot: the village fills the screen with near geometry |
| 3 | Terrain3D | 7.2 ms | |
| 4 | Sun shadows | 4.4 ms | 247 draw calls |
| 5 | Characters (17) | 1.6 ms | 239 draw calls (modular bodies) |

**Son Ocak — 27.5 ms (36.4 fps)** (categories and the draw-call diagnostic; per-node numbers not used)

| # | Source | Saved | Note |
|---|---|---|---|
| 1 | SSAO | 4.8 ms | Medium only |
| 2 | **Point lights (4), two with shadows** | 4.3 ms (shadows alone 2.8 ms) | the hearth's light is redrawn into its shadow cube **every frame** (365 draw calls) because its flicker moves the light a few centimetres each frame; Aras's room lamp adds 195 |
| 3 | Sun shadows | 4.2 ms | 325 draw calls |
| 4 | Characters (7) | 3.6 ms | ≈ 400 draw calls: a modular character is many meshes, each drawn again in every shadow pass |
| 5 | Glow / volumetric fog | 0.9 / 0.6 ms | |

Draw calls in the hub (1119): hearth-light shadow 365 (33 %), sun shadow ≈ 320 (29 %), room-lamp shadow ≈ 195 (17 %),
the picture itself ≈ 240 (21 %). **Four fifths of the hub's draw calls are shadow passes.**

**Kartal Yamacı — 16.0 ms (62.6 fps)**: the slope mesh 5.1 ms, sun shadows 4.0 ms, characters (2) 2.3 ms, SSAO 2.3 ms,
the one point light 1.9 ms. It is already above the target.

## 3. The question: how much does Low give over Medium in the valley?

| Spot | Medium | Low | Gain |
|---|---|---|---|
| Start (Geçit Ocağı) | 38.4 fps | 52.0 fps | **+13.6 fps (+35 %)** |
| Kürköy | 28.6 fps | 44.6 fps | **+16.0 fps (+56 %)** |

**The gain is large, not marginal.** On this machine Low is the difference between a village at 29 fps and one at 45.
So the benchmark sending this GPU to Low is not a pointless downgrade — what is wrong is that Medium is too expensive
here. Where the difference comes from (Medium → Low): SSAO off (4.2 ms at the start, 10.1 ms in Kürköy), the 3D
resolution 0.87 → 0.77 (27 % fewer pixels, on a fill-rate-bound GPU), the shadow distance 90 → 70 m (134 fewer draw
calls at the start), volumetric fog off (0.5–0.8 ms). The geometry is the same in both presets.

Both presets miss the target in Kürköy at Medium (28.6 fps); only Kartal Yamacı meets it.

## 4. The "1.6 s hitch" at the valley's entry

**What it is: not an in-game freeze, but the end of loading, caught by the benchmark's clock.** The benchmark node
starts its clock inside the scene's `_ready`, before `world_mode._begin()` (loading the state, the first streaming
pass) has run. With only 1.5 s discarded, the rest of the start-up (≈ 1.6 s) arrives as the first "frame" it records —
that single sample is the 0.6 fps 1 % low. With 3 s discarded it is gone (1 % low 30–33 fps). The player sees it as
the last part of the black load, never as a stutter in play.

What the player really gets on entering the valley, measured separately (Medium):

| | Load (scene change → ready) | First frame after | Later frames over 50 ms (first 10 s) |
|---|---|---|---|
| **First launch ever** (clean profile, no shader cache) | 9.6–10.6 s | 349 ms | 2: 68 ms and 154 ms, at 0.4–0.6 s |
| **Later launches** (shader cache on disk) | 7.0–7.7 s | 183–312 ms | 2–3: 55–89 ms, at 0.24–0.55 s |
| **Re-entry in the same session** (from Son Ocak) | 2.9–3.1 s | 162–198 ms | 1: 56–59 ms, at ≈ 0.27 s |
| Son Ocak itself | 4.7 s first time, 0.7 s again | 13–120 ms | none |

Sources, by subtracting the rows:

1. **Shader / pipeline compilation — first launch only**: ≈ 2–3 s more load, a bigger first frame (349 vs ≈ 190 ms)
   and a 154 ms frame. Paid once per install or driver update.
2. **Reading resources from disk — once per session**: ≈ 4 s of the load (7.1 → 2.9 s on re-entry).
3. **Building the world — every entry**: ≈ 3 s (Terrain3D, the streamer's first pass), a first frame of ≈ 170–200 ms,
   and 1–3 frames of 55–90 ms in the first half second. Those frames come with +140 … +320 new nodes each: the
   streamer's main-thread jobs adding the first places. After 0.6 s there is no frame over 50 ms.

So: every entry costs a 3–10 s load **with no loading screen** and about 0.2–0.5 s of visible stutter right after it;
nothing later. There is no 1.6 s frame in play.

## 5. Benchmark: proposal (not applied)

Measured medians at the valley's start, Medium: 38.4 (probe), 38.6 / 38.2 / 38.2 (three benchmark runs), 38.7, 37.6,
36.6, 35.4 (other runs, the last two with other work on the machine). The current single threshold (38) sits exactly
on this machine, so its preset flips between launches.

**(a) Start on "ready", not on a fixed time.** Begin measuring when: the scene's `_begin` has finished, the streamer
reports nothing pending (`loaded_count()["pending"] == 0`), and 30 further frames have been drawn. Then measure 5 s.
This removes the load tail (the false 1.6 s frame) on any machine, however slow its disk. Keep a 10 s cap: if "ready"
never comes, measure anyway.

**(b) A dead zone instead of one threshold.** The numbers proposed in the task (≥ 40 → Medium, ≤ 34 → Low, between →
Medium) would keep this machine on Medium — and section 3 shows Medium is 28.6 fps in Kürköy here, while Low is 44.6.
The benchmark measures at the start spot, which is the *lighter* view: Kürköy runs at 74 % of the start spot's frame
rate at Medium (28.6 / 38.4). For Medium to hold ≈ 35 fps in the village the start spot must measure ≈ 47. Proposal:

| Median at the start spot (Medium, vsync off) | Preset |
|---|---|
| ≥ 46 fps | Medium (High only on a discrete GPU, ≥ 65 as now) |
| ≤ 40 fps | Low |
| 40–46 (the dead zone) | Medium — and measure again on the next launch before saving (two agreeing results) |

On this machine every measured median (35.4–38.7) is below 40, so the result is stable: **Low**, which is also the
right answer today (52 / 45 fps instead of 38 / 29). Once part 2 brings Medium to ≥ 45 in the valley, the same
thresholds put this machine on Medium without any change.

## 6. Performance budget proposed for part 2 (terrain and the modular kit)

Target: Intel UHD, Medium, **valley ≥ 45 fps and Son Ocak ≥ 45 fps** → a 22.2 ms frame. Today: 26.0 ms (start),
35.0 ms (Kürköy), 27.5 ms (hub). Needed: −3.8 ms, −12.8 ms, −5.3 ms.

### Frame budget (Medium, 22 ms)

| Part | Budget | Today (start / Kürköy / hub) |
|---|---|---|
| Ground (terrain surface) | 6 ms | ≈ 10 / 6 / — |
| Buildings and props | 5 ms | ≈ 1 / 12.4 / not measured |
| Shadows (sun + one point light) | 3.5 ms | 5.1 / 4.4 / 7.0 |
| Screen effects (SSAO, fog, glow) | 2.5 ms | 5.6 / 11.6 / 6.3 |
| Trees, rocks, grass | 2 ms | ≈ 1–2 |
| Characters | 1.5 ms | 1.0 / 1.6 / 3.6 |
| Everything else | 1.5 ms | |

Scene limits at Medium: **≤ 450 draw calls** in the valley (662–727 today), **≤ 500** in the hub (1119 today);
**≤ 700 k primitives** in view (791–956 k today); **≤ 120 unique materials** in view (338–375 today).

### MultiMesh plan

| | Cell | LOD / range | Shadows | Presets |
|---|---|---|---|---|
| **Trees** | one MultiMesh per species per 64 m cell | full mesh to 40 m, reduced (≤ 35 % of the triangles) to 120 m, a card / impostor to 230 m, nothing beyond | cast only by the full mesh, within 40 m | Low: no tree shadows, impostor from 80 m |
| **Rocks** | one MultiMesh per kind per 64 m cell | one mesh, `visibility_range_end` 140 m (Low 100 m) | within 40 m only | |
| **Grass** | one MultiMesh per 16 m cell | ≤ 12 triangles a tuft, alpha **scissor** (no blending, no overdraw), no LOD | never | Low: off (or 25 % density to 20 m); Medium: 60 % to 35 m; High: 100 % to 60 m |

Grass budget at Medium: ≤ 150 k triangles in view, ≤ 1.5 ms (measure with the probe: MultiMesh nodes off).

### `visibility_range` / LOD rules

- Small props (under 1 m): gone at 40 m. Medium props (1–3 m): gone at 80 m. Fade margin 5–10 m on Medium and High,
  a hard cut on Low.
- A building: LOD0 to 60 m; LOD1 (≤ 30 % of the triangles, one merged material) to 250 m; a far card beyond. The
  modules of one house are merged into one mesh per material when the house is built (no per-module draw call at a
  distance).
- Interior pieces (behind a door) are visible only within 12 m of that door.
- Nothing under 0.5 m casts a shadow; grass and far LODs never do.

### Occlusion culling for Son Ocak

The courtyard is closed on all four sides, so most of what is drawn today is behind a wall. Proposal: turn on
occlusion culling for the hub and give it simple box occluders — one `OccluderInstance3D` per room block and per
wall run (the rooms are solid boxes already), built in code with the level. Expected: the outer village, the back of
the rooms and Aras's room interior stop being drawn from the courtyard; they also leave the shadow passes. To be
measured with the probe (target: ≤ 500 draw calls).

Two hub changes that are not geometry but belong to the same budget (measured above):
- the hearth light's flicker moves the light every frame, which redraws its shadow cube every frame (365 draw
  calls): flicker the energy only, or update that shadow every few frames;
- Aras's room lamp casts shadows all the time (195 draw calls): only while he is in the room.

### Limits per module (the Caucasus kit)

| | Limit |
|---|---|
| Wall module (2 × 3 m), plain / corner | ≤ 600 triangles at LOD0, ≤ 150 at LOD1 |
| Wall with a door or a window | ≤ 1 200 triangles |
| Roof module (beam ends, earth top) | ≤ 800 triangles |
| Door frame, eyvan post and rail | ≤ 500 triangles each |
| A whole house | ≤ 12 k triangles at LOD0, ≤ 3 k at LOD1 |
| Materials | the **whole kit shares ≤ 3 opaque materials** (stone, wood, earth / roof) on one trim or atlas set, plus one alpha-scissor material for roof grass; no per-module material; 2K textures (1K on Low) |
| Material rule | non-metal: metallic 0, roughness ≥ 0.7 (checked by `tools/audit_materials.gd`) |
| Lights | at most **one shadowed point light in view** (a hearth); other lights unshadowed, range ≤ 8 m; at most 4 point lights on any module; lit windows are emissive material, not lights |
| Shadows | modules cast the sun's shadow; trim under 0.5 m does not |

### The cheapest wins found by this profile (for the owner to decide; none applied)

| Change | Measured cost today | Where |
|---|---|---|
| SSAO at Medium: half resolution / lowest quality, or High only | 4.2–10.1 ms | every place |
| Ground shader: fewer blended textures and no extra detail layers at Low and Medium | ≈ 10 ms of the terrain's 12.5 | valley |
| Kürköy's houses: merged meshes per material, LOD1, fewer unique materials | 12.4 ms | valley |
| Hearth-light shadow not redrawn every frame; the room lamp's only when needed | 2.8 ms, 560 draw calls | hub |
| Sun shadows at Medium: 70 m instead of 90 m, small props and grass not casting | 4.2–5.1 ms | every place |
| A loading screen (3–10 s of black today) | — | valley entry |
