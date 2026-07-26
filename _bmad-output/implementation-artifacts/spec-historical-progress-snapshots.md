---
title: 'Historical progress snapshots and skip states'
type: 'bugfix'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
baseline_commit: '85e3e6af6428116eba791c3e24e253d0a4945868'
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/STATE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Progress currently recomputes historical denominators from each task's live weekday assignment and archive state. Editing or archiving a task therefore changes past streaks and heatmap cells. Completion records also cannot distinguish a completed task from an intentional skip.

**Approach:** Capture each day's scheduled task IDs once, backfill the captured schedule for existing completion dates, and calculate historical Progress only from those snapshots plus stateful completion records. Preserve the current lift-parent-as-one-task rule with immutable parent-to-child snapshot metadata, and make skips neutral to the skipped task's numerator and denominator.

## Boundaries & Constraints

**Always:** Keep storage in the existing App Group SwiftData store. Add `DaySnapshot` with unique `dayKey`, `[UUID] scheduledTaskIDs`, and `capturedAt`; never overwrite an existing snapshot. Persist `CompletionRecord` state as `complete` or `skipped`, with legacy records reading as complete. Use live task schedule/archive state only for today before its first capture; older dates without a snapshot are neutral. Preserve parent/child history by capturing parent-to-child completion-unit metadata alongside the required snapshot model. Keep existing task archival behavior and the dark flat visual language. Preserve unrelated dirty-worktree changes.

**Ask First:** Any change to seed data, App Group identifier/store path, task-management archival semantics, navigation, or non-Progress product behavior beyond making skipped records truthful where they are already displayed.

**Never:** Rebuild or overwrite a historical snapshot; derive a past Progress denominator from current task schedule/archive state; delete historical completion records to implement skip; add networking, accounts, notifications, or dependencies.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|---------------------------|----------------|
| First capture | Today is rendered or a completion/skip is written and no snapshot exists | Persist today's current scheduled top-level IDs and lift child mapping once before the UI/record write relies on it | If save fails, do not write the completion mutation and show the existing save error |
| Legacy backfill | Existing completion dates and no completed migration marker | Create only missing snapshots from current state, save, then set the versioned App Group marker | A failure leaves the marker unset; retry remains idempotent through unique day keys |
| Archived/rescheduled history | A task changes after a prior day was captured | Prior completion, heatmap, and weekly result are unchanged | Missing past snapshot is neutral, never live-data fallback |
| Skip | A scheduled task has a `.skipped` record | Exclude that task from both daily numerator and denominator; a fully skipped day is neutral | A later complete/unskip replaces/removes the same task-day state without duplicates |
| Lift substeps | A captured parent had child substeps | Parent remains one scheduled unit and uses its captured child IDs, ignoring later child archive/edit state | Legacy parent-only records remain compatible |

</frozen-after-approval>

## Code Map

- `Linkerworks/Models.swift` -- SwiftData task, completion-record, and new snapshot model declarations.
- `Linkerworks/SharedModelContainer.swift` -- App Group SwiftData schema registration.
- `Linkerworks/LinkerworksApp.swift` -- ordered shared-store startup after seed import.
- `Linkerworks/ContentView.swift` -- Today capture, stateful completion mutation/undo, row rendering, and swipe skip control.
- `Linkerworks/StreaksView.swift` -- streak, heatmap, current-week calculation and explanatory copy.
- `Linkerworks/Domain.swift` -- reusable historical completion/snapshot calculation types and lift-unit semantics.
- `LinkerworksWidget/LinkerworksWidget.swift` -- avoid treating skipped records as completed in the existing today widget.
- `Linkerworks/TrackersView.swift` -- distinguish skipped history from actual completions in existing tracker history.
- `LinkerworksTests/HistoricalProgressTests.swift` and `Linkerworks.xcodeproj/project.pbxproj` -- focused regression coverage and its XCTest target.

## Tasks & Acceptance

