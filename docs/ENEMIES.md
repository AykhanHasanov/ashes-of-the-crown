# Düşmənlər (V3 Faza C)

Hamısı `data/enemies/*.json`-da təsvir olunur. Balans `data/balance/ai.json` və `data/balance/affixes.json`-dadır. Kod: `scripts/enemies/foe.gd`, `perception.gd`, `affixes.gd`.

## Tiplər: 3 fraksiya, 12 tip və 1 mini-boss

| Fraksiya | Düşmən | Rol | Necə döyüşmək lazımdır |
|---|---|---|---|
| Kül | **Kül Kölgəsi** | yaxın döyüş | Bazadır. Gecikdirilmiş chop zərbəsini parry et |
| Kül | **Sürətli Kölgə** | flanker | Yandan dolanır, uzaqdan hücum edir. Yayın və əzici silahla vur |
| Kül | **Kül Oxçusu** | oxçu | Alovlu ox atır (yanma verir), 8–20 m məsafə saxlayır, yüksəyə çıxır. Üstünə qaç, yayınaraq yaxınlaş |
| Kül | **Partlayan Kül** | intihar | 2 saniyə parlayır və partlayır (3.8 m). Onu öldürüb yayın, parry işləmir |
| Kül | **Kül Şamanı** | dəstək | Müttəfiqlərə qalxan verir və ölən kölgəni **bir dəfə** diriltir. İlk hədəf odur |
| Kül | **Kül Nəhəngi** (elit, 3 m) | ağır | Parry edilməyən zərbələr vurur, yeri silkələyir (AoE), qalxanı qırır. Adaptivdir |
| Quldur | **Qılınclı quldur** | flanker | Kombo vurur, yayınır. Morale var |
| Quldur | **Qalxanlı quldur** | tank | Öndə durur, blok edir. Ağır zərbə və ya arxadan hücum lazımdır |
| Quldur | **Quldur oxçu** | oxçu | Deşici oxla uzaqdan vurur |
| Quldur | **Nizəçi** | uzun məsafə | 3.4 m-lik dürtmə və hücum qaçışı. İçəri gir |
| Quldur | **Ataman** (elit) | lider | Döyüş nərəsi çəkir (+25% zərər), feint edir, qalxanı qırır. Ölümü quldurları sarsıdır |
| Heyvan | **Canavar** | sürü, flanker | Əvvəlcə nərildəyir (ərazi davranışı). Uzaqlaşsan hücum etmir |
| Heyvan | **Qafqaz bəbiri** (mini-boss) | gizlənən | 3 hücumdan sonra kölgəyə çəkilir, sonra sıçrayışla (parry olmur) qayıdır. 50%-də qəzəblənir, boss zolağı çıxır |

## AI

- **Utility:** hər 0.2–0.4 saniyədə bütün seçimlər qiymətləndirilir. Hücumlar, blok, yayınma, yaxınlaşma, dövrə vurma, flank, öndə durma, məsafə saxlama, yüksəyə çıxma, arxada qalma, geri çəkilmə və morale (qaçış və ya təslim olma).
- **Tokenlər:** Arasın büdcəsi 3-dür. Adi düşmən 1, elit 2, boss 3 token tutur. Oxçular, sehrlər və partlayanlar token gözləmir.
- **Algılama:** görmə 120°, gündüz 25 m, gecə və dumanda 12 m, görmə xətti yoxlanır. Eşitmə: sprint 15 m, döyüş səsi 30 m. Vəziyyətlər: sakit → şübhəli (sarı ?) → döyüş (qırmızı !) → 8 s axtarış → evə qayıdış.
- **Adaptiv (elit və boss):** Arasın son 60 s-dəki vərdişinə əks-cavab verir. Yayınmaya süpürmə və gecikdirilmiş zərbə, bloka qalxan qıran, parry-yə feint, məsafəyə sıçrayış.
- **AI LOD:** 40 m-ə qədər tam, 40–120 m-də saniyədə bir qərar və seyrək animasiya, 120 m-dən uzaqda donmuş.
- **Səviyyə:** HP = baza × (1 + 0.12(L−1)), zərər = baza × (1 + 0.08(L−1)), XP formulu. Arasdan 5+ səviyyə yuxarı olanın adının yanında ☠ görünür. Kül gecə +20% güclüdür.
- **Affikslər** (adi düşmənə 6%, elitə 30%, 1–2 ədəd): Alovlu, Qalın, Sürətli, Çağıran, Qisasçı, Sarsılmaz, Kül Şahının Gözü.
- **Morale:** quldurun canı az qalanda və tək olanda (və ya ataman ölüb) qaçır və ya təslim olur. Təslim olanı buraxmaq ([E]) və ya öldürmək olar. Orduya almaq Faza F-dədir.

## Debug

- **F4:** AI overlay (vərdişlər, vəziyyət, algılama, LOD, utility xalları, tokenlər, adaptiv çəkilər, affikslər, XP).
- **F10 (arena):** hər düşməni adi və ya affiksli çağırmaq, səviyyəsi 8 olan quldur (☠).
- **Testlər:** `--demo=ai_selftest` (41 yoxlama, arena), `arena_selftest` (19), `world_selftest` (28).
