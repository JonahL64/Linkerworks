---
title: 'Full UI redesign'
type: 'feature'
created: '2026-07-24'
status: 'in-review'
review_loop_iteration: 0
baseline_commit: '85e3e6af6428116eba791c3e24e253d0a4945868'
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/STATE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-Linkerworks-2026-07-24/DESIGN.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-Linkerworks-2026-07-24/EXPERIENCE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The app’s screens are functionally capable but visually inconsistent and overuse broad system controls, filled tiles, and competing actions. The new Plan calendar makes the problem especially visible: it reads as a keypad rather than a calendar.

**Approach:** Apply the finalized Linkerworks Training Log visual and experience spines across the entire existing iPhone app. Preserve all workflows and data; redesign hierarchy, layout, shared components, and interaction chrome so Today, Plan, Log, Progress, More, Manage, and their editors feel like one calm, precise product.

## Boundaries & Constraints

**Always:** Implement `DESIGN.md` and `EXPERIENCE.md` as the source of truth. Retain the five existing tabs and all current models, persistence, seed import, widget behavior, navigation destinations, and editing/completion semantics. Use the dark athletic palette: flat `#0E1210` canvas, near-white primary text, muted secondary text, hairline separators, monospaced times/numbers, and green only for completion/progress. Prefer compact native toolbar actions, flat rows, restrained 6–8pt corners, one clear action per surface, Dynamic Type, and 44pt hit targets.

**Ask First:** Changing the five-tab information architecture, any feature behavior/data model, the App Group store, seed data, widgets, the established dark palette, or adding third-party dependencies/assets.

**Never:** Add feature scope, gradients, shadows/glow, category-color systems, card-heavy dashboards, persistent floating actions, oversized pill/circle controls, decorative illustrations, custom navigation patterns, or change user data/history.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Compact Plan calendar | Month with no or many events; a date is selected | Plain numbered cells, a quiet event marker, selected-date treatment, compact context tabs, and an agenda without duplicate or competing CTAs | Empty dates retain a readable agenda message and the native Add action remains reachable |
| Existing workflow | Tasks, events, meals, workouts, tracking history, and editors contain data | Same data and actions remain reachable through the existing routes, but use flat rows, clear hierarchy, and shared spacing/type treatments | Save/delete validation and failure messaging retain existing behavior and entered data |
| Accessibility | Large Dynamic Type, VoiceOver, Reduce Motion | Essential labels wrap, controls remain tappable/announced, color is not the only state signal, and motion stays optional | No date number or primary action becomes hidden/truncated |

</frozen-after-approval>

## Code Map

- `Linkerworks/TrainingLogTheme.swift` -- shared palette, spacing, type, row, section, and mode-control primitives used by all app surfaces.
- `Linkerworks/ContentView.swift` -- tab shell, Today hierarchy, progress summary, and More placeholder.
- `Linkerworks/CalendarPlanView.swift` -- highest-priority Plan redesign: calendar grid, mode tabs, agendas, toolbars, and event editor presentation.
- `Linkerworks/TrackersView.swift`, `Linkerworks/StreaksView.swift` -- Log and Progress root/detail hierarchy, rows, summaries, and heatmap presentation.
- `Linkerworks/ManageView.swift`, `Linkerworks/NutritionView.swift`, `Linkerworks/WorkoutView.swift` -- management/logging lists and editor/form chrome aligned with the shared system.
- `STATE.md` -- implementation handoff and verification results.

## Tasks & Acceptance

**Execution:**

- [x] `Linkerworks/TrainingLogTheme.swift` -- add reusable flat-surface, divider, section-label, row, compact-action, and text-mode control treatments -- prevent per-screen visual drift.
- [x] `Linkerworks/ContentView.swift` -- recompose Today and More around compact headers, one clear summary, flat checklist rows, and the system primitives while retaining behavior.
- [x] `Linkerworks/CalendarPlanView.swift` -- replace the segmented pill/tiled month/competing controls with quiet text mode tabs, a flat calendar, compact context navigation, and a clean agenda/editor hierarchy.
- [x] `Linkerworks/TrackersView.swift` and `Linkerworks/StreaksView.swift` -- make Log and Progress information-first with clear section rhythm, flat action rows, restrained summaries, and readable data grids.
- [x] `Linkerworks/ManageView.swift`, `Linkerworks/NutritionView.swift`, and `Linkerworks/WorkoutView.swift` -- apply the system to management/logging rows and forms without changing operations, reorder behavior, or validation.
- [x] `STATE.md` -- append a factual redesign handoff, changed paths, preservation statement, and runtime verification status.

**Acceptance Criteria:**

- Given any tab, when opened, then it uses the shared dark flat hierarchy, readable type scale, hairline grouping, and compact native actions without changing its destination or business behavior.
- Given Plan in Month, Week, or Day mode, when the user navigates or selects a date, then the event data/agenda behavior stays intact while the calendar has plain cells, quiet event dots, a compact active mode, and no oversized circular/pill controls or day tiles.
- Given a user opens a task, event, meal, workout, tracker, or management screen, when they use its existing actions, then data entry, persistence, validation, reordering, and deletion semantics are unchanged and the surface follows the redesign system.
- Given Dynamic Type, VoiceOver, or Reduce Motion, when the redesigned UI is used, then essential content remains readable and operable, state has a non-color cue, and nonessential animation does not block the task.

## Design Notes

This is a visual/system redesign, not an information-architecture rewrite. The most visible correction is Plan: date cells become unfilled typography; selection is the only filled date; event presence is a dot; Month/Week/Day becomes an inline text control; and creation stays in the native toolbar. Across the app, replace broad fills with alignment and dividers, keep one dominant piece of information per block, and use green only where actual progress/completion occurs.

## Verification

**Commands:**

- `swiftc -parse Linkerworks/*.swift` -- expected: all app sources parse.
- `git diff --check` -- expected: no whitespace errors.

**Manual checks (if Xcode is available):**

- Inspect every tab, editor, empty state, navigation sheet, large Dynamic Type setting, and VoiceOver labels. Create/edit/delete an event; complete a task; add/edit a meal and workout; reorder a task/set; and confirm no existing data or workflow changed.
