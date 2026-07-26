# STATE.md — session handoff log

Sprint 0 completed. Repo contains: AGENTS.md, SPRINT_PLAN.md, data/schedule.json, data/reference.json.

Sprint 1 data layer completed: SwiftData models live in `Linkerworks/Models.swift` and domains in `Linkerworks/Domain.swift`.
Created `Linkerworks/SharedModelContainer.swift` and `Linkerworks/SeedImporter.swift`; replaced the template `Item` model.
The App Group identifier is exactly `group.com.jonah.linkerworks`; the app entitlement contains only that identifier.
The store path is `<group.com.jonah.linkerworks container>/Library/Application Support/Linkerworks.store` (the OS assigns the container UUID at install time).
Both root seed files are app-target resources through the synchronized `data` group in `Linkerworks.xcodeproj/project.pbxproj`.
First-launch import uses shared UserDefaults key `seedImportVersion`; it sets version 1 only after the SwiftData save succeeds.
Seed validation/import mapping succeeded: Saturday 27, Sunday 25, Monday 28, Tuesday 26, Wednesday 27, Thursday 27, Friday 26 top-level tasks.
All 29 lift sub-steps validated as children (Mon 7, Tue 7, Thu 8, Fri 7), and 10 reference tables map to the six domains.
Open verification issue: this machine has Command Line Tools only, not full Xcode/iOS Simulator, so the signed app's first-launch SwiftData run still needs confirmation in Xcode.

Sprint 2 changed `Linkerworks/ContentView.swift` and appended this handoff to `STATE.md`; no new app files were created and no widget files were touched.
Today's `DaySchedule` is selected from `Calendar.current.weekday`; its sections and top-level tasks sort by their stored `sortOrder` values.
Lift sub-steps render only from each parent task's `children` relationship, indented under that parent, and retain their own independent toggle.
Toggling writes or deletes `CompletionRecord`s matched by `taskId` and `Calendar.current.isDate(_:inSameDayAs:)`; new records normalize to that day's start via the existing model initializer.
The progress ring counts only today's completed top-level task records. A parent lift task is complete only when its own record exists; child records never auto-change a parent or ring progress.
Validation completed: `swiftc -parse` passes for all app Swift sources and `git diff --check` passes.
Simulator validation remains blocked on this machine because full Xcode/`simctl` is not installed; checking/unchecking across a day boundary must be run in Xcode before sign-off.

Sprint 3 added `Linkerworks/ManageView.swift` and changed `Linkerworks/ContentView.swift` to host the Manage tab; no Streaks, Trackers, widget, or Today logic was changed.
Manage lists only top-level TaskItems by existing weekday/section, with Active and Archived filters, an Add button, task editor, and inline Lifting sub-step drafts/editing.
Add/edit persist title, optional time, detail, existing section, domain, non-empty multi-day assignment, and default new tasks to the end of their selected section.
Drag reordering is scoped to active tasks in one section and writes sequential `sortOrder` values before saving.
All TaskItem removal actions set `isArchived = true` (parents also archive children); no Manage path calls `modelContext.delete`, and archived task rows are reachable through the Archived filter.
Changing `daysOfWeek` only assigns the TaskItem field; the editor neither queries nor mutates CompletionRecord, preserving existing completion history by task ID.
`swiftc -parse` and `git diff --check` pass, but full Xcode/Simulator are unavailable (Command Line Tools only), so build/run and the requested hands-on add/edit/archive/reorder/history checks still require verification in Xcode.

Sprint 4 added `Linkerworks/StreaksView.swift` and changed `Linkerworks/ContentView.swift` to host the Streaks tab; Today, Trackers, Manage, and widget code were not changed.
The tab reads TaskItem and CompletionRecord only, displays current and longest streaks, a current-month `LazyVGrid` heatmap, and calendar-week completion rollups through today.
A day is complete only when every current, non-archived, top-level (not substep/no parent) TaskItem whose current `daysOfWeek` includes that weekday has a CompletionRecord for that date.
The current streak ends yesterday: today is intentionally excluded while in progress, so it cannot yet start or break the displayed current streak; the longest streak can include today once all of its scheduled tasks are checked.
Days with zero scheduled qualifying tasks are ignored in both streak calculations: they neither increment nor break a run, show as unshaded heatmap cells, and add no denominator to weekly percentages.
Longest-streak history starts at the earliest CompletionRecord (there is no stored installation date) and evaluates each TaskItem's current weekday assignment; historical schedule reconstruction is intentionally out of scope.
`swiftc -parse Linkerworks/*.swift` and `git diff --check` pass. Full Xcode, `xcodebuild`, `simctl`, installed Simulator runtimes, and a local Linkerworks app-group store are absent on this machine, so the requested Linkerworks-scheme Simulator build/run and real-history visual sanity check could not be performed here.

