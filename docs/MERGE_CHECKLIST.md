# Merge checklist (before every merge to `main`)

Nothing is merged to `main` until every line below is green on the branch's last commit. Set
`G="C:/Users/User/Documents/games/_tools/godot/Godot_v4.7.2-stable_win64_console.exe"` and run from the project root.

## 1. The headless suites (all of them, every time)

| Suite | Command | Ends with |
|---|---|---|
| State, saves, menu, presets, material rule | `"$G" --headless --path . res://scenes/tests/state_test.tscn` | `STATE SELFTEST DONE, failures: 0` |
| Echoes | `"$G" --headless --path . res://scenes/tests/echo_test.tscn` | `ECHO TESTS DONE, failures: 0` |
| NPCs, ally | `"$G" --headless --path . res://scenes/tests/npc_test.tscn` | `NPC TESTS DONE, failures: 0` |
| Son Ocak hub | `"$G" --headless --path . res://scenes/tests/hub_test.tscn` | `HUB TESTS DONE, failures: 0` |
| Story foundation | `"$G" --headless --path . res://scenes/tests/story_test.tscn` | `STORY TESTS DONE, failures: 0` |
| Combat, AI, encounters, balance (~4 min) | `"$G" --headless --path . res://scenes/tests/combat_test.tscn` | `COMBAT TESTS DONE, failures: 0` |
| Animation isolation | `"$G" --headless --path . -s tools/test_anim_isolation.gd` | `ANIM ISOLATION DONE, failures: 0` |

## 2. The windowed checks

| Check | Command | Ends with |
|---|---|---|
| Open world | `"$G" --path . res://scenes/world.tscn -- --demo=world_selftest` | `WORLD SELFTEST DONE, failures: 0` |
| Session flow, launch 1 | `P="$TEMP/aotc_flow"; rm -rf "$P"; mkdir -p "$P"; APPDATA="$(cygpath -w "$P")" FLOW_PHASE=1 "$G" --path . res://scenes/tests/flow_test.tscn` | `FLOW TEST DONE (phase 1), failures: 0` |
| Session flow, launch 2 | `APPDATA="$(cygpath -w "$P")" FLOW_PHASE=2 "$G" --path . res://scenes/tests/flow_test.tscn` | `FLOW TEST DONE (phase 2), failures: 0` |

The flow test plays the real game on a clean user profile (it never touches the player's own saves or settings):
New Game → the valley and the first-launch benchmark → light a hearth → Son Ocak → change the preset in the settings →
save → quit; then a restart → Continue → the preset and the lit hearth are still there.

## 3. Then

- Models or materials changed: `"$G" --headless --path . -s tools/audit_materials.gd` reports 0 violations.
- `git merge --no-ff <branch>` on `main`, tag if the owner asked for one, `git push` (and push the tag).
- A red line is not merged "for now": fix it on the branch, or tell the owner first.
