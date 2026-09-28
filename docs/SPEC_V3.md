# ASHES OF THE CROWN: V3, açıq dünya spec-i

> **Claude Code üçün təlimat:**
> 1. Bu sənəd V2-nin (`ASHES_V2_SPEC.md`) üzərinə gəlir. V2 sistemləri **saxlanılır** (xatirələr, alınmış xatirələr, bağ, ocaq müdafiəsi, Kölgə Aras) və açıq dünyaya uyğunlaşdırılır (bölmə 11).
> 2. Kod yazmazdan əvvəl layihəni oxu və arxitektura planı hazırla: qovluq strukturu, əsas sinif/node-lar, data formatları. Plan təsdiqlənmədən başlama.
> 3. **Fazalarla işlə** (bölmə 14). Hər faza ayrıca branch/commit olsun və oyun işləyir vəziyyətdə qalsın. **Faza C-dən sonra dayan**: bu, "əyləncə qapısı"dır.
> 4. **Data-driven yaz.** Silahlar, düşmənlər, bacarıqlar, hadisələr, tapşırıq şablonları `.tres`/JSON data fayllarında olsun, kodda hardcode olmasın. Bütün balans rəqəmləri `balance/` qovluğunda saxlanılsın.
> 5. Oyundakı bütün mətnlər Azərbaycan dilindədir. Bütün idarəetmə düymələri parametrlərdən dəyişdirilə bilsin. Gamepad dəstəyi də olsun.
> 6. Performans hədəfi: orta PC-də 1080p, 60 FPS. Hər fazanın sonunda F3 profilini yoxla və nəticəni hesabata yaz.

---

## 1. Konsepsiya

Atəşan Səltənəti Kül Gecəsindən sonra açıq dünyaya çevrilir. Aras yanmış Közqaladan çıxır. Sağ qalanları toplayır, bölgələri Kül Şahının kölgələrindən, quldurlardan və oyanmış əfsanəvi varlıqlardan azad edir, ordu qurur. Döyüşdükcə güclənir, amma ən böyük gücü yenə xatirələrinin hesabına gəlir.

**Dizayn sütunları:**
1. **Döyüş dərindir:** stamina, stance, parry, infaz. Hər düşmən tipi fərqli yanaşma tələb edir.
2. **Dünya sıxdır:** hər 150–200 m-də maraqlı bir şey olur, hər nöqtədən ən azı bir orientir görünür.
3. **Dünya canlıdır:** NPC-lərin gün rejimi, reaksiyaları, yaddaşı var. Hadisələri Hekayəçi idarə edir.
4. **Güc qazanılır:** səviyyə, silah ustalığı, bacarıq ağacı, bossdan qazanılan bacarıqlar, ordu.
5. **Hər gücün qiyməti var:** xatirələr.
6. **Kimlik:** Azərbaycan və türk folkloru, Qafqaz və İpək Yolu təbiəti, muğam.

---

## 2. Kamera və hərəkət

- **Kamera:** üçüncü şəxs, çiyin arxasından (SpringArm3D, divarla toqquşmada kamera yaxınlaşır). Siçan ilə sərbəst fırlanma.
  - Lock-on rejimində kamera oyunçu ilə hədəf arasında balanslaşır.
  - Döyüşdə geri çəkilir (FOV və məsafə artır), dialoqda kinematoqrafik yaxın plan qalır.
  - Köhnə yuxarıdan baxan kamera silinir.
- **Hərəkət:**
  - Yeriş/qaçış (analog sürət), sprint (Shift, stamina −10/s)
  - Tullanma (sprint zamanı Space, və ya ayrıca düymə)
  - Aşağı enmə və kiçik maneələrin üstündən keçmə (vault, 1 m-ə qədər)
  - Üzmə: stamina −6/s, stamina bitəndə can itir, üzərkən silah istifadə olunmur
  - Yamaclar: 40°-dən dik yamacda sürüşmə
  - Düşmə zərəri: 6 m-dən yuxarı hündürlükdən düşəndə, 15 m-də ölüm
- **Minik (Faza G):** Qarabağ atı (H ilə çağırılır). Yeriş, çapma, stamina ilə sürətlənmə. Atdan sadə yan zərbə vurmaq olur.

---

## 3. Döyüş sistemi (Souls-lite)

### 3.1 İdarəetmə (dəyişdirilə bilən)
| Düymə | Hərəkət |
|---|---|
| Sol klik | yüngül zərbə (kombo zənciri) |
| F (basılı saxlamaq = yüklənmə) | ağır zərbə |
| Sağ klik (basılı) | blok. Blokun ilk 0.15 s-si parry pəncərəsidir |
| Space | Kül addımı (yayınma) |
| Q qısa / Q basılı | köz bacarığı / radial menyu və Alov Dalğası (V2) |
| 1–4 | bacarıq slotları |
| C / siçan çarxı | lock-on / hədəfi dəyişmək |
| R | nar şərbəti içmək |
| T (basılı) | ordu komanda çarxı |
| V (basılı) | Köz baxışı (bölmə 8.4) |
| E | danışmaq, toxunmaq, infaz |
| Tab / M | jurnal / xəritə |

### 3.2 Stamina
- Baza 100-dür (Dözüm atributu artırır). Bərpası 35/s-dir, son hərəkətdən 0.6 s sonra başlayır. Stamina tam boşalıbsa, 1.2 s "yorğunluq" olur və bərpa yarı sürətlə gedir.
- Xərclər: yüngül zərbə 12, ağır zərbə 25 (tam yüklənmiş 35), yayınma 20, blokda qarşılanan zərbə (zərərin 50%-i, qalxanla 30%-i), uğurlu parry 0.
- Stamina çatmayanda hərəkət başlamır (buffer-də gözləyir).

### 3.3 Stance (poise) və infaz
- Hər düşmənin **stance zolağı** var (can zolağının altında, nazik, qızılı rəngdə).
- Zərbələr stance zərəri vurur: yüngül ×1, ağır ×2.5, yüklənmiş ×4, uğurlu parry +40% maksimum stance.
- Stance 3 s zərbə almayanda saniyədə 15% azalır.
- **Stance qırılanda:** düşmən 2 s yerə çökür, üstündə "E" işarəsi çıxır. **Köz İnfazı** normal zərərin 250%-ini vurur. Kinematoqrafik qısa animasiya olur, kamera yaxınlaşır, hitstop artır. İnfaz zamanı oyunçu toxunulmazdır.
- Oyunçunun da stance-i var (gizli, 100). Ağır zərbənin başlanğıc animasiyasında "hyper armor" olur, kiçik düşmənlər onu kəsə bilmir.

