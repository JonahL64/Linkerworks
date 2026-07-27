---
title: 'Keep multi-day routine tasks manageable'
type: 'bugfix'
created: '2026-07-27'
status: 'done'
baseline_commit: 'f59f7238c881d73f4ec68455adba82fe5816c958'
review_loop_iteration: 0
context:
  - '{project-root}/AGENTS.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** A task created in Sunday/Morning and assigned to every day correctly appears on Today, but Manage Routine shows it only on Sunday. The user cannot edit or drag-reorder it from its equivalent section on the other scheduled days.

**Approach:** Make Manage Routine read the persisted task collection directly and project each multi-day task into the same-named section on every assigned weekday. Persist the originally selected section explicitly as the task's source section; keep one underlying task, completion history, and existing shared sort order.

## Boundaries & Constraints

**Always:** Display a multi-day task once in the section with the same name on every weekday in its schedule, including the originally selected section. Keep multi-day assignment behavior unchanged in Today and the widget; the selected section's weekday remains included in the task's schedule. Keep one TaskItem and its task ID, CompletionRecords, archival behavior, substeps, and existing shared sort-order semantics intact. Use the existing SwiftData App Group store and current Manage visual treatment.

**Ask First:** Renaming/restructuring existing files, changing the meaning of an existing task's primary section, or changing the user-facing multi-day controls.

**Never:** Duplicate one task into several persisted records, create one copy per day, introduce per-day sort-order storage, alter or delete historical completion records, add new routine/scheduling features, or change Today, Plan, Log, Progress, widget layout, seed data, or schema definitions.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Multi-day add | New active task has Sunday/Morning selected and every weekday selected | It appears once in Morning under every selected weekday in Manage and on every selected day in Today | Save continues to surface the existing error alert if persistence fails |
| Immediate return | Add sheet saves a task while Manage remains presented | Manage refreshes from persisted task records and exposes the new task in all matching weekday sections for editing and reordering | No stale section-relationship-only result is used |
| Existing multi-day task | An active or archived task was saved before this repair with a source section relationship | It appears under the same-named section on every assigned weekday with the correct Active/Archived filter and phase | Tasks with no section are safely omitted, as before |
| Reorder | Several active tasks share a displayed weekday section and phase | Dragging the multi-day task persists its existing single sort-order value | Existing save rollback and widget reload behavior remains |

</frozen-after-approval>

## Code Map

- `Linkerworks/ManageView.swift` -- Projects persisted task rows into assigned weekday sections, saves new tasks, and performs scoped reordering.
- `Linkerworks/Models.swift` -- Defines the persisted TaskItem-to-Section relationship; no migration is expected.
- `Linkerworks/ContentView.swift` -- Today reads the weekday schedule and is a non-regression boundary.
- `LinkerworksTests/` -- Existing focused test target; add coverage only if its current SwiftData setup can exercise this regression without new infrastructure.

## Tasks & Acceptance

**Execution:**
- [x] `Linkerworks/ManageView.swift` -- Query the persisted TaskItem collection for the Manage screen, filter/group active or archived top-level tasks by every assigned weekday's same-named section, and use that same projection for next-order and normalization calculations -- makes multi-day tasks manageable and sortable on each scheduled day without duplicating data.
- [x] `Linkerworks/ManageView.swift` -- On the new-task save path, establish the selected section directly on the TaskItem before insertion while preserving its current selected-section day plus extra-day schedule construction -- makes the primary management location explicit and durable.
- [x] `LinkerworksTests/ManageRoutineTests.swift` -- Added an in-memory SwiftData regression test that creates a Sunday/Morning task scheduled every day, saves/refetches it, confirms Manage's projection returns it for both Sunday Morning and Monday Morning exactly once under both Active and Archived filters, and calculates the next order from a mixed-source Monday list. Full Xcode test execution remains unavailable on this host.
- [x] `STATE.md` -- Appended the requested concise handoff covering the repair, paths changed, validation, and runtime limitation.

**Acceptance Criteria:**
- Given a new Sunday/Morning task with all weekdays selected, when the add sheet saves, then Manage displays it exactly once in the Morning group for each selected weekday without leaving and re-entering the screen.
- Given that task appears in a scheduled weekday's Manage group, when the user enters edit mode and drags it within its phase, then its existing persisted sort order changes with its peers and its schedule remains all weekdays.
- Given an existing single-day or multi-day task, when Manage opens in Active or Archived mode, then it appears under the same-named section on each and only each scheduled weekday, with its applicable phase.
- Given any task schedule is edited through this repair, when it is later viewed on Today, then its existing selected weekday behavior and historical CompletionRecords are unchanged.

## Spec Change Log

## Design Notes

The selected section remains the task's persisted source section. In Manage, `daysOfWeek` projects that task into each scheduled day's section with the same name, so “Sunday · Morning” scheduled daily appears in every day's “Morning” section without creating data copies.

## Verification

**Commands:**
- `swiftc -parse Linkerworks/ManageView.swift Linkerworks/Models.swift` -- expected: parsing succeeds.
- `swiftc -parse LinkerworksTests/ManageRoutineTests.swift` -- expected: parsing succeeds if the focused test is added.
- `git diff --check` -- expected: no whitespace errors.

**Manual checks (if no CLI):**
- In Xcode, add a Sunday/Morning task, enable every additional weekday, save, and confirm it immediately appears in Morning under Sunday through Saturday Manage where it can be dragged; confirm it is visible in Today on each assigned day.

## Suggested Review Order

**Manage projection and ordering**

- Read the persisted task query and daily section list entry point.
  [`ManageView.swift:7`](../../Linkerworks/ManageView.swift#L7)

- Verify same-named weekday sections receive one shared task record.
  [`ManageView.swift:165`](../../Linkerworks/ManageView.swift#L165)

- Confirm new tasks use the selected source section and projected ordering.
  [`ManageView.swift:236`](../../Linkerworks/ManageView.swift#L236)

- Confirm all new-task order positions use the same projection.
  [`ManageView.swift:581`](../../Linkerworks/ManageView.swift#L581)

**Regression coverage**

- Review active, archived, and mixed-source ordering assertions.
  [`ManageRoutineTests.swift:7`](../../LinkerworksTests/ManageRoutineTests.swift#L7)
