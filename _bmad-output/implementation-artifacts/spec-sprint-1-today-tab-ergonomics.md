---
title: 'Sprint 1 Today tab ergonomics'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
baseline_commit: '85e3e6af6428116eba791c3e24e253d0a4945868'
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/STATE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The Today checklist requires repeated scrolling through completed work and does not expose schedule timing, section progress, focused lift control, feedback, or a recovery path for accidental checks. Late in the day, the next unfinished task can be buried behind work that no longer needs attention.

**Approach:** Make Today a compact, schedule-aware checklist: sections can collapse and collapse automatically when complete, completed work can be hidden persistently, and the next relevant timed work is visually separated. Add direct-but-reversible completion controls, including batch parent-lift completion, while preserving the existing App Group SwiftData models and completion-history rules.

## Boundaries & Constraints

**Always:** Work only in the Today surface and supporting local UI helpers; preserve existing `TaskItem`, `CompletionRecord`, `TaskCompletion`, App Group storage, task IDs, date-scoped records, widget reloads, and final-day visual completion moment. Use the established dark flat visual language; scheduled `HH:mm` times are right-aligned, muted, and monospaced. Persist only the Hide completed preference. Existing worktree changes must be preserved.

**Ask First:** Any model/schema, seed-data, navigation, widget-layout, or project-file change; any change to historical completion semantics outside the Today interaction.

**Never:** Add accounts, networking, notifications, third-party dependencies, new tabs, or work from other sprints. Do not delete or mutate historical records when editing a task.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|---------------------------|----------------|
| Finished section | Every active top-level task in a section is complete | The section collapses and its header reads its monospaced completed/total count; tapping its header can reopen it | N/A |
| Hidden completed | Persisted Hide completed is on | Completed task rows are removed from the active checklist while headers/progress retain their true totals | Empty sections remain structurally available through their headers |
| Lift parent | Parent has active children | Tap completes every currently incomplete child (or uncompletes the controlled group); long-press expands child rows for individual checks | Legacy parent-only completion remains readable and can be undone without corrupting records |
| Invalid/untimed schedule value | `time` is nil, `--`, or not `HH:mm` | No right-side time and no now-divider placement is produced for that task | N/A |
| Save failure | SwiftData save throws | Keep the current view state and show the existing plain save-failure alert; do not offer an undo for an unsaved mutation | Alert explains save failed |

</frozen-after-approval>

## Code Map

- `Linkerworks/ContentView.swift` -- Today list, completion persistence, progress ring, and final-day moment; primary implementation site.
- `Linkerworks/Domain.swift` -- Existing parent/child effective-completion helper that the Today controls must continue to use.
- `Linkerworks/TrainingLogTheme.swift` -- Existing palette, row, and section typography helpers.
- `Linkerworks/Models.swift` -- Existing SwiftData record identity/date fields used to snapshot and restore an undo.

## Tasks & Acceptance

**Execution:**
- [x] `Linkerworks/ContentView.swift` -- Add per-section expand/collapse state, auto-collapse on full effective completion, a persisted Hide completed toolbar control, and headers with monospaced mini progress so unfinished work stays compact.
- [x] `Linkerworks/ContentView.swift` -- Render valid scheduled times at the trailing edge and insert one subtle Now divider at the transition from past to upcoming timed tasks; keep untimed/placeholder values out of time logic.
- [x] `Linkerworks/ContentView.swift` -- Make lift parents batch-control active children on tap and reveal individual child controls on long press, with animated check-state transitions and preserved `TaskCompletion` semantics.
- [x] `Linkerworks/ContentView.swift` -- Centralize successful completion mutations to provide light, section-success, and custom day-complete haptics; snapshot each mutation and display a five-second Undo toast that restores the exact prior records.
- [x] `STATE.md` -- Append a concise Sprint 1 handoff covering changed paths, validation, and any runtime-only verification gap.

**Acceptance Criteria:**
- Given completed sections earlier in the day, when Today is opened at 8 PM, then fully complete sections are collapsed and the next unfinished task is visible without manually traversing their rows.
- Given Hide completed is enabled, when the app is relaunched, then the setting remains enabled and section/header and overall counts still include completed work.
- Given a task has a valid scheduled time, when it is displayed, then its time is muted, monospaced, trailing-aligned, and a single Now divider appears before the first upcoming timed task.
- Given a lift parent with active children, when it is tapped, then all active children move together to the requested completion state; when long-pressed, then individual children are available without modifying task structure.
- Given any successful check or uncheck, when it completes, then Undo remains available for five seconds and restores the exact prior record set; section and day completion feedback occur only on their corresponding completion transitions.

## Design Notes

The parent lift row remains a progress summary because `TaskCompletion` already treats children as authoritative once child records exist. Batch completion therefore writes child records rather than a new parent record. A legacy parent-only record is retained as the fallback state until a child interaction supersedes it.

The Hide completed preference belongs in `@AppStorage`; temporary section expansion and the currently expanded lift parent remain view-local. The scheduled time parser accepts only a strict 24-hour `HH:mm` value so seed placeholders cannot create false ordering or a misleading divider.

## Verification

**Commands:**
- `swiftc -parse Linkerworks/*.swift` -- expected: all app source files parse successfully.
- `git diff --check` -- expected: no whitespace errors.

**Manual checks (if no CLI):**
- In Xcode/device or Simulator, verify persistent Hide completed, collapse/expand behavior, next-task visibility late in the day, valid/invalid time placement, long-press lift expansion, child batch state, haptic hierarchy, and five-second undo restoration.

## Suggested Review Order

**Checklist visibility and scheduling**

- Builds the compact Today list and derives the on-screen time transition.
  [`ContentView.swift:57`](../../Linkerworks/ContentView.swift#L57)

- Keeps the NOW divider faithful to visible, expanded, and unhidden rows.
  [`ContentView.swift:124`](../../Linkerworks/ContentView.swift#L124)

- Provides collapsible section headers, mini counts, Hide completed, and periodic date refresh.
  [`ContentView.swift:176`](../../Linkerworks/ContentView.swift#L176)

**Completion integrity and feedback**

- Implements lift-parent controls, VoiceOver actions, batched child changes, and rollback-safe saving.
  [`ContentView.swift:422`](../../Linkerworks/ContentView.swift#L422)

- Snapshots exact records for five-second undo and refreshes the shared widget timeline.
  [`ContentView.swift:501`](../../Linkerworks/ContentView.swift#L501)

- Renders and expires the reversible completion toast.
  [`ContentView.swift:619`](../../Linkerworks/ContentView.swift#L619)

**Handoff and verification**

- Records modified paths, guarantees, validation, and the outstanding device-only checks.
  [`STATE.md:174`](../../STATE.md#L174)
