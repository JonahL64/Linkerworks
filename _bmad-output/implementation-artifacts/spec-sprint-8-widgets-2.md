---
title: 'Sprint 8 Widgets 2.0'
type: 'feature'
created: '2026-07-25'
status: 'done'
review_loop_iteration: 0
baseline_commit: 'a9988f011ec87a3489338182cec4ee6fb485215d'
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/STATE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The widget's next-task order hides overdue routine work behind future timed work, cannot complete work in place, and lacks the requested richer home-screen, assignment, and lock-screen summaries. Widget content can also remain stale after routine/assignment edits.

**Approach:** Make widget data a faithful shared-store projection of Today and Homework, route interactive completion through the same reusable routine-completion mutation as the app, and add the requested widget families while preserving existing fallback, refresh, completion, and deep-link behavior.

## Boundaries & Constraints

**Always:** Keep App Group SwiftData as the sole cross-process store; support iOS 17+ interactive widgets (project targets iOS 26.5); preserve parent/child completion and skip rules; create archive-safe `CompletionRecord` values exactly as Today does; reload the existing widget kind after every successful relevant routine or assignment write; retain hourly-or-midnight refresh, Day complete, unavailable, and Today deep link states.

**Ask First:** Any schema migration, App Group/entitlement change, project restructuring, file rename, or additional widget beyond the listed families.

**Never:** Add networking, notifications, third-party dependencies, cloud sync, a separate completion data path, or changes to unrelated tabs/features.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| Overdue sort | Incomplete timed task is past now; another is future; untimed task exists | List orders past timed ascending, then future timed ascending, then untimed by routine order | Invalid/missing time is untimed |
| Widget completion | Incomplete ordinary task or lift parent with active children | Intent writes the same dated complete records and child-derived parent state as Today | Failed shared-store save returns intent failure and leaves data unchanged |
| Completed/neutral/unavailable | No incomplete tasks; all skipped; or shared store unreadable | Preserve Day complete, neutral, or unavailable presentation respectively | Tap still opens Today where applicable |
| Assignment widget | Unfinished assignment with/without course, standard/sentinel due date | Show nearest valid due assignment title, course color treatment, and due time | No valid assignment shows an explicit empty state |

</frozen-after-approval>

## Code Map

- `Linkerworks/ContentView.swift` — existing Today task mutation, undo, and routine UI.
- `Linkerworks/Domain.swift` — shared completion/parent-child and historical progress semantics.
- `Linkerworks/HomeworkView.swift` — assignment writes and ordering helpers.
- `LinkerworksWidget/LinkerworksWidget.swift` — App Group timeline reads, existing widgets, deep link, and refresh policy.
- `LinkerworksWidget/AppIntent.swift` and `LinkerworksWidget/LinkerworksWidgetControl.swift` — existing generated intent/control templates to replace or reuse.
- `LinkerworksTests/` — current XCTest target, including the Sprint 0 characterization coverage to update.

## Tasks & Acceptance

**Execution:**
- [x] Extract a shared, App Group-safe routine completion command used by both Today and a new widget `AppIntent`; preserve date normalization, snapshot capture, child batches, state replacement, error rollback, and widget reload.
- [x] Replace the template intent/control implementation with the task-completion intent and use `Button(intent:)` in the home-screen routine widget for incomplete tasks.
- [x] Centralize widget projection/sort support: classify incomplete timed tasks as overdue or upcoming at entry time, then untimed by section/task routine order; expose progress, top three incomplete tasks, and next valid assignment with course metadata.
- [x] Extend `LinkerworksWidget.swift` with a medium routine widget (ring plus next three), a next-assignment-due widget, and lock-screen rectangular `completed/total · Next: title` content; retain existing small/circular behavior and all fallback states.
- [x] Make successful routine-management and assignment create/edit/complete/postpone/delete/bulk writes reload widget timelines; do not reload on failed saves.
- [x] Update the existing next-task characterization test and add focused tests for sort categories, widget-intent record parity/parent-child handling, and assignment selection/course fallback.

**Acceptance Criteria:**
- Given a past 08:00 task, a future 18:00 task, and an untimed task at 12:00, when widget data is loaded, then their incomplete display order is 08:00, 18:00, then the untimed task in section and task routine order.
- Given a widget completion action for a lift parent, when its active children require completion, then the persisted `CompletionRecord` set and effective parent completion match an equivalent Today action.
- Given medium, assignment, and accessory-rectangular families, when data is available, then they show the specified progress/tasks, assignment metadata, and `14/22 · Next: Mobility`-style summary respectively.
- Given every successful routine or assignment write, when it saves, then the widget kind's timeline is reloaded; failed writes do not report success.

## Design Notes

The shared completion command must be framework-neutral: Today can layer haptics, section collapse, undo, and animation after it succeeds, while the intent only needs persistent-equivalent records and a reload. The task ID is the intent input; the intent re-fetches the task from the shared store and derives child IDs there, avoiding stale serialized child state.

## Verification

**Commands:**
- `swiftc -parse Linkerworks/*.swift LinkerworksWidget/*.swift LinkerworksTests/*.swift` — no syntax errors when Swift tooling is available.
- `git diff --check` — no whitespace errors.

**Manual checks (if no CLI):**
- In Xcode on an iOS 17+ device, add each widget family; complete a normal task and lift parent from Home Screen; compare resulting records/Today state, test overdue ordering, assignment updates, deep links, Day complete, unavailable storage, hourly refresh, and midnight rollover.

## Suggested Review Order

**Shared completion boundary**

- One shared write command keeps Today and widget completion records identical.
  [`Domain.swift:51`](../../Linkerworks/Domain.swift#L51)

- The AppIntent opens the shared App Group store and invokes that command.
  [`AppIntent.swift:5`](../../LinkerworksWidget/AppIntent.swift#L5)

- Today now delegates persistence while retaining its UI-only haptics, animation, and undo behavior.
  [`ContentView.swift:763`](../../Linkerworks/ContentView.swift#L763)

**Widget projections and surfaces**

- Provider projects ordered routine tasks, progress, and the nearest valid assignment from shared storage.
  [`LinkerworksWidget.swift:41`](../../LinkerworksWidget/LinkerworksWidget.swift#L41)

- Medium uses interactive task buttons; rectangular expresses progress plus next action.
  [`LinkerworksWidget.swift:82`](../../LinkerworksWidget/LinkerworksWidget.swift#L82)

- Assignment due widget adds title, course color indicator, and due time as its own family.
  [`LinkerworksWidget.swift:90`](../../LinkerworksWidget/LinkerworksWidget.swift#L90)

**Freshness and coverage**

- Routine management saves refresh both routine and assignment widget timelines after success.
  [`ManageView.swift:161`](../../Linkerworks/ManageView.swift#L161)

- Assignment and course persistence refreshes widget timelines only after a successful save.
  [`HomeworkView.swift:327`](../../Linkerworks/HomeworkView.swift#L327)

- Characterization covers sort order, due-assignment filtering, and lift-parent completion records.
  [`WidgetProjectionTests.swift:7`](../../LinkerworksTests/WidgetProjectionTests.swift#L7)
