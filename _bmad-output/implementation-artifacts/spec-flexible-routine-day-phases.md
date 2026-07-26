---
title: 'Flexible routine day phases'
type: 'feature'
created: '2026-07-25'
status: 'done'
review_loop_iteration: 0
context: []
baseline_commit: 'e6c369675a83a76f07415e25508cf8747a446c8a'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Routine tasks currently carry fixed clock times from seed data and the task editor, making ordinary habits feel overdue when the user wakes late or has an irregular day. The user still wants an intentional sequence, but not time pressure.

**Approach:** Replace routine-task clock scheduling with flexible day phases—Anytime, Morning, Midday, Afternoon, and Evening—and retain drag ordering inside each phase. Add settings that let the user define the meanings and time ranges of those phases; those settings are guidance and labels only, never due dates.

## Boundaries & Constraints

**Always:** Remove exact-time display, editing, Now dividers, and time-based widget routine ordering for all routine tasks, including seed and newly created tasks. Preserve each task’s relative order inside its selected phase. Existing routine times must be converted once to an initial phase and then cleared. Homework due dates and calendar-event start/end times remain exact-time features and must be unchanged. Preserve TaskItem IDs and CompletionRecord history.

**Ask First:** Adding additional phase types, phase-specific reminder behavior, or changing homework/calendar due-time behavior.

**Never:** Add notifications, networking, accounts, cloud sync, or reinterpret historical completion/streak data.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Existing routine migration | Task has a valid legacy time | It receives its inferred phase, clears its routine time, and retains its relative phase order | Malformed/missing times use the task section or Anytime fallback |
| New task | User selects Afternoon and saves | It is appended after other active Afternoon tasks in the selected section; Today and widgets show no clock time | Empty title/section retains current validation |
| Phase move | Existing task changes from Morning to Evening | It moves to the end of Evening order without changing completion records | Save failure rolls back model changes and reports error |
| Due-time data | Assignment/calendar event with a time | Its existing date/time UI and ordering remain unchanged | Existing behavior |

</frozen-after-approval>

## Code Map

- Linkerworks/Models.swift — persisted TaskItem phase and phase model helpers.
- Linkerworks/SeedImporter.swift and Linkerworks/LinkerworksApp.swift — first import and one-time legacy task migration.
- Linkerworks/ContentView.swift — Today grouping and removal of time-based task-bar pressure.
- Linkerworks/ManageView.swift — phase picker, phase-scoped ordering, and time-free task summaries/editing.
- Linkerworks/SettingsView.swift — editable day-phase labels/ranges.
- Linkerworks/Domain.swift and LinkerworksWidget/LinkerworksWidget.swift — phase-first routine widget ordering and time-free widget content.
- LinkerworksTests/ — phase inference, ordering, and migration-focused regression coverage.

## Tasks & Acceptance

**Execution:**
- [x] Models.swift — add an additive persisted day-phase representation to TaskItem, with stable ordering and legacy time/section inference helpers.
- [x] SeedImporter.swift and LinkerworksApp.swift — assign phases during seed import and run an idempotent App Group migration that maps existing task times, clears routine times, and does not touch completion records.
- [x] ManageView.swift — replace task/substep time fields with a phase picker, show phase labels in summaries, append new/phase-moved tasks at the end of their phase, and keep drag moves scoped to a phase.
- [x] ContentView.swift — display routine tasks by configured phase and existing section/order, removing time labels and the Now/upcoming divider.
- [x] SettingsView.swift — add a routine-phase settings section for customized phase names and start-time guidance, rejecting blank/duplicate labels and non-ascending boundaries.
- [x] Domain.swift and LinkerworksWidget.swift — remove routine-time parsing/display and order incomplete routine tasks by phase, section, then within-phase task order.
- [x] LinkerworksTests/ — cover valid/malformed legacy mapping and phase ordering; existing routine-only progress tests continue to exclude assignment/calendar data.

**Acceptance Criteria:**
- Given a seeded or existing regular task with a clock time, when the app completes its one-time migration, then the task has a flexible phase and no routine time is visible or retained.
- Given a user adds a task in a phase, when they save it, then it appears after that phase’s current tasks and can be drag-reordered only among tasks in that phase.
- Given the user customizes phase wording/ranges, when they return to Today or Manage, then the chosen wording is reflected without changing task completion, schedules, or exact-time due data.
- Given an assignment or calendar event with a specific time, when routine phases are introduced, then its time remains displayed and behaves exactly as before.
- Given routine tasks are viewed in Today or the routine widget, when they are incomplete, then they have no clock-time display or time-pressure ordering.

## Spec Change Log

## Design Notes

Phase settings are personal guidance, not alarms or eligibility gates. Suggested defaults: Morning (wake–11:30), Midday (11:30–14:30), Afternoon (14:30–18:00), Evening (18:00–sleep), plus Anytime. Their labels may be personalized, but persisted phase identities remain stable so changing a label never remaps tasks.

## Verification

**Commands:**
- swiftc -parse Linkerworks/*.swift LinkerworksWidget/*.swift LinkerworksTests/*.swift — expected: all sources parse.
- git diff --check — expected: no whitespace errors.

**Manual checks (if no CLI):**
- Verify a pre-existing seeded task migrates once, has no displayed routine time, and retains completion history.
- Add, edit, drag, and move tasks across phases; verify phase-local order and widget order.
- Confirm homework due times and calendar-event times remain visible and unchanged.

## Suggested Review Order

**Routine data and safe migration**

- Defines stable phase identities independently from personalized labels.
  [Models.swift:6](../../Linkerworks/Models.swift#L6)

- Converts legacy routine times once without touching completion history.
  [SeedImporter.swift:231](../../Linkerworks/SeedImporter.swift#L231)

- Runs migration after seed import during App Group store startup.
  [LinkerworksApp.swift:13](../../Linkerworks/LinkerworksApp.swift#L13)

**Flexible routine experience**

- Renders Today phase-first and surfaces personalized guidance.
  [ContentView.swift:259](../../Linkerworks/ContentView.swift#L259)

- Keeps task creation and drag ordering scoped to a chosen phase.
  [ManageView.swift:39](../../Linkerworks/ManageView.swift#L39)

- Lets labels and time-of-day guidance match the user's own day.
  [SettingsView.swift:16](../../Linkerworks/SettingsView.swift#L16)

**Widget and regression support**

- Orders incomplete routine tasks by phase, never by clock time.
  [LinkerworksWidget.swift:70](../../LinkerworksWidget/LinkerworksWidget.swift#L70)

- Characterizes phase ordering and legacy inference boundaries.
  [WidgetProjectionTests.swift:7](../../LinkerworksTests/WidgetProjectionTests.swift#L7)
