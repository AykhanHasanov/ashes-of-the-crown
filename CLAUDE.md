# CLAUDE.md — Ashes of the Crown

A permanent guide for future sessions. Read this first. Then read `ARCHITECTURE_AUDIT.md` (how the code fits together and what is risky) and `docs/SPEC_V3.md` (the design spec). Log decisions in `docs/DECISIONS.md`.

## Project

- **What it is:** a 3D action-RPG. Ayxan, last heir of Atəşan, fights through a Caucasus / Silk Road land burned by Kül Şahı (the Ash Shah).
- **Core mechanic:** *Yaddaş Yanğını*. Memories are fuel: burning them gives fire power at a cost.
- **Owner:** a solo developer with no engine experience. They delegate decisions and want the best option chosen, then explained. **Talk to the owner in Azerbaijani.**
- **Current direction:** a Bloodborne-like structure.
  - One unified world (menu: New game / Continue).
  - A persistent hub: the Son Ocaq caravanserai. It changes with story actions and rescued NPCs. At night NPCs answer through closed doors. Death is permanent and NPCs have relationships.
  - A soulslike loop: "Xatirə" is collected from enemies (currency + level), dropped on death and lost on a second death, and each loss makes the night deeper (4 stages).
  - Redeemable enemies can be purified with a 3 s ritual after a stagger.
  - Aggressive combat: rally (win health back by attacking) and hit-stop.
  - The fight zone becomes a hidden dev test arena.
- **Before the redesign:** tag `pre-redesign-v0`. The redesign plan and the per-file keep/change/archive list are in `AUDIT.md`.

## Tech stack

- **Engine:** Godot **4.7.2** stable (Forward+), GDScript only. Executable: `C:\Users\User\Documents\games\_tools\godot\Godot_v4.7.2-stable_win64_console.exe`.
- **Terrain:** Terrain3D 1.0.2 (`addons/terrain_3d`). It was built for Godot 4.4–4.6; three workarounds live in `scripts/world/open_world.gd`, so do not remove them without testing.
- **Art:**
  - Quaternius CC0 characters (Modular Outfits + Universal Base Characters) with the Universal Animation Library;
  - generated trees from ambientCG photo leaves;
  - Poly Haven rocks and terrain textures;
  - Medieval Village / Fantasy Props MegaKits.
- **Voices:** edge-tts Turkish neural voices processed by `tools/gen_voices.py`. **These are prototypes and must be replaced before release.**
- **Tooling:** Python 3 (numpy, pillow, scipy, edge-tts) for offline content generation.
- **Dev machine:** Intel UHD, about 20–30 fps in the open world. The target (Asus) machine has not been profiled yet.

## Folders

| Folder | Use |
|---|---|
| `scenes/` | Root-only scenes. Everything else is built in code by the scene's script |
| `scripts/` | Code, grouped by domain. Mode scripts sit at the root and extend `chapter_base.gd` |
| `scripts/<domain>/` | `camera/`, `characters/`, `combat/`, `core/`, `debug/`, `enemies/`, `npc/`, `player_v3/` (current player), `player/` (V2, legacy), `story/`, `systems/` (autoloads), `ui/`, `world/`, `world/gen/` |
| `data/` | **All tunable numbers and content as JSON**, loaded through `DataDB`. Balance, enemies, weapons, looks, voices, world layout, prefabs, trees, houses, villagers |
| `shaders/` | `.gdshader` and `.gdshaderinc` |
| `tools/` | Headless generators and checks (`godot --headless --path . -s tools/<x>.gd`) and Python generators |
| `assets/` | Third-party and generated assets. **Keep the `.import` files in git**: they carry the import settings |
| `world/` | Generated terrain and meta. Regenerate with `tools/gen_world.gd`; never hand-edit |
| `docs/` | Spec, decisions log, pipelines |
| `captures/` | Debug screenshots (git-ignored) |

## Naming conventions (as actually used)

- Files and folders: `snake_case` (`third_person_camera.gd`, `data/enemies/ash_shade.json`).
- **No `class_name`.** Scripts reference each other with PascalCase preload constants: `const Foe := preload("res://scripts/enemies/foe.gd")`, then `Foe.new()`. Subclasses use `extends "res://…/base.gd"`.
- Variables and functions: `snake_case`. Private ones start with an underscore: `_model`, `_tick()`. Constants: `UPPER_SNAKE`. Enums: `enum S { MOVE, ATTACK }`.
- Signals: past-tense or noun phrases (`health_changed`, `memory_burned`, `action_finished`, `poi_full`).
- Data ids: `snake_case` strings (`bandit_sword`, `hearth_west`). Prefab model prefixes:
  - `v:` Quaternius village
  - `f:` generated foliage and rocks
  - `b:` generated houses
  - `pm:` props kit
  - `vm:` village kit
