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

**Közcü (Ember-keeper).** The keeper of Ulu Ocaq. A Közcü can burn memories directly
into fire power. **By Ateşan tradition, the crown heir serves as Közcü of Ulu Ocaq until
he takes the crown.** Aras is the crown prince **and** the King's Közcü.

**The reversal.** The King turned Ulu Ocaq backwards: instead of consuming memories,
it *preserves* them. **On the fire night the King gave his own body to the reversed
hearth; people now call him Kül Şahı (the Ash King).** Kül Şahı and the King are one and
the same — Aras's father, and the game's only antagonist (§3.7). Consequences:
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
Kür and Narin.

**Kür Vadisi.** Aras and Kür — the two great rivers that merge. After Kür died, the King
renamed the valley below Közkale **Kür Vadisi** after his younger son. (The valley in the
game keeps this name; this is where it comes from.)

**The lullaby.** One family lullaby, passed down the generations: Queen Humay sang it to
Aras; Aras and Sona sang it to Narin; the King knows it as his wife's song (§8).

---

## 3. Timeline before the game

1. The hearth custom works. Ulu Ocaq burns in Közkale. Aras — the King's son and crown
   prince — is Közcü, married to Sona, father of Narin (the King's granddaughter).
   Kür is Aras's younger brother. Elvin, the King's illegitimate son, is Aras's
   half-brother. Rüfət is Aras's blood brother and captain of the guard.
   - Years before the Cold Sickness, **Queen Humay**, Aras's mother, dies. As custom
     demands, the King gives her memory to the hearth — and can never recall her face
     again. That emptiness stays with him.
2. **The Cold Sickness** spreads. The King's younger son **Kür** dies; the King renames
   the valley Kür Vadisi after him. **Narin dies.**
3. Remembering Humay's lost face, the King swears *"never again"*: he cannot give his son
   to the fire. This is the root of the reversal. He orders **İbrahim** to design a way to
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
   When Aras's fire hits Ulu Ocaq, **the King throws himself into the hearth** to keep
   holding the dead. **Aras's fire created Kül Şahı.**
   The plan half-works: the King's power is sealed inside Közkale, the shades weaken,
   but the cold remains and Ulu Ocaq stays reversed.
8. Before the fire, Aras writes a **letter to himself** and makes Rüfət promise:
   *"Never tell me."* Rüfət carries Aras out and leaves him in the valley.
9. Survivors of the court flee to the last village with a burning hearth:
   **Son Ocaq** — a village grown around an old caravanserai; the last hearth burns in
   its courtyard. Everyone believes **the King** caused the fire. Only Rüfət knows the
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
- First fight. **Rüfət finds him** and joins (condition `joined:rufet`, derived from his
  WorldState location `party` — one fact, one owner; there is no separate flag).
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
- A child is born in Son Ocaq; the parents ask Aras to name it (see §7, Kemal & Gülçin).
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
| **Kül Şahı (Ash King)** | Aras refuses to burn and takes his father's crown of ash | He becomes the new Kül Şahı and stays with Narin's shade. The land stays frozen. Son Ocaq slowly goes out. |
| **Ocağın Sönməsin (true)** | Narin's memory KEPT **and** Sona alive and told the truth **and** at least [TBD: 5] of 8 core residents alive with their grief resolved | Narin's memory is **shared**: each resident takes a piece of it to their own hearth. Novruz-like fire, people jumping over flames. Bittersweet, not alone. |

The true-ending option is **visible but locked** at the final choice if conditions are
not met, so the player understands something was possible.

---

## 6. Mechanics ↔ story mapping

| System | Story meaning | Rules |
|---|---|---|
| Memory states UNKNOWN / KEPT / BURNED | Remembering vs forgetting | BURN is final. KEEP is not safe forever. |
| Echo choice (hold-to-confirm BURN) | Deciding right after living the memory | Autosave on choice. No save inside echoes. |
| Combat wheel can burn KEPT memories | Temptation in every hard fight | Hold-to-confirm, slowed time. `combat_burnable=false` protects story-critical memories (`own_name`, `narin`, [TBD others]). |
| `burn_context` echo / combat | "You burned her out of fear" | Story may react differently later. |
| Ash → İbrahim → permanent abilities | Power built from loss | Resolves BACKLOG MUST-FIX. |
| Kül Aras scaling | What you burn comes back | Final boss strength from BURNED set. |
| KEEP value of memories | Remembering pays off later | See the table below. |
| Name blanking | Aras cannot "hold" names he burned | Voice still says the name; all text shows `———`. Exception: `ignores_burned_names` (Kül Şahı only). |
| Night doors | Fear, grief, trust | Nobody opens at night. Opening to a shade = death. |
| Permanent NPC death | Loss is real | Dead NPCs never respawn. |
| Hub growth | Collective grief | Each resolved grief quest: that house's snow melts, a window lights up, the hearth grows. |
| Telling Sona the truth | Trust | Required for Sona's survival and the true ending. Aras must tell her himself before Act III [TBD: exact trigger]. |

---

### KEEP value of the six memories

What keeping each memory gives later (burning it gives fire power now; §2).

| Memory | KEEP value |
|---|---|
| `rufet_face` — Rüfet'in yüzü | Full recognition in Rüfət's confession scene. |
| `mother_name` — Annemin adı | Recognise the lullaby (its *ninni* is the family lullaby, §8); in the finale, reach the King through Humay's name. |
| `sabir_lesson` — Sabir'in ilk dersi | In Sabir's quest, remind him of his own lesson. |
| `kozqala_streets` — Közkale'nin sokakları | **Gameplay:** know shortcuts and hidden paths in burning Közkale (Act III). |
| `father_voice` — Babamın sesi | In the finale, address the King as a father. [TBD: if BURNED, Aras does not recognise his father's voice.] |
| `first_sword` — İlk kılıcım | After the midpoint, opens a path to reconcile with Şahbaz. |

---

## 7. Characters

Format: **id** — Name, *epithet* — role. Stance on grief. Secret. Hub function.
Permanent death risk. Epithets are given in their in-game Turkish form
(`NPC_<ID>_EPITHET`); names in Azerbaijani spelling note the in-game Turkish form.

### Protagonist
- **protagonist** — **Aras**, *Közcü* — the King's son, crown prince and Közcü of Ulu
  Ocaq (by Ateşan tradition the heir keeps the hearth until he is crowned). Complicit,
  not a villain: he helped reverse the hearth for Narin, then burned everything to undo it.
  Wakes nameless. Name shown via `PROTAGONIST_NAME`, linked to `own_name`.
  Marketing title: **Közcü** (EN: *The Emberbearer*).

### Core cast
- **rufet** — **Rüfət** (TR: Rüfet), *kan kardeşi* — companion. **Silent love:** knows everything,
  lies to protect Aras from his own guilt. Carries Aras's letter. Name memory:
  `rufet_face`. Downed, never killed in normal combat; fate decided by story [TBD].
- **sona** — **Sona**, *dokumacı* — Aras's wife, Narin's mother. **Remembers what
  Aras burned.** Asks through the door: *"Do you remember Narin?"* Does not know Aras
  burned her. Death risk: **Act III, Sona's night.** (New model needed.)
- **narin** — **Narin**, *kapıdaki gölge* → *Közcü'nün kızı* — Aras's daughter, the King's
  granddaughter. Her epithet follows the story: *kapıdaki gölge* ("the shade at the door")
  until the reveal, *Közcü'nün kızı* ("the Közcü's daughter") after it (flag
  `narin_revealed`).
  `npc_kind: shade`. Appears only in echoes and at Aras's door at night. Her lullaby is
  the game's main motif (§8). Her memory is `narin`, `combat_burnable=false`.
- **elvin** — **Elvin**, *şahın gölgedeki oğlu* — the King's illegitimate son, Aras's
  half-brother. **The forgotten
  living:** the King kept his dead son and forgot his living one. Wants to be seen.
  Hub **aşık**: sings Aras's story, including what Aras burned (§9). Meets his father
  in Act III; the King does not recognise him. **Lost one:** his mother, a singer the
  King never acknowledged [TBD: name].
- **ehliman** — **Ehliman**, *Köz Nizamı'nın kâhini* — **forget everything:** burned all
  memories of his own family out of piety; calls everyone "evlat" because he no longer
  remembers his children. Opposed the reversal. Keeps Son Ocaq's hearth. Late-game
  ideological antagonist, voice of the "Adsız" ending.
- **ibrahim** — **İbrahim**, *saray âlimi* — **guilt:** built the reversal mechanism out
  of curiosity. Lost his assistant through neglect. Only one who understands Ulu Ocaq
  technically. Hub: turns **ash into permanent abilities**. Death risk [TBD].
- **sabir** — **Sabir**, *yaşlı öğretmen* — Aras's teacher since childhood.
  **Unchosen forgetting:** losing memory to old age and fighting it — the mirror of
  Aras, who forgets by choice. Quest: help him remember his students' names.
  Hub: keeper of **kept memories** — re-watch KEPT echoes at the hearth.
  Handle with respect. No death risk. **Lost one:** Kür — Sabir was also Kür's teacher.
  Sometimes he calls Aras "Kür" (a condition-based hook; the trigger is [TBD]).
- **sahbaz** — **Şahbaz**, *serdar* — **anger:** his soldiers died in the fire. At
  first blames the King; at the midpoint learns Aras lit it → door closes. Quest:
  release his soldiers' ash legion; confront **Tural**. Hub: combat training.
  Death risk: yes (ash legion / Tural line).
- **esref** — **Eşref**, *Kartal Dağları'nın beyi* — **loyal memory:** swore to his dead
  wife he would never forget her. Honour makes him a small mirror of the King.
  **Highest death risk:** if his quest fails, one night he opens the door to her shade.
- **nermin** — **Nərmin** (TR: Nermin), *kervan hanımı* — replaces V2 **Anar** (same hooded model,
  adapted; migrate id `anar` → `nermin`). **Denial:** counts the dead in her ledger so
  she never has to feel them. One name is missing: her brother **Samir**.
  Dry humour. Hub: merchant, and **buys KEPT memories** for rare items
  ("everything has a price"). Selling = another way to lose a memory [TBD: does a sold
  memory count as BURNED for Kül Aras?]. **Lost one:** her husband, the caravan master
  [TBD: name]. **Samir's shade never comes to her door** — he is alive — and she
  notices (placeholder line hook).
- **kul_sahi** — **Kül Şahı**, *Ateşan'ın şahı* — **the King, Aras's father.** He gave his
  body to the reversed hearth; people now call him Kül Şahı. The only antagonist.
  `npc_kind: voice_only`, no body. **Never let go.** Kept every memory anyone burned,
  including Aras's. Has a real argument:
  *"You forgot. I did not."* `ignores_burned_names = true`.

### Family (memory only)
- **kur** — **Kür**, *[TBD epithet]* — the King's younger son, Aras's brother. Died of the
  Cold Sickness; the valley bears his name. His death is the root of the reversal.
  `npc_kind: shade` [TBD: where he appears]. Placeholder look.
- **humay** — **Humay**, *[TBD epithet]* — the Queen, Aras's mother. Died years before the
  Cold Sickness; the King gave her memory to the hearth and lost her face. She sang the
  family lullaby. `npc_kind: voice_only` (heard in echoes) [TBD]. Placeholder look.

### Supporting cast
- **domrul** — **Dəli Domrul** (TR: Deli Dumrul), *şehrin delisi* — (Dede Korkut). Talked to his dead
  wife's shade through the door every night for a year; learned the truth; lost his
  mind. **Everything he says is literally true** — riddles, rhymes, mis-sung lullaby.
  Example meaning: *"The Ember-keeper kissed his daughter, then gave her to the fire."*
  Arc end: on his last night he wants to open the door and go with her; Aras stops or
  releases him. Replaces Bəhlul (dropped).
- **yadigar** — **Yadigar**, *başka bir Közcü* (world) — a Közcü further down the same
  road. Each meeting he is emptier: advice → forgets why he hunts → forgets his name
  → attacks Aras or is found dead [TBD]. "Yadigar" = keepsake: the man who kept
  nothing. The in-story warning against burning everything. Model: Közcü variant.
- **ayna** — **Ayna**, *kendini bilen gölge* (world) — a shade who knows she is a shade and
  begs Aras to burn her memory and free her. Makes the player see shades as people.
  Model: shade variant.
- **tural** — **Tural**, *Kül Şövalyesi* (world, boss) — Şahbaz's former lieutenant;
  chose the King for the promise of his dead comrades. Save or kill [TBD outcomes].
  Model: enemy knight variant.
- **peri_nene** — **Pəri Nənə** (TR: Peri Nene), *ağıtçı* (hub) — blind lament singer. Cannot see the
  shades' borrowed faces, recognises them by voice — **the only one who can safely
  open a door at night**; Aras's go-between. Her laments shape the soundtrack.
  (New model needed.)
- **kemal / gulcin** — **Kemal**, *demirci*, and **Gülçin**, *ekmekçi* (hub) — young couple expecting a child.
  They sleep in a room of the caravanserai (behind a door at night; the birth happens
  there); the smithy and the bakery outside the gate are their daytime workplaces.
  Everyday life: arguing, laughing, preparing. **Naming scene (Act III):** they ask
  Aras to name the baby. If Narin is KEPT, "Narin" appears as an option; if not, the
  option simply does not exist.
- **samir** — **Samir**, *kervancı* (world, hidden) — Nərmin's brother. Alive: survived the cold by
  burning all his memories. Found and brought home, he does not know her.

### Lost ones (the shade at each door)
At night the shade that knocks on a resident's door is **that person's own lost loved
one**; a door death means opening the door to them. Only the dead have shades.

| Resident | Lost one |
|---|---|
| Sona | Narin |
| Eşref | his wife |
| Domrul | his wife |
| Ehliman | his children |
| İbrahim | his assistant |
| Şahbaz | his soldiers |
| Sabir | Kür |
| Elvin | his mother, a singer [TBD name] |
| Nərmin | her husband, the caravan master [TBD name] — never Samir, who is alive |

### Background
Generic villagers with barks only. Unlimited. Never carry story facts alone.

### Death risk summary
Can die permanently: Sona, Eşref, Şahbaz, Domrul (by choice), İbrahim [TBD],
Yadigar [TBD], Tural (boss). Never: Sabir, Kemal, Gülçin, the newborn.
Rüfət: story-only [TBD].

---

## 8. Motifs

- **The family lullaby (Narin's lullaby).** One lullaby across generations: Queen Humay
  sang it to Aras; Aras and Sona sang it to Narin; the King knows it as his wife's song.
  It is the *ninni* of the memory `mother_name`. Sona hums it. Domrul sings it with wrong
  words. Elvin plays it without knowing where he learned it. It plays in the memory menu.
  **Heard complete only once — in the final scene.**
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
3. **Közcü's journal** (auto-filled):
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
| Aras is the Közcü | Act I, Rüfət / residents | Act I |
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
- Protagonist: **Aras** (`PROTAGONIST_NAME`). Title: **Közcü** (the Turkish form, used in
  all Turkish text).
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
9. Kür's and Humay's epithets; where Kür's shade appears; how Humay is heard.
10. Which memories besides own_name and Narin are `combat_burnable=false`.
11. `father_voice` BURNED: does Aras fail to recognise his father's voice?

---

## 14. Changelog

- **2026-09-29 — Son Ocaq and the lost ones** (owner)
  - Son Ocaq's residents live in caravanserai **rooms opening onto the courtyard** behind
    an arched gallery; every door is seen from the hearth. Kemal and Gülçin have a room
    inside; the smithy and the bakery are daytime workplaces outside the gate.
  - Lost ones: Sabir → Kür (Sabir taught Kür; he sometimes calls Aras "Kür"); Elvin → his
    mother, a singer the King never acknowledged [TBD name]; Nərmin → her husband, the
    caravan master [TBD name]; Samir's shade never appears at her door (he is alive).
    Table in §7.
- **2026-09-28 — open items resolved** (owner)
  - The King's younger son is **Kür** (Aras and Kür: the two great rivers that merge).
    The King renamed the valley Kür Vadisi after him.
  - The Queen, Aras's mother, is **Humay**. She died years before the Cold Sickness; the
    King gave her memory to the hearth and could never recall her face — the root of his
    "never again" and of the reversal.
  - One family lullaby across generations; `mother_name`'s *ninni* is this lullaby (§8).
  - The King gave his body to the hearth **on the fire night**: Aras's fire created
    Kül Şahı (§3.7).
  - Narin's epithet depends on the story: *kapıdaki gölge*, then *Közcü'nün kızı* after
    `narin_revealed`.
  - KEEP value of the six memories (§6).
  - Kür (shade) and Humay (voice only) added as data-only entries with placeholder looks.
- **2026-09-28 — owner decisions after the first conflict report**
  - Aras is the crown prince **and** the King's Közcü (Ateşan tradition: the heir keeps
    Ulu Ocaq until he is crowned). Heir references ("küçük şah", "şehzadem", "Babamın
    sesi") stay.
  - Kül Şahı **is** the King, Aras's father; he gave his body to the reversed hearth.
    One antagonist. The "Kül Şahı" ending = Aras takes his father's crown of ash.
  - The King's dead son is Aras's younger brother [TBD name]; Elvin is Aras's
    half-brother; Narin is the King's granddaughter.
  - Son Ocaq: a village grown around an old caravanserai; the last hearth burns in its
    courtyard.
  - `rufet_joined` is not a flag: the condition `joined:rufet` derives it from his
    location `party`.
  - Narin: memory `narin` (`combat_burnable=false`) and NPC `narin` (shade) added as
    placeholders.
  - Turkish forms: Közcü (not Közçü) in all Turkish text; Nermin, Deli Dumrul, Peri Nene,
    Kemal (id `kemal`, was `kamal`). Epithets fixed (§7).
- **2026-09-28 — first version** (owner).
