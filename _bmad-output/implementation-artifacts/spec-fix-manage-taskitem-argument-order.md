---
title: 'Fix Manage TaskItem Argument Order'
type: 'bugfix'
created: '2026-07-26'
status: 'done'
route: 'one-shot'
---

# Fix Manage TaskItem Argument Order

## Intent

**Problem:** `ManageView` passes `routinePhase` after `detail` in two `TaskItem` initializers, violating Swift's ordered argument-label rule and blocking compilation.

**Approach:** Place `routinePhase` before `detail` at both new-task creation sites, matching the established initializer declaration.

## Suggested Review Order

**Task creation calls**

- Verify both creation paths follow the initializer’s required label sequence.
  [`ManageView.swift:469`](../../Linkerworks/ManageView.swift#L469)

- Confirm pending lift sub-steps receive the selected parent phase.
  [`ManageView.swift:500`](../../Linkerworks/ManageView.swift#L500)

**Initializer contract**

- Confirm the declaration requires `routinePhase` before `detail`.
  [`Models.swift:250`](../../Linkerworks/Models.swift#L250)

**Handoff record**

- Capture the targeted repair and its validation boundary.
  [`STATE.md:298`](../../STATE.md#L298)