### 3.4 Parry
- Blokun ilk 0.15 s-si parry pəncərəsidir (qalxanla 0.2 s). Uğurlu parry: düşmən 1.2 s çaşır, stance +40% dolur, kiçik yavaş çəkiliş (0.15 s, timescale 0.4) olur, metal "cingilti" səsi və qığılcım effekti çıxır.
- Parry edilə bilməyən hücumlar (böyük varlıqlar, bəzi boss zərbələri) **qırmızı parıltı** ilə göstərilir, onlardan yalnız yayınmaq olar.
- V2-dəki mükəmməl yayınma saxlanılır.

### 3.5 Silahlar (data-driven moveset)
| Silah | Xarakter | Zərər növü | Yüngül kombo | Xüsusiyyət |
|---|---|---|---|---|
| **Qılınc** | balanslı | Kəsici | 4 zərbə | ən sürətli bərpa |
| **Qılınc və qalxan** | müdafiə | Kəsici | 3 zərbə | güclü blok, parry 0.2 s, qalxan zərbəsi (stance) |
| **Gürz** (iki əlli) | ağır, yavaş | Əzici | 3 zərbə | böyük stance zərəri, geniş qövs |
| **Nizə** | məsafə | Deşici | 4 zərbə (dürtmə) | uzun məsafə, zirehə qarşı yaxşıdır |
| **Yay** (Faza D) | uzaq məsafə | Deşici | – | nişan almaq (sağ klik ilə, yay seçiləndə), stamina ilə dartmaq |

Hər silahın yüngül kombosu, ağır və yüklənmiş zərbəsi, qaçaraq zərbəsi, yayınmadan sonrakı zərbəsi və ustalıqla açılan xüsusi hərəkətləri (bölmə 5.3) var. Silahı 1–4 slotlarından birinə təyin etmək, ya da inventardan dəyişmək olur.

### 3.6 Zərər növləri və statuslar
- Növlər: **Kəsici, Əzici, Deşici, Od.** Hər düşmənin müqavimət cədvəli var:
  - Kül kölgələri oda müqavimətlidir (−50%), əziciyə zəifdir (+30%)
  - Zirehli quldurlar kəsiciyə müqavimətlidir, deşiciyə zəifdir
  - Heyvanlar kəsiciyə zəifdir
  - Bu, silah seçiminə məna verir.
- Statuslar (bar dolanda işə düşür): **Yanma** (5 s ərzində zərər), **Qanaxma** (maksimum canın 15%-i ani zərər), **Sersemləmə** (stance-ə bonus), **Donma** (dağlarda: yavaşlama, stamina bərpası −50%), **Zəhər** (Şahmaran, bataqlıq).

### 3.7 Zərbə hissi
- Hitstop silahın ağırlığına görə dəyişir: qılınc 0.05 s, gürz 0.09 s, infaz 0.15 s.
- İstiqamətli zərbə reaksiyaları: düşmən zərbə gəldiyi tərəfə əyilir. Kiçik düşmənlər ağır zərbədən yerə yıxılır (ragdoll lazım deyil, "knockdown" animasiyası kifayətdir).
- Kamera silkələnməsi zərbənin gücünə və istiqamətinə uyğun olur.
- Qan əvəzinə köz və kül hissəcikləri çıxır (üslub).

### 3.8 Müalicə və ölüm
- **Nar şərbəti** (Estus analoqu): başlanğıcda 4 dəfə, hər biri canın 40%-ini bərpa edir. İçmə animasiyası 0.9 s çəkir və oyunçu bu zaman həssasdır. Ocaqda yenidən dolur. Tapılan "nar toxumu" ilə sayı 10-a qədər artırılır.
- **Ocaqlar** (Elden Ring-dəki "Site of Grace"-in analoqu): dincəlmək, şərbəti doldurmaq, səviyyə xallarını paylamaq, sürətli səyahət. **Dincələndə** boss olmayan düşmənlər yenidən doğulur.
- **Ölüm:** oyunçu son ocaqda qalxır. Xərclənməmiş gümüş ölüm yerində **"kül ləkəsi"** kimi qalır. Oyunçu ora çatsa geri götürür, yolda yenə ölsə gümüş itir.

---

## 4. Düşmənlər

### 4.1 AI arxitekturası
- **Utility AI:** hər düşmən hər 0.2–0.4 s bütün mümkün hərəkətlərini qiymətləndirir və ən yüksək xallı olanı seçir. Hərəkətlər: yaxınlaşmaq, hücum növləri, geri çəkilmək, dövrə vurmaq, blok, qaçmaq, kömək çağırmaq, qaçmaq (morale). Qiymətləndirmə meyarları: məsafə, öz canı və stamina-sı, oyunçunun vəziyyəti (hücumda, müalicədə, yıxılıb, blokda), müttəfiqlərin sayı, hücum tokeninin olub-olmaması, cooldown-lar.
- **Hücum tokenləri** (V1-dəki "ən çox 2 hücumçu"nun ümumi versiyası): hər hədəfin token büdcəsi var (oyunçu üçün 3). Adi düşmən 1, elit 2, boss 3 token tutur. Tokeni olmayan düşmən dövrə vurur, mövqe dəyişir, oxçular atəş açır.
- **Cəzalandırma:** oyunçu şərbət içəndə və ya stamina-sı bitəndə aqressiv tiplərin hücum xalı ×1.5 olur.
- **Adaptiv AI** (yalnız elitlər və bosslar): oyunçunun son 60 s-dəki müdafiə vərdişləri qeydə alınır (yayınma, blok, parry, məsafədə qalmaq). Ən çox istifadə olunana qarşı cavab çəkisi artır:
  - yayınma spam-ı → gecikdirilmiş zərbələr, geniş süpürmə
  - blok → qalxan qıran zərbə (stamina-nı birbaşa boşaldır)
  - parry → yalançı hərəkət (feint), parry edilməyən zərbə
  - məsafə → sıçrayış hücumu, uzaq məsafəli hücum
