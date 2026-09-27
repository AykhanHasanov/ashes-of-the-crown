# Ashes of the Crown — Audit (redizayndan əvvəl)

**Tarix:** 2026-09-27

**Təhlükəsizlik nöqtəsi:** `pre-redesign-v0` tag-ı, commit `eba3120` (main). Geri qayıtmaq üçün: `git checkout pre-redesign-v0`.

**Mühərrik:** Godot 4.7.2 (Forward+). Terrain üçün Terrain3D 1.0.2.

**Ölçü:** `scripts/` altında təxminən 16 300 sətir GDScript (79 fayl). Bundan başqa 21 shader, 44 JSON data faylı, 19 dev aləti var.

**Testlər:** avtomatik testlərin hamısı keçir.
- `arena_selftest`: 19 yoxlama
- `ai_selftest`: 40-dan çox yoxlama
- `world_selftest`: 28 yoxlama

> `.gitignore` haqqında qeyd. `.godot/`, `captures/` və `export/` ignore olunur. `*.import` isə **bilərəkdən ignore edilmədi.** Godot 4-də bu fayllar hər assetin idxal ayarlarını saxlayır: normal map bayraqları, kit teksturalarının 1K limiti, yarpaq kartlarının mipmap və VRAM sıxılması. 1350 belə fayl izlənir. Onları ignore etmək təmiz klonda görüntünü korlayar: yarpaqlar titrəyər, teksturalar 2K-ya qayıdar.

---

## a) Ümumi struktur

### Qovluqlar

| Qovluq | Nə var |
|---|---|
| `scenes/` | 6 səhnə. Hər biri tək kök node və skriptdən ibarətdir, qalan hər şey kodda qurulur |
| `scripts/` | `camera/`, `characters/`, `combat/`, `core/`, `debug/`, `enemies/`, `npc/`, `player/` (V2), `player_v3/`, `story/`, `systems/`, `ui/`, `world/` (+`world/gen/`). Kökdə 5 rejim skripti var |
| `data/` | `balance/` (combat, ai, affixes, world), `enemies/` (13), `weapons/` (3), `world/` (layout, qaydalar, vegetasiya, ağaclar, evlər, kəndlilər, 14 prefab), `voices/`, `looks.json` |
| `shaders/` | 21 shader |
| `tools/` | Offline generatorlar: dünya, ağaclar, evlər, bitki bişirmə, animasiya kitabxanası, başlar, səslər, SFX. Bir də inspect/check alətləri |
| `assets/` | `anims/` (UAL), `chars/` (real insanlar), `characters/` (KayKit, V2), `environment/` (KayKit dungeon/halloween), `quaternius/` (8 paket), `village_mk/`, `props_mk/`, `nature/` (Poly Haven), `foliage/`, `buildings/`, `terrain/`, `audio/` |
| `world/` | Generasiya olunmuş Terrain3D regionları və `world_meta.json`, kağız xəritə |
| `docs/` | GDD, SPEC_V2, SPEC_V3, DECISIONS, ENEMIES, ANIMATIONS, WORLD_PIPELINE |

### Autoload-lar (sıra ilə)

`DataDB` → `Settings` → `Memory` → `GameState` → `Fx` → `Audio` → `Barks`.

### Səhnələr

| Səhnə | Kök skript | Rol |
|---|---|---|
| `scenes/main.tscn` (**main scene**) | `scripts/main.gd` | Titul ekranı + Fəsil 1 "İlk sabah" (Közkale). V2 yığını |
| `scenes/chapter2.tscn` | `scripts/chapter2.gd` | Fəsil 2 "Son Ocaq" karvansarayı. V2 yığını |
| `scenes/world.tscn` | `scripts/world_mode.gd` | Açıq dünya "Kür Vadisi" (512×512 m). V3 yığını |
| `scenes/arena.tscn` | `scripts/arena_mode.gd` | Fight Zone: V3 döyüş arenası, 8 dalğa |
| `scenes/char_lab.tscn`, `scenes/tree_lab.tscn` | `scripts/debug/*_lab.gd` | Dev laboratoriyaları, menyudan açılmır |

### Giriş nöqtəsi və menyu axını

1. `main.tscn` açılır. `main.gd` Közkale həyətini qurur, kamera orbitdə fırlanır, `main_menu.gd` göstərilir.
2. Menyu düymələri:
   - **Devam et** (save varsa): `GameState.load_game()`, sonra save-dəki fəsil və checkpoint.
   - **Yeni oyun**: `GameState.new_game()`, sonra Fəsil 1.
   - **Kür Vadisi (açık dünya, V3 test)**: `change_scene_to_file(world.tscn)`.
   - **Savaş arenası (V3 test)**: `change_scene_to_file(arena.tscn)`.
   - **Ayarlar**, **Çıkış**.
