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
  - The old wave-based fight zone (arena) has been removed completely.
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
| `data/` | **All tunable numbers and content as data**, loaded through `DataDB` (JSON) or registries (`.tres`, e.g. `data/memories/`). Balance, enemies, weapons, looks, voices, world layout, prefabs, trees, houses, villagers, memories |
| `localization/` | `strings.csv` (translation keys → Turkish). Imported to `strings.tr.translation`, registered in Project Settings → Localization |
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
3. **No game state stored in scenes or nodes.** Anything that must survive a save, an unload or a scene change lives in `WorldState` (see *State & Save*). Nodes are views that read state and emit events. Streamed POIs, NPCs and enemies are freed and rebuilt at any time.
4. **Content and numbers in data, not code.** Add JSON under `data/` and read it through `DataDB`. Do not add constants to `systems/balance.gd` (legacy).
5. **Language.**
   - Player-facing text uses translation keys via `tr()`, defined in `localization/strings.csv`. **Current language: Turkish (text and voice). New text must never be hardcoded.** Only the memories and the save-slot dialog use keys so far; moving the remaining legacy strings is a separate task.
   - Code, comments and commit messages: English.
   - Chat with the owner: Azerbaijani.
6. **Keep the tests green.** Run the three self-tests before merging (see below). Add checks for new systems to the relevant self-test.
7. **Git.** Work on a `v3/<topic>` branch, commit per stage, merge to `main` with `--no-ff` after the tests pass, then `git push` (remote: private `github.com/AykhanHasanov/ashes-of-the-crown`). End commit messages with the attribution line the harness provides.
8. **Assets.** CC0 (or clearly licensed) only. Record the source in a `CREDITS` file. Before downloading, state the file, source and size (the owner has given blanket approval).

## State & Save

**Autoloads:** `EventBus` (signals only), `WorldState` (all persistent state) and `SaveManager` (all file I/O). Load order: `DataDB`, `Settings`, `EventBus`, `WorldState`, `SaveManager`, `Memory`, `Fx`, `Audio`, `Barks`.

**WorldState**
- It is the single source of truth. Sections:
  - `meta`
  - `player`: stats, region, position, burned memories
  - `inventory`
  - `flags`
  - `story`: chapter, checkpoint, echoes seen
  - `npcs`: reserved for the NPC model
  - `world`: clock, day, hub stage, open-world progress
- **Never mutate its dictionaries.** Use the typed accessors (`set_flag`, `burn_memory`, `add_item`, `set_player_stats`, `add_world_entry`, ...).
- Every mutation emits its `EventBus` signal. The signal list and who emits each one are in the header of `scripts/systems/event_bus.gd`.
- **One fact, one owner.** Story progress lives in `story` and must never be mirrored in `flags`. The same rule holds for every other value: never store it in two places.
- **Live values stay on nodes and are copied in only at save time.** This covers health, flasks, fire, clock, fog and position. On `EventBus.saving(slot)` the active mode writes them through the accessors. Do not write them every frame.

**Debug runs:** a `--demo` plays in memory; SaveManager never writes during one.

**SaveManager**
- Slots `user://saves/slot_1..3.json`.
- Atomic write: `.tmp`, then the old file becomes `.bak`, then the temp file is renamed into place. Loading falls back to `.bak`.
- `meta.save_version` with a `_migrate_step()` chain. v0 is the old `GameState` format. **Add a step for every schema change; never break old saves.**
- Autosaves on `EventBus.checkpoint_rested` (ocaq rest, story checkpoint) and `region_changed`.
- New game takes the first empty slot and never overwrites without the menu's confirmation.
- The old two-file saves were imported once into slot 1; the originals are kept as `*.migrated`.

**Memories**
- Defined as data: `MemoryDefinition` resources in `data/memories/*.tres`, looked up through `scripts/core/memory_registry.gd` by permanent id.
- Burned state is WorldState's. `Memory` (the autoload) is only the rules layer.
- Refer to memories by id (`&"mother_name"`), never by title.

**Tests:** `"$G" --headless --path . res://scenes/tests/state_test.tscn` covers state, saves, migration and every main-menu case. It uses its own save folders.

**Removed with the arena:** the combat self-test (19 checks) and the AI self-test (41 checks) lived in the arena. Combat and enemy AI currently have **no automated tests**; they should get a test scene of their own in the world.

## Running and testing

Set `G="C:/Users/User/Documents/games/_tools/godot/Godot_v4.7.2-stable_win64_console.exe"` and run from the project root.

**Main menu** (`scripts/ui/main_menu.gd`, shown by `main.gd`): two choices only, both from translation keys.
- *Continue* (`MENU_CONTINUE`) loads the most recently written slot. It falls back to the slot's `.bak`, is greyed out when no slot can be read, and on a failed load stays on the menu with `MENU_LOAD_FAILED` (it never starts a new game instead). A save whose region is `kur_vadisi` continues in the open world, otherwise in its chapter.
- *New Game* (`MENU_NEW_GAME`) takes the first empty slot, or asks before overwriting the oldest one (`MENU_OVERWRITE_*`). It then starts Chapter 1.
- There are no Settings or Quit entries on the title. Both are in the in-game pause menu (Esc).

**Main story (Chapter 1 → 2)**
- Play: `"$G" --path .` opens the title screen.
- Jump straight in: `"$G" --path . -- --demo=<mode>`. See the `settings.gd` header for the demo list (menu, explore, dialogue, fight…).
- Chapter 2 directly: `"$G" --path . res://scenes/chapter2.tscn`.

**Open world (Kür Vadisi)**
- The open world has no menu entry and no story path leads there yet. It is reached by *Continue* on a save made in the world, or from the command line: `"$G" --path . res://scenes/world.tscn` (loads the newest slot, or starts a new game in the first empty one).
- Self-test: `"$G" --path . res://scenes/world.tscn -- --demo=world_selftest` (28 checks).
- Views: `--demo=world_village | world_square | world_evening | world_deer | world_forest | world_dusk | world_night | world_rain | world_lake`.

**Common flags and hotkeys**
- `--capture=captures/x.png --frame=240` saves a screenshot and quits. It also prints a `PROFILE` line (fps, draw calls, primitives, VRAM).
- `--quality=low|high` forces the graphics preset.
- In game: F10 debug menu, F4 AI overlay, F6 streaming overlay, F3 FPS, F9 quality.

**Labs**
- `res://scenes/char_lab.tscn`: `CHAR_LAB_LOOKS`, `CHAR_LAB_WEAPON`, `CHAR_LAB_OVERLAY`.
- `res://scenes/tree_lab.tscn`: `TREE_LAB_IDS`, `TREE_LAB_DIST`.

**Content pipelines:** see `docs/WORLD_PIPELINE.md` for the cards → trees → foliage bake → houses → world order.

**State and save tests:** `"$G" --headless --path . res://scenes/tests/state_test.tscn`. **Animation isolation:** `"$G" --headless --path . -s tools/test_anim_isolation.gd`.

**Known tool issue:** `tools/check_scripts.gd` reports false failures, because autoloads do not exist in `-s` mode. Use the self-tests or run a scene to check scripts.