Sprint 5 added `Linkerworks/TrackersView.swift` and changed `Linkerworks/ContentView.swift` to host the Trackers tab; Today, Streaks, Manage, and widget code were not changed.
All six domains are complete: Sleep, Eating, Goalkeeping, Lifting, Posture, and Grooming each have a domain detail view with TaskItem-derived completion history and reference content.
Task items are grouped by title with their scheduled days and aggregate CompletionRecord count; recorded completions list the resolved task title and timestamp.
Eating also displays all seven DaySchedule daily targets: calories, protein, fat, carbohydrates, and fiber; it adds no meal logging or macro estimation.
Raw reference rows decode dynamically: one-cell rows render as readable narrative/section labels, while multi-cell rows render as horizontally scrollable tables; this covers Sleep (2 columns), Eating/Lifting (5), Goalkeeping/Grooming tables (2–3), and Posture/Running narrative rows.
Grooming shows its four source sections independently: Brushing, Shaving, Skincare, and Small grooming; Lifting includes Working Out and Running.
`swiftc -parse Linkerworks/*.swift`, `git diff --check`, and a `jq` validation that all ten reference sources are arrays of row arrays pass.
Simulator verification remains unperformed: `xcodebuild` and `xcrun simctl` fail because this machine has Command Line Tools only, with no full Xcode or Simulator runtime, so a Linkerworks-scheme build/run and visible seeded-data confirmation cannot truthfully be claimed here.

Sprint 5 follow-up: marked `TaskEditorView` in `Linkerworks/ManageView.swift` as `@MainActor` so its `SubstepDraft(task:)` initialization can read SwiftData TaskItem properties under Swift 6 actor isolation; this is a compile-blocker repair only, with no behavior or UI change.

Sprint 6 implemented the home-screen and lock-screen accessory widget in `LinkerworksWidget/LinkerworksWidget.swift`; `LinkerworksWidget/LinkerworksWidgetBundle.swift` now ships only that widget.
Before widget code was changed, `LinkerworksWidgetExtension.entitlements` was checked and already exactly matched `Linkerworks/Linkerworks.entitlements`: both contain only `group.com.jonah.linkerworks` in all lowercase; there was no mismatch to fix.
`Linkerworks.xcodeproj/project.pbxproj` now compiles `Domain.swift`, `Models.swift`, and `SharedModelContainer.swift` directly into the widget target, so its TimelineProvider opens the same App Group SwiftData store as the app.
Progress uses non-archived top-level tasks and same-day parent CompletionRecords; the next item is the earliest incomplete task with a valid `HH:mm` time strictly later than now, with a day-complete state when none remains.
The widget supports `systemSmall`, `systemMedium`, `accessoryCircular`, and `accessoryRectangular`, and refreshes hourly or at midnight, whichever comes first.
`Linkerworks/ContentView.swift` changed only at the tab shell to handle `linkerworks://today`; Today, Streaks, Trackers, and Manage feature implementations were otherwise untouched.
The iOS 17 tap-to-check AppIntent stretch goal was not attempted or shipped; the stable tap behavior opens the Today tab.
Validation passed: Swift parsing for app/widget sources, plist/project linting, and `git diff --check`; the existing Simulator App Group SQLite store was inspected read-only and contains all seven schedules plus real TaskItem rows.
Actual home-screen/lock-screen widget verification was not performed and real data was not visually confirmed in the widget: this Mac currently has no Xcode app, `xcodebuild`, or `simctl`, despite a prior Simulator store remaining on disk.
Sprint 6 compile follow-up: qualified both widget preview timeline values as `LinkerworksWidgetEntry.placeholder`; unqualified `.placeholder` was incorrectly inferred as a member of the `TimelineEntry` protocol by Xcode.