3. Fəsil 1 bitəndə Enter basılır və `chapter_base.go_to_chapter(2)` Fəsil 2-yə keçir. Keçid rejimi `static var restart_mode` ilə ötürülür.
4. Pause menyusundan "əsas menyu" seçiləndə yenidən `main.tscn` açılır.
5. Açıq dünyanın öz save-i var: `user://world_test.json`. Hekayə save-i isə `user://save.json`-dur.

---

## b) Sistemlər

Keyfiyyət şkalası: **stabil** / **işləyir amma qarışıqdır** / **bug-lıdır**.

| Sistem | Fayllar | Nə edir | Keyfiyyət | Asılılıqlar |
|---|---|---|---|---|
| **Hərəkət (V3)** | `player_v3/ayxan.gd` (1399 sətir) | Yerimə, qaçış, sprint (stamina), sprintdən tullanma, yuvarlanma, üzmə, sürüşmə, düşmə zərəri, 1 m maneəni aşma | **işləyir amma qarışıqdır.** Testlərlə təsdiqlənib, amma hərəkət, döyüş, Köz, kilid və UI-bağlantıları tək monolitdədir. Üstəlik ölü `MODEL_PATH`, `HIDDEN` və `CharacterModel` qalıqları var | `combatant.gd`, `human.gd`, `Settings`, `Memory`, `Fx`, `DataDB` (weapons, combat.json), `third_person_camera` |
| **Hərəkət (V2)** | `player/player.gd` (627) | İzometrik hərəkət, 3 zərbəlik kombo, Kül addımı, Alov dalğası | **işləyir amma qarışıqdır.** V3-ün təkrarıdır, yalnız Fəsil 1–2-də işlənir | `balance.gd`, `camera_rig`, `Memory`, `radial_menu`, `ash_offer` |
| **Kamera** | `camera/third_person_camera.gd` (V3), `camera/camera_rig.gd` (V2) | V3: çiyin üstündən, SpringArm, lock-on, döyüşdə genişlənmə, köhnə rig-in API-si (cinematic, shake). V2: izometrik, titul orbiti | V3 **stabil**, V2 **dublikat** | `Fx` (shake/punch), dialoq |
| **Döyüş** | `combat/combatant.gd`, `hit.gd`, `melee.gd`, `projectile.gd`, `aoe.gd`, `player_habits.gd`, `data/weapons/*`, `data/balance/combat.json` | Zərbə ilə can, stamina, stance (poise), parry, blok, arxadan zərbə, edam, statuslar (yanma), tokenlər, mərmilər, sahə effektləri, hit-stop (`Fx`) | **stabil** (19 test) | `Fx`, `DataDB` |
| **Stamina/can** | `combatant.gd` (V3), `player.gd` (V2, ayrıca), ocaqda sağalma `chapter_base.gd` (V2 `Balance`) | Stamina hər hərəkətin qapısıdır. Şərbət (flask) sistemi var. Ocaqda dincəlmək | V3 **stabil**. Ocaqda sağalma **qarışıqdır**: `chapter_base` V2 `Balance`-ı hamı üçün işlədir | `balance.gd`, `Memory` (`mother_name` cəzası) |
| **Düşmən AI** | `enemies/foe.gd` (1573), `perception.gd`, `affixes.gd`, `data/enemies/*`, `data/balance/ai.json` | Utility AI, görmə/eşitmə/axtarış, AI LOD, 7 affiks, morale və təslim olma, adaptiv AI, bosslar | **işləyir amma qarışıqdır.** 40-dan çox test keçir, amma tək 1573 sətirlik fayldır. Parsın xallarından qalan `spots` kodu ölüdür | `combatant`, `human`/`character_model`, `fur`, `Barks`, `DataDB` |
| **Düşmən (V2)** | `enemies/ash_shade.gd` (397) | Fəsil 1-in skelet kölgələri: halqa telegrafı, tək hücum | **dublikat.** `foe` + `ash_shade.json` eyni işi görür | `balance.gd`, KayKit |
| **Dalğa sistemi** | `main.gd` (Fəsil 1: 3 dalğa), `arena_mode.gd` (8 dalğa + ocaq) | Dalğaları yaratmaq, sonunu aşkar etmək | Hər ikisi **işləyir**. İki ayrı implementasiyadır | Düşmən sinifləri |
| **Dialoq** | `ui/dialogue_ui.gd`, `story/rufet_dialogue.gd`, `story/king_echoes.gd` | Letterbox, yazı maşını effekti, seçimlər, bayraqlar, yaddaş şərtli budaqlar | UI **stabil**. Məzmun GDScript-dədir, JSON-da deyil (spec qaydasına ziddir) | `GameState` (flag), `Memory`, `camera.cinematic` |
| **Save** | `systems/game_state.gd` | JSON: fəsil, checkpoint, bayraqlar, əks-sədalar, yanmış xatirələr, `world{}` (ocaqlar, sandıqlar, kəşflər, xəritə dumanı, vaxt, mövqe). Versiya 4 | **işləyir amma qarışıqdır.** İki fayl və iki model var: hekayə fəsil+checkpoint, dünya isə açarlı siyahı. EventBus yoxdur. Düşmən, NPC və dünya vəziyyəti saxlanılmır | `Memory`, hamı `GameState.flags` oxuyur |
| **UI** | `ui/hud.gd`, `pause_menu`, `settings_panel`, `ui_theme`, `main_menu`, `journal`, `compass`, `world_map`, `hearth_menu`, `radial_menu`, `ash_offer` | HUD: can, stamina, şərbət, Köz, xatirə siyahısı, boss zolağı, bannerlər. Menyular, jurnal, kompas, xəritə, ocaq menyusu, xatirə çarxı, Kül Şahı təklifi | Menyular **stabil**. `hud.gd` V2 və V3 elementlərini qarışıq saxlayır | `Memory`, `GameState`, `Settings`, `Balance` |
| **Audio** | `systems/audio.gd`, `systems/barks.gd`, `tools/gen_audio.py`, `tools/gen_voices.py`, `data/voices/*` | Sintez olunmuş SFX, musiqi qatları, külək. 3D səsli türkcə replikalar və altyazılar (düşmənlər, kəndlilər) | **stabil.** Səslər TTS prototipidir, buraxılışdan əvvəl dəyişməlidir | `Settings` (səs), `DataDB` |
| **Yaddaş Yanğını** | `systems/memory_system.gd`, `ui/radial_menu.gd`, `ui/ash_offer.gd`, `ayxan.gd` (Köz ölçüsü, `_refresh_burn_look`), `player.gd` | 6 şəxsi xatirə hərəsinin cəzası var. Çarxdan seçilib Alov Dalğası üçün yandırılır, Kül Şahı aşağı canda təsadüfi birini yandırır. Köz (ember) zərbələrlə dolur. Yanmış xatirə sayı Ayxanın "yanıq görünüşünü" artırır (**bu, yeni dizayndakı "kül səviyyəsi"nə ən yaxın şeydir**) | **işləyir.** Amma şəxsi xatirə modeli yeni "Xatirə valyutası" ilə uyğun gəlmir | `Fx`, HUD, dialoq (budaqlar), ocaq sağalması |
| **Səviyyələr** | `world/kozqala.gd` (580), `son_ocaq.gd`, `arena.gd` (ikisi də kozqala-dan törəyir), `open_world.gd` + `cell_streamer`, `poi_builder`, `terrain_setup`, `day_night`, `weather`, `water`, `birds`, `wildlife`, `interactable`, `gen/world_generator.gd` | V2 səviyyələri kodda qurulub (KayKit). Açıq dünya data-dan generasiya olunur və stream edilir | Açıq dünya **stabil** (28 test). Terrain3D-nin 4.7-də 3 uyğunsuzluğu həll edilib. V2 səviyyələri **işləyir**, amma realizm keçidindən kənarda qalıb (chibi üslubu) | `DataDB`, Terrain3D, `human`, `villager` |
| **NPC-lər** | `npc/villager.gd` (V3 rejim), `npc/survivor.gd` + `story/survivors.gd` (V2 ehtiyac AI), `npc/companion.gd` (Rüfət) | V3: saata görə iş yerləri, salam, qaçış. V2: istilik/ünsiyyət/vəzifə ehtiyacları | Hər ikisi **işləyir**. İki ayrı NPC beyni var. Yaddaş, münasibət və qalıcı ölüm yoxdur | `human`/`character_model`, `Barks`, `day_night` |
| **Personaj modelləri** | `characters/human.gd`, `character_model.gd`, `fur.gd`, `data/looks.json`, `tools/build_anim_library.gd`, `tools/bake_heads.gd` | Real insanlar (UAL animasiyaları, KayKit klip xəritəsi), heyvanlar (shell fur) | **stabil.** Bir riski var, bax: (e) | assets |
| **Debug** | `debug/*`, `Settings` (`--demo`, `--capture`) | F10 menyusu, F4 AI overlay, 3 avtomatik test, laboratoriyalar, demo kameraları | **stabil** | hamısı |

