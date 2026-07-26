# Edge Case Hunter Review — Sprint 11 Plan Calendar & Events

Invoke the `bmad-review-edge-case-hunter` skill on the scoped Sprint 11 diff below. Treat all other uncommitted work as pre-existing and out of scope.

## Baseline

`85e3e6af6428116eba791c3e24e253d0a4945868` (initial commit). The repository was already dirty before Sprint 11 began by explicit user approval.

## Scoped diff

- Added `Linkerworks/CalendarPlanView.swift`: Plan calendar UI, month grid, selected day agenda, week/day navigation, event editor, ordering, save/delete error handling, and delete confirmation.
- `Linkerworks/Models.swift`: added an independent `CalendarEvent` SwiftData model with normalized date, optional times, all-day state, notes, timestamps, and sort order.
- `Linkerworks/SharedModelContainer.swift`: added `CalendarEvent.self` to the existing App Group schema.
- `Linkerworks/ContentView.swift`: replaced the private static `PlanView` placeholder with `CalendarPlanView(showingManageRoutine:)`.

## Edge cases to walk

- Month changes across short months, years, and the active locale's first weekday.
- Today/previous/next navigation, date selection, and switching Month/Week/Day modes.
- Multiple all-day/timed events, same start times, no end time, equal times, invalid end-before-start, moving an event to another date, and deletion/save failure rollback.
- Existing shared SwiftData store migration and preservation of the Manage Routine route and unrelated models.

Read the listed current files and report only unhandled edge cases, with the affected path and a concise reason.
