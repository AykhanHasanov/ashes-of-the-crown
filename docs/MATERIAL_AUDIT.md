# Material audit (art-lighting, part 1)

Rule (scripts/core/material_policy.gd): a non-metal is `metallic = 0` and `roughness >= 0.7`. Values an ORM / metallic
texture drives are left to the texture (outfits: metal only on buckles, 1.6–6 % of pixels). Real metal (by material
name) keeps its values; glass, water and eyes lose metallic but stay glossy. Applied at glTF import
(`tools/import/material_policy_import.gd`) and to baked foliage (`tools/fix_materials.gd`; the foliage generators apply
it too). Check: `godot --headless --path . -s tools/audit_materials.gd` (now 0 violations of 1822 materials).

## Exceptions: keeping a material exactly as authored

The rule runs on every model at import, so an asset that is metal on purpose (a sword, armour, a lantern) needs a way
to say "do not touch". A material is left alone when ANY of these holds (data: `data/art/material_policy.json`):

1. **The `_keep` suffix** on the material's name — the artist's mark, set in Blender: `Steel_keep`, `Plate_keep`.
   This is the normal way for new assets: it travels with the model, needs no project change, and is visible in the
   audit as `(keep)`.
2. **`keep_materials`** — exact material names, for third-party files that cannot be renamed.
3. **`keep_models`** — model path patterns with `*` (e.g. `res://assets/weapons/*`): every material of those models.
4. **`metal_hints`** — a metal word in the material's name (`metal`, `iron`, `steel`, `sword`, `blade`, `armor`,
   `lantern` ...), shown as `(metal)` in the audit. This is what already protects the existing packs' metal parts.

Also: `glossy_hints` names (glass, water, eyes) lose `metallic` but keep their `roughness`; values driven by a
metallic / ORM / roughness texture are never touched.