---

## c) Üç rejim

| | **Main Story** | **Açıq dünya** | **Fight Zone** |
|---|---|---|---|
| Səhnələr | `main.tscn`, `chapter2.tscn` | `world.tscn` | `arena.tscn` |
| Rejim skripti | `main.gd` (525), `chapter2.gd` (125) | `world_mode.gd` (652) | `arena_mode.gd` (255) |
| Səviyyə | `kozqala.gd`, `son_ocaq.gd` | `open_world.gd` + streaming, generator | `arena.gd` (kozqala-dan törəyir) |
| Oyunçu | **V2** `player/player.gd` | **V3** `ayxan.gd` | **V3** `ayxan.gd` |
| Kamera | **V2** `camera_rig.gd` | **V3** `third_person_camera.gd` | **V3** |
| Düşmənlər | **V2** `ash_shade.gd` | **V3** `foe.gd` | **V3** `foe.gd` |
| NPC | `companion.gd`, `survivor.gd` | `villager.gd` | yoxdur |
| Save | `user://save.json` | `user://world_test.json` | yoxdur |
| Modellər | KayKit chibi | Real (Quaternius/UAL) | Real |

**Paylaşılan kod:**
- Hamısı `chapter_base.gd`-dən törəyir (273 sətir): HUD, dialoq, pause, jurnal, çarx, Kül Şahı, ocaq sağalması, capture.
- Hamısı autoload-ları, `hud.gd`, `effects.gd`, `visuals.gd`-ni işlədir.
- Açıq dünya ilə Fight Zone V3 nüvəsini tam paylaşır: `ayxan`, `foe`, `combatant`, `third_person_camera`, `human`, `debug_menu`, `ai_overlay`. Main Story V3 nüvəsindən **heç nə** işlətmir.

