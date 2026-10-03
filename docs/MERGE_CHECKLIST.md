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

## 3. Performance (only when the merge touches lighting, materials, shaders, presets or scene geometry)

On a clean profile, nothing else running on the machine. **Low is the gate** (integrated GPU = minimum spec),
**Medium is a relative indicator**. Only the MEDIAN counts: the 1 % low swings by 7–12 ms between runs of the same
build (`docs/PERF_PROFILE.md`, stage D epilogue), so it is recorded, never decisive.

```
P="$TEMP/aotc_perf_$(date +%H%M%S)"; mkdir -p "$P"; export APPDATA="$(cygpath -w "$P")"
for q in low medium; do
  PERF_FAST=1 PERF_SCENE=world              "$G" --path . res://scenes/tests/perf_probe.tscn -- --demo=perf --quality=$q
  PERF_FAST=1 PERF_SCENE=world PERF_SPOT=village "$G" --path . res://scenes/tests/perf_probe.tscn -- --demo=perf --quality=$q
  PERF_FAST=1 PERF_SCENE=hub                "$G" --path . res://scenes/tests/perf_probe.tscn -- --demo=perf --quality=$q
done
```

Each prints `PERF_JSON {...}` (`base.median_fps`, `base.median_ms`, `monitors.draw_calls`). Run each spot **three
times and take the middle run** — Kürköy swings by ±2 ms and a best-of-three reading once produced a baseline that
later looked like a regression.

- **Low must be ≥ 45 fps median** at the valley's start, in Kürköy and in Son Ocak. Below that the branch is not
  merged — fix it or tell the owner first.
- **Medium may not be more than 1 ms worse** than the baseline table in `docs/PERF_PROFILE.md` (stage D epilogue).
  A known, explained cost is fine and goes in the merge commit; an unexplained one is not merged.
- Update that baseline table when the numbers change on purpose.

## 4. Then

- Models or materials changed: `"$G" --headless --path . -s tools/audit_materials.gd` reports 0 violations.
- `project.godot` still has `run/main_scene="res://scenes/main.tscn"`. A test branch may point
  Play at its own scene; that line must never reach `main`.
- `git merge --no-ff <branch>` on `main`, tag if the owner asked for one, `git push` (and push the tag).
- A red line is not merged "for now": fix it on the branch, or tell the owner first.