Sprint 7 applied the shared dark athletic palette in `Linkerworks/TrainingLogTheme.swift` and asset color sets: background `#0E1210`, primary `#EDEFEC`, secondary `#7A857F`, and completion-only accent `#3ECF6E`.
`ContentView.swift`, `StreaksView.swift`, `TrackersView.swift`, and `ManageView.swift` now use flat near-black list/form/navigation/tab surfaces with explicit palette colors; source audit found no remaining default blue/system semantic color styling in the shipped tabs.
Today and Manage task times, Tracker history timestamps, and every widget time use `.monospacedDigit()`.
Today’s completion moment is a one-shot green ring pulse plus brief “DAY COMPLETE” label, triggered only after saving a check on the final remaining top-level task; it does not fire for substeps, ordinary task checks, or unchecks.
`Linkerworks/Assets.xcassets/AppIcon.appiconset/AppIcon.png` and `LinkerworksWidget/Assets.xcassets/AppIcon.appiconset/AppIcon.png` are new 1024px flat dark/green app-icon assets; both catalogs reference them.
`LinkerworksWidget/LinkerworksWidget.swift` now has the matching dark widget background, primary/secondary text, completion-only green progress/check states, and monospaced times; unshipped live-activity template colors were also neutralized.
Validation passed: `swiftc -parse` for all app/widget Swift sources, `git diff --check`, JSON parsing for every asset catalog manifest, and visual inspection of the generated raster icon.
Runtime verification is still blocked: this Mac has Command Line Tools only, so `xcodebuild`, `simctl`, and `devicectl` are unavailable; no iPhone was detected over USB. No device/Simulator build or in-app/widget visual inspection was run, and that remains the sole Sprint 7 sign-off gap.

Product-direction session only; no app source, model, project, or seed-data files were changed.
The agreed next scope is two separate future sprints: manual meal/macro logging, then workout session/set logging.
Both features must extend the existing App Group SwiftData store and preserve the current task/checklist workflows.
Deferred from these sprints: food lookup/scanning, HealthKit, routine builder, coaching, social, cloud, and notifications.
Recommended future navigation is intent-based: Today, Plan, Log, Progress, and More; specialist tools should live within these areas rather than become top-level tabs.
Forge artifacts are in `_bmad-output/forge/fitness-and-nutrition-log/`.

Sprint 8 reorganized the root navigation into exactly Today, Plan, Log, Progress, and More in `Linkerworks/ContentView.swift`.
Plan now opens on a themed Calendar placeholder and presents the existing `ManageView` unchanged from a prominent Manage Routine action.
Log hosts the unchanged domain/history/reference experience, with its root title changed in `Linkerworks/TrackersView.swift`.
Progress hosts the unchanged streak summary, heatmap, and rollups, with its root title changed in `Linkerworks/StreaksView.swift`.
More is a non-functional themed placeholder for future app-level settings and data tools; no routine manager was moved there.
No SwiftData models, App Group configuration, seed JSON, widgets, or existing feature behavior were modified for this sprint.
Validation passed: `swiftc -parse Linkerworks/*.swift` and `git diff --check`.
Runtime visual verification remains unavailable because this machine has Command Line Tools only, without full Xcode or a Simulator runtime.

Sprint 9 added manual Nutrition logging in `Linkerworks/NutritionView.swift`, reached as the first, emphasized action in the existing Log root (`Linkerworks/TrackersView.swift`).
The screen defaults to today, permits any date selection, groups manual entries by Breakfast, Lunch, Dinner, Snack, and Other, and supports add, edit, and delete actions.
`MealEntry` persists a normalized date, category, food name, calories, protein, carbohydrates, fat, fiber, timestamp, and sort order in `Linkerworks/Models.swift`.
`DailyMacroTarget` is a singleton-keyed, editable local configuration; its initial values match the existing 4,005 kcal / 150P / 525C / 145F / 40 fiber nutrition defaults.
`SavedMeal` stores user-created reusable macro presets; selecting one preloads a new independent entry, and entry deletion or editing never mutates a preset or historical meal record.
`Linkerworks/SharedModelContainer.swift` now includes these three models in the established App Group SwiftData schema; seed JSON/import and widget code were not changed.
The existing Eating tracker remains available with its checklist completion history, weekday target reference, and imported Eating reference content intact.
Validation passed: `swiftc -parse Linkerworks/*.swift` and `git diff --check`; full Xcode/Simulator build and hands-on persistence/UI testing remain unavailable because this machine has Command Line Tools only.

