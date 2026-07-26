---
title: 'Sprint 10 workout sessions and set logging'
type: 'feature'
created: '2026-07-23'
status: 'done'
review_loop_iteration: 0
baseline_commit: '85e3e6af6428116eba791c3e24e253d0a4945868'
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/STATE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Log has Lifting checklist and reference material but no durable way to record an actual workout, its exercises, or the sets completed in it.

**Approach:** Add a first-class Workout destination to Log, backed by additive App Group SwiftData session, exercise, and set records. It supports one resumable in-progress workout, editing its exercises and sets, finishing it into retained history, and leaves the Lifting tracker accessible.

## Boundaries & Constraints

**Always:** Preserve all existing task/checklist, tracker/reference, Nutrition, navigation, widget, seed-import, and App Group behavior. Persist sessions, exercises, and sets in the existing shared SwiftData store. A session records a start time, optional finish time/title/notes, and in-progress/completed state; exercises retain a name and order; sets retain order, reps, optional load, and completed timestamp/state. Log presents Workout as its clear first action while retaining all six domain tracker links, including Lifting. Numeric reps, load, dates, and times use monospaced treatment where shown.

**Ask First:** Changing seed JSON, widget code, App Group identifier/configuration, tab structure, existing Lifting checklist/reference behavior, or broad file/folder organization.

**Never:** Add workout templates, program builders, rest timers, PR analytics, HealthKit, social features, cloud sync, notifications, third-party packages, or modifications to seed data/widget code.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Start and resume | No session, then app relaunches with one in-progress session | Starting creates one durable session; Log reopens its Workout screen and it resumes the same session | A second start action is unavailable while an in-progress session exists |
| Exercise management | Active workout with exercises | Add, rename, move, or remove exercises; order persists and removing one removes only its own sets | Blank exercise names cannot be saved |
| Set logging | Active exercise with a set draft | A valid reps value and optional nonnegative load save; completion can be toggled and records/clears timestamp; moves and deletes persist | Missing/negative reps or invalid/negative load prevents saving with an explanation |
| Finish and history | Active workout with exercises/sets | Finish stamps completion, removes it from active state, and keeps its exercises/sets visible in completed history | No delete occurs while finishing; save failure leaves the active state intact |
| Existing Lifting | User opens Log or Lifting after upgrade | Workout is the primary route; Lifting checklist completion history and imported reference content are unchanged | No task, completion, reference, or seed mutation occurs |

</frozen-after-approval>

## Code Map

- `Linkerworks/Models.swift` -- shared SwiftData entity definitions; add workout state/session, exercise, and set models with dependent relationships.
- `Linkerworks/SharedModelContainer.swift` -- explicit schema for the established App Group store; register the additive workout models.
- `Linkerworks/WorkoutView.swift` -- new active-session editor and retained completed-workout history UI.
- `Linkerworks/TrackersView.swift` -- Log root; route its first, visibly emphasized action to Workout without removing trackers.
- `STATE.md` -- Sprint 10 handoff and verification gap.

## Tasks & Acceptance

**Execution:**

- [x] `Linkerworks/Models.swift` -- define persistent, additive `WorkoutSession`, `WorkoutExercise`, and `WorkoutSet` models plus durable state representation and ordered cascade relationships.
- [x] `Linkerworks/SharedModelContainer.swift` -- include all workout models in the existing App Group schema without changing its store location or previous entities.
- [x] `Linkerworks/WorkoutView.swift` -- implement the start/resume workflow, optional title/notes editing, exercise and set add/edit/complete/reorder/delete flows, finish action, history list/detail presentation, validation, saves, and dark athletic numeric styling.
- [x] `Linkerworks/TrackersView.swift` -- make Workout the first, visually primary Log route while retaining Nutrition and all six tracker links.
- [x] `STATE.md` -- append 5–10 factual lines covering Sprint 10 scope, changed paths, preservation, verification, and any runtime gap.

**Acceptance Criteria:**

- Given no workout is active, when the user starts one from Workout, then exactly one in-progress persistent session opens; after relaunch, it is the session shown.
- Given an active workout, when exercises or valid sets are added, edited, moved, completed/uncompleted, or deleted, then their persisted ordered structure reflects those changes without changing another exercise or session.
- Given a completed set, when it is uncompleted, then its persisted completion timestamp is cleared; when it is completed again, a timestamp is recorded.
- Given an active workout, when it is finished, then it becomes completed with a finish time and retains all recorded exercises and sets in history.
- Given the Log tab, when it opens, then Workout is the clear first action while Nutrition and every existing domain tracker remain reachable; the Lifting tracker still shows its existing task history and reference content.

## Design Notes

Keep workout relationships session -> exercises -> sets local and cascade-deleting only within a session. Finishing is a state/timestamp update, never a deletion. The active workout query is defensive: it resolves the one persisted in-progress session (latest start time if legacy/corrupt duplicate records exist) so no second active session is created. Set load remains optional rather than encoding absent load as zero.

## Verification

**Commands:**

- `swiftc -parse Linkerworks/*.swift` -- expected: all app sources parse.
- `git diff --check` -- expected: no whitespace errors.

**Manual checks (if Xcode is available):**

- Launch against a pre-existing store; start, relaunch, resume, and finish a workout; create/edit/reorder/delete exercises and sets; toggle set completion; confirm history survives and existing Lifting content is unchanged.

## Suggested Review Order

**Log entry and active-session workflow**

- Makes Workout the first Log action without removing existing trackers.
  [`TrackersView.swift:8`](../../Linkerworks/TrackersView.swift#L8)

- Coordinates start/resume, finishing, exercise order, and retained completed history.
  [`WorkoutView.swift:14`](../../Linkerworks/WorkoutView.swift#L14)

- Prevents duplicate rapid starts while the SwiftData query refreshes.
  [`WorkoutView.swift:172`](../../Linkerworks/WorkoutView.swift#L172)

**Exercise and set logging**

- Provides editable, ordered sets and protects completed workouts from stale edits.
  [`WorkoutView.swift:291`](../../Linkerworks/WorkoutView.swift#L291)

- Toggles completion timestamps and safely normalizes order after deletes.
  [`WorkoutView.swift:389`](../../Linkerworks/WorkoutView.swift#L389)

- Validates optional decimal loads across locales and rejects non-finite values.
  [`WorkoutView.swift:737`](../../Linkerworks/WorkoutView.swift#L737)

**Shared persistence**

- Enforces one persisted in-progress session and cascades its dependent records.
  [`Models.swift:291`](../../Linkerworks/Models.swift#L291)

- Registers additive workout models in the existing App Group schema.
  [`SharedModelContainer.swift:8`](../../Linkerworks/SharedModelContainer.swift#L8)

**Handoff and verification**

- Records scope preservation and the remaining device-runtime verification gap.
  [`STATE.md:95`](../../STATE.md#L95)
