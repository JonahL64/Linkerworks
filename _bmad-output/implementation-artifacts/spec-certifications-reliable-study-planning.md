---
title: 'Certifications reliable study planning'
type: 'feature'
created: '2026-07-26'
status: 'done'
review_loop_iteration: 0
baseline_commit: '25baa34'
context:
  - '{project-root}/AGENTS.md'
  - '{project-root}/STATE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-sprint-5-certifications.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Certifications is unreliable to enter on its first attempt, and its linked-study picker can appear empty with no way to create the missing routine task. A certification test date only paints a month marker, leaving the Plan agenda empty instead of providing a usable calendar entry.

**Approach:** Make Certifications navigation and editor presentation have a single stable owner, expose active Certifications-domain routine tasks consistently, create one directly from the certification workflow when needed, and maintain an app-owned all-day calendar event for each certification exam date.

## Boundaries & Constraints

**Always:** Continue using the shared App Group SwiftData store; study remains ordinary `TaskItem` and `CompletionRecord` data. The existing-task picker must offer every active top-level routine task, while a newly created study task defaults to the Certifications domain; neither path may modify historical completion data. An automatic exam event must be all-day, use the current certification name and target date, update when either changes, and be removed when the date is cleared or the certification is removed. Only the event associated with that certification may be changed or deleted. Preserve manually created calendar events, milestones, progress, heatmap, tracker history, and current Paper & Ink tokens.

**Ask First:** Any migration that rewrites or deletes user-created calendar events; notifications, recurrence, EventKit sync, cloud/network changes, or an independent study-completion path.

**Never:** Reintroduce a second study log, create duplicate calendar events for a certification, delete/alter a task's `CompletionRecord`s, or change non-Certifications calendar/task behavior.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| First entry | User taps Certifications from Log | The tracker stays open on the first tap and Add certification can present once | Ignore a repeated tap while presentation/navigation is in flight |
| Existing link | Active top-level routine task exists | It appears in the linked-task picker and can be selected | Archived and substep tasks remain unavailable |
| New link | No suitable task exists or user chooses Add study task | A routine task is created and immediately selected for this certification | Retain editor values and show an error if saving either object fails |
| Set/change exam | Certification has a target date/name | Exactly one associated all-day Plan event appears with the date/name | Save failure rolls the certification/event mutation back together |
| Clear/remove exam | Date is cleared or certification is deleted | Only its associated automatic event is removed | Manual events and other certificates' events stay intact |

</frozen-after-approval>

## Code Map

- `Linkerworks/CertificationViews.swift` -- certification tracker routing, editor, linked-task selection, and persistence coordination.
- `Linkerworks/Models.swift` -- additive association between `Certification` and its app-owned calendar event.
- `Linkerworks/CalendarPlanView.swift` -- existing local event presentation; must show the synchronized exam item in the selected-day agenda.
- `Linkerworks/ManageView.swift` -- established active top-level routine-task creation rules to reuse for the inline certification path.
- `Linkerworks/SharedModelContainer.swift` -- App Group SwiftData schema registration if a supporting additive model is required.
- `LinkerworksTests/CertificationTests.swift` -- deterministic event/link helper coverage.

## Tasks & Acceptance

**Execution:**

- [x] `Linkerworks/CertificationViews.swift` -- give certification navigation/editor presentation stable, explicit ownership; repair the active top-level linked-task query across routine domains; add a focused Create study task action that saves a normal Certifications routine task and selects it before the certification save completes.
- [x] `Linkerworks/Models.swift` -- add a durable, certification-owned identifier/relationship for the automatic event so synchronization never relies on matching a mutable name/date.
- [x] `Linkerworks/CertificationViews.swift` -- on create/edit/delete, coordinate exam event create/update/removal with the certification mutation, preserving all unrelated events and rolling back failed saves.
- [x] `Linkerworks/CalendarPlanView.swift` -- retain normal event ordering and editing behavior while rendering the synchronized exam as the created all-day event; remove the redundant derived-only certification marker once the event is authoritative.
- [x] `LinkerworksTests/CertificationTests.swift` -- cover active-task eligibility, generated event identity/update/clear rules, and manual-event isolation.
- [x] `STATE.md` -- append the delivered navigation, routine-link, calendar synchronization, test, and remaining runtime-verification status.

**Acceptance Criteria:**

- Given Log is visible, when Certifications is opened once, then its tracker remains visible and its add/edit presentation does not immediately dismiss or conflict with another presentation.
- Given active, archived, and substep routine tasks across domains, when the certification editor opens, then every active top-level task appears and selecting one preserves ordinary routine progress semantics.
- Given no eligible task, when Create study task succeeds, then the task is active in the routine and selected as the linked task without a separate management trip.
- Given a certification target date, when Plan opens that day, then it contains one all-day event named for the certification; changing the name/date changes that same event rather than adding another.
- Given an automatic exam event and unrelated manual events, when the target date is cleared or the certification is deleted, then only the automatic exam event disappears.

## Design Notes

The automatic event needs stable ownership, not title matching: title and target date are both user-editable and collisions with manual events are valid. The study-task shortcut should use the same active, top-level task invariants as Manage, but keep the short path inside the certification editor so the user can continue their original task.

## Verification

**Commands:**

- `swiftc -parse Linkerworks/*.swift LinkerworksTests/*.swift` -- expected: app and focused test sources parse.
- `git diff --check` -- expected: no whitespace errors.

**Manual checks (if no CLI):**

- In Xcode, open Certifications repeatedly, add/edit a certification, create and link a routine study task, then verify normal completion history still drives its 30-day total.
- Set, rename, move, clear, and delete a test date while keeping a same-day manual event; verify exactly the certification-owned all-day event follows/removes and all manual events persist.

## Suggested Review Order

**Event ownership and startup migration**

- Stable event identity prevents matching or touching manual calendar items.
  [`CertificationViews.swift:32`](../../Linkerworks/CertificationViews.swift#L32)

- Existing saved exam dates receive owned events before Plan is first opened.
  [`LinkerworksApp.swift:21`](../../Linkerworks/LinkerworksApp.swift#L21)

- The additive identifier makes ownership durable across launches and edits.
  [`Models.swift:400`](../../Linkerworks/Models.swift#L400)

**Certification workflow**

- The tracker owns one add-editor presentation to avoid competing sheet transitions.
  [`CertificationViews.swift:79`](../../Linkerworks/CertificationViews.swift#L79)

- The editor links active top-level routine tasks or creates one in place.
  [`CertificationViews.swift:355`](../../Linkerworks/CertificationViews.swift#L355)

- Event synchronization updates, moves, clears, and deletes only the owned event.
  [`CertificationViews.swift:442`](../../Linkerworks/CertificationViews.swift#L442)

**Plan protection and regression coverage**

- Generated exam rows remain visible but are managed exclusively from Certifications.
  [`CalendarPlanView.swift:188`](../../Linkerworks/CalendarPlanView.swift#L188)

- Plan save/delete guards protect automatic exam invariants from direct mutation.
  [`CalendarPlanView.swift:280`](../../Linkerworks/CalendarPlanView.swift#L280)

- Focused tests cover task eligibility and stale ownership-ID recovery.
  [`CertificationTests.swift:41`](../../LinkerworksTests/CertificationTests.swift#L41)
