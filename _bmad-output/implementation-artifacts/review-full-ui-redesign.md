# Independent Review — Full UI Redesign

Run both `bmad-review-adversarial-general` and `bmad-review-edge-case-hunter` against the scoped redesign described below. Treat other uncommitted repository work as pre-existing; it was explicitly preserved before this sprint.

## Scoped files

- `Linkerworks/TrainingLogTheme.swift`
- `Linkerworks/ContentView.swift`
- `Linkerworks/CalendarPlanView.swift`
- `Linkerworks/TrackersView.swift`
- `Linkerworks/StreaksView.swift`
- `Linkerworks/ManageView.swift`
- `Linkerworks/NutritionView.swift`
- `Linkerworks/WorkoutView.swift`

## Requirements

- Preserve all models, SwiftData/App Group behavior, seed import, widgets, tab routing, and existing editing/completion/reorder/delete semantics.
- Make the app flat, dark, typography-led, and easy to scan. Green remains completion/progress-only; avoid gradients, heavy cards, persistent floating controls, and oversized pill/circle buttons.
- Plan must retain all event functionality while replacing its segmented pill and dark date tiles with inline text modes, plain date cells, selected-date treatment, quiet event dots, and non-competing actions.
- Accessibility must retain 44pt targets, readable Dynamic Type behavior, VoiceOver state cues, and nonessential-only motion.

Report only real regressions or unhandled edge cases caused by these scoped changes, with affected path and concise reason.
