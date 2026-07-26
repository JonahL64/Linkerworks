---
title: 'Daily routine rollover, goalkeeping choice, and widget visual alignment'
type: 'feature'
created: '2026-07-26'
status: 'done'
review_loop_iteration: 0
baseline_commit: '612c9fa43fd34b103308163c3f8af42f88d825c0'
context:
  - '{project-root}/AGENTS.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The widget still looks like the pre-redesign app, goalkeeping is fixed to its repeating schedule, and Today switches to the calendar date at midnight even when the user is finishing yesterday's routine after midnight.

**Approach:** Give Today one explicitly selected routine day, confirm before advancing it at a calendar-day boundary, let the user mark scheduled goalkeeping as a rest day for that selected date, and have the widget project the same day with the Paper & Ink visual language.

## Boundaries & Constraints

**Always:** Preserve every historical completion, skip, DaySnapshot, and recurring task assignment. Keep the shared App Group store and the existing widget deep link/AppIntent completion behavior. Use App Group defaults for the selected routine day so app and widget agree. Treat a goalkeeping rest day as skipped work for that date, not as a recurring-task edit; it must be reversible. Keep widget colors duplicated in both asset catalogues and respect light/dark appearance.

**Ask First:** Any new persisted SwiftData model or migration, changes to the data-retention/backup behavior, a new widget family, or a change to task history semantics beyond date-specific skipped records.

**Never:** Delete or rewrite CompletionRecords or DaySnapshots; alter `TaskItem.daysOfWeek` to express a one-day choice; add notifications, network/cloud sync, third-party packages, or unrelated Today/Plan/Log features.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| First opening Today | No saved routine-day selection | Today and widget use the calendar date; no confirmation is shown. | Fall back to calendar date if shared defaults are unavailable. |
| After midnight | Saved routine day is yesterday; current calendar day is newer | Show “Are you on the next day?” with a choice to keep the prior routine day or start the current calendar day. Keep means all Today completion writes remain dated yesterday; start means the selected day advances and widget reloads. | If a save fails, retain the prior selected day and show the existing save error. |
| Deferred rollover | User keeps the prior day at 3 AM | Do not re-prompt for that same calendar date; offer a clear route to start the calendar day later. | Calendar changes again before selection: prompt against the current calendar day, never silently advance. |
| Goalkeeping rest day | Selected date has scheduled goalkeeping tasks; user chooses Rest day | Batch-write skipped records for those scheduled goalkeeping completion units, remove them from progress/streak denominator, hide the routine rows, and show a reversible rest-day state. | Do not affect non-goalkeeping records or recurring scheduling. |
| Resume goalkeeping | User changes Rest day back to Goalkeeping today | Remove only the date's goalkeeping skip state and restore those tasks as pending; existing valid completions remain intact. | Save failure leaves the prior choice visible and reports the error. |
| Widget projection | Selected day is not calendar date | Routine widget reads that selected day for its next task/progress and its AppIntent writes to it; assignment widget continues to use its nearest real due assignment. | Unavailable shared data keeps the current open-app fallback. |

</frozen-after-approval>

## Code Map

- `Linkerworks/Domain.swift` -- shared routine completion and date/domain helpers compiled by both app and widget.
- `Linkerworks/ContentView.swift` -- Today date, progress, goalkeeping control, rollover confirmation, and completion mutation calls.
- `LinkerworksWidget/LinkerworksWidget.swift` -- all widget timeline projection and routine/assignment widget layouts.
- `Linkerworks/Assets.xcassets/` and `LinkerworksWidget/Assets.xcassets/` -- duplicated adaptive Paper & Ink color assets.
- `LinkerworksTests/HistoricalProgressTests.swift` and `LinkerworksTests/WidgetProjectionTests.swift` -- focused date-selection, skip semantics, and widget parity tests.

## Tasks & Acceptance

**Execution:**
- [x] `Linkerworks/Domain.swift` -- add a testable App Group-backed routine-day selection helper and focused goalkeeping batch-state helpers; reuse `RoutineCompletionCommand` so snapshot capture, save, and widget reload rules remain centralized.
- [x] `Linkerworks/ContentView.swift` -- render Today from the selected routine day, present/suppress the rollover confirmation correctly, expose a deliberate later advance action, and add a reversible Goalkeeping today/Rest day control without changing task recurrence.
- [x] `LinkerworksWidget/LinkerworksWidget.swift` -- project the shared selected day for routine entries and intents; restyle small, medium, and lock-screen routine views plus the assignment widget with private Paper & Ink type/spacing/surface equivalents while retaining their supported families and actions.
- [x] `Linkerworks/Assets.xcassets/` and `LinkerworksWidget/Assets.xcassets/` -- add matching raised, sunken, and hairline adaptive colors required by the widget's Paper & Ink hierarchy.
- [x] `LinkerworksTests/HistoricalProgressTests.swift` and `LinkerworksTests/WidgetProjectionTests.swift` -- cover selected-day defer/advance persistence, date-correct completion writes, all-goalkeeping skip exclusion, and routine-widget selected-day projection.
- [x] `STATE.md` -- append a concise implementation handoff, file map, validation result, and any runtime limitation.