**Dublikat kod (təxmini ~1 700 sətir, bütün kodun ~10%-i):**
- `player.gd` ↔ `ayxan.gd`: iki tam oyunçu kontrolleri (hərəkət, kombo, yuvarlanma, Köz, Alov). Təxminən 600 sətir.
- `ash_shade.gd` ↔ `foe.gd` + `data/enemies/ash_shade.json`. Təxminən 400 sətir.
- `camera_rig.gd` ↔ `third_person_camera.gd`: shake/cinematic API iki dəfə yazılıb. Təxminən 100 sətir.
- `survivor.gd` ↔ `villager.gd`: iki NPC beyni. Təxminən 240 sətir.
- Ocaq məntiqi: `chapter_base._update_hearths` (V2) ↔ `interactable.gd` + `hearth_menu` (V3).
- `echo_spot.gd` ↔ `interactable.gd`-nin "echo" növü.
- Dalğalar: `main.gd` ↔ `arena_mode.gd`. Düşmən yaratma və izləmə: `arena_mode.spawn_foe` ↔ `world_mode._foes`.
- Tənzimləmələr: `systems/balance.gd` (V2 sabitləri) ↔ `data/balance/combat.json` (V3).

---

## d) Faylların yeni dizayna görə təsnifatı

**SAXLA** · **DƏYİŞDİR** · **TEST ARENASI** · **ARXİV** (silinmir, sadəcə işarələnir)

### Səhnələr

| Fayl | Qərar | Səbəb |
|---|---|---|
| `scenes/main.tscn` | DƏYİŞDİR | Giriş nöqtəsi olaraq qalır, amma yalnız "Yeni oyun / Davam et" menyusunu göstərib birləşmiş dünyanı açmalıdır |
| `scenes/chapter2.tscn` | ARXİV | Son Ocaq ayrıca fəsil deyil, dünyanın içindəki hub olacaq |
| `scenes/world.tscn` | DƏYİŞDİR | Tək birləşmiş dünyanın səhnəsinə çevrilir |
| `scenes/arena.tscn` | TEST ARENASI | Debug menyusundan açılan gizli test sahəsi |
| `scenes/char_lab.tscn`, `scenes/tree_lab.tscn` | SAXLA | Asset yoxlamaq üçün dev laboratoriyalarıdır, dizayndan asılı deyil |

### Rejim skriptləri

