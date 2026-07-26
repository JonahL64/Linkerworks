# Linkerworks — Native App Sprint Plan (v2, supersedes PWA spec)

**PMO:** Claude (owns this plan, data files, reviews each sprint's output)
**Builder:** Codex (executes one sprint per session)
**Requirement change driving v2:** home screen + lock screen widget → native app, not PWA.

---

## Platform: LOCKED — iPhone (SwiftUI + WidgetKit), building on Mac/Xcode

Free Apple ID note: apps installed with a free account expire after 7 days — you re-plug the phone and hit Run again in Xcode to refresh. Fine for personal use; $99/yr dev account removes it if it annoys you.

## Platform fork (resolved — kept for reference)

| | iPhone | Android |
|---|---|---|
| Stack | SwiftUI + WidgetKit | Kotlin + Jetpack Compose + Glance |
| Widget support | Home screen + lock screen (iOS 16+ accessory widgets); interactive tap-to-check via AppIntents (iOS 17+) | Home screen widgets solid; lock screen widgets effectively unavailable on most phones |
| Requirements | **A Mac with Xcode — non-negotiable.** Free Apple ID installs expire every 7 days (re-plug and rebuild); $99/yr dev account removes that | Android Studio on any OS; sideload freely, no expiry |
| Data sharing app↔widget | App Group (shared UserDefaults / file container) | Shared DataStore/Room DB |

Everything below is platform-agnostic except Sprint 6; the fork only changes syntax, not structure.

---

## App structure (locked scope)

**Tabs:**
1. **Today** — today's checklist from the weekly schedule, grouped by section (After Wakeup / Morning / Afternoon / Evening / Before Bed), progress ring, "completion moment" when the day maxes out.
2. **Streaks** — current streak, longest streak, calendar heatmap of daily completion %, per-week rollup.
3. **Trackers** — one tracker per health domain: Sleep, Eating (macros vs 4,005 kcal target), Goalkeeping, Lifting, Posture, Grooming/Skincare. Each shows domain-specific completion history and the reference info from `reference.json` (workout program, macro tables, GK focus rotation, etc.).
4. **Manage** — add/edit/delete tasks, reorder within sections, edit times/details, assign tasks to days of week, archive tasks without losing their history.

**Seed data:** `schedule.json` + `reference.json` (already extracted — a starting point only, imported once on first launch; after that, the app's own database is the source of truth so Manage edits persist and the JSON is never re-read).

**Non-goals (do not let Codex add):** accounts, cloud sync, notifications (revisit later), social anything, App Store distribution.

---

## Codex usage rules (apply to every sprint)

- **`AGENTS.md` in repo root** containing: this plan's scope section, the data model from Sprint 1, and "prefer shell commands over MCP; keep command output terse; do not add scope beyond the current sprint." Keep it stable — edit only between sprints, never mid-session, so prompt caching keeps paying.
- **One sprint = one fresh session.** Never `resume` a previous sprint's thread. At the end of each sprint, have Codex append 5–10 lines to a `STATE.md` (what was built, key file paths, open issues) — the next session reads that instead of inheriting a bloated context.
- **Debugging gets its own session too.** If a sprint hits a nasty bug, finish diagnosing in a throwaway session, write the fix instruction into STATE.md, then apply it in a clean session. Never drag investigation context into building.
- **No MCP servers connected.** Zero are needed for this project; each one taxes every turn.
- **Model tiers (GPT-5.6 family):** *Sol* = deep reasoning (scarcest on Plus), *Terra* = default, *Luna* = fast/cheap. The table below assigns them. When in doubt, drop a tier — escalate to Sol only when Terra visibly fails.

---

## Sprints

| # | Sprint | Deliverable | Model | Session rule |
|---|---|---|---|---|
| 0 | **Setup** | New Xcode/Android Studio project, repo, AGENTS.md, JSON seed files added, app runs empty on your phone | None/Luna | Fresh session; mostly manual clicking, use Codex only if setup errors |
| 1 | **Data layer** | Data model (Task, Section, DaySchedule, CompletionRecord, Tracker domains), JSON import on first launch, local persistence, **storage placed in the App Group / shared container from day one so the widget can read it later** | **Sol** | Fresh session. This is the only architecture sprint — the widget-readable storage decision is brutal to retrofit, spend the good model here |
| 2 | **Today tab** | Full checklist UI, section grouping, sub-steps nested under lifts, checking persists by date, progress ring | Terra | Fresh session, seeded by STATE.md |
| 3 | **Manage tab** | Add/edit/delete/reorder tasks, day-of-week assignment, edits apply to future days without corrupting past completion history | Terra | Fresh session |
| 4 | **Streaks tab** | Current/longest streak logic, heatmap, week rollups | Terra (Luna for the heatmap grid rendering if split) | Fresh session |
| 5 | **Trackers tab** | Six domain trackers with history + reference content rendered readably | Terra | Fresh session; if it drags, split into two sessions (3 domains each) rather than one long one |
| 6 | **Widget** | Home screen widget (today's progress + next task) and, on iPhone, a lock screen accessory widget; taps deep-link into the app. Stretch (iOS 17+): tap-to-check the next task from the widget | **Sol** for the app↔widget data wiring and timeline provider; Luna for widget layout tweaks after it works | Fresh session. Widget data-sharing bugs are the likeliest place you'll burn tokens — if debugging exceeds ~30 min, stop, new session |
| 7 | **Polish + install** | Visual pass (dark athletic palette: near-black `#0E1210`, off-white text, single pitch-green `#3ECF6E` accent on progress/completion only; monospace times), completion-moment animation, app icon, build to phone | Terra, Luna for icon/asset boilerplate | Fresh session |

**Review gate:** after every sprint, bring the result (screenshots or code) back to me before starting the next. I check it against this plan; you only ever tell Codex "build Sprint N per AGENTS.md."

---

## Budget expectations on Plus

Plus supports a few focused coding sessions per five-hour window. Sprints 1 and 6 are your Sol spends — do them on days you haven't burned allowance. Sprints 2–5 and 7 are each comfortably a single Terra session if you start clean and keep prompts surgical (name exact files, never "look into it"). Realistic calendar: one sprint per sitting, 8 sittings total.

---

## Sprint 11 — Plan calendar & events

**Deliverable:** Replace the Plan placeholder with a local, App Group-backed event calendar: navigable month view, selectable day agenda, week and day views, and add/edit/delete event flows. Keep routine management reachable from Plan.

**Detailed plan:** [`CALENDAR_SPRINT_PLAN.md`](CALENDAR_SPRINT_PLAN.md)

**Out of scope:** recurrence, reminders/notifications, EventKit or external calendars, invitations, locations, cloud sync, and widget calendar content.

**Session rule:** Fresh implementation session. Perform a SwiftData migration/persistence check against an existing shared store before sign-off.
