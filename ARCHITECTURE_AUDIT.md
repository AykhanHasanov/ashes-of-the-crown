# Architecture Audit — Ashes of the Crown

- **Date:** 2026-09-27
- **Code state:** `main` @ `7ec1d12`. Safety tag: `pre-redesign-v0`.
- **Engine:** Godot 4.7.2 (Forward+) with Terrain3D 1.0.2.
- **Companion document:** `AUDIT.md` (Azerbaijani). It has the per-file KEEP / CHANGE / TEST-ARENA / ARCHIVE classification and a system quality table. This document covers the architecture questions and the risks for the persistent hub.

**Methodology.** I read every script header and the core systems in full. I compiled all scripts and ran the game from `main.tscn` with warnings captured. The three self-tests pass: `arena_selftest`, `ai_selftest` and `world_selftest`.

---

## 1. Folder structure

| Folder | Contents |
|---|---|
| `scenes/` | Six `.tscn` files. **Each one is only a root node plus a script.** Every other node is built in code by the mode script (see §3) |
| `scripts/` | All game code (~16.3k lines, 79 files). Subfolders: `camera/`, `characters/`, `combat/`, `core/`, `debug/`, `enemies/`, `npc/`, `player/` (V2), `player_v3/`, `story/`, `systems/` (autoloads), `ui/`, `world/` (+ `world/gen/`). The five mode scripts sit at the root: `main.gd`, `chapter2.gd`, `chapter_base.gd`, `world_mode.gd`, `arena_mode.gd` |
| `data/` | JSON content. `balance/` holds combat, ai, affixes and world tuning. `enemies/` has 13 enemy definitions and `weapons/` has 3. `world/` holds the layout, POI rules, vegetation, trees, houses, villagers and 14 POI prefabs. `voices/` has the voice config and generated manifest. `looks.json` holds the human appearance presets |
| `shaders/` | 21 shaders: characters, foliage, terrain, water, sky, UI and effects |
| `tools/` | Offline generators run headless with `-s`: world, trees, houses, foliage bake, animation library, heads, voices (Python), SFX (Python), foliage cards (Python). Also inspection and check scripts |
| `assets/` | Models, textures and audio. Details: `CREDITS.md`, `assets/*/CREDITS.txt` |
| `world/` | Generated Terrain3D regions (`world/terrain/*.res`), `world/generated/world_meta.json` and the parchment map |
| `docs/` | GDD, SPEC_V2, **SPEC_V3** (the active spec), DECISIONS (decision log), ENEMIES, ANIMATIONS, WORLD_PIPELINE |
| `addons/terrain_3d/` | The Terrain3D GDExtension |

---

## 2. Autoloads (load order)

| Autoload | Script | Responsibility |
|---|---|---|
| `DataDB` | `core/data_db.gd` | Loads JSON under `res://data`. `balance(id)`, `weapon(id)`, `enemy(id)`, `world(file)`, `prefab(type)` |
| `Settings` | `systems/settings.gd` | Player settings (`user://settings.cfg`): quality preset, volumes, subtitles, key bindings. Also parses the command-line debug args (`--demo`, `--capture`, `--frame`, `--quality`) |
| `Memory` | `systems/memory_system.gd` | Yaddaş Yanğını: the 6 memories, which are burned, and Kül Şahı's whispers. Signals `memory_burned` and `memories_reset` |
| `GameState` | `systems/game_state.gd` | Saveable progress: chapter, checkpoint, flags, echoes seen, the open-world `world` dictionary. `save_game`, `load_game`, dialogue `apply`/`check` |
| `Fx` | `systems/fx.gd` | Game feel: hit-stop, slow motion (named time holds), camera shake/punch, damage numbers, notifications, one-shot VFX. **Holds references to the current scene's camera rig and world** (`Fx.camera_rig`, `Fx.world`) |
| `Audio` | `systems/audio.gd` | Pooled SFX (2D/3D), music layer crossfade (ambient/battle), wind |
| `Barks` | `systems/barks.gd` | Voiced 3D lines with subtitles for enemies and villagers. At most 2 voices at once, with cooldowns |

---

## 3. Scene trees at runtime

All trees below are built in code. `chapter_base.gd._ready()` always creates this core:

