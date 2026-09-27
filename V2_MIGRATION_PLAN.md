# V2 Migration Plan — Chapter 1 (Közqala) and Chapter 2 (Son Ocaq)

**Status:** analysis only. No chapter code was changed.

**Base:** `main` after the arena removal (2026-09-28).

**Inputs:** `scripts/main.gd`, `scripts/chapter2.gd`, `scripts/chapter_base.gd`, the V2 systems (`player/player.gd`, `camera/camera_rig.gd`, `enemies/ash_shade.gd`, `npc/companion.gd`, `npc/survivor.gd`), the levels (`world/kozqala.gd`, `world/son_ocaq.gd`, `world/echo_spot.gd`), the content (`story/rufet_dialogue.gd`, `story/king_echoes.gd`, `story/survivors.gd`), `docs/GDD.md` and `docs/SPEC_V2.md`.

## Top-level recommendation

**Rebuild the chapters on the open-world systems; carry over their content, not their code.**

The hypothesis holds for systems (replace them) and for dialogue (port it). It **does not hold** for level layouts and scripted events:
- The two levels are built in code from KayKit chibi props, so "porting" them keeps exactly the look the owner rejected.
- The chapter flow (`main.gd`, 528 lines; `chapter2.gd`, 126 lines) is a phase machine that calls V2-only APIs in almost every step. Every call would have to be rewritten anyway.

What survives is about **230 lines of real content**: dialogue trees, echo data, the cast of eight, title cards and chapter summaries. Everything else is cheaper to rebuild on the world's systems than to adapt. Chapter 1 is a short, linear 10–15 minute sequence, so rebuilding its flow on the new stack is roughly 2–3 focused steps of work. Porting it line by line would take longer and leave V2 assumptions behind.

---

## 1. Component table

Effort: **S** < 1 session, **M** 1–2 sessions, **L** 3+ sessions.

