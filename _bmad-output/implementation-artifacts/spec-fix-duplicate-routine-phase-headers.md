---
title: 'Fix duplicate routine phase headers'
type: 'bugfix'
created: '2026-07-26'
status: 'done'
route: 'one-shot'
---

# Fix duplicate routine phase headers

## Intent

**Problem:** Today repeated a flexible phase label and its guidance for every underlying routine section, making a phase such as Morning appear multiple times in the checklist.

**Approach:** Render one List section per populated phase, then render each applicable routine-section control and its filtered tasks inside that phase.

## Suggested Review Order

**One phase heading, many routine sections**

- [ContentView.swift:377](../../Linkerworks/ContentView.swift#L377) — groups populated sections beneath a single phase header.

**Existing task behavior retained**

- [ContentView.swift:394](../../Linkerworks/ContentView.swift#L394) — preserves filtering, completion hiding, collapse controls, and lift sub-step rendering for each routine section.

