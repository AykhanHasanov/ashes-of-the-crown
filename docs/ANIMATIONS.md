# Animasiya siyahısı (V3, Faza A)

Hər klipin modeldə olub-olmadığını `tools/check_anims.gd` avtomatik yoxlayır. Hazırda
**çatışmayan klip: 0**. Aşağıda "əvəzedici" yazılan yerlər işləyir, amma ideal deyil.
Sonrakı fazalarda imkan olarsa əsl animasiya ilə əvəz olunacaq.

```
godot --headless --path . -s tools/check_anims.gd
```

## Ayxan (KayKit Rogue_Hooded, Rig_Medium)

| Hərəkət | Klip | Qeyd |
|---|---|---|
| Dayanma / yeriş / qaçış | Idle, Walking_A, Running_A | Sprint = Running_A sürətləndirilmiş |
| Kilidli yan addım / geri | Running_Strafe_Left/Right, Walking_Backwards | |
| Yayınma | Dodge_Forward/Backward/Left/Right | Kilidlidə istiqamətli |
| Tullanma | Jump_Start, Jump_Idle, Jump_Land | |
| Yüngül zəncir (qılınc) | 1H_Melee_Attack_Slice_Diagonal → Slice_Horizontal → Chop → Stab | 4-cü zərbə ustalıq 2-dən açılır |
| Ağır / yüklənmiş | 1H_Melee_Attack_Chop (+ windup 2H_Melee_Idle) | **Əvəzedici:** ayrıca "yüklənmə" pozası yoxdur |
| Gürz | 2H_Melee_Attack_Chop / Slice / Spin | |
| Qalxan zərbəsi | Block_Attack | |
| Blok | Blocking, Block_Hit | |
| Parry | Block_Attack (sürətli) | **Əvəzedici:** ayrıca parry klipi yoxdur |
| İnfaz | silahın `execution.clip` (Stab / Chop) | **Əvəzedici:** cüt (sinxron) infaz animasiyası yoxdur |
| Nar şərbəti | Use_Item | |
| Zərbə yeyəndə | Hit_A, Hit_B | |
| Yıxılma / qalxma | Lie_Down, Lie_Idle, Lie_StandUp | Duruş qırılanda |
| Köz gücləri | Spellcast_Raise, Spellcast_Shoot | |
| Ölüm | Death_A | |

## Düşmənlər

| Düşmən | Model | Qeyd |
|---|---|---|
| Kül Kölgəsi | KayKit Skeleton_Minion | Doğulma: Spawn_Ground_Skeletons. **Blok yoxdur** (dizayn: blok etmir). Stagger = Lie_Down |
| Qalxanlı quldur | KayKit Barbarian (rəngi dəyişdirilib) | Blocking, Block_Attack (qalxan zərbəsi), 1H Chop |
| Canavar | Quaternius Wolf | Dişləmə: Attack, sıçrayış: Gallop_Jump. **Əvəzedici:** stagger = Death klipi 0.55 s-də dondurulur; qalxma = Jump_ToIdle |

## Çatışmayanlar və plan

| Lazım olan | İndiki həll | Nə vaxt / haradan |
|---|---|---|
| Cüt infaz (Ayxan + düşmən sinxron) | Tək zərbə + düşmən yıxılır | Faza H cilası. Mixamo retarget variantı |
| Ayrıca parry klipi | Block_Attack sürətləndirilmiş | Faza H |
| Yüklənmə (charge) pozası | 2H_Melee_Idle / Blocking | Faza H |
| Canavar stagger/qalxma | Death dondurulur + Jump_ToIdle | Başqa heyvan paketi tapılsa |
| Üzmə | Running_A yavaşladılır, model 0.55 m suya batırılır | Faza H: üzmə klipi (Mixamo retarget) |
| Yamacda sürüşmə | Jump_Idle | Faza H |
| Maneədən aşma (vault) | Jump_Start + qövs üzrə hərəkət | Faza H |
| At minmə, dırmaşma | yoxdur | Faza G |
| Boss/canavarlar (Div, Təpəgöz, ayı) | model yoxdur | Faza D–E: CC0 mənbə axtarışı |