| Component | V2 implementation | Open-world equivalent | Recommendation | Effort | Risk |
|---|---|---|---|---|---|
| Player controller | `player/player.gd` (627 lines): KayKit Rogue, 3-hit combo, dodge, Köz strike, Alov Dalğası, Kül Şahı offer, `lie_down` / `stand_up` / `wake` | `player_v3/ayxan.gd`: all of those plus stamina, weapons as data, lock-on, flasks, swim, fall damage, realistic model | **Replace** (hypothesis confirmed). Add the two cutscene hooks V2 has and V3 lacks (see §2) | S | Low. V3 already offers `wake()`; `lie_down` / `stand_up` map to the UAL `LayToIdle` clip |
| Camera | `camera/camera_rig.gd`: isometric follow, cinematic close-up, title orbit | `camera/third_person_camera.gd`: keeps the same `cinematic` / `release` / `orbit` / `add_trauma` API | **Replace** (confirmed). `talk_with()` in `chapter_base` already works with both | S | Low. Dialogue framing needs a visual check at over-the-shoulder distance |
| Enemies | `enemies/ash_shade.gd` (397): normal / fast / elite skeletons, telegraph ring, unstoppable windup, the elite's 360° "Kül Burulğanı" | `enemies/foe.gd` + `data/enemies/ash_shade.json`, `ash_runner.json` (utility AI, perception, unstoppable windups, spins), realistic charred humans | **Replace** (confirmed). The wave-3 boss **"Kül Şövalyesi" has no V3 data file**: add one JSON (heavy sword, spin attack, boss bar) | S | Low |
| Combat core | Inside `player.gd` / `ash_shade.gd`, tuned by `systems/balance.gd` | `combat/combatant.gd`, `hit.gd`, `melee.gd`, `projectile.gd`, `data/balance/combat.json` | **Replace** (confirmed) | — (comes free with player + enemies) | Low. Chapter 1 difficulty must be re-tuned: V3 Ayxan is stronger (flasks, stamina, lock-on) |
| Companion (Rüfət fights beside Ayxan) | `npc/companion.gd` (102): follows, talks, swings at shades; shades ignore him | **None.** The world has no ally combatant | **Rebuild** on `combatant` as an allied faction (enemies may target him), realistic Human | M | Medium. An ally that enemies attack needs death rules; with permanent NPC death he can die (see §6) |
| Level: Közkale courtyard | `world/kozqala.gd` (580): a courtyard built in code from KayKit dungeon props plus lava/soot/stone shaders (throne dais, crater, galleries, south-gate hearth, spawn points) | The world streams prefab POIs built from realistic kits. Közkale already appears **as a smoke column behind the western pass** | **Rebuild** (hypothesis *rejected*). Keep the *layout design* (dais, crater, three echo spots, south gate, hearth), rebuild it as a world region/POI with the Village MegaKit (brick and plaster walls, arches) and Poly Haven rocks | L | Medium–high. Largest art task. The world is 512 m and fully used, so the courtyard needs either a western extension of the terrain or a separate streamed area behind the pass |
| Level: Son Ocaq caravanserai | `world/son_ocaq.gd` (160): an arcaded yard in code (extends kozqala), one great fire, 8 stations, hide spots | Houses and props are built from the MegaKit (`tools/build_houses.gd`); villages are POIs with routines | **Rebuild** (*rejected*) as **the hub POI** in the valley: MegaKit arches, walls and doors (with the door metadata the hub needs) | L | Medium. This is the future hub; build it once, for the hub's needs, not as a copy of the V2 yard |
| Dialogue content | `story/rufet_dialogue.gd` (3 trees, ~40 nodes), inline dialogues in `main.gd` / `chapter2.gd`, survivor greetings in `story/survivors.gd` | `ui/dialogue_ui.gd` (shared), conditions via `WorldState.check` | **Port** (confirmed): move the trees to data files with translation keys, **minus the traitor-linked beats** (§5) | M | Low |
| Ember echoes (cutscene) | `world/echo_spot.gd` + `main.gd._play_echo`: a ghost of the king replays an animation, the world desaturates, his words are heard unless `father_voice` is burned | `world/interactable.gd` "echo" kind: text only | **Port INTO the world:** extend the echo interactable with an optional replay (ghost Human + clip + desaturation + memory-gated words). `echo_spot.gd` is then discarded | M | Low. It is a real V2 feature that the world lacks |
| Scripted waves | `main.gd._start_wave`: 3 waves from data, banners, horn, battle music, last-kill slow motion, boss bar | The world spawns fixed POI actors; there is no scripted encounter | **Rebuild** as a small reusable *Encounter* (data: waves of foe ids, spawn points, banner keys) that any story beat can trigger | M | Low. Useful later for hub raids (the V2 spec's hearth defence) |
| Chapter flow / phases | `main.gd` phase machine (MENU … CHAPTER_END, DEFEAT), checkpoints, restart | `world_mode.gd` + WorldState (`story` section) + SaveManager checkpoints | **Rebuild** as story beats driven by WorldState `story` progress and EventBus. Keep the checkpoint ids (`start`, `waves`, `echoes`, `return`, `chapter_end`, `c2_start`) so saves keep meaning | M | Medium. Death and restart rules differ: V2 reloads a checkpoint, the world respawns at the last hearth. Decide per chapter |
| Survivor AI | `npc/survivor.gd` (238): needs (warmth, company, duty), activity scoring, personality, hold for talk, flee and hide during attacks | `npc/villager.gd`: hourly schedules, work spots, greet, go home at night, flee | **Port INTO the unified NPC model:** needs become a layer on top of schedules. Neither AI survives alone | M | Medium. This is the hub NPC's core, so design it with the hub |
| Survivor cast | `story/survivors.gd`: 8 people (name, role, KayKit look, station, greeting) | `data/looks.json`, `data/world/villagers.json` | **Port** names, roles and greetings. **Rebuild** looks (§3). **Re-frame** the cast: it was designed as eight suspects (§5) | S (data) + M (looks) | Medium. Several roles need robes the current outfit set does not have |
| Hearth healing | `chapter_base._update_hearths`: passive warmth heal near braziers (weaker if `mother_name` is burned), tuned in `balance.gd` | Hearth rest (full heal, flask refill, enemies return, save) | **Discard** the passive heal (Souls rest replaces it). **Move the `mother_name` cost** to hearth rest (e.g. flasks refill one short). Do not lose the memory's consequence | S | Low |
| Title and chapter cards | `hud.title_card`, `hud.show_card` (defeat card, chapter summary) | Same HUD (shared) | **Keep and port** (text to keys) | S | Low |
| Memory wheel / Kül Şahı offer | `ui/radial_menu.gd`, `ui/ash_offer.gd` (shared by both players) | Same | **Keep for now**; the Xatirə redesign replaces them later (per AUDIT.md) | — | — |
| Tuning | `systems/balance.gd` (84 lines of V2 constants) | `data/balance/*.json` | **Discard** after the V2 player, enemy and hearth code go | S | Low |

## 2. V2 features the open world lacks (port INTO the new systems, do not discard)

1. **Echo replays.** A ghost re-enactment, desaturation and memory-gated words. Goes into `interactable.gd` as an echo "scene" option.
2. **Allied companion in combat.** Rüfət fights beside Ayxan. Needs an allied faction on `combatant` / `foe`.
3. **Scripted encounters.** Waves with banners, music, a boss bar and last-kill slow motion. Becomes a data-driven Encounter.
4. **Needs-based NPC life.** Warmth, company and duty, plus hiding places during attacks. Belongs in the unified NPC model.
5. **Cutscene body states.** `lie_down` / `stand_up` for the opening, via the UAL `LayToIdle` / `Death01` clips on `Human`.
6. **Chapter summary card.** Reads burned memories and echoes seen. Keep it as a story-beat UI.
7. **Memory consequences tied to V2 code paths.** `mother_name` weakens hearth healing, which V3 does not have; `father_voice` silences the echoes, which V3 echoes do not have. Each must be re-homed or it silently stops working.

## 3. Visual consistency

**V2 today**
- **Characters:** Ayxan (Rogue), Rüfət (Knight with helmet and shield), the eight survivors (Knight, Mage, Rogue, Barbarian with recolours), the king's ghost (Rogue) and the shades (KayKit Skeletons). All KayKit chibi.
- **Levels:** KayKit dungeon, halloween and castle props.

**Open world today**
- **Characters:** Quaternius Modular Outfits on the Universal Base Characters with the Universal Animation Library.
- **Environment:** generated photo-card trees, Poly Haven rocks and terrain, Medieval Village and Fantasy Props MegaKits.
- **Animals:** fur-shelled Quaternius animals.

**The single world should use the open-world (realistic) set.** It is what the owner asked for, and mixing the two in one world would look broken.

**Cost**

| Item | Work | Effort |
|---|---|---|
| Ayxan, shades, bandits | Already realistic | — |
| Rüfət, Şahbaz, Eşref, Elvin, Anar | Looks from existing outfits (Ranger / Peasant + recolours + beards), about one `looks.json` entry each | S |
| Sabir (vizier), İbrahim (alchemist), Ehliman (high priest) | **Robes the current outfit set does not have.** Need an extra CC0 outfit pack (e.g. another Quaternius outfit set) or a robe mesh on the existing skeleton | M, **asset gap** |
| The king's ghost | A Human with a crown prop and the ghost shader | S |
| Kül Şövalyesi | Charred Human with armour pieces (pauldron) and a larger sword | S |
| Közkale courtyard | Rebuild with the MegaKit and Poly Haven | L |
| Son Ocaq | Rebuild as the hub | L |

KayKit assets (`assets/characters/`) become unused once the V2 code is gone. That lets the ~32 MB of KayKit characters (`assets/characters/`) be archived.

## 4. Duplicated code that disappears

About 1,700 lines were identified as duplicated in `ARCHITECTURE_AUDIT.md` §4. Under this plan:

| File / part | Lines | Fate |
|---|---|---|
| `player/player.gd` | 627 | Gone (Ayxan V3) |
| `enemies/ash_shade.gd` | 397 | Gone (foe + JSON) |
| `npc/survivor.gd` | 238 | Gone (its needs logic moves into the unified NPC) |
| `camera/camera_rig.gd` | 108 | Gone (TPCamera) |
| `systems/balance.gd` | 84 | Gone (JSON) |
| `world/echo_spot.gd` | 77 | Gone (echo interactable) |
| `chapter_base` V2 defaults + hearth heal | ~40 | Gone |
| Wave logic in `main.gd` | ~60 | Replaced by the shared Encounter |
| **Total** | **~1,630 of ~1,700** | |

The rest (~70) is duplicated spawning in `world_mode.gd`, which the Encounter can absorb later.

Also gone: the phase-machine code of `main.gd` / `chapter2.gd` (~450 lines, not counted as duplication) and `kozqala.gd` / `son_ocaq.gd` (740 lines of level-in-code) once their replacements exist.

## 5. Traitor/detective-linked beats — **DO NOT MIGRATE AS-IS**

The mechanics (random traitor, clues, interrogation, trust, accusation, the "Külün Xaini" boss, exile, the letter clue) were already deleted in V2 (`docs/SPEC_V2.md`, line 24). No code for them remains. **These story beats still carry that concept:**

| # | Where | What | Why it belongs to the old concept |
|---|---|---|---|
| T1 | `story/rufet_dialogue.gd`, nodes `where`, `why`, `believe` | Choice "Yangın gecesi sen neredeydin, Rüfet?"; his alibi; flags `king_sent_guards_away`, `rufet_believed` | An alibi interrogation of a suspect; "I believe you" was a trust mechanic |
| T2 | `story/rufet_dialogue.gd`, node `status2` | "Elvin kendini çoktan tahtın varisi ilan etti… Eşref Bey susuyor. İbrahim ise yangından beri ortada yok." | Introduces the cast as suspects, each with a motive or a missing alibi |
| T3 | `story/survivors.gd` (whole cast) and `chapter2.gd` | The eight survivors | GDD M4/M5: they were designed as **the eight suspects** (3 clues each). Their roles (illegitimate heir, blood-feud lord, vanished alchemist, cult priest) still read as motives |
| T4 | `story/king_echoes.gd`, echo 2 | "Kral bir mektup yazıyor…" / "Oğluma… oğluma de ki…" | The unfinished letter is the remnant of the **letter clue** that SPEC_V2 says was removed |
| T5 | `docs/GDD.md` §4 and §7 (M4, M5), line 154 | Clue sets, `interrogation.gd`, flags `clue_letter`, `rufet_hesitated` | Documentation of the replaced concept. Already marked superseded; do not implement |

**Recommendation**
- Drop T1 (keep "where is the king" and "the ember" branches).
- Rewrite T2 as plain news of the realm.
- Keep the characters of T3 but re-frame them as hub residents.
- Decide whether T4 stays as pure lore (a father's last words, no clue) or is cut.

## 6. Connection to the future persistent hub

These story moments should write WorldState now, even with no hub yet. Everything below respects one fact, one owner.

| Moment | Write | Section |
|---|---|---|
| Ayxan wakes in Közkale | `story.checkpoint = "start"` (exists) | story |
| Meets Rüfət | `npcs.rufet = {met: true, alive: true, location: "kozkale"}` | npcs |
| Rüfət dialogue lore choices | keep `lore_forgetting_king`, `king_chose_fire` | flags |
| Rüfət not recognised | **Do not write `rufet_forgotten`.** It is derivable from `burned_memories` containing `rufet_face` | — |
| Each echo seen | `story.echoes_seen` (exists) | story |
| Kül Şövalyesi defeated | `story.checkpoint = "echoes"` (exists); if he is a named former guard, `npcs.kul_sovalyesi = {alive: false, cause: "slain"}`. With the redemption mechanic he could instead be **redeemed**, and this is the natural first candidate | story / npcs |
| Rüfət survives or dies in the waves | `npcs.rufet.alive`, `death_cause`; permanent | npcs |
| Chapter 1 ends / arrival at Son Ocaq | `story.chapter = 2`, `npcs.rufet.location = "son_ocaq"` | story / npcs |
| Each survivor met | `npcs.<id> = {met: true, alive: true, location: "son_ocaq", relationship: 0}` | npcs |
| Later: rescues | `npcs.<id>.rescued_from`, `location = "son_ocaq"`, `world.hub_stage` += | npcs / world |

## 7. Hardcoded player-facing text

| Area | Strings | Words |
|---|---|---|
| V2 story content (dialogues, echoes, survivors) | 92 | ~544 |
| V2 chapter flow (objectives, banners, cards) | 40 | ~214 |
| V2 systems | 6 | ~20 |
| Shared UI and systems (HUD, journal, wheel, offer, pause, settings, whispers) | 35 | ~137 |
| Open world code | 51 | ~250 |
| JSON content (names, voice lines, prefab texts) | ~196 | — |

**Recommendation:** move the V2 texts to translation keys **as part of the migration of each beat, not before**:
- About 40% of V2 story text changes anyway (§5 rewrites and re-framing).
- Rewritten lines go straight into `strings.csv`, so nothing is translated twice.
- Shared UI (35) and open-world (51) strings are a separate, mechanical task.

Also noted: `settings_panel.gd` shows "Qrafika", an Azerbaijani word in the Turkish UI.

## 8. Migration order (each step leaves the game playable)

1. **Encounter system in the world.**
   - Data-driven waves with banners, boss bar and slow motion, plus the Kül Şövalyesi JSON.
   - Test with a debug trigger in Kür Vadisi.
   - *Chapters untouched.*
2. **Echo replays in the world.**
   - Extend the echo interactable (ghost Human, clip, desaturation, `father_voice` gating).
   - One valley echo uses it. *Chapters untouched.*
3. **Allied combatant.**
   - Rüfət as a realistic Human ally on `combatant`, with his `npcs` record.
   - Test him in the valley. *Chapters untouched.*
4. **Közkale region.**
   - Rebuild the courtyard layout as a POI or area behind the western pass (realistic kits).
   - Reachable in the world, still empty of story.
5. **Chapter 1 as world story beats.**
   - Wake → Rüfət (dialogue in data + keys, T1/T2 removed) → encounter → echoes → return.
   - Uses steps 1–4 and writes §6's WorldState.
   - The menu's New Game switches from `main.tscn` Chapter 1 to the world beat.
   - **The old chapter stays in the repo but unreachable** until the new one is verified.
6. **Delete the V2 Chapter 1 stack:** `main.gd` flow, `player.gd`, `ash_shade.gd`, `camera_rig.gd`, `companion.gd`, `echo_spot.gd`, `balance.gd`, KayKit characters. The title screen moves to a light scene of its own.
7. **Son Ocaq as the hub POI.**
   - Built with doors (door metadata).
   - The unified NPC model (villager + survivor needs).
   - The eight residents with realistic looks. Robe outfits need the asset step first.
8. **Chapter 2 as the arrival beat into the hub.** Then delete `chapter2.gd`, `son_ocaq.gd`, `survivor.gd`, `survivors.gd`.
9. **Tests.** A combat and AI test scene in the world, replacing the 60 checks lost with the arena. **It should be done early**, ideally together with step 1: the migration changes combat balance.

## 9. Port or rebuild? Honest estimate

**Rebuild.** Porting means making V2 code work on V3 systems.
- `main.gd`'s flow calls V2-only APIs in almost every function: `lie_down`, `rufet.in_combat`, `AshShade.configure`, `level.spawn_points`, `level.rufet_spot`, passive hearths, `restart_mode` reloads.
- The two levels are code-built KayKit geometry that the realism direction rejects.
- A port would therefore touch nearly every line and still leave chibi art and V2 assumptions.
- Rebuilding reuses the world's streaming, saves, NPCs and combat. It moves the ~230 lines of genuine content into data with translation keys, and it produces three reusable systems the hub needs anyway: Encounter, echo replays, allied combatant.

**Rough cost:**

| Part | Estimate |
|---|---|
| Systems (steps 1–3) | M + M + M |
| Közkale region | L |
| Chapter 1 beats | M |
| Hub and Chapter 2 | L + M (shared with the hub work that must happen regardless) |

**The only large cost unique to the migration is the Közkale courtyard art.** If the owner wants to save it, a cheaper option is to open the story in the valley itself (at the Geçit Ocağı hearth with Közkale burning in the distance). The courtyard could then be built later as a destination.