- **Algılama:** görmə konusu (120°, 25 m, gecə və dumanda 12 m), eşitmə (sprint 15 m, döyüş səsi 30 m). Vəziyyətlər: sakit → şübhəli (sarı işarə) → döyüş (qırmızı). Oyunçu itəndə 8 s axtarış olur, sonra düşmən geri qayıdır.
- **Qrup taktikası:** canavarlar və quldurlar yandan dolanır (flanking), qalxanlılar öndə dayanır, oxçular yüksək yer və məsafə axtarır, şaman arxada qalır.
- **AI LOD:** 40 m-ə qədər tam AI, 40–120 m-də sadələşdirilmiş (hər 1 s qərar, animasiya LOD), 120 m-dən uzaqda dondurulmuş (patrullar sxematik simulyasiya olunur).

### 4.2 Fraksiyalar və tiplər
**Kül Kölgələri** (ölülər, gecə +20% güclü olurlar):
- Adi kölgə, sürətli kölgə, Kül Cəngavəri (V2)
- **Kül Oxçusu:** məsafə saxlayır, alovlu ox atır
- **Partlayan Kül:** yaxınlaşıb partlayır, 2 s telegrafı var
- **Kül Şamanı:** ölmüş kölgələri 1 dəfə diriltir, qalxan verir, prioritet hədəfdir
- **Kül Nəhəngi** (elit, 3 m): parry edilməyən zərbələr, yeri silkələyir

**Quldurlar/Qaçaqlar** (insanlar):
- Qılınclı, qalxanlı, oxçu, nizəçi, ataman (elit, ətrafdakılara buff verir)
- Morale sistemi: canı az qalanda qaçır, bəzən **təslim olur** (silahı yerə atır). Təslim olanı öldürmək, buraxmaq və ya **orduya almaq** olar (bölmə 7.1).

**Vəhşi heyvanlar:**
- Canavar (sürü, yandan dolanır, 4–6 başlıq), ayı (tank, ayağa qalxıb zərbə vurur), çöl donuzu (hücum qaçışı, yayınmaqla keçilir), **Qafqaz bəbiri** (mini-boss, gizlənir, sıçrayır)
- Heyvanlar ərazi davranışı göstərir: xəbərdarlıq nəriltisi verir, uzaqlaşsan hücum etmir.

**Əfsanəvi varlıqlar** (Azərbaycan və türk folkloru):
- **Albastı** (Hirkan meşəsi, gecə): görünməz olur, yalançı səs çıxarır, kopiyalar yaradır
- **Su Anası** (Mavi Göl): sudan hücum edir, oyunçunu suya çəkir
- **Div** (Neft Çölü): nəhəng, qaya atır, yaralananda qəzəblənir
- **Təpəgöz** (Qartal Dağlarının ətəyi): tək göz zəif nöqtədir (lock-on göz nöqtəsinə), qoyun sürüsü mexanikası (Dədə Qorqud-a işarə)
- **Şahmaran** (dağ mağarası): ilan bədəni, zəhər, iki fazalı boss. Hekayə seçimi var: öldürmək və ya sirrini saxlamaq
- **Əjdaha** (Faza G, dünya bossu): uçur, od püskürür, Kül Şahı ilə bağlıdır

### 4.3 Səviyyələr
- Oyunçunun səviyyə həddi hələlik 30-dur. Düşmən səviyyəsi **bölgəyə bağlıdır, oyunçuya uyğunlaşmır.** Güclü yerə erkən girmək təhlükəlidir, geri qayıdanda isə güclənmək hiss olunur.
- Formullar:
  - `HP = baza × (1 + 0.12 × (L−1))`
  - `zərər = baza × (1 + 0.08 × (L−1))`
  - `XP = baza × L × clamp(1 + 0.1 × (L_düşmən − L_oyunçu), 0.2, 2.0)`
- Düşmən oyunçudan 5+ səviyyə yuxarıdırsa, adının yanında **kəllə ikonu** görünür. Rəqəm göstərilmir.

### 4.4 Elit affikslər (prosedur müxtəliflik)
Adi düşmənin 6%, elitin 30% ehtimalla 1–2 affiksi olur. Affiksli düşmənin adı rəngli görünür və prefiksli olur ("Alovlu Sürətli Canavar"):
- **Alovlu:** arxasında yanan iz qoyur, zərbəsi yanma vurur
- **Qalın:** +60% can, +50% stance
- **Sürətli:** +25% sürət və hücum sürəti
- **Çağıran:** canı 50%-ə düşəndə 2 köməkçi çağırır
- **Qisasçı:** ölərkən 2 s sonra partlayır
- **Sarsılmaz:** ilk stance qırılmasına toxunulmazdır
- **Kül Şahının gözü:** oyunçunu hər zaman görür, qaçmaq olmur
- Affiksli düşmən 2 dəfə XP və yaxşı qənimət ehtimalı verir.

### 4.5 Bosslar
- Hər bölgədə 1 sahə bossu və 1–2 mini-boss var (bölmə 9).
- Bossların 2–3 fazası, dumanlı giriş qapısı (arenaya giriş), musiqi dəyişikliyi və ekranın aşağısında boss zolağı var.
- Öldürülən boss **Köz Ruhu** verir: yeni aktiv bacarıq (bölmə 5.5).

---

## 5. İnkişaf (progression)

### 5.1 Səviyyə və atributlar
- `XP_növbəti = 100 × L^1.5`. Hər səviyyədə **2 atribut xalı** və **1 bacarıq xalı** verilir (hər 5-ci səviyyədə 2 bacarıq xalı).
- Xallar ocaqda paylanır.
- Atributlar:
  - **Güc:** ağır və əzici zərər, daşıma
  - **Çeviklik:** yüngül və deşici zərər, stamina bərpası
  - **Dözüm:** can (+8/xal), stamina (+4/xal)
  - **Od:** köz qazanma, od zərəri
  - **Nüfuz:** ordu limiti, morale, NPC reaksiyaları