```
<ModeRoot> (Node3D, mode script)
├─ level              (_make_level())
├─ rig                (_make_camera())         V2 CameraRig | V3 TPCamera
├─ player             (_make_player())         V2 Player    | V3 Aras
├─ Hud, DialogueUI, PauseMenu, Journal, RadialMenu, AshOffer   (CanvasLayers)
└─ ...mode-specific children from _setup()
```

**Main menu + Chapter 1** (`scenes/main.tscn` → `main.gd`, the main scene):
```
Main
├─ Kozqala (world/kozqala.gd): courtyard, walls, throne, crater, braziers, FX, all built in code
├─ CameraRig (orbiting for the title), Player (V2, KayKit)
├─ core UI … + MainMenu (ui/main_menu.gd, on top while at the title)
├─ Companion "Rüfət" (npc/companion.gd)
├─ AshShade × n per wave (enemies/ash_shade.gd)
├─ EchoSpot × 3 (world/echo_spot.gd), plus a ghost CharacterModel for the echo replays
```

**Chapter 2** (`scenes/chapter2.tscn` → `chapter2.gd`):
```
Chapter2
├─ SonOcaq (world/son_ocaq.gd extends kozqala.gd): the caravanserai yard
├─ CameraRig, Player (V2) + core UI
└─ Survivor × 8 (npc/survivor.gd; data in story/survivors.gd)
```

**Open world** (`scenes/world.tscn` → `world_mode.gd`):
```
WorldMode
├─ OpenWorld (world/open_world.gd)
│  ├─ DayNight (WorldEnvironment + sun/moon), Weather (rain particles and audio)
│  ├─ Terrain3D (+ instanced vegetation MMIs), Water, WorldBounds, ambience players
│  ├─ CellStreamer: per-POI visual nodes (threaded), colliders, lights, Interactables
│  ├─ Birds, Wildlife (deer herds)
├─ TPCamera, Aras (V3, realistic Human model) + core UI
├─ Compass, WorldMap, HearthMenu, DebugMenu (F10), AiOverlay (F4), stream label (F6)
├─ Foe × n: spawned per POI actor, tracked in world_mode._foes by "poi@index"
└─ Villager × n: spawned when a village POI loads fully, freed when it unloads
```

**Fight zone** (`scenes/arena.tscn` → `arena_mode.gd`):
```
ArenaMode
├─ Arena (world/arena.gd extends kozqala.gd): walled ring, hearth, torches
├─ TPCamera, Aras (V3) + core UI
├─ DebugMenu (spawn any enemy, weapons, burn memories), AiOverlay
└─ Foe × n (8 waves) | CombatSelfTest | AiSelfTest (with --demo)
```

---

## 4. How the three menu modes load, and what they share

