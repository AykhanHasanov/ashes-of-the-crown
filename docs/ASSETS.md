# Assets register

Every third-party asset in the project, with its source and licence. **Budget is zero: CC0 or clearly free only.**
Add a row here in the same commit that adds the files — file or folder, what it is, source URL, licence, date.
`CREDITS.md` at the root is the short public credits list; this file is the full record.

Rules that go with an import:
- keep the `.import` files in git (they carry the import settings);
- every model keeps `tools/import/material_policy_import.gd` as its import script (`docs/MATERIAL_AUDIT.md`);
- a material that must stay metal or glossy is marked `_keep` (see the same doc).

## Models

| Folder | What | Source | Licence | Added |
|---|---|---|---|---|
| `assets/characters/adventurers`, `assets/characters/skeletons` | KayKit Adventurers 1.0, Skeletons 1.0 | kaylousberg.com, github.com/KayKit-Game-Assets | CC0 | before 2026-09 |
| `assets/environment/dungeon`, `assets/environment/halloween` | KayKit Dungeon Remastered 1.0, Halloween Bits 1.0 | as above | CC0 | before 2026-09 |
| `assets/chars/base`, `assets/chars/outfits`, `assets/chars/heads`, `assets/chars/hair` | Quaternius Universal Base Characters + Modular Outfits (the protagonist and every NPC) | quaternius.com | CC0 | before 2026-09 |
| `assets/anims` | Quaternius Universal Animation Library | quaternius.com | CC0 | before 2026-09 |
| `assets/quaternius/*` | Quaternius packs: medieval village, modular medieval buildings, modular dungeon, nature, animals, medieval weapons, RPG items, survival | quaternius.com | CC0 | before 2026-09 |
| `assets/props_mk` | Fantasy Props MegaKit | — (free kit) | free asset kit | before 2026-09 |
| `assets/village_mk` | Medieval Village MegaKit | — (free kit) | free asset kit | before 2026-09 |
| `assets/nature` | Poly Haven models: rock_07, rock_09, rock_face_01, rock_moss_set_01/02, shrub_03/04, fern_02, tree_stump_01, dead_tree_trunk | polyhaven.com | CC0 | before 2026-09 |

## Textures

| Folder | What | Source | Licence |
|---|---|---|---|
| `assets/terrain` | Ground textures (grass, dirt, mud, forest, meadow), albedo+height / normal+rough | Poly Haven | CC0 |
| `assets/foliage/cards`, `assets/foliage/bark` | Leaf and bark photo sets (LeafSet014/016/019/024/027, Foliage001/003/006, Bark001/005/012) composed by `tools/make_foliage_cards.py` | ambientcg.com | CC0 |

## Generated in this project (no third party)

| Folder | What | Made by |
|---|---|---|
| `assets/foliage/*.scn` | Trees, bushes, rocks, grass cards baked to Y-up metre scale | `tools/gen_trees.gd`, `tools/bake_foliage.gd` |
| `assets/buildings` | Houses assembled from the kits | `tools/build_houses.gd` |
| `assets/audio` | Every sound effect and music loop, synthesised in the spirit of Azerbaijani mugham (Şur, tar, kamança, nağara, qaval) | `tools/gen_audio.py` |
| `world/terrain` | The valley's terrain and meta | `tools/gen_world.gd` |
| NPC voice lines | edge-tts Turkish neural voices — **prototypes, to be replaced before release** | `tools/gen_voices.py` |

## Engine and addons

| What | Source | Licence |
|---|---|---|
| Godot Engine 4.7.2 | godotengine.org | MIT |
| Terrain3D 1.0.2 (`addons/terrain_3d`) | github.com/TokisanGames/Terrain3D | MIT |
