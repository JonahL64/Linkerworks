---
title: 'Full usability simplification'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
baseline_commit: '85e3e6af6428116eba791c3e24e253d0a4945868'
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-Linkerworks-2026-07-24/EXPERIENCE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-Linkerworks-2026-07-24/DESIGN.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Common repeat actions require full forms, duplicate choices, or navigation through overlapping destinations. Routine scheduling also allows an ambiguous section/day combination, and lifting has two competing completion controls.

**Approach:** Add direct, safe fast paths for repeat meal and set logging; make detailed fields progressive; remove redundant surfaces and modes; and make routine schedule/completion semantics match what is shown. Preserve all persisted records and retain full editors for exceptions.

## Boundaries & Constraints

**Always:** Preserve the App Group SwiftData schema and all existing MealEntry, SavedMeal, Workout, CalendarEvent, TaskItem, and CompletionRecord history. A quick action always creates an independent record. Completed workouts stay immutable. Use native SwiftUI interactions and the established dark training-log theme. Retain access to all reference data.

**Ask First:** Any migration, deletion of persisted user data, new third-party dependency, networking, notifications, HealthKit, routine builder, or change to widget behavior.

**Never:** Add food lookup/scanning, template/routine-builder systems, cloud/account features, or new top-level destinations. Do not make a calendar, log, or completion action depend on a swipe-only gesture.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| Quick-log meal | Saved meal is tapped on an arbitrary selected date | A new independent entry copies its values/category, receives the next category order, and updates totals without an editor | Keep the entry unchanged and show existing save error on failure |
| Save favorite | A recorded meal is saved as a favorite | A matching preset is created once; future entry edits/deletes do not alter it | Exact duplicate is a no-op |
| Fast set | An in-progress exercise has a prior set | Add Set creates the next completed set with copied reps/load and timestamp | Keep the prior set untouched on save failure |
| First workout | User starts then cancels before naming first exercise | No in-progress workout is persisted | Existing active workout remains resumable |
| Lift completion | Parent has children; at least one child is completed today | Parent/progress completion derives from all active children | A legacy parent record counts only until child-based logging begins |
| Event timing | Timed event omits its end time | Save a start-only event with no end time | Reject end earlier than start |

</frozen-after-approval>

## Code Map

- `Linkerworks/NutritionView.swift` -- nutrition summary, entry editor, presets, and persistence calls.
- `Linkerworks/WorkoutView.swift` -- workout/session/exercise/set creation and editing.
- `Linkerworks/ManageView.swift` -- routine task editor and lifting substeps.
- `Linkerworks/ContentView.swift` -- tab shell and Today completion rendering.
- `Linkerworks/CalendarPlanView.swift` -- Plan modes and event editor.
- `Linkerworks/TrackersView.swift` -- Log routes and domain reference/history views.
- `Linkerworks/StreaksView.swift` -- progress computation and presentation.
- `Linkerworks/Domain.swift` or a focused shared helper -- inferred task domain and shared effective completion rule.

## Tasks & Acceptance

**Execution:**
- [x] `NutritionView.swift` -- replace preset picker/save toggle with visible Saved Meals quick-log rows and a post-save Favorite action; make custom meal form show name/calories first and reveal date/category/macros only when needed.
- [x] `WorkoutView.swift` -- create a session atomically with its named first exercise; cancel creates nothing; add a subsequent set as a completed copy of the prior set while retaining first-set and edit forms.
- [x] `ManageView.swift` and shared domain helper -- make section day authoritative, retain optional extra days in a disclosure, collapse domain/time/detail and substep details, and never mutate completion history.
- [x] `ContentView.swift` and shared completion helper -- make parents with substeps display-only and child-derived, include a legacy-record compatibility fallback, and use the same effective rule for Today progress, final completion, and streaks.
- [x] `CalendarPlanView.swift` -- keep month plus selected-day agenda; remove duplicated Week/Day modes; make event timing and notes progressive without changing stored event semantics.
- [x] `TrackersView.swift`, `NutritionView.swift`, and `WorkoutView.swift` -- remove duplicate Eating/Lifting Log routes, provide their reference access from Nutrition/Workout, and keep the remaining domains as routine history/reference routes.
- [x] `ContentView.swift` and `StreaksView.swift` -- remove the empty More tab; retain streaks and heatmap while replacing the month-long weekly list with one concise current-week summary.
- [x] `STATE.md` -- append the delivered behavior, files, validation, and any runtime gap.