Sprint 10 added workout session and set logging through the new `Linkerworks/WorkoutView.swift`, reached as the clear first action in the existing Log root.
`WorkoutSession`, `WorkoutExercise`, and `WorkoutSet` in `Linkerworks/Models.swift` persist state/timestamps, optional workout title/notes and load, reps, completion, and integer order with cascading session-to-exercise-to-set relationships.
`Linkerworks/SharedModelContainer.swift` registers those models in the existing App Group SwiftData schema; no store location, seed importer, seed JSON, or widget code changed.
Workout enforces one persisted in-progress session and resumes it after relaunch; it supports editable details, exercise add/rename/reorder/delete, and set add/edit/complete/uncomplete/reorder/delete.
Finishing sets a completed state and finish timestamp without deleting the workout; completed sessions retain their exercise/set records in a detailed history list.
The Lifting tracker remains reachable in Log and its existing checklist completion history and imported reference content were not changed.
Validation passed: `swiftc -parse Linkerworks/*.swift` and `git diff --check`.
Runtime verification remains unavailable on this machine because full Xcode/Simulator tooling is not installed; start/resume, SwiftData migration/persistence, reorder gestures, and visual checks require an Xcode/device run.

Sprint 10 compile repair corrected two Xcode diagnostics in `Linkerworks/WorkoutView.swift` without changing workout behavior or data models.
`isWorkoutInProgress` now belongs to `WorkoutExerciseView`, the only scope that uses its read-only guards for sets and exercise edits.
The workout-details form now uses SwiftUI's explicit `Section` content/header/footer closure initializer, resolving generic inference in Xcode.
`swiftc -parse Linkerworks/*.swift` and `git diff --check` pass after the repair.
An independent source review found no additional issue caused by these corrections.
Full Xcode compilation and device/Simulator interaction verification remain unavailable on this machine.

Calendar planning session only; no app source, data model, project, seed, or widget files changed.
`CALENDAR_SPRINT_PLAN.md` defines Sprint 11: local CalendarEvent persistence in the existing App Group SwiftData store, a navigable Plan month grid, selectable day agenda, and week/day views.
It scopes event fields to title, date, all-day or start/end time, and notes, with create/edit/delete and invalid time-range validation.
Routine management stays reachable from Plan; it is deliberately separate from events.
Deferred: recurrence, reminders, EventKit/external sync, invitations, locations, cloud, and calendar widget content.
`SPRINT_PLAN.md` now includes a compact Sprint 11 entry that links to the detailed plan.

UI redesign: finalized design and experience spines are in `_bmad-output/planning-artifacts/ux-designs/ux-Linkerworks-2026-07-24/`.
`TrainingLogTheme.swift` now supplies the shared flat-surface hierarchy, hairlines, text section labels, row rhythm, and compact text-tab/filter controls.
`CalendarPlanView.swift` removes the segmented pill and per-day dark tiles: Month/Week/Day are inline text tabs, calendar cells are plain except selection/today/event markers, and Manage Routine is a quiet text action.
`ContentView.swift`, `TrackersView.swift`, and `StreaksView.swift` now favor compact summaries, flat rows, and typography-led sections; More is a quiet list rather than an oversized placeholder.
`ManageView.swift`, `NutritionView.swift`, and `WorkoutView.swift` receive the shared control/row treatment; their persistence, validation, editing, deletion, and reordering logic is unchanged.
No model, seed, App Group, widget, tab-routing, or feature behavior changed. `swiftc -parse Linkerworks/*.swift` and `git diff --check` pass.
Runtime visual/accessibility verification still requires a full Xcode/device or Simulator run; this host’s active developer path is Command Line Tools.

Sprint 11 replaced the Plan placeholder with `CalendarPlanView.swift`: a navigable month grid, selectable date agenda, and independently navigable week/day agendas.
`CalendarEvent` in `Models.swift` persists an independent title, normalized date, optional time range, all-day state, notes, timestamps, and sort order; it is registered in `SharedModelContainer.swift`'s existing App Group schema.
Plan creates, edits, and confirmation-deletes events. Event editor rejects a blank title or end time earlier than start; equal times and a start-only timed event are valid.
Month cells signal event-bearing days; all-day events sort before timed events, with time, sort order, creation time, and ID as deterministic ties.
`ContentView.swift` now hosts the calendar Plan view and retains its unchanged Manage Routine sheet route.
No seed, task/completion, nutrition, workout, tracker, navigation, entitlement, store-location, or widget behavior was changed.
`swiftc -parse Linkerworks/*.swift` and `git diff --check` pass. Full typecheck/device verification remains unavailable because the installed Command Line Tools lacks SwiftData macro support and full Xcode/Simulator tooling.

