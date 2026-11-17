# Offline checks

Run from the Sintezza_Loot repository root with Python 3.12 and Lupa 2.8. The runner explicitly selects Lupa's Lua 5.1 engine. It compiles every shipped Lua file, checks TOC paths and version consistency, then runs history, CSV and UI-state mocks. It does not start or contact WoW.

```powershell
python -m pip install --target .test-deps lupa==2.8
$env:PYTHONPATH = Join-Path (Get-Location) '.test-deps'
python Tests/run.py
```

In the Codex bundled environment, use this Python executable if `python` resolves to the Windows Store alias:

```powershell
$testPython = 'C:\Program Files\WindowsApps\OpenAI.CodexPrimaryRuntime.v26-1112-611-0_26.1112.611.0_x64__3k8sg7r9htsxt\dependencies\python\python.exe'
$env:PYTHONPATH = 'D:\Games\WoW_addons\.loot-verification-20261117\python'
& $testPython Tests/run.py
```

Expected result: eighteen PASS lines, exit code 0. Tests and local dependencies are excluded from installation and ZIP packaging. `Test/Simulator.lua` remains part of the addon.

## Coverage for 1.6.0

- Empty visits and unfinished or simulated rolls create no saved run. The first recorded roll saves the original visit time.
- A failed encounter, ghost return, living return and reload preserve a run. A hidden difficulty value does not split it. Target GUIDs are not a boundary signal.
- Confirmed resets, another map/difficulty, group departure and challenge starts/resets separate runs, including challenge events received outside.
- Delayed results retain their original run after completion, leaving and garbage collection. Clearing rolls removes empty metadata without losing the current in-memory visit. Deleted rolls cannot be restored by late updates.
- Old-data cleanup is idempotent and retains loot, attempt counts and monotonically increasing IDs. The 400-roll limit and CSV import/export still work; imports skip unreferenced runs and report that in the preview.
- History rows use Theme's `RowBand`, `MenuHighlight` and `DisclosureArrow`. The whole row toggles details. Pooled participant rows reset the self outline, and wins and losses use the same outline without the self tag.

## Run identity requirements and acceptance for 1.7.0

The run-tracking changes use no timeout and no creature GUID inference. Tests are in `RunEvidence.lua` and the existing history fixtures. The source pin remains Forever 1.60.1.70938 below. No new window controls or configurable preferences are added; `/sloot newrun` is available through the existing slash-command handler and help text.

| Requirement | Implementation | Offline acceptance |
| --- | --- | --- |
| RUN-1: empty visits do not create archived runs | Pending run objects; persistence on recorded roll | Original empty/history/migration tests pass |
| RUN-2: wipe returns have no duration limit | An unfinished run keeps its presence across exits | Return after three days resumes; no timer or date boundary |
| RUN-3: successful reset overrides continuation | Exact client-localized success notification; challenge reset events | Immediate successful reset splits; failure and other-instance messages do not |
| RUN-4: completion leaves room for trash loot | Completed presence retained inside, cleared on confirmed exit | Trash, reload, reconnect and late results retain the original run; next-day re-entry after exit starts another |
| RUN-5: additional evidence is applied conservatively | Unique locked map/difficulty match after `RequestRaidInfo`; validated lock-prompt snapshot | Changed save key or a previously dead boss now alive separates the visit; missing, secret, inconsistent or out-of-context data does not |
| RUN-6: late evidence cannot move earlier visits | Persistent visit IDs; pending sessions retain their visit object | Current visit rolls and kills move together, including across reload; previous visits are unchanged |
| RUN-7: no completion guess based on journal order | All encounters in an available journal list must be recorded killed | Killing only the last listed boss leaves the run open |
| RUN-8: unknown cases have a manual boundary | `/sloot newrun` closes history presence and starts a new pending run on entry | Works inside/outside; no game instance reset and no old-record reassignment |
| RUN-9: existing history and transfer remain compatible | Optional run evidence; runtime visit IDs excluded from CSV | Old-data cleanup and repeated initialization pass; CSV round trip retains lock/progress evidence and manual end reasons |

