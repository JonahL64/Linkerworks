# Blind Hunter Review — Sprint 11 Plan Calendar & Events

Invoke the `bmad-review-adversarial-general` skill on the scoped Sprint 11 diff below. Treat all other uncommitted work as pre-existing and out of scope.

## Baseline

`85e3e6af6428116eba791c3e24e253d0a4945868` (initial commit). The repository was already dirty before Sprint 11 began by explicit user approval.

## Scoped diff

- Added `Linkerworks/CalendarPlanView.swift`: Plan calendar UI, month grid, selected day agenda, week/day navigation, event editor, ordering, save/delete error handling, and delete confirmation.
- `Linkerworks/Models.swift`: added an independent `CalendarEvent` SwiftData model with normalized date, optional times, all-day state, notes, timestamps, and sort order.
- `Linkerworks/SharedModelContainer.swift`: added `CalendarEvent.self` to the existing App Group schema.
- `Linkerworks/ContentView.swift`: replaced the private static `PlanView` placeholder with `CalendarPlanView(showingManageRoutine:)`.

## Requirements

- Events persist offline and are independent from tasks, completions, meals, and workouts.
- Month view is navigable, marks event days, and selecting a date changes its agenda.
- Week and day views are selectable and navigable; all-day events appear first, then timed events by time and deterministic tie-breakers.
- Event creation/editing/deletion supports title, date, all-day or time range, and notes. Blank titles and end-before-start must fail; equal times are valid. Deletion needs confirmation.
- Preserve the Manage Routine sheet and every existing app/widget behavior. No recurrence, notifications, EventKit, sync, cloud, or widget calendar.

Read the listed current files and report only real findings, with the affected path and a concise reason.
