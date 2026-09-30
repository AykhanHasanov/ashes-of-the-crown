# CLAUDE.md — Ashes of the Crown

Standing rules for every session, so a prompt can be short. Detail lives in the linked docs; keep them current
instead of copying them here.

| Read when | Doc |
|---|---|
| Any story task (**before** touching story) | `STORY_BIBLE.md` (canon), `STORY_SLICE.md` (the vertical slice) |
| How a system works | `docs/SYSTEMS.md` (state, saves, memories, echoes, names, NPCs, story director, tests, all run commands) |
| Before any merge to `main` | `docs/MERGE_CHECKLIST.md` |
| Performance numbers, budget, heaviest sources | `docs/PERF_PROFILE.md` |
| Material rule and its exceptions | `docs/MATERIAL_AUDIT.md` |
| Design spec / decisions / backlog | `docs/SPEC_V3.md`, `docs/DECISIONS.md`, `BACKLOG.md` |
| Every third-party asset's source and licence | `docs/ASSETS.md` |

## The game

A 3D action-RPG. Aras, crown prince of Ateşan and Közcü of its Great Hearth, walks a frozen Caucasus / Silk Road land
ruled from a burning castle by Kül Şahı — the King, his own father. Core mechanic *Yaddaş Yanğını*: memories are fuel,
burning them gives fire power at a cost. Structure: one persistent world, the hub Son Ocaq (a village grown around a
caravanserai), a soulslike loop, permanent death for NPCs. Full story in `STORY_BIBLE.md` — **never invent story
content**; use `[TBD]` placeholders and flag them.

**Owner:** a solo developer with no engine experience. Decide, then explain. **Reply in Azerbaijani**; code, comments,
commit messages and docs in English. Player-facing text only through `tr()` keys in `localization/strings.csv`
(currently Turkish; the move to Azerbaijani is in `BACKLOG.md`).

## Autonomy

| Level | What | How to work |
|---|---|---|
| **GREEN** | Content from what exists: props, set dressing, NPC placement and routines, ambient sound, particles, lights, buildings from the existing kit | Work to completion without stopping. If every suite, `flow_test` and `perf_probe` pass within budget, merge to `main` yourself. One report at the end with before/after screenshots |
| **YELLOW** | A new mechanic, a new scene, a UI change | A short plan first (max 10 lines), then execute to the end without stopping |
| **RED** | Save system, presets/benchmark, architecture, deleting content, V2 migration | Step by step, approval per step |

Unsure which level? Take the higher one. Report in Azerbaijani, with screenshots for anything visual.

## Tech

- Godot **4.7.2** stable, Forward+, GDScript only.
  `G="C:/Users/User/Documents/games/_tools/godot/Godot_v4.7.2-stable_win64_console.exe"`, run from the project root.
- Terrain3D 1.0.2 (`addons/terrain_3d`), built for Godot 4.4–4.6: three workarounds live in
  `scripts/world/open_world.gd` — do not remove them without testing.
- Python 3 (numpy, pillow, scipy, edge-tts) for offline generation. Voices are edge-tts prototypes, to be replaced.
- Dev machine: Intel UHD (integrated) — the minimum spec. The target Asus machine is not profiled yet.

## Code rules

1. **Static typing** wherever the type is knowable; explicit types for Variant values (JSON, `Dictionary.get`).
2. **Signals over references.** Cross-system events go through `EventBus`; never reach across the tree.
3. **No game state in nodes or scenes.** Everything that must survive lives in `WorldState`; nodes are views.
4. **Numbers and content in `data/`**, read through `DataDB` — not in code.
5. **No `class_name`**: `const Foe := preload("res://scripts/enemies/foe.gd")`. `snake_case` files, `_private`
   members, `UPPER_SNAKE` constants. Every script opens with a `##` doc comment. LF line endings.
6. **Every scene change goes through `LoadingScreen.go(tree, path)`**, never `change_scene_to_file`.
7. **Tests are the gate.** All suites before every commit; `docs/MERGE_CHECKLIST.md` before every merge. New system →
   new checks in the matching self-test.

## Git

Branch `v3/<topic>` → commit per step → `docs/MERGE_CHECKLIST.md` → `git merge --no-ff` into `main` → **a tag per
milestone** (`v3-<name>`) → push branch, `main` and the tag. Remote: private `github.com/AykhanHasanov/ashes-of-the-crown`.
Parallel work happens in a **git worktree**, and touches only the area the task names.

## Performance

Target, measured with `scenes/tests/perf_probe.tscn` (vsync off, clean profile, best of 2–3 runs; the 1 % low is too
noisy to gate on — see `docs/PERF_PROFILE.md`):

- **Integrated GPU (this machine) = minimum spec: Low ≥ 45 fps median everywhere, Kürköy included.** This is the gate.
- **Medium is the quality preset for entry-level discrete GPUs.** Here it is only a relative indicator: no change may
  make it **more than 1 ms worse** than the baseline in `docs/PERF_PROFILE.md`.
- Benchmark thresholds are recalibrated only after art part 2.
- **Kürköy takes no new content until part 2** (it is the heaviest place in the game).

Budget per module, the frame budget and the heaviest sources: `docs/PERF_PROFILE.md`. Short version: a house ≤ 12 k
triangles at LOD0, the whole kit ≤ 3 opaque materials, ≤ 1 shadowed point light in view, trees / rocks / grass through
MultiMesh with visibility ranges, nothing under 0.5 m casts a shadow.

## Materials

Non-metal = `metallic 0`, `roughness ≥ 0.7`, applied automatically at glTF import
(`tools/import/material_policy_import.gd` — keep that import script on every new model). A material stays exactly as
authored when its name ends with **`_keep`**, is listed in `data/art/material_policy.json`, or contains a metal word.
Check with `-s tools/audit_materials.gd` (must report 0). Details: `docs/MATERIAL_AUDIT.md`.

## Art direction

- Dark stylized Caucasus / Silk Road fantasy — not photoreal, not cartoon: simple forms, honest materials, restrained
  colour. References for architecture: Xınalıq, Lahıc (flat-roofed stone houses, terraces, eyvan, arcades).
- **Warm fire against cold night.** Fire, embers and lit windows are the only warm light; everything else is cool blue.
  Nothing else competes with a hearth.
- **Readable silhouettes.** A character, an enemy and a door must be recognisable as a shape before any detail.
- Never a black cut-out: a night still shows the ground and the lit side of a character (`ambient.min_energy`,
  `camera_fill` in `data/world/lighting.json`).
- Ash is the world's weather: pale ash-snow on the ground, ash falling in the air, scorch where something burned.
- **Son Ocaq door scenes stay dark**: the courtyard goes almost black and the only warm light is the strip under the
  door being spoken through. Do not "fix" that darkness.
- Placeholders are allowed and must be named so in the report.

## Assets

Budget is **zero**: CC0 or clearly free only — Kenney, Quaternius, KayKit, Poly Haven, ambientCG, Freesound CC0.
Record every new asset in `docs/ASSETS.md` (file, source URL, licence, date). Keep `.import` files in git. Before
downloading, say what the file is, its source and its size (blanket approval given).
