# STORY_BIBLE.md — Ashes of the Crown

> Canonical story reference. Every system, dialogue, quest, and scene must stay
> consistent with this document. **SPOILERS: the entire story is here.**

## 0. How to use this document (rules for Claude Code)

- This file is **canon**. If code, data, or a request conflicts with it, stop and ask.
- **Never invent story content** (new characters, lines, reveals, bosses, quests).
  Build systems and placeholders; story content comes from the owner.
- Anything marked **[TBD]** is undecided. Use a placeholder and flag it in the report.
- Player-facing text is **Turkish**, always via translation keys in `strings.csv`.
  Example lines in this document show *meaning*, not final wording.
- Character names and epithets are always shown via keys (`NPC_<ID>_NAME`,
  `NPC_<ID>_EPITHET`) and the name-resolution function (burned-name rules apply).
- When this document changes, update the related data and report what changed.

---

## 1. Core

**Logline:** A nameless ember-keeper wakes in a frozen, ash-covered valley, below a
castle that has been burning for months. To survive he must burn his own memories
for power — and the memories he is burning are the story of what he did.

**Theme: grief.** One question drives everything: *what do we do with the people we
lose — forget them, or refuse to let them go?* Every major character embodies one
answer. The true answer the game arrives at: **grief is not forgetting and not
holding alone — it is carried together.**

