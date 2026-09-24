# Ashes of the Crown: Oyun Dizayn Sənədi (GDD)

> Versiya 0.1 · 2026-09-24 · Status: canlı sənəddir, hər mərhələdə yenilənir.
>
> ⚠️ **V2 qeydi:** Satqın/detektiv sistemi (bölmə 4-dəki cədvəl, iz sistemi, Fəsil 2-nin sorğu-sual və divan hissəsi) V2-də silinib. Aktual dizayn üçün **docs/SPEC_V2.md** faylına bax. Dünya, personajlar, döyüş və Yaddaş Yanğınının əsasları qüvvədədir.

## 1. Bir cümlədə

Kral öldü, paytaxt bir gecədə yandı. Sinəsində Tacın közü yanan sonuncu varis **Ayxan** dağılan səltənəti xilas etməli, sarayda satqını tapmalı və tac qoymalıdır. Hər dəfə közün gücündən istifadə etdikdə isə kim olduğunun bir parçasını itirir.

## 2. Forma

- **Janr:** hekayə əsaslı 3D aksiya-RPG + saray və krallıq idarəetməsi
- **Kamera:** yuxarıdan, bucaq altında 3D. Dialoqlarda kinematoqrafik yaxın plan
- **Üslub:** stilizə edilmiş qaranlıq fantaziya. Soyuq ay işığı ilə isti od işığının kontrastı, kül, köz, duman
- **Platforma:** PC (Windows). Əvvəl itch.io demosu, sonra Steam
- **Mühərrik:** Godot 4.7.2
- **Hədəf müddət:** 10–15 saat. Çoxlu təkrar oynanma
- **Dil:** Azərbaycan dili (əsas), sonra ingilis dili

## 3. Dünya: Atəşan Səltənəti

Qafqaz və İpək Yolu ruhunda uydurma odlar diyarı: atəşgahlar, karvansaralar, neft ocaqları, dağ tayfaları, Xəzər sahilləri.

Min il boyu **Tac**, torpağı canlı saxlayan qədim **İlk Ocağı** içində bağlayan bir qab olub. Amma Tacda **Kül Şahı** adlı bir ruh yaşayır. Bu ruh tacı daşıyan hər kralı yavaş-yavaş içdən yeyir: onların xatirələrini yandırır.

**Kül Gecəsi:** Kral taxt salonunda alova büründü. Paytaxt **Közqala** yandı, Tac əriyib yox oldu. Azad qalan od indi səltənəti külə çevirir: kül fırtınaları qalxır, ölülər **Kül Kölgələri** olaraq geri qayıdır.

### Dərin sirr (bütün oyunlarda sabit)

Satqın kim olursa olsun, sonda həqiqət açılır: **kral yanğını özü istəyirdi.** O, Kül Şahını məhv etmək üçün özünü və şəhəri qurban verdi. Amma Tacın bir közü Ayxanın sinəsinə keçdi, indi Kül Şahı həmin közün içindən yeni qab axtarır.

## 4. Personajlar

| Ad | Rolu | Şübhə səbəbi | Gizli motivi (satqın olduqda) |
|---|---|---|---|
| **Ayxan** | Baş qəhrəman. Sonuncu varisdir, sinəsində köz yanır | — | — |
| **Rüfət** | Uşaqlıq dostu, qan qardaşı, mühafizə rəisi | Yanğın gecəsi postunda deyildi | Sabirin məktubu onu Elvinə bağlayır: taxtı "daha güclü" birinə vermək istəyir |
| **Sabir** | Qoca vəzir, Ayxanın müəllimi | Hər şeyi bilir, heç nə demir | Kralın planını bilirdi. Közü Ayxana özü yönəltdi |
| **Şahbaz** | Sərkərdə | Kral onun oğlunu edam etdirmişdi | İntiqam: yanğın gecəsi darvazaları açıq qoydu |
| **Elvin** | Ayxanın qeyri-qanuni qardaşı, parlaq və iddialı | Özünü varis elan edib | Tacı özü üçün istəyir, Kül Şahı ilə danışıq aparır |
| **Əhliman** | Közün Ordeninin baş kahini | Yanğını "ilahi hökm" adlandırır | Kül Şahına sitayiş edən gizli təriqətin başçısıdır |
| **Anar** | Karvan Gildiyasının başçısı | Yanğından sonra qəribə şəkildə varlanıb | Xarici imperiyaya satılıb, Tacın qalığını satmaq istəyir |
| **Əşrəf** | Qartal Dağları tayfalarının bəyi | Taxtla üç nəsillik qan davası var | Tayfasını azad etmək üçün yanğını fürsət bildi |
| **İbrahim** | Saray alimi və kimyagər | Yanğından sonra itkin düşüb | Tacın sirrini açan odur. Közü idarə etməyin yolunu bilir, amma bunun qiyməti var |