Usability audit only; no app source, model, project, or seed-data files were changed.
Reviewed the live interaction paths in `ContentView.swift`, `CalendarPlanView.swift`, `ManageView.swift`, `NutritionView.swift`, `WorkoutView.swift`, `TrackersView.swift`, and `StreaksView.swift`.
The primary friction pattern is repeated full-form entry for common actions: meals, workout sets, routine tasks, and calendar items all ask for configuration that is normally stable.
Recommended direction: make the common path one tap or one short inline edit, while keeping the existing full editors as secondary “More details” routes.
The next product decision should be a focused simplification sprint rather than additional features; it can preserve the existing App Group models and history guarantees.
Runtime usability testing remains outstanding because this host has no Xcode/Simulator; findings are based on the implemented flows and UI structure.

Full usability simplification updated `NutritionView.swift`, `WorkoutView.swift`, `ManageView.swift`, `ContentView.swift`, `CalendarPlanView.swift`, `TrackersView.swift`, `StreaksView.swift`, `Domain.swift`, and the widget's shared completion calculation; no schema, seed, or persisted-history changes were made.
Nutrition now quick-logs visible saved meals and lets recorded meals become deduplicated favorites; its custom form reveals date/category/macros only in Details and keeps Eating reference inside Nutrition.
Workout creation now saves a session only with its named first exercise, repeated sets clone the immediately previous set directly, and Lifting reference remains inside Workout.
Routine section day is authoritative with optional extra days; time, detail, domain, and substep details are progressive, while task edits continue to leave CompletionRecords untouched.
Lift parents with children are display-only summaries; effective completion is child-derived once child records exist, with legacy parent-only records preserved as a fallback for old history.
Plan is now month plus its selected-day agenda, with progressive event time/notes; Log omits duplicate Eating/Lifting routes, navigation has Today/Plan/Log/Progress only, and Progress shows one current-week summary.
Validation passed: `swiftc -parse Linkerworks/*.swift LinkerworksWidget/*.swift` and `git diff --check`; full Xcode/device or Simulator behavior checks remain unavailable because this host only has Command Line Tools.

Workout start compile repair changed only `Linkerworks/WorkoutView.swift`.
`StartWorkoutEditorView` now uses SwiftUI's explicit Section content/header/footer closures.
This resolves Xcode's generic `Content` inference error at the prior `Section("First Exercise")` call.
The visible First Exercise label, input, and explanatory footer are unchanged.
Validation passed: `swiftc -parse Linkerworks/WorkoutView.swift` and `git diff --check`.
No model, persistence, workflow, widget, or navigation behavior changed.

Today/widget simplification changed `Linkerworks/ContentView.swift` and `LinkerworksWidget/LinkerworksWidget.swift` only.
Today task rows now display title and detail without an inline scheduled time.
All widget families now prioritize the next incomplete task title, without a time or progress count.
Widget task selection follows Today’s weekday assignment, including optional extra days and untimed tasks.
Today completion saves request an immediate widget timeline reload so the next task stays current.
Validation passed: `swiftc -parse Linkerworks/ContentView.swift LinkerworksWidget/LinkerworksWidget.swift` and `git diff --check`.

Documentation review only; no product source, project, seed, or asset files were changed.
Inspected the four current tabs and all reachable feature screens: Today, Plan/Calendar/Manage, Log/Nutrition/Workout/domain trackers, and Progress/Streaks.
Confirmed the shared App Group SwiftData store, first-launch seeds, widget deep link, and all persisted model families from source.
Noted an implementation/planning mismatch: the calendar currently ships month + selected-day agenda only, not the planned Week/Day views.
Noted verification constraints for future review: no automated test targets and no full Xcode/Simulator runtime validation recorded on this host.