**Execution:**
- [x] `Linkerworks/Models.swift` and `Linkerworks/SharedModelContainer.swift` -- add `DaySnapshot`, its immutable lift-completion-unit companion, and default-complete record state; register all models without changing the shared store location.
- [x] `Linkerworks/Domain.swift` and `Linkerworks/LinkerworksApp.swift` -- add day-key/snapshot capture and versioned, save-before-marker backfill services; run the migration after seed import and expose deterministic, pure daily-progress calculation inputs.
- [x] `Linkerworks/ContentView.swift` -- capture today on first render and before mutation; make completion/skip state mutually exclusive, preserve it through Undo, and add accessible swipe skip/unskip with muted non-green skipped rows.
- [x] `Linkerworks/StreaksView.swift` -- query snapshots, use immutable snapshot IDs and lift mappings for historical dates, treat zero effective scheduled IDs as neutral, update heatmap/current-week/streak calculations and Progress copy.
- [x] `LinkerworksWidget/LinkerworksWidget.swift` and `Linkerworks/TrackersView.swift` -- filter widget completion to `.complete` and label/count skipped tracker history truthfully.
- [x] `LinkerworksTests/HistoricalProgressTests.swift` and `Linkerworks.xcodeproj/project.pbxproj` -- add narrow tests for archive-stable historical calculations, neutral fully skipped days, idempotent backfill, and legacy default-complete state.
- [x] `STATE.md` -- append a concise migration handoff, changed paths, validation, and runtime verification gap.

**Acceptance Criteria:**
- Given a captured historical day, when any of its tasks or child substeps are archived or rescheduled, then recomputing Progress leaves that day's heatmap cell and completion result unchanged.
- Given complete day one, a fully skipped captured day two, and complete day three, when streaks are recomputed, then day two neither increments nor breaks the two-day run.
- Given legacy completion records and no migration marker, when startup backfill runs twice, then each qualifying day has exactly one unchanged snapshot and the marker is recorded only after successful persistence.
- Given an existing completion record with no stored state, when it is read after migration, then it is treated as `.complete` throughout Today, Progress, widget, and history.
- Given a Today task is skipped, when it is rendered, then it is muted with a distinct non-green glyph and its swipe action can unskip it or a normal check can mark it complete.

## Design Notes

The required `DaySnapshot.scheduledTaskIDs` remains the authoritative top-level denominator. A related immutable completion-unit record captures child IDs for parents that used substeps when the day was captured; this prevents a later child archive, addition, or edit from reinterpreting an old parent. The calculator uses snapshot metadata and records, not current schedule/archive fields, for every past date. A date that predates snapshots and has no backfilled completion record is intentionally unknown/neutral rather than guessed from today's routine.

## Verification

**Commands:**
- `swiftc -parse Linkerworks/*.swift LinkerworksWidget/*.swift` -- expected: all source files parse.
- `git diff --check` -- expected: no whitespace errors.
- `xcodebuild test -project Linkerworks.xcodeproj -scheme Linkerworks -destination 'platform=iOS Simulator,name=<available simulator>'` -- expected: focused historical-progress tests pass when full Xcode is available.

**Manual checks (if no CLI):**
- In Xcode/Simulator, capture a day, archive/reschedule its task, relaunch, and compare the historical heatmap cell and rollup; skip all scheduled tasks between two complete days; verify Progress copy, Today glyph/swipe/Undo, and widget next-task behavior.

## Suggested Review Order

**Migration entry point**

- Runs seed import before a save-before-marker historical backfill.
  [`LinkerworksApp.swift:8`](../../Linkerworks/LinkerworksApp.swift#L8)

- Captures immutable day IDs and lift child units, then backfills only missing keys.
  [`Domain.swift:160`](../../Linkerworks/Domain.swift#L160)

**Historical calculation**

- Applies complete/skip states without consulting live schedule or archive fields.
  [`Domain.swift:72`](../../Linkerworks/Domain.swift#L72)

- Defines the lightweight-migration default and immutable snapshot relationship.
  [`Models.swift:211`](../../Linkerworks/Models.swift#L211)

- Selects snapshots for historical Progress and keeps missing past dates neutral.
  [`StreaksView.swift:288`](../../Linkerworks/StreaksView.swift#L288)

**Today and shared readers**

- Captures before mutations and replaces task-day state while preserving Undo.
  [`ContentView.swift:514`](../../Linkerworks/ContentView.swift#L514)

- Renders accessible muted skips with reversible row swipe actions.
  [`ContentView.swift:419`](../../Linkerworks/ContentView.swift#L419)

- Keeps skipped tasks out of widget completion and neutral-day presentation.
  [`LinkerworksWidget.swift:105`](../../LinkerworksWidget/LinkerworksWidget.swift#L105)

**Regression coverage**

- Covers archive stability, neutral skips, lift metadata, and idempotent backfill.
  [`HistoricalProgressTests.swift:15`](../../LinkerworksTests/HistoricalProgressTests.swift#L15)

- Registers the focused XCTest target and app-hosted test bundle.
  [`project.pbxproj:210`](../../Linkerworks.xcodeproj/project.pbxproj#L210)