### 5.2 Bacarıq ağacı (3 qol, MVP-də hərəsində 10 düyün)
- **Qılınc yolu:** kombo uzadılması, stance zərəri +%, parry pəncərəsi +0.03 s, parrydan sonra avtomatik əks-zərbə, infaz zərəri +%, ikinci yayınma (stamina ilə)
- **Od yolu:** köz qazanma +%, yeni köz bacarıqları:
  - *Alov Qalxanı:* 3 s ərzində zərərin 50%-ini udur
  - *Köz Mızrağı:* uzaq məsafəli atış
  - *Kül Pərdəsi:* yayınma qısa teleporta çevrilir
  - *Yanar Silah:* 10 s ərzində silaha od zərəri əlavə edir
- **Sərkərdə yolu:** ordu limiti +2, morale +, əsgər XP-si +%, *Döyüş nərəsi* (yaxındakı müttəfiqlərə +20% zərər, morale bərpası), *Od bayrağı* (yerə sancılan bayraq, ətrafında müttəfiq sağalır), formasiya bonusları

### 5.3 Silah ustalığı ("döyüşdükcə öyrənirsən")
- Hər silah növünün ustalığı 1–5 arasındadır. Yalnız **oyunçudan ən çox 3 səviyyə aşağı olan** düşmənlərə dəyən zərbələr sayılır (zəif düşmənləri farm etməyə qarşı).
- Hədlər: 50 / 150 / 350 / 700 / 1200 dəyən zərbə.
- Hər ustalıq səviyyəsi yeni hərəkət açır. Məsələn, qılınc:
  - 2: 4-cü kombo zərbəsi
  - 3: "Burulğan" (ağır zərbədən sonra fırlanma)
  - 4: parrydan sonra ani infaz
  - 5: "Köz kəsiği" (yüklənmiş zərbə dalğa kimi uçur)
- Hər silah üçün 5 hərəkət data faylında təyin edilir. Yeni hərəkət açılanda ekranda qısa bildiriş çıxır və jurnalda animasiyalı təsviri görünür.

### 5.4 Avadanlıq və hazırlama (craft)
- Slotlar: silah ×2, baş, gövdə, əllər, ayaqlar, 2 üzük/tilsim.
- Keyfiyyət: Adi, Yaxşı, Nadir, Əfsanəvi. Qənimət **Diablo kimi çox deyil, Witcher səviyyəsindədir**: az, amma mənalı.
- Dəmirçi (Son Ocaqda və kəndlərdə): materiallarla (dəmir, dəri, köz daşı, varlıq hissələri) silahı +1…+10 gücləndirmək və zireh hazırlamaq olur.

### 5.5 Köz Ruhları (bossdan bacarıq)
Hər boss bir aktiv bacarıq verir və o, 1–4 slotlarından birinə qoyulur:
- Qafqaz bəbiri → *Bəbir sıçrayışı* (hədəfə sıçrayış hücumu)
- Su Anası → *Dalğa* (düşmənləri geri itələyir)
- Təpəgöz → *Yer silkinməsi* (ətrafa stance zərəri)
- Div → *Div nərəsi* (düşmənləri qorxudur, morale azaldır)
- Şahmaran → *Zəhərli dişlər* (silaha zəhər)
- Albastı → *Kölgə surəti* (3 s ərzində düşmənləri çaşdıran surət)

---

## 6. Dünya

### 6.1 Ölçü və texnologiya
- Arxitektura 4×4 km-ə qədər genişlənə bilən qurulur. **Faza B** 512×512 m-lik slice-dır, **Faza G** 2×2 km-dir.
- **Terrain:** əvvəlcə **Terrain3D** (GDExtension) addonunun Godot versiyası ilə uyğunluğunu yoxla. Uyğun deyilsə, öz chunk-lı terrain sistemini yaz (64 m chunk, 4 LOD səviyyəsi).
- **Generasiya kodla aparılır:** makro forma (dağ silsilələri spline, çay spline, göl mərkəzləri, biom idarəetmə nöqtələri) `world/world_layout.json` faylında təsvir olunur. Generator skripti noise qatları ilə hündürlük xəritəsini hesablayır, çay yataqlarını və gölləri oyur, biom maskalarını çıxarır. Nəticə resource kimi saxlanılır. Beləcə dünyanın "mənbəyi" mətn faylı olaraq qalır.
- **Streaming:** 128 m hüceyrələr (cell). Oyunçu ətrafındakı 3×3 hüceyrə tam yüklənir, 5×5 LOD ilə. Yükləmə arxa planda (threaded) aparılır.
- **Bitki örtüyü:** MultiMeshInstance3D. Ağac, kol və ot biom maskasına görə səpilir (Poisson disk). Otun sıxlığı məsafə ilə azalır. Otlar oyunçunun ayağı altında əyilir (shader).
- **Su:** göl və çay üçün shader. Çay axın istiqaməti spline-dan götürülür, sahil köpüyü, dərinliyə görə rəng. Üzmək mümkündür.
- **Gecə-gündüz dövrü:** 24 oyun saatı = 24 real dəqiqə. Günəş, ay və ulduzlar var. Gecə düşmənləri güclənir, NPC-lər evə çəkilir.
- **Hava:** biomdan asılıdır. Yağış, duman (meşə), qar (dağ), qum-kül fırtınası (çöl), Kül fırtınası (xüsusi hadisə: görmə azalır, kölgələr çoxalır).

### 6.2 Bölgələr (tam versiya)
| Bölgə | Təsvir | Səviyyə | Əsas düşmənlər | Boss |
|---|---|---|---|---|
| **Közqala** | yanmış paytaxt, Fəsil 1 (xətti tutorial) | 1–3 | Kül kölgələri | Kül Cəngavəri |
| **Kür Vadisi** | mərkəzi çay, kəndlər, dəyirmanlar, körpülər, tarlalar, Son Ocaq karvansarası | 2–8 | quldurlar, canavarlar, kölgələr | Quldur atamanı |
| **Hirkan Meşəsi** | cənub, sıx relikt meşə, duman, qədim ağaclar | 5–12 | canavar, ayı, Albastı | Qafqaz bəbiri |
| **Mavi Göl** | dağ ətəyində göl, şəlalə, balıqçı kəndi | 8–14 | Su ruhları, quldurlar | Su Anası |
| **Neft Çölü** | şərq, yarımsəhra, yanan qaz çıxışları (Yanardağ), palçıq vulkanları, qayaüstü təsvirlər | 12–20 | Div, çöl quldurları, Kül nəhəngləri | Div |
| **Qartal Dağları** | şimal, qarlı zirvələr, qədim atəşgah, dağ kəndi | 16–26 | Təpəgöz, dağ kölgələri | Şahmaran (mağara) |
| **Batmış Liman** | cənub-şərq, Xəzər sahili, suya batmış liman şəhəri | 22–30 | Kül dənizçiləri | Kül Admiralı |