| Fayl | Qərar | Səbəb |
|---|---|---|
| `scripts/chapter_base.gd` | DƏYİŞDİR | Ortaq iskele faydalıdır, amma fəsillər, `restart_mode`, V2 oyunçu/kamera defoltları və V2 ocaq sağalması tək dünya üçün yenidən qurulmalıdır |
| `scripts/main.gd` | DƏYİŞDİR | Titul hissəsi yeni menyuya, Fəsil 1-in hekayəsi (Rüfət, əks-sədalar) dünyada proloq/ərazi kimi V3 yığınına köçürülməlidir |
| `scripts/chapter2.gd` | ARXİV | Onun rolunu dünyadakı hub (Son Ocaq) götürür |
| `scripts/world_mode.gd` | DƏYİŞDİR | Birləşmiş oyunun əsası olur: WorldState, EventBus, Xatirə düşməsi və gecə mərhələləri buraya qoşulacaq |
| `scripts/arena_mode.gd` | TEST ARENASI | Dalğalar, F10 spawn və testlər dev arenası üçün olduğu kimi faydalıdır |

### Oyunçu, kamera, döyüş

| Fayl | Qərar | Səbəb |
|---|---|---|
| `player_v3/ayxan.gd` | DƏYİŞDİR | Nüvə qalır. Monolit hissələrə bölünməli, Köz Xatirə yandırmaya çevrilməli, zərbə ilə can qaytarma (rally) əlavə olunmalı, ölü qalıqlar təmizlənməlidir |
| `player/player.gd` | ARXİV | V2 izometrik oyunçunun yerini `ayxan.gd` tam tutur |
| `camera/third_person_camera.gd` | SAXLA | Soulslike kamera, lock-on və kinematik API hazırdır |
| `camera/camera_rig.gd` | ARXİV | İzometrik V2 kamerasıdır. Titul orbitinə ehtiyac olsa, V3 kamerası ilə edilir |
| `combat/combatant.gd` | DƏYİŞDİR | Stabildir, amma "qurtarıla bilən" stagger vəziyyəti və rally (gecikmiş can itkisi) buraya aiddir |
| `combat/hit.gd`, `melee.gd`, `projectile.gd`, `aoe.gd`, `player_habits.gd` | SAXLA | Stabil, testlidir və dizaynla ziddiyyəti yoxdur |

### Düşmənlər

| Fayl | Qərar | Səbəb |
|---|---|---|
| `enemies/foe.gd` | DƏYİŞDİR | AI qalır. Xatirə düşməsi, "Təmizləmə" ritualı üçün stagger pəncərəsi və qurtarılınca insana çevrilmə əlavə olunmalıdır. Ölçüsü bölünməyi tələb edir |
| `enemies/perception.gd`, `enemies/affixes.gd` | SAXLA | Stabil və müstəqildir |
| `enemies/ash_shade.gd` | ARXİV | V2 kölgəsini `foe.gd` + `ash_shade.json` tam əvəz edir |

### NPC və hekayə

| Fayl | Qərar | Səbəb |
|---|---|---|
| `npc/villager.gd` | DƏYİŞDİR | Hub NPC-lərinin təməlidir. Qalıcı ölüm, münasibətlər, yaddaş, gecə qapı arxası dialoqu və qurtarılanların yerləşməsi əlavə olunmalıdır |
| `npc/survivor.gd` | DƏYİŞDİR | Ehtiyac AI-ı (istilik, ünsiyyət, vəzifə) `villager.gd`-nin rejimi ilə tək NPC beynində birləşməlidir |
| `npc/companion.gd` | DƏYİŞDİR | Rüfət hekayədə qalır, amma KayKit modelindən real insana və V3 döyüşünə keçməlidir |
| `story/survivors.gd` | DƏYİŞDİR | Səkkiz sakinin şəxsiyyəti dəyərlidir, amma data JSON-a və real görünüşlərə köçməlidir |
| `story/rufet_dialogue.gd`, `story/king_echoes.gd` | DƏYİŞDİR | Məzmun qalır, format data-driven JSON-a keçməlidir |

### Sistemlər (autoload)

| Fayl | Qərar | Səbəb |
|---|---|---|
| `core/data_db.gd` | SAXLA | Data yükləyicisi dizayndan asılı deyil |
| `systems/settings.gd` | SAXLA | Ayarlar, idarəetmə və debug arqumentləri universaldır |
| `systems/fx.gd` | SAXLA | Hit-stop, shake və slow-mo Bloodborne hissi üçün lazımdır |
| `systems/audio.gd`, `systems/barks.gd` | SAXLA | Stabildir. Yeni hadisələr (qapı arxası səsləri) data ilə əlavə olunur |
| `systems/game_state.gd` | DƏYİŞDİR | WorldState + Save-ə çevrilməlidir: tək fayl, gecə mərhələsi, yerdəki Xatirə, NPC-lərin vəziyyəti, qurtarılanlar |
| `systems/memory_system.gd` | DƏYİŞDİR | Yaddaş Yanğını qalır, amma mənbə 6 şəxsi xatirədən Xatirə valyutasına keçir. Yanıq görünüşü ("kül səviyyəsi") çıxarılır |
| `systems/balance.gd` | ARXİV | V2 sabitləridir. V3 dəyərləri `data/balance/*.json`-da yaşayır (`chapter_base` və `ash_offer` əvvəl oradan ayrılmalıdır) |

