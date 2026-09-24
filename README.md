# Ashes of the Crown

Stilizə edilmiş 3D aksiya-RPG. Kül Gecəsindən sonra Atəşan səltənəti.
Mühərrik: **Godot 4.7.2** (Forward+). Bütün səviyyə, personajlar və effektlər koddan qurulur.

## Necə oynamalı

`play.bat` faylına iki dəfə kliklə.

| Düymə | Hərəkət |
|---|---|
| W A S D | Hərəkət |
| Sol klik / J | Qılınc. Ardıcıl 3 dəfə bas: kombo, 3-cü zərbə ən güclüsüdür |
| Sağ klik / Q | **Alov Dalğası**: bir xatirəni yandırır |
| Space | Kül addımı (yayınma, zərbədən qoruyur) |
| E | Danış / davam et |
| 1-3 | Dialoq seçimi |
| F9 | Qrafika: Aşağı / Yüksək |
| F3 | FPS göstər |
| F11 | Tam ekran |
| R | Yenidən başla (son ekranında) |
| Esc | Çıxış |

Yaralanmısansa, ocaqların yanında dayan: odun istisi səni sağaldır.
Düşmənin altında qırmızı halqa böyüyürsə, o, zərbə vurmağa hazırlaşır. Yayın!

## Struktur

```
docs/         GDD və qərarlar jurnalı
scenes/       main.tscn (giriş nöqtəsi)
scripts/
  main.gd       Fəsil 1 axını: giriş → Rüfət → 3 dalğa → son
  systems/      Settings, Memory (Yaddaş Yanğını), Fx (hitstop, effektlər), Audio autoload-ları
  characters/   KayKit modellərini idarə edən qat (animasiya, rəng, silah)
  world/        Közqala səviyyəsi, vizual və partikl köməkçiləri
  player/       Ayxan
  npc/          Rüfət
  enemies/      Kül Kölgəsi / Kül Cəngavəri
  camera/       İzometrik kamera + dialoq kamerası
  ui/           HUD, dialoq pəncərəsi
  story/        Dialoq mətnləri
shaders/      Yer, daş, lava, kül örtüyü, rəng dəyişmə, vinyet
assets/       KayKit personajları (CC0), sintez olunmuş səslər
tools/        gen_audio.py (səs və musiqi generatoru), inspect_models.gd
```

Səsləri yenidən yaratmaq üçün: `python tools/gen_audio.py`

## Tərtibatçı üçün: avtomatik ekran görüntüsü

```bash
Godot_v4.7.2-stable_win64_console.exe --path . -- --demo=combat --capture=captures/combat.png --frame=260
```

Rejimlər: `explore`, `dialogue`, `fight`, `combat`, `victory`. Konsolda orta FPS göstərilir.
