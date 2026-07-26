---
title: 'Sprint 5 certifications'
type: 'feature'
created: '2026-07-25'
status: 'done'
review_loop_iteration: 0
baseline_commit: 'NO_VCS'
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/STATE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-Linkerworks-2026-07-24/DESIGN.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Certifications need a focused planning and review surface without inventing a second way to record study. The existing routine task and `CompletionRecord` history must remain the sole source for study activity, streaks, and heatmap data.

**Approach:** Add Certifications as a normal task domain, persist certificates and ordered milestones in the existing shared SwiftData store, and layer certificate metadata and detail views above the existing generic domain-tracker body. Derive exam calendar markers and study totals from certification data and completion history.

## Boundaries & Constraints

**Always:** Use the App Group SwiftData container; add the specified `Certification` and `CertMilestone` models to its schema so SwiftData migrates the existing store without discarding data. A linked task remains an ordinary `TaskItem` in the Certifications domain; its completions, skips, snapshots, streaks, and heatmap use the current shared logic unchanged. Archive routine tasks rather than deleting them. Keep the existing dark flat-list visual language.

**Ask First:** A manual/custom migration that changes or deletes existing stored records, notifications, cloud/networking, calendar event creation, or a separate study-completion data path.

**Never:** Store exam dates as `CalendarEvent`s, create duplicate completion/streak/heatmap logic, fork the generic domain tracker renderer, add reference seed data, or special-case Certifications in historical progress calculations.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Create and link | A user creates a Certifications-domain routine task and a certificate | Certificate editor selects that task; its normal completion records immediately power the detail's rolling 30-day count and the shared tracker history | Save failure leaves the editor open with retained values and a plain error |
| No exam date/task | `targetDate` and/or `linkedTaskID` is nil | Detail omits countdown or says no linked study task; generic tracker still shows all domain tasks/history | No crash or synthetic records |
| Expiring credential | `expiresOn` is today through 90 days away | Every certificate list/header row persistently shows an amber expiry line; dates beyond 90 days and nil dates do not | Date-only calculation handles local-day boundaries |
| Exam month | A certification target date is in the displayed Plan month | Its day receives a read-only certification marker in addition to existing event/assignment markers | Multiple certificates do not create events or hide other markers |

</frozen-after-approval>

## Code Map

- `Linkerworks/Domain.swift` -- `Domain` cases/display metadata and common task-domain routing.
- `Linkerworks/Models.swift` -- SwiftData model definitions and relationship conventions.
- `Linkerworks/SharedModelContainer.swift` -- shared schema used by the app and existing App Group store.
- `Linkerworks/TrackersView.swift` -- Log root and the current generic `DomainTrackerView` body/history renderer.
- `Linkerworks/CertificationViews.swift` -- new certification list, editor/detail, milestones, and a wrapper that composes the generic domain-tracker body.
- `Linkerworks/CalendarPlanView.swift` -- month-cell marker composition for derived exam dates.
- `LinkerworksTests/CertificationTests.swift` -- focused pure-date and completion-window behavior where the current test target allows it.

## Tasks & Acceptance

**Execution:**
- [x] `Domain.swift` -- add `.certifications` with display name and an SF Symbol; rely on `CaseIterable` so Manage's picker and Log's filtered tracker list include it without per-screen exceptions.
- [x] `Models.swift` and `SharedModelContainer.swift` -- add `Certification` (unique ID, optional dates/task ID/notes, status string) and cascade-owned `CertMilestone` (title, done state/date, order), constructors consistent with existing models, and both schema registrations for additive SwiftData migration.
- [x] `TrackersView.swift` -- expose the existing generic domain tracker and compose the certification header above its unchanged history/reference body.
- [x] `CertificationViews.swift` -- add certificate creation/editing, ordered milestone checklist, status picker, linked routine-task selector limited to Certifications tasks, optional notes/dates, certificate rows/header countdown and `done of total`, expiry warning, and detail's 30-day linked-task complete-record count.
- [x] `CalendarPlanView.swift` -- query certifications and add a distinct read-only exam-date marker to `CalendarDayCell`; derive it directly from `targetDate` and preserve existing event and homework markers.
- [x] `LinkerworksTests/CertificationTests.swift` -- cover expiry-window inclusivity, target-date countdown/no-date behavior, milestone count, and a linked task's 30-day count using only complete `CompletionRecord`s.
- [x] `STATE.md` -- append delivered files, shared-completion invariant, validation results, migration/runtime verification status, and unresolved issues.

**Acceptance Criteria:**
- Given Manage Routine, when a user creates a task, then Certifications appears in the domain picker and saving it follows ordinary task/history behavior.
- Given Log, when the user opens Certifications, then its header lists certificates and its tracker section is the existing generic domain history/reference output, not a parallel renderer.
- Given a linked task's completion history, when its certification detail and Progress heatmap are viewed, then both report the same underlying task records and no certification completion can be toggled independently.
- Given a certification has milestones, when a milestone is checked, then its completion timestamp is set; when unchecked, it is cleared; progress is deterministic by stored order.
- Given an exam date, when Plan shows that month, then its cell displays a noninteractive exam marker without a stored `CalendarEvent`.
- Given `expiresOn` is within 90 calendar days inclusive, when certificates are listed, then an amber expiry line remains visible.

## Design Notes

The generic domain tracker should expose an optional leading content slot (or a wrapper around its existing body), so Certification header rows are composed immediately before the identical `completionHistory`/reference sections. Certification-specific UI owns only metadata and milestones; task completion lookup filters `CompletionRecord.state == .complete`, matches `linkedTaskID`, and compares normalized record dates against the trailing 30 calendar days.

## Verification

**Commands:**
- `swiftc -parse Linkerworks/*.swift` -- expected: all app sources parse.
- `swiftc -parse LinkerworksTests/*.swift` -- expected: focused tests parse where Swift toolchain is available.
- `git diff --check` -- expected: no whitespace errors.

**Manual checks (if no CLI):**
- In Xcode/device or Simulator, migrate an existing populated App Group store; create and link a Certifications task/certificate in under a minute; complete the routine task across dates; compare certification detail, tracker history, and Progress heatmap; toggle milestones/status/notes; inspect Plan's derived marker and 90-day expiry line.

## Suggested Review Order

**Tracker composition and routine-history invariant**

- Certifications adds only a leading metadata section to the shared tracker body.
  [`TrackersView.swift:79`](../../Linkerworks/TrackersView.swift#L79)

- This wrapper keeps study activity in ordinary task and completion-record queries.
  [`CertificationViews.swift:29`](../../Linkerworks/CertificationViews.swift#L29)

- Detail reads the linked task's trailing completion history and persists milestones safely.
  [`CertificationViews.swift:85`](../../Linkerworks/CertificationViews.swift#L85)

**Shared-store migration and domain propagation**

- The enum addition automatically feeds the existing picker and root tracker list.
  [`Domain.swift:4`](../../Linkerworks/Domain.swift#L4)

- Certification metadata and cascade-owned milestones are additive SwiftData models.
  [`Models.swift:296`](../../Linkerworks/Models.swift#L296)

- Both new models enter the existing App Group container schema.
  [`SharedModelContainer.swift:8`](../../Linkerworks/SharedModelContainer.swift#L8)

**Derived planning signal**

- Plan queries target dates directly and passes a read-only exam marker to month cells.
  [`CalendarPlanView.swift:134`](../../Linkerworks/CalendarPlanView.swift#L134)

**Focused behavior coverage**

- Date windows and complete-only rolling counts are specified in focused regression tests.
  [`CertificationTests.swift:7`](../../LinkerworksTests/CertificationTests.swift#L7)