Sprint 1 Today ergonomics changed `Linkerworks/ContentView.swift` and appended this handoff; no model, navigation, seed, project, or widget-layout files changed.
Today now auto-collapses fully complete sections, supports manual header expansion, shows monospaced section counts, and persists Hide completed with `@AppStorage`.
Rows render valid strict `HH:mm` schedule values at the trailing edge and show one muted Now divider before visible upcoming work after a past timed task.
Lift parents batch-toggle their active children, use an exclusive long-press gesture to expose individual child controls, and retain legacy parent-only record compatibility through `TaskCompletion`.
All successful completion mutations reload the widget, trigger scoped haptics, and provide a five-second Undo that restores exact record IDs, dates, and timestamps.
Validation passed: `swiftc -parse Linkerworks/*.swift` and `git diff --check`.
Runtime behavior, persistence, haptic feel, and gesture interaction still require a full Xcode/device or Simulator run because this host has Command Line Tools only.

Today compile repair updated `Linkerworks/ContentView.swift` only.
`TodayView` is now `@MainActor`, allowing completion-record snapshots to read SwiftData properties under Swift 6 isolation.
Visible-task `flatMap` closures now explicitly return `[TaskItem]`, avoiding empty-array inference to `[Any]`.
The parent accessibility value is explicitly a SwiftUI `Text`, resolving the overloaded modifier call.
`swiftc -parse Linkerworks/*.swift` and `git diff --check` pass; full Xcode typecheck remains unavailable on this host.

Follow-up: parent-lift completion state now forms part of its accessibility label rather than using `accessibilityValue`.
This avoids Xcode's overloaded `accessibilityValue` ambiguity while retaining the same VoiceOver state announcement.

Historical Progress migration added `DaySnapshot` and immutable lift completion-unit metadata in `Linkerworks/Models.swift`, registered by `SharedModelContainer.swift`.
`Domain.swift` captures a day once, backfills record dates once with an App Group version marker after save, and supplies snapshot-based skip-aware progress calculations.
`LinkerworksApp.swift` runs backfill after seed import; `ContentView.swift` captures Today and adds skip/unskip swipe actions, muted skip rendering, and stateful Undo.
`StreaksView.swift` uses snapshots for historical heatmap, streak, and weekly data; `TrackersView.swift` labels skip history and the widget excludes skipped/completeness state appropriately.
Focused XCTest coverage is in `LinkerworksTests/HistoricalProgressTests.swift`, with a new `LinkerworksTests` target in the project.
Validation passed: Swift parse (app, widget, tests), project plist lint, and `git diff --check`; full `xcodebuild test`/SwiftData migration and UI verification remain blocked because this host only has Command Line Tools.

Review follow-up: the widget now treats fully skipped lift parents and all-skipped/unscheduled days as neutral rather than completed.
Backfill now fetches tasks and existing snapshot keys once, avoiding repeated full-store reads for every historical record day.
Historical snapshot reads tolerate duplicate completion-unit metadata, and focused tests cover later lift child archival/addition without reinterpreting a captured parent.

Streaks compile repair changed `Linkerworks/StreaksView.swift` only.
`HeatmapDayCell` now accepts `ProgressDayCompletion`, matching the snapshot-backed summary calculator.
The stale removed `DayCompletion` reference at the heatmap cell boundary is gone.
`swiftc -parse Linkerworks/StreaksView.swift Linkerworks/Domain.swift Linkerworks/Models.swift` and `git diff --check` pass.
Independent adversarial review found no issue in the one-line repair; full Xcode build remains unavailable on this host.

Sprint 3 Homework core added `Course` and `Assignment` SwiftData models in `Linkerworks/Models.swift`, registered in the existing App Group schema in `Linkerworks/SharedModelContainer.swift`.
`Linkerworks/HomeworkView.swift` provides Plan-reachable homework, course add/rename/color/reorder/archive management, course filters, grouped deterministic assignment rows, direct completion, swipe postponement/deletion, and progressive editor details.
`CalendarPlanView.swift` now has a Homework toolbar route; calendar events and Manage Routine remain unchanged.
Due date is a required model field; the UI represents no due date with an internal `Date.distantFuture` sentinel so no task/progress APIs are affected.
`LinkerworksTests/HomeworkCoreTests.swift` covers midnight bucketing, default 11:59 PM round-trip, and deterministic tie sorting.
Validation limitation: neither `swiftc`, `xcodebuild`, nor Git is installed on this Windows host; source-level review completed, but Xcode must run migration/tests and hands-on UI checks.

