# Açıq dünya: necə qurulur (V3 Faza B)

Dünyanın mənbəyi mətn fayllarıdır. Qalan hər şey onlardan generasiya olunur.

## Mənbələr (əllə redaktə olunur)

| Fayl | Nə var |
|---|---|
| `data/world/world_layout.json` | Ölçü, toxum (seed), noise qatları, dağ silsilələri, təpələr, çay spline-ı, göllər, biom nöqtələri, əsas POI-lər, yollar |
| `data/world/poi_rules.json` | Kiçik POI-lərin prosedur qaydaları (boşluq ≤ 125 m, yamac, su, kənar) |
| `data/world/vegetation.json` | Bitki örtüyü: model, sıxlıq, biom ehtimalları, görünmə məsafəsi, gövdə kolliziyası |
| `data/world/prefabs/*.json` | POI prefabları: modellər, `line`/`ring`/`grid` generatorları, işıqlar, düşmənlər, qarşılıqlı əlaqə |
| `data/balance/world.json` | Vaxt (24 dəq = 1 gün), hava, streaming, üzmə/sürüşmə/düşmə, terrain teksturaları, xəritə |

## Generasiya (sırası ilə)

```
godot --headless --path . -s tools/pack_terrain.gd    # Poly Haven teksturaları → Terrain3D formatı
godot --headless --path . -s tools/bake_foliage.gd    # bitki modelləri → metr ölçülü, Y-yuxarı mesh-lər; ot kolu prosedur
godot --headless --path . -s tools/gen_world.gd       # dünya → world/terrain/*.res + world/generated/
godot --headless --path . --import
```

`gen_world` loqu POI sıxlığını yoxlayır. Hazırkı nəticə: ən uzaq gəzilə bilən nöqtə POI-dən 119 m aralıdır (qayda ≤ 150–200 m).

## Oyunda

- `scripts/world/open_world.gd`: Terrain3D, su, gecə-gündüz, hava, ambient səs, sərhədlər, körpülər, Közqala tüstüsü.
- `scripts/world/cell_streamer.gd`: 128 m hüceyrələr. 3×3 tam yüklənir (kolliziya, işıq, düşmən, qarşılıqlı əlaqə), 5×5 yalnız vizual, qalanında ancaq "far" orientirlər. Mesh-lər WorkerThreadPool-da qurulur, əsas thread-də isə hər kadr üçün 3 ms büdcə var.
- `scripts/world_mode.gd`: kəşf, ocaqlar, sandıqlar, əks-səda daşları, düşmənlərin izlənməsi, sürətli səyahət, ölüm, avtomatik save (5 dəqiqədən bir), F10 debug, F6 streaming overlay.

## Terrain3D 1.0.2 + Godot 4.7 uyğunsuzluqları (həll edilib)

Terrain3D 4.4–4.6 üçün yazılıb. 4.7-də yüklənir və işləyir, amma instancer-də üç problem var. Hamısı `open_world.gd`-də həll olunub:

1. Diskdən yüklənən regionların MMI node-ları region küncünə yerləşdirilmir, bütün bitkilər (0,0) regionuna yığılır. **Həll:** MMI-lər əllə öz küncünə qoyulur.
2. Godot 4.7 görünmə məsafəsini node-un başlanğıcından ölçür, hüceyrədən yox, ona görə yaxındakı ot gizlənir. **Həll:** mühərrik məsafəsi söndürülür, hər MMI-ni öz hüceyrəsinin mərkəzinə olan məsafəyə görə özümüz göstərir və gizlədirik.
3. Sahnəyə girəndə asset siyahısı sıfırlanır. **Həll:** asset-lər sahnəyə daxil olandan sonra təyin edilir, region qovluğu isə ondan da sonra.

Quaternius təbiət modelləri 1/100 miqyasdadır (node ×100, Z-yuxarı). Instancer node transformunu nəzərə almır, ona görə `bake_foliage` mesh-ləri metr ölçüsünə gətirir.
