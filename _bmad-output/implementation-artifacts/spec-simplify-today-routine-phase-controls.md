---
title: 'Simplify Today routine phase controls'
type: 'bugfix'
created: '2026-07-26'
status: 'done'
route: 'one-shot'
---

# Simplify Today routine phase controls

## Intent

**Problem:** A legacy routine section can contain tasks from more than one flexible phase, so showing that section under each phase duplicated its control and made expansion awkward.

**Approach:** Make flexible phases the only collapsible Today groups, with one accessible header, progress count, and direct task list per populated phase.

## Suggested Review Order

**Phase-first Today structure**

- [ContentView.swift:377](../../Linkerworks/ContentView.swift#L377) — renders each populated phase as one direct task group, without legacy section nesting.

**Phase controls and completion behavior**

- [ContentView.swift:444](../../Linkerworks/ContentView.swift#L444) — makes the phase header accessible and expandable.
- [ContentView.swift:724](../../Linkerworks/ContentView.swift#L724) — collapses a completed phase and reopens it when it becomes incomplete.

