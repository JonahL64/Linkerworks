---
title: 'Fix workout start form compilation'
type: 'bugfix'
created: '2026-07-24'
status: 'done'
route: 'one-shot'
---

# Fix workout start form compilation

## Intent

**Problem:** The start-workout form used a `Section` initializer shape that SwiftUI could not infer in Xcode.

**Approach:** Use SwiftUI’s explicit content, header, and footer closure initializer without changing the form or workout-start behavior.

## Suggested Review Order

- The explicit closure initializer resolves generic inference while retaining the existing labels and footer.
  [`WorkoutView.swift:657`](../../Linkerworks/WorkoutView.swift#L657)
