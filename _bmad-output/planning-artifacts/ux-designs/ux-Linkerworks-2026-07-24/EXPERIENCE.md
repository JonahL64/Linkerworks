---
name: Linkerworks Training Log
description: Behavioral and information-architecture spine for the iPhone training log redesign.
status: final
sources:
  - '{project-root}/AGENTS.md'
  - '{project-root}/STATE.md'
  - '{project-root}/CALENDAR_SPRINT_PLAN.md'
updated: 2026-07-24
---

# Linkerworks — Experience Spine

## Foundation

Single-user, offline-first iPhone app built in SwiftUI for iOS 17. Native navigation, sheets, forms, Dynamic Type, VoiceOver, and system gestures remain the behavioral baseline. `DESIGN.md` is the visual identity reference; this document owns behavior. The five-tab information architecture stays intact: Today, Plan, Log, Progress, More.

## Information Architecture

| Surface | Reached from | Purpose |
|---|---|---|
| Today | Launch / tab | Complete today's routine and understand daily progress at a glance. |
| Plan | Tab | See and manage calendar events by month, week, or day; open routine management. |
| Log | Tab | Choose Nutrition, Workout, or a domain history/reference view. |
| Progress | Tab | Review streaks, completion history, and weekly trend. |
| More | Tab | Reach future settings and data tools without competing with daily actions. |
| Editors | Row tap / add action | Create or edit one event, meal, workout item, or task in a one-level sheet. |

The tab bar is the only persistent navigation. Every tab opens directly to useful content; no hero dashboard is added.

## Voice and Tone

Microcopy is short, factual, and steady.

| Do | Don't |
|---|---|
| `No events scheduled.` | `Your calendar is totally clear!` |
| `3 of 8 complete` | `You're crushing it!` |
| `Add event` | `Let's plan something` |
| `Couldn’t save. Try again.` | Technical storage jargon |

## Component Patterns

| Component | Behavioral rules |
|---|---|
| Tab bar | Five stable destinations. Active state is native; labels always remain visible. |
| Surface header | Today shows the date and progress; other tabs show a succinct title and context action. No duplicate title inside scroll content. |
| Flat row | One tap opens detail/editor; toggles remain direct only for immediate completion. Swipe-to-delete is retained only where the feature already supports deletion, with confirmation for calendar events. |
| Mode tabs | Month / Week / Day switches context without resetting the selected date. The active tab is visually underlined per `{components.mode-switcher}`. |
| Calendar | Tapping a date selects it. Month keeps the selected-day agenda below the grid; week/day display the same event rows in context. Previous/next controls change the visible period. |
| Event row | All-day events precede timed events. A tap opens the editor. No event card is used. |
| Empty state | One muted sentence and, where useful, the nearby native Add action. No illustration or oversized call to action. |

## State Patterns

| State | Treatment |
|---|---|
| Selected calendar date | `{components.selected-date}`; today retains a hairline when not selected. |
| Event-bearing date | One small muted dot below the number. |
| Completion | `{components.completion-state}` only for task completion/progress. |
| Editing/saving failure | Keep the editor open, preserve entered data, and state the problem plainly. |
| Empty day/week | Show `No events scheduled.` in the expected agenda position. |
| Final task complete | Retain the existing one-shot completion moment; Reduce Motion changes it to an immediate state. |

## Interaction Primitives

- Tap a row to inspect or edit; tap a task control to complete/uncomplete.
- Use native iOS sheets for creation/editing and a confirmation dialog for destructive event deletion.
- Previous/next controls advance the current calendar context. Today returns Plan to the current date.
- Keep reordering gestures in Manage/Workout where already supported; do not introduce custom long-press behavior elsewhere.
- Banned: carousel navigation, swipe-only essential actions, persistent floating action buttons, modal stacks deeper than one, celebration banners other than the existing final-task moment.

## Accessibility Floor

- All visible and invisible touch targets are at least 44pt.
- VoiceOver labels name the action and state: a date announces its full date and whether it contains events; completion controls announce completion state.
- Dynamic Type may expand rows; text must wrap rather than truncate essential labels and no calendar cell may hide its date number.
- Color is never the only state signal. Event dots are accompanied by accessibility value; completion includes text/icon state.
- Reduce Motion removes nonessential transition effects. Standard iOS focus order follows visual reading order.

## Key Flows

### Flow 1 — Morning routine (Jonah, before leaving home)

1. Jonah opens Today.
2. The date, one compact progress summary, and the first routine section are immediately visible.
3. He checks tasks without leaving the list.
4. He scans the next section through clear hairline-separated rows rather than card blocks.
5. **Climax:** the final completion updates the quiet progress state and triggers the existing single completion moment.

### Flow 2 — Plan a commitment (Jonah, Sunday night)

1. Jonah opens Plan, which lands on the current month without oversized controls.
2. He taps a date; the selected-day agenda appears directly below a flat calendar grid.
3. He uses the native add action, enters a title and time, and saves.
4. The grid gains a quiet event dot and the new row appears in the agenda.
5. **Climax:** he switches to Week and sees the same event in chronological context without relearning the interface.

### Flow 3 — Log training (Jonah, after lifting)

1. Jonah opens Log.
2. Nutrition and Workout appear as two simple primary routes; tracker history remains below as reference destinations.
3. He opens Workout and records a set with the existing editor behavior.
4. He returns to Log without a success toast or dashboard detour.
5. **Climax:** the log is updated, easy to scan, and no activity is hidden behind decorative UI.
