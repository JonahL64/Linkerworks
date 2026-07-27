---
title: 'Weight tracker and macro entry'
type: 'feature'
created: '2026-07-27'
status: 'done'
review_loop_iteration: 0
baseline_commit: '2466f0b103f03797bcd43a68f3db183394e47f09'
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/STATE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Linkerworks has nutrition and workout logging, but no way to record body weight or see its change over time. New-meal detailed macro fields contain a literal zero, so typing a value appends to it instead of replacing it.

**Approach:** Add a dedicated Weight destination in Log with one manual pounds entry per calendar day, editable history, and an accessible Paper & Ink line graph. Make the detailed new-meal macros treat their initial zero as a replaceable default while retaining valid zero values.

## Boundaries & Constraints

**Always:** Persist weight entries in the existing App Group SwiftData store; normalize each entry to its selected calendar day; keep one entry per day by updating that day’s existing record; preserve the existing meal, routine, workout, progress, and widget behavior; use iOS 17 built-in Swift Charts and existing `LW*` tokens only; keep graph and controls accessible.

**Ask First:** Adding unit conversion/preferences, HealthKit integration, goals/coaching, imported scale data, or changing the navigation structure beyond a Log destination.

**Never:** Add networking, accounts, third-party dependencies, notification behavior, or alter historical completion records.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| First weight | A valid positive pounds value and selected date with no record | One normalized-day entry saves and immediately appears in history and graph | Reject blank, nonnumeric, or nonpositive values without saving |
| Same-day correction | A valid value for a date already logged | The existing record is updated; history/graph show one point for that day | Preserve the record identity and show a save failure if persistence fails |
| Sparse history | Fewer than two dated entries or gaps between entries | Show the logged point(s), an explanatory empty/insufficient-history state as appropriate, and no fabricated values | The screen remains usable for add/edit/delete |
| New meal details | Protein/carbohydrate/fat/fiber default value is zero and the user starts typing | The first entered digit replaces the default zero rather than creating a leading-zero value | A deliberately entered or retained zero still saves as zero |

</frozen-after-approval>

## Code Map

- `Linkerworks/Models.swift` -- SwiftData model families and date-normalized persistence conventions.
- `Linkerworks/SharedModelContainer.swift` -- the App Group schema registration point.
- `Linkerworks/TrackersView.swift` -- Log root destinations.
- `Linkerworks/NutritionView.swift` -- meal entry editor and detailed macro fields.
- `Linkerworks/WeightView.swift` -- new dedicated weight history, editor, and graph screen.
- `LinkerworksTests/WeightTrackerTests.swift` -- focused date/upsert/projection coverage.

## Tasks & Acceptance

**Execution:**

- [x] `Linkerworks/Models.swift` -- add a `WeightEntry` SwiftData model and small deterministic support helpers for normalized dates, ordered history, and one-record-per-day lookup.
- [x] `Linkerworks/SharedModelContainer.swift` -- register `WeightEntry` in the existing shared schema so the app and its App Group store can migrate it.
- [x] `Linkerworks/WeightView.swift` -- build the Log-reachable manual pounds tracker: current/add entry action, date and value editor, edit/delete history, a token-styled Swift Charts line/point graph of recorded history, and truthful empty/insufficient-history states.
- [x] `Linkerworks/TrackersView.swift` -- add Weight as a first-level Log destination without removing or moving existing destinations.
- [x] `Linkerworks/NutritionView.swift` -- make the four detailed new-meal macro defaults replace on initial entry, while preserving validation and intentional zero macros for new and edited meals.
- [x] `LinkerworksTests/WeightTrackerTests.swift` -- cover day normalization, same-day upsert selection, deterministic graph ordering, and no fabricated history points.

**Acceptance Criteria:**

- Given the user opens Log, when they choose Weight, then they can save, edit, and delete dated pounds entries and only one record represents each calendar day.
- Given two or more weight records, when the tracker displays, then its graph plots their chronological actual values with metrics readable using the app’s typography and VoiceOver context.
- Given no records or only one record, when the tracker displays, then it explains the state without drawing an invented trend.
- Given a new meal’s expanded Details fields begin at zero, when the user types a macro amount, then the value is entered without a leading default zero; intentional zeros still pass current validation.
- Given existing nutrition, workout, routine, progress, and widget flows, when the feature is added, then their models and displayed behavior are unchanged.

## Design Notes

Use pounds for this focused first release; entries are stored as a `Double` in that displayed unit. The tracker belongs beside Nutrition in Log rather than inside the nutrition meal screen, because it is a recurring body metric with its own history. The graph must use `LWColor.accent` for the line and markers, never the completion-only success token.

## Verification

**Commands:**

- `swiftc -parse Linkerworks/*.swift LinkerworksTests/*.swift` -- expected: all changed app/test source parses.
- `git diff --check` -- expected: no whitespace errors.

**Manual checks (if no CLI):**

- In Xcode, migrate an existing App Group store, add/correct/delete same-day and historical weights, inspect empty/one/multiple-point graph states, and enter 25 into each default detailed macro field to verify it becomes 25 rather than 025.

## Suggested Review Order

**Entry and experience**

- The Log destination keeps weight discoverable without changing the primary tab structure.
  [TrackersView.swift:30](../../../Linkerworks/TrackersView.swift#L30)

- This screen owns daily entry, history, accessible charts, and truthful sparse-data states.
  [WeightView.swift:6](../../../Linkerworks/WeightView.swift#L6)

**Data integrity**

- Stable, unique day keys preserve one weigh-in per intended calendar day across time zones.
  [Models.swift:619](../../../Linkerworks/Models.swift#L619)

- Same-day corrections update one record and remove any legacy duplicate safely.
  [WeightView.swift:190](../../../Linkerworks/WeightView.swift#L190)

- Charts display actual dated entries only and expose an equivalent accessible summary.
  [WeightView.swift:236](../../../Linkerworks/WeightView.swift#L236)

**Nutrition input repair**

- New detailed macro fields strip only the initial default zero on first numeric entry.
  [NutritionView.swift:669](../../../Linkerworks/NutritionView.swift#L669)

**Verification**

- Focused tests cover normalization, ordering, deterministic lookup, and timezone-stable day identity.
  [WeightTrackerTests.swift:14](../../../LinkerworksTests/WeightTrackerTests.swift#L14)
