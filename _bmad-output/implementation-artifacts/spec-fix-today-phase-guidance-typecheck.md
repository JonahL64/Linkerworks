---
title: 'Fix Today Phase Guidance Type Check'
type: 'bugfix'
created: '2026-07-26'
status: 'done'
route: 'one-shot'
---

# Fix Today Phase Guidance Type Check

## Intent

**Problem:** The nested optional-formatting expression for Today’s phase guidance exceeds Xcode’s SwiftUI type-checking budget.

**Approach:** Compute the phase-guidance string in a small helper and pass its concrete result to `Text`.

## Suggested Review Order

**Today phase header**

- Confirm the SwiftUI header receives a simple concrete string.
  [`ContentView.swift:283`](../../Linkerworks/ContentView.swift#L283)

- Verify the helper preserves both configured and flexible guidance wording.
  [`ContentView.swift:441`](../../Linkerworks/ContentView.swift#L441)

**Handoff record**

- Capture the compiler-repair scope and validation boundary.
  [`STATE.md:304`](../../STATE.md#L304)
