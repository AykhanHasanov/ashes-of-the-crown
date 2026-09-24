# Qərarlar jurnalı

Burada yalnız təsdiqlənmiş qərarlar yazılır. Burada olmayan heç nə qərar sayılmır.

| Tarix | Qərar | Kim | Səbəb |
|---|---|---|---|
| 2026-09-24 | Layihə tək nəfərlikdir. Sahib istiqaməti verir, Claude bütün dizaynı və kodu hazırlayır | Sahib | Sahibin oyun mühərriki təcrübəsi yoxdur |
| 2026-09-24 | Ssenari, hadisələr və personaj rolları tamamilə Claude-a həvalə olunub | Sahib | "Ən fantastik ssenariləri özün seç" |
| 2026-09-24 | 2D yox, **3D** | Sahib | Maksimum vizual təsir |
| 2026-09-24 | Baş qəhrəman: **Ayxan** | Sahib | — |
| 2026-09-24 | Əsas personajlar: Sabir, Anar, Elvin, Şahbaz, Əşrəf, Rüfət, İbrahim, Əhliman | Sahib | — |
| 2026-09-24 | Mühərrik: **Godot 4.7.2** (Unreal Engine 5 yox) | Claude, sahib təsdiqlədi | Noutbukda (Intel UHD, 8 GB) UE5 işləməz. Godot yüngüldür, hər şey mətn faylıdır, Claude onu tam idarə edə bilir |
| 2026-09-24 | Kamera: yuxarıdan bucaq altında 3D (BG3, Diablo, Hades üslubu), dialoqda kinematoqrafik yaxın plan | Claude | Zəif kompüterdə gözəl görünür, miqyas realdır |
| 2026-09-24 | Vizual üslub: stilizə edilmiş qaranlıq fantaziya, gözəlliyi işıq, od, duman və partikllər yaradır | Claude | Kodla yaradıla bilir, zəif avadanlıqda işləyir |
| 2026-09-24 | İki qrafika rejimi: Aşağı (noutbuk) və Yüksək (Asus TUF F15, GTX 1660 Ti). Videokarta görə avtomatik seçilir, F9 ilə dəyişir | Claude | Sahibin iki kompüteri var |
| 2026-09-24 | Əsas mexanika: **Yaddaş Yanğını**. Hər od gücü bir xatirəni yandırır | Claude | Unikal xüsusiyyət (USP) |
| 2026-09-24 | 3D personajlar: KayKit Adventurers + Skeletons (CC0). Ayxan kapüşonlu Rogue modelidir, paltarı al-qırmızıya boyanıb, əlində cəngavər qılıncı var. Rüfət dəbilqəli Knight, Kül Kölgələri isə skeletlərdir | Sahib icazə verdi, seçim Claude-undur | Pulsuz, hazır animasiyalıdır. "Külün altından qalxan ölülər" hekayəyə uyğundur. Barbarian modeli gələcəkdə Əşrəf bəy üçün saxlanılır |
| 2026-09-24 | Səs və musiqi kodla sintez olunur, xaricdən endirilmir. Musiqi muğam ruhundadır: Şur məqamı, tar, kamança, nağara, 6/8 | Claude | Unikal kimlik, lisenziya problemi yoxdur, istənilən vaxt yenidən yaradıla bilir |
| 2026-09-24 | Döyüş hissi: 3 zərbəli kombo, zərbəyə görə hitstop, kamera "yumruğu", zərbə rəqəmləri, düşmən hücumundan əvvəl xəbərdarlıq halqası, dalğanın son düşməni öldükdə yavaş çəkiliş | Claude | Sahibin tələbi: "hiss edim ki, döyüşürəm" |
| 2026-09-24 | Düşmənin üstündə zərbə rəqəmi yox, can zolağı göstərilir. Rəqəmlər parametrlərdə seçim kimi qalır (default: bağlı) | Sahib | "Rəqəm gözü yorur" |
| 2026-09-24 | Mühit: KayKit Dungeon Remastered + Halloween Bits (CC0). Tint və hisə batma şeyderi ilə "yanmış" görünüş verilir. Taxt, krater və effektlər isə kodla qalır | Sahib icazə verdi, seçim Claude-undur | Primitiv formalar əvəzinə detallı xarabalıq |
| 2026-09-24 | Baş menyu, fasilə (Esc/P), parametrlər (`user://settings.cfg`-də saxlanılır), Musiqi/SFX səs kanalları. Esc artıq oyunu bağlamır | Claude | M3 məqsədi |
| 2026-09-24 | Balans: eyni anda ən çox 2 hücum edən düşmən (hücum növbəsi) | Claude | Kütlə halında hücumlar ədalətsiz olurdu |
| 2026-09-24 | Ekranın solundakı xatirə yazıları silindi. Yerinə can zolağının altında 6 köz ikonu var, mətnlər jurnala (Tab) köçürüldü | Sahib | "Çox pis görünür" |
| 2026-09-24 | Qılınc səsi yenidən sintez olundu: 0.22 saniyəlik rezonanslı "şşing" və polad cingiltisi (köhnəsi küləyə bənzəyirdi) | Sahib | Döyüş hissi |
| 2026-09-24 | Satqın sistemi: 8 şübhəli × 3 unikal iz, Kül əks-sədaları, jurnal, checkpoint əsaslı yadda saxlama (`user://save.json`). Ölümdən sonra oyun son checkpoint-dən davam edir | Claude | M4 |
| 2026-09-24 | Fəsil 2 (Son Ocaq): bütün fəsillər üçün ortaq `chapter_base.gd`, ayrıca `chapter2.tscn` səhnəsi. Mage və Rogue modelləri endirildi (CC0). Hər şübhəli model + rəng dəyişməsi ilə fərqlənir | Sahib icazə verdi, dizayn Claude-undur | Fəsillər arası keçid, vahid kod bazası |
| 2026-09-24 | Səhv ittihamın real nəticəsi var: günahsız sürgün edilir, satqın qaçır, son dəyişir | Claude | Qərarlar mənalı olmalıdır |
| 2026-09-24 | **V2 konsepsiyası** (`docs/SPEC_V2.md`): detektiv/satqın sistemi tam silindi. Mərkəzdə artıq Yaddaş Yanğını, bağlar, ocaqların müdafiəsi və Kölgə Ayxan dayanır. İş 6 fazada aparılır | Sahib | Yeni dizayn istiqaməti |
| 2026-09-24 | V2 Faza 1: `conspiracy.gd` və `interrogation.gd` silindi. NPC məlumatları `survivors.gd`-yə, kralın əks-sədaları `king_echoes.gd`-yə keçdi. Save versiyası 3 oldu | Claude | Spec Faza 1 |
| 2026-09-24 | Layihə qovluğu: `Documents/games/ashes-of-the-crown` (boşluqsuz). Godot isə `Documents/games/_tools/godot` qovluğundadır | Claude | Köhnə `ashes-of-the crown` qovluğu başqa proqram tərəfindən açıq idi, adını dəyişmək mümkün olmadı. O qovluq boşdur, silinə bilər |
| 2026-09-24 | **V3 konsepsiyası:** açıq dünya, fazalar A→H. Hər faza ayrıca branch-da aparılır, faza bitəndə oyun işlək qalır. Faza C-dən sonra "əyləncə qapısı" sualları üçün dayanılır | Sahib | Yeni spec |
| 2026-09-24 | V3 məzmunu data-driven qurulur: `data/balance`, `data/weapons`, `data/enemies` altında JSON fayllar, `DataDB` autoload | Claude | Balans kodu dəyişmədən tənzimlənir |
| 2026-09-24 | V3 Faza A döyüş nüvəsi: arxadan kamera (SpringArm, lock-on), stamina, input buferi, yayınma, blok/parry, duruş (stance) qırılması, infaz, nar şərbəti (4 dəfə), 3 silah (qılınc, qılınc+qalxan, gürz), Utility AI düşmənləri, hücum token büdcəsi 3 | Claude | Souls tipli dərin döyüş |
| 2026-09-24 | Test düşmənləri: Kül Kölgəsi (KayKit skelet), Qalxanlı quldur (Barbarian), Canavar (Quaternius Wolf, CC0). Canavar 2.1 m "kül canavarı"dır, közlü örtüyü var | Claude | Fərqli döyüş ritmləri |
| 2026-09-24 | Quaternius CC0 paketləri (heyvanlar, silahlar, RPG əşyaları, təbiət, kənd, survival) endirildi: `assets/quaternius/` | Sahib icazə verdi (bütün fazalar üçün) | Açıq dünya üçün məzmun |
| 2026-09-24 | Bütün PC düymələri dəyişdirilə bilir (Parametrlər → Düymələr, `user://input.cfg`). Toqquşma olanda düymələr yerini dəyişir. Gamepad tam dəstəklənir | Claude | Spec tələbi |
| 2026-09-24 | Avtomatik döyüş testi: `--demo=arena_selftest` (19 yoxlama). Animasiya yoxlaması: `tools/check_anims.gd` | Claude | Hər fazada regressiyanı tutmaq üçün |