### 6.3 Sıxlıq qaydaları (dizaynın ən vacib hissəsi)
- Xəritənin istənilən nöqtəsindən 150–200 m radiusda ən azı 1 maraqlı nöqtə (POI) olmalıdır.
- Hər nöqtədən ən azı 1 **orientir** görünməlidir: atəşgahın alovu, palçıq vulkanının tüstüsü, nəhəng çinar, qala qülləsi, Kül Şahının göydəki közü.
- POI növləri: kənd, qala/düşərgə (azad edilə bilən), mağara/zindan (kiçik, 5–10 dəqiqəlik), xarabalıq, ocaq (sürətli səyahət), əks-səda (lore), xəzinə, heyvan yuvası, tapmaca (məsələn, köz sütunlarını düzgün sıra ilə yandırmaq), tacir, nar bağı (nar toxumu), boss arenası.
- **Yerləşdirmə generatoru:** POI-lər `world/poi_rules.json` qaydaları ilə yerləşdirilir (biom, yamac, sudan məsafə, POI-lər arasında minimum məsafə). Əsas POI-lər (bosslar, hekayə məkanları) isə əllə, koordinatla verilir.
- **Yol şəbəkəsi:** kəndlər arasında A* ilə terrain üzərində yol çəkilir və yol teksturası tətbiq olunur. Yollar NPC-lər, karvanlar və patrullar üçün də istifadə olunur.

### 6.4 Asset mənbələri (hamısı CC0)
- KayKit: Adventurers, Skeletons, Forest Nature, Dungeon
- Quaternius: Ultimate Nature, Animated Monsters, Universal Animation Library
- Kenney: Nature Kit
- Poly Haven: terrain teksturaları
- Əfsanəvi varlıqlar üçün uyğun model tapılmasa, mövcud modellərdən miqyas, rəng və shader dəyişikliyi ilə törəmə düzəlt. Məsələn, Təpəgöz böyüdülmüş trol modelinə tək göz əlavə etməklə alınar.
- Başlıqlar (papaq, çalma) V2-dəki kimi qalır.
- **Animasiya ən böyük darboğazdır.** Hər silah üçün lazım olan animasiyaların siyahısını Faza A-nın əvvəlində çıxar, çatmayanları qeyd et və əvəzedici həll təklif et (animasiya retargeting və ya prosedur animasiya).

---

## 7. Ordu sistemi

### 7.1 Əsgər toplamaq
- Mənbələr:
  - azad edilmiş kəndlərdən könüllülər
  - təslim olmuş quldurlar (aşağı başlanğıc morale, sadiqlik yavaş artır)
  - Son Ocaqda və düşərgələrdə muzdlular (gümüşlə)
  - dinamik hadisələrdə xilas edilən yaralı əsgərlər
- **Sərkərdələr:** Son Ocağın 8 personajı bağ ≥ 75 olanda sərkərdəyə çevrilir. Onlar qəhrəman bölmə kimi döyüşür, unikal bacarıqları olur və ölmürlər (yaralanıb Son Ocağa qayıdırlar):
  - Rüfət: *Cangüdən* (oyunçuya gələn zərbələrin 20%-ni öz üzərinə götürür)
  - Şahbaz: *Nizam* (formasiyada +25% müdafiə)
  - Əşrəf: *Dağ pusqusu* (dəstə görünməz yaxınlaşır)
  - İbrahim: *Kükürd bombası* (sahəyə zərər)
  - Əhliman: *Dua* (sahədə sağaltma)
  - Anar: *Karvan* (ordunun gündəlik xərci −30%)
  - Sabir: *Kəşfiyyat* (xəritədə düşmən patrulları görünür)
  - Elvin: *Kral bayrağı* (morale +)

### 7.2 Bölmə tipləri və inkişaf
| Tip | Rol | Tier 1 → 3 |
|---|---|---|
| Milis | ucuz, zəif | Kəndli → Müdafiəçi |
| Piyada | qılınc və qalxan | Əsgər → Veteran → Cəngavər |
| Nizəçi | ağır düşmənə və qaçışa qarşı | Nizəçi → Mızraqçı → Qala mühafizi |
| Oxçu | uzaq məsafə | Ovçu → Oxçu → Kamandar |
| Ağır piyada | gürz, stance qırmaq | Gürzçü → Pəhləvan |

- Əsgərlər döyüşdə XP qazanır. Tier artırmaq üçün XP və gümüş lazımdır, bu Son Ocaqdakı təlim meydanında edilir.
- Ölən əsgər qalıcı olaraq itir. Veteranları itirmək ağrılı olmalıdır.

### 7.3 Komandalar
- **T (basılı): komanda çarxı**
  - Arxamca gəl
  - Burada dayan (nişan alınan nöqtə)
  - Hücum et (hamı)
  - Mənim hədəfimə hücum (lock-on hədəfi)
  - Geri çəkil
  - Formasiya: Sıra / Qalxan divarı / Səpələnmiş
- Sürətli düymələr F1–F5.
- **Formasiya:** slotlar lider mövqeyinə görə hesablanır. Terrain maneələrində slot ən yaxın keçilə bilən nöqtəyə sürüşür. Hərəkət NavigationAgent3D ilə, avoidance aktiv halda aparılır.
- Əsgərlər də bölmə 4.1-dəki eyni Utility AI-dən istifadə edir (müttəfiq fraksiya ilə).

