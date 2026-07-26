# Linkerworks — Codex build instructions

Personal iOS habit/regimen app for a single user. SwiftUI, iOS 17 target, WidgetKit extension. No accounts, no networking, no cloud sync, no notifications, no third-party dependencies (SPM packages only if truly unavoidable — ask first).

## Working rules
- Build ONLY the sprint named in the prompt. Do not combine sprints or add features beyond it. If you think something extra is needed, list it at the end instead of building it.
- Read `STATE.md` at session start for what already exists. Append 5–10 lines to it at session end: what you built, key file paths, open issues.
- Prefer shell commands over any MCP tooling. Keep command output terse (pipe through `tail`/`grep` when output is long). Avoid dumping large files; read only the files relevant to the current sprint.
- Ask before renaming files or restructuring folders that STATE.md says exist.

## Architecture (fixed — do not redesign)
- **Storage lives in the App Group container** (`group.com.jonah.linkerworks`) from Sprint 1 onward, so the widget extension can read it. Use SwiftData or a JSON-file-backed store in the shared container — your call, but it must be readable from the widget target without the app running.
- **Data model:** `TaskItem` (id, title, time, detail, section, daysOfWeek, sortOrder, domain, isSubstep, isArchived), `CompletionRecord` (date, taskId, completedAt), plus computed streak/summary helpers. Task edits must never corrupt historical CompletionRecords (archive, don't delete).
- **Seed data:** `data/schedule.json` and `data/reference.json` in the repo. Import once on first launch into the store; after that the store is the source of truth (the Manage tab edits it).
- **Domains** (for the Trackers tab): sleep, eating, goalkeeping, lifting, posture, grooming. Tag imported tasks with a domain during import based on task content.

## App structure (fixed scope)
Tabs: **Today** (checklist grouped by section, progress ring), **Streaks** (current/longest streak, heatmap), **Trackers** (six domain views: history + reference content), **Manage** (add/edit/delete/reorder tasks, day-of-week assignment, archive).
Widget target: home screen widget (today's progress + next task) and lock screen accessory widget; taps deep-link into the app.

## Visual language — "Paper & Ink" (established; build to this, do not reinvent)

The design system lives in `Linkerworks/Theme/`. **Use its tokens. Do not hardcode colours, fonts, or spacing values in view code.**

- `Theme/Palette.swift` — `LWColor`. Semantic tokens only: `surface` / `surfaceRaised` / `surfaceSunken`, `ink` / `inkSecondary` / `inkTertiary`, `hairline` / `separator`, `accent` / `accentMuted` / `onAccent`, and the state colours `success` / `warning` / `danger` / `neutral`. Plus a tint per Log domain.
- `Theme/Typography.swift` — `LWFont`. Named scale. **Never write `.font(.caption)`, `.font(.headline)` etc. in a view.**
- `Theme/Metrics.swift` — `LWSpace` (4pt grid), `LWRadius`, `LWStroke`, `LWMotion`.
- `Theme/Components.swift` — `LWSection`, `LWCheckControl`, `LWProgressRing`, `LWProgressBar`, `LWStatBlock`, `LWHeatCell`, `LWChip`, `LWSegmentedTabs`, `LWEmptyState`, `LWToast`, `LWBanner`, `LWRowDivider`. Reach for these before writing a bespoke row.
- `TrainingLogTheme.swift` is a **compatibility shim** over `LWColor`/`LWSpace` for pre-redesign call sites. New code uses the `LW*` types directly.

Rules that define the look:

- **Warm neutrals, both appearances.** Ground is warm off-white `#F7F5F0` in light and warm charcoal `#1A1917` in dark — never near-black. Every colour adapts; the app follows the system appearance. **Do not add `.preferredColorScheme(.dark)` anywhere.**
- **Accent is ink blue, not green.** `LWColor.accent` is interactive/brand. `LWColor.success` (desaturated green) means *completion only*. Overdue is `danger`, approaching is `warning`. Never signal a warning with the success colour.
- **Sentence case everywhere.** No tracked-out uppercase micro-labels (`DUE TODAY`, `NOW`, `SET 1`). No `.tracking()` on small text. This was the app's most obvious design tic and it is gone — do not reintroduce it.
- **Serif for display.** Large numerals and screen titles use the system serif (`LWFont.display*`, `LWFont.title*`). System sans for everything else. Times and metrics use monospaced digits.
- **Group with raised surfaces, not just hairlines.** Content sits in `LWSection` / `.lwBlock()` blocks on `surfaceRaised` with generous padding. Still no gradients and no card-heavy dashboard styling — restraint, but with real hierarchy.
- **44pt minimum tap targets** (`LWSpace.minTapTarget`).
- One signature animation: completing the final task of the day (`DayCompleteMoment` in `ContentView.swift`).

Widget note: the widget target cannot import `LWColor`. Shared colours are duplicated in both asset catalogues under the same names — a colour added to one must be added to the other.
