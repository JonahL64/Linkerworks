---
title: 'Fix Streaks heatmap completion type'
type: 'bugfix'
created: '2026-07-24'
status: 'done'
route: 'one-shot'
---

# Fix Streaks heatmap completion type

## Intent

**Problem:** `HeatmapDayCell` still referenced the removed `DayCompletion` type, preventing `StreaksView.swift` from compiling.

**Approach:** Use `ProgressDayCompletion`, the value returned by the snapshot-backed streak calculator.

## Suggested Review Order

- Aligns the heatmap input with the calculator's current result type.
  [`StreaksView.swift:151`](../../Linkerworks/StreaksView.swift#L151)
