---
title: 'WorkoutView compile repair'
type: 'bugfix'
created: '2026-07-24'
status: 'done'
route: 'one-shot'
---

# WorkoutView compile repair

## Intent

**Problem:** Xcode could not resolve the active-workout helper in the exercise editor and could not infer the workout-details `Section` generic content.

**Approach:** Scope the helper to `WorkoutExerciseView` and use SwiftUI's explicit content/header/footer `Section` initializer, without altering workout behavior.

## Suggested Review Order

- Keeps the completed-workout read-only guard in the editor scope that consumes it.
  [`WorkoutView.swift:287`](../../Linkerworks/WorkoutView.swift#L287)

- Uses an unambiguous form section initializer for workout title and notes.
  [`WorkoutView.swift:574`](../../Linkerworks/WorkoutView.swift#L574)

- Captures the repair and remaining Xcode/device verification gap.
  [`STATE.md:104`](../../STATE.md#L104)
