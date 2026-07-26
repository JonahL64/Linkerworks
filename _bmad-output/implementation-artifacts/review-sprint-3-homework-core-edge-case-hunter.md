# Edge Case Hunter Review Prompt — Sprint 3 Homework core

Invoke the `bmad-review-edge-case-hunter` skill on the current Sprint 3 implementation. There is no usable Git baseline; inspect these files directly:

- `Linkerworks/Models.swift`
- `Linkerworks/SharedModelContainer.swift`
- `Linkerworks/HomeworkView.swift`
- `Linkerworks/CalendarPlanView.swift`
- `LinkerworksTests/HomeworkCoreTests.swift`

Walk boundaries for midnight/week transitions, `Date.distantFuture` no-due sentinel, default 11:59 PM preservation, completed-at 14-day cutoff, archive/nullify persistence, deterministic comparator ties, zero courses, archived selected courses, save failures/rollback, course reorder, swipe actions, and editor state transitions. Report only unhandled cases that can break the specified user flow, with exact source locations and minimal corrections. Do not modify files.