### 7.4 Morale
- Hər əsgərin morale-i 0–100-dür.
- Azalır: yaxında müttəfiq öləndə (−8), canı az olanda, nəhəng düşmən görünəndə (−15), sərkərdə yaralananda.
- Artır: oyunçu yaxında düşmən öldürəndə (+3), infaz edəndə (+8), Döyüş nərəsi, Kral bayrağı, Alov Dalğası (+20, "Arasın odu").
- Morale < 20 olanda əsgər qaçır. Döyüş nərəsi ilə yenidən toplanır.
- Düşmən insanların da morale-i var. Atamanı öldürmək bütün dəstəni sarsıdır.

### 7.5 Limitlər və təchizat
- Sahədəki ordu: 4 + Nüfuz + Sərkərdə bacarıqları, **maksimum 20**. Artıq əsgərlər qarnizonlarda qalır.
- Gündəlik xərc: hər əsgər üçün tier-ə görə gümüş. Ödənilmirsə, morale hər gün −10 düşür.
- **Döyüş direktoru:** bir döyüşdə eyni anda ən çox 40 aktiv döyüşçü olur. Artığı dalğalarla gəlir. Əsgərlər "duel cütləşməsi" ilə düşmənlərlə cüt-cüt eşləşir ki, izdiham xaosu olmasın.

### 7.6 Qalaları azad etmək
- Hər bölgədə 2–3 quldur və ya Kül qalası var. Qalanın qarnizonu, ataman bossu və çağırılan əlavə qüvvələri olur.
- Azad edilən qala: ocaq (sürətli səyahət), əsgər toplama mənbəyi, qarnizon və bölgənin "azadlıq" xalı verir. Azad edilmiş bölgədə kəndlər canlanır, tacirlər gəlir, patrullar azalır.
- **Geri hücum:** Hekayəçi (bölmə 8.3) bir müddət sonra azad edilmiş qalaya Kül Şahının hücumunu planlaşdırır və oyunçuya xəbər verir ("Qartal qalasına kölgələr yaxınlaşır"). Oyunçu 1 oyun günü ərzində gəlməsə, qarnizon döyüşür və nəticə simulyasiya olunur. Gəlsə, **V2-dəki ocaq müdafiəsi mexanikası** işə düşür.

---

## 8. Canlı dünya və NPC-lər

### 8.1 NPC gündəlik rejimi
- Kəndlərdə NPC rolları: əkinçi, çoban, dəmirçi, tacir, keşikçi, dəyirmançı, balıqçı, çayçı. **Yalnız yetkin NPC-lər olsun.**
- Rejim data faylı ilə təyin olunur:
  - 06:00 oyanır
  - 07–12 rolunun yerində işləyir (animasiyalı)
  - 12–13 yemək
  - 13–19 iş
  - 19–22 çarasa, ocaq başında söhbət, musiqi
  - 22 yatır
- Yağışda örtülü yerə qaçır. Gecə keşikçilər məşəl yandırır.
- V2-dəki ehtiyaclar sistemi (istilik, ünsiyyət, vəzifə) Son Ocaq sakinləri üçün saxlanılır və rejimlə birləşdirilir.
- Uzaq kəndlər sxematik simulyasiya olunur: kim harada olmalıdır cədvəldən hesablanır, oyunçu gələndə NPC-lər düzgün yerdə yaranır.

### 8.2 Reaksiyalar və yaddaş
- NPC-lər döyüşü görəndə qaçır və keşikçini çağırır. Keşikçilər düşmənlə döyüşür.
- **Kənd reputasiyası** (−100…+100): kömək, tapşırıq və azadlıq artırır; oğurluq və zərər azaldır. Reputasiya salama, qiymətlərə və könüllü əsgərlərin sayına təsir edir.
- **NPC yaddaşı:** hər NPC oyunçu ilə bağlı son 5 hadisəni saxlayır ("kəndi xilas etdi", "Təpəgözü öldürdü"). Bunlar NPC-nin danışıqlarında istifadə olunur.
- **Kontekstual sətirlər (barks):** şablon + dəyişən sistemi ilə qurulur. Şərtlər: saat, hava, oyunçunun avadanlığı, ordu ölçüsü, yanmış xatirələrin sayı, son böyük hadisələr. Nümunələr:
  - "Gecə yola çıxma, oğul. Kölgələr gecə daha acdır."
  - (4+ xatirə yanıbsa) "Gözlərin... od kimi yanır. Qorxuram səndən."
  - (Div öldürülübsə) "Deyirlər, çöldəki Divi sən yıxmısan. Doğrudur?"
  - (Ordu ≥ 10) "Bu qədər əsgər... Bizi qorumağa gəlmisiniz, yoxsa aparmağa?"
- **NPC-lər arası söhbətlər:** iki NPC yaxın olanda şablon dialoqlar səslənir (subtitr kimi). Mövzular: hava, məhsul, kölgələr, oyunçunun əməlləri, kənd dedi-qodusu.

### 8.3 Hekayəçi (event director)
- **Gərginlik modeli (0–100):** döyüş intensivliyi, alınan zərər, ölümlər və son hadisədən keçən vaxt əsasında hesablanır.
  - Gərginlik yüksəkdirsə, sakit hadisələr gəlir (tacir, qaçqın, mənzərə anı, musiqiçi).
  - Aşağıdırsa və 3–5 dəqiqə heç nə olmayıbsa, döyüş hadisəsi yaranır.
- Hadisələr oyunçunun **görmə sahəsindən kənarda**, 150–400 m radiusda yaradılır. Oyunçu onları təsadüfən tapmış kimi hiss etməlidir.
- Hadisə kataloqu (`events/*.json`: şərtlər, biom, saat, çəki, cooldown):
  - karvana quldur hücumu (xilas et → gümüş və reputasiya)
  - canavarlar çobana hücum edir
  - yaralı əsgər (orduya qatıla bilər)
  - qaçqın ailə (Son Ocağa yönləndirmək)
  - gəzən tacir
  - Kül fırtınası
  - elit affiksli düşmən patrulu
  - (çox xatirə yanıbsa, gecə) Kül Şahının pusqusu: yalançı səsin arxasınca gedirsən və pusquya düşürsən
  - (azad edilmiş bölgədə) toy və ya bayram: NPC-lər rəqs edir, musiqi çalır, bufflı yemək verilir
