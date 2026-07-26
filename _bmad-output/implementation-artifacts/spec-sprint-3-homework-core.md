---
title: 'Sprint 3 Homework core'
type: 'feature'
created: '2026-07-25'
status: 'in-review'
review_loop_iteration: 0
baseline_commit: 'NO_VCS'
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/STATE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-Linkerworks-2026-07-24/DESIGN.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Homework currently lives in a spreadsheet, requiring manual tracking of due date/time, course, and completion. Linkerworks needs a quick local assignment workflow that preserves the app’s focused Plan experience.

**Approach:** Add SwiftData `Course` and `Assignment` records to the shared App Group store, with a Plan-toolbar Homework route for course management and a grouped, filterable assignment list with fast progressive entry.

## Boundaries & Constraints

**Always:** Persist the supplied model fields and Course-to-Assignment nullifying relationship; use only the fixed course palette as a 3pt leading rule or small dot, never a filled row; reserve `#3ECF6E` solely for completion; default a new due time to 11:59 PM and retain whether it was default; save must be available with Details closed; archive courses without deleting their assignments; use haptics and animation for direct completion; deterministic assignment ordering is due date, course sort order, creation time, then UUID.

**Ask First:** Any change to the tab structure, Today/progress/streak/heatmap behavior, App Group identifier/store location, or existing calendar/routine/nutrition/workout flows.

**Never:** Add calendar integration, Today surfacing, recurrence, bulk actions, accounts/networking/cloud sync/notifications, third-party dependencies, or a completion confirmation dialog.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| Fast entry | New assignment with title/course/date | Due time is 11:59 PM, `usesDefaultTime` is true, and Save works without Details | Blank title remains unsaved with a clear validation message |
| Explicit time | User opens Details and selects a time | Due date stores that day/time and `usesDefaultTime` becomes false | Preserve date/time on edit round-trip |
| Date grouping | Due dates span immediately before/after midnight | Item is bucketed as Overdue, Today, Tomorrow, This week, Later, or No due date from the current calendar day | Recalculate buckets when the calendar day changes |
| Completion | User taps an incomplete checkbox | Assignment saves completed timestamp, haptic fires, and row animates to Done | Save failure leaves visible state recoverable and reports it |
| Course archive | Course with assignments is archived | Course disappears from active selection; existing assignments remain readable with their course relationship | Never cascade/delete assignments |

</frozen-after-approval>

## Code Map

- `Linkerworks/Models.swift` — existing SwiftData model definitions; add Course and Assignment.
- `Linkerworks/SharedModelContainer.swift` — fixed App Group SwiftData schema registration.
- `Linkerworks/CalendarPlanView.swift` — current Plan toolbar and sheet route for calendar/routine; add Homework entry point without changing calendar behavior.
- `Linkerworks/HomeworkView.swift` — new assignment list, course management, editors, grouping/sort helpers, filters, and swipe/completion interactions.
- `LinkerworksTests/HistoricalProgressTests.swift` — current XCTest target pattern; retain untouched.
- `LinkerworksTests/HomeworkCoreTests.swift` — focused pure grouping, default-time, and deterministic-sort coverage.
- `STATE.md` — append Sprint 3 handoff after implementation.

## Tasks & Acceptance

**Execution:**

- [x] `Linkerworks/Models.swift` and `Linkerworks/SharedModelContainer.swift` — add the specified `Course`/`Assignment` SwiftData types, initializers, inverse/nullify relationship, and schema registration for lightweight migration in the existing App Group store.
- [x] `Linkerworks/HomeworkView.swift` — implement a Plan-reachable Homework stack: active/archived course management (add, rename, fixed color picker, drag reorder, archive); horizontal course filter chips with long-press solo; grouped list in required order; deterministic sorting; last-14-days collapsed Done; direct haptic completion; edit sheet; +1-day leading swipe; confirmation-backed destructive trailing swipe.
- [x] `Linkerworks/HomeworkView.swift` — implement the assignment sheet with visible Title, Course, and Due date; Details-only time/notes; default-time indicator/rendering; validation and save/error handling consistent with existing native sheets.
- [x] `Linkerworks/CalendarPlanView.swift` — expose Homework from the Plan toolbar while preserving its existing calendar add-event and Manage Routine behavior.
- [x] `LinkerworksTests/HomeworkCoreTests.swift` — test bucket classification across a midnight boundary, default 11:59 PM serialization/edit round-trip, and stable full tie-break ordering.
- [x] `STATE.md` — append a concise Sprint 3 implementation handoff, key paths, validation, and remaining device checks.

**Acceptance Criteria:**

- Given ten new assignments, when entering title, course, and due date only, then each can be saved without revealing Details or dismissing the keyboard and the flow supports completion in under three minutes.
- Given open assignments with overdue, today, tomorrow, week, future, and missing due dates, when Homework loads, then groups appear exactly in the required order and rows sort deterministically within each group.
- Given a default-time assignment, when it is saved, listed, and edited, then it remains 11:59 PM with muted time treatment until the user explicitly changes its time.
- Given a completed assignment within 14 days, when its checkbox is tapped, then it moves into the collapsed Done group without confirmation; assignments completed earlier are excluded.
- Given an archived course, when Homework lists assignments, then its assignments persist and no assignment is added to Today, its progress ring, streaks, or heatmap.

## Design Notes

Homework uses the existing dark, flat list rhythm. A course marker is identity only: a 3pt leading vertical rule (or compact dot in filter chips), never a tint or card. Completion is the only green state; default 11:59 PM is subdued monospaced metadata.

## Verification

**Commands:**

- `swiftc -parse Linkerworks/*.swift LinkerworksTests/*.swift` — expected: all sources parse.
- `git diff --check` — expected: no whitespace errors (if Git is available).

**Manual checks (if no CLI):**

- In Xcode, run the test target and verify a pre-midnight/post-midnight transition, ten quick entries, course archive persistence, chip solo/filter behavior, completion animation/haptic, both swipe paths, and that Today/Progress remain assignment-free.
