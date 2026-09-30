# CLAUDE.md — Ashes of the Crown

A permanent guide for future sessions. Read this first. Then read `ARCHITECTURE_AUDIT.md` (how the code fits together and what is risky) and `docs/SPEC_V3.md` (the design spec). Log decisions in `docs/DECISIONS.md`.

**Story:** `STORY_BIBLE.md` is the canonical story reference. **Read STORY_BIBLE.md before any story-related task. Never invent story content; use placeholders for [TBD] items and flag them.** If code, data or a request conflicts with the bible, stop and ask.

## Project

- **What it is:** a 3D action-RPG. Aras, crown prince of Ateşan and Közcü (keeper) of its Great Hearth, fights through a frozen Caucasus / Silk Road land ruled from the burning castle by Kül Şahı — the King, his own father. The full story is in `STORY_BIBLE.md`.
- **Core mechanic:** *Yaddaş Yanğını*. Memories are fuel: burning them gives fire power at a cost.
- **Owner:** a solo developer with no engine experience. They delegate decisions and want the best option chosen, then explained. **Talk to the owner in Azerbaijani.**
- **Current direction:** a Bloodborne-like structure.
  - One unified world (menu: New game / Continue).
  - A persistent hub: Son Ocaq, a village grown around an old caravanserai; the last hearth burns in its courtyard. It changes with story actions and rescued NPCs. At night NPCs answer through closed doors. Death is permanent and NPCs have relationships.
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
6. **Keep the tests green.** Run ALL the suites before EVERY commit — state_test, echo_test, npc_test, hub_test, story_test, combat_test, tools/test_anim_isolation.gd and the windowed world_selftest — not only the ones that look affected (the HUD, dialogue and WorldState are shared by every mode). Add checks for new systems to the relevant self-test.
7. **Git.** Work on a `v3/<topic>` branch, commit per stage, merge to `main` with `--no-ff` after the tests pass, then `git push` (remote: private `github.com/AykhanHasanov/ashes-of-the-crown`). End commit messages with the attribution line the harness provides.
8. **Story.** Read `STORY_BIBLE.md` before any story-related task. Never invent story content; use placeholders for [TBD] items and flag them in the report.
9. **Assets.** CC0 (or clearly licensed) only. Record the source in a `CREDITS` file. Before downloading, state the file, source and size (the owner has given blanket approval).

## State & Save

**Autoloads:** `EventBus` (signals only), `WorldState` (all persistent state) and `SaveManager` (all file I/O). Load order: `DataDB`, `Settings`, `EventBus`, `WorldState`, `SaveManager`, `Memory`, `Fx`, `Audio`, `Barks`.