- Eyni hadisə ardıcıl 2 dəfə təkrarlanmır. Hadisə tarixçəsi save-də saxlanılır.

### 8.4 Müqavilələr (Witcher tipli ov)
- Kənd lövhəsindən müqavilə götürülür: varlıq tipi, məkan və sübut zənciri şablonlardan yığılır.
- **Köz baxışı (V basılı):** dünya boza keçir (əks-sədalardakı effekt kimi), izlər, qan ləkələri və caynaq izləri közərir. İzləri 2–4 addım izləyib yuvanı tapırsan.
- Köz baxışı həm də düşmənin zəifliyini göstərir (müqavimət ikonları) və lore obyektlərini vurğulayır.
- Mükafat: gümüş, XP, varlıq hissəsi (craft üçün), bəzən unikal əşya.
- Əllə yazılmış müqavilələr də olur (daha dərin hekayə ilə).

### 8.5 Tapşırıqlar
- Əsas hekayə tapşırıqları əllə yazılır. Yan tapşırıqlar əllə yazılır və şablonlarla tamamlanır.
- Jurnalda aktiv tapşırıq seçilir. Marker göstərilməsi parametrdən açılıb bağlanır (default olaraq açıq). "Közqalanın küçələri" yanıbsa, marker göstərilmir (bölmə 11).

---

## 9. İqtisadiyyat (yüngül)
- Valyuta: gümüş. Mənbələri: düşmənlər, müqavilələr, xəzinələr, əşya satışı.
- Xərclər: avadanlıq, craft, əsgər xərci, tier artırma, nar şərbəti və tilsimlər.
- Qiymətlər bölgəyə və reputasiyaya görə dəyişir (±20%).

---

## 10. UI
- **HUD:** can, stamina, köz ölçüsü, 6 xatirə ikonu və alınmış xatirələr (V2), bacarıq slotları 1–4, şərbət sayı, kompas (yuxarıda, orientirlər və aktiv tapşırıq ilə), düşmən zolaqları (can və stance), boss zolağı, ordu paneli (sol aşağıda: əsgər sayı, orta morale).
- **Xəritə (M):** kəşf edilən ərazilər açılır, işarələr qoymaq olur, ocaqlardan sürətli səyahət edilir.
- **Jurnal:** V2-dəki 4 tab + Müqavilələr + Bestiarium (öyrənilən düşmənlərin zəifliyi və müqaviməti) + Ordu.
- **Bacarıq ekranı:** 3 qollu ağac, silah ustalığı, Köz Ruhları.
- Bildirişlər qısa və üst-üstə yığılan (stack) formadadır: "Qılınc ustalığı 3: Burulğan açıldı".

---

## 11. V2 sistemlərinin açıq dünyaya uyğunlaşdırılması
- **Fəsil 1 (Közqala)** xətti tutorial olaraq qalır, amma yeni döyüş sistemi ilə yenidən balanslaşdırılır. Rüfətin son sözündən ("Sağ qalanlar Son Ocaqda toplaşıb...") sonra Közqalanın darvazası açılır və dünya açılır. Son Ocağa piyada getmək lazımdır, yol ilk kəşf təcrübəsidir.
- **Fəsil 2 (Son Ocaq)** əsas hekayə bölməsi olur:
  - 8 personajın tapşırıqları dünyanın müxtəlif bölgələrinə paylanır.
  - "Gündə 3 tapşırıq" limiti ləğv olunur. Əvəzində **zaman təzyiqi** var: birinci gecə hücumu 3 oyun günü sonra, ikincisi 3 gün sonra gəlir. Səyahət vaxt aparır, ona görə hamıya çatmaq çətindir. Dilemma qalır.
  - Ocaq müdafiəsi, bağ sistemi, alınmış xatirələr və Kölgə Aras bossu olduğu kimi qalır. Kölgə Arasın hərəkətləri yeni döyüş sisteminə uyğunlaşdırılır.
- **Xatirələrin nəticələri (yenilənmiş cədvəl):**

| Xatirə | Açıq dünyada nəticəsi |
|---|---|
| Rüfətin üzü | V2 kimi (tanımamaq, kül-shader) + Rüfətin *Cangüdən* bacarığı 20% → 10% |
| Anamın adı | nar şərbətinin sağaltması 40% → 30% |
| Sabirin ilk dərsi | parry və mükəmməl yayınma pəncərələri yarıya düşür |
| Közqalanın küçələri | **xəritədə oyunçunun işarəsi və tapşırıq markerləri yox olur**, kompas yalnız şimalı göstərir |
| Atamın səsi | əks-sədalar səssiz qalır, musiqidə kamança qatı susur (V2) |
| İlk qılıncım | silah ustalığının artım sürəti −50% |

- **Hekayə genişlənməsi:** kralın əks-sədaları (V2) dünyanın hər yerinə səpələnir (cəmi 12). Hamısını tapmaq Fəsil 3-ün sirrini (kral niyə yanğını istədi) tədricən açır.

---

## 12. Səs və musiqi
- V2-dəki muğam qatları saxlanılır. Musiqi bölgəyə görə dəyişir, amma hamısı muğam ruhundadır:
  - Kür Vadisi: Şur
  - Hirkan meşəsi: Segah (sirli)
  - Neft Çölü: Çahargah (gərgin)
  - Qartal Dağları: Bayatı-Şiraz (hüznlü)
  - Batmış Liman: Rast
- Döyüş musiqisi qatlarla dinamik qalxır: düşmən sayı və boss vəziyyətinə görə nağara qatları əlavə olunur.
- Ətraf səsləri (kodla sintez): külək (hündürlüyə görə güclənir), çay (məsafəyə görə), quşlar (gündüz), cırcırama (gecə), kənd səsləri, ocaq çırtıltısı.
- Silah səsləri material və silah növünə görə fərqlənir.

---