**Satqın hər oyunda təsadüfi seçilir.** Sübutlar da ona uyğun paylanır. Hər personajın həm satqın, həm də sadiq variantı üçün ayrıca hekayə xətti var.

### İz sistemi (M4, `scripts/story/conspiracy.gd`)
8 iz: ağır əsgər çəkməsi, ladan, mürəkkəb, yad sikkə, canavar xəzi, kral möhürü, kükürd, solaxay zərbə. Hər şübhəlinin 3 izi var, dəstlər unikaldır:

| Şübhəli | İzlər |
|---|---|
| Sabir | ladan, mürəkkəb, möhür |
| Anar | yad sikkə, kükürd, solaxay |
| Elvin | mürəkkəb, yad sikkə, möhür |
| Şahbaz | çəkmə, xəz, solaxay |
| Əşrəf | çəkmə, xəz, yad sikkə |
| Rüfət | çəkmə, möhür, solaxay |
| İbrahim | ladan, mürəkkəb, kükürd |
| Əhliman | ladan, kükürd, solaxay |

1 iz 2–4 şübhəli, 2 iz 1–2 şübhəli qoyur, 3 iz isə həmişə tək bir nəfərə aparır (bu, avtomatik yoxlanılıb). Fəsil 1-də sübut hələ hökm deyil: ittiham Fəsil 2-də, Son Ocaqda olacaq.

## 5. Əsas mexanika: Yaddaş Yanğını ⭐

- Ayxanın **6 xatirəsi** var: Rüfətin üzü, anasının adı, Sabirin ilk dərsi, Közqalanın küçələri, atasının səsi, ilk qılıncı.
- Od gücləri güclüdür, amma hər istifadə **növbədəki xatirəni yandırır**. Növbə ekranda görünür, yəni oyunçu nəyi itirəcəyini bilərək qərar verir.
- Yanmış xatirənin nəticələri:
  - Dialoqlar dəyişir (məsələn, "Rüfətin üzü" yanıbsa, Ayxan onu tanımır).
  - Münasibətlər dəyişir, bəzi seçimlər və sübutlar yox olur.
  - Köz daha parlaq yanır, Ayxanın zirehi külə çevrilir (vizual göstərici).
  - Kül Şahının pıçıltısı güclənir.
- Sonlar yanmış xatirələrin sayından asılıdır.

## 6. Oyun dövrü (tam oyun)

1. **Son Ocaq (baza):** bərpa olunan karvansara. Divan, yoldaşlar, qərarlar
2. **Ekspedisiya:** bölgəyə səfər. Kəşf, döyüş, sübut, müttəfiq
3. **Qayıdış və divan:** resurslar, fraksiyalar, siyasi qərarlar
4. **Dünyanın növbəsi:** kül yayılır, NPC-lər öz planlarını həyata keçirir, laqeyd buraxılan bölgə düşür

## 7. Bölgələr

| Bölgə | Vizual | Mahiyyəti |
|---|---|---|
| **Közqala** | Yanmış paytaxt, köz, qızıl xarabalıqlar | Taxt salonunun sirri, satqının izləri |
| **Neft Çölü** | Alov sütunları, qara göllər, atəşgahlar | Közün Ordeni, Odun tarixi |
| **Qartal Dağları** | Qar ilə külün qarışığı, qala-kəndlər | Əşrəfin tayfaları, qan davası |
| **Batmış Liman** | Yarı su altında qalmış şəhər, fırtına | Anarın gildiyası, imperiyanın casusları |

## 8. Döyüş

