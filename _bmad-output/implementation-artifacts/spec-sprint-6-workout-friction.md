---
title: 'Sprint 6 workout friction'
type: 'feature'
created: '2026-07-25'
status: 'done'
review_loop_iteration: 0
baseline_commit: '944c6918729ed8bbfbcec23c4747e0126ad04cd6'
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/STATE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Straight-set workout logging currently requires repeated secondary actions and modal editing, making a simple 5x5 session far slower than it needs to be. An active workout is also only discoverable through Log.

**Approach:** Keep the existing session/set storage and history immutable, but streamline the active workout path: surface it on Today, clone a matching finished workout, give set entry a continuous keyboard path, and put repeated-set logging first.

## Boundaries & Constraints

**Always:** Use the established App Group SwiftData workout records without schema changes. Keep `WorkoutSession`'s unique in-progress key as the one-active-session guarantee. Clone only exercise names, order, set order, reps, and loads; cloned sets are always uncompleted with no completion timestamps. Keep all finished sessions and their details read-only. Display duration, timer, and volume with monospaced numeric text where appropriate. The rest timer is visual-only and never sends notifications.

**Ask First:** Changing workout model/schema, App Group configuration, tab structure, seed files, widgets, or any non-workout feature.

**Never:** Add templates, routines/builders, plate math, notifications, cloud features, or historical-session mutation. Do not make an untitled prior session eligible for Repeat last workout; matching uses a trimmed non-empty title.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Resume banner | One persisted in-progress session, including after relaunch | Today pins a tappable title, live elapsed time, and total set count; tap opens its Workout screen | No banner when no active session exists |
| Repeat matching workout | New workout title matches a finished titled session | Clone the most recent matching session's ordered exercise/set structure and loads into the sole new active session; every set starts uncompleted | No matching/non-empty title leaves normal new-workout behavior available |
| Keyboard set chain | Active exercise; user submits reps then load | Reps advances focus to load; load submission adds the next uncompleted set and returns focus to reps without dismissing the keyboard | Invalid/empty numeric input leaves focus in place and shows validation rather than creating a set |
| Repeated set and timer | Completed set exists; user adds repeated completed set or completes a set | Primary action clones the latest completed set's reps/load as completed; timer starts/reset from the latest completion and appears in header | No completed prior set falls back to the normal first-set entry |
| Finished history | Finished session/detail | Existing history remains visible but has no mutation or clone side effects | Existing read-only guards remain intact |

</frozen-after-approval>

## Code Map

- `Linkerworks/ContentView.swift` — Today query and pinned active-workout resume link.
- `Linkerworks/WorkoutView.swift` — workout start/repeat logic, active exercise fast entry, repeated-set primary action, rest display, and volume header.
- `STATE.md` — Sprint 6 handoff, paths, constraints, and verification state.

## Tasks & Acceptance

**Execution:**

- [x] `Linkerworks/ContentView.swift` — query the persisted active session and add a pinned Today resume banner with derived title, elapsed duration, and set count.
- [x] `Linkerworks/WorkoutView.swift` — accept a workout title at start; locate the newest completed same-title session and clone its exercise/set shape without completion state while retaining load values.
- [x] `Linkerworks/WorkoutView.swift` — implement the active-exercise reps → load → submit focus chain, including immediate next-set creation/refocus and input validation.
- [x] `Linkerworks/WorkoutView.swift` — promote repeated completed set cloning to the main action; calculate/display visual rest time and per-exercise volume without persisting either.
- [x] `STATE.md` — append the Sprint 6 handoff and runtime-verification gap.

**Acceptance Criteria:**

- Given a matching completed 5x5 workout, when it is repeated and the user logs the session, then it can be completed in 12 taps or fewer end-to-end.
- Given an active session, when the app relaunches, then the same single persisted session remains resumable from both Today and Workout.
- Given a finished workout, when it is viewed in history, then its exercises and sets remain unchanged and non-editable.

## Design Notes

Use a Today `safeAreaInset` (or equivalent fixed top placement) so the resume control does not scroll away with the checklist. Derive volume as the sum of each set's reps × load, treating missing load as zero; derive the rest display from the most recent completed set and reset/restart it on the next completion. The keyboard chain must use a keyboard configuration that supplies Return/Submit, not a decimal pad that cannot submit.

## Verification

**Commands:**

- `swiftc -parse Linkerworks/*.swift` — expected: all app sources parse.
- `git diff --check` — expected: no whitespace errors.

**Manual checks (if Xcode is available):**

- Start a titled workout, log a 5x5 with the keyboard flow, finish it, repeat it, and confirm cloned loads/structure with all cloned sets uncompleted.
- Relaunch while active and confirm one Today banner resumes the active workout; complete sets and confirm timer/volume; inspect finished history remains read-only.

## Suggested Review Order

**Resume and session safety**

- Today surfaces exactly the one persisted workout without changing its storage contract.
  [`ContentView.swift:298`](../../Linkerworks/ContentView.swift#L298)

- Title matching selects the latest finished routine and clones only editable active-session data.
  [`WorkoutView.swift:194`](../../Linkerworks/WorkoutView.swift#L194)

**Fast set logging**

- Inline fields keep keyboard focus through reps, load, and set creation.
  [`WorkoutView.swift:500`](../../Linkerworks/WorkoutView.swift#L500)

- Repeated completed sets stay a deliberate, prominent one-tap action.
  [`WorkoutView.swift:592`](../../Linkerworks/WorkoutView.swift#L592)

**Session feedback**

- Completed-work volume and cross-exercise visual rest time are derived, never persisted.
  [`WorkoutView.swift:366`](../../Linkerworks/WorkoutView.swift#L366)

- The session handoff captures scope, checks, and the device-runtime verification gap.
  [`STATE.md:232`](../../STATE.md#L232)
