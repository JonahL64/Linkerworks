---
title: 'Restore whole-app responsiveness'
type: 'bugfix'
created: '2026-07-26'
status: 'done'
review_loop_iteration: 0
baseline_commit: 'ce6ca06e7cf487028cf9af449453e664b255e9e7'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Routine taps and navigation can stall because view redraws repeatedly rescan and sort full SwiftData result sets, recompute the same completion state, and refresh unrelated widgets on the main thread. The cost grows with completion, planning, and homework history.

**Approach:** Build each screen's derived state once per data change, use day-key indexes for repeated lookups, and refresh only the widget affected by a mutation. Preserve the current storage model, visual design, routine semantics, and historical records.

## Boundaries & Constraints

**Always:** Keep all persisted data and App Group compatibility intact; preserve late-night routine-day, goalkeeping rest-day, substep, skip, streak, calendar, assignment, and widget behavior; use pure helpers for derived indexes so correctness can be regression-tested; keep UI mutations on the main actor.

**Ask First:** Any schema migration, data deletion/rewrite, visual or interaction change, new dependency, or architectural restructuring beyond localized projection/index helpers.

**Never:** Hide latency with arbitrary delays, drop records from history, weaken save/rollback handling, disable widget updates, add networking/background services, or change feature scope.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| Routine tap | Long completion history; parent, child, skipped, or goalkeeping task | Tap updates promptly; progress, phase state, collapse behavior, undo, and widget remain correct | Failed save rolls back and shows the existing error |
| Plan render | Many historical events, assignments, and to-dos | Month markers and selected-day agenda use indexed day lookups and match existing ordering | Invalid/no-due items remain excluded as today |
| Progress render | Long snapshot and completion history | Streaks, heatmap, recent trend, and weekly rollup retain their exact values without repeated full-history scans | Missing historical snapshots remain neutral |
| Widget refresh | Routine-only or assignment-only mutation | Only the affected widget timeline reloads; app and widget projections agree | Widget load failure keeps the existing unavailable state |
| Midnight/rest-day | Held prior routine day or inactive goalkeeping rest-day records | Selected day and ignored records are resolved once per projection and preserve current semantics | No stored selection/state falls back exactly as today |

</frozen-after-approval>

## Code Map

- `Linkerworks/ContentView.swift` -- Today queries, repeated completion derivation, tap/save paths, rollover, and widget refresh calls.
- `Linkerworks/Domain.swift` -- historical completion projection, goalkeeping ignored records, and widget timeline API.
- `Linkerworks/CalendarPlanView.swift` -- repeated per-cell event/assignment/to-do filtering and ordering.
- `Linkerworks/StreaksView.swift` -- repeated snapshot and completion-history scans across streak and heatmap calculations.
- `LinkerworksWidget/LinkerworksWidget.swift` -- widget fetch/projection path.
- `LinkerworksTests/HistoricalProgressTests.swift` -- historical completion and streak regression coverage.
- `LinkerworksTests/WidgetProjectionTests.swift` -- shared widget projection and refresh-routing coverage.
- `STATE.md` -- implementation record and remaining device-validation note.

## Tasks & Acceptance

**Execution:**
- [x] `Linkerworks/ContentView.swift` -- derive today's record states once and reuse task/phase completion sets; replace unrelated widget reloads with targeted refreshes.
- [x] `Linkerworks/Domain.swift` -- add explicit routine/assignment reload entry points and reusable day/state projection helpers that avoid repeated defaults decoding and sorting.
- [x] `Linkerworks/CalendarPlanView.swift` -- group and order events, active assignments, and to-dos by normalized day key once per redraw.
- [x] `Linkerworks/StreaksView.swift` -- pre-index snapshots and records by day and share one summary projection through a redraw.
- [x] `LinkerworksWidget/LinkerworksWidget.swift` -- constrain fetches where supported and reuse completion-state sets instead of rebuilding them per task.
- [x] `LinkerworksTests/HistoricalProgressTests.swift`, `LinkerworksTests/WidgetProjectionTests.swift` -- cover indexed projections, ignored records, ordering, and routine/assignment refresh separation without changing outcomes.
- [x] `STATE.md` -- append the performance fix, touched paths, verification, and device profiling limitation.

**Acceptance Criteria:**
- Given accumulated history, when a routine item is completed, skipped, undone, or restored, then the Today screen performs one day-state projection per redraw and all visible counts remain correct.
- Given a month grid, when Plan renders or changes month/day, then each persisted collection is grouped once rather than scanned for every day cell.
- Given Progress history, when streak content renders, then day records and snapshots are dictionary lookups and all existing historical tests still pass.
- Given a routine mutation, when WidgetKit is notified, then only the routine widget reloads; assignment mutations reload only the assignment widget.
- Given the current repository constraints, when static checks complete, then touched Swift files parse and the project file remains valid; final on-device responsiveness is explicitly reported as a manual check.

## Spec Change Log

## Verification

**Commands:**
- `swiftc -parse <touched Swift files>` -- expected: parser exits successfully.
- `plutil -lint Linkerworks.xcodeproj/project.pbxproj` -- expected: project file is valid.
- `git diff --check` -- expected: no whitespace errors.

**Manual checks (if no CLI):**
- On iPhone with existing data, rapidly complete/undo routine items, change tabs, scroll Progress, and move between Plan months; taps should no longer freeze and all counts/markers/widgets should stay correct.

## Suggested Review Order

**Today interaction path**

- Start with the shared day projection that removes repeated row-level history work.
  [`ContentView.swift:56`](../../Linkerworks/ContentView.swift#L56)

- Selected-day fetches keep minute redraws independent of accumulated history.
  [`ContentView.swift:1212`](../../Linkerworks/ContentView.swift#L1212)

- Tap handlers reuse projected state for phase, skip, undo, and final-day behavior.
  [`ContentView.swift:1025`](../../Linkerworks/ContentView.swift#L1025)

**Shared projections and retained tabs**

- Skip-aware completion is now one shared rule for Today, Progress, and widgets.
  [`Domain.swift:358`](../../Linkerworks/Domain.swift#L358)

- Progress indexes historical states once and caches across unrelated view redraws.
  [`StreaksView.swift:63`](../../Linkerworks/StreaksView.swift#L63)

- Plan caches deterministic day indexes instead of scanning each calendar cell.
  [`CalendarPlanView.swift:163`](../../Linkerworks/CalendarPlanView.swift#L163)

**Widget isolation**

- Explicit refresh targets prevent routine mutations from rebuilding assignment timelines.
  [`Domain.swift:10`](../../Linkerworks/Domain.swift#L10)

- Separate providers isolate routine and assignment fetch costs and failures.
  [`LinkerworksWidget.swift:78`](../../LinkerworksWidget/LinkerworksWidget.swift#L78)

**Regression coverage**

- Lift skips and legacy parent records verify UI-progress semantic agreement.
  [`HistoricalProgressTests.swift:363`](../../LinkerworksTests/HistoricalProgressTests.swift#L363)

- Plan ordering and assignment ties protect deterministic indexed projections.
  [`WidgetProjectionTests.swift:91`](../../LinkerworksTests/WidgetProjectionTests.swift#L91)