**Why marks and not "only the Quaternius folder":** the materials that broke the rule came from six sources, not one
(Quaternius packs, the KayKit adventurers and skeletons, both MegaKits' glass, the dungeon set, the baked foliage).
A folder rule would have let the next imported pack through unchecked. With marks the default is safe for everything
new, and the exception is an explicit decision recorded on the asset or in one data file.

After changing the exceptions, re-import the models (delete the model's files under `.godot/imported/` or reimport in
the editor) and run the audit: `godot --headless --path . -s tools/audit_materials.gd`.

## Kept by the keyword rule (review list)

211 materials in 158 models are left as authored only because a metal word is in their
name. They are listed here so a wrong match is easy to spot (a cloth called "GoldenThread" would show up). Checked
2026-09-30: all 13 names are real metal. Regenerate with the audit (`KEYWORD` lines).

| Material | Matched word | metallic / roughness | Models |
|---|---|---|---|
| `DarkMetal` | metal | 0.40 / 0.42 | 9 |
| `DarkSteel` | steel | 0.40 / 0.42 | 16 |
| `Gold` | gold | 0.40 / 0.42 | 22 |
| `Gold.001` | gold | 0.40 / 0.42 | 1 |
| `Golden` | gold | 0.40 / 0.42 | 22 |
| `LightGold` | gold | 0.40 / 0.42 | 7 |
| `LightMetal` | metal | 0.40 / 0.42 | 5 |
| `LightSteel` | steel | 0.40 / 0.42 | 21 |
| `MI_MetalOrnaments` | metal | 1.00 / 1.00 | 9 |
| `MI_Trim_Metal` | metal | 1.00 / 1.00 | 55 |
| `MI_Trim_Metal_Vertex` | metal | 1.00 / 1.00 | 5 |
| `Metal` | metal | 0.40 / 0.42 | 15 |
| `Steel` | steel | 0.40 / 0.42 | 24 |

<details><summary>Every model, by material</summary>

**`DarkMetal`** (word: metal) — `quaternius/medieval_village_pack/Cauldron.glb`, `quaternius/rpg_items_pack/Chest_Closed.glb`, `quaternius/rpg_items_pack/Chest_Ingots.glb`, `quaternius/rpg_items_pack/Chest_Open.glb`, `quaternius/survival_pack/Pistol_1.glb`, `quaternius/survival_pack/Shotgun_1.glb`, `quaternius/survival_pack/Shotgun_2.glb`, `quaternius/survival_pack/Shotgun_SawedOff.glb`, `quaternius/survival_pack/Shotgun_ShortStock.glb`

**`DarkSteel`** (word: steel) — `quaternius/medieval_weapons_pack/Claymore.glb`, `quaternius/medieval_weapons_pack/Dagger.glb`, `quaternius/medieval_weapons_pack/Sword.glb`, `quaternius/medieval_weapons_pack/Sword_2.glb`, `quaternius/medieval_weapons_pack/Sword_Big.glb`, `quaternius/medieval_weapons_pack/Sword_Golden.glb`, `quaternius/modular_dungeon_pack/Chest.glb`, `quaternius/modular_dungeon_pack/Chest_gold.glb`, `quaternius/modular_dungeon_pack/Torch.glb`, `quaternius/modular_dungeon_pack/Torch_wall.glb`, `quaternius/modular_dungeon_pack/Window.glb`, `quaternius/rpg_items_pack/Armor_Metal.glb`, `quaternius/rpg_items_pack/Dagger_Golden.glb`, `quaternius/rpg_items_pack/Key3.glb`, `quaternius/rpg_items_pack/Sword_big.glb`, `quaternius/rpg_items_pack/Sword_big_Golden.glb`

**`Gold`** (word: gold) — `quaternius/medieval_weapons_pack/Bow_Golden.glb`, `quaternius/medieval_weapons_pack/Dagger_2.glb`, `quaternius/medieval_weapons_pack/Shield_Celtic_Golden.glb`, `quaternius/medieval_weapons_pack/Sword_Golden.glb`, `quaternius/modular_dungeon_pack/Candelabrum.glb`, `quaternius/modular_dungeon_pack/Candelabrum_tall.glb`, `quaternius/modular_dungeon_pack/Carpet.glb`, `quaternius/modular_dungeon_pack/Chest_gold.glb`, `quaternius/modular_dungeon_pack/Potion.glb`, `quaternius/rpg_items_pack/Backpack.glb`, `quaternius/rpg_items_pack/Bag.glb`, `quaternius/rpg_items_pack/Book3_Closed.glb`, `quaternius/rpg_items_pack/Book3_Open.glb`, `quaternius/rpg_items_pack/Chalice.glb`, `quaternius/rpg_items_pack/Chest_Ingots.glb`, `quaternius/rpg_items_pack/Coin.glb`, `quaternius/rpg_items_pack/Coin_Skull.glb`, `quaternius/rpg_items_pack/Coin_Star.glb`, `quaternius/rpg_items_pack/Crown.glb`, `quaternius/rpg_items_pack/Crown2.glb`, `quaternius/rpg_items_pack/Gold_Ingots.glb`, `quaternius/rpg_items_pack/Star.glb`

**`Gold.001`** (word: gold) — `quaternius/modular_dungeon_pack/Candle.glb`

**`Golden`** (word: gold) — `quaternius/rpg_items_pack/Armor_Golden.glb`, `quaternius/rpg_items_pack/Arrow_Golden.glb`, `quaternius/rpg_items_pack/Axe_Double_Golden.glb`, `quaternius/rpg_items_pack/Axe_small_Golden.glb`, `quaternius/rpg_items_pack/Book2_Closed.glb`, `quaternius/rpg_items_pack/Book2_Open.glb`, `quaternius/rpg_items_pack/Bow_Golden.glb`, `quaternius/rpg_items_pack/Dagger_Golden.glb`, `quaternius/rpg_items_pack/Dart_Golden.glb`, `quaternius/rpg_items_pack/Hammer_Double_Golden.glb`, `quaternius/rpg_items_pack/Key4.glb`, `quaternius/rpg_items_pack/Necklace1.glb`, `quaternius/rpg_items_pack/Necklace2.glb`, `quaternius/rpg_items_pack/Necklace3.glb`, `quaternius/rpg_items_pack/Ring1.glb`, `quaternius/rpg_items_pack/Ring2.glb`, `quaternius/rpg_items_pack/Ring3.glb`, `quaternius/rpg_items_pack/Ring4.glb`, `quaternius/rpg_items_pack/Ring5.glb`, `quaternius/rpg_items_pack/Ring6.glb`, `quaternius/rpg_items_pack/Sword_Golden.glb`, `quaternius/rpg_items_pack/Sword_big_Golden.glb`

**`LightGold`** (word: gold) — `quaternius/medieval_weapons_pack/Shield_Celtic_Golden.glb`, `quaternius/medieval_weapons_pack/Sword_Golden.glb`, `quaternius/rpg_items_pack/Axe_Double_Golden.glb`, `quaternius/rpg_items_pack/Axe_small_Golden.glb`, `quaternius/rpg_items_pack/Dagger_Golden.glb`, `quaternius/rpg_items_pack/Hammer_Double_Golden.glb`, `quaternius/rpg_items_pack/Sword_big_Golden.glb`

**`LightMetal`** (word: metal) — `quaternius/survival_pack/Pistol_2.glb`, `quaternius/survival_pack/Revolver_1.glb`, `quaternius/survival_pack/Revolver_2.glb`, `quaternius/survival_pack/Revolver_3.glb`, `quaternius/survival_pack/Shotgun_1.glb`

**`LightSteel`** (word: steel) — `quaternius/medieval_weapons_pack/Arrow.glb`, `quaternius/medieval_weapons_pack/Axe.glb`, `quaternius/medieval_weapons_pack/Axe_Double.glb`, `quaternius/medieval_weapons_pack/Axe_Small.glb`, `quaternius/medieval_weapons_pack/Dagger.glb`, `quaternius/medieval_weapons_pack/Dagger_2.glb`, `quaternius/medieval_weapons_pack/Hammer_Double.glb`, `quaternius/medieval_weapons_pack/Hammer_Small.glb`, `quaternius/medieval_weapons_pack/Scythe.glb`, `quaternius/medieval_weapons_pack/Shield_Heater.glb`, `quaternius/medieval_weapons_pack/Shield_Heater_2.glb`, `quaternius/medieval_weapons_pack/Shield_Round.glb`, `quaternius/medieval_weapons_pack/Shield_Round_2.glb`, `quaternius/medieval_weapons_pack/Spear.glb`, `quaternius/medieval_weapons_pack/Sword.glb`, `quaternius/medieval_weapons_pack/Sword_2.glb`, `quaternius/medieval_weapons_pack/Sword_Big.glb`, `quaternius/rpg_items_pack/Armor_Metal2.glb`, `quaternius/rpg_items_pack/Axe_small.glb`, `quaternius/rpg_items_pack/Dart.glb`, `quaternius/rpg_items_pack/Sword_big.glb`

**`MI_MetalOrnaments`** (word: metal) — `village_mk/Door_2_Flat.gltf`, `village_mk/Door_2_Round.gltf`, `village_mk/Door_4_Flat.gltf`, `village_mk/Door_4_Round.gltf`, `village_mk/Door_8_Flat.gltf`, `village_mk/Door_8_Round.gltf`, `village_mk/Prop_MetalFence_Ornament.gltf`, `village_mk/Prop_MetalFence_Simple.gltf`, `village_mk/Roof_Tower_RoundTiles.gltf`

**`MI_Trim_Metal`** (word: metal) — `props_mk/Anvil.gltf`, `props_mk/Anvil_Log.gltf`, `props_mk/Banner_1.gltf`, `props_mk/Banner_1_Cloth.gltf`, `props_mk/Banner_2.gltf`, `props_mk/Banner_2_Cloth.gltf`, `props_mk/Barrel.gltf`, `props_mk/Barrel_Apples.gltf`, `props_mk/Barrel_Holder.gltf`, `props_mk/Bed_Twin1.gltf`, `props_mk/Bed_Twin2.gltf`, `props_mk/Bench.gltf`, `props_mk/Book_7.gltf`, `props_mk/Book_Stack_2.gltf`, `props_mk/Bookcase_2.gltf`, `props_mk/Bucket_Metal.gltf`, `props_mk/Bucket_Wooden_1.gltf`, `props_mk/Cabinet.gltf`, `props_mk/Cage_Small.gltf`, `props_mk/CandleStick.gltf`, `props_mk/CandleStick_Stand.gltf`, `props_mk/CandleStick_Triple.gltf`, `props_mk/Cauldron.gltf`, `props_mk/Chain_Coil.gltf`, `props_mk/Chair_1.gltf`, `props_mk/Chalice.gltf`, `props_mk/Chandelier.gltf`, `props_mk/Chest_Wood.gltf`, `props_mk/Crate_Metal.gltf`, `props_mk/Crate_Wooden.gltf`, `props_mk/Dummy.gltf`, `props_mk/FarmCrate_Apple.gltf`, `props_mk/FarmCrate_Carrot.gltf`, `props_mk/FarmCrate_Empty.gltf`, `props_mk/Key_Metal.gltf`, `props_mk/Lantern_Wall.gltf`, `props_mk/Mug.gltf`, `props_mk/Peg_Rack.gltf`, `props_mk/Pot_1.gltf`, `props_mk/Pot_1_Lid.gltf`, `props_mk/Pouch_Large.gltf`, `props_mk/Shelf_Arch.gltf`, `props_mk/Shelf_Small_Bottles.gltf`, `props_mk/Stall_Cart_Empty.gltf`, `props_mk/Stall_Empty.gltf`, `props_mk/Table_Fork.gltf`, `props_mk/Table_Knife.gltf`, `props_mk/Table_Large.gltf`, `props_mk/Table_Plate.gltf`, `props_mk/Table_Spoon.gltf`, `props_mk/Torch_Metal.gltf`, `props_mk/WeaponStand.gltf`, `props_mk/Whetstone.gltf`, `props_mk/Workbench.gltf`, `props_mk/Workbench_Drawers.gltf`

**`MI_Trim_Metal_Vertex`** (word: metal) — `props_mk/Coin.gltf`, `props_mk/Coin_Pile.gltf`, `props_mk/Coin_Pile_2.gltf`, `props_mk/Key_Gold.gltf`, `props_mk/Shield_Wooden.gltf`

**`Metal`** (word: metal) — `quaternius/medieval_village_pack/Door_Straight.glb`, `quaternius/medieval_village_pack/Sawmill.glb`, `quaternius/medieval_village_pack/Sawmill_saw.glb`, `quaternius/rpg_items_pack/Chest_Closed.glb`, `quaternius/rpg_items_pack/Chest_Ingots.glb`, `quaternius/rpg_items_pack/Chest_Open.glb`, `quaternius/survival_pack/Pistol_1.glb`, `quaternius/survival_pack/Pistol_2.glb`, `quaternius/survival_pack/Revolver_1.glb`, `quaternius/survival_pack/Revolver_2.glb`, `quaternius/survival_pack/Revolver_3.glb`, `quaternius/survival_pack/Shotgun_1.glb`, `quaternius/survival_pack/Shotgun_2.glb`, `quaternius/survival_pack/Shotgun_SawedOff.glb`, `quaternius/survival_pack/Shotgun_ShortStock.glb`

**`Steel`** (word: steel) — `quaternius/medieval_weapons_pack/Arrow.glb`, `quaternius/medieval_weapons_pack/Axe.glb`, `quaternius/medieval_weapons_pack/Axe_Double.glb`, `quaternius/medieval_weapons_pack/Axe_Small.glb`, `quaternius/medieval_weapons_pack/Dagger.glb`, `quaternius/medieval_weapons_pack/Dagger_2.glb`, `quaternius/medieval_weapons_pack/Hammer_Double.glb`, `quaternius/medieval_weapons_pack/Hammer_Small.glb`, `quaternius/medieval_weapons_pack/Scythe.glb`, `quaternius/medieval_weapons_pack/Shield_Heater.glb`, `quaternius/medieval_weapons_pack/Shield_Heater_2.glb`, `quaternius/medieval_weapons_pack/Shield_Round.glb`, `quaternius/medieval_weapons_pack/Shield_Round_2.glb`, `quaternius/medieval_weapons_pack/Spear.glb`, `quaternius/medieval_weapons_pack/Sword.glb`, `quaternius/medieval_weapons_pack/Sword_2.glb`, `quaternius/medieval_weapons_pack/Sword_Big.glb`, `quaternius/modular_dungeon_pack/Barrel.glb`, `quaternius/modular_dungeon_pack/Bars.glb`, `quaternius/modular_dungeon_pack/Chest.glb`, `quaternius/modular_dungeon_pack/Chest_gold.glb`, `quaternius/rpg_items_pack/Axe_small.glb`, `quaternius/rpg_items_pack/Dart.glb`, `quaternius/rpg_items_pack/Sword_big.glb`

</details>

**1145 materials changed.** Most common before → after:

- 940 × metallic 0.40, roughness 0.42 → metallic 0.00, roughness 0.70
- 105 × metallic 0.40, roughness 1.00 → metallic 0.00, roughness 1.00
- 45 × metallic 0.00, roughness 0.45 → metallic 0.00, roughness 0.70
- 20 × metallic 0.40, roughness 0.42 → metallic 0.00, roughness 0.42
- 18 × metallic 0.00, roughness 0.50 → metallic 0.00, roughness 0.70
- 14 × metallic 0.00, roughness 0.60 → metallic 0.00, roughness 0.70
- 3 × metallic 1.00, roughness 1.00 → metallic 0.00, roughness 1.00

## By folder

### quaternius/nature_pack (347)

- `BirchTree_1.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_1.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `BirchTree_1.glb` Green: 0.40/0.42 → 0.00/0.70
- `BirchTree_1.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_2.glb` Black.001: 0.40/0.42 → 0.00/0.70
- `BirchTree_2.glb` DarkGreen.001: 0.40/0.42 → 0.00/0.70
- `BirchTree_2.glb` Green.001: 0.40/0.42 → 0.00/0.70
- `BirchTree_2.glb` White.001: 0.40/0.42 → 0.00/0.70
- `BirchTree_3.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_3.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `BirchTree_3.glb` Green: 0.40/0.42 → 0.00/0.70
- `BirchTree_3.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_4.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_4.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `BirchTree_4.glb` Green: 0.40/0.42 → 0.00/0.70
- `BirchTree_4.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_5.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_5.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `BirchTree_5.glb` Green: 0.40/0.42 → 0.00/0.70
- `BirchTree_5.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_Autumn_1.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_Autumn_1.glb` LightOrange: 0.40/0.42 → 0.00/0.70
- `BirchTree_Autumn_1.glb` Orange: 0.40/0.42 → 0.00/0.70
- `BirchTree_Autumn_1.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_Autumn_2.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_Autumn_2.glb` LightOrange: 0.40/0.42 → 0.00/0.70
- `BirchTree_Autumn_2.glb` Orange: 0.40/0.42 → 0.00/0.70
- `BirchTree_Autumn_2.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_Autumn_3.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_Autumn_3.glb` LightOrange: 0.40/0.42 → 0.00/0.70
- `BirchTree_Autumn_3.glb` Orange: 0.40/0.42 → 0.00/0.70
- `BirchTree_Autumn_3.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_Autumn_4.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_Autumn_4.glb` LightOrange: 0.40/0.42 → 0.00/0.70
- `BirchTree_Autumn_4.glb` Orange: 0.40/0.42 → 0.00/0.70
- `BirchTree_Autumn_4.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_Autumn_5.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_Autumn_5.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `BirchTree_Autumn_5.glb` Orange: 0.40/0.42 → 0.00/0.70
- `BirchTree_Autumn_5.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_1.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_1.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_2.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_2.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_3.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_3.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_4.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_4.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_5.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_5.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_Snow_1.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_Snow_1.glb` Snow: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_Snow_1.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_Snow_2.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_Snow_2.glb` Snow: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_Snow_2.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_Snow_3.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_Snow_3.glb` Snow: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_Snow_3.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_Snow_4.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_Snow_4.glb` Snow: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_Snow_4.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_Snow_5.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_Snow_5.glb` Snow: 0.40/0.42 → 0.00/0.70
- `BirchTree_Dead_Snow_5.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_1.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_1.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_1.glb` Green: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_1.glb` Snow: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_1.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_2.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_2.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_2.glb` Green: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_2.glb` Snow: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_2.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_3.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_3.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_3.glb` Green: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_3.glb` Snow: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_3.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_4.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_4.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_4.glb` Green: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_4.glb` Snow: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_4.glb` White: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_5.glb` Black: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_5.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_5.glb` Green: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_5.glb` Snow: 0.40/0.42 → 0.00/0.70
- `BirchTree_Snow_5.glb` White: 0.40/0.42 → 0.00/0.70
- `BushBerries_1.glb` Berry: 0.40/0.42 → 0.00/0.70
- `BushBerries_1.glb` Green: 0.40/0.42 → 0.00/0.70
- `BushBerries_2.glb` Berry: 0.40/0.42 → 0.00/0.70
- `BushBerries_2.glb` Green: 0.40/0.42 → 0.00/0.70
- `Bush_1.glb` Green: 0.40/0.42 → 0.00/0.70
- `Bush_2.glb` Green: 0.40/0.42 → 0.00/0.70
- `Bush_Snow_1.glb` Green: 0.40/0.42 → 0.00/0.70
- `Bush_Snow_1.glb` Snow: 0.40/0.42 → 0.00/0.70
- `Bush_Snow_2.glb` Green: 0.40/0.42 → 0.00/0.70
- `Bush_Snow_2.glb` Snow: 0.40/0.42 → 0.00/0.70
- `CactusFlower_1.glb` Green: 0.40/0.42 → 0.00/0.70
- `CactusFlowers_2.glb` Green: 0.40/0.42 → 0.00/0.70
- `CactusFlowers_2.glb` Pink: 0.40/0.42 → 0.00/0.70
- `CactusFlowers_3.glb` Green: 0.40/0.42 → 0.00/0.70
- `CactusFlowers_3.glb` Pink: 0.40/0.42 → 0.00/0.70
- `CactusFlowers_4.glb` Green: 0.40/0.42 → 0.00/0.70
- `CactusFlowers_4.glb` Pink: 0.40/0.42 → 0.00/0.70
- `CactusFlowers_5.glb` Green: 0.40/0.42 → 0.00/0.70
- `CactusFlowers_5.glb` Pink: 0.40/0.42 → 0.00/0.70
- `Cactus_1.glb` Green: 0.40/0.42 → 0.00/0.70
- `Cactus_1.glb` LightOrange: 0.40/0.42 → 0.00/0.70
- `Cactus_2.glb` Green: 0.40/0.42 → 0.00/0.70
- `Cactus_3.glb` Green: 0.40/0.42 → 0.00/0.70
- `Cactus_4.glb` Green: 0.40/0.42 → 0.00/0.70
- `Cactus_5.glb` Green: 0.40/0.42 → 0.00/0.70
- `CommonTree_1.glb` Green: 0.40/0.42 → 0.00/0.70
- `CommonTree_1.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_2.glb` Green: 0.40/0.42 → 0.00/0.70
- `CommonTree_2.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_3.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `CommonTree_3.glb` Green: 0.40/0.42 → 0.00/0.70
- `CommonTree_3.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_4.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `CommonTree_4.glb` Green: 0.40/0.42 → 0.00/0.70
- `CommonTree_4.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_5.glb` Green: 0.40/0.42 → 0.00/0.70
- `CommonTree_5.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_Autumn_1.glb` Orange: 0.40/0.42 → 0.00/0.70
- `CommonTree_Autumn_1.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_Autumn_2.glb` LightOrange: 0.40/0.42 → 0.00/0.70
- `CommonTree_Autumn_2.glb` Orange: 0.40/0.42 → 0.00/0.70
- `CommonTree_Autumn_2.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_Autumn_3.glb` LightOrange: 0.40/0.42 → 0.00/0.70
- `CommonTree_Autumn_3.glb` Orange: 0.40/0.42 → 0.00/0.70
- `CommonTree_Autumn_3.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_Autumn_4.glb` LightOrange: 0.40/0.42 → 0.00/0.70
- `CommonTree_Autumn_4.glb` Orange: 0.40/0.42 → 0.00/0.70
- `CommonTree_Autumn_4.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_Autumn_5.glb` Orange: 0.40/0.42 → 0.00/0.70
- `CommonTree_Autumn_5.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_Dead_1.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_Dead_2.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_Dead_3.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_Dead_4.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_Dead_5.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_Dead_Snow_1.glb` Snow: 0.40/0.42 → 0.00/0.70
- `CommonTree_Dead_Snow_1.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_Dead_Snow_2.glb` Snow: 0.40/0.42 → 0.00/0.70
- `CommonTree_Dead_Snow_2.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_Dead_Snow_3.glb` Snow: 0.40/0.42 → 0.00/0.70
- `CommonTree_Dead_Snow_3.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_Dead_Snow_4.glb` Snow: 0.40/0.42 → 0.00/0.70
- `CommonTree_Dead_Snow_4.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_Dead_Snow_5.glb` Snow.002: 0.40/0.42 → 0.00/0.70
- `CommonTree_Dead_Snow_5.glb` Wood.002: 0.40/0.42 → 0.00/0.70
- `CommonTree_Snow_1.glb` Green: 0.40/0.42 → 0.00/0.70
- `CommonTree_Snow_1.glb` Snow: 0.40/0.42 → 0.00/0.70
- `CommonTree_Snow_1.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_Snow_2.glb` Green: 0.40/0.42 → 0.00/0.70
- `CommonTree_Snow_2.glb` Snow: 0.40/0.42 → 0.00/0.70
- `CommonTree_Snow_2.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_Snow_3.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `CommonTree_Snow_3.glb` Green: 0.40/0.42 → 0.00/0.70
- `CommonTree_Snow_3.glb` Snow: 0.40/0.42 → 0.00/0.70
- `CommonTree_Snow_3.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_Snow_4.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `CommonTree_Snow_4.glb` Green: 0.40/0.42 → 0.00/0.70
- `CommonTree_Snow_4.glb` Snow: 0.40/0.42 → 0.00/0.70
- `CommonTree_Snow_4.glb` Wood: 0.40/0.42 → 0.00/0.70
- `CommonTree_Snow_5.glb` Green: 0.40/0.42 → 0.00/0.70
- `CommonTree_Snow_5.glb` Snow: 0.40/0.42 → 0.00/0.70
- `CommonTree_Snow_5.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Corn_1.glb` Green: 0.40/0.42 → 0.00/0.70
- `Corn_2.glb` Green: 0.40/0.42 → 0.00/0.70
- `Corn_2.glb` Yellow: 0.40/0.42 → 0.00/0.70
- `Flowers.glb` Cyan: 0.40/0.42 → 0.00/0.70
- `Flowers.glb` Green: 0.40/0.42 → 0.00/0.70
- `Flowers.glb` Yellow: 0.40/0.42 → 0.00/0.70
- `Grass.glb` Green: 0.40/0.42 → 0.00/0.70
- `Grass_2.glb` Green: 0.40/0.42 → 0.00/0.70
- `Grass_Short.glb` Green: 0.40/0.42 → 0.00/0.70
- `Lilypad.glb` Green: 0.40/0.42 → 0.00/0.70
- `Lilypad.glb` Pink: 0.40/0.42 → 0.00/0.70
- `PalmTree_1.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `PalmTree_1.glb` Green: 0.40/0.42 → 0.00/0.70
- `PalmTree_1.glb` Wood: 0.40/0.42 → 0.00/0.70
- `PalmTree_2.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `PalmTree_2.glb` Green: 0.40/0.42 → 0.00/0.70
- `PalmTree_2.glb` Wood: 0.40/0.42 → 0.00/0.70
- `PalmTree_3.glb` Coconuts: 0.40/0.42 → 0.00/0.70
- `PalmTree_3.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `PalmTree_3.glb` Green: 0.40/0.42 → 0.00/0.70
- `PalmTree_3.glb` Wood: 0.40/0.42 → 0.00/0.70
- `PalmTree_4.glb` Coconuts: 0.40/0.42 → 0.00/0.70
- `PalmTree_4.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `PalmTree_4.glb` Green: 0.40/0.42 → 0.00/0.70
- `PalmTree_4.glb` Wood: 0.40/0.42 → 0.00/0.70
- `PineTree_1.glb` Green: 0.40/0.42 → 0.00/0.70
- `PineTree_1.glb` Wood: 0.40/0.42 → 0.00/0.70
- `PineTree_2.glb` Green: 0.40/0.42 → 0.00/0.70
- `PineTree_2.glb` Wood: 0.40/0.42 → 0.00/0.70
- `PineTree_3.glb` Green: 0.40/0.42 → 0.00/0.70
- `PineTree_3.glb` Wood: 0.40/0.42 → 0.00/0.70
- `PineTree_4.glb` Green: 0.40/0.42 → 0.00/0.70
- `PineTree_4.glb` Wood: 0.40/0.42 → 0.00/0.70
- `PineTree_5.glb` Green: 0.40/0.42 → 0.00/0.70
- `PineTree_5.glb` Wood: 0.40/0.42 → 0.00/0.70
- `PineTree_Autumn_1.glb` LightOrange: 0.40/0.42 → 0.00/0.70
- `PineTree_Autumn_1.glb` Orange: 0.40/0.42 → 0.00/0.70
- `PineTree_Autumn_1.glb` Wood: 0.40/0.42 → 0.00/0.70
- `PineTree_Autumn_2.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `PineTree_Autumn_2.glb` Orange: 0.40/0.42 → 0.00/0.70
- `PineTree_Autumn_2.glb` Wood: 0.40/0.42 → 0.00/0.70
- `PineTree_Autumn_3.glb` LightOrange: 0.40/0.42 → 0.00/0.70
- `PineTree_Autumn_3.glb` Orange: 0.40/0.42 → 0.00/0.70
- `PineTree_Autumn_3.glb` Wood: 0.40/0.42 → 0.00/0.70
- `PineTree_Autumn_4.glb` LightOrange: 0.40/0.42 → 0.00/0.70
- `PineTree_Autumn_4.glb` Orange: 0.40/0.42 → 0.00/0.70
- `PineTree_Autumn_4.glb` Wood: 0.40/0.42 → 0.00/0.70
- `PineTree_Autumn_5.glb` LightOrange: 0.40/0.42 → 0.00/0.70
- `PineTree_Autumn_5.glb` Orange: 0.40/0.42 → 0.00/0.70
- `PineTree_Autumn_5.glb` Wood: 0.40/0.42 → 0.00/0.70
- `PineTree_Snow_1.glb` Green: 0.40/0.42 → 0.00/0.70
- `PineTree_Snow_1.glb` Snow: 0.40/0.42 → 0.00/0.70
- `PineTree_Snow_1.glb` Wood: 0.40/0.42 → 0.00/0.70
- `PineTree_Snow_2.glb` Green: 0.40/0.42 → 0.00/0.70
- `PineTree_Snow_2.glb` Snow: 0.40/0.42 → 0.00/0.70
- `PineTree_Snow_2.glb` Wood: 0.40/0.42 → 0.00/0.70
- `PineTree_Snow_3.glb` Green: 0.40/0.42 → 0.00/0.70
- `PineTree_Snow_3.glb` Snow: 0.40/0.42 → 0.00/0.70
- `PineTree_Snow_3.glb` Wood: 0.40/0.42 → 0.00/0.70
- `PineTree_Snow_4.glb` Green: 0.40/0.42 → 0.00/0.70
- `PineTree_Snow_4.glb` Snow: 0.40/0.42 → 0.00/0.70
- `PineTree_Snow_4.glb` Wood: 0.40/0.42 → 0.00/0.70
- `PineTree_Snow_5.glb` Green: 0.40/0.42 → 0.00/0.70
- `PineTree_Snow_5.glb` Snow: 0.40/0.42 → 0.00/0.70
- `PineTree_Snow_5.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Plant_1.glb` Green: 0.40/0.42 → 0.00/0.70
- `Plant_2.glb` Leaves: 0.40/0.42 → 0.00/0.70
- `Plant_2.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Plant_3.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `Plant_4.glb` Green: 0.40/0.42 → 0.00/0.70
- `Plant_5.glb` Pink: 0.40/0.42 → 0.00/0.70
- `Plant_5.glb` Yellow: 0.40/0.42 → 0.00/0.70
- `Rock_1.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Rock_2.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Rock_3.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Rock_4.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Rock_5.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Rock_6.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Rock_7.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Rock_Moss_1.glb` Green: 0.40/0.42 → 0.00/0.70
- `Rock_Moss_1.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Rock_Moss_2.glb` Green: 0.40/0.42 → 0.00/0.70
- `Rock_Moss_2.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Rock_Moss_3.glb` Green: 0.40/0.42 → 0.00/0.70
- `Rock_Moss_3.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Rock_Moss_4.glb` Green: 0.40/0.42 → 0.00/0.70
- `Rock_Moss_4.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Rock_Moss_5.glb` Green: 0.40/0.42 → 0.00/0.70
- `Rock_Moss_5.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Rock_Moss_6.glb` Green: 0.40/0.42 → 0.00/0.70
- `Rock_Moss_6.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Rock_Moss_7.glb` Green: 0.40/0.42 → 0.00/0.70
- `Rock_Moss_7.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Rock_Snow_1.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Rock_Snow_1.glb` Snow: 0.40/0.42 → 0.00/0.70
- `Rock_Snow_2.glb` Rock.001: 0.40/0.42 → 0.00/0.70
- `Rock_Snow_2.glb` Snow.001: 0.40/0.42 → 0.00/0.70
- `Rock_Snow_3.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Rock_Snow_3.glb` Snow: 0.40/0.42 → 0.00/0.70
- `Rock_Snow_4.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Rock_Snow_4.glb` Snow: 0.40/0.42 → 0.00/0.70
- `Rock_Snow_5.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Rock_Snow_5.glb` Snow: 0.40/0.42 → 0.00/0.70
- `Rock_Snow_6.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Rock_Snow_6.glb` Snow: 0.40/0.42 → 0.00/0.70
- `Rock_Snow_7.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Rock_Snow_7.glb` Snow: 0.40/0.42 → 0.00/0.70
- `TreeStump.glb` Green: 0.40/0.42 → 0.00/0.70
- `TreeStump.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `TreeStump.glb` Wood: 0.40/0.42 → 0.00/0.70
- `TreeStump_Moss.glb` Green: 0.40/0.42 → 0.00/0.70
- `TreeStump_Moss.glb` Wood: 0.40/0.42 → 0.00/0.70
- `TreeStump_Snow.glb` Snow: 0.40/0.42 → 0.00/0.70
- `TreeStump_Snow.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Wheat.glb` Yellow: 0.40/0.42 → 0.00/0.70
- `Willow_1.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `Willow_1.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_2.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `Willow_2.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_3.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `Willow_3.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_4.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `Willow_4.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_5.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `Willow_5.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_Autumn_1.glb` Orange: 0.40/0.42 → 0.00/0.70
- `Willow_Autumn_1.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_Autumn_2.glb` Orange: 0.40/0.42 → 0.00/0.70
- `Willow_Autumn_2.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_Autumn_3.glb` Orange: 0.40/0.42 → 0.00/0.70
- `Willow_Autumn_3.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_Autumn_4.glb` Orange: 0.40/0.42 → 0.00/0.70
- `Willow_Autumn_4.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_Autumn_5.glb` Orange: 0.40/0.42 → 0.00/0.70
- `Willow_Autumn_5.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_Dead_1.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_Dead_2.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_Dead_3.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_Dead_4.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_Dead_5.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_Dead_Snow_1.glb` Snow: 0.40/0.42 → 0.00/0.70
- `Willow_Dead_Snow_1.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_Dead_Snow_2.glb` Snow: 0.40/0.42 → 0.00/0.70
- `Willow_Dead_Snow_2.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_Dead_Snow_3.glb` Snow: 0.40/0.42 → 0.00/0.70
- `Willow_Dead_Snow_3.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_Dead_Snow_4.glb` Snow: 0.40/0.42 → 0.00/0.70
- `Willow_Dead_Snow_4.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_Dead_Snow_5.glb` Snow: 0.40/0.42 → 0.00/0.70
- `Willow_Dead_Snow_5.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_Snow_1.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `Willow_Snow_1.glb` Snow: 0.40/0.42 → 0.00/0.70
- `Willow_Snow_1.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_Snow_2.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `Willow_Snow_2.glb` Snow: 0.40/0.42 → 0.00/0.70
- `Willow_Snow_2.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_Snow_3.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `Willow_Snow_3.glb` Snow: 0.40/0.42 → 0.00/0.70
- `Willow_Snow_3.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_Snow_4.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `Willow_Snow_4.glb` Snow: 0.40/0.42 → 0.00/0.70
- `Willow_Snow_4.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Willow_Snow_5.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `Willow_Snow_5.glb` Snow: 0.40/0.42 → 0.00/0.70
- `Willow_Snow_5.glb` Wood: 0.40/0.42 → 0.00/0.70
- `WoodLog.glb` Mushroom_Bottom: 0.40/0.42 → 0.00/0.70
- `WoodLog.glb` Mushroom_Top: 0.40/0.42 → 0.00/0.70
- `WoodLog.glb` Wood: 0.40/0.42 → 0.00/0.70
- `WoodLog_Moss.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `WoodLog_Moss.glb` Green: 0.40/0.42 → 0.00/0.70
- `WoodLog_Moss.glb` Mushroom_Bottom: 0.40/0.42 → 0.00/0.70
- `WoodLog_Moss.glb` Mushroom_Top: 0.40/0.42 → 0.00/0.70
- `WoodLog_Moss.glb` Wood: 0.40/0.42 → 0.00/0.70
- `WoodLog_Snow.glb` Snow: 0.40/0.42 → 0.00/0.70
- `WoodLog_Snow.glb` Wood: 0.40/0.42 → 0.00/0.70

### quaternius/medieval_village_pack (167)

- `Bag.glb` Bag: 0.40/0.42 → 0.00/0.70
- `Bag_Open.glb` Bag: 0.40/0.42 → 0.00/0.70
- `Bag_Open.glb` Bag_Inside: 0.40/0.42 → 0.00/0.70
- `Bags.glb` Bag: 0.40/0.42 → 0.00/0.70
- `Barrel.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Barrel.glb` Stone: 0.40/0.42 → 0.00/0.70
- `Barrel.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Bell.glb` Bell: 0.40/0.42 → 0.00/0.70
- `Bell_Tower.glb` Beige: 0.40/0.42 → 0.00/0.70
- `Bell_Tower.glb` Bell: 0.40/0.42 → 0.00/0.70
- `Bell_Tower.glb` RoofTiles: 0.40/0.42 → 0.00/0.70
- `Bell_Tower.glb` Stone: 0.40/0.42 → 0.00/0.70
- `Bell_Tower.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `Bell_Tower.glb` Stone_Light: 0.40/0.42 → 0.00/0.70
- `Bell_Tower.glb` Windows: 0.40/0.42 → 0.00/0.70
- `Bell_Tower.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Bell_Tower.glb` Wood_Light: 0.40/0.42 → 0.00/0.70
- `Bell_Tower.glb` Wood_Side: 0.40/0.42 → 0.00/0.70
- `Bench_1.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Bench_2.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Blacksmith.glb` Plaster: 0.40/0.42 → 0.00/0.70
- `Blacksmith.glb` RoofTiles_Red: 0.40/0.42 → 0.00/0.70
- `Blacksmith.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `Blacksmith.glb` Stone_Light: 0.40/0.42 → 0.00/0.70
- `Blacksmith.glb` Windows: 0.40/0.42 → 0.00/0.70
- `Blacksmith.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Blacksmith.glb` Wood_Light: 0.40/0.42 → 0.00/0.70
- `Blacksmith.glb` Wood_Side: 0.40/0.42 → 0.00/0.70
- `Bonfire.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `Bonfire.glb` Stone_Light: 0.40/0.42 → 0.00/0.70
- `Bonfire.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Bonfire.glb` WoodSide: 0.40/0.42 → 0.00/0.70
- `Bonfire_Lit.glb` Fire: 0.40/1.00 → 0.00/1.00
- `Bonfire_Lit.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `Bonfire_Lit.glb` Stone_Light: 0.40/0.42 → 0.00/0.70
- `Bonfire_Lit.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Bonfire_Lit.glb` WoodSide: 0.40/0.42 → 0.00/0.70
- `Cart.glb` Beige: 0.40/0.42 → 0.00/0.70
- `Cart.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Cart.glb` Red: 0.40/0.42 → 0.00/0.70
- `Cart.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `Cart.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Cauldron.glb` Orange: 0.40/0.42 → 0.00/0.70
- `Cauldron.glb` Soup: 0.40/0.42 → 0.00/0.70
- `Cauldron.glb` Stone: 0.40/0.42 → 0.00/0.70
- `Crate.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Crate.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Door_Round.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `Door_Round.glb` Stone_Light: 0.40/0.42 → 0.00/0.70
- `Door_Round.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Door_Round.glb` Wood_Light: 0.40/0.42 → 0.00/0.70
- `Door_Straight.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `Door_Straight.glb` Stone_Light: 0.40/0.42 → 0.00/0.70
- `Door_Straight.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Door_Straight.glb` Wood_Light: 0.40/0.42 → 0.00/0.70
- `Fence.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Gazebo.glb` RoofTiles_Red: 0.40/0.42 → 0.00/0.70
- `Gazebo.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Hay.glb` Hay: 0.40/0.42 → 0.00/0.70
- `House_1.glb` Plaster: 0.40/0.42 → 0.00/0.70
- `House_1.glb` RoofTiles: 0.40/0.42 → 0.00/0.70
- `House_1.glb` Stone: 0.40/0.42 → 0.00/0.70
- `House_1.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `House_1.glb` Stone_Light: 0.40/0.42 → 0.00/0.70
- `House_1.glb` Windows: 0.40/0.42 → 0.00/0.70
- `House_1.glb` Wood: 0.40/0.42 → 0.00/0.70
- `House_1.glb` Wood_Light: 0.40/0.42 → 0.00/0.70
- `House_1.glb` Wood_Side: 0.40/0.42 → 0.00/0.70
- `House_2.glb` Beige: 0.40/0.42 → 0.00/0.70
- `House_2.glb` RoofTiles: 0.40/0.42 → 0.00/0.70
- `House_2.glb` Stone: 0.40/0.42 → 0.00/0.70
- `House_2.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `House_2.glb` Stone_Light: 0.40/0.42 → 0.00/0.70
- `House_2.glb` Windows: 0.40/0.42 → 0.00/0.70
- `House_2.glb` Wood: 0.40/0.42 → 0.00/0.70
- `House_2.glb` Wood_Light: 0.40/0.42 → 0.00/0.70
- `House_2.glb` Wood_Side: 0.40/0.42 → 0.00/0.70
- `House_3.glb` Stone: 0.40/0.42 → 0.00/0.70
- `House_3.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `House_3.glb` Stone_Light: 0.40/0.42 → 0.00/0.70
- `House_3.glb` Wood: 0.40/0.42 → 0.00/0.70
- `House_3.glb` Wood_Light: 0.40/0.42 → 0.00/0.70
- `House_3.glb` Wood_Side: 0.40/0.42 → 0.00/0.70
- `House_4.glb` Stone: 0.40/0.42 → 0.00/0.70
- `House_4.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `House_4.glb` Stone_Light: 0.40/0.42 → 0.00/0.70
- `House_4.glb` Wood: 0.40/0.42 → 0.00/0.70
- `House_4.glb` Wood_Side: 0.40/0.42 → 0.00/0.70
- `Inn.glb` Plaster: 0.40/0.42 → 0.00/0.70
- `Inn.glb` RoofTiles_Red: 0.40/0.42 → 0.00/0.70
- `Inn.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `Inn.glb` Stone_Light: 0.40/0.42 → 0.00/0.70
- `Inn.glb` Windows: 0.40/0.42 → 0.00/0.70
- `Inn.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Inn.glb` Wood_Light: 0.40/0.42 → 0.00/0.70
- `MarketStand_1.glb` Beige: 0.40/0.42 → 0.00/0.70
- `MarketStand_1.glb` RoofTiles_Red: 0.40/0.42 → 0.00/0.70
- `MarketStand_1.glb` Wood: 0.40/0.42 → 0.00/0.70
- `MarketStand_1.glb` Wood_Side: 0.40/0.42 → 0.00/0.70
- `MarketStand_2.glb` Beige: 0.40/0.42 → 0.00/0.70
- `MarketStand_2.glb` RoofTiles_Red: 0.40/0.42 → 0.00/0.70
- `MarketStand_2.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Mill.glb` Green: 0.40/0.42 → 0.00/0.70
- `Mill.glb` Plaster: 0.40/0.42 → 0.00/0.70
- `Mill.glb` RoofTiles: 0.40/0.42 → 0.00/0.70
- `Mill.glb` Stone: 0.40/0.42 → 0.00/0.70
- `Mill.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `Mill.glb` Stone_Light: 0.40/0.42 → 0.00/0.70
- `Mill.glb` Windows: 0.40/0.42 → 0.00/0.70
- `Mill.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Mill.glb` Wood_Light: 0.40/0.42 → 0.00/0.70
- `Mill.glb` Wood_Side: 0.40/0.42 → 0.00/0.70
- `Package_1.glb` Bag: 0.40/0.42 → 0.00/0.70
- `Package_1.glb` Leather: 0.40/0.42 → 0.00/0.70
- `Package_2.glb` Bag: 0.40/0.42 → 0.00/0.70
- `Package_2.glb` Leather: 0.40/0.42 → 0.00/0.70
- `Path_Square.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `Path_Square.glb` Stone_Light: 0.40/0.42 → 0.00/0.70
- `Path_Straight.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `Path_Straight.glb` Stone_Light: 0.40/0.42 → 0.00/0.70
- `Rock_1.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `Rock_2.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `Rock_3.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `Sawmill.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Sawmill.glb` Plaster: 0.40/0.42 → 0.00/0.70
- `Sawmill.glb` RoofTiles_Red: 0.40/0.42 → 0.00/0.70
- `Sawmill.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `Sawmill.glb` Stone_Light: 0.40/0.42 → 0.00/0.70
- `Sawmill.glb` Windows: 0.40/0.42 → 0.00/0.70
- `Sawmill.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Sawmill.glb` Wood_Light: 0.40/0.42 → 0.00/0.70
- `Sawmill.glb` Wood_Side: 0.40/0.42 → 0.00/0.70
- `Sawmill_saw.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Sawmill_saw.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Sawmill_saw.glb` WoodSide: 0.40/0.42 → 0.00/0.70
- `Sawmill_saw.glb` Wood_Side: 0.40/0.42 → 0.00/0.70
- `Smoke.glb` Smoke: 0.40/1.00 → 0.00/1.00
- `Stable.glb` Beige: 0.40/0.42 → 0.00/0.70
- `Stable.glb` RoofTiles: 0.40/0.42 → 0.00/0.70
- `Stable.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `Stable.glb` Stone_Light: 0.40/0.42 → 0.00/0.70
- `Stable.glb` Windows: 0.40/0.42 → 0.00/0.70
- `Stable.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Stable.glb` Wood_Light: 0.40/0.42 → 0.00/0.70
- `Stable.glb` Wood_Side: 0.40/0.42 → 0.00/0.70
- `Stairs.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `Stairs.glb` Stone_Light: 0.40/0.42 → 0.00/0.70
- `Well.glb` Bag: 0.40/0.42 → 0.00/0.70
- `Well.glb` RoofTiles_Red: 0.40/0.42 → 0.00/0.70
- `Well.glb` Stone_Dark: 0.40/0.42 → 0.00/0.70
- `Well.glb` Stone_Light: 0.40/0.42 → 0.00/0.70
- `Well.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Window_1.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Window_1.glb` Windows: 0.40/0.42 → 0.00/0.70
- `Window_1.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Window_2.glb` Stone: 0.40/0.42 → 0.00/0.70
- `Window_2.glb` Windows: 0.40/0.42 → 0.00/0.70
- `Window_2.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Window_2.glb` Wood_Light: 0.40/0.42 → 0.00/0.70
- `Window_3.glb` Stone: 0.40/0.42 → 0.00/0.70
- `Window_3.glb` Windows: 0.40/0.42 → 0.00/0.70
- `Window_3.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Window_3.glb` Wood_Light: 0.40/0.42 → 0.00/0.70
- `Window_4.glb` Stone: 0.40/0.42 → 0.00/0.70
- `Window_4.glb` Windows: 0.40/0.42 → 0.00/0.70
- `Window_4.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Window_4.glb` Wood_Light: 0.40/0.42 → 0.00/0.70

### quaternius/rpg_items_pack (150)

- `Armor_Black.glb` Black: 0.40/0.42 → 0.00/0.70
- `Armor_Black.glb` DarkRed: 0.40/0.42 → 0.00/0.70
- `Armor_Leather.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Arrow.glb` DarkRed: 0.40/0.42 → 0.00/0.70
- `Arrow_Golden.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Axe_Double_Golden.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Axe_Double_Golden.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Axe_small.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Axe_small.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Axe_small_Golden.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Axe_small_Golden.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Backpack.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Backpack.glb` DarkBrown: 0.40/0.42 → 0.00/0.70
- `Bag.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Bag.glb` DarkBrown: 0.40/0.42 → 0.00/0.70
- `Bone.glb` Beige: 0.40/0.42 → 0.00/0.70
- `Book1_Closed.glb` Beige: 0.40/0.42 → 0.00/0.70
- `Book1_Closed.glb` DarkRed: 0.40/0.42 → 0.00/0.70
- `Book1_Open.glb` Beige: 0.40/0.42 → 0.00/0.70
- `Book1_Open.glb` DarkRed: 0.40/0.42 → 0.00/0.70
- `Book2_Closed.glb` Beige: 0.40/0.42 → 0.00/0.70
- `Book2_Closed.glb` DarkRed: 0.40/0.42 → 0.00/0.70
- `Book2_Open.glb` Beige: 0.40/0.42 → 0.00/0.70
- `Book2_Open.glb` DarkRed: 0.40/0.42 → 0.00/0.70
- `Book3_Closed.glb` Beige: 0.40/0.42 → 0.00/0.70
- `Book3_Closed.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Book3_Closed.glb` DarkBrown: 0.40/0.42 → 0.00/0.70
- `Book3_Open.glb` Beige: 0.40/0.42 → 0.00/0.70
- `Book3_Open.glb` DarkBrown: 0.40/0.42 → 0.00/0.70
- `Book4_Closed.glb` Beige: 0.40/0.42 → 0.00/0.70
- `Book4_Closed.glb` DarkRed: 0.40/0.42 → 0.00/0.70
- `Book4_Closed.glb` DarkTeal: 0.40/0.42 → 0.00/0.70
- `Book4_Closed.glb` Teal: 0.40/0.42 → 0.00/0.70
- `Book4_Open.glb` Beige: 0.40/0.42 → 0.00/0.70
- `Book4_Open.glb` DarkRed: 0.40/0.42 → 0.00/0.70
- `Book4_Open.glb` Teal: 0.40/0.42 → 0.00/0.70
- `Chest_Closed.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Chest_Ingots.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Chest_Open.glb` Wood: 0.40/0.42 → 0.00/0.70
- `ChickenLeg.glb` Beige: 0.40/0.42 → 0.00/0.70
- `ChickenLeg.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Crown2.glb` Red: 0.40/0.42 → 0.00/0.70
- `Crystal1.glb` Purple: 0.40/0.42 → 0.00/0.70
- `Crystal1_Damaged.glb` Purple: 0.40/0.42 → 0.00/0.70
- `Crystal2.glb` Pink: 0.40/0.42 → 0.00/0.70
- `Crystal2_Damaged.glb` Pink: 0.40/0.42 → 0.00/0.70
- `Crystal3.glb` Green: 0.40/0.42 → 0.00/0.70
- `Crystal3_Damaged.glb` Green: 0.40/0.42 → 0.00/0.70
- `Crystal4.glb` Red: 0.40/0.42 → 0.00/0.70
- `Crystal5.glb` Cyan: 0.40/0.42 → 0.00/0.70
- `Crystal5_Damaged.glb` Cyan: 0.40/0.42 → 0.00/0.70
- `Dagger_Golden.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Dagger_Golden.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Dart.glb` DarkRed: 0.40/0.42 → 0.00/0.70
- `Dart.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Dart_Golden.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `FishBone.glb` Beige: 0.40/0.42 → 0.00/0.70
- `Glove.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Hammer_Double_Golden.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Hammer_Double_Golden.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Heart.glb` Red: 0.40/0.42 → 0.00/0.70
- `Heart_Broken.glb` Red: 0.40/0.42 → 0.00/0.70
- `Heart_Half.glb` Red: 0.40/0.42 → 0.00/0.70
- `Key1.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Key2.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Mineral.glb` Grey: 0.40/0.42 → 0.00/0.70
- `Mineral.glb` Pink: 0.40/0.42 → 0.00/0.70
- `Necklace1.glb` DarkBrown: 0.40/0.42 → 0.00/0.70
- `Necklace1.glb` Lilac: 0.40/0.42 → 0.00/0.70
- `Necklace2.glb` DarkBrown: 0.40/0.42 → 0.00/0.70
- `Necklace2.glb` Red: 0.40/0.42 → 0.00/0.70
- `Necklace3.glb` Cyan: 0.40/0.42 → 0.00/0.70
- `Necklace3.glb` DarkBrown: 0.40/0.42 → 0.00/0.70
- `Padlock.glb` Black: 0.40/0.42 → 0.00/0.70
- `Padlock.glb` Grey: 0.40/0.42 → 0.00/0.70
- `Parchment.glb` Beige: 0.40/0.42 → 0.00/0.70
- `Potion10_Empty.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion10_Empty.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion10_Filled.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion10_Filled.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion10_Filled.glb` Liquid_Cyan: 0.40/1.00 → 0.00/1.00
- `Potion11_Empty.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion11_Empty.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion11_Filled.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion11_Filled.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion11_Filled.glb` Liquid_Cyan: 0.40/1.00 → 0.00/1.00
- `Potion1_Empty.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion1_Empty.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion1_Filled.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion1_Filled.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion1_Filled.glb` Liquid_Red: 0.40/1.00 → 0.00/1.00
- `Potion2_Empty.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion2_Empty.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion2_Filled.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion2_Filled.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion2_Filled.glb` Liquid_Yellow: 0.40/1.00 → 0.00/1.00
- `Potion3_Empty.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion3_Empty.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion3_Filled.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion3_Filled.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion3_Filled.glb` Liquid_Green: 0.40/1.00 → 0.00/1.00
- `Potion4_Empty.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion4_Empty.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion4_Filled.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion4_Filled.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion4_Filled.glb` Liquid_Magenta: 0.40/1.00 → 0.00/1.00
- `Potion5_Empty.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion5_Empty.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion5_Filled.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion5_Filled.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion5_Filled.glb` Liquid_Cyan: 0.40/1.00 → 0.00/1.00
- `Potion6_Empty.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion6_Empty.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion6_Filled.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion6_Filled.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion6_Filled.glb` Liquid_Red: 0.40/1.00 → 0.00/1.00
- `Potion7_Empty.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion7_Empty.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion7_Filled.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion7_Filled.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion7_Filled.glb` Liquid_Yellow: 0.40/1.00 → 0.00/1.00
- `Potion8_Empty.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion8_Empty.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion8_Filled.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion8_Filled.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion8_Filled.glb` Liquid_Magenta: 0.40/1.00 → 0.00/1.00
- `Potion9_Empty.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion9_Empty.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion9_Filled.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Potion9_Filled.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion9_Filled.glb` Liquid_Green: 0.40/1.00 → 0.00/1.00
- `Pouch.glb` Brown: 0.40/0.42 → 0.00/0.70
- `Pouch.glb` DarkRed: 0.40/0.42 → 0.00/0.70
- `Ring3.glb` Red: 0.40/0.42 → 0.00/0.70
- `Ring4.glb` Cyan: 0.40/0.42 → 0.00/0.70
- `Ring5.glb` Lilac: 0.40/0.42 → 0.00/0.70
- `Ring6.glb` Green: 0.40/0.42 → 0.00/0.70
- `Ring7.glb` DarkTeal: 0.40/0.42 → 0.00/0.70
- `Ring7.glb` Teal: 0.40/0.42 → 0.00/0.70
- `Scroll.glb` Beige: 0.40/0.42 → 0.00/0.70
- `Scroll.glb` DarkRed: 0.40/0.42 → 0.00/0.70
- `Skull.glb` Bone: 0.40/0.42 → 0.00/0.70
- `Skull2.glb` Bone: 0.40/0.42 → 0.00/0.70
- `Snowflake1.glb` Snowflake: 0.40/0.42 → 0.00/0.70
- `Snowflake2.glb` Snowflake: 0.40/0.42 → 0.00/0.70
- `Snowflake3.glb` Snowflake: 0.40/0.42 → 0.00/0.70
- `Sword_big.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Sword_big.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Sword_big_Golden.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Sword_big_Golden.glb` LightWood: 0.40/0.42 → 0.00/0.70

### quaternius/survival_pack (130)

- `Axe.glb` LightGrey: 0.40/0.42 → 0.00/0.70
- `Axe.glb` Red: 0.40/0.42 → 0.00/0.70
- `Axe_Small.glb` Grey: 0.40/0.42 → 0.00/0.70
- `Axe_Small.glb` LightGrey: 0.40/0.42 → 0.00/0.70
- `Backpack.glb` Green: 0.40/0.42 → 0.00/0.70
- `Backpack.glb` LightGreen: 0.40/0.42 → 0.00/0.70
- `Bandages.glb` Red: 0.40/0.42 → 0.00/0.70
- `Bandages.glb` White: 0.40/0.42 → 0.00/0.70
- `Battery_Big.glb` Black: 0.40/0.42 → 0.00/0.70
- `Battery_Big.glb` Grey: 0.40/0.42 → 0.00/0.70
- `Battery_Big.glb` Orange: 0.40/0.42 → 0.00/0.70
- `Battery_Small.glb` Black: 0.40/0.42 → 0.00/0.70
- `Battery_Small.glb` Grey: 0.40/0.42 → 0.00/0.70
- `Battery_Small.glb` Orange: 0.40/0.42 → 0.00/0.70
- `BearTrap_Closed.glb` Grey: 0.40/0.42 → 0.00/0.70
- `BearTrap_Open.glb` Grey: 0.40/0.42 → 0.00/0.70
- `Bonfire.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Bonfire_Fire.glb` Fire: 0.40/0.42 → 0.00/0.70
- `Bonfire_Fire.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Bonfire_Fire.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Can_Broken.glb` DarkGrey: 0.40/0.42 → 0.00/0.70
- `Can_Broken.glb` Grey: 0.40/0.42 → 0.00/0.70
- `Can_Closed.glb` Grey: 0.40/0.42 → 0.00/0.70
- `Can_Closed.glb` LightGrey: 0.40/0.42 → 0.00/0.70
- `Can_Open.glb` Grey: 0.40/0.42 → 0.00/0.70
- `Can_Open.glb` LightGrey: 0.40/0.42 → 0.00/0.70
- `Can_Red.glb` Grey: 0.40/0.42 → 0.00/0.70
- `Can_Red.glb` LightGrey: 0.40/0.42 → 0.00/0.70
- `Can_Red.glb` Red: 0.40/0.42 → 0.00/0.70
- `Compass_Closed.glb` DarkYellow: 0.40/0.42 → 0.00/0.70
- `Compass_Closed.glb` Yellow: 0.40/0.42 → 0.00/0.70
- `Compass_Open.glb` Black: 0.40/0.42 → 0.00/0.70
- `Compass_Open.glb` DarkYellow: 0.40/0.42 → 0.00/0.70
- `Compass_Open.glb` Red: 0.40/0.42 → 0.00/0.70
- `Compass_Open.glb` White: 0.40/0.42 → 0.00/0.70
- `Compass_Open.glb` Yellow: 0.40/0.42 → 0.00/0.70
- `FirstAidKit.glb` Black: 0.40/0.42 → 0.00/0.70
- `FirstAidKit.glb` Red: 0.40/0.42 → 0.00/0.70
- `FirstAidKit.glb` White: 0.40/0.42 → 0.00/0.70
- `FirstAidKit_Hard.glb` Grey: 0.40/0.42 → 0.00/0.70
- `FirstAidKit_Hard.glb` LightGrey: 0.40/0.42 → 0.00/0.70
- `FirstAidKit_Hard.glb` Red: 0.40/0.42 → 0.00/0.70
- `FirstAidKit_Hard.glb` White: 0.40/0.42 → 0.00/0.70
- `FlareGun.glb` Black: 0.40/0.42 → 0.00/0.70
- `FlareGun.glb` Red: 0.40/0.42 → 0.00/0.70
- `GasCan.glb` Black: 0.40/0.42 → 0.00/0.70
- `GasCan.glb` DarkRed: 0.40/0.42 → 0.00/0.70
- `GasCan.glb` Red: 0.40/0.42 → 0.00/0.70
- `Knife.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Knife.glb` Grey: 0.40/0.42 → 0.00/0.70
- `Knife.glb` LightGrey: 0.40/0.42 → 0.00/0.70
- `Knife.glb` Yellow: 0.40/0.42 → 0.00/0.70
- `Match.glb` Match: 0.40/0.42 → 0.00/0.70
- `Match.glb` Red: 0.40/0.42 → 0.00/0.70
- `Match_Burnt.glb` Black: 0.40/0.42 → 0.00/0.70
- `Match_Fire.glb` Fire: 0.40/0.42 → 0.00/0.70
- `Match_Fire.glb` Match: 0.40/0.42 → 0.00/0.70
- `Matchbox.glb` DarkYellow: 0.40/0.42 → 0.00/0.70
- `Matchbox.glb` Match: 0.40/0.42 → 0.00/0.70
- `Matchbox.glb` Red: 0.40/0.42 → 0.00/0.70
- `Matchbox.glb` Yellow: 0.40/0.42 → 0.00/0.70
- `Pan.glb` Black: 0.40/0.42 → 0.00/0.70
- `Pan.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Pan.glb` Grey: 0.40/0.42 → 0.00/0.70
- `Pan_Small.glb` Black: 0.40/0.42 → 0.00/0.70
- `Pan_Small.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Pan_Small.glb` Grey: 0.40/0.42 → 0.00/0.70
- `Phone.glb` Black: 0.40/0.42 → 0.00/0.70
- `Phone.glb` Grey: 0.40/0.42 → 0.00/0.70
- `Phone.glb` White: 0.40/0.42 → 0.00/0.70
- `Pistol_1.glb` Black: 0.40/0.42 → 0.00/0.70
- `Pistol_1.glb` Black2: 0.40/0.42 → 0.00/0.70
- `Pistol_1.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Pistol_2.glb` Black: 0.40/0.42 → 0.00/0.70
- `Pistol_2.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Pot.glb` Black: 0.40/0.42 → 0.00/0.70
- `Pot.glb` Grey: 0.40/0.42 → 0.00/0.70
- `Pot_Small.glb` Black: 0.40/0.42 → 0.00/0.70
- `Pot_Small.glb` Grey: 0.40/0.42 → 0.00/0.70
- `PropaneTank.glb` Black: 0.40/0.42 → 0.00/0.70
- `PropaneTank.glb` Orange: 0.40/0.42 → 0.00/0.70
- `PropaneTank.glb` Red: 0.40/0.42 → 0.00/0.70
- `PropaneTank.glb` White: 0.40/0.42 → 0.00/0.70
- `Radio.glb` Black: 0.40/0.42 → 0.00/0.70
- `Radio.glb` DarkGrey: 0.40/0.42 → 0.00/0.70
- `Radio.glb` LightGrey: 0.40/0.42 → 0.00/0.70
- `Radio.glb` Red: 0.40/0.42 → 0.00/0.70
- `Raft.glb` Black: 0.40/0.42 → 0.00/0.70
- `Raft.glb` BrightYellow: 0.40/0.42 → 0.00/0.70
- `Raft_Paddle.glb` Blue: 0.40/0.42 → 0.00/0.70
- `Raft_Paddle.glb` BrightYellow: 0.40/0.42 → 0.00/0.70
- `Revolver_1.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Revolver_2.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Revolver_3.glb` Grey: 0.40/0.42 → 0.00/0.70
- `Shotgun_1.glb` Black: 0.40/0.42 → 0.00/0.70
- `Shotgun_2.glb` Black: 0.40/0.42 → 0.00/0.70
- `Shotgun_2.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Shotgun_SawedOff.glb` Black: 0.40/0.42 → 0.00/0.70
- `Shotgun_SawedOff.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Shotgun_SawedOff.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Shotgun_ShortStock.glb` Black: 0.40/0.42 → 0.00/0.70
- `Shotgun_ShortStock.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Shovel.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Shovel.glb` Grey: 0.40/0.42 → 0.00/0.70
- `Shovel.glb` Red: 0.40/0.42 → 0.00/0.70
- `Tent.glb` Black: 0.40/0.42 → 0.00/0.70
- `Tent.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Tent.glb` Green: 0.40/0.42 → 0.00/0.70
- `Tent.glb` LightGreen: 0.40/0.42 → 0.00/0.70
- `Torch.glb` Black: 0.40/0.42 → 0.00/0.70
- `Torch.glb` DarkYellow: 0.40/0.42 → 0.00/0.70
- `Torch.glb` LightBlue: 0.40/0.42 → 0.00/0.70
- `Torch.glb` Yellow: 0.40/0.42 → 0.00/0.70
- `Trashcan.glb` Black: 0.40/0.42 → 0.00/0.70
- `Trashcan.glb` DarkGreen: 0.40/0.42 → 0.00/0.70
- `WaterBottle_1.glb` Grey: 0.40/0.42 → 0.00/0.70
- `WaterBottle_1.glb` Plastic: 0.40/0.42 → 0.00/0.70
- `WaterBottle_2.glb` Grey: 0.40/0.42 → 0.00/0.70
- `WaterBottle_2.glb` Plastic: 0.40/0.42 → 0.00/0.70
- `WaterBottle_3.glb` Grey: 0.40/0.42 → 0.00/0.70
- `WaterBottle_3.glb` Plastic: 0.40/0.42 → 0.00/0.70
- `WaterBottle_3.glb` Red: 0.40/0.42 → 0.00/0.70
- `WoodLog.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `WoodenTorch.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `WoodenTorch.glb` LightGrey: 0.40/0.42 → 0.00/0.70
- `WoodenTorch.glb` Yellow: 0.40/0.42 → 0.00/0.70
- `WoodenTorch_Fire.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `WoodenTorch_Fire.glb` Fire: 0.40/0.42 → 0.00/0.70
- `WoodenTorch_Fire.glb` LightGrey: 0.40/0.42 → 0.00/0.70
- `WoodenTorch_Fire.glb` Yellow: 0.40/0.42 → 0.00/0.70

### quaternius/animals_pack (76)

- `Alpaca.glb` Eyes_Black: 0.40/0.42 → 0.00/0.42
- `Alpaca.glb` Eyes_White: 0.40/0.42 → 0.00/0.42
- `Alpaca.glb` Hooves: 0.40/0.42 → 0.00/0.70
- `Alpaca.glb` Main: 0.40/0.42 → 0.00/0.70
- `Alpaca.glb` Main_Dark: 0.40/0.42 → 0.00/0.70
- `Alpaca.glb` Main_Light: 0.40/0.42 → 0.00/0.70
- `Alpaca.glb` Muzzle: 0.40/0.42 → 0.00/0.70
- `Bull.glb` Eye_Black: 0.40/0.42 → 0.00/0.42
- `Bull.glb` Eye_White: 0.40/0.42 → 0.00/0.42
- `Bull.glb` Hooves: 0.40/0.42 → 0.00/0.70
- `Bull.glb` Horns: 0.40/0.42 → 0.00/0.70
- `Bull.glb` Main: 0.40/0.42 → 0.00/0.70
- `Bull.glb` Main_Light: 0.40/0.42 → 0.00/0.70
- `Bull.glb` Muzzle: 0.40/0.42 → 0.00/0.70
- `Cow.glb` Eye_Black: 0.40/0.42 → 0.00/0.42
- `Cow.glb` Eye_White: 0.40/0.42 → 0.00/0.42
- `Cow.glb` Hooves: 0.40/0.42 → 0.00/0.70
- `Cow.glb` Horns: 0.40/0.42 → 0.00/0.70
- `Cow.glb` Main: 0.40/0.42 → 0.00/0.70
- `Cow.glb` Main_Light: 0.40/0.42 → 0.00/0.70
- `Cow.glb` Muzzle: 0.40/0.42 → 0.00/0.70
- `Deer.glb` Eye_Black: 0.40/0.42 → 0.00/0.42
- `Deer.glb` Eye_Lighter: 0.40/0.42 → 0.00/0.42
- `Deer.glb` Eye_White: 0.40/0.42 → 0.00/0.42
- `Deer.glb` Hooves: 0.40/0.42 → 0.00/0.70
- `Deer.glb` Main: 0.40/0.42 → 0.00/0.70
- `Deer.glb` Main_Dark: 0.40/0.42 → 0.00/0.70
- `Deer.glb` Main_Light: 0.40/0.42 → 0.00/0.70
- `Donkey.glb` Eye_Dark: 0.40/0.42 → 0.00/0.42
- `Donkey.glb` Eye_White: 0.40/0.42 → 0.00/0.42
- `Donkey.glb` Hair: 0.40/0.42 → 0.00/0.70
- `Donkey.glb` Hooves: 0.40/0.42 → 0.00/0.70
- `Donkey.glb` Main: 0.40/0.42 → 0.00/0.70
- `Donkey.glb` Main_Dark: 0.40/0.42 → 0.00/0.70
- `Donkey.glb` Main_Light: 0.40/0.42 → 0.00/0.70
- `Donkey.glb` Muzzle: 0.40/0.42 → 0.00/0.70
- `Fox.glb` Black: 0.40/0.42 → 0.00/0.70
- `Fox.glb` Eyes: 0.40/0.42 → 0.00/0.42
- `Fox.glb` Grey: 0.40/0.42 → 0.00/0.70
- `Fox.glb` Main: 0.40/0.42 → 0.00/0.70
- `Fox.glb` Main_Light: 0.40/0.42 → 0.00/0.70
- `Horse.glb` Eye_Black: 0.40/0.42 → 0.00/0.42
- `Horse.glb` Eye_White: 0.40/0.42 → 0.00/0.42
- `Horse.glb` Hair: 0.40/0.42 → 0.00/0.70
- `Horse.glb` Hooves: 0.40/0.42 → 0.00/0.70
- `Horse.glb` Main: 0.40/0.42 → 0.00/0.70
- `Horse.glb` Main_Dark: 0.40/0.42 → 0.00/0.70
- `Horse.glb` Main_Light: 0.40/0.42 → 0.00/0.70
- `Horse.glb` Muzzle: 0.40/0.42 → 0.00/0.70
- `Horse_White.glb` Eye_Black: 0.40/0.42 → 0.00/0.42
- `Horse_White.glb` Eye_White: 0.40/0.42 → 0.00/0.42
- `Horse_White.glb` Hair: 0.40/0.42 → 0.00/0.70
- `Horse_White.glb` Hooves: 0.40/0.42 → 0.00/0.70
- `Horse_White.glb` Main: 0.40/0.42 → 0.00/0.70
- `Horse_White.glb` Main_Light: 0.40/0.42 → 0.00/0.70
- `Horse_White.glb` Muzzle: 0.40/0.42 → 0.00/0.70
- `Husky.glb` Material: 0.40/0.42 → 0.00/0.70
- `Husky.glb` Material.001: 0.40/0.42 → 0.00/0.70
- `Husky.glb` Material.002: 0.40/0.42 → 0.00/0.70
- `Husky.glb` Material.003: 0.40/0.42 → 0.00/0.70
- `Husky.glb` Material.006: 0.40/0.42 → 0.00/0.70
- `ShibaInu.glb` Black: 0.40/0.42 → 0.00/0.70
- `ShibaInu.glb` Eyes_Black: 0.40/0.42 → 0.00/0.42
- `ShibaInu.glb` Eyes_Pupil: 0.40/0.42 → 0.00/0.42
- `ShibaInu.glb` Eyes_White: 0.40/0.42 → 0.00/0.42
- `ShibaInu.glb` Main: 0.40/0.42 → 0.00/0.70
- `ShibaInu.glb` Main_Light: 0.40/0.42 → 0.00/0.70
- `Stag.glb` Material: 0.40/0.42 → 0.00/0.70
- `Stag.glb` Material.001: 0.40/0.42 → 0.00/0.70
- `Stag.glb` Material.003: 0.40/0.42 → 0.00/0.70
- `Stag.glb` Material.010: 0.40/0.42 → 0.00/0.70
- `Stag.glb` Material.011: 0.40/0.42 → 0.00/0.70
- `Wolf.glb` Eyes_Black: 0.40/0.42 → 0.00/0.42
- `Wolf.glb` Main: 0.40/0.42 → 0.00/0.70
- `Wolf.glb` Main_Light: 0.40/0.42 → 0.00/0.70
- `Wolf.glb` Nose: 0.40/0.42 → 0.00/0.70

### quaternius/modular_dungeon_pack (67)

- `Bones.glb` Bones: 0.40/0.42 → 0.00/0.70
- `Bones2.glb` Bones: 0.40/0.42 → 0.00/0.70
- `Book2.glb` Cover.001: 0.40/0.42 → 0.00/0.70
- `Book2.glb` Ink.001: 0.40/0.42 → 0.00/0.70
- `Book2.glb` Paper.001: 0.40/0.42 → 0.00/0.70
- `Book3.glb` Cover: 0.40/0.42 → 0.00/0.70
- `Book3.glb` Ink: 0.40/0.42 → 0.00/0.70
- `Book3.glb` Paper: 0.40/0.42 → 0.00/0.70
- `Book_Open.glb` Cover: 0.40/0.42 → 0.00/0.70
- `Book_Open.glb` Ink: 0.40/0.42 → 0.00/0.70
- `Book_Open.glb` Paper: 0.40/0.42 → 0.00/0.70
- `Candelabrum.glb` Black: 0.40/0.42 → 0.00/0.70
- `Candelabrum.glb` Candle: 0.40/0.42 → 0.00/0.70
- `Candelabrum_tall.glb` Black: 0.40/0.42 → 0.00/0.70
- `Candelabrum_tall.glb` Candle: 0.40/0.42 → 0.00/0.70
- `Candle.glb` Black: 0.40/0.42 → 0.00/0.70
- `Candle.glb` Candle.001: 0.40/0.42 → 0.00/0.70
- `Carpet.glb` Red: 0.40/0.42 → 0.00/0.70
- `Chest.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Chest_gold.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Column.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Column_Broken.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Column_Broken2.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Entrance.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Entrance2.glb` Rock: 0.40/0.42 → 0.00/0.70
- `ModularColumn_bottom.glb` Rock: 0.40/0.42 → 0.00/0.70
- `ModularColumn_bottom.glb` RockLight: 0.40/0.42 → 0.00/0.70
- `ModularColumn_middle.glb` Rock: 0.40/0.42 → 0.00/0.70
- `ModularColumn_middle.glb` RockLight: 0.40/0.42 → 0.00/0.70
- `ModularColumn_top.glb` Rock: 0.40/0.42 → 0.00/0.70
- `ModularColumn_top.glb` RockLight: 0.40/0.42 → 0.00/0.70
- `ModularFloor.glb` Rock: 0.40/0.42 → 0.00/0.70
- `ModularFloor.glb` RockLight: 0.40/0.42 → 0.00/0.70
- `ModularStoneWall.glb` Rock: 0.40/0.42 → 0.00/0.70
- `ModularStoneWall.glb` RockLight: 0.40/0.42 → 0.00/0.70
- `ModularStoneWall_EntranceTop.glb` Rock: 0.40/0.42 → 0.00/0.70
- `ModularStoneWall_EntranceTop.glb` RockLight: 0.40/0.42 → 0.00/0.70
- `ModularStoneWall_top.glb` Rock: 0.40/0.42 → 0.00/0.70
- `ModularStoneWall_top.glb` RockLight: 0.40/0.42 → 0.00/0.70
- `Potion.glb` Blue: 0.40/0.42 → 0.00/0.70
- `Potion.glb` Cork: 0.40/0.42 → 0.00/0.70
- `Potion2.glb` Cork: 0.40/0.42 → 0.00/0.70
- `Potion2.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion2.glb` Liquid: 0.40/0.42 → 0.00/0.70
- `Potion3.glb` Grey: 0.40/0.42 → 0.00/0.70
- `Potion3.glb` Ice: 0.40/0.42 → 0.00/0.70
- `Potion4.glb` Cork: 0.40/0.42 → 0.00/0.70
- `Potion4.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion4.glb` Liquid: 0.40/0.42 → 0.00/0.70
- `Potion5.glb` Cork: 0.40/0.42 → 0.00/0.70
- `Potion5.glb` Glass: 0.40/1.00 → 0.00/1.00
- `Potion5.glb` Liquid: 0.40/0.42 → 0.00/0.70
- `Potion6.glb` Cork: 0.40/0.42 → 0.00/0.70
- `Potion6.glb` Yellow: 0.40/0.42 → 0.00/0.70
- `Rock1.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Rock2.glb` Rock.001: 0.40/0.42 → 0.00/0.70
- `Rock3.glb` Rock.002: 0.40/0.42 → 0.00/0.70
- `Rock4.glb` Rock.003: 0.40/0.42 → 0.00/0.70
- `Rock5.glb` Rock.004: 0.40/0.42 → 0.00/0.70
- `Stairs.glb` Rock: 0.40/0.42 → 0.00/0.70
- `Torch.glb` Fire: 0.40/0.42 → 0.00/0.70
- `Torch.glb` Wood: 0.40/0.42 → 0.00/0.70
- `Torch_wall.glb` Fire: 0.40/0.42 → 0.00/0.70
- `Torch_wall.glb` Wood: 0.40/0.42 → 0.00/0.70
- `WallRocks.glb` RockLight: 0.40/0.42 → 0.00/0.70
- `Window.glb` Black: 0.40/0.42 → 0.00/0.70
- `Window.glb` Rock: 0.40/0.42 → 0.00/0.70

### quaternius/modular_medieval_buildings_pack (67)

- `Banner.glb` Banner: 0.40/1.00 → 0.00/1.00
- `Banner.glb` LightWood: 0.40/1.00 → 0.00/1.00
- `Bridge.glb` LightWood: 0.40/1.00 → 0.00/1.00
- `Bridge.glb` Material.006: 0.40/1.00 → 0.00/1.00
- `Door.glb` DarkWood: 0.40/1.00 → 0.00/1.00
- `Door.glb` LightWood: 0.40/1.00 → 0.00/1.00
- `Dummy.glb` DarkWood: 0.40/1.00 → 0.00/1.00
- `Dummy.glb` Leather: 0.40/1.00 → 0.00/1.00
- `LargeSimpleTower.glb` Black: 0.40/1.00 → 0.00/1.00
- `LargeSimpleTower.glb` Celing: 0.40/1.00 → 0.00/1.00
- `LargeSimpleTower.glb` DarkRock: 0.40/1.00 → 0.00/1.00
- `LargeSimpleTower.glb` LightRock: 0.40/1.00 → 0.00/1.00
- `LargeSquareTower.glb` Black: 0.40/1.00 → 0.00/1.00
- `LargeSquareTower.glb` LightRock: 0.40/1.00 → 0.00/1.00
- `LargeSquareTowerBricks.glb` Black.001: 0.40/1.00 → 0.00/1.00
- `LargeSquareTowerBricks.glb` DarkRock: 0.40/1.00 → 0.00/1.00
- `LargeSquareTowerBricks.glb` LightRock.001: 0.40/1.00 → 0.00/1.00
- `LargeTower.glb` LightRock.001: 0.40/1.00 → 0.00/1.00
- `PointyTower.glb` Black.001: 0.40/1.00 → 0.00/1.00
- `PointyTower.glb` Celing.001: 0.40/1.00 → 0.00/1.00
- `PointyTower.glb` DarkRock.001: 0.40/1.00 → 0.00/1.00
- `PointyTower.glb` LightRock.001: 0.40/1.00 → 0.00/1.00
- `SimpleTowerBricks.glb` Black.002: 0.40/1.00 → 0.00/1.00
- `SimpleTowerBricks.glb` Celing: 0.40/1.00 → 0.00/1.00
- `SimpleTowerBricks.glb` DarkRock.001: 0.40/1.00 → 0.00/1.00
- `SimpleTowerBricks.glb` LightRock.002: 0.40/1.00 → 0.00/1.00
- `Simpletower.glb` Black: 0.40/1.00 → 0.00/1.00
- `Simpletower.glb` Celing: 0.40/1.00 → 0.00/1.00
- `Simpletower.glb` DarkRock: 0.40/1.00 → 0.00/1.00
- `Simpletower.glb` LightRock: 0.40/1.00 → 0.00/1.00
- `SmallSquareTower.glb` Black: 0.40/1.00 → 0.00/1.00
- `SmallSquareTower.glb` LightRock: 0.40/1.00 → 0.00/1.00
- `SmallSquareTowerBricks.glb` Black: 0.40/1.00 → 0.00/1.00
- `SmallSquareTowerBricks.glb` DarkRock: 0.40/1.00 → 0.00/1.00
- `SmallSquareTowerBricks.glb` LightRock: 0.40/1.00 → 0.00/1.00
- `SmallTower.glb` LightRock: 0.40/1.00 → 0.00/1.00
- `TallWall.glb` LightRock: 0.40/1.00 → 0.00/1.00
- `TallWallBricks.glb` DarkRock: 0.40/1.00 → 0.00/1.00
- `TallWallBricks.glb` LightRock: 0.40/1.00 → 0.00/1.00
- `TallWallEntrance.glb` DarkRock: 0.40/1.00 → 0.00/1.00
- `TallWallEntrance.glb` LightRock: 0.40/1.00 → 0.00/1.00
- `Target.glb` DarkWood: 0.40/1.00 → 0.00/1.00
- `Target.glb` Red: 0.40/1.00 → 0.00/1.00
- `Target.glb` White: 0.40/1.00 → 0.00/1.00
- `TargetWithArrows.glb` DarkWood: 0.40/1.00 → 0.00/1.00
- `TargetWithArrows.glb` Red: 0.40/1.00 → 0.00/1.00
- `TargetWithArrows.glb` White: 0.40/1.00 → 0.00/1.00
- `Tower.glb` Black: 0.40/1.00 → 0.00/1.00
- `Tower.glb` DarkRock: 0.40/1.00 → 0.00/1.00
- `Tower.glb` LightRock: 0.40/1.00 → 0.00/1.00
- `Tunnel.glb` LightRock.001: 0.40/1.00 → 0.00/1.00
- `Wall.glb` LightRock: 0.40/1.00 → 0.00/1.00
- `WallBricks.glb` DarkRock: 0.40/1.00 → 0.00/1.00
- `WallBricks.glb` LightRock: 0.40/1.00 → 0.00/1.00
- `WallEntrance.glb` LightRock: 0.40/1.00 → 0.00/1.00
- `WallEntranceBricks.glb` DarkRock: 0.40/1.00 → 0.00/1.00
- `WallEntranceBricks.glb` LightRock: 0.40/1.00 → 0.00/1.00
- `WatchTowerWRoof.glb` Celing: 0.40/1.00 → 0.00/1.00
- `WatchTowerWRoof.glb` LightWood: 0.40/1.00 → 0.00/1.00
- `Watchtower.glb` LightWood: 0.40/1.00 → 0.00/1.00
- `Well.glb` Celing: 0.40/1.00 → 0.00/1.00
- `Well.glb` LightRock: 0.40/1.00 → 0.00/1.00
- `Well.glb` LightWood: 0.40/1.00 → 0.00/1.00
- `WindowGothic.glb` DarkWood.001: 0.40/1.00 → 0.00/1.00
- `WindowGothic.glb` Glass.001: 0.40/1.00 → 0.00/1.00
- `WindowSquare.glb` DarkWood: 0.40/1.00 → 0.00/1.00
- `WindowSquare.glb` Glass: 0.40/1.00 → 0.00/1.00

### quaternius/medieval_weapons_pack (54)

- `Arrow.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Arrow.glb` Red: 0.40/0.42 → 0.00/0.70
- `Axe.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Axe.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Axe_Double.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Axe_Double.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Axe_Small.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Axe_Small.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Bow_Evil.glb` Black: 0.40/0.42 → 0.00/0.70
- `Bow_Evil.glb` Red: 0.40/0.42 → 0.00/0.70
- `Bow_Evil.glb` White: 0.40/0.42 → 0.00/0.70
- `Bow_Golden.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Bow_Golden.glb` White: 0.40/0.42 → 0.00/0.70
- `Bow_Wooden.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Bow_Wooden.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Bow_Wooden.glb` White: 0.40/0.42 → 0.00/0.70
- `Bow_Wooden2.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Bow_Wooden2.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Bow_Wooden2.glb` White: 0.40/0.42 → 0.00/0.70
- `Claymore.glb` Black: 0.40/0.42 → 0.00/0.70
- `Claymore.glb` DarkBrown: 0.40/0.42 → 0.00/0.70
- `Claymore.glb` LightRed: 0.40/0.42 → 0.00/0.70
- `Claymore.glb` Red: 0.40/0.42 → 0.00/0.70
- `Dagger.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Dagger.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Dagger_2.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Dagger_2.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Hammer_Double.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Hammer_Double.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Hammer_Small.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Hammer_Small.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Scythe.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Scythe.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Shield_Celtic_Golden.glb` Green: 0.40/0.42 → 0.00/0.70
- `Shield_Celtic_Golden.glb` LightBlue: 0.40/0.42 → 0.00/0.70
- `Shield_Heater.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Shield_Heater.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Shield_Heater_2.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Shield_Heater_2.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Shield_Round.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Shield_Round.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Shield_Round_2.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Shield_Round_2.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Shield_Round_2.glb` White: 0.40/0.42 → 0.00/0.70
- `Spear.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Spear.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Sword.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Sword.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Sword_2.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Sword_2.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Sword_Big.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Sword_Big.glb` LightWood: 0.40/0.42 → 0.00/0.70
- `Sword_Golden.glb` DarkWood: 0.40/0.42 → 0.00/0.70
- `Sword_Golden.glb` LightWood: 0.40/0.42 → 0.00/0.70

### environment/dungeon (45)

- `banner_patternA_red.glb` texture: 0.00/0.45 → 0.00/0.70
- `banner_red.glb` texture: 0.00/0.45 → 0.00/0.70
- `banner_shield_red.glb` texture: 0.00/0.45 → 0.00/0.70
- `banner_thin_red.glb` texture: 0.00/0.45 → 0.00/0.70
- `banner_triple_red.glb` texture: 0.00/0.45 → 0.00/0.70
- `barrel_large.glb` texture: 0.00/0.45 → 0.00/0.70
- `barrel_small.glb` texture: 0.00/0.45 → 0.00/0.70
- `barrier_column.glb` texture: 0.00/0.45 → 0.00/0.70
- `box_large.glb` texture: 0.00/0.45 → 0.00/0.70
- `box_stacked.glb` texture: 0.00/0.45 → 0.00/0.70
- `candle_melted.glb` texture: 0.00/0.45 → 0.00/0.70
- `candle_triple.glb` texture: 0.00/0.45 → 0.00/0.70
- `coin_stack_large.glb` texture: 0.00/0.45 → 0.00/0.70
- `coin_stack_medium.glb` texture: 0.00/0.45 → 0.00/0.70
- `coin_stack_small.glb` texture: 0.00/0.45 → 0.00/0.70
- `column.glb` texture: 0.00/0.45 → 0.00/0.70
- `crates_stacked.glb` texture: 0.00/0.45 → 0.00/0.70
- `floor_tile_large_rocks.glb` texture: 0.00/0.45 → 0.00/0.70
- `floor_tile_small_broken_A.glb` texture: 0.00/0.45 → 0.00/0.70
- `floor_tile_small_broken_B.glb` texture: 0.00/0.45 → 0.00/0.70
- `keg.glb` texture: 0.00/0.45 → 0.00/0.70
- `pillar.glb` texture: 0.00/0.45 → 0.00/0.70
- `pillar_decorated.glb` texture: 0.00/0.45 → 0.00/0.70
- `rubble_half.glb` texture: 0.00/0.45 → 0.00/0.70
- `rubble_large.glb` texture: 0.00/0.45 → 0.00/0.70
- `stairs.glb` texture: 0.00/0.45 → 0.00/0.70
- `stairs_wide.glb` texture: 0.00/0.45 → 0.00/0.70
- `sword_shield_broken.glb` texture: 0.00/0.45 → 0.00/0.70
- `table_long_broken.glb` texture: 0.00/0.45 → 0.00/0.70
- `table_medium_broken.glb` texture: 0.00/0.45 → 0.00/0.70
- `torch_lit.glb` texture: 0.00/0.45 → 0.00/0.70
- `torch_mounted.glb` texture: 0.00/0.45 → 0.00/0.70
- `trunk_large_A.glb` texture: 0.00/0.45 → 0.00/0.70
- `wall.glb` texture: 0.00/0.45 → 0.00/0.70
- `wall_arched.glb` texture: 0.00/0.45 → 0.00/0.70
- `wall_archedwindow_open.glb` texture: 0.00/0.45 → 0.00/0.70
- `wall_broken.glb` texture: 0.00/0.45 → 0.00/0.70
- `wall_corner.glb` texture: 0.00/0.45 → 0.00/0.70
- `wall_cracked.glb` texture: 0.00/0.45 → 0.00/0.70
- `wall_doorway_sides.glb` texture: 0.00/0.45 → 0.00/0.70
- `wall_endcap.glb` texture: 0.00/0.45 → 0.00/0.70
- `wall_half.glb` texture: 0.00/0.45 → 0.00/0.70
- `wall_pillar.glb` texture: 0.00/0.45 → 0.00/0.70
- `wall_scaffold.glb` texture: 0.00/0.45 → 0.00/0.70
- `wall_window_open.glb` texture: 0.00/0.45 → 0.00/0.70

### environment/halloween (14)

- `arch.gltf` HalloweenBits: 0.00/0.60 → 0.00/0.70
- `arch_gate.gltf` HalloweenBits: 0.00/0.60 → 0.00/0.70
- `bone_A.gltf` HalloweenBits: 0.00/0.60 → 0.00/0.70
- `bone_B.gltf` HalloweenBits: 0.00/0.60 → 0.00/0.70
- `bone_C.gltf` HalloweenBits: 0.00/0.60 → 0.00/0.70
- `fence_broken.gltf` HalloweenBits: 0.00/0.60 → 0.00/0.70
- `fence_pillar_broken.gltf` HalloweenBits: 0.00/0.60 → 0.00/0.70
- `pillar.gltf` HalloweenBits: 0.00/0.60 → 0.00/0.70
- `post_skull.gltf` HalloweenBits: 0.00/0.60 → 0.00/0.70
- `ribcage.gltf` HalloweenBits: 0.00/0.60 → 0.00/0.70
- `skull.gltf` HalloweenBits: 0.00/0.60 → 0.00/0.70
- `tree_dead_large.gltf` HalloweenBits: 0.00/0.60 → 0.00/0.70
- `tree_dead_medium.gltf` HalloweenBits: 0.00/0.60 → 0.00/0.70
- `tree_dead_small.gltf` HalloweenBits: 0.00/0.60 → 0.00/0.70

### characters/skeletons (8)

- `Skeleton_Axe.gltf` skeleton: 0.00/0.50 → 0.00/0.70
- `Skeleton_Blade.gltf` skeleton: 0.00/0.50 → 0.00/0.70
- `Skeleton_Minion.glb` Glow: 1.00/1.00 → 0.00/1.00
- `Skeleton_Minion.glb` skeleton: 0.00/0.50 → 0.00/0.70
- `Skeleton_Rogue.glb` Glow: 1.00/1.00 → 0.00/1.00
- `Skeleton_Rogue.glb` skeleton: 0.00/0.50 → 0.00/0.70
- `Skeleton_Warrior.glb` Glow: 1.00/1.00 → 0.00/1.00
- `Skeleton_Warrior.glb` skeleton: 0.00/0.50 → 0.00/0.70

### foliage (7)

- `oak_tall.scn` DarkGreen: 0.40/0.42 → 0.00/0.70
- `oak_tall.scn` Green: 0.40/0.42 → 0.00/0.70
- `oak_tall.scn` Wood: 0.40/0.42 → 0.00/0.70
- `pine.scn` Green: 0.40/0.42 → 0.00/0.70
- `pine.scn` Wood: 0.40/0.42 → 0.00/0.70
- `willow.scn` DarkGreen: 0.40/0.42 → 0.00/0.70
- `willow.scn` Wood: 0.40/0.42 → 0.00/0.70

### village_mk (6)

- `Prop_Vine1.gltf` MI_Vine: 0.00/0.50 → 0.00/0.70
- `Prop_Vine2.gltf` MI_Vine: 0.00/0.50 → 0.00/0.70
- `Prop_Vine4.gltf` MI_Vine: 0.00/0.50 → 0.00/0.70
- `Prop_Vine5.gltf` MI_Vine: 0.00/0.50 → 0.00/0.70
- `Prop_Vine6.gltf` MI_Vine: 0.00/0.50 → 0.00/0.70
- `Prop_Vine9.gltf` MI_Vine: 0.00/0.50 → 0.00/0.70

### characters/adventurers (5)

- `Barbarian.glb` barbarian_texture: 0.00/0.50 → 0.00/0.70
- `Knight.glb` knight_texture: 0.00/0.50 → 0.00/0.70
- `Mage.glb` mage_texture: 0.00/0.50 → 0.00/0.70
- `Rogue.glb` rogue_texture: 0.00/0.50 → 0.00/0.70
- `Rogue_Hooded.glb` rogue_texture: 0.00/0.50 → 0.00/0.70

### props_mk (2)

- `Scroll_1.gltf` MI_Page_Empty: 0.00/0.50 → 0.00/0.70
- `Scroll_2.gltf` MI_Page_Empty: 0.00/0.50 → 0.00/0.70
