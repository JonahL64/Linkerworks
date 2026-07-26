---
name: Linkerworks Training Log
description: A quiet, precise iPhone training log that makes daily planning and recovery feel deliberate rather than gamified.
status: final
sources:
  - '{project-root}/AGENTS.md'
  - '{project-root}/STATE.md'
  - '{project-root}/CALENDAR_SPRINT_PLAN.md'
updated: 2026-07-24
colors:
  canvas: '#0E1210'
  surface: '#141A17'
  surface-pressed: '#1D2520'
  ink: '#EDEFEC'
  ink-muted: '#7A857F'
  hairline: '#303A34'
  completion: '#3ECF6E'
  destructive: '#E58A8A'
typography:
  display:
    note: 'iOS system rounded, 28pt semibold, used once per surface at most'
  title:
    note: 'iOS system, 20pt semibold'
  body:
    note: 'iOS system, 17pt regular'
  meta:
    note: 'iOS system, 13pt medium; uppercase only for short section labels'
  time:
    note: 'iOS system monospaced digits, 13pt medium'
rounded:
  cell: 6px
  control: 8px
  sheet: 16px
spacing:
  '1': 4px
  '2': 8px
  '3': 12px
  '4': 16px
  '5': 24px
  '6': 32px
components:
  divider:
    color: '{colors.hairline}'
  primary-action:
    foreground: '{colors.ink}'
    radius: '{rounded.control}'
  completion-state:
    color: '{colors.completion}'
  selected-date:
    background: '{colors.ink}'
    foreground: '{colors.canvas}'
    radius: '{rounded.cell}'
---

## Brand & Style

Linkerworks is a personal training log, not a social fitness product or a dashboard. It should feel like opening a well-kept coach's notebook: dark, precise, calm, and immediately legible. The interface earns visual weight through type, alignment, and rhythm—not floating cards, oversized pills, or decorative containers.

The user has explicitly asked for a slicker, cleaner, easier experience. The design response is **quiet utility**: one obvious next action per surface, compact navigation, flat lists, and dense-but-breathable information. The existing athletic direction remains intact.

## Colors

- **Canvas `{colors.canvas}`** is the continuous app background. Screens should read as one surface, not stacked cards.
- **Ink `{colors.ink}`** is reserved for primary content, selected calendar dates, and the one primary action on a surface.
- **Muted ink `{colors.ink-muted}`** carries times, summaries, helper text, inactive controls, and empty states.
- **Hairline `{colors.hairline}`** separates rows and creates restrained structure. It replaces filled containers as the default grouping tool.
- **Completion `{colors.completion}`** is exclusive to completed tasks, progress, and the final-day completion moment. It never marks a calendar selection, navigation mode, or ordinary button.
- **Destructive `{colors.destructive}`** appears only at destructive actions and confirmations.

No gradients, shadows, neon glow, category colors, or tinted dashboard cards.

## Typography

Use native iOS typography and Dynamic Type. `{typography.display}` introduces the surface only once; screen content normally begins at `{typography.title}` or `{typography.body}`. Section labels use `{typography.meta}` with restrained tracking. Times, time ranges, numbers, percentages, and set loads use `{typography.time}`.

Titles are sentence case. Avoid all-caps except short structural labels such as `TODAY`, `UP NEXT`, or section names. Never use heavy text beside a second equally heavy label; hierarchy should always identify what to read first.

## Layout & Spacing

Use a 16pt iPhone content gutter and `{spacing.4}` as normal row padding. Separate major blocks with `{spacing.5}` or `{spacing.6}`, not filled cards. Lists use a single column with hairline dividers; an item has one primary tap target. Keep headers compact and content-led: controls belong in the navigation bar or aligned with the block they modify.

## Elevation & Depth

There is no ornamental elevation. Sheets use the system presentation with `{rounded.sheet}`; standard rows and calendar cells sit directly on `{colors.canvas}`. A pressed state may use `{colors.surface-pressed}` briefly. Raised fill `{colors.surface}` is reserved for text inputs, selected-control backgrounds, and an occasional editor grouping—not routine content.

## Shapes

Avoid persistent pill containers and large circular buttons. `{rounded.cell}` is for a selected calendar date or compact inline control; `{rounded.control}` is for a normal button or input. Icon actions use native toolbar placement with at least a 44pt hit target but no visible oversized circle unless the action is destructive or modal.

## Components

- **Surface header** — title left, one text or icon action right. No second title below it.
- **Section header** — subdued meta label, optional small count or contextual text; never boxed.
- **List row** — leading state/time, primary label, optional one-line detail, hairline below. Tapping the row edits or drills in.
- **Primary action** — a single full-width compact button only when a surface needs a creation action. Otherwise use the navigation-bar plus.
- **Mode switcher** — compact text tabs with a 2pt underline on the active mode. Do not use a large segmented pill.
- **Calendar grid** — plain numbered cells. Event existence is one small muted dot; selected date gets `{components.selected-date}`. Today gets a hairline outline. No tile behind every date.
- **Progress** — thin ring or line plus a numeric label. Green is used only for completed proportion.
- **Editor** — native form structure, clear labels, a single Save action, and a separated destructive action at the bottom.

## Do's and Don'ts

| Do | Don't |
|---|---|
| Let whitespace, type, and hairlines organize content | Wrap every content group in a filled card |
| Use one strong action per screen | Put a large Today button, plus button, segmented control, and bottom CTA in the same viewport |
| Use flat calendar cells with a quiet event dot | Render every calendar day as a rounded dark tile |
| Keep mode/context controls close to the content they affect | Use oversized system segmented controls as a page hero |
| Reserve green for completion/progress | Use green to indicate ordinary selection or navigation |
| Keep native iOS editing and sheet behavior | Invent custom control chrome that duplicates system affordances |