### UI

| Fayl | Qərar | Səbəb |
|---|---|---|
| `ui/main_menu.gd` | DƏYİŞDİR | Yalnız "Yeni oyun / Davam et / Ayarlar / Çıxış" qalır, test rejimləri debug menyusuna keçir |
| `ui/hud.gd` | DƏYİŞDİR | Xatirə sayğacı, gecə mərhələsi və rally göstəricisi əlavə olunmalı, V2 xatirə siyahısı çıxarılmalıdır |
| `ui/hearth_menu.gd` | DƏYİŞDİR | Ocaqda Xatirə ilə səviyyə artırma bura əlavə olunmalıdır |
| `ui/journal.gd` | DƏYİŞDİR | Şəxsi xatirələr əvəzinə hub sakinləri, münasibətlər və əks-sədalar göstərilməlidir |
| `ui/ash_offer.gd` | DƏYİŞDİR | Kül Şahı motivi qalır, amma "təsadüfi xatirə yandırmaq" yeni valyuta modelinə uyğunlaşdırılmalıdır |
| `ui/radial_menu.gd` | ARXİV | Xatirə valyuta olanda yandırmaq seçim deyil, miqdardır. Çarxa ehtiyac qalmır |
| `ui/dialogue_ui.gd` | SAXLA | Generik dialoq qutusudur. Qapı arxası rejimi üslub parametri kimi əlavə olunar |
| `ui/pause_menu.gd`, `settings_panel.gd`, `ui_theme.gd`, `compass.gd`, `world_map.gd` | SAXLA | Stabildir və dizaynla ziddiyyəti yoxdur |

### Dünya

| Fayl | Qərar | Səbəb |
|---|---|---|
| `world/open_world.gd`, `cell_streamer.gd`, `poi_builder.gd`, `terrain_setup.gd`, `day_night.gd`, `weather.gd`, `water.gd`, `birds.gd`, `wildlife.gd`, `effects.gd`, `visuals.gd`, `gen/world_generator.gd` | SAXLA | Birləşmiş dünyanın hazır, testli infrastrukturudur. "Gecə dərinləşir" mərhələləri `day_night`/`weather` üzərinə parametr kimi gələcək |
| `world/interactable.gd` | DƏYİŞDİR | Yerdə qalan Xatirə yığını və hub qapıları yeni növlər kimi bura əlavə olunmalıdır |
| `world/kozqala.gd` | DƏYİŞDİR | Közkale proloq ərazisi kimi dünyaya daxil olmalıdır. `arena.gd` və `son_ocaq.gd` onun köməkçilərindən törəyir |
| `world/son_ocaq.gd` | DƏYİŞDİR | Hub-ın (karvansaray) təməlidir. Real assetlərlə dünyanın içində yenidən qurulmalıdır |
| `world/arena.gd` | TEST ARENASI | Fight Zone səviyyəsidir |
| `world/echo_spot.gd` | ARXİV | `interactable.gd`-nin "echo" növü eyni işi görür |

### Personajlar və debug

| Fayl | Qərar | Səbəb |
|---|---|---|
| `characters/human.gd`, `characters/fur.gd`, `characters/character_model.gd` | SAXLA | Real personaj və heyvan boru xəttidir. `character_model` heyvanlar üçün hələ lazımdır |
| `debug/debug_menu.gd`, `ai_overlay.gd`, `world_selftest.gd`, `char_lab.gd`, `tree_lab.gd` | SAXLA | Dev alətləridir |
| `debug/combat_selftest.gd`, `debug/ai_selftest.gd` | TEST ARENASI | Arena səhnəsində işləyirlər |

### Shader-lər

| Fayl | Qərar | Səbəb |
|---|---|---|
| `ash_overlay`, `foliage`, `fur_shell`, `grass_cards`, `hp_bar`, `noise.gdshaderinc`, `recolor`, `sky`, `tree_bark`, `tree_leaves`, `tree_wind.gdshaderinc`, `vignette`, `water`, `window_glow` | SAXLA | Aktiv V3 dünyası və personajlar bunları işlədir |
| `ghost`, `ground`, `lava`, `soot`, `stone` | DƏYİŞDİR | Közkale/əks-səda üçündür. Proloq dünyaya köçəndə real görünüşə uyğunlaşdırılmalıdır |
| `shade.gdshader` | ARXİV | Heç bir skript istifadə etmir |
| `spots.gdshader` | ARXİV | Parsın xallarını indi `fur_shell` çəkir. `foe.gd`-dəki `spots` budağı ölüdür |

