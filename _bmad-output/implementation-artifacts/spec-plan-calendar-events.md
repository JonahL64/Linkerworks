---
title: 'Sprint 11 Plan calendar and events'
type: 'feature'
created: '2026-07-24'
status: 'in-progress'
review_loop_iteration: 0
baseline_commit: '85e3e6af6428116eba791c3e24e253d0a4945868'
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/STATE.md'
  - '{project-root}/CALENDAR_SPRINT_PLAN.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Plan is a static, current-month placeholder, so the user cannot organize personal events or inspect a chosen day or week.

**Approach:** Replace that placeholder with a local calendar backed by additive App Group SwiftData events. The Plan tab provides a navigable month grid, selected-day agenda, and Month/Week/Day contexts, plus complete event creation, editing, and deletion.

## Boundaries & Constraints

**Always:** Preserve all existing routine, completion, nutrition, workout, tracker, navigation, seed-import, widget, and App Group behavior. Add a standalone `CalendarEvent` with a stable ID, normalized event date, optional start/end times, all-day flag, notes, creation/update timestamps, and sort order. Use `Calendar.current` and the existing dark palette; times are monospaced and normal events never use the completion-green accent. Plan retains its Manage Routine route. Events persist offline in the existing shared store and display all-day events before timed events, then by start time and deterministic tie-breaker.

**Ask First:** Changing the App Group identifier/store location, seed data/importer, widget behavior, tab structure, existing routine/task behavior, or broad file/folder organization.

**Never:** Add recurrence, routine-to-calendar projection, notifications/reminders, EventKit or external calendar sync/import/export, invitations, locations, attachments, cloud sync, widget calendar content, third-party packages, or changes to existing historical records.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Create and persist | A title and selected date; all-day or valid timed values | A durable event appears in its month marker and selected day/week agendas after relaunch | Blank title cannot save; a storage failure leaves the editor open with an explanation |
| View context | A date is tapped, or Month/Week/Day is selected | Plan changes to the tapped day; week is anchored to that day’s calendar week and day shows that day’s agenda | An empty date/context states that no events are scheduled |
| Timed ordering | Several all-day and timed events share a date | All-day entries appear first; timed entries sort by start time, then order/creation tie-breaker | Point-in-time equal start/end is valid |
| Edit or delete | Existing event is opened | Valid edits update its date/details and all contexts; confirmed delete removes only that event | End earlier than start is rejected inline; delete requires confirmation |

</frozen-after-approval>

## Code Map

- `Linkerworks/Models.swift` -- shared SwiftData models; add the independent calendar event entity.
- `Linkerworks/SharedModelContainer.swift` -- explicit App Group schema; register the additive entity.
- `Linkerworks/CalendarPlanView.swift` -- new Plan month grid, week/day agendas, event editor, ordering, validation, persistence, and delete confirmation.
- `Linkerworks/ContentView.swift` -- replace its private placeholder Plan implementation with the calendar view while preserving the Manage Routine sheet route.
- `STATE.md` -- factual Sprint 11 handoff, changed paths, validation, and runtime gap.

## Tasks & Acceptance

**Execution:**

- [x] `Linkerworks/Models.swift` -- define additive `CalendarEvent` persistence fields and a single initializer that normalizes dates -- preserve all existing data models.
- [x] `Linkerworks/SharedModelContainer.swift` -- register `CalendarEvent` in the existing shared schema without changing its container configuration.
- [x] `Linkerworks/CalendarPlanView.swift` -- implement date helpers, navigable month grid with selected-day marker/agenda, Month/Week/Day switcher, event editor, save/error handling, deterministic ordering, and destructive-delete confirmation.
- [x] `Linkerworks/ContentView.swift` -- make Plan host `CalendarPlanView`, passing through the existing Manage Routine binding unchanged.
- [x] `STATE.md` -- append the Sprint 11 implementation handoff and any unavailable runtime verification.

**Acceptance Criteria:**

- Given a user saves an all-day or valid timed event, when Plan is reopened after relaunch, then the event persists and is visible in the matching month, week, and day contexts.
- Given a user navigates months, taps a day, or selects Today, when the navigation completes, then the visible month and active day correspond to the selected calendar date without altering events.
- Given events share a day, when its agenda is shown, then all-day items precede timed items and timed items use start time then deterministic tie-breakers.
- Given a user supplies an end time before its start time, when Save is pressed, then the event is not written and the editor identifies the invalid range; equal times save as a point-in-time event.
- Given a user edits or confirms deletion of an event, when Plan refreshes, then only that event reflects the change and Manage Routine remains available from Plan.

## Design Notes

Keep calendar events intentionally detached from scheduled `TaskItem`s: Plan is an event organizer, not a second completion system. Store an all-day event’s date separately from its optional time-of-day values so date comparison remains local-calendar-safe. The month grid only signals that events exist; event titles belong in agendas to avoid dense card styling.

## Verification

**Commands:**

- `swiftc -parse Linkerworks/*.swift` -- expected: all app sources parse.
- `git diff --check` -- expected: no whitespace errors.

**Manual checks (if Xcode is available):**

- Open a pre-calendar shared store; create all-day, timed, equal-time, and same-day events; relaunch; navigate months; tap dates; verify Week/Day ordering; edit/delete; reject an end-before-start range; and confirm existing routine/nutrition/workout data is intact.
