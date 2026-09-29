# STORY_SLICE.md — Vertical Slice Script (Act I: "Kül")

> Script for the vertical slice. Canon source: STORY_BIBLE.md.
> Stage directions are English. **Player-facing lines are final-draft Turkish** and go
> into `strings.csv` under the listed keys.

## 0. Rules for implementation

- Names inside lines use tokens: `{PROTAGONIST}`, `{NPC:<id>}`. Never write a raw name
  in a line that is subject to known/burned-name rules.
  Exception: names spoken inside **echoes** and the **cold open** (see below).
- **Echo name rule:** inside an echo, all names are known (it is a memory from before).
  If the echo is **KEPT**, NPCs named inside it become `name_known = true`.
  If **BURNED**, they stay unknown.
- **Cold open name rule:** the cold open happens before the fire night burned
  everything, so all names resolve as known there (scene-level override).
- Condition notation (the game's condition language): `mem:<id>=KEPT|BURNED|UNKNOWN`,
  `flag:<name>`, `known:<id>` (`known:protagonist` = Aras knows his own name), `has_item:<id>`,
  `rescued:<npc>`, `dead:<npc>`, `grief:<npc>`, `joined:<npc>`, `time:<phase>`, `any_burned`,
  `any_kept`; `!` negates, `&` joins. Written `[if …]` below.
  Action notation: `{reveal_name:<id>}`, `{set:<flag>}`, `{item:+<id>}`, `{move_npc:<id>:<location>}`.
- `(…)` in a line = a written pause/silence in delivery, not text shown.
- Speaker labels always resolve through the Names function (epithet until known).
- Placeholder art/audio is fine. **Lines are not placeholders** — use them as written.

---

## 1. Slice flow

| # | Scene | Where | Time | Gate |
|---|---|---|---|---|
| S0 | Cold open — the fire night | Közkale | night | game start |
| S1 | Wake, light Geçit Ocağı | valley | day | after S0 |
| S2 | First fight, Rüfət joins | valley | day | Geçit Ocağı lit |
| S3 | Arrival at Son Ocak | hub | day | Rüfət joined |
| S4 | First night | hub | night | S3 done, player rests |
| S5 | Morning: the name | hub | dawn | S4 done |
| S6 | Echo 1 — "İlk kılıcım" | valley road | — | after S5, on the road |
| S7 | Yadigar | valley road | day | on the road to Kartal Yamacı |
| S8 | Eşref's hut, rescue | Kartal Yamacı | day | after S5 |
| S9 | Echo 2 — "Ocak başında" | Kartal Yamacı path | — | after S8, optional but on the path |
| S10 | Eşref in the hub (nights 1–3) | hub | day/night | esref rescued |
| S11 | Final night — "Narin'i hatırlıyor musun?" | hub | night | Eşref line concluded |

The player can do S6 and S9 in any order relative to S7/S8 as long as they are on
the path; S11 must react correctly to every state of `hearth_lesson`
(UNKNOWN / KEPT / BURNED).

---

## 2. New data needed

| Type | id | Details |
|---|---|---|
| Memory | `hearth_lesson` | Title key `MEMORY_HEARTH_LESSON_NAME` = "Ocak başında". weight 2, combat_burnable **true** (a temptation). Echo S9. |
| Echo | `echo_first_sword` | Uses existing memory `first_sword`. Echo S6. `reveals_on_keep`: sahbaz, kur. (Replaces the placeholder `test_echo`.) |
| Echo | `echo_hearth_lesson` | Memory `hearth_lesson`. Echo S9. |
| Item | `sirin_yazmasi` | "Şirin'in yazması" — red embroidered headscarf. Found at Eşref's cold hearth. |
| Lost one | esref → `sirin` | Name key `LOST_SIRIN_NAME` = "Şirin". |
| Location | `kartal_yamaci` | Eşref's hut on the mountain slope, with a cold stone hearth. Placeholder. A separate scene reached by a trail from the valley road (like Son Ocak); integrated into the terrain later. |
| Flags | `sona_seen`, `heard_domrul_3`, `act1_complete` | The only real flags. Everything else is a condition on state that already exists (one fact, one owner): |
| Conditions | `rescued:esref` (was esref_rescued), `dead:esref` (esref_dead), `grief:esref` (esref_resolved), the warning (esref_warning: HubNights), `joined:rufet` (Rüfət's location `party`, set with `{move_npc:rufet:party}`), `known:<id>` | |

**Design note (slice-only, until the İbrahim system exists):** every BURN grants a
**permanent** fire upgrade, designed by breakpoints so it is felt: burning
`hearth_lesson` alone unlocks one extra Köz Darbesi charge; burning `first_sword` alone
gives a smaller but visible gain (faster Köz regeneration). Final numbers in the
changelog once approved. This is the stand-in for the MUST-FIX.

---

## 3. The family lullaby (original)

Used in S9 (first two lines only) and in the final game (complete, once).
Narin's knock rhythm = the syllables of line 1: **"U-yu, kö-züm, u-yu"** →
`tak-tak · tak-tak · tak-tak` (short pause between pairs, long pause after).
Data: `data/hub/door_talk.json` → `knocks.narin.rhythm`.

| Key | Line |
|---|---|
| `LULLABY_1` | Uyu, közüm, uyu, |
| `LULLABY_2` | Ocak yanar, sen uyu. |
| `LULLABY_3` | Kül üşürse ben üşürüm, |
| `LULLABY_4` | Sen ısın, kuzum, uyu. |

"Közüm" (my ember) is also the pet name Aras uses for his daughter.

---

## S0 — Cold open: the fire night

**Direction.** Black screen, fire sound. Open in a burning corridor of Közkale.
The player controls Aras running, carrying a **child-sized bundle wrapped in a red
kilim** in both arms. No attacks, no HUD. Linear path, burning beams fall, 60–90 s.
The player should assume he is rescuing a child. (At the end of the full game this
scene replays with context: he is carrying his daughter's shade **into** the fire.)
Ends in the great hall before the enormous Ulu Ocaq. Aras steps into the light →
white-out → title card.

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_S0_01` | Rüfət | {PROTAGONIST}! Bırak onu! | Distant, shouting. Name shown (cold open rule). |
| `SLICE_S0_02` | Kül Şahı | Onu bana ver. | Whisper, from everywhere. |
| `SLICE_S0_03` | Rüfət | Geç kaldık! Bırak artık! | Closer. |
| `SLICE_S0_04` | Kül Şahı | Onu bana ver... | As Aras steps into the light. |

"Bırak onu" works twice: now it reads as *"leave the child, save yourself"*; at the
end of the game it means *"let her go"*.

---

## S1 — Wake

**Direction.** Aras wakes near Geçit Ocağı, light ash falling. Közkale burns on the
horizon. Existing prompt: "Geçit Ocağı'nı yak". No dialogue — silence is the point.

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_S1_01` | Aras | ...Neredeyim? | Whisper, once, after lighting the hearth. |

---

## S2 — First fight, Rüfət

**Direction.** A small placeholder encounter (3 enemies). Midway, Rüfət charges in.
After the fight, Rüfət stares at Aras for a long beat before speaking.

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_S2_01` | Rüfət | Arkanı kolla! | Combat bark on arrival. |
| `SLICE_S2_02` | Rüfət | Sağsın. (…) Gerçekten sağsın. | |
| `SLICE_S2_03` | Aras | Seni tanıyor muyum? | |
| `SLICE_S2_04` | Rüfət | Tanımıyor musun? | |
| `SLICE_S2_05` | Rüfət | (…) İyi. Böylesi daha iyi. | |
| `SLICE_S2_06` | Aras | Ben kimim? | |
| `SLICE_S2_07` | Rüfət | Adını sorma bana. Adın ağır. Önce ayakta dur. | He deliberately withholds it. |
| `SLICE_S2_08` | Rüfət | Rüfət. Benim adım Rüfət. Bunu da unutursan kafana vururum. | Dry humour. |
| `SLICE_S2_09` | Rüfət | Son Ocak'a gidiyoruz. Hava kararmadan. | `{move_npc:rufet:party}` (joined is derived from his location, never a flag) |

---

## S3 — Arrival at Son Ocak (day)

**Direction.** Through the eyvan into the courtyard. Before Aras's name is revealed,
villagers must not speak it (see Barks §5).

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_S3_01` | Rüfət | Kimse sana soru sormaz. Sorarlarsa, ben cevap veririm. | At the gate. |
| `SLICE_S3_02` | Ehliman | Hoş geldin, evlat. Ateş seni tanıdı; ben de tanırım. | At the hearth. |
| `SLICE_S3_03` | Ehliman | Yorgunsun. Yük taşıyan yorulur. Yakmak hafifletir, evlat. Ateş hatırlamaz; ateş affeder. | The "Adsız" voice, early. |
| `SLICE_S3_04` | Gülçin | Bu çocuk ateşten korkmuyor. Karnımda tekmeleyip duruyor. | At the bakery. |
| `SLICE_S3_05` | Kemal | Babasına çekmiş. Ben de korkmam. | |
| `SLICE_S3_06` | Gülçin | Sen örümcekten korkarsın, Kemal. | Life, humour. |
| `SLICE_S3_07` | Domrul | Közcü geldi! Közcü geldi! Ateşi getirdi, kızı getirmedi! | **Domrul line 1.** Dancing round the hearth. Pays off in S11. |
| `SLICE_S3_08` | Rüfət | Aldırma. {NPC:domrul}'dur. Karısını kaybettiğinden beri... böyle. | `{reveal_name:domrul}` before this line. |
| `SLICE_S3_09` | Peri Nene | Adımlarını tanıdım. Ama yürüyüşün değişmiş. Yük mü bıraktın, yük mü aldın, oğul? | Blind; she knows him by his step. |

**Sona (no lines).** Under the gallery, at her loom. She sees Aras. Her hands stop.
She stands, goes inside, and closes the door. `{set:sona_seen}`

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_S3_10` | Rüfət | Ona zaman ver. | Quietly, after her door closes. |
| `SLICE_S3_11` | Aras | Kimdi o? | |
| `SLICE_S3_12` | Rüfət | Soracaksan ona sor. Bana değil. | |

---

## S4 — First night

**Direction.** Rüfət in Aras's room first, then the player is free in the dark
courtyard. Recommended order is guided by where light strips glow, not forced.

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_S4_01` | Rüfət | Gece kapılar açılmaz. Kim çalarsa çalsın. | Before the player leaves the room. |

**Peri Nene's door** (`allows_night_open` — face to face).

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_S4_02` | Peri Nene | Gel, oğul. Benim kapım açılır. Ben görmem; yüzler bana yalan söyleyemez. | |
| `SLICE_S4_03` | Aras | Kapıları kim çalıyor? | |
| `SLICE_S4_04` | Peri Nene | Özlediklerimiz. Sesleri aynı, yüzleri aynı. İçleri boş. | |
| `SLICE_S4_05` | Peri Nene | Açan gider. Onlarla gider. Sabah kapısı aralık, eşiği kül olur. | Teaches the door-death rule. |
| `SLICE_S4_06` | Peri Nene | Bir şey daha. Ölüler ağıt bilmez. Ağıt yakan bir ses duyarsan, o ses yaşıyordur. | Deep-layer lore. |

**Sona's door.** Name challenge. Aras does not know his own name yet.

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_S4_07` | Sona | Kim o? | Label: epithet ("Dokumacı"). |
| `SLICE_S4_08` | Aras | Bilmiyorum... | The only option (name unknown). |
| `SLICE_S4_09` | Sona | (…) Ben biliyorum. | The shadow under the door stops moving during the pause. |
| `SLICE_S4_10` | Sona | Git uyu. Gece uzun. | Door silent until morning. |

**Aras's room.** The small shade knocks in the lullaby rhythm. Rüfət is in bed.

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_S4_11` | Aras | Biri kapıyı çalıyor. | |
| `SLICE_S4_12` | Rüfət | Kimse yok. Uyu. | |
| `SLICE_S4_13` | Aras | Çalıyor, Rüfət. | |
| `SLICE_S4_14` | Rüfət | (…) Açma. Ne olursa olsun, açma. | He knows exactly who it is. |

"Dinle" plays the knock rhythm. No further text.

---

## S5 — Morning: the name

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_S5_01` | Rüfət | Dün gece... ona adını söyleyemedin. | |
| `SLICE_S5_02` | Aras | Bilmiyorum ki. | |
| `SLICE_S5_03` | Rüfət | Aras. Adın Aras. | `{reveal_name:protagonist}` — the name appears on the HUD right after. |
| `SLICE_S5_04` | Rüfət | Bunu benden duyman gerekmezdi. | |
| `SLICE_S5_05` | Aras | Aras... | |
| `SLICE_S5_06` | Rüfət | Kartal Yamacı'nda biri var. Eşref Bey. Yangından sonra dağa çıktı, bir daha inmedi. | Quest start. |
| `SLICE_S5_07` | Rüfət | Sözünden dönmez o adam. Ölse de dönmez. Korkarım tam da bu yüzden ölecek. | |

---

## S6 — Echo 1: "İlk kılıcım" (`first_sword`)

**Direction.** An ember on the valley road. **Echoes are the only places with full,
warm colour** (the world before the cold). Közkale courtyard, bright day.
Young Şahbaz, child Aras (~10), little Kür (~6). Short wooden-sword sparring:
3 exchanges, non-lethal.

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_E1_01` | Şahbaz | Omzunu düşür, şehzadem. Kılıç kolla tutulmaz, omuzla tutulur. | Rhymes with Sabir's lesson ("Taç başa değil, omuza konur"). |
| `SLICE_E1_02` | Şahbaz | Ha şöyle! Bir gün beni gerçekten yeneceksin. | After the player lands a hit. |
| `SLICE_E1_03` | Kür | Sıra bende! Abi, sıra bende! | First time the player hears Kür. |
| `SLICE_E1_04` | Küçük Aras | Sen daha küçüksün, Kür. | |
| `SLICE_E1_05` | Kür | Büyüyünce senden iyi olacağım! | Kür never grew up. |
| `SLICE_E1_06` | Şahbaz | O zaman ikinizi birden yenerim. | Laughs. Fade. |

Choice screen title: "İlk kılıcım". KEEP → `name_known` for sahbaz and kur.
BURN → existing Kül Şahı whisper + permanent upgrade. Designed to be **easy to burn**:
the player has not met Şahbaz or learned who Kür is. The cost is invisible now and
lands in Act II (Şahbaz reconciliation) and with Sabir.

---

## S7 — Yadigar

**Direction.** A man by a small dead fire on the road, pressing a faint ember into
his palm. Calm, tired, sharp.

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_Y_01` | Yadigar | Bir Közcü daha. Son ben kaldım sanıyordum. | |
| `SLICE_Y_02` | Yadigar | Adın ne, kardeş? | name_challenge node. |
| `SLICE_Y_03A` | Yadigar | Güzel ad. Sakla onu. Ben kendi adımı bir kış gecesi az kalsın yakıyordum. | [if known:protagonist] |
| `SLICE_Y_03B` | Yadigar | Benden önde gidiyorsun demek. | [if not known:protagonist] (fallback) |
| `SLICE_Y_04` | Yadigar | Yadigar. Adımı hâlâ hatırlıyorum. Şimdilik. | `{reveal_name:yadigar}` |
| `SLICE_Y_05` | Yadigar | Her yaktığında biraz hafiflersin. Hafiflik iyi gelir. Sorun da bu. | |
| `SLICE_Y_06` | Aras | O zaman neden yakıyorsun? | |
| `SLICE_Y_07` | Yadigar | Bir sebebim vardı. (…) Onu da bir ara yaktım galiba. | He smiles. |
| `SLICE_Y_08` | Yadigar | Kartal Yamacı'na gidiyorsan dikkat et. Gölgeler orada kalabalık. Birinin kapısını bekliyorlar. | Useful + ominous. |

---

## S8 — Eşref's hut, Kartal Yamacı

**Direction.** A stone hut on a windy slope. Outside: a **cold** stone hearth, a red
headscarf (yazma) lying on its stones. Shades circle the hut. Eşref fights them at
his door with an axe. Encounter; Rüfət fights too.

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_ES_01` | Eşref | Rüfət? Yaşıyorsun ha! Yanındaki kim... (…) Şehzadem? | |
| `SLICE_ES_02` | Rüfət | Hafızası yok, Eşref. Kimseyi tanımıyor. | |
| `SLICE_ES_03` | Eşref | Tanımasın. Tanımak ağır iş. | |
| `SLICE_ES_04` | Eşref | Eşref derler. Kartal Dağları'nın beyi. Eskiden. | `{reveal_name:esref}` |
| `SLICE_ES_05` | Rüfət | Burada ölürsün. Gel, Son Ocak'ta ateş var. | |
| `SLICE_ES_06` | Eşref | Ateş var da ne olacak? Ateşe vereceğim bir şeyim yok benim. | |
| `SLICE_ES_07` | Eşref | {NPC_LOST:esref} öldüğünde bu ocağı yakmadım. Ondan tek bir anı vermedim. Söz verdim ona: seni unutmayacağım dedim. | Looking at the cold hearth. Token resolves to "Şirin". |
| `SLICE_ES_08` | Eşref | Söz, sözdür. | |

**Choice (Aras):**

| Key | Option | Response key | Response |
|---|---|---|---|
| `SLICE_ES_09A` | Burada kalırsan sözün de seninle ölür. | `SLICE_ES_10A` | (…) Dilin babanınki gibi keskin. |
| `SLICE_ES_09B` | Seni anlıyorum. | `SLICE_ES_10B` | Anlamazsın. Ama sağ ol. |

ES_10A is the first hint of the father. Both lead to:

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_ES_11` | Eşref | Peki. Gelirim. Ama o ocağı bana bir daha gösterme. Bakamam. | |
| `SLICE_ES_12` | Eşref | Siz önden gidin. Kapıyı kapatıp geleceğim. | He walks inside; `{set:esref_rescued}`. |

**The yazma.** While Eşref is inside, the player may pick up the headscarf from the
cold hearth: `{item:+sirin_yazmasi}`. Nobody comments. Optional — if the player skips
it, they must return here later (S10).

---

## S9 — Echo 2: "Ocak başında" (`hearth_lesson`)

**Direction.** An ember in the snow on the path down from Kartal Yamacı, clearly
visible. A small family room in Közkale, evening, warm hearth, a red kilim on the
wall (the same kilim as the cold open bundle). Adult Aras and a little girl (~5).
She is **never named** in this echo. Label: "Küçük kız".
Gameplay: the girl hands Aras an old comb (Humay's); the player carries it to the
hearth and places it.

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_E2_01` | Küçük kız | Baba, babaanneyi yakacak mıyız? | |
| `SLICE_E2_02` | Aras | Yakmayacağız, közüm. Onu ateşe vereceğiz. O da bizi ısıtacak. | "Közüm" = pet name. |
| `SLICE_E2_03` | Küçük kız | Ama sonra unutursak? | |
| `SLICE_E2_04` | Aras | Bir tanesini veririz. Gerisi bizde kalır. | The core rule of grief in this world. |
| `SLICE_E2_05` | Küçük kız | Hangisini? | |
| `SLICE_E2_06` | Aras | Sen seç. | |
| `SLICE_E2_07` | Küçük kız | Ninni söylediğini. Ninniyi artık ben biliyorum. Unutsak da olur. | She gives the lullaby memory because she carries it now. |
| — | Küçük kız | `LULLABY_1` + `LULLABY_2`, sung softly | While the comb burns. Fade. |

Choice screen title: "Ocak başında". Designed to be **hard to burn**: the player just
held her hand. BURN grants a bigger upgrade (weight 2).

---

## S10 — Eşref in the hub (nights 1–3)

**Timeline after rescue.** Nights are counted in the hub only (waiting at the Son Ocak
hearth). Day 0 arrival → Night 1 normal talk → Night 2 **warning** (HubNights; condition
"warned") → if not resolved, the death on a later night while waiting until morning.
Resolving at any point before the death night cancels the warning.
**Fairness rule:** permanent loss never comes before the player has actually received a
warning. The death countdown starts only once the player has heard Eşref's warning at his
door **or** Domrul's line 3. If neither was heard, the warning repeats on the next hub night.

**Day 0 — arrival.**

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_EH_01` | Eşref | Sağ ol, şehzadem. Borcum olsun. | At his door, first time in the hub. |

**Night 1 — his door.**

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_EN1_01` | Eşref | Kim o? | name_challenge. |
| `SLICE_EN1_02` | Eşref | Gir... Yok, girme. Gece kapı açılmaz. Otur eşiğe, konuşalım. | |
| `SLICE_EN1_03` | Eşref | {NPC_LOST:esref} kilim dokurdu. Seninki gibi... (…) Neyse. Kilim dokurdu. Kırmızıyı severdi. | Slip: Şirin and Sona wove together. The player does not know yet that Sona is his wife. |
| `SLICE_EN1_04` | Eşref | Her gece aklımdan geçiriyorum, bir şey kaybolmasın diye. Yüzünü, sesini, kokusunu. Sayıyorum. | |

**Night 2 — warning** (`HUB_WARNING_ESREF`).

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_EN2_01` | Eşref | Dün gece geldi. | |
| `SLICE_EN2_02` | Aras | Kim? | |
| `SLICE_EN2_03` | Eşref | {NPC_LOST:esref}. Kapıyı üç kez çaldı. Sesi aynıydı. Aynı, {PROTAGONIST}. | |
| `SLICE_EN2_04` | Eşref | Açmadım. (…) Ama elim kapıdaydı. | |

**Day after the warning — Domrul line 3** (`{set:heard_domrul_3}`).

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_D3_01` | Domrul | {NPC:esref}'in karısı dün gece üç kez çaldı! Dördüncüde açılır o kapı. Dördüncüde hep açılır! | Literally true: the next knock is the death night. |

**Resolution (day, requires `sirin_yazmasi`).** If the player does not have it,
Eşref's day lines point nowhere; the player must remember (or read in the journal)
that the scarf was at the cold hearth. Journal thread line: `JOURNAL_ESREF_THREAD` =
"Eşref'in ocağında bir yazma vardı."

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_ER_01` | Eşref | Bu... {NPC_LOST:esref}'in yazması. Nereden buldun? | |
| `SLICE_ER_02` | Aras | Ocağının başındaydı. | |
| `SLICE_ER_03` | Eşref | Hep ocağın başında dururdu zaten. | |
| `SLICE_ER_04` | Eşref | Söz verdim, unutmayacağım dedim. Ama her gece saydıkça... onu değil, saydıklarımı hatırlıyorum artık. | |
| `SLICE_ER_05` | Eşref | Bir tanesini vereceğim. Gerisi bende kalır. | Echoes S9 word for word. If the player saw S9, it lands. |

At the Son Ocak hearth (short ritual: Eşref lays the yazma on the stones, flame rises):

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_ER_06` | Eşref | İlk güldüğü günü veriyorum sana, ateş. Onu ısıt. Beni de. | Snow melts at his door. `{set:esref_resolved}`, grief_resolved esref. |
| `SLICE_ER_07` | Ehliman | Güzel, evlat. Birini verdin. Gerisini de ver; hafiflersin. | |
| `SLICE_ER_08` | Eşref | Yok, kâhin. Gerisi benim. | First visible clash with Ehliman's ideology. |

**Failure — death morning** (`{set:esref_dead}`). Peri Nene's lament is heard on
entering the courtyard; Eşref's door is ajar, ash on the threshold, footprints from
the gate. His light never returns.

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_EF_01` | Rüfət | Dördüncüde açtı. | [if flag:heard_domrul_3] |
| `SLICE_EF_02` | Rüfət | Açmış. (…) Söz sözdür, derdi. | [if not flag:heard_domrul_3] |
| `SLICE_EF_03` | Domrul | Söz sözdür! Söz sözdür! | Quietly, not dancing. Once. |

---

## S11 — Final night: "Narin'i hatırlıyor musun?"

**Gate:** `esref_resolved` or `esref_dead`. That night, Sona's light strip is the only
one on the north side. Everything else as the standard door scene.

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_SF_01` | Sona | Kim o? | Label still "Dokumacı". |
| `SLICE_SF_02` | Aras | {PROTAGONIST}. | name_challenge (known now). |
| `SLICE_SF_03` | Sona | (…) Rüfət söyledi demek. | |
| `SLICE_SF_04` | Sona | Eşref de gitti. {NPC_LOST:esref}'i o kadar sevdi ki kapıyı açtı. | [if flag:esref_dead] |
| `SLICE_SF_05` | Sona | Benim adım Sona. Bunu da mı hatırlamıyorsun? | `{reveal_name:sona}` right after — the label changes on screen. |
| `SLICE_SF_06` | Aras | Hatırlamıyorum. Özür dilerim. | |
| `SLICE_SF_07` | Sona | Sana bir şey soracağım. Doğru söyle. | |
| `SLICE_SF_08` | Sona | Narin'i hatırlıyor musun? | The first time the name "Narin" is spoken. |

**Branch by `hearth_lesson`:**

KEPT

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_SF_K1` | Aras | Ocak başında küçük bir kız... Bana "baba" dedi. Ninni söylüyordu. | |
| `SLICE_SF_K2` | Sona | (…) O ninniyi ona ben öğrettim. | Sound: a weaving shuttle drops to the floor behind the door. |
| `SLICE_SF_K3` | Sona | O senin kızındı, {PROTAGONIST}. Bizim kızımızdı. | |

BURNED (options: "———" disabled, and "Hayır.")

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_SF_B1` | Aras | Hayır. | |
| `SLICE_SF_B2` | Sona | Keşke ben de unutabilseydim. | |
| `SLICE_SF_B3` | Kül Şahı | Ben hatırlıyorum, küçük şah. | Whisper, queued after the door scene closes. |

UNKNOWN (echo 2 never found)

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_SF_U1` | Aras | Hayır. | |
| `SLICE_SF_U2` | Sona | Bir gün hatırlarsın. Ya da hatırlamazsın. Hangisi daha kötü, bilmiyorum. | |

**All branches end:**

| Key | Speaker | Line | Notes |
|---|---|---|---|
| `SLICE_SF_END` | Sona | Git uyu, {PROTAGONIST}. Bu gece kapını çalan olursa... açma. | |

Aras returns to his room. The small shade knocks: `tak-tak · tak-tak · tak-tak`.
Rüfət is asleep. The player can "Dinle". Hold for a few seconds, fade to black.
End card: `SLICE_END_CARD` = "I. Perde — Kül" / `SLICE_END_SUB` = "Devam edecek."
`{set:act1_complete}`

Domrul line 1 pays off here: *"Ateşi getirdi, kızı getirmedi."*

---

## 4. Domrul — lines and payoffs

| # | Key | When | Line | Pays off |
|---|---|---|---|---|
| 1 | `SLICE_S3_07` | Arrival | Közcü geldi! Közcü geldi! Ateşi getirdi, kızı getirmedi! | S11 (Narin) |
| 2 | `SLICE_D2_01` | Day after the first night | Kapılar kimi bekler, bilir misin? Adını unutanı! Adını unutanı! | S4 / S11 (name challenge) |
| 3 | `SLICE_D3_01` | Day after Eşref's warning | (see S10) | S10 (the fourth knock) |

Each line must be heard by default on the critical path (Domrul stands at the hearth,
which the player passes). The flashback montage (bible §9.6) is **not** used in the
slice — the payoffs are close enough to land alone.

---

## 5. Barks

Before `known:protagonist`, no bark may contain `{PROTAGONIST}` (enforced by the bark
system). Rüfət's combat barks have name-free variants until then ("Kılıcını çek, kardeş!").

| Key | Speaker | Line | Condition |
|---|---|---|---|
| `BARK_VILLAGER_PRE_01` | Villager | Şehzadem... demek yaşıyorsun. | not known:protagonist |
| `BARK_VILLAGER_PRE_02` | Villager | Ocak yanıyor mu, şehzadem? Yanıyor, değil mi? | not known:protagonist |
| `BARK_VILLAGER_POST_01` | Villager | Sen {PROTAGONIST}'sın, değil mi? Şehzadem... demek yaşıyorsun. | known:protagonist (existing line) |
| `BARK_GULCIN_01` | Gülçin | Ekmek sıcak. Soğuk her yeri alsa da ekmeği almasın. | day |
| `BARK_KEMAL_01` | Kemal | Demir de ateşi sever. Ama unutmaz, iz tutar. | day |
| `BARK_EHLIMAN_01` | Ehliman | Hafifle, evlat. | day, after any BURN |
| `BARK_EHLIMAN_02` | Ehliman | Tuttuğun her anı bir taş. Taşla yüzülmez, evlat. | day, after any KEEP |

---

## 6. Implementation notes for Claude Code

- New token `{NPC_LOST:<id>}` resolves to that NPC's lost_one name key and **always shows the
  name** (it is the NPC who says it).
- Aras is **silent** in the slice: his lines are subtitles only.
- Story beats run in the `StoryDirector` (the whole game's), data per act: `data/story/act1_beats.json`.
- Inside echoes, unknown names show as known, but **burned** names still blank
  (use `{PROTAGONIST}` for Aras's label in echoes: "Küçük {PROTAGONIST}").
- S11 must be tested in all three `hearth_lesson` states and with/without `esref_dead`.
- The yazma (item) must survive save/load and appear in the journal thread if unpicked.
- Keep every key above even if a branch is unreachable in a given playthrough.

---

## 7. Playtest (5 players, no guidance)

Record, per player:
1. Finished the slice? Time played.
2. "Tell me the story in your own words." (Did they understand Aras, Sona, Narin?)
3. Echo choices: first_sword KEEP/BURN, hearth_lesson KEEP/BURN/not found.
4. Eşref: saved or dead? Did they notice the warning? Did they connect Domrul's line?
5. Reaction at "Narin'i hatırlıyor musun?" (observe face, note words).
6. Did they understand the night door rule without being told twice?
7. What did they think the cold-open bundle was?
8. Would they play the next act? (1–5)

Success signal: most players can retell Aras/Sona/Narin, at least one echo feels
genuinely hard, and Eşref's fate feels caused by their own actions.

---

## 8. [TBD]

1. Exact knock-rhythm timing (placeholder above).
2. Turkish title for the game card after S0 (keep "ASHES OF THE CROWN" for now).
3. Eşref's day lines between nights (placeholder pool is fine for the slice).
4. Music cues per scene.

---

## 9. Changelog

- **2026-09-29 — owner decisions after the conflict report**
  - Condition language as in §0 (`known:`, `!`, `&`, `mem:`, `has_item:`, `any_burned`,
    `any_kept`); `joined:rufet` comes from `{move_npc:rufet:party}`, not a flag.
  - Real flags only `sona_seen`, `heard_domrul_3`, `act1_complete`; the `esref_*` states are
    conditions (`rescued:`, `dead:`, `grief:`, the warning).
  - Key `MEMORY_HEARTH_LESSON_NAME` (was `MEM_HEARTH_LESSON_TITLE`).
  - `{NPC_LOST:<id>}` always shows the name. Echoes and the cold open: all names known
    (burned names still blank); an echo KEPT reveals its names (`reveals_on_keep`).
  - Permanent burn power by breakpoints (hearth_lesson alone = +1 Köz Darbesi charge;
    first_sword = faster Köz regeneration).
  - Eşref's nights counted in the hub only, with the fairness rule (§S10).
  - Kartal Yamacı is a separate scene for now.
  - Aras is silent in the slice (subtitles only).
  - Rüfət's combat barks are name-free until Aras knows his name.
  - New Game → S0 → valley; V2 chapters only from the dev menu.
  - The placeholder `test_echo` is removed; `echo_first_sword` replaces it.
  - Encoding fixed (S10: "Eşref"); the file is UTF-8.