### Data

| Fayl | Qərar | Səbəb |
|---|---|---|
| `data/balance/combat.json` | DƏYİŞDİR | Rally (zərbə ilə can qaytarma), Xatirə yandırma qiyməti və hit-stop dəyərləri əlavə olunmalıdır |
| `data/balance/ai.json`, `affixes.json`, `world.json` | SAXLA | Mövcud sistemlərin tənzimləmələridir. Gecə mərhələləri `world.json`-a əlavə kimi gəlir |
| `data/enemies/*.json` (13) | DƏYİŞDİR | Hər düşmənə `xatire` (düşən miqdar) və `redeemable` (qurtarıla bilər və kimə çevrilir) sahəsi lazımdır |
| `data/weapons/*.json`, `data/looks.json`, `data/voices/*`, `data/world/*` (layout, poi_rules, vegetation, trees, houses, prefabs) | SAXLA | Data-driven məzmundur, dizaynla ziddiyyəti yoxdur |
| `data/world/villagers.json` | DƏYİŞDİR | Hub sakinləri, qurtarılanlar, münasibətlər və qalıcı ölüm üçün sxem genişlənməlidir |

### Alətlər

| Fayl | Qərar | Səbəb |
|---|---|---|
| `gen_world`, `bake_foliage`, `gen_trees`, `make_foliage_cards.py`, `build_houses`, `build_anim_library`, `bake_heads`, `pack_terrain`, `gen_audio.py`, `gen_voices.py`, `check_scripts`, `check_anims`, `anim_lengths`, `list_anims`, `inspect_rig` | SAXLA | Məzmun pipeline-ı və yoxlama alətləridir |
| `inspect_models`, `inspect_props`, `inspect_quaternius`, `inspect_sizes` | ARXİV | Birdəfəlik araşdırma skriptləri idi, heç nə onlardan asılı deyil |

### Assetlər (qovluq səviyyəsində)

| Qovluq | Qərar | Səbəb |
|---|---|---|
| `assets/chars`, `anims`, `foliage`, `nature`, `buildings`, `village_mk`, `props_mk`, `terrain`, `audio` | SAXLA | Realizm keçidinin aktiv assetləridir |
| `assets/quaternius/animals_pack`, `medieval_weapons_pack`, `rpg_items_pack`, `survival_pack`, `modular_medieval_buildings_pack` | SAXLA | Heyvanlar, silahlar, qala və proplar hələ istifadə olunur |
| `assets/quaternius/medieval_village_pack`, `modular_dungeon_pack`, `assets/environment` | DƏYİŞDİR | Quyu, köşk, tonqal və xarabalıq hissələri qalıb. Real kitlərlə əvəz olunmalıdır |
| `assets/quaternius/nature_pack` | ARXİV | Heç bir prefab onu işlətmir. `vegetation.json`-da yalnız işlənməyən ehtiyat yolları qalıb |
| `assets/characters` (KayKit) | ARXİV | Yalnız V2 oyunçu, ash_shade, Rüfət və sakinlər işlədir, bir də `ayxan.gd`-də ölü sabitdə qalıb. V2 köçürüldükdən sonra yeri qalmır |

---

## e) Bilinən bug-lar və texniki borc

**Bug və risklər**

1. **`human.gd` → `play_action()`** paylaşılan animasiya kitabxanasında `loop_mode = NONE` yazır (bu resurs bütün personajlar üçün birdir). Kimsə looplu klipi action kimi oynatsa, həmin klip hamı üçün loopunu itirir.
2. **`villager.gd`:** iş yerindəki prop (məsələn oduncunun baltası) əlinə bir dəfə taxılır və heç vaxt çıxarılmır.
3. **Çıxışda sızmalar:** dünya səhnəsindən çıxanda 39–47 ObjectDB nüsxəsi və 1 Mesh RID sızır. Zərərsizdir, amma səs-küy yaradır və gələcək sızmaları gizlədir.
4. **`gen_world`:** Terrain3D ağaca əlavə olunanda `Error loading resource: ''` yazır. Zərərsizdir, amma təmizlənməmiş xətadır.
5. **Performans (Intel UHD):** açıq dünya 25–30 fps, kənd meydanı 17–21 fps verir. Detallı evlər kölgə kaskadlarında dəfələrlə çəkilir. Hədəf maşın (Asus) hələ ölçülməyib.
6. **Testlər zamana həssasdır:** maşın yüklü olanda vaxt pəncərəli yoxlamalar düşə bilir. `Human.warm_up()` bunu xeyli azaldıb, amma riski tam aradan qaldırmayıb.
7. **Demo mövqeyi:** `world_forest` demosunun kamerası sıldırım yamaca düşür, Ayxan düşmə pozasında qalır. Oyuna təsiri yoxdur.

