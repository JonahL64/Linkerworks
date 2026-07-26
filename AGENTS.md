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

## Visual language (apply in polish sprint; keep earlier sprints unstyled)
Dark athletic training-log look. Background `#0E1210`, text `#EDEFEC`, secondary `#7A857F`, single accent `#3ECF6E` used only for progress/completion states. Times in monospaced digits. One signature animation: completing the final task of the day. No gradients, no card-heavy dashboard styling.