- Qılınc (kombo), **Kül addımı** (toqquşmadan keçən sürətli qaçış), **Alov Dalğası** (xatirə yandırır). Sonrakı mərhələlərdə yeni od gücləri gələcək.
- Düşmənlər hücumdan əvvəl xəbərdarlıq edir (gözləri alışır, qolları qalxır). Qılınc zərbəsi adi düşmənin hücumunu kəsir.
- Ocaqların istisi yaraları sağaldır, yəni ərazinin taktiki mənası var.
- Yoldaş döyüşdə kömək edir. Satqın yoldaş isə kritik anda arxa çevirə bilər.

### Döyüş hissi (M2)
- **Kombo:** çəpinə → üfüqi → yuxarıdan güclü zərbə. Düymə əvvəlcədən basılsa, yadda saxlanılır. Hər zərbədə irəli addım atılır, zərər qılıncın dəydiyi anda hesablanır.
- **Çəki:** zərbədə qısa zaman dayanması (hitstop), kameranın silkələnməsi, güclü zərbədə kamera yaxınlaşması, qığılcım və işıq partlayışı, uçan zərbə rəqəmləri.
- **Oxunaqlılıq:** düşmən hücumdan əvvəl gözlərini alışdırır, altında isə böyüyən qırmızı halqa çıxır. Adi düşmənin hücumunu qılınc kəsir, elitə hücumunu isə yalnız güclü zərbə kəsə bilir.
- **Kulminasiya:** dalğanın son düşməni yavaş çəkilişdə yıxılır.
- **Can zolaqları (M3):** düşmənin başı üstündə zolaq zərbə dəyəndən sonra görünür. İtirilən hissə bir anlıq açıq rəngdə qalıb əriyir. Zərbə rəqəmləri default olaraq bağlıdır, parametrlərdən açıla bilər.
- **Hücum növbəsi (M3):** eyni anda ən çox 2 kölgə hücum edir, qalanları Ayxanın ətrafında dövrə vurub növbə gözləyir. Kalabalıq ədalətli, amma gərgin qalır.

### Səs dizaynı
- Bütün səslər `tools/gen_audio.py` ilə sintez olunur.
- **Musiqi:** sakit qat (tar improvizasiyası, kamança, uzaq qonq) və döyüş qatı (6/8 ölçüdə nağara və qaval, tar ostinatosu, kamança fəryadı). Qatlar arasında yumşaq keçid var.
- Ocaqların çırtıltısı 3D məkanda eşidilir, külək isə daim əsir.

## 8b. Fəsil 2: Son Ocaq (M5)

**Axın:** Ayxan sağ qalanların toplaşdığı karvansaraya gəlir → şübhəliləri sorğu-suala tutur → 4 söhbətdən sonra **gecə hücumu** başlayır (darvaza içəridən açılır, satqın və təsadüfi bir günahsız yoxa çıxır) → şahid kimin olmadığını deyir → **Ocaqda divan**: bir ad seçilir.
- **Doğru ittiham:** satqın etiraf edir (hər personajın öz motivi var), Kül Şahı danışır, satqın külə çevrilib **"<ad> — Külün Xaini"** bossu kimi qalxır.
- **Səhv ittiham:** günahsız sürgün edilir, hamının etibarı düşür, satqın son hücumu təşkil edir. Satqın Fəsil 3-ə qədər sağ qalır.

**Sorğu-sual (`scripts/story/interrogation.gd`):** hər şübhəlinin isti və soyuq salamı var (etibar < 35 olanda soyuq). Alibisinin satqın versiyası yayındırıcı səslənir. Öz izlərinə günahsız və ya günahkar cavab verir, başqasının izinə isə inkarla cavab verir. Sübut göstərmək etibarı azaldır (–4 öz izi üçün, –8 əsassız ittiham üçün). Etibar ≥ 55 olanda şübhəli gördüyü birinin adını deyir: çox vaxt satqını, bəzən isə səhv adamı.

**NPC süni intellekti (`scripts/npc/survivor.gd`):** hər sağ qalanın 3 ehtiyacı zamanla azalır: istilik, ünsiyyət və vəzifə. Hər birinin azalma sürəti fərqlidir (xasiyyət). Hər 9–18 saniyədən bir fəaliyyətlər qiymətləndirilir: ocağın yanında oturmaq, başqası ilə söhbət, öz guşəsi, gəzinti. Ən təcili olan seçilir. Rejimlər: danışıq üçün dayanmaq, hücumda gizlənmək, darvazadan sıvışmaq (satqın), sürgün.

## 9. NPC süni intellekti