Each visit captures its pre-entry progress. Fresh kills during that visit are not compared against a delayed snapshot as if they happened before entry. When late evidence splits a visit, its observed kills move along with its rolls. API refresh requests defer during combat and are event-driven.

The remaining ambiguity is explicit: matching progress or a missing saved-instance row cannot prove the identity of a normal dungeon copy. Unknown data keeps the current unfinished run; the manual command can separate future rolls. A journal catalog and completion APIs may be unavailable in Forever, so optional completion paths are capability-checked. Actual event delivery and nonempty dungeon data remain untested in game.

## UI scope and acceptance

The user's screenshots and instructions define the visual change: preserve Theme's palette, fonts and item colors; use a flat expandable list and a quiet one-pixel outline for the player. The arrow communicates expansion, the alternating band helps scanning, and the outline communicates identity independently of winning. No new artwork or animation is added. Antislop mode: during, selected for this chat. ENERGY 1, RHYTHM 1, MOTION 0 for these rows.

The existing item tooltip and native button click remain reachable with the pointer. A controller cursor can use the same row hit area; native directional navigation, focus acquisition and controller operation were not tested or newly implemented. There is no new input capture or binding change. The outline is decorative and does not intercept input. Mocks exercise the addon-owned controls with combat lockdown enabled; they do not prove client behavior or rendered layout.

Delivery checks: PASS for using the existing Theme components and the user-selected design; PASS for working row actions and clearing recycled state in mocks; PASS for keeping data-backed item names, results and counts; PASS for avoiding new assets, text labels and animations. Rendered appearance, minimum-width/scale layout, tooltip input handoff and controller use require the user's game check and are not claimed as passed.

## API evidence and limits

Target: WoW Forever 1.60.1, interface 16001. Source mirror reviewed 2026-11-17 at Gethe/wow-ui-source commit `bebcb6bf309cf41b41bd74f8ca651e6a105b2676` (1.60.1.70938). The current installed client build was not queried.

- [InstanceDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/InstanceDocumentation.lua): `GetInstanceInfo` supplies the instance name/type/difficulty/map fields used by the existing tracker; `GetInstanceLockTimeRemaining` supplies encounter totals. Secret or unavailable identifying values are ignored before comparison.
- [UnitDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua): `UnitIsGhost` reports a unit state, not a persistent run identity. No ghost-state dependency is required.
- [RaidFrame.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_RaidFrame/Mainline/RaidFrame.lua): the native UI requests saved-instance data with `RequestRaidInfo`, handles `UPDATE_INSTANCE_INFO`, and reads `GetSavedInstanceInfo`. Loot accepts only a unique locked record matching map, difficulty and instance kind; absent or incomplete records do not imply a reset.
- [EncounterInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/EncounterInfoDocumentation.lua): typed payloads for `ENCOUNTER_END`, `BOSS_KILL`, and the lock-prompt start/warning/stop events. Loot does not infer completion from failed encounters.
- [GameDialogDefs.lua](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_StaticPopup_Game/GameDialogDefs.lua): the lock dialog uses `GetInstanceLockTimeRemaining` and `GetInstanceLockTimeRemainingEncounter`. Loot reads these only during the corresponding prompt lifecycle, requires a complete consistent nonsecret snapshot, and compares only evidence from before the current visit. General `UPDATE_INSTANCE_INFO` events outside that lifecycle cannot produce progress-based resets.
- `C_RaidLocks.IsEncounterComplete` is not used to infer that a boss is alive in the current copy; player lock credit is not a universal current-copy snapshot. `C_Commentator.GetInstanceInfo` is excluded because its generated contract requires commentator access.
- The NPC GUID copy heuristic is removed. When no reset notification is available, another copy of the same map/difficulty may remain grouped with the previous visit. A time limit is deliberately not used to infer a new run. Old populated runs are not merged without evidence.

Source declarations, offline tests, and in-game event delivery are separate evidence. Per project instructions, no game launch, in-game automation, WTF edit or SavedVariables file edit was performed. The migration runs through the addon's normal initialization.
