---
title: 'Fix weight entry helper shadowing'
type: 'bugfix'
created: '2026-07-27'
status: 'done'
route: 'one-shot'
---

# Fix weight entry helper shadowing

## Intent

**Problem:** `WeightEntrySupport.entry` attempted to call `entries(...)`, but its `entries` parameter shadows that helper and prevents Xcode compilation.

**Approach:** Qualify the static helper with `Self` so the existing same-day lookup executes unchanged.

## Suggested Review Order

- Qualification resolves the name collision without changing the weight-entry selection logic.
  [Models.swift:670](../../../Linkerworks/Models.swift#L670)
