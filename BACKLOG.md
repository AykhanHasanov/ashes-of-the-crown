# Backlog

Notes to decide or clean up later. Not scheduled; nothing here is being worked on.

- **"Kül Şahının gözü" affix.** Enemies with this affix see the player from anywhere. Decide later whether this is a bug or intended; if intended, it needs a clear visual/audio tell so the player understands why they were spotted.
- **Headless log noise: `Parameter "material" is null`.** Printed many times in headless runs (tests, captures). Clean it up later: it can hide real errors in the test output.
- ~~**MUST-FIX before the vertical slice — permanent burn power.**~~ Done for the slice (A2, `scripts/combat/burn_power.gd`: weight ≥ 2 = +1 Köz Darbesi, weight 1 = faster Köz, diminishing). Still open: replace it with İbrahim's ash upgrades, and decide whether the one-time Alov Dalğası on a burn stays.
- **Memories at the hub hearth.** Kept memories can be re-watched at the hearth in the hub; burned ones remain as empty slots in that list.
- **Villager facing.** `scripts/npc/villager.gd` turns its model with `atan2(x, z)` while the Human model faces -Z (the protagonist, enemies and the new NPC scripts use `atan2(-x, -z)`). Check in game whether villagers face away from what they look at.
- **Pre-vertical-slice: mood pass.** Gradient from a faded late-autumn valley with light ash, to fully desaturated near Közkale; colour returns in Son Ocaq as grief is resolved. Lighting, fog, ash particles, saturation only — no new assets.
- **Valley entrance to Son Ocaq.** Replace the signpost by Geçit Ocağı with visible caravanserai walls and a gate; the transition happens when walking through the gate.
- **Hub room doors open inward** once the rooms have interiors (they swing out into the gallery for now).
- **MUST before the vertical slice: Kürköy art identity pass.** A Caucasus mountain village (reference: Xınalıq, Lahıc): flat-roofed stone houses, terraced on the slopes, the same visual language as the caravanserai. No marketing screenshots before this.
- **Art pass: pointed (sivri) arches** instead of round arches in the caravanserai.
- **Kartal Yamacı into the terrain.** It is a separate scene for the slice (reached by a trail from the valley road); integrate it into the valley terrain later.
