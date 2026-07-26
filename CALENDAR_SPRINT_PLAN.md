# Linkerworks — Sprint 11: Plan Calendar & Events

## Outcome

Replace the Plan placeholder with an offline calendar where the user can create, edit, and delete personal events; scan a month at a glance; select a day; and switch to a week or day agenda to see the scheduled events in time order.

## Scope

### Event data

- Add a SwiftData `CalendarEvent` model to the existing App Group-backed schema. It stores a stable ID, title, normalized start date, optional start/end time, all-day flag, optional notes, creation/update timestamps, and integer sort order.
- Keep the model independent of `TaskItem`, `CompletionRecord`, meals, and workouts. Calendar events must not alter routine completion history or tracker calculations.
- Use the existing shared `ModelContainer`, so events persist offline and remain available after relaunch. The widget is unchanged in this sprint.

### Plan tab

- Replace the static current-month grid with a navigable month view, including previous/next month controls and a Today action.
- Indicate days that contain events without turning the calendar into a card dashboard. Selecting a date updates the active date and opens that date’s agenda.
- Provide an explicit Month / Week / Day view control. Week view shows the selected week, while Day view shows the selected day; both list all-day events first and timed events in chronological order.
- Let the user add an event from Plan and from the selected day. The event editor supports title, date, all-day or a start/end time, and notes; edit and delete are available from an event detail/editor flow.
- Preserve the current “Manage Routine” route from Plan. It continues to present `ManageView` and is not folded into event editing.

### Interaction and visual constraints

- Use `Calendar.current`, local dates, and the existing dark training-log palette. Timed labels use monospaced digits; green remains reserved for completion/progress rather than ordinary event decoration.
- Reject an end time earlier than the start time with a clear inline validation message. Events with equal start/end times are treated as a point-in-time event.
- No calendar accounts, EventKit import/export, invitations, notifications, recurrence, locations, attachments, cloud sync, or widget calendar display in this sprint.

## Implementation sequence

1. Add and register `CalendarEvent`; verify a migration from the existing shared SwiftData store preserves all current models and data.
2. Extract the Plan placeholder into calendar/event views, with date helpers for month-grid cells, week boundaries, event lookup, and a deterministic display order.
3. Build the month selector and selected-day agenda, then add the Week and Day views over the same query/data helpers.
4. Add the event editor and destructive-delete confirmation; ensure all write paths save and surface errors consistently.
5. Restore the Manage Routine sheet and perform visual/accessibility checks for selection, empty states, and time ordering.

## Acceptance criteria

- A new event survives app relaunch and appears on its date in month, week, and day contexts.
- Month navigation and Today correctly change the visible month/selected day without losing event data.
- Tapping a calendar day presents that day’s agenda; week view is anchored to its selected date’s calendar week.
- All-day events appear before timed events; timed events sort by start time and then creation/order tie-breaker.
- The user can create, edit, and delete an event, and an invalid time range cannot be saved.
- Existing Today, Log, Progress, More, routine management, SwiftData models, seed import, and widget behavior remain unchanged.

## Verification

- Run `swiftc -parse Linkerworks/*.swift` and `git diff --check`.
- In Xcode/device or Simulator: create each event type, relaunch, navigate months, select days, check week/day ordering, edit/delete, and test the invalid end-time state.
- Confirm the app opens an existing pre-calendar shared store without loss of routine, completion, nutrition, or workout records.

## Deferred follow-ons

- Recurring events and routine-to-calendar projections.
- Event reminders/notifications and a next-event widget surface.
- EventKit import/export, external calendars, locations, invitations, and cloud sync.
