# ASHES OF THE CROWN: V2 dizayn spec-i

> Bu sənəd sahibin təsdiqlədiyi V2 konsepsiyasıdır (2026-09-24) və GDD-dəki köhnə detektiv hissələrini əvəz edir. İmplementasiya fazalarla gedir (bölmə 12). Hər fazanın statusu aşağıda qeyd olunur.

## İmplementasiya statusu
| Faza | Məzmun | Status |
|---|---|---|
| 1 | Təmizlik: satqın sistemi silindi, Fəsil 2 müvəqqəti "gəz və tanış ol" vəziyyətindədir | ✅ |
| 2 | Od sistemi və balans: köz ölçüsü, Köz Zərbəsi, radial menyu, ilk istifadə təsdiqi, mükəmməl yayınma, kəsilməz faza, Kül Burulğanı, Kül Şahının təklifi, ocaq sağaltma qaydaları, bütün rəqəmlər `balance.gd`-də | ✅ |
| 3 | Xatirə nəticələri, səs, vizual | Növbəti |
| 4 | Fəsil 1-in yenilənməsi (qismən Faza 1-də edildi: Rüfətin yeni "harada idin?" qolu, kralın əks-sədalarının mətnləri, yeni qayıdış dialoqu, yeni son kart) | Qismən |
| 5 | Fəsil 2-nin əsası | |
| 6 | Final | |

---

## 1. Yeni konsepsiya
Əsas sual artıq **"Satqın kimdir?"** deyil, **"Başqalarını xilas etmək üçün özündən nə qədər verə bilərsən?"**dir.

Arasın gücü xatirələrindən gəlir. Hər böyük od istifadəsi bir xatirəni yandırır. Sağ qalanlarla bağ qurduqca onlar ona öz xatirələrini verir: bunlar həm güc (perk), həm də yanacaqdır. Kül Şahı hər yanmış xatirə ilə Arasa daha çox yaxınlaşır.

Əsas dövrə: **Döyüş → Od (xatirə yandırmaq) → Bağ (xatirə almaq) → Ocaqları müdafiə → Seçimlərin nəticəsi (Kölgə Aras, sonlar).**

Satqın, izlər, sorğu-sual, etibar, divan, ittiham, "Külün Xaini" bossu, sürgün və məktub ipucusu tam silinib.

## 2. Xatirə sistemi
- **6 öz xatirəsi.** Hansının yanacağını oyunçu özü seçir. Yanmış xatirə geri qayıtmır.
- **Hər xatirənin mexaniki nəticəsi var:**

| Xatirə | Yanandan sonra |
|---|---|
| Rüfətin üzü | Rüfət tanınmır, üzündə kül effekti görünür, bağın maksimumu 70 olur |
| Anamın adı | Ocaq sağaltması 9 → 5 can/s, Əhlimanın dialoqu dəyişir |
| Sabirin ilk dərsi | Mükəmməl yayınma pəncərəsi 0.12 → 0.06 s |
| Közqalanın küçələri | Yol göstərən ox və marker-lər sönür |
| Atamın səsi | Əks-sədalar səssiz olur, musiqidə kamança susur |
| İlk qılıncım | 3-cü zərbə 38 → 26, güclü zərbədə kamera yaxınlaşması itir |

- **Alınmış xatirələr** (maksimum 8, hər NPC-dən bir): bağ ≥ 60 olanda verilir və perk qazandırır. Yandırılanda perk itir, həmin NPC ilə bağ −25 düşür və o, reaksiya sətri deyir.
- **Kül Şahının təklifi:** can ≤ 15 olanda gəlir, hər döyüşdə ən çox 1 dəfə. E ilə qəbul edilir: can tam bərpa olur, amma Kül Şahı təsadüfi bir öz xatirəni yandırır.
- **Halüsinasiyalar:** 4+ öz xatirəsi yanıbsa, dalğalara yalançı kölgələr qatılır.

## 3. Od sistemi
- **Köz ölçüsü (0–100):** zərbə dəyəndə +6, öldürəndə +10, mükəmməl yayınmada +20.
- **Köz Zərbəsi:** Q qısa basılır, 50 köz sərf edir, konus şəklində 30 zərər vurur.
- **Alov Dalğası:** Q basılı saxlanılır → radial menyu açılır → xatirə seçilir → 75 zərər. İlk istifadədə təsdiq istənilir.

## 4. Balans
- Kül addımı cooldown-u 0.8 s.
- Mükəmməl yayınma yavaş çəkiliş verir.
- Düşmən halqası 0.9 s böyüyür, son 0.35 s-də hücumu heç bir zərbə kəsmir.
- Döyüş vaxtı ocaq sağaltmır.
- Kül Cəngavərinin yeni hərəkəti: **Kül Burulğanı**.

## 5–6. Bağ sistemi, tapşırıqlar, alınmış xatirələr
Bağ 0–100 arasındadır:
- < 35: soyuq münasibət
- ≥ 35: tapşırıq açılır
- ≥ 60: xatirəsini hədiyyə edir
- ≥ 75: gecədə yanında döyüşür

8 tapşırıq 3 şablonla qurulur: Təmizlə, Gətir, Əks-səda. 8 perk var. Hər NPC-nin açar sətirləri sahibin spec-indədir və dəyişmədən istifadə olunur.

## 7. Ssenari
- **Fəsil 1:** kralın son gecəsinin 3 əks-sədası, Rüfətin yeni "harada idin?" qolu (kral mühafizəni saraydan çıxarıb), yeni qayıdış dialoqu.
- **Fəsil 2:** 8 nəfər, 3 ocaq, 2 gün + 2 gecə, ən çox 6 tapşırıq. Ocaq sönəndə yanındakılar külə dönür. 5 saniyə ərzində xatirə yandırmaqla ocağı yenidən alovlandırmaq olar.
- **Boss: Kölgə Aras.** Canı 300 + (yanmış öz xatirəsi × 60). Hər yanmış xatirə ona bir hərəkət qazandırır.
- **Sonlar matrisi:** sağ qalanların sayı (≥ 6 və ya ≤ 5) × yanmış öz xatirələri (≤ 2 və ya ≥ 3).

## 8–11. HUD, jurnal, vizual, səs, yadda saxlama
- Jurnalda 4 tab olacaq: Xatirələr, Bağlar, Tapşırıqlar, Əks-sədalar.
- Başlıqlar, kül-shader, Kölgə Aras, kral xəyalı.
- Musiqi 6 qata bölünür, hər qat bir xatirəyə bağlıdır.
- Save versiyası artırılır, köhnə save aşkar olunanda mesaj göstərilir.

Tam mətn, bütün rəqəmlər və NPC sətirləri üçün sahibin orijinal spec-inə bax. Rəqəmlər `scripts/systems/balance.gd` faylına köçürüləcək (Faza 2).
