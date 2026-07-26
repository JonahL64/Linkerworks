# Blind Hunter Review Prompt — Sprint 3 Homework core

Invoke the `bmad-review-adversarial-general` skill on the following implementation scope. Review only current-source behavior; there is no usable Git baseline on this host.

Changed files:

- `Linkerworks/Models.swift`: new SwiftData `Course` and `Assignment` models.
- `Linkerworks/SharedModelContainer.swift`: registers both models in the existing App Group schema.
- `Linkerworks/HomeworkView.swift`: assignment/course UI, bucketing, sort logic, filters, haptics, and editors.
- `Linkerworks/CalendarPlanView.swift`: Plan toolbar Homework navigation route.
- `LinkerworksTests/HomeworkCoreTests.swift`: focused XCTest coverage.

Required behavior: course palette must never be completion green; rows use a small course marker only; groups are Overdue, Today, Tomorrow, This week, Later, No due date, Done; Done is collapsed and only shows the last 14 days; ordering is due date, course order, creation time, UUID; completion is immediate with haptic and no confirmation; leading swipe postpones a day; trailing swipe confirms deletion; Detail disclosure holds due-time/notes; Today and Progress must remain assignment-free.

Read the files and report only concrete, user-impacting findings with file/line, consequence, and a minimal correction. Do not modify files.
