---
title: 'Fix Today List Builder Type Check'
type: 'bugfix'
created: '2026-07-26'
status: 'done'
route: 'one-shot'
---

# Fix Today List Builder Type Check

## Intent

**Problem:** Today’s large `List` result builder continues to exceed Xcode’s type-checking budget as independent nested branches are inferred together.

**Approach:** Render the homework, saved-meal, and routine-phase branches through dedicated opaque view helpers, leaving the outer list builder shallow.

## Suggested Review Order

**Outer list boundary**

- Confirm conditional branches delegate to opaque helper views.
  [`ContentView.swift:201`](../../Linkerworks/ContentView.swift#L201)

**Extracted sections**

- Verify homework and saved-meal presentation retain their existing actions and limits.
  [`ContentView.swift:320`](../../Linkerworks/ContentView.swift#L320)

- Verify routine phases retain filtering, collapse, and lift-child rendering.
  [`ContentView.swift:377`](../../Linkerworks/ContentView.swift#L377)

**Handoff record**

- Capture the compiler-repair scope and validation boundary.
  [`STATE.md:322`](../../STATE.md#L322)