**Texniki borc**

8. **İki oyunçu, iki kamera, iki düşmən, iki NPC beyni.** Təxminən 1 700 sətir dublikat var (bax: c).
9. **İki save faylı və iki save modeli.** EventBus yoxdur. Düşmən və NPC vəziyyəti saxlanılmır.
10. **Monolitlər:** `foe.gd` (1573) və `ayxan.gd` (1399). Yeni mexanikalar (Xatirə, Təmizləmə, rally) bunları daha da böyüdər.
11. **Tənzimləmə iki yerdədir:** `balance.gd` (V2) və `data/balance/*.json` (V3).
12. **Dialoq məzmunu GDScript-dədir**, JSON-da deyil.
13. **Ölü kod:**
    - `ayxan.gd`: `MODEL_PATH`, `HIDDEN`, `CharacterModel`;
    - `foe.gd`: `spots` budağı;
    - `vegetation.json`: ot, çiçək və buğda üçün işlənməyən `model` yolları;
    - `shade.gdshader`.
14. **Main Story vizual olaraq geridə qalıb:** KayKit chibi Ayxan, Rüfət və sakinlər, kodla qurulmuş Közkale.
15. **Heyvanlar:** canavar və pars low-poly modeldir, yalnız tüklə yaxşılaşdırılıb. Pars tülkü modelindən törədilib.
16. **Səslər:** TTS prototipidir, kommersiya buraxılışından əvvəl real səsləndirmə lazımdır.
17. **Terrain3D 1.0.2** Godot 4.7 üçün yazılmayıb. Üç workaround kodda saxlanır, Terrain3D yenilənəndə yenidən yoxlanmalıdır.
18. **Sətir sonları:** CRLF/LF qarışıqdır. Git hər commit-də xəbərdarlıq verir, `.gitattributes` LF tələb edir.

---

## f) Tövsiyə olunan ilk 5 addım

1. **WorldState + EventBus + Save nüvəsi.**
   - `game_state.gd`-ni tək save faylı və versiyalı sxem olan WorldState-ə çevirmək. Sxemə gecə mərhələsi (0–3), yerdəki Xatirə (mövqe və miqdar), NPC-lər (sağ/ölü, münasibətlər) və qurtarılanlar daxil olsun.
   - Yüngül `EventBus` autoload-u əlavə etmək: `enemy_killed`, `player_died`, `xatire_changed`, `npc_rescued`, `night_deepened`.
   - Hələ heç bir mexanika dəyişmir, yalnız təməl qoyulur. `world_selftest`-ə save/load yoxlamaları əlavə olunur.
2. **Tək dünyaya keçid.**
   - `main_menu` yalnız "Yeni oyun / Davam et" göstərsin, arena debug menyusuna köçsün.
   - `world_mode` əsas rejim olsun, `chapter_base` sadələşsin.
   - V2 faylları (bax: d) yalnız işarələnsin, hələ silinməsin. Fəsil 1–2-yə menyudan giriş bağlanır.
3. **Soulslike döngü.**
   - Düşmənlərdən Xatirə düşsün (`data/enemies/*.json` sahəsi). Ölümdə yerdə qalsın (`interactable` yeni növü), təkrar ölümdə itsin və gecə bir mərhələ dərinləşsin.
   - Ocaqda Xatirə ilə səviyyə artırılsın (`hearth_menu`).
   - Yaddaş Yanğını Xatirəni yandırsın: Köz ölçüsü, yanıq görünüşü və çarx çıxarılır.
4. **Döyüş hissi.**
   - `combatant` və `ayxan` üçün rally (zərbədən sonra geri qaytarıla bilən can), daha aqressiv tempi, hit-stop dəyərləri `combat.json`-a.
   - Eyni vaxtda `ayxan.gd`-ni hərəkət, döyüş və resurs komponentlərinə bölmək.
   - Arena testləri genişlənir.
5. **Qurtarma və hub.**
   - `foe`-ya "qurtarıla bilən" stagger pəncərəsi və 3 saniyəlik Təmizləmə ritualı.
   - Qurtarılan düşmən real insan NPC kimi Son Ocaq hub-ında yaşamağa başlayır. `villager` + `survivor` birləşmiş NPC beyni: gün/gecə rejimi, gecə qapı arxası dialoqu, qalıcı ölüm, münasibətlər.
   - Son Ocaq dünyanın içində real kitlərlə qurulur.