**WorldState**
- It is the single source of truth. Sections:
  - `meta`
  - `player`: stats, region, position, memory states
  - `inventory`
  - `flags`
  - `story`: chapter, checkpoint, echoes seen, beats (StoryDirector's played once-only beats)
  - `npcs`: one record per NPC definition (alive, location_id, rescued, relationship, death_cause, flags)
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
- Every memory has one of three states in WorldState (`player.memories`, id → state): UNKNOWN (not found; absent), KEPT, BURNED. Change them only with `keep_memory` (UNKNOWN → KEPT, emits `memory_kept`) and `burn_memory(id, context)` (UNKNOWN/KEPT → BURNED, emits `memory_burned`); read with `get_memory_state` / `has_burned`. Each burn records where it happened (`player.burn_context`: `echo` or `combat`; `get_burn_context`). Dialogue conditions: `memory:<id>` (burned), `kept:<id>`, `flag:<name>`, `alive:<npc>`, `dead:<npc>`, `rescued:<npc>`.
- `Memory` (the autoload) is only the rules layer. Memories with `combat_burnable = false` (e.g. `own_name`) are never offered to the fire wheel; they burn only in their echo.
- The fire wheel (`scripts/ui/radial_menu.gd`) burns KEPT memories too (intended). It needs hold-to-confirm: point at a memory and keep pointing for `ember.burn_hold_seconds` (`data/balance/combat.json`, 1.5 s, shared with the echo's BURN) while time is slowed; letting go early cancels.
- A burn's power is PERMANENT (the slice's stand-in for İbrahim's upgrades): `scripts/combat/burn_power.gd`, derived from the burned memories every time, never stored. Weight ≥ 2 = +50 max Köz (one more Köz Darbesi); weight 1 = faster Köz, diminishing, never zero (curve in `combat.json` `ember.burn_power`). The echo choice shows the gain; the journal shows it next to BURNED memories only. The one-time Alov Dalğası still fires on a burn.
- Refer to memories by id (`&"mother_name"`), never by title.

**Echoes** (the protagonist's lost memories, played as short scenes)
- Data: `EchoDefinition` resources in `data/echoes/*.tres` (id, memory_id, scene path, title/prompt/keep/burn keys), looked up through `scripts/core/echo_registry.gd`.
- Trigger: a `memory_echo` interactable (a glowing ember) in a world prefab, `{"kind":"memory_echo","echo":"<id>"}`. It disappears once its memory is decided.
- Flow: `scripts/echoes/echo_director.gd` (static state) stores scene, position, facing and clock, loads the echo scene; the echo scene extends `scripts/echoes/echo_mode.gd`, overrides `_make_level()`/`_start()` and calls `complete()`. The choice screen (`scripts/ui/echo_choice.gd`): KEEP (E) or BURN by holding Q / the button for 1.5 s. The choice is final: WorldState is written and the game autosaves at once, then chapter_base's `_return_from_echo()` puts him back exactly; a burn releases the existing Alov Dalğası.
- Echoes are non-lethal and never save (`SaveManager.can_save()` is false while `EchoDirector.active`). The echo system never hardcodes consequences: other systems listen to `memory_kept` / `memory_burned`.
- `test_echo` (`scenes/echoes/test_echo.tscn`, memory `first_sword`, keys `ECHO_TEST_*`) is a PLACEHOLDER.

**The protagonist's name**
- The protagonist is **Aras**. The name is only ever shown via the key `PROTAGONIST_NAME` and `scripts/core/names.gd` — never write it in code, scenes, data or dialogue. Internal ids use `protagonist`.
- In text, write the token `{PROTAGONIST}` and pass the text through `Names.fill(text, speaker_id)`. Once a name's memory is burned (`own_name` for his), **all text** shows the blank `NAME_FORGOTTEN` — UI, dialogue, subtitles, NPC lines. Voices keep saying the name (`tools/gen_voices.py` fills the token with the real name). The only exception is a speaker whose NpcDefinition sets `ignores_burned_names` (Kül Şahı, `data/npcs/kul_sahi.tres`) — never hardcode a speaker check.
- Names inside any line are tokens: `{NPC:<id>}` (and `{PROTAGONIST}`), filled by `Names.fill()` — never write an NPC's name raw in text. Aras's own knowledge of his name is the flag `protagonist_name_known` (dialogue action `reveal_name:protagonist`); what he can answer is `Names.protagonist_answer()` ("Bilmiyorum..." / name / blank).
- NPC names: `Names.npc(id)`. Until Aras knows a name (WorldState `is_name_known` / `reveal_name`, NPC flag `name_known`, dialogue action `reveal_name:<id>`; at the start only `name_known_at_start` NPCs — Rüfət) every label shows the capitalised epithet; once known, their `name_key`, blank once their `name_memory_id` burned. Dialogue nodes name NPC speakers with `"speaker_id"`.
- The HUD never talks over a conversation: title cards, banners, burn notices and whispers queue while a dialogue is open and come one at a time after it (`hud.queued()`).
- Old saves with the former name are renamed by the v1 → v2 migration in `save_manager.gd` (the only place the old name may appear).

**NPCs** (identities only; roles and quests come later from the owner)
- Data: `NpcDefinition` in `data/npcs/*.tres` (id, name_key `NPC_<ID>_NAME`, epithet_key `NPC_<ID>_EPITHET` plus epithet_rules `"condition=>KEY"` (first match wins), name_memory_id, look_id → `data/looks.json`, weapon/shield, voice_profile → `data/voices/voices.json`, dev-only personality_notes, home_location_id, companion, ignores_burned_names, npc_kind `human`/`shade`/`voice_only`, presence `hub`/`world`, tags `boss`/`hidden`, placeholder), looked up through `scripts/core/npc_registry.gd`. The cast follows `STORY_BIBLE.md` §7: V2's eight carried over without suspect content (`anar` became `nermin`, save v4 migrates it) plus the bible's new people as data only; `kul_sahi` is voice only. Show names with `Names.npc(id)` and epithets with `Names.npc_epithet(id)` (never blanked).
- A companion "joined" is not a flag: the condition `joined:<npc>` is true while their location is `party` (one fact, one owner).
- State: `WorldState` NPC accessors (`move_npc`, `rescue_npc` → location `son_ocaq`, `kill_npc` — permanent, `change_npc_relationship`, `set_npc_flag`) with `npc_moved` / `npc_rescued` / `npc_died` / `npc_relationship_changed`. Locations: a POI id, `party` (with the protagonist), `son_ocaq` (hub, not built), or `""`.
- Bodies come only from WorldState: `scripts/npc/npc_spawner.gd` (world_mode owns one) builds a `resident.gd` at a loaded POI or an `ally.gd` for a companion in the party; the dead never get a body again. Never hand-place a named NPC. Generic villagers (`data/world/villagers.json`) are separate and unchanged.
- The ally (`scripts/npc/ally.gd`, numbers in `data/balance/allies.json`): a player-side Combatant that follows, fights, sometimes draws an enemy off the protagonist (`Foe.retarget`). At 0 health he is DOWNED, never dead: the protagonist helps him up ([E], `help_up()`), or he rises alone when no enemy is near. Only the story kills him (`kill_npc`).

**Story foundation** (vertical slice, `STORY_SLICE.md`)
- Conditions: `scripts/core/conditions.gd` — leaves joined with `&`, negated with `!`; WorldState leaves include `known:`, `mem:<id>=KEPT|BURNED|UNKNOWN`, `has_item:`, `any_burned`, `any_kept`, `rescued:`, `dead:`, `grief:`, `joined:`, `time:`, `flag:`. Actions (`WorldState.apply`): `set:`, `reveal_name:`, `item:+/-`, `move_npc:<id>:<loc>`, `grief:`; anything else goes to the mode through `DialogueUI.action_requested` (`silence_door:<door>`, `lights_out:<door>`).
- Dialogue graphs: `data/story/dialogue/<id>.json` through `scripts/story/dialogue_graphs.gd` (speaker, key, next, choices with `if` / `disabled_if`, `branch`, `name_challenge`, `do`, `sfx`, `label_key`). A `(…)` in a line is a pause, not text (`pause_changed`; the door shadow freezes).
- Names: `{NPC_LOST:<id>}` always shows the lost one's name; `Names.scene_all_known` in echoes and the cold open; `EchoDefinition.reveals_on_keep`.
- Barks: a line in `data/voices/voices.json` may be `{key, if}`; `Barks.playable()` filters by condition and never plays a line with `{PROTAGONIST}` before `known:protagonist`.
- Items: `data/items/<id>.json`, `scripts/world/item_pickup.gd` (taken pickups in the world list `pickups`).
- StoryDirector (`scripts/story/story_director.gd`, every V3 mode owns one as `story`): beats in `data/story/act1_beats.json` — `on` (enter, phase, flag, dialogue_end, interact, rest, encounter_end, encounter_wave `<id>:<n>`, near `<spot>`, health_below + `during`), `if`, `where`, `repeat`, `do` (dialogue:, whisper:, banner:, card:, encounter:, wait:, any WorldState action, else the mode's `on_story_action`). Once-only beats are stored in `story.beats` (save v8). Modes name places for it with `story_spot(id)`.
- Közcü journal (`scripts/ui/kozcu_journal.gd`, Tab, V3 modes): people met (NPC flags `met` / `last_line`, recorded by chapter_base from every shown line; `NpcDefinition.relation_key`), the one-line thread (world value `thread`, action `thread:<KEY>`), kept/burned memories.
- Hub nights (`scripts/hub/hub_nights.gd`): counted per NPC in the hub only (`hub_nights`); warning from `warning_night`; FAIRNESS: death only on a hub night after the warning was HEARD (the line at his door, or `warning_heard:<npc>` — Domrul's line 3); unheard it repeats; `cancel_if` (grief resolved) ends it.
- Aras's room (hub): hollow room behind `door_protagonist` (`hub_level.room_spots`, `in_room`); by day walk in; at night "Odana gir", inside "Dinle / Dışarı çık"; Rüfət sits awake on his bed at night (`ally.rest_at`) — permanent design.
- Kartal Yamacı: `scenes/kartal_yamaci.tscn` (`scripts/kartal_mode.gd`, `scripts/world/kartal_level.gd`), region `kartal_yamaci`, reached by the trail sign at Karaağaç Ocağı (`hearth.json` interact `trail`; `HubTravel.enter(..., target)`), Yadigar stands by that sign (`stand` in the entry → world_mode `_npc_stand`). Views `--demo=kartal | kartal_hut | kartal_lit` (the lit hearth variant, debug only).
- Balance rule: every slice encounter is comfortably beatable at base values (no burns). The balance suite in combat_test plays each (`combat.json` `balance_check`) with a plain bot, with the story's beats live (Rüfət joins S2 at wave 2 or below 30% health); every seed must win with ≥ 40% health.
- Tests: `"$G" --headless --path . res://scenes/tests/story_test.tscn` (99 checks).

**Tests:** `"$G" --headless --path . res://scenes/tests/state_test.tscn` covers state, saves, migration and every main-menu case. It uses its own save folders.

**Combat, AI, encounters and balance:** `"$G" --headless --path . res://scenes/tests/combat_test.tscn` (env `BALANCE_DEBUG=1`: the balance suite only). It runs four suites on a primitive test yard (`scripts/debug/test_yard.gd`, the old arena's layout) with the real protagonist and Foe nodes:
- combat: 19 checks;
- enemy AI: 41 checks;
- encounters: 13 checks;
- balance: 10 checks (the slice encounters at base values, the S2 rescue, attack tokens returned).

It exits with the failure count and takes about 4 minutes headless.

**Echoes, memory states, names, migration:** `"$G" --headless --path . res://scenes/tests/echo_test.tscn` plays the real KEEP and BURN flows (host `scenes/tests/echo_host.tscn` → test echo → back), checks hold-to-confirm, position/clock restore, save/load of the three states, v1/v0 migration incl. the name rename, the blank name, and scans the project for the old protagonist name.

**NPCs, ally, names in subtitles, fire wheel:** `"$G" --headless --path . res://scenes/tests/npc_test.tscn` (72 checks): definitions, NPC state and signals, save/load and v2 → v3 migration, spawning from WorldState (the dead never respawn, rescue moves them away), name blanking for NPCs and in subtitles (Kül Şahı excepted), Rüfət's fight / downed / help-up / recover, the ally never hurting the protagonist, burn contexts, the wheel's hold-to-confirm.

## Running and testing

Set `G="C:/Users/User/Documents/games/_tools/godot/Godot_v4.7.2-stable_win64_console.exe"` and run from the project root.

**Main menu** (`scripts/ui/main_menu.gd`, shown by `main.gd`): Continue, New Game, Settings and Quit, all from translation keys (`MENU_*`). Settings opens the same screen as the pause menu.
- *Continue* (`MENU_CONTINUE`) loads the most recently written slot. It falls back to the slot's `.bak`, is greyed out when no slot can be read, and on a failed load stays on the menu with `MENU_LOAD_FAILED` (it never starts a new game instead). A save whose region is `kur_vadisi` continues in the open world, otherwise in its chapter.
- *New Game* (`MENU_NEW_GAME`) takes the first empty slot, or asks before overwriting the oldest one (`MENU_OVERWRITE_*`). It then starts the slice in Kür Vadisi (`main.prepare_new_game`; the cold open S0 comes in phase C). V2's Chapter 1 is only reachable from the world's F10 menu (*Eski*).

**Main story (Chapter 1 → 2)**
- Play: `"$G" --path .` opens the title screen.
- Jump straight in: `"$G" --path . -- --demo=<mode>`. See the `settings.gd` header for the demo list (menu, explore, dialogue, fight…).
- Chapter 2 directly: `"$G" --path . res://scenes/chapter2.tscn`.

**Open world (Kür Vadisi)**
- New Game starts here. It is also reached by *Continue* on a save made in the world, or from the command line: `"$G" --path . res://scenes/world.tscn` (loads the newest slot, or starts a new game in the first empty one).
- Self-test: `"$G" --path . res://scenes/world.tscn -- --demo=world_selftest` (30 checks). It turns off elite affix rolls (`world_mode.roll_affixes`) and waits for landings instead of fixed times, so it stays deterministic under load.
- Views: `--demo=world_village | world_square | world_evening | world_deer | world_forest | world_dusk | world_night | world_rain | world_lake`.

**Encounters** (`scripts/world/encounter.gd`, data in `data/encounters/*.json`)
- Waves of enemies rise around a point, one wave after another.
- The encounter only runs the fight. Banners and music come from the mode, via `EventBus.encounter_started` / `encounter_wave_started` / `encounter_finished`.
- What a finished encounter means for the story is written to WorldState by the caller.
- In the world: `world_mode.start_encounter(id, center)`, F10 → *Karşılaşma*, or `--demo=world_encounter`.
- `test_ash_rising` is **placeholder data**. Real encounters and bosses are designed with the new story.

**Common flags and hotkeys**
- `--capture=captures/x.png --frame=240` saves a screenshot and quits. It also prints a `PROFILE` line (fps, draw calls, primitives, VRAM).
- `--quality=low|medium|high` forces the graphics preset (F9 cycles them; the settings screen offers all three).
- In game: F10 debug menu, F4 AI overlay, F6 streaming overlay, F3 FPS, F9 quality.

**Look (lighting and presets)**
- Every outdoor mode lights through `scripts/world/day_night.gd`; its look is data in `data/world/lighting.json`: warm low sun, cool blue ambient, soft shadows, AgX, glow, haze and valley mist, and per preset what is on.
- Low: glow, 2 shadow splits. Medium: + SSAO and coarse volumetric fog. High: + SSIL, finer volumetric fog, 4 splits, contact-hardening shadows. `Settings.is_high()` is High only; `Settings.at_least_medium()` for Medium and up.
- SDFGI is NOT part of a preset: it is the separate, experimental "Küresel aydınlatma (deneysel)" setting (`Settings.global_illumination`, `--gi=on`), off by default. It does not read the sky (on the dev Intel UHD its probes turned characters and trees chrome-white even with correct materials); two shadowless cool "sky fill" lights stand in for the sky while it is on.
- First launch: `scripts/systems/benchmark.gd` times every frame of the first gameplay scene at Medium with vsync off, throws the first 1.5 s away, and picks the preset from the MEDIAN frame rate (`lighting.json` benchmark; no measurement → Medium; an integrated GPU never gets High). It logs median / 1% low / mean and shows a 3.5 s notice (`BENCH_RESULT`). Saved; the player can change it. `--benchmark` runs it now without saving. Never in a --demo, capture or headless.
- Night readability: ambient never drops below `ambient.min_energy` (times the mode's `mood_scale`, so the hub's door talk still goes dark), its colour turns moonlit blue at night, and a weak cool shadowless `camera_fill` light shines along the camera's view at night so the character is never a black cut-out. Without GI the shaded side is lit by this environment ambient; with SDFGI the engine replaces the ambient with its own bounce light, which is why the sky-fill lights exist only in GI mode. Stills: `--demo=hub_light_hearth | hub_light_corner`.
- Materials: non-metals are `metallic 0`, `roughness >= 0.7` (`scripts/core/material_policy.gd`), applied at glTF import (`tools/import/material_policy_import.gd` is every model's import script — keep it when adding models) and to baked foliage (`tools/fix_materials.gd`). Exceptions (`data/art/material_policy.json`): a material named `..._keep`, listed in `keep_materials`, from a `keep_models` path, or with a metal word in its name is left as authored. Audit: `-s tools/audit_materials.gd`; list and how-to in `docs/MATERIAL_AUDIT.md`.
- Hearths look through `scripts/world/hearth_fire.gd` (lit: stone ring, embers, flames — mixed blend, so no white blob — sparks, flickering light; cold: ash, charred logs, a thread of smoke): Kartal Yamacı, the Son Ocak hearth, every valley hearth (cold until lit). Air dust: `Effects.dust_motes`. Views `--demo=world_hearth | world_hearth_lit`.

**Before every merge to main:** `docs/MERGE_CHECKLIST.md` — all the headless suites, the world self-test and the two-launch flow test.

**Session flow (before a merge to main):** `scenes/tests/flow_test.tscn` plays the real game in two launches on a clean user profile (New Game → valley, the benchmark → light a hearth → Son Ocak → change the preset in the settings → save → quit; then restart → Continue → the preset and the lit hearth are still there). Windowed, not part of the headless suites; the commands (APPDATA pointed at an empty folder, `FLOW_PHASE=1` then `2`) are in the header of `scripts/debug/flow_selftest.gd`.

**Labs**
- `res://scenes/char_lab.tscn`: `CHAR_LAB_LOOKS`, `CHAR_LAB_WEAPON`, `CHAR_LAB_OVERLAY`.
- `res://scenes/tree_lab.tscn`: `TREE_LAB_IDS`, `TREE_LAB_DIST`.

**Content pipelines:** see `docs/WORLD_PIPELINE.md` for the cards → trees → foliage bake → houses → world order.

**State and save tests:** `"$G" --headless --path . res://scenes/tests/state_test.tscn`. **Echo tests:** `"$G" --headless --path . res://scenes/tests/echo_test.tscn`. NPC tests: `"$G" --headless --path . res://scenes/tests/npc_test.tscn`. Son Ocaq (hub, in progress — step 4): `"$G" --headless --path . res://scenes/tests/hub_test.tscn` (138 checks); control hints on the HUD come only from `scripts/ui/control_hints.gd` (the live InputMap) — never write them in a mode; scene `res://scenes/son_ocaq.tscn`, views `--demo=hub_day | hub_night | hub_doors | hub_leave | hub_door_talk | hub_door_burned | hub_room | hub_room_day | hub_journal`; talking by day and through doors at night: `scripts/hub/door_talk.gd` with `data/hub/door_talk.json` (placeholder keys, day/night pools, silent_if, challenge, knock rhythms), dialogue node type `name_challenge`, muffled `Door` audio bus for NPC voices only; nights: `scripts/hub/hub_nights.gd` with `data/hub/night_events.json` (warning night → death night, resolved only while waiting at the hearth until morning; aftermath derived from death_cause "door"), shades `scripts/hub/hub_shade.gd` (never combatants), views `--demo=hub_shades | hub_morning_after`, valley road `--demo=world_hub_gate`. NPC views: `--demo=world_npcs` (the residents in Kürköy's square, Rüfət with the protagonist), `--demo=world_ally` (Rüfət and a bandit). Echo views: `--demo=world_echo` (walk to the ember and enter), `res://scenes/echoes/test_echo.tscn -- --demo=echo_choice` (straight to the choice screen). **Animation isolation:** `"$G" --headless --path . -s tools/test_anim_isolation.gd`.

**Known tool issue:** `tools/check_scripts.gd` reports false failures, because autoloads do not exist in `-s` mode. Use the self-tests or run a scene to check scripts.
