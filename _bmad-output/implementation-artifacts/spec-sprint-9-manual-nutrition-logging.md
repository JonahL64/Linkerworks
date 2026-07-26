---
title: 'Sprint 9 manual nutrition logging'
type: 'feature'
created: '2026-07-22'
status: 'done'
review_loop_iteration: 0
baseline_commit: '85e3e6af6428116eba791c3e24e253d0a4945868'
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/STATE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The Log area shows Eating checklist history and reference material but cannot record what was actually eaten or track daily nutrition. Re-entering frequent meals should not require retyping their macros.

**Approach:** Add a first-class Nutrition destination from Log, backed by additive App Group SwiftData models for dated meal entries, one editable macro target configuration, and reusable saved-meal presets. It provides date navigation, grouped manual entries, daily totals and remaining/over amounts while retaining the current Eating tracker intact.

## Boundaries & Constraints

**Always:** Preserve task, calendar-placeholder, Log, Progress, Manage Routine, widget, App Group, and seed-import behavior. Persist Nutrition data in the existing shared store. Nutrition opens as the clear first action from Log; Eating checklist/reference content remains reachable. Meal categories are Breakfast, Lunch, Dinner, Snack, and Other. A saved meal must be reusable to prefill a new entry and must not couple or mutate past meal entries.

**Ask First:** Changing the seed JSON, widget code, App Group identifier/configuration, navigation tab count, or unrelated existing tracker behavior.

**Never:** Add food databases, barcode scanning, nutrition APIs, AI estimation, HealthKit, cloud sync, notifications, third-party packages, or workout logging.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Date logging | User chooses any date and saves a valid manual meal | Entry persists for that calendar day, appears in its category, and updates that day’s totals | Required name and nonnegative numeric values prevent saving invalid input |
| Daily totals | Recorded totals are below, equal to, or above a target | Each nutrient displays remaining, met, or over amount accurately | Zero target remains legible and avoids division/negative-progress errors |
| Reusable meal | User saves an entry as a meal preset, then selects it for a later date | New-entry fields prefill from preset; saving creates an independent dated entry | Updating/deleting an entry does not alter a preset or historical entries |
| Existing data | User opens Log or Eating after upgrade | Nutrition is prominent; Eating checklist history, weekday target reference, and source reference remain available | No seed re-import or task/completion mutation occurs |

</frozen-after-approval>

## Code Map

- `Linkerworks/Models.swift` — existing shared SwiftData entities; add meal entry, target configuration, and saved-meal models/category type.
- `Linkerworks/SharedModelContainer.swift` — explicit shared schema used by app and future widget work.
- `Linkerworks/TrackersView.swift` — Log root and existing Eating detail; add the prominent Nutrition route without removing Eating content.
- `Linkerworks/NutritionView.swift` — new date-scoped nutrition summary, grouped entries, target editor, and entry/preset editing UI.
- `STATE.md` — Sprint 9 handoff and honest verification status.

## Tasks & Acceptance

**Execution:**

- [x] `Linkerworks/Models.swift` — add persistent `MealEntry`, singleton-keyed `DailyMacroTarget`, and independent reusable meal preset models, including category and all calories/macro/fiber fields.
- [x] `Linkerworks/SharedModelContainer.swift` — include the new entities in the existing App Group SwiftData schema without changing its location or seed path.
- [x] `Linkerworks/NutritionView.swift` — implement date selection, target totals/remaining-over display, category sections, add/edit/delete flows, and saved-meal prefilling/saving using the themed SwiftUI conventions.
- [x] `Linkerworks/TrackersView.swift` — make Nutrition the first, visibly primary Log action and keep all six tracker links and Eating content available.
- [x] `STATE.md` — append 5–10 factual Sprint 9 lines describing changed paths and verification limits.

**Acceptance Criteria:**

- Given the Log tab, when it opens, then Nutrition is the clear first action and the existing six tracker destinations remain present.
- Given a Nutrition date, when entries are added, edited, or deleted, then only that date’s grouped list and totals change and the records survive relaunch.
- Given entries totaling more than a target, when the summary renders, then it identifies the nutrient amount as over rather than a negative remaining value.
- Given a saved meal, when it is selected while composing an entry, then category, name, and macros are preloaded; later edits are independent records.
- Given the existing Eating tracker, when it is opened, then its task completion history, weekday target reference, and imported reference content remain intact.

## Design Notes

The single target configuration initializes from the established nutrition defaults (4,005 kcal; 150g protein; 525g carbohydrates; 145g fat; 40g fiber) only when no target exists, then becomes the local source of truth. Entry totals use calendar-day comparisons rather than equality of timestamps. Saved meals are a lightweight user-created preset library, not a food database.

## Verification

**Commands:**

- `swiftc -parse Linkerworks/*.swift` — expected: all app sources parse.
- `git diff --check` — expected: no whitespace errors.

**Manual checks (if Xcode is available):**

- Launch against an existing store; add, edit, delete, reuse, and save a meal on today and another date; edit targets; verify grouped totals/over states and unchanged Eating tracker content.

## Suggested Review Order

**Log entry point**

- Makes Nutrition the first action while retaining every domain tracker.
  [`TrackersView.swift:8`](../../Linkerworks/TrackersView.swift#L8)

**Date-scoped nutrition workflow**

- Coordinates date selection, summaries, grouping, editors, and durable saves.
  [`NutritionView.swift:4`](../../Linkerworks/NutritionView.swift#L4)

- Handles grouped entries, independent presets, and rollback on write failure.
  [`NutritionView.swift:103`](../../Linkerworks/NutritionView.swift#L103)

- Prefills new entries from presets while allowing correction of a meal's day.
  [`NutritionView.swift:259`](../../Linkerworks/NutritionView.swift#L259)

- Keeps daily totals safe for unusually large manual values.
  [`NutritionView.swift:531`](../../Linkerworks/NutritionView.swift#L531)

**Shared persistence**

- Defines normalized dated meals, singleton targets, and independent reusable meals.
  [`Models.swift:170`](../../Linkerworks/Models.swift#L170)

- Extends the existing App Group schema without moving its store.
  [`SharedModelContainer.swift:8`](../../Linkerworks/SharedModelContainer.swift#L8)

**Handoff and verification**

- Records scope, preservation guarantees, and the remaining runtime verification gap.
  [`STATE.md:86`](../../STATE.md#L86)