The main menu lives inside `main.gd` (Chapter 1's scene). Its buttons work as follows:

- **Devam et / Yeni oyun** stay in `main.tscn`. `GameState.load_game()` or `new_game()` runs, then Chapter 1 starts or resumes from its checkpoint. Chapter 2 is reached with `chapter_base.go_to_chapter(2)`, which calls `change_scene_to_file`. A **`static var restart_mode`** carries "checkpoint" / "fresh" across the scene change.
- **Kür Vadisi (open world)** calls `change_scene_to_file("res://scenes/world.tscn")`.
- **Savaş arenası (fight zone)** calls `change_scene_to_file("res://scenes/arena.tscn")`.

**Shared code**
- Everything shares `chapter_base.gd`, all the autoloads, `hud.gd`, the UI screens, `effects.gd` and `visuals.gd`.
- The open world and the fight zone share the whole V3 core: `aras`, `foe`, `combatant`, `perception`, `third_person_camera`, `human`, `debug_menu`, `ai_overlay`.
- **The story chapters share none of the V3 gameplay.** They run the V2 player, camera and enemy.

**Shared state**
- All modes read and write the same autoloads: `GameState`, `Memory`, `Settings`.
- Save files differ. The story uses `user://save.json`. The open world keeps its progress in `GameState.world` but saves to `user://world_test.json`.
- **The modes clobber each other's in-memory state.** The save files on disk are safe, because Continue reloads `save.json`.
  - `arena_mode._setup()` calls `GameState.new_game()`. That wipes chapter, flags, echoes, the world dictionary and burned memories.
  - `world_mode` loads `world_test.json` over the same `GameState`, replacing the story's chapter, flags and memories with whatever that file holds. Its autosave then writes story fields into the world file too.
  - There is one `GameState`, but the modes treat it as their own.

**Duplicated logic:** about 1.7k lines. Full list in `AUDIT.md` §c.
- player ↔ aras
- ash_shade ↔ foe
- camera_rig ↔ third_person_camera
- survivor ↔ villager
- two hearth implementations
- echo_spot ↔ interactable "echo"
- two wave systems
- `balance.gd` ↔ `data/balance/*.json`

---

## 5. Game state: where it lives

| State | Where | Persisted? |
|---|---|---|
| Health, stamina, stance | `combatant.gd` vars on the player node | No. Rebuilt at spawn |
| Flasks (current/max) | `protagonist.gd` (`flasks`); the max also in `GameState.world["max_flasks"]` | Max only |
| Equipped weapon | `protagonist.gd` (`weapon`, from `data/weapons/`) | **No** |
| Ember / Köz meter | `protagonist.gd` (`ember`) | No |
| Burned memories | `Memory.burned` | Yes (`memory.burned` ids) |
| Story progress | `GameState.chapter`, `checkpoint`, `echoes_seen` | Yes |
| Flags | `GameState.flags` (Dictionary of `true`), set by dialogue `set`/`do` and code | Yes |
| Open-world progress | `GameState.world`: string lists `hearths`, `chests`, `echoes`, `discovered`, `killed`, plus `fog` (base64 bits), `hour`, `pos`, `max_flasks` | Yes, in the world save |
| NPC state (needs, routine position, relationships) | Node vars in `survivor.gd` / `villager.gd` | **No.** Lost when a POI unloads or the scene changes |
| Enemy state | Foe nodes; kills recorded as `poi@index` in `world.killed` | Kills only |
| **Inventory** | **Does not exist.** There are no items, currency, levels or player progression (Phase D is not started) | — |

---

## 6. Save / load

**The file**
- `GameState.save_game(path)` writes one JSON: `{version: 4, chapter, checkpoint, flags, echoes_seen, memory: {burned: [...]}, world: {...}}`.
- `load_game(path)` accepts versions 3 and 4, with no migration code beyond "a v3 file has an empty world".

**When it saves**
- Story chapters save at checkpoints.
- The open world saves when resting at a hearth and every 5 minutes, to `user://world_test.json`.

**Gaps**
- No save slots.
- No schema migrations.
- No central registry of what is saveable. Each system pokes string keys into `GameState.world`.
- No event log.
- Player stats and equipment are not saved.
- The two save files cannot both be "the game".

---

## 7. Memory burning (Yaddaş Yanğını)

**Data**
- `Memory.MEMORIES` is a **GDScript constant** with 6 entries `{id, title, text, cost}`. Titles and texts are in Turkish.
- `Memory.WHISPERS` holds 6 Kül Şahı lines.
- `gifted` exists but is never filled (it was meant for V2 phase 5).

**Signals**
- `Memory.memory_burned(memory)` is heard by the HUD (memory diamonds), the V2 player and Aras (burn look).
- `Memory.memories_reset` fires on new game and load.
- `radial_menu.confirmed(ok)` answers the one-time "are you sure".
- `ash_offer.resolved(accepted)` answers Kül Şahı's offer.

**V3 flow in `protagonist.gd`**
1. **Tap Q:** Köz strike. `_ember_strike()` spends the ember meter. Ember fills from hits, kills and perfect dodges.
2. **Hold Q:** opens `RadialMenu`, which slows time. On release, `cast_wave(id)` → `_do_cast()` → `Memory.burn(id)` → a fire nova (radius and damage from `data/balance/combat.json` → `ember`).
3. **Health ≤ `offer_health_fraction`:** `AshOffer` opens once per encounter. Accepting calls `Memory.burn_random()` and heals to full.
4. **`_refresh_burn_look()`:** the ash overlay intensity and ember light scale with `burned.size()`. **This is the de-facto "ash level".**

**Consequences are hardcoded by id across files**

| Memory id | Effect | Where |
|---|---|---|
| `mother_name` | Weaker hearth healing | `chapter_base.gd` |
| `sabir_lesson` | Harder perfect dodge | `protagonist.gd` |
| `father_voice` | Echoes go silent | `main.gd`, `journal.gd` |
| `rufet_face` | Rüfət not recognised | `main.gd`, `chapter2.gd`, dialogue branches |

The dialogue data branches on `memory` burned/intact. The V2 `player.gd` has its own copy of the whole flow.

---

## 8. NPC, dialogue and interaction systems

**NPC brains (three separate ones)**
- `npc/companion.gd`: Rüfət, V2, KayKit. Follows, fights beside Aras and talks.
- `npc/survivor.gd` + `story/survivors.gd`: V2 needs-based utility AI (warmth, company, duty). Picks an activity; the greeting is spoken on interact.
- `npc/villager.gd` + `data/world/villagers.json`: V3 hourly schedule with work spots and routes via a hub point. Turns to greet Aras with voiced Barks, walks home at night (hides the model), flees from nearby aggro foes. Moves kinematically on the terrain height. **Spawned per POI type from static JSON: there is no per-NPC identity or persistence.**

**Dialogue**
- `ui/dialogue_ui.gd` takes a Dictionary of nodes: `speaker`, `text`, `next`, `choices[{text, next, set, event}]`, `branch{memory, burned, intact}`, `do`.
- Conditions are only `memory:<id>` and `flag:<name>` (`GameState.check`).
- Presentation is cinematic: letterbox bars, a camera close-up via `rig.cinematic`, a typewriter effect.
- The content lives in GDScript (`story/rufet_dialogue.gd`, `story/king_echoes.gd`, inline in `main.gd`), not in data.

**Interaction**
- V2: `chapter_base.near_prompt()` handles `[E]` prompts by distance to a node or point, with a talk range of 3 m.
- V3: `world/interactable.gd` nodes (hearth, chest, echo), created by the streamer from prefab `interact` entries. Their state is keyed in `GameState.world`.
- Houses (`tools/build_houses.gd`) are merged meshes: **doors are not separate nodes and have no recorded positions.**

---

## 9. Godot 3 / deprecated API scan

**No Godot 3-style code found.** I searched for `yield`, `.instance()`, `onready`/`export` without `@`, `setget`, `KinematicBody`/`Spatial`, `rand_range`, `stepify`, `deg2rad`, `Pool*Array`, `change_scene(`, `OS.get_ticks_*`, `funcref`, `VisualServer`, `.empty()`, string-based `connect(... self ...)`. Every script uses Godot 4 syntax: typed `:=`, `@export` where used, Callables, `await`. Running `main.tscn` prints no deprecation warnings.

Things to watch:
- **`tools/check_scripts.gd` reports 41 false "FAILED".** In `-s` mode the autoloads do not exist, so every script that references `DataDB`, `Fx` and so on fails to compile. The tool is broken, not the scripts; it needs to run inside a scene or stub the autoloads.
- **Terrain3D 1.0.2 was built for Godot 4.4–4.6.**
  - It logs `instance_reset_physics_interpolation() is deprecated` and a harmless `Error loading resource: ''` when added to the tree.
  - Three instancer workarounds live in `open_world.gd`: MMI placement at region corners, custom distance culling, asset assignment after entering the tree.
  - A Terrain3D update may make them unnecessary or wrong.
- `settings.gd` uses `get_node("/root/Barks")` because Barks loads after Settings. It works, but depends on load order.
- `Human.play_action()` writes `loop_mode` on animations from a **shared** `AnimationLibrary` resource, a cross-character side effect (see §10).

---

## 10. Technical debt, duplication, hardcoding, fragile dependencies

**Duplication:** see §4 and `AUDIT.md` §c. About 10% of the code.

**Monoliths**
- `enemies/foe.gd` (1573 lines): AI, animation, UI bar, barks, affixes, statuses and phases in one file.
- `player_v3/protagonist.gd` (1399 lines): movement, combat, ember, memory wheel, lock-on and UI signals.

**Hardcoded values and strings**
- Memory ids scattered across 6 files (§7).
- POI id `"hearth_west"` in `world_mode._update_compass`.
- World size `512` and margins `20/492` in `wildlife.gd`. The bounds are also in `open_world`.
- V2 tuning in `systems/balance.gd`, still used by `chapter_base` (hearth healing for *all* modes) and `ash_offer`.
- `CHAPTER_SCENES` dictionary in `chapter_base`.
- Player-facing Turkish strings inline in code (`Fx.notify("Kusursuz kaçış")`, HUD prompts, menu labels) instead of a string table.

**Fragile dependencies**
- **Autoloads hold scene references:** `Fx.camera_rig` and `Fx.world` are set by each mode. A stale reference after a scene change would crash Fx calls.
- **Direct wiring:** `player.radial = radial`, `player.offer = offer`, `player.rig = rig`, `player.water_query = level.water.surface_at`. The villager setup is handed `level.day_night`, `player` and `level.height_at` directly.
- **Group scans each tick:** villagers call `get_tree().get_nodes_in_group("enemies")` every 0.5 s each, and the dodge check scans `"combatants"`.
- **Test timing:** the self-tests depend on real time. They get flaky under load; `Human.warm_up()` mitigates this.
- **`static var restart_mode`** as cross-scene state.
- **Mixed line endings** (CRLF vs `.gitattributes` LF), so git warns on every commit.

---

## 11. Risks for the persistent hub

| # | What will fight us | Why | Mitigation |
|---|---|---|---|
| 1 | **NPC state lives in nodes** | `villager.gd` / `survivor.gd` keep everything in vars. The streamer frees villagers when their POI unloads, and scene changes wipe them. A hub whose residents die permanently, change relationships or move in after a rescue needs per-NPC records | A central `WorldState.npcs[id]` (alive, location, relationships, rescued_from, memories). NPC nodes become views that read it and emit events |
| 2 | **No stable NPC identity** | Villagers are spawned from a per-prefab list with no ids. Rescued enemies (`foe` nodes) have no path into the villager system | Give NPC ids in data, plus a "rescued → resident" transition that writes to WorldState, and a spawner that places residents by schedule |
| 3 | **The save model is ad-hoc and split** | String lists in `GameState.world`, two files, no migrations, no player stats or inventory. The modes also overwrite the one shared `GameState` in memory (§4) | A single WorldState + Save with a versioned schema and migration hooks, before any hub content is written |
| 4 | **Story runs on a different stack and scenes** | The chapters use V2 player, camera, enemies and KayKit art in separate scenes. Hub reactions to story actions cannot see them | Port the chapter content into the unified world on the V3 stack, and drive "story actions" through an EventBus that the hub listens to |
| 5 | **Doors do not exist as objects** | Houses are merged meshes; the door is baked into geometry. Night "answers through closed doors" needs a door position, facing and an interaction per house | Record door transforms as metadata in `build_houses.gd`, the same way it already records chimneys, and spawn a door `Interactable` per resident's home |
| 6 | **Dialogue conditions are too thin** | Only `memory:` / `flag:`. Door dialogues need time of day, NPC state, relationship, night stage, the rescued-by-player condition, and a "no visible speaker" presentation (the cinematic close-up assumes a face) | Extend `GameState.check` into a condition registry. Move dialogue content to data. Add a voice-only presentation mode to `dialogue_ui` |
| 7 | **Time and night stages** | `DayNight.hour` is a plain var polled by villagers. "Night deepens" (4 stages) will change lighting, spawns and NPC behaviour at once | `DayNight` emits signals (hour, dusk, dawn), and a `night_stage` in WorldState broadcast on the EventBus instead of polling |
| 8 | **The memory system's shape** | Six hardcoded personal memories with effects wired by id. The new design burns a collected currency | Keep the id-effect table as data. Separate "currency burning" (Yaddaş Yanğını power) from "story memories" before the hub reads either |
| 9 | **Performance headroom** | The village already runs 17–21 fps on the dev laptop (Intel UHD). Each resident is a skinned Human with about 8–10 draw calls plus shadows. A busy hub at night with lights adds more | NPC LOD (animation throttling and shadows off at distance), fewer shadow-casting lights, profiling on the target (Asus) machine |
| 10 | **Shared animation resource mutation** | Many residents play one-shot animations. `play_action` changing `loop_mode` on shared clips can silently break other NPCs' loops | Duplicate per-character or never mutate library clips. Fix before the hub scales NPC count |

---

## 12. Recommended fix order (before building the hub)

1. **WorldState + EventBus + unified Save** (§6, §11.1–3).
2. **Single world:** retire the chapter scenes and `restart_mode`; the menu offers only New / Continue; the fight zone moves to the debug menu (§4).
3. **NPC model:** one NPC brain (villager + survivor) reading per-NPC records from WorldState, with stable ids, schedules as data and permanent death (§8, §11.1–2).
4. **Hub hooks:** door metadata in houses, a dialogue condition registry, and a voice-only door dialogue (§11.5–6).
5. **Hygiene:**
   - fix the shared-animation mutation;
   - move `balance.gd` values to JSON;
   - centralise memory effects;
   - fix `check_scripts.gd`;
   - normalise line endings.

   These are cheap and remove traps (§9, §10).
