---
title: 'Restore immediate Today interactions'
type: 'bugfix'
created: '2026-07-27'
status: 'done'
review_loop_iteration: 0
baseline_commit: 'b2546f14631863a2e2ce007be088b47590d3edcc'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Entering text in Today’s quick to-do field stutters because each keystroke invalidates the entire Today screen and its routine/history-derived view state. Completing a routine item also incurs an unnecessary scan of the complete day-snapshot history before its required local persistence work, which dulls the completion response as history grows.

**Approach:** Isolate draft text editing from the Today screen’s expensive projections, and change the required snapshot lookup to address only the selected day. Preserve all existing Today behavior, data, visual design, completion history, undo, haptics, and widget updates.

## Boundaries & Constraints

**Always:** Keep SwiftData/App Group schemas and persisted records unchanged; keep successful to-do add/edit/delete/toggle behavior, routine completion/skip/undo, lifted-child semantics, historical snapshots, error rollback, haptics, and routine widget refreshes exactly correct; retain the existing Paper & Ink tokens and interaction affordances; keep UI-owned mutations on the main actor.

**Ask First:** Any schema migration, data rewrite/deletion, visual or interaction redesign, background service, new dependency, or change to widget-refresh behavior beyond removing redundant work.

**Never:** Debounce or delay typing/completion to hide the issue; perform broad data fetches merely to test whether one day already has a snapshot; weaken save/rollback handling; remove the completion moment, undo, or haptic feedback; change task, skip, late-night, rest-day, or historical-progress semantics.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|---------------------------|----------------|
| Quick to-do drafting | User types, edits, or clears text before submitting | Keystrokes redraw only the composer; Today’s routine/history projection does not run until a persisted change occurs | Blank submit retains existing validation message and creates no record |
| Quick to-do submit | Valid title on the selected routine day | One correctly ordered `DailyTodo` is saved, the field clears, and the new row appears | Save failure rolls back, keeps the draft available, and presents the existing save error |
| Routine completion | Existing snapshot for the selected day and long snapshot history | The command checks that one day directly, writes the same records, then Today updates, haptics/undo/widget behavior remains intact | A failed lookup or save preserves existing rollback/error behavior |
| First completion on a day | No day snapshot exists | The snapshot is captured once using the existing scheduled-task/child-unit rules before completion persists | Failure creates no partial completion state |

</frozen-after-approval>

## Code Map

- `Linkerworks/ContentView.swift` -- owns the Today list, quick to-do text state, routine projection, and synchronous completion feedback path.
- `Linkerworks/Domain.swift` -- `RoutineCompletionCommand` captures/checks daily snapshots before the authoritative completion save.
- `LinkerworksTests/DailyTodoTests.swift` -- covers ordering and selected-day identity of independent daily to-dos.
- `LinkerworksTests/HistoricalProgressTests.swift` -- establishes snapshot idempotency and historical completion invariants.
- `LinkerworksTests/WidgetProjectionTests.swift` -- verifies the shared routine completion command, including child-derived lift writes.
- `STATE.md` -- receives the session handoff and device-profiling limitation.

## Tasks & Acceptance

**Execution:**
- [x] `Linkerworks/ContentView.swift` -- moved the unsaved quick-to-do title/validation into a focused composer view with local draft state; only persistence outcomes return to Today.
- [x] `Linkerworks/ContentView.swift` -- retained validation, ordering, save/rollback, haptic, accessibility, and visible row behavior; failed saves retain the draft.
- [x] `Linkerworks/Domain.swift` -- made `DaySnapshotService.captureIfNeeded` use a day-key-constrained SwiftData lookup before fetching tasks.
- [x] `LinkerworksTests/DailyTodoTests.swift` -- covered blank/trimmed drafts and deterministic next-order selection through the extracted pure helper.
- [x] `LinkerworksTests/HistoricalProgressTests.swift` -- covered reuse of an existing same-day snapshot alongside unrelated historical snapshots.
- [x] `LinkerworksTests/WidgetProjectionTests.swift` -- covered lift-child completion writes with historical snapshots already present.
- [x] `STATE.md` -- will receive the final repair handoff after review and final static verification.

**Acceptance Criteria:**
- Given a populated Today screen, when the user enters or deletes characters in Add a to-do, then the routine completion projection is not recomputed per character and input remains immediately responsive.
- Given a valid quick to-do, when the user submits it, then it appears once on the selected day in deterministic next order and the composer clears only after a successful save.
- Given an empty quick-to-do or persistence failure, when submitted, then no empty/partial `DailyTodo` remains and the user can correct or retry without losing valid entered text.
- Given many `DaySnapshot` records, when a user completes, uncompletes, skips, or batch-completes Today work, then the snapshot precondition reads only the selected day; records, progress, collapses, undo, haptics, final-day moment, and routine widget refresh remain equivalent.
- Given the first completion on a previously uncaptured day, when it saves, then exactly one immutable snapshot with the existing scheduled-task and child-unit data is created before the completion record.

## Spec Change Log

## Design Notes

The composer should own transient text because it is the only state changing on every keypress. Today should receive a persisted-change signal rather than a parent-owned character binding. The snapshot optimization is deliberately a query-shape change, not a cache, so it stays correct across app relaunches and external widget/app changes.

## Verification

**Commands:**
- `swiftc -parse Linkerworks/ContentView.swift Linkerworks/Domain.swift LinkerworksTests/DailyTodoTests.swift LinkerworksTests/HistoricalProgressTests.swift LinkerworksTests/WidgetProjectionTests.swift` -- expected: parser exits successfully.
- `git diff --check` -- expected: no whitespace errors.

**Manual checks (if no CLI):**
- On a populated device store, type rapidly in Add a to-do, submit a valid item, retry after a blank submit, and toggle normal/lift routine work repeatedly. Text entry and checkmarks should respond immediately while rows, progress, undo, haptics, snapshots, and widget next-task state remain correct.

## Suggested Review Order

**Typing isolation**

- The Today list passes only stable persistence inputs into the independently stateful composer.
  [`ContentView.swift:584`](../../Linkerworks/ContentView.swift#L584)

- Draft text and validation are isolated, while save/rollback and haptics retain existing behavior.
  [`ContentView.swift:1329`](../../Linkerworks/ContentView.swift#L1329)

- Pure validation and sort-order logic make the composer’s persistence inputs deterministic.
  [`ContentView.swift:1389`](../../Linkerworks/ContentView.swift#L1389)

**Completion latency**

- Existing snapshots are resolved by exact day key and capped at one record.
  [`Domain.swift:530`](../../Linkerworks/Domain.swift#L530)

**Regression boundaries**

- Draft validation and overflow-safe next ordering are covered without SwiftUI interaction scaffolding.
  [`DailyTodoTests.swift:54`](../../LinkerworksTests/DailyTodoTests.swift#L54)

- Historical snapshot reuse remains idempotent in a populated snapshot store.
  [`HistoricalProgressTests.swift:176`](../../LinkerworksTests/HistoricalProgressTests.swift#L176)

- Lift completion still writes child records when historical snapshots already exist.
  [`WidgetProjectionTests.swift:180`](../../LinkerworksTests/WidgetProjectionTests.swift#L180)
