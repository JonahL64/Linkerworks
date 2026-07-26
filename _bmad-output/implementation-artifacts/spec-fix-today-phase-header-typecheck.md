---
title: 'Fix Today Phase Header Type Check'
type: 'bugfix'
created: '2026-07-26'
status: 'done'
route: 'one-shot'
---

# Fix Today Phase Header Type Check

## Intent

**Problem:** Even with a precomputed guidance string, Today’s nested list-builder header still exceeds Xcode’s type-checking budget.

**Approach:** Extract the complete phase header into an opaque `some View` helper so the outer list builder type-checks only a single call.

## Suggested Review Order

**List-builder boundary**

- Confirm the nested section header is now one opaque helper call.
  [`ContentView.swift:283`](../../Linkerworks/ContentView.swift#L283)

**Extracted phase header**

- Verify the helper preserves phase label, guidance, and section control layout.
  [`ContentView.swift:434`](../../Linkerworks/ContentView.swift#L434)

**Handoff record**

- Capture the compiler-repair scope and validation boundary.
  [`STATE.md:310`](../../STATE.md#L310)