- Every script starts with a `##` doc comment saying what it is and how it fits.
- Line endings: LF (`.gitattributes`).

## Rules

1. **Static typing wherever possible:** `var x: float`, `func f(a: int) -> void`, `:=` when the type is inferable. Variant values (JSON, `Dictionary.get`) need explicit types; `:=` on a Variant is a parse error.
2. **Signals over direct node references.** Emit events upward and let owners wire children. Do not reach across the tree with `get_node("/root/…")` or hand every system a reference to every other one. New cross-system events go through a central event bus.
3. **No game state stored in scenes or nodes.** Anything that must survive a save, an unload or a scene change lives in the central state system (today `GameState`; after the redesign `WorldState`). Nodes are views that read state and emit events. Streamed POIs, NPCs and enemies are freed and rebuilt at any time.
4. **Content and numbers in data, not code.** Add JSON under `data/` and read it through `DataDB`. Do not add constants to `systems/balance.gd` (legacy).
5. **Language.**
   - Code, comments, commit messages and docs meant for tools: **English**.
   - Chat with the owner: **Azerbaijani**.
   - **Player-facing text: currently Türkiye Türkçesi.** This was the owner's decision on 2026-09-27 (`docs/DECISIONS.md`) and every in-game string and voice line is Turkish today. A later instruction asked for Azerbaijani player-facing text. **Confirm with the owner before writing new player-facing strings in either language, and update this line.**
6. **Keep the tests green.** Run the three self-tests before merging (see below). Add checks for new systems to the relevant self-test.
7. **Git.** Work on a `v3/<topic>` branch, commit per stage, merge to `main` with `--no-ff` after the tests pass, then `git push` (remote: private `github.com/AykhanHasanov/ashes-of-the-crown`). End commit messages with the attribution line the harness provides.
8. **Assets.** CC0 (or clearly licensed) only. Record the source in a `CREDITS` file. Before downloading, state the file, source and size (the owner has given blanket approval).

## Running and testing

Set `G="C:/Users/User/Documents/games/_tools/godot/Godot_v4.7.2-stable_win64_console.exe"` and run from the project root.

**Main story (Chapter 1 → 2)**
- Play: `"$G" --path .`. The title screen opens; choose *Yeni oyun* or *Devam et*.
- Jump straight in: `"$G" --path . -- --demo=<mode>`. See the `settings.gd` header for the demo list (menu, explore, dialogue, fight…).
- Chapter 2 directly: `"$G" --path . res://scenes/chapter2.tscn`.

**Open world (Kür Vadisi)**
- Play: `"$G" --path . res://scenes/world.tscn` (or the menu button *Kür Vadisi*).
- Self-test: `"$G" --path . res://scenes/world.tscn -- --demo=world_selftest` (28 checks).
- Views: `--demo=world_village | world_square | world_evening | world_deer | world_forest | world_dusk | world_night | world_rain | world_lake`.

**Fight zone (arena)**
- Play: `"$G" --path . res://scenes/arena.tscn` (or the menu button *Savaş arenası*).
- Combat self-test: `"$G" --path . res://scenes/arena.tscn -- --demo=arena_selftest` (19 checks).
- AI self-test: `-- --demo=ai_selftest`.
- Views: `--demo=arena_fight | arena_all | arena_boss | arena_wolves`.

**Common flags and hotkeys**
- `--capture=captures/x.png --frame=240` saves a screenshot and quits. It also prints a `PROFILE` line (fps, draw calls, primitives, VRAM).
- `--quality=low|high` forces the graphics preset.
- In game: F10 debug menu, F4 AI overlay, F6 streaming overlay, F3 FPS, F9 quality.

**Labs**
- `res://scenes/char_lab.tscn`: `CHAR_LAB_LOOKS`, `CHAR_LAB_WEAPON`, `CHAR_LAB_OVERLAY`.
- `res://scenes/tree_lab.tscn`: `TREE_LAB_IDS`, `TREE_LAB_DIST`.

**Content pipelines:** see `docs/WORLD_PIPELINE.md` for the cards → trees → foliage bake → houses → world order.

**Known tool issue:** `tools/check_scripts.gd` reports false failures, because autoloads do not exist in `-s` mode. Use the self-tests or run a scene to check scripts.