- Əsas yanaşma "utility AI"dır: hər NPC-nin məqsədi, qorxusu, sirri, sədaqəti və Ayxan haqqında yaddaşı olur.
- NPC-lər ittifaq qurur, şayiə yayır, plan hazırlayır. Sistem proqnozlaşdırıla bilir, test olunur və internet tələb etmir.
- İstəyə görə, sonradan dialoqu zənginləşdirmək üçün dil modeli (LLM) qatı əlavə oluna bilər. Oyunun təməli ondan asılı deyil.

## 10. Sonlar

1. **Tacı yenidən alovlandır:** yeni qab olursan, səltənət xilas olur, sən isə özünü itirirsən.
2. **Odu söndür:** sehr bitir, sən insan qalırsan.
3. **Odu xalqa payla:** tac yox olur, hər evdə ocaq yanır.
4. **Kül İmperatoru:** Kül Şahı ilə birləşirsən (qaranlıq son).
5. **Gizli son:** yalnız bir dəfə də xatirə yandırmadan oyunu bitirənlər üçün açılır.

## 11. İnkişaf yol xəritəsi

| Mərhələ | Məzmun | Status |
|---|---|---|
| **M1: Prototip** | Közqala həyəti, Ayxan, Rüfət, dialoq, Yaddaş Yanğını, 3 dalğa, 2 qrafika rejimi | ✅ Hazırdır |
| **M2: Hiss** | KayKit 3D personajları və animasiyaları, kombo döyüşü, hitstop, zərbə rəqəmləri, 28 sintez səs və muğam musiqisi (sakit və döyüş qatları) | ✅ Hazırdır |
| **M3: Dünya və interfeys** | Közqala KayKit mühit modelləri ilə yenidən quruldu (hisə batmış divarlar, bayraqlar, xəzinə, sümüklər, yanmış ağaclar, məşələlər). Baş menyu (Ayxan külün içində yatır, kamera həyət ətrafında fırlanır), fasilə menyusu, yadda qalan parametrlər (səs, qrafika, tam ekran, silkələnmə, zərbə rəqəmləri). Düşmənlərin üstündə can zolaqları, eyni anda ən çox 2 düşmən hücum edir | ✅ Hazırdır |
| **M4: Satqın və sübutlar** | Hər oyunda təsadüfi satqın (8 şübhəli × 3 iz), 3 Kül əks-sədası (görüntü: dünya boz rəngə keçir, közdən xəyal çıxır), jurnal (Tab), şərtli dialoqlar (satqın Rüfətdirsə, o, özünü başqa cür aparır), avtomatik yadda saxlama və "Davam et", hədəf işarəsi, köz ikonları | ✅ Hazırdır |
| **M5: Son Ocaq** | Fəsil 2: karvansara, 8 şübhəli (hər birinin ayrıca modeli və rəngi), utility AI (istilik, ünsiyyət, vəzifə ehtiyacları), sorğu-sual (alibi, sübut, şübhə), etibar sistemi, gecə hücumu (satqın darvazanı açır, 2 nəfər yox olur), divan və ittiham, iki son (boss döyüşü və ya günahsızın sürgünü) | ✅ Hazırdır |
| M6: Fəsil 3 | Kül Şahının həqiqəti, bölgələrə səyahət, Yaddaş Yanğınının sonlara təsiri | Növbəti |
| M5: Vertical slice | Közqala tam hekayə xətti ilə, 3 NPC, 1 satqın ssenarisi | |
| M6+ | Digər bölgələr, bütün sonlar, Steam | |

## 12. Prototip (M1): nə var?

Fəsil 1, "Birinci səhər":
1. Titr ekranı: *Közqala. Kül Gecəsindən üç gün sonra.*
2. Ayxan yanmış həyətdə oyanır. Tapşırıq: Rüfəti tapmaq.
3. Rüfətlə budaqlanan dialoq. Onun üzü yanıbsa, dialoq tamam başqa cür gedir. Seçimlər qeydə alınır: `clue_letter`, `rufet_hesitated` və s.
4. Üç dalğa: Kül Kölgələri, sürətli kölgələr və **Kül Cəngavəri** (boss).
5. Son ekranı: yanmış xatirələrə və seçimlərə görə mətn dəyişir.

Performans: noutbukda (Intel UHD) "Aşağı" rejimdə ~50 FPS.