Sprint 4 Homework integration changed `CalendarPlanView.swift`, `ContentView.swift`, and `HomeworkView.swift`; no SwiftData schema or routine-progress code changed.
Plan month cells now show the existing circular event marker plus a separate horizontal assignment-due marker, and selected-day agendas append unfinished due assignments after deterministically sorted all-day/timed events.
Today now has a DUE TODAY strip above routine sections with the first three unfinished due assignments, overdue count, inline completion, and a header route to Homework.
Homework has Select mode with bulk mark-done, push-due-date-one-day, and course reassignment actions; its empty state now says “Nothing due. Enjoy it.”
`LinkerworksTests/HomeworkCoreTests.swift` includes a regression asserting byte-identical routine completion output with assignments present; assignments remain outside the ring, snapshots, streaks, and heatmap inputs.
Validation remains limited on this Windows host: `swiftc` and Git are unavailable, so full Xcode test/build and runtime interaction verification are still required.

Homework availability setting added in `Linkerworks/SettingsView.swift`, reached from the Today navigation bar’s gear icon.
The shared `@AppStorage("homeworkIntegrationEnabled")` flag defaults to enabled and preserves all stored Course/Assignment data when disabled.
When off, Homework is hidden from Today’s DUE TODAY strip and from Plan’s Homework shortcut, month markers, and selected-day agenda entries.
Routine task progress, snapshots, streaks, and heatmap behavior remain unchanged.
Full Xcode build and interaction verification are still required because this Windows host lacks Swift tooling.
`HomeworkCoreTests` now toggles `homeworkIntegrationEnabled` both off and on and asserts byte-identical routine completion output in each case; this covers the same routine-only input used by snapshots, streaks, and heatmap.

Sprint 5 Certifications added `.certifications` to `Linkerworks/Domain.swift`; CaseIterable now carries it through Manage Routine and Log without picker/list special cases.
`Linkerworks/Models.swift` defines additive SwiftData `Certification` and cascade-owned `CertMilestone` models, registered in the shared App Group schema by `Linkerworks/SharedModelContainer.swift`.
`Linkerworks/CertificationViews.swift` composes certificate rows above the un-forked `DomainTrackerView` body, with status/dates/notes, ordered milestones, linked Certifications-domain routine tasks, and a trailing-30-day complete-record count.
Certification study remains solely `CompletionRecord` data: no certification completion, streak, heatmap, snapshot, or tracker calculation was added or changed.
`Linkerworks/CalendarPlanView.swift` derives a noninteractive orange checkmark-seal marker directly from certification target dates; it never creates a CalendarEvent.
`LinkerworksTests/CertificationTests.swift` covers inclusive expiry, countdown/no-date, milestone progress, and complete-only rolling study counts.
Validation is blocked on this Windows host: `swiftc` and Git are unavailable, so Xcode must build the SwiftData migration, run tests, and verify the creation/linking, heatmap parity, and Plan marker UI.
Review follow-up: milestone add/toggle operations now roll back and show an error when SwiftData cannot save; rolling 30-day records normalize to local days before filtering.

Sprint 6 workout friction changed only `Linkerworks/ContentView.swift` and `Linkerworks/WorkoutView.swift`; no workout schema, App Group, widget, or finished-history code was changed.
Today now queries the existing persisted in-progress workout and pins a Resume banner with its title, live monospaced elapsed time, and total set count; it remains absent without an active session.
Workout start accepts an optional title and exposes Repeat Last Workout only for a non-empty title with a matching completed session; cloning preserves ordered exercise/set names, reps, and loads but creates every cloned set uncompleted.
Active exercise detail adds inline Reps -> Load keyboard submit chaining, validation that retains focus, a prominent repeated-completed-set action, and a visual-only rest timer derived from the latest completion timestamp.
Exercise headers show monospaced session volume as sets x reps x load, treating missing loads as zero; completing, quick-logging, and repeated-set creation refresh the timer source without persistence changes.
Completed workout detail remains display-only and all existing in-progress mutation guards remain in place; `WorkoutSession.inProgressKey` remains the sole one-active-session persistence invariant.
Validation passed: `swiftc -parse Linkerworks/ContentView.swift Linkerworks/WorkoutView.swift` and `git diff --check`.
Runtime verification remains required in Xcode/device or Simulator because this host cannot run the iOS app; confirm keyboard Return behavior, timer updates, resume after relaunch, clone state, and completed-history read-only behavior there.