**Acceptance Criteria:**
- Given saved meals or a prior workout set, when the direct action is used, then the result is recorded in one action and remains independently editable.
- Given a new routine task, when its section changes, then its primary scheduled day follows that section and details do not obstruct basic creation.
- Given lifting substeps, when they are completed, then Today and Progress agree on the parent’s completion without requiring a parent tap.
- Given a selected calendar date, when the user plans an event, then title/date are direct and time, end time, and notes appear only on request.
- Given the Log root, when the user needs Nutrition or Workout reference material, then it is reachable within that destination and no duplicate Eating/Lifting route is shown.
- Given launch navigation, when the user views the tab bar, then it contains only Today, Plan, Log, and Progress.

## Design Notes

The fast lane is intentional: direct actions copy values into new immutable historical records. Detailed editors remain available by tapping the resulting row. For legacy lift records, a parent record counts only before any child has a same-day record; this preserves old history while making new substep completion deterministic.

## Verification

**Commands:**
- `swiftc -parse Linkerworks/*.swift` -- expected: all app sources parse.
- `git diff --check` -- expected: no whitespace errors.

**Manual checks (if no CLI):**
- In Xcode/device or Simulator, verify quick logging, first-workout cancellation, copied sets, task-day editing, legacy and new lift completion, reference navigation, calendar event variants, and persistence across relaunch.

## Suggested Review Order

**Daily routine consistency**

- The four-tab shell removes an empty destination while preserving the Today deep link.
  [`ContentView.swift:4`](../../Linkerworks/ContentView.swift#L4)

- Today now includes every task scheduled for the selected weekday, including optional extra days.
  [`ContentView.swift:83`](../../Linkerworks/ContentView.swift#L83)

- Parent lift completion is shared by Today, Progress, and the widget with legacy compatibility.
  [`Domain.swift:37`](../../Linkerworks/Domain.swift#L37)

- Task editing makes the section day primary and guards invalid substep/domain combinations.
  [`ManageView.swift:198`](../../Linkerworks/ManageView.swift#L198)

**Fast logging**

- Saved meals become one-tap logs, while favorites remain explicit and deduplicated.
  [`NutritionView.swift:113`](../../Linkerworks/NutritionView.swift#L113)

- A workout starts only after its first exercise is named; repeat sets copy the previous set.
  [`WorkoutView.swift:183`](../../Linkerworks/WorkoutView.swift#L183)

**Focused planning and progress**

- Plan is reduced to a month and selected-day agenda with locale-correct weekday headings.
  [`CalendarPlanView.swift:4`](../../Linkerworks/CalendarPlanView.swift#L4)

- Event details reveal timing and notes only when needed.
  [`CalendarPlanView.swift:362`](../../Linkerworks/CalendarPlanView.swift#L362)

- Log keeps action destinations distinct and removes duplicate Eating/Lifting entries.
  [`TrackersView.swift:5`](../../Linkerworks/TrackersView.swift#L5)

- Progress keeps the heatmap and adds one concise current-week rollup.
  [`StreaksView.swift:7`](../../Linkerworks/StreaksView.swift#L7)

**Widget alignment and verification**

- Widget progress now follows the same child-derived completion semantics as the app.
  [`LinkerworksWidget.swift:115`](../../LinkerworksWidget/LinkerworksWidget.swift#L115)

- Deferred historical and failure-path work is recorded separately from this usability sprint.
  [`deferred-work.md:1`](deferred-work.md#L1)
