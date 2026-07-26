- source_spec: `_bmad-output/implementation-artifacts/spec-full-usability-simplification.md`
  summary: Preserve historical streak and heatmap denominators when a task is later moved, rescheduled, or archived.
  evidence: Streak calculation intentionally uses each task's current schedule and archived state, so past progress can be reinterpreted despite unchanged completion records.
- source_spec: `_bmad-output/implementation-artifacts/spec-full-usability-simplification.md`
  summary: Roll back staged model mutations after a task/completion save failure.
  evidence: Existing Today and Manage save paths report failures but leave their in-memory mutation staged for a later save.
- source_spec: `_bmad-output/implementation-artifacts/spec-full-usability-simplification.md`
  summary: Improve widget next-task selection for untimed or already-past incomplete tasks.
  evidence: The existing widget can show “Day complete” when incomplete tasks have no later valid HH:mm time.
- source_spec: `_bmad-output/implementation-artifacts/spec-historical-progress-snapshots.md`
  summary: Define and migrate stable local-day semantics when the device time zone changes.
  evidence: Existing CompletionRecord dates and new snapshot day keys both derive from Calendar.current, so cross-time-zone history needs an explicit product policy rather than implicit reinterpretation.
- source_spec: `_bmad-output/implementation-artifacts/spec-fix-manage-taskitem-argument-order.md`
  summary: Add Xcode-backed persistence and UI coverage for creating phased tasks and lift sub-steps.
  evidence: The compiler repair is source-parsed, but this host has only Command Line Tools and cannot run the app-target build or interaction tests.
