---
title: 'Sprint 8 intent-based navigation'
type: 'feature'
created: '2026-07-21'
status: 'done'
review_loop_iteration: 0
baseline_commit: '85e3e6af6428116eba791c3e24e253d0a4945868'
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/STATE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Linkerworks currently exposes feature-oriented top-level tabs—Streaks, Trackers, and Manage—which do not match the intended user flow. Routine management also lacks a natural home beside a calendar-led planning surface.

**Approach:** Reorganize the existing SwiftUI shell into exactly Today, Plan, Log, Progress, and More. Preserve the existing Today, Trackers, Streaks, and Manage implementations, altering only their placement and visible labels; Plan and More provide polished, non-persistent placeholders for future scope.

## Boundaries & Constraints

**Always:** Keep Today’s checklist, progress ring, final-completion moment, and `linkerworks://today` routing unchanged. Keep all Manage editing, weekday, ordering, archive, and completion-history safeguards intact. Keep Log’s six domain/history/reference behaviors and Progress’s streak, heatmap, rollup, and history behavior intact. Retain the established dark athletic visual language and the existing file structure wherever possible.

**Ask First:** Adding persistent calendar/event behavior, app-level settings/data tooling, a new top-level tab, a new model or seed content, modifying widgets, or changing App Group configuration.

**Never:** Implement functional calendar events or scheduling; study/certification, nutrition, workout, or settings features; new data models; seed-data changes; widgets; third-party integrations; or a rewrite of existing feature behavior.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| Deep link | App receives `linkerworks://today` from any selected tab | Today becomes selected and keeps its current behavior | Ignore unrelated URLs as before |
| Routine management | User opens Manage Routine from Plan | Existing Manage experience opens with its full editing/archive behavior | Existing Manage validation and save errors remain responsible |
| Future surfaces | User opens Plan or More with no future data configured | Calendar placeholder or app-tools placeholder appears; neither persists data | No unavailable feature action is offered |

</frozen-after-approval>

## Code Map

- `Linkerworks/ContentView.swift` — owns the tab shell, Today view, and deep-link tab selection; will host the lightweight Plan and More surfaces.
- `Linkerworks/TrackersView.swift` — current domain tracker list and detail content; only its user-facing root title should change.
- `Linkerworks/StreaksView.swift` — current streak summary, heatmap, and weekly rollups; only its user-facing root title should change.
- `Linkerworks/ManageView.swift` — existing routine management implementation reused unchanged from Plan.
- `Linkerworks/TrainingLogTheme.swift` — existing dark palette and view modifiers used by the new placeholder surfaces.
- `STATE.md` — append Sprint 8 scope, affected paths, and honest verification status.

## Tasks & Acceptance

**Execution:**

- [x] `Linkerworks/ContentView.swift` — replace the four-item tab shell with exactly Today, Plan, Log, Progress, and More in that order; preserve Today routing, move the existing views to Log/Progress, and add only lightweight themed Plan/More views. Plan defaults to a calendar empty state and presents the unchanged Manage view from a prominent “Manage Routine” action.
- [x] `Linkerworks/TrackersView.swift` — change the root navigation title from “Trackers” to “Log” without touching domain navigation, queries, history, or reference rendering.
- [x] `Linkerworks/StreaksView.swift` — change the root navigation title from “Streaks” to “Progress” without touching calculations, heatmap, rollups, or history behavior.
- [x] `STATE.md` — append 5–10 factual Sprint 8 handoff lines, including changed paths and the runtime verification limitation if it remains.

**Acceptance Criteria:**

- Given the app’s root TabView, when it renders, then it shows exactly five tabs in this order: Today, Plan, Log, Progress, More; Manage, Streaks, and Trackers are not top-level labels.
- Given the Plan tab, when it first opens, then a dark calendar-focused placeholder is its default destination and it offers a prominent Manage Routine action without event, schedule, study, or certification functionality.
- Given the user taps Manage Routine, when the existing manager is presented, then adding, editing, reordering, weekday assignment, archiving, and historical-completion protections remain available through the unmodified Manage experience.
- Given the Log and Progress tabs, when they open, then their previous content and behavior remain available under the new visible root labels “Log” and “Progress.”
- Given the app receives `linkerworks://today`, when any tab is selected, then the Today tab becomes selected exactly as it did before.

## Design Notes

The Plan action should present `ManageView` rather than recreate or relocate management controls. This keeps the feature’s behavior and state boundaries intact while making routine management available where it belongs in the new IA. Plan and More should use the existing flat background, primary/secondary text, and SF Symbols; their copy must make future scope legible without implying a working feature.

## Verification

**Commands:**

- `swiftc -parse Linkerworks/*.swift` — expected: every app Swift source parses successfully.
- `git diff --check` — expected: no whitespace errors.

**Manual checks (if Xcode is available):**

- Launch the app and confirm five tabs, Plan default calendar placeholder, Manage Routine presentation, renamed Log/Progress roots, existing feature content, and a `linkerworks://today` return to Today.

## Suggested Review Order

**Navigation and routing**

- Establishes the five intent-based destinations and preserves Today deep-link routing.
  [ContentView.swift:4](../../Linkerworks/ContentView.swift#L4)

- Dismisses routine management before a Today deep link changes the selected tab.
  [ContentView.swift:46](../../Linkerworks/ContentView.swift#L46)

**Plan and future surfaces**

- Keeps Calendar non-persistent while reusing the existing routine manager unchanged.
  [ContentView.swift:62](../../Linkerworks/ContentView.swift#L62)

- Reserves a minimal themed location for future app-level tools.
  [ContentView.swift:149](../../Linkerworks/ContentView.swift#L149)

**Relabeled existing experiences**

- Renames the existing domain tracker root without changing its detail navigation.
  [TrackersView.swift:5](../../Linkerworks/TrackersView.swift#L5)

- Renames the existing streak view without changing its calculations or content.
  [StreaksView.swift:58](../../Linkerworks/StreaksView.swift#L58)
