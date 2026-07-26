---
title: 'Date-based daily to-do list'
type: 'feature'
created: '2026-07-26'
status: 'done'
review_loop_iteration: 0
baseline_commit: '582932598c87218d55d76bf0c8a04072aa302db0'
context:
  - '{project-root}/AGENTS.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Linkerworks has recurring routines and school assignments, but no lightweight place for ordinary one-off things that arise during the day or need planning for a future date.

**Approach:** Add an independent, local, date-based to-do list: quickly add and complete items for the active Today date, and manage/edit future-dated items from Plan without making them part of routine progress.

## Boundaries & Constraints

**Always:** Persist to-dos in the existing App Group SwiftData store. A to-do has a non-empty title, a normalized scheduled date, completion state/timestamp, deterministic order, and created/updated timestamps. The Today list follows the selected routine day, including late-night rollover choice. Keep to-dos separate from `TaskItem`, `CompletionRecord`, homework assignments, routine snapshots, streaks, progress rings, and the day-complete moment. Completion, edit, and delete must affect only that to-do and save/rollback through the existing error pattern.

**Ask First:** Reminders/notifications, recurrence, priority/tags, notes, subtasks, widget to-do content, cloud/network synchronization, or any reinterpretation of existing homework/routine records.

**Never:** Reuse `Assignment` for general to-dos; alter routine scheduling/history; add a new top-level tab; add dependencies or external services.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| Quick add today | Non-empty title on Today | A pending to-do is saved for the selected routine day and appears in deterministic order. | Blank/whitespace title remains unsaved with inline validation. |
| Plan future work | User chooses a future date in Plan and saves a title | The to-do is visible in that date’s Plan agenda and in the to-do manager, not Today until that selected day arrives. | Failed save restores the prior state and shows the existing save error. |
| Complete/reopen | Existing date-specific to-do | Check sets `isCompleted` and timestamp; uncheck clears timestamp without changing its date/title/order. | Save failure rolls back the toggle. |
| Day rollover | User continues yesterday after midnight | Today shows yesterday’s to-dos until the user explicitly starts the new routine day. | No civil-date auto-move or duplicate item. |
| Removal | User confirms deletion | Only the selected to-do is permanently removed; routine, homework, and calendar events remain unchanged. | Cancellation changes nothing. |

</frozen-after-approval>

## Code Map

- `Linkerworks/Models.swift` -- SwiftData model and date/order support for standalone to-dos.
- `Linkerworks/SharedModelContainer.swift` -- App Group schema registration.
- `Linkerworks/ContentView.swift` -- selected-day Today section, quick add, completion, and deletion.
- `Linkerworks/DailyTodosView.swift` -- Plan-reachable list/editor for today and future dates.
- `Linkerworks/CalendarPlanView.swift` -- Plan route, month marker, and selected-day agenda projection.
- `LinkerworksTests/DailyTodoTests.swift` -- date, ordering, completion, and routine-isolation regression coverage.

## Tasks & Acceptance

**Execution:**
- [x] `Linkerworks/Models.swift` and `Linkerworks/SharedModelContainer.swift` -- add/register `DailyTodo` plus small deterministic date/order helpers, preserving the shared-store architecture.
- [x] `Linkerworks/ContentView.swift` -- show an independent To-dos section for the selected routine day; provide quick add, inline complete/reopen, edit route, confirmation delete, haptics, and save rollback without touching routine progress.
- [x] `Linkerworks/DailyTodosView.swift` -- build a Paper & Ink manager and editor for dated to-dos, prefillable from Plan, with date-aware active/done organization and safe editing/deletion.
- [x] `Linkerworks/CalendarPlanView.swift` -- add the Plan navigation route, a visually distinct date marker, and selected-date to-do agenda rows without changing event/homework semantics.
- [x] `LinkerworksTests/DailyTodoTests.swift` -- cover normalized dates, deterministic ordering, completion timestamp transitions, future-date visibility, and routine progress isolation.
- [x] `STATE.md` -- append an accurate feature handoff and validation/runtime note.

**Acceptance Criteria:**
- Given a non-empty quick-add title, when it is saved from Today, then the item belongs to the selected routine day and does not change checklist progress.
- Given the user keeps yesterday after midnight, when Today renders to-dos or completes one, then it uses yesterday until the explicit rollover action.
- Given a future-dated to-do, when its date is selected in Plan, then it has a visible date marker and agenda row and remains absent from Today before that date.
- Given a to-do is completed, reopened, edited, or deleted, when it saves, then only that item’s state changes and no homework, calendar event, or completion record changes.
- Given a to-do date has only a time component difference, when stored or filtered, then it resolves to exactly one calendar day.

## Design Notes

To-dos are deliberately one-off commitments, not a second routine engine. Plan owns future planning; Today owns immediate capture. A small independent model avoids course/due-time terminology and protects the routine-history guarantees.

## Verification

**Commands:**
- `swiftc -parse Linkerworks/*.swift LinkerworksWidget/*.swift LinkerworksTests/*.swift` -- expected: all modified app, widget, and test sources parse.
- `git diff --check` -- expected: no whitespace errors.

**Manual checks (if no CLI):**
- In Xcode, add, complete, reopen, edit, and delete Today to-dos; hold yesterday after midnight and verify its to-dos stay visible.
- Create a future to-do from Plan and verify its marker/agenda placement, then advance/select that date and check Today isolation.

## Suggested Review Order

**Date-based persistence**

- One-off model preserves a stable calendar-day key and never touches routine history.
  [`Models.swift:172`](../../Linkerworks/Models.swift#L172)

- Shared helper normalizes, keys, filters, and deterministically orders to-dos.
  [`Models.swift:208`](../../Linkerworks/Models.swift#L208)

**Today capture**

- Today provides quick capture and isolated inline completion/edit/delete actions.
  [`ContentView.swift:561`](../../Linkerworks/ContentView.swift#L561)

- Quick-add writes against the selected routine day rather than the civil date.
  [`ContentView.swift:1046`](../../Linkerworks/ContentView.swift#L1046)

**Future planning**

- Plan groups to-dos once by day key before rendering month markers and agenda rows.
  [`CalendarPlanView.swift:23`](../../Linkerworks/CalendarPlanView.swift#L23)

- Dedicated manager handles dated editing, completion, and deletion without homework semantics.
  [`DailyTodosView.swift:8`](../../Linkerworks/DailyTodosView.swift#L8)

- Editor preserves date normalization and resets ordering only when moving days.
  [`DailyTodosView.swift:162`](../../Linkerworks/DailyTodosView.swift#L162)

**Regression coverage**

- Tests cover timezone-stable day keys and held-routine-day visibility after midnight.
  [`DailyTodoTests.swift:82`](../../LinkerworksTests/DailyTodoTests.swift#L82)