## 13. Yadda saxlama
- Dünya vəziyyəti: öldürülən bosslar, azad edilən qalalar, açılan ocaqlar, açılmış sandıqlar, kəşf edilən xəritə, NPC statusları və reputasiya, ordu (hər əsgər: tip, tier, XP), hadisə tarixçəsi, müqavilələr, oyun vaxtı.
- Hüceyrə əsaslı "delta" saxlanılır: dəyişməyən obyektlər yazılmır.
- Avtomatik yadda saxlama: ocaqda dincələndə, bölgəyə girəndə, hər 5 dəqiqədən bir (döyüşdən kənar).
- Save versiyası artırılır. V2 save-i yeni oyuna çevrilir, Fəsil 1-in başlanğıcı saxlanılır.

---

## 14. İmplementasiya fazaları

### Faza A: Döyüş nüvəsi (test arenasında)
- Üçüncü şəxs kamera, yeni hərəkət, stamina, lock-on, yüngül/ağır/yüklənmiş zərbə, blok və parry, stance və infaz, qılınc və gürz, zərbə hissi, nar şərbəti.
- 3 test düşməni (adi kölgə, quldur qalxanlı, canavar) sadə Utility AI ilə.
- Animasiya siyahısı və çatmayanların hesabatı.
- **Qəbul:** arenada 10 dəqiqə döyüşmək əyləncəlidir. Parry və infaz aydın hiss olunur. Stamina idarəsi strategiya yaradır.

### Faza B: Dünya parçası (512×512 m)
- Terrain generatoru (JSON layout ilə), streaming, bitki örtüyü, çay və göl, gecə-gündüz, hava (yağış, duman), 1 kənd, 1 qala, 2 ocaq, sürətli səyahət, xəritə və kompas.
- **Qəbul:** 60 FPS. Uzaqdan orientir görünür. Yeriyəndə hər 150–200 m-də bir POI var. Ocaqdan ocağa səyahət işləyir.

### Faza C: Düşmən çərçivəsi
- Tam Utility AI, tokenlər, algılama, qrup taktikası, AI LOD, səviyyə formulları, affiks sistemi, adaptiv AI.
- 3 fraksiyadan cəmi 10 düşmən tipi, 1 mini-boss (Qafqaz bəbiri).
- **Qəbul:** hər düşmən tipi fərqli yanaşma tələb edir. Affikslər oyunu vizual və mexaniki olaraq dəyişir. Adaptiv AI debug overlay-də görünür (F4: oyunçu vərdişləri və AI cavab çəkiləri).

> **ƏYLƏNCƏ QAPISI.** Faza C bitəndən sonra dayan və bu sualları ver: döyüş 2 saat oynayanda əyləncəlidirmi? Dünyanı gəzmək maraqlıdırmı? Performans necədir? Cavab "yox"dursa, D-yə keçmədən düzəliş et.

### Faza D: İnkişaf sistemi
- XP və səviyyə, atributlar, bacarıq ağacı (3×10), silah ustalığı, nizə və yay, avadanlıq və qənimət, dəmirçi, Köz Ruhu mexanikası, ölüm və kül ləkəsi.
- **Qəbul:** 1–10 səviyyə arasında güclənmə hiss olunur. Hər ustalıq hərəkəti açılır və işləyir.

### Faza E: Canlı dünya
- NPC gündəlik rejimi, reaksiyalar, reputasiya, NPC yaddaşı, barks, NPC-lər arası söhbətlər, Hekayəçi və 10 hadisə, müqavilələr və Köz baxışı, Bestiarium.
- **Qəbul:** kənddə 10 dəqiqə dayananda NPC-lər rejimə uyğun hərəkət edir. Hekayəçinin gərginlik qrafiki debug overlay-də görünür (F5). Hadisələr təbii hiss olunur.

### Faza F: Ordu
- Əsgər toplamaq, 5 bölmə tipi və tier-lər, komanda çarxı, formasiyalar, morale, sərkərdələr, döyüş direktoru, qala azad etmək, geri hücum (ocaq müdafiəsi ilə).
- **Qəbul:** 20 müttəfiq və 20 düşmənlə döyüşdə 50+ FPS. Formasiyalar terrain-də pozulmur. Morale-dən qaçış və yenidən toplanma işləyir.

### Faza G: Tam dünya
- Xəritə 2×2 km-ə genişlənir, bütün bölgələr qurulur, bütün bosslar (Su Anası, Div, Təpəgöz, Şahmaran, Albastı) və Əjdaha, Qarabağ atı, bütün POI növləri, bölgə musiqiləri.
- **Qəbul:** hər bölgədən keçmək üçün tam oyun 15–25 saat çəkir. Performans hədəfi qorunur.

### Faza H: Hekayənin inteqrasiyası
- Fəsil 1-in yeni döyüşlə balansı, Fəsil 2-nin açıq dünyaya köçürülməsi (bölmə 11), 12 kral əks-sədası, xatirə nəticələrinin yenilənməsi, Fəsil 3-ün girişi.
- **Qəbul:** yeni oyundan Kölgə Arasa qədər hekayə boyunca kəsinti yoxdur. Bütün xatirə nəticələri debug menyusu ilə yoxlanılır.

---

## 15. Debug alətləri (bütün fazalarda)
- F10: xatirələr, bağlar, səviyyə, gümüş, teleport (xəritə nöqtəsinə), vaxt və hava.
- F4: AI overlay (vəziyyət, utility xalları, tokenlər, adaptiv çəkilər).
- F5: Hekayəçi overlay (gərginlik qrafiki, növbəti hadisə, cooldown-lar).
- F6: streaming overlay (hüceyrələr, yükləmə vaxtı, draw call-lar).
- Hər düşmən, hadisə və POI-ni konsol ilə çağırmaq imkanı.

## 16. Playtest göstəriciləri
- Seansın uzunluğu və seansın bitdiyi yer (harada oyunu dayandırırlar)
- Vaxtın bölgüsü: döyüş / kəşf / menyu (hədəf təxminən 40 / 50 / 10)
- Saatda ölüm sayı, bölgəyə və düşmən tipinə görə
- Parry və infaz istifadə faizi (hədəf: 3 saatdan sonra döyüşlərin 30%+-ində)
- Silah və bacarıq istifadəsinin paylanması (bir seçim 60%-dən çox dominantdırsa, balans problemi var)
- Hadisələrin nə qədər tamamlandığı, ordunun orta ölçüsü, azad edilən qalaların sayı
- Yanmış xatirələrin orta sayı (V2)
