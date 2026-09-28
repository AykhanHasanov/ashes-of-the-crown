# Backlog

Notes to decide or clean up later. Not scheduled; nothing here is being worked on.

- **"Kül Şahının gözü" affix.** Enemies with this affix see the player from anywhere. Decide later whether this is a bug or intended; if intended, it needs a clear visual/audio tell so the player understands why they were spotted.
- **Headless log noise: `Parameter "material" is null`.** Printed many times in headless runs (tests, captures). Clean it up later: it can hide real errors in the test output.
- **MUST-FIX before the vertical slice — permanent burn power.** Burning must grant a PERMANENT power (e.g. unlock or upgrade a fire ability per memory). Today a burn gives a one-time Alov Dalğası (placeholder). Solve together with consolidating memory effects.
- **Memories at the hub hearth.** Kept memories can be re-watched at the hearth in the hub; burned ones remain as empty slots in that list.
- **Villager facing.** `scripts/npc/villager.gd` turns its model with `atan2(x, z)` while the Human model faces -Z (the protagonist, enemies and the new NPC scripts use `atan2(-x, -z)`). Check in game whether villagers face away from what they look at.