**Acceptance Criteria:**
- Given the calendar crosses midnight, when the user has not selected the new day, then Today never silently changes the completion date and asks whether they are on the next day.
- Given a user continues yesterday after midnight, when they complete, skip, or undo a task, then records and progress remain assigned to yesterday until they explicitly start the new day.
- Given scheduled goalkeeping is set to Rest day, when progress and streak summaries are calculated, then only those goalkeeping completion units are excluded and all unrelated routine work is unchanged.
- Given the user selects Goalkeeping today again, when the choice saves, then goalkeeping rows return as pending without modifying the recurring routine or unrelated historical records.
- Given the selected routine day differs from the calendar day, when the routine widget refreshes or completes a task, then it displays and writes against the same selected day as Today.
- Given either appearance, when routine and assignment widgets render, then their surfaces, ink-blue interaction color, completion-only green, serif metrics, sentence-case labels, and restrained raised grouping match the Paper & Ink app language.

## Design Notes

The selected routine day is a temporary daily-work context, not a redefinition of calendar history: the date is explicit in every completion record and can be held through late-night work. A goalkeeping rest day uses the existing `skipped` semantic because it already removes date-specific work from progress without corrupting the immutable captured schedule.

For the widget, duplicate only the portable visual primitives it needs (asset-backed colors, token-like spacing/type constants, raised/sunken grouping). Do not link app Theme sources into the extension or substitute success green for the interactive ink-blue accent.

## Verification

**Commands:**
- `swiftc -parse Linkerworks/*.swift LinkerworksWidget/*.swift LinkerworksTests/*.swift` -- expected: all modified Swift sources parse.
- `git diff --check` -- expected: no whitespace errors.

**Manual checks (if no CLI):**
- In Xcode on a device or Simulator, hold yesterday at 3 AM, complete and undo a task, then advance to today; inspect the Today and widget dates/progress in both appearances.
- Toggle a scheduled goalkeeping day to Rest day and back; verify only its work is excluded/restored and Progress history remains coherent.
- Add each widget family and confirm Paper & Ink hierarchy and touch targets remain readable.

## Suggested Review Order

**Routine-day ownership**

- Shared App Group selection makes late-night work explicit across app and widget.
  [`Domain.swift:18`](../../Linkerworks/Domain.swift#L18)

- Today holds or advances the day only after a safe snapshot capture.
  [`ContentView.swift:238`](../../Linkerworks/ContentView.swift#L238)

- Rollover actions preserve the prior selection when persistence fails.
  [`ContentView.swift:1042`](../../Linkerworks/ContentView.swift#L1042)

**Goalkeeping rest semantics**

- Rest-day records are owned and reversibly ignored without deleting history.
  [`Domain.swift:201`](../../Linkerworks/Domain.swift#L201)

- Today exposes the reversible choice inside its primary routine summary.
  [`ContentView.swift:363`](../../Linkerworks/ContentView.swift#L363)

**Widget parity and visual language**

- Routine entries carry their selected date through timeline projection.
  [`LinkerworksWidget.swift:44`](../../LinkerworksWidget/LinkerworksWidget.swift#L44)

- Medium widget keeps one 44-point direct action in Paper & Ink hierarchy.
  [`LinkerworksWidget.swift:143`](../../LinkerworksWidget/LinkerworksWidget.swift#L143)

- Intents reject stale widget entries rather than writing to a different day.
  [`AppIntent.swift:5`](../../LinkerworksWidget/AppIntent.swift#L5)

**Regression coverage**

- Tests cover rollover suppression and non-destructive rest-day restoration.
  [`HistoricalProgressTests.swift:189`](../../LinkerworksTests/HistoricalProgressTests.swift#L189)

- Tests verify selected-day completion uses the held routine date.
  [`WidgetProjectionTests.swift:29`](../../LinkerworksTests/WidgetProjectionTests.swift#L29)