**Tone:** dark, quiet, cold, intimate. Horror comes from loss, not gore.
Hope exists, but it is earned and small (a light in a window, a newborn's name).

**Pillars**
1. **The mechanic is the story.** Burning memories is the player's own tragedy,
   not a stat upgrade.
2. **Every choice costs.** Keeping and burning both have real value and real loss.
3. **The world remembers for the player.** Aras forgets; the game never lets the
   player get lost (see §9).
4. **Two layers.** The surface story is clear to everyone. The deep layer
   (item texts, Domrul's riddles, environment) rewards fans.
5. **Rooted, not generic.** Caucasus / Silk Road culture: the hearth (ocak),
   laments (ağıt), aşık songs, Dede Korkut, Novruz fire.

---

## 2. World rules

**The hearth custom.** In this land the dead are not buried — they are *given to the
hearth*. The family burns one memory of the dead person; the memory becomes warmth,
and the dead keep warming the living. The blessing "Ocağın sönməsin"
(may your hearth never go out) comes from this. Letting go = warmth.

**Ulu Ocaq (the Great Hearth)** burns in Közkale and anchors every hearth in the land.

**Közçü (Ember-keeper).** The keeper of Ulu Ocaq. A Közçü can burn memories directly
into fire power. Aras was the King's Közçü.

**The reversal.** The King turned Ulu Ocaq backwards: instead of consuming memories,
it *preserves* them. Consequences:
- The dead did not leave. They returned as **Küllüler (the Ash-born)**: shades wearing
  the faces and voices of the people who loved them. They are empty inside.
- Hearths stopped giving warmth. The land froze. **Ash falls like snow, constantly.**
- Visual rule: the world is grey and cold. **The only real colour is fire.**

**Küllüler at night.** After dark they enter villages and knock on doors, speaking
with the voices of lost loved ones. Nobody opens a door at night. People talk through
doors. Opening the door to a shade kills the one who opens it.

**Echoes.** When Aras burned his memories on the fire night, the reversed hearth
could not consume them fully. Fragments scattered across the land as glowing
**embers**. Touching one = playing that memory as an echo.
- **KEEP:** Aras remembers it again. No power.
- **BURN:** Aras burns it for good. He gains power — but because Ulu Ocaq is still
  reversed, what he burns goes to the King. (This feeds the final boss, §5.)

**Ash.** Every burned memory leaves ash. İbrahim can turn ash into **permanent** fire
abilities (solves the MUST-FIX in BACKLOG.md).

**The Cold Sickness.** The plague that started everything. It killed the King's son
and Narin.

---

## 3. Timeline before the game

1. The hearth custom works. Ulu Ocaq burns in Közkale. Aras is Közçü, married to
   Sona, father of Narin. Rüfət is his blood brother and captain of the guard.
2. **The Cold Sickness** spreads. The King's son dies. **Narin dies.**
3. The King cannot give his son to the fire. He orders **İbrahim** to design a way to
   reverse Ulu Ocaq. **Aras helps** — because he wants Narin back.
   **Ehliman** (high priest) opposes it. Nobody listens.
4. The reversal works. The dead return as shades. **Narin's shade comes home.**
   Sona wants to open the door. Aras looks into the shade's eyes and sees emptiness.
   He understands what they have done.
5. **Tural** (Şahbaz's lieutenant) sides with the King, who promised to return his
   fallen comrades. Şahbaz does not.
6. **Domrul**'s wife's shade comes to his door. He never opens it, but talks to her
   every night for a year. The dead know what happened in Közkale. It breaks his mind.
7. **The fire night.** Aras burns *all* his memories at once — Narin included — to
   force Ulu Ocaq back to its true direction. **Közkale bursts into flame.**
   The plan half-works: the King's power is sealed inside Közkale, the shades weaken,
   but the cold remains and Ulu Ocaq stays reversed.
8. Before the fire, Aras writes a **letter to himself** and makes Rüfət promise:
   *"Never tell me."* Rüfət carries Aras out and leaves him in the valley.
9. Survivors of the court flee to the last village with a burning hearth:
   **Son Ocaq**. Everyone believes **the King** caused the fire. Only Rüfət knows the
   truth. Közkale is still burning on the horizon — **that fire is Aras's past.**

---

## 4. The game: three acts

### Cold open — the fire night (playable)
No context. The player controls a man running through burning Közkale, carrying
something in his arms. White-out. **The same scene returns at the very end with full
context**, and the player finally understands what he was carrying [TBD: exact object
— Narin's shade? her memory ember? decide with the final echo].

### Act I — "Kül" (Ash)
- Aras wakes alone in the valley near **Geçit Ocağı**, nameless. Közkale burns in the
  distance.
- First fight. **Rüfət finds him** and joins (flag `rufet_joined`).
  *"You don't know me? ...Good. Better this way."*
- Reach **Son Ocaq**. Meet the residents. Learn the night/door rule.
- First echoes: happy memories. Burning looks easy.
- First meeting with **Yadigar** (still sharp, gives advice).
- **Domrul** speaks nonsense that is secretly true.
- Goal of the act: keep Son Ocaq alive, bring survivors in.
- **Act end:** an echo shows a little girl. Through a door, Sona asks:
  *"Do you remember Narin?"*

### Act II — "Köz" (Ember)
- The world opens. Residents' grief quests; rescues; each quest unlocks a
  fire-night echo fragment held by that witness.
- **Tural** boss (Kül Şövalyesi) — climax of Şahbaz's line.
- Rüfət gives Aras **his own letter**: *"If you are reading this, you have forgotten me."*
  The `own_name` echo becomes available.
- **MIDPOINT REVEAL:** an echo shows **Aras helping the King** reverse the hearth.
  Şahbaz learns that **Aras lit the fire** that killed his soldiers → his door closes.
  Rüfət confesses he knew all along.
- Yadigar no longer remembers his own name.
- Domrul's riddles start to make sense (flashback montage, §9).
- **Act end:** the small shade that knocks on Aras's door every night **is Narin**.

### Act III — "Alov" (Flame)
- Return to **Közkale** — walking into his own burning past. The final echoes,
  including the full fire night.
- Elvin meets his father. **The King does not recognise him.**
- Ehliman pushes Aras to burn Narin for good ("Adsız" path).
- **Sona's night:** Sona learns Aras burned Narin. If Aras has not earned her trust
  (told her the truth himself, see §6), she opens the door to Narin's shade → she dies.
- A child is born in Son Ocaq; the parents ask Aras to name it (see §7, Kamal & Gülçin).
- **Domrul's last night:** he wants to open the door and go with his wife. Aras
  chooses: stop him or let him go.
- **Final boss: Kül Aras** (§5). Then the last conversation with the King at Ulu Ocaq.
  *"You forgot. I did not."*
- The cold open replays with full context. Ending (§5).

---

## 5. Final boss and endings

**Kül Aras (Ash Aras).** The King kept everything Aras burned. The final boss is a
shade built from Aras's burned memories. It uses the abilities Aras gave up, and its
strength **scales with how much he burned** (count + weight of BURNED memories,
both echo and combat). This is the counterweight to "burn everything".

**Endings**

| Ending | Condition | Result |
|---|---|---|
| **Adsız (Nameless)** | Aras burns Narin's memory at the final choice | Ulu Ocaq relit, land warms, residents live. Last scene: someone opens a door and calls Aras by his name. He does not know it. |
| **Kül Şahı (Ash King)** | Aras refuses to burn and takes the King's place | He stays with Narin's shade. The land stays frozen. Son Ocaq slowly goes out. |
| **Ocağın Sönməsin (true)** | Narin's memory KEPT **and** Sona alive and told the truth **and** at least [TBD: 5] of 8 core residents alive with their grief resolved | Narin's memory is **shared**: each resident takes a piece of it to their own hearth. Novruz-like fire, people jumping over flames. Bittersweet, not alone. |

The true-ending option is **visible but locked** at the final choice if conditions are
not met, so the player understands something was possible.

---

## 6. Mechanics ↔ story mapping

| System | Story meaning | Rules |
|---|---|---|
| Memory states UNKNOWN / KEPT / BURNED | Remembering vs forgetting | BURN is final. KEEP is not safe forever. |
| Echo choice (hold-to-confirm BURN) | Deciding right after living the memory | Autosave on choice. No save inside echoes. |
| Combat wheel can burn KEPT memories | Temptation in every hard fight | Hold-to-confirm, slowed time. `combat_burnable=false` protects story-critical memories (own_name, Narin, [TBD others]). |
| `burn_context` echo / combat | "You burned her out of fear" | Story may react differently later. |
| Ash → İbrahim → permanent abilities | Power built from loss | Resolves BACKLOG MUST-FIX. |
| Kül Aras scaling | What you burn comes back | Final boss strength from BURNED set. |
| Name blanking | Aras cannot "hold" names he burned | Voice still says the name; all text shows `———`. Exception: `ignores_burned_names` (Kül Şahı only). |
| Night doors | Fear, grief, trust | Nobody opens at night. Opening to a shade = death. |
| Permanent NPC death | Loss is real | Dead NPCs never respawn. |
| Hub growth | Collective grief | Each resolved grief quest: that house's snow melts, a window lights up, the hearth grows. |
| Telling Sona the truth | Trust | Required for Sona's survival and the true ending. Aras must tell her himself before Act III [TBD: exact trigger]. |

---

## 7. Characters

Format: **id** — Name, *epithet* — role. Stance on grief. Secret. Hub function.
Permanent death risk.

### Protagonist
- **protagonist** — **Aras**, *Közçü* — former King's Ember-keeper. Complicit, not a
  villain: he helped reverse the hearth for Narin, then burned everything to undo it.
  Wakes nameless. Name shown via `PROTAGONIST_NAME`, linked to `own_name`.
  Marketing title: **Közçü** (EN: *The Emberbearer*).

### Core cast
- **rufet** — **Rüfət**, *qan qardaşı* — companion. **Silent love:** knows everything,
  lies to protect Aras from his own guilt. Carries Aras's letter. Name memory:
  `rufet_face`. Downed, never killed in normal combat; fate decided by story [TBD].
- **sona** — **Sona**, *[TBD epithet]* — Aras's wife, Narin's mother. **Remembers what
  Aras burned.** Asks through the door: *"Do you remember Narin?"* Does not know Aras
  burned her. Death risk: **Act III, Sona's night.** (New model needed.)
- **narin** — **Narin** — Aras's daughter. `npc_kind: shade`. Appears only in echoes
  and at Aras's door at night. Her lullaby is the game's main motif (§8).
  Her memory is `combat_burnable=false`.
- **elvin** — **Elvin**, *şahın oğlu* — the King's illegitimate son. **The forgotten
  living:** the King kept his dead son and forgot his living one. Wants to be seen.
  Hub **aşık**: sings Aras's story, including what Aras burned (§9). Meets his father
  in Act III; the King does not recognise him.
- **ehliman** — **Ehliman**, *Köz Ordeninin kahini* — **forget everything:** burned all
  memories of his own family out of piety; calls everyone "evlat" because he no longer
  remembers his children. Opposed the reversal. Keeps Son Ocaq's hearth. Late-game
  ideological antagonist, voice of the "Adsız" ending.
- **ibrahim** — **İbrahim**, *saray alimi* — **guilt:** built the reversal mechanism out
  of curiosity. Lost his assistant through neglect. Only one who understands Ulu Ocaq
  technically. Hub: turns **ash into permanent abilities**. Death risk [TBD].
- **sabir** — **Sabir**, *qoca müəllim* — Aras's teacher since childhood.
  **Unchosen forgetting:** losing memory to old age and fighting it — the mirror of
  Aras, who forgets by choice. Quest: help him remember his students' names.
  Hub: keeper of **kept memories** — re-watch KEPT echoes at the hearth.
  Handle with respect. No death risk.
- **sahbaz** — **Şahbaz**, *sərkərdə* — **anger:** his soldiers died in the fire. At
  first blames the King; at the midpoint learns Aras lit it → door closes. Quest:
  release his soldiers' ash legion; confront **Tural**. Hub: combat training.
  Death risk: yes (ash legion / Tural line).
- **esref** — **Eşref**, *Qartal Dağlarının bəyi* — **loyal memory:** swore to his dead
  wife he would never forget her. Honour makes him a small mirror of the King.
  **Highest death risk:** if his quest fails, one night he opens the door to her shade.
- **nermin** — **Nərmin**, *karvan xanımı* — replaces V2 **Anar** (same hooded model,
  adapted; migrate id `anar` → `nermin`). **Denial:** counts the dead in her ledger so
  she never has to feel them. One name is missing: her brother **Samir**.
  Dry humour. Hub: merchant, and **buys KEPT memories** for rare items
  ("everything has a price"). Selling = another way to lose a memory [TBD: does a sold
  memory count as BURNED for Kül Aras?].
- **kul_sahi** — **Kül Şahı** — `npc_kind: voice_only`, no body. **Never let go.**
  Kept every memory anyone burned, including Aras's. Has a real argument:
  *"You forgot. I did not."* `ignores_burned_names = true`.

### Supporting cast
- **domrul** — **Dəli Domrul**, *şəhərin dəlisi* — (Dede Korkut). Talked to his dead
  wife's shade through the door every night for a year; learned the truth; lost his
  mind. **Everything he says is literally true** — riddles, rhymes, mis-sung lullaby.
  Example meaning: *"The Ember-keeper kissed his daughter, then gave her to the fire."*
  Arc end: on his last night he wants to open the door and go with her; Aras stops or
  releases him. Replaces Bəhlul (dropped).
- **yadigar** — **Yadigar**, *başqa bir Közçü* (world) — a Közçü further down the same
  road. Each meeting he is emptier: advice → forgets why he hunts → forgets his name
  → attacks Aras or is found dead [TBD]. "Yadigar" = keepsake: the man who kept
  nothing. The in-story warning against burning everything. Model: Közçü variant.
- **ayna** — **Ayna**, *özünü bilən kölgə* (world) — a shade who knows she is a shade and
  begs Aras to burn her memory and free her. Makes the player see shades as people.
  Model: shade variant.
- **tural** — **Tural**, *Kül Şövalyesi* (world, boss) — Şahbaz's former lieutenant;
  chose the King for the promise of his dead comrades. Save or kill [TBD outcomes].
  Model: enemy knight variant.
- **peri_nene** — **Pəri Nənə**, *ağıtçı* (hub) — blind lament singer. Cannot see the
  shades' borrowed faces, recognises them by voice — **the only one who can safely
  open a door at night**; Aras's go-between. Her laments shape the soundtrack.
  (New model needed.)
- **kamal / gulcin** — **Kamal** and **Gülçin** (hub) — young couple expecting a child.
  Everyday life: arguing, laughing, preparing. **Naming scene (Act III):** they ask
  Aras to name the baby. If Narin is KEPT, "Narin" appears as an option; if not, the
  option simply does not exist.
- **samir** — **Samir** (world, hidden) — Nərmin's brother. Alive: survived the cold by
  burning all his memories. Found and brought home, he does not know her.

### Background
Generic villagers with barks only. Unlimited. Never carry story facts alone.

### Death risk summary
Can die permanently: Sona, Eşref, Şahbaz, Domrul (by choice), İbrahim [TBD],
Yadigar [TBD], Tural (boss). Never: Sabir, Kamal, Gülçin, the newborn.
Rüfət: story-only [TBD].

---

## 8. Motifs

- **Narin's lullaby.** Sona hums it. Domrul sings it with wrong words. Elvin plays it
  without knowing where he learned it. It plays in the memory menu. **Heard complete
  only once — in the final scene.**
- **Doors.** Closed = fear and grief. Opened = trust or death.
- **Ash snow.** Constant. Melts only near living fire and resolved grief.
- **Fire is the only colour.** Közkale's flame on the horizon is always visible.
- **Names.** Who remembers whose name is the emotional map of the game.

---

## 9. Narrative delivery — the player never has to memorise

**Principle: Aras forgets; the world remembers for him.**

1. **Elvin's recap songs.** Returning to the hub: a 30–60 s skippable song about recent
   events. Loading a save: a three-sentence voiced "previously" recap by Elvin.
2. **Burned memories become legend, not blanks.** When a memory is burned, its
   first-person journal entry is replaced by a verse from Elvin's song ("They say the
   Ember-keeper had a daughter..."). The player keeps the information; Aras loses it.
3. **Közçü's journal** (auto-filled):
   - *People:* portrait, epithet, one-line relationship, last thing they said.
     Burned name → portrait stays, name shows `———`.
   - *Threads:* always exactly one current goal line.
   - *Places:* discovered places and what is left there.
4. **Epithet rule.** Every character is always introduced with the same epithet
   ("Sabir, the old teacher"), so the epithet identifies them even if the name slips.
5. **Rule of three.** Every key fact is delivered at least three ways: dialogue,
   environment, echo.
6. **Flashback montage on reveals.** At big reveals, earlier clues flash for 3–4 s.
   The player gets the "aha" without having to remember.
7. **Pacing of introductions.** At most 1–2 new important characters per session.
8. **Two layers.** The surface story must be understandable with zero lore reading.
   Deep lore lives in item texts, Domrul, and the environment.

---

## 10. Reveal schedule (what the player knows, when)

| Fact | First hint | Confirmed |
|---|---|---|
| Aras is the Közçü | Act I, Rüfət / residents | Act I |
| Közkale's fire was not the King's | Act I, Domrul | Act II midpoint |
| Aras had a daughter | Act I, Domrul / lullaby | Act I end (echo + Sona) |
| Aras helped reverse the hearth | Act II, İbrahim's quest | Act II midpoint (echo) |
| Aras lit the fire | Act I, Domrul | Act II midpoint (Şahbaz, Rüfət) |
| The knocking shade is Narin | Act I, small shade at Aras's door | Act II end |
| The King kept what Aras burned | Act II, Ayna / Yadigar | Act III, Kül Aras |
| What Aras carried in the cold open | Cold open | Act III, final replay |

---

## 11. Language and naming

- Player-facing text: **Turkish**, via keys only. Code, comments, docs: English.
- Protagonist: **Aras** (`PROTAGONIST_NAME`). Title: **Közçü**.
- Place names used in-game follow the existing Turkish forms (Közkale, Geçit Ocağı,
  Kürköy). Son Ocaq's Turkish in-game form: [TBD: "Son Ocak"].
- Each NPC: `NPC_<ID>_NAME` and `NPC_<ID>_EPITHET`.

---

## 12. Vertical slice scope (prove the story works before building chapters)

- Cold open (short).
- Valley wake-up near Geçit Ocağı, first fight, Rüfət joins.
- Son Ocaq with **Sona** and **one** core resident [TBD: Eşref or Sabir], plus
  **Pəri Nənə** (night go-between).
- Night door mechanic, including one knock by the small shade.
- **Two echoes** (one easy to burn, one hard), permanent-power burning via İbrahim
  [TBD: include İbrahim or stub the ash upgrade].
- **Yadigar** first meeting.
- **Domrul**: three lines that pay off within the slice.
- Act I ending beat: *"Do you remember Narin?"*

---

## 13. Open questions [TBD]

1. Cold open: what exactly is Aras carrying?
2. Final true-ending threshold (how many residents).
3. Rüfət's fate in each ending.
4. Does selling a memory to Nərmin count toward Kül Aras?
5. Tural: consequences of saving vs killing.
6. Yadigar's end: fight or found dead.
7. İbrahim's death risk.
8. Exact trigger for telling Sona the truth.
9. Sona's epithet; King's dead son's name (if ever needed).
10. Which memories besides own_name and Narin are `combat_burnable=false`.
