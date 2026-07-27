import Foundation
import SwiftData
import XCTest

@testable import Linkerworks

@MainActor
final class HistoricalProgressTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testArchivedTaskDoesNotChangeCapturedHistoricalCompletion() {
        let date = utcDate(year: 2026, month: 7, day: 20)
        let firstTask = TaskItem(
            title: "First",
            detail: "",
            daysOfWeek: ["Monday"],
            sortOrder: 0,
            domain: .sleep
        )
        let secondTask = TaskItem(
            title: "Second",
            detail: "",
            daysOfWeek: ["Monday"],
            sortOrder: 1,
            domain: .sleep
        )
        let snapshot = DaySnapshot(
            dayKey: DaySnapshotService.dayKey(for: date, calendar: calendar),
            scheduledTaskIDs: [firstTask.id, secondTask.id]
        )
        let records = [
            CompletionRecord(date: date, taskId: firstTask.id),
            CompletionRecord(date: date, taskId: secondTask.id),
        ]

        let beforeArchive = completion(for: snapshot, records: records)
        firstTask.isArchived = true
        secondTask.daysOfWeek = ["Tuesday"]
        let afterArchive = completion(for: snapshot, records: records)

        XCTAssertEqual(beforeArchive, ProgressDayCompletion(scheduledCount: 2, completedCount: 2))
        XCTAssertEqual(afterArchive, beforeArchive)
    }

    func testFullySkippedDayIsNeutralBetweenTwoCompleteDays() {
        let firstTaskID = UUID()
        let secondTaskID = UUID()
        let completeDay = HistoricalDayProgress.completion(
            scheduledTaskIDs: [firstTaskID, secondTaskID],
            childTaskIDsByParent: [:],
            records: [
                CompletionRecord(taskId: firstTaskID, date: utcDate(year: 2026, month: 7, day: 20)),
                CompletionRecord(taskId: secondTaskID, date: utcDate(year: 2026, month: 7, day: 20)),
            ]
        )
        let skippedDay = HistoricalDayProgress.completion(
            scheduledTaskIDs: [firstTaskID, secondTaskID],
            childTaskIDsByParent: [:],
            records: [
                CompletionRecord(taskId: firstTaskID, date: utcDate(year: 2026, month: 7, day: 21), state: .skipped),
                CompletionRecord(taskId: secondTaskID, date: utcDate(year: 2026, month: 7, day: 21), state: .skipped),
            ]
        )

        XCTAssertTrue(completeDay.isComplete)
        XCTAssertEqual(skippedDay.scheduledCount, 0)
        XCTAssertEqual(skippedDay.completedCount, 0)
        XCTAssertEqual(completedRun(in: [completeDay, skippedDay, completeDay]), 2)
    }

    func testCapturedLiftChildrenRemainStableAfterRoutineEdits() {
        let date = utcDate(year: 2026, month: 7, day: 20)
        let parent = TaskItem(
            title: "Lift",
            detail: "",
            daysOfWeek: ["Monday"],
            sortOrder: 0,
            domain: .lifting
        )
        let firstChild = TaskItem(
            title: "First set",
            detail: "",
            daysOfWeek: ["Monday"],
            sortOrder: 0,
            domain: .lifting,
            isSubstep: true
        )
        let secondChild = TaskItem(
            title: "Second set",
            detail: "",
            daysOfWeek: ["Monday"],
            sortOrder: 1,
            domain: .lifting,
            isSubstep: true
        )
        parent.children = [firstChild, secondChild]
        let snapshot = DaySnapshot(
            dayKey: DaySnapshotService.dayKey(for: date, calendar: calendar),
            scheduledTaskIDs: [parent.id]
        )
        snapshot.completionUnits = [
            DaySnapshotCompletionUnit(
                parentTaskID: parent.id,
                childTaskIDs: [firstChild.id, secondChild.id],
                daySnapshot: snapshot
            ),
        ]
        let records = [
            CompletionRecord(date: date, taskId: firstChild.id),
            CompletionRecord(date: date, taskId: secondChild.id),
        ]

        let beforeRoutineEdit = completion(for: snapshot, records: records)
        firstChild.isArchived = true
        parent.children.append(
            TaskItem(
                title: "Added later",
                detail: "",
                daysOfWeek: ["Monday"],
                sortOrder: 2,
                domain: .lifting,
                isSubstep: true
            )
        )
        let afterRoutineEdit = completion(for: snapshot, records: records)

        XCTAssertEqual(beforeRoutineEdit, ProgressDayCompletion(scheduledCount: 1, completedCount: 1))
        XCTAssertEqual(afterRoutineEdit, beforeRoutineEdit)
    }

    func testBackfillIsIdempotentAndPreservesFirstCapturedSnapshot() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let defaults = testDefaults()
        let date = utcDate(year: 2026, month: 7, day: 20)
        let task = TaskItem(
            title: "Historical task",
            detail: "",
            daysOfWeek: ["Monday"],
            sortOrder: 0,
            domain: .sleep
        )
        context.insert(task)
        context.insert(CompletionRecord(date: date, taskId: task.id))
        try context.save()

        XCTAssertTrue(try DaySnapshotService.backfillIfNeeded(
            in: context,
            defaults: defaults,
            calendar: calendar
        ))
        let firstSnapshot = try requiredSnapshot(for: date, in: context)
        let firstTaskIDs = firstSnapshot.scheduledTaskIDs
        let firstCaptureTime = firstSnapshot.capturedAt

        task.isArchived = true
        try context.save()

        XCTAssertFalse(try DaySnapshotService.backfillIfNeeded(
            in: context,
            defaults: defaults,
            calendar: calendar
        ))
        let snapshots = try context.fetch(FetchDescriptor<DaySnapshot>())

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots[0].scheduledTaskIDs, firstTaskIDs)
        XCTAssertEqual(snapshots[0].capturedAt, firstCaptureTime)
        XCTAssertEqual(defaults.integer(forKey: DaySnapshotService.backfillMarkerKey), DaySnapshotService.backfillVersion)
    }

    func testCaptureReturnsExistingDaySnapshotAfterUnrelatedHistoryExists() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let targetDate = utcDate(year: 2026, month: 7, day: 20)
        let existing = DaySnapshot(
            dayKey: DaySnapshotService.dayKey(for: targetDate, calendar: calendar),
            scheduledTaskIDs: [UUID()]
        )
        let historicalSnapshots = (1...12).map { offset in
            DaySnapshot(
                dayKey: DaySnapshotService.dayKey(
                    for: calendar.date(byAdding: .day, value: -offset, to: targetDate)!,
                    calendar: calendar
                ),
                scheduledTaskIDs: []
            )
        }
        context.insert(existing)
        historicalSnapshots.forEach(context.insert)
        try context.save()

        let captured = try DaySnapshotService.captureIfNeeded(
            for: targetDate,
            in: context,
            calendar: calendar,
            capturedAt: utcDate(year: 2026, month: 7, day: 21)
        )
        let snapshots = try context.fetch(FetchDescriptor<DaySnapshot>())

        XCTAssertEqual(captured.id, existing.id)
        XCTAssertEqual(snapshots.count, historicalSnapshots.count + 1)
        XCTAssertEqual(captured.scheduledTaskIDs, existing.scheduledTaskIDs)
    }

    func testLegacyCompletionRecordDefaultsToComplete() {
        let taskID = UUID()
        let record = CompletionRecord(
            date: utcDate(year: 2026, month: 7, day: 20),
            taskId: taskID
        )

        XCTAssertEqual(record.state, .complete)

        record.stateRawValue = "legacy-missing-state"
        XCTAssertEqual(record.state, .complete)
    }

    func testRoutineDaySelectionDefersOnlyTheCurrentCalendarDay() {
        let defaults = testDefaults()
        let yesterday = utcDate(year: 2026, month: 7, day: 20)
        let today = utcDate(year: 2026, month: 7, day: 21)
        let tomorrow = utcDate(year: 2026, month: 7, day: 22)

        XCTAssertEqual(
            RoutineDaySelection.selectedDay(now: today, defaults: defaults, calendar: calendar),
            today
        )
        XCTAssertFalse(RoutineDaySelection.needsRolloverConfirmation(now: today, defaults: defaults, calendar: calendar))

        RoutineDaySelection.select(yesterday, defaults: defaults, calendar: calendar)
        XCTAssertTrue(RoutineDaySelection.needsRolloverConfirmation(now: today, defaults: defaults, calendar: calendar))

        RoutineDaySelection.deferRollover(for: today, defaults: defaults, calendar: calendar)
        XCTAssertFalse(RoutineDaySelection.needsRolloverConfirmation(now: today, defaults: defaults, calendar: calendar))
        XCTAssertTrue(RoutineDaySelection.needsRolloverConfirmation(now: tomorrow, defaults: defaults, calendar: calendar))

        RoutineDaySelection.select(today, defaults: defaults, calendar: calendar)
        XCTAssertEqual(RoutineDaySelection.selectedDay(now: tomorrow, defaults: defaults, calendar: calendar), today)
    }

    func testGoalkeepingRestDaySkipsOnlyItsCompletionUnits() {
        let date = utcDate(year: 2026, month: 7, day: 20)
        let goalkeeping = TaskItem(title: "Goalkeeping", detail: "", daysOfWeek: ["Monday"], sortOrder: 0, domain: .goalkeeping)
        let sleep = TaskItem(title: "Sleep", detail: "", daysOfWeek: ["Monday"], sortOrder: 1, domain: .sleep)
        let goalkeepingIDs = GoalkeepingRestDay.completionUnitTaskIDs(for: [goalkeeping])

        XCTAssertEqual(goalkeepingIDs, Set([goalkeeping.id]))
        let completion = HistoricalDayProgress.completion(
            scheduledTaskIDs: [goalkeeping.id, sleep.id],
            childTaskIDsByParent: [:],
            records: [
                CompletionRecord(date: date, taskId: goalkeeping.id, state: .skipped),
                CompletionRecord(date: date, taskId: sleep.id),
            ]
        )
        XCTAssertEqual(completion, ProgressDayCompletion(scheduledCount: 1, completedCount: 1))
    }

    func testResumingGoalkeepingRestDayPreservesExistingCompletion() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let defaults = testDefaults()
        let date = utcDate(year: 2026, month: 7, day: 20)
        let task = TaskItem(title: "Goalkeeping", detail: "", daysOfWeek: ["Monday"], sortOrder: 0, domain: .goalkeeping)
        context.insert(task)
        context.insert(CompletionRecord(date: date, taskId: task.id, completedAt: date.addingTimeInterval(60)))
        try context.save()

        try GoalkeepingRestDay.setRestDay(
            true,
            tasks: [task],
            date: date,
            in: context,
            defaults: defaults,
            calendar: calendar
        )
        XCTAssertTrue(GoalkeepingRestDay.isRestDay(
            tasks: [task],
            date: date,
            defaults: defaults,
            calendar: calendar
        ))

        try GoalkeepingRestDay.setRestDay(
            false,
            tasks: [task],
            date: date,
            in: context,
            defaults: defaults,
            calendar: calendar
        )
        let records = try context.fetch(FetchDescriptor<CompletionRecord>())
        XCTAssertEqual(records.filter { $0.taskId == task.id && $0.state == .complete }.count, 1)
        XCTAssertTrue(records.contains { $0.taskId == task.id && $0.state == .skipped })
        XCTAssertEqual(
            HistoricalDayProgress.stateByTaskID(
                records,
                ignoredRecordIDs: GoalkeepingRestDay.ignoredRecordIDs(defaults: defaults)
            )[task.id],
            .complete
        )
    }

    func testResumingRestDayLeavesManualGoalkeepingSkipsIntact() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let defaults = testDefaults()
        let date = utcDate(year: 2026, month: 7, day: 20)
        let task = TaskItem(title: "Goalkeeping", detail: "", daysOfWeek: ["Monday"], sortOrder: 0, domain: .goalkeeping)
        context.insert(task)
        context.insert(CompletionRecord(date: date, taskId: task.id, state: .skipped))
        try context.save()

        try GoalkeepingRestDay.setRestDay(true, tasks: [task], date: date, in: context, defaults: defaults, calendar: calendar)
        try GoalkeepingRestDay.setRestDay(false, tasks: [task], date: date, in: context, defaults: defaults, calendar: calendar)

        let records = try context.fetch(FetchDescriptor<CompletionRecord>())
        XCTAssertEqual(HistoricalDayProgress.stateByTaskID(records)[task.id], .skipped)
        XCTAssertTrue(records.allSatisfy { $0.state == .skipped })
    }

    func testGoalkeepingParentUsesChildCompletionUnitsForRestDay() {
        let parent = TaskItem(title: "Goalkeeping", detail: "", daysOfWeek: ["Monday"], sortOrder: 0, domain: .goalkeeping)
        let firstChild = TaskItem(title: "Drills", detail: "", daysOfWeek: ["Monday"], sortOrder: 0, domain: .goalkeeping, isSubstep: true, parent: parent)
        let secondChild = TaskItem(title: "Distribution", detail: "", daysOfWeek: ["Monday"], sortOrder: 1, domain: .goalkeeping, isSubstep: true, parent: parent)
        parent.children = [firstChild, secondChild]

        XCTAssertEqual(
            GoalkeepingRestDay.completionUnitTaskIDs(for: [parent]),
            Set([firstChild.id, secondChild.id])
        )
    }

    func testCompletionRecordDayIndexGroupsOnceAndPreservesLatestState() {
        let firstDay = utcDate(year: 2026, month: 7, day: 20)
        let secondDay = utcDate(year: 2026, month: 7, day: 21)
        let taskID = UUID()
        let early = CompletionRecord(
            date: firstDay,
            taskId: taskID,
            completedAt: firstDay.addingTimeInterval(60),
            state: .complete
        )
        let late = CompletionRecord(
            date: firstDay,
            taskId: taskID,
            completedAt: firstDay.addingTimeInterval(120),
            state: .skipped
        )
        let next = CompletionRecord(date: secondDay, taskId: taskID)

        let index = CompletionRecordDayIndex(
            records: [late, next, early],
            ignoredRecordIDs: [],
            calendar: calendar
        )
        let firstKey = DaySnapshotService.dayKey(for: firstDay, calendar: calendar)
        let secondKey = DaySnapshotService.dayKey(for: secondDay, calendar: calendar)

        XCTAssertEqual(index.recordsByDayKey[firstKey]?.count, 2)
        XCTAssertEqual(index.recordsByDayKey[secondKey]?.count, 1)
        XCTAssertEqual(index.statesByDayKey[firstKey]?[taskID], .skipped)
        XCTAssertEqual(index.statesByDayKey[secondKey]?[taskID], .complete)
    }

    func testCompletionRecordDayIndexExcludesIgnoredRestDayRecords() {
        let date = utcDate(year: 2026, month: 7, day: 20)
        let taskID = UUID()
        let retained = CompletionRecord(
            date: date,
            taskId: taskID,
            completedAt: date.addingTimeInterval(60),
            state: .complete
        )
        let ignored = CompletionRecord(
            date: date,
            taskId: taskID,
            completedAt: date.addingTimeInterval(120),
            state: .skipped
        )
        let index = CompletionRecordDayIndex(
            records: [retained, ignored],
            ignoredRecordIDs: [ignored.id],
            calendar: calendar
        )
        let key = DaySnapshotService.dayKey(for: date, calendar: calendar)

        XCTAssertEqual(index.recordsByDayKey[key]?.map(\.id), [retained.id])
        XCTAssertEqual(index.statesByDayKey[key]?[taskID], .complete)
    }

    func testSkipAwareTaskCompletionMatchesHistoricalProgress() {
        let parentID = UUID()
        let completedChildID = UUID()
        let skippedChildID = UUID()
        let states: [UUID: CompletionRecordState] = [
            completedChildID: .complete,
            skippedChildID: .skipped,
        ]

        XCTAssertTrue(HistoricalDayProgress.isTaskComplete(
            taskID: parentID,
            childTaskIDs: [completedChildID, skippedChildID],
            states: states
        ))
        XCTAssertEqual(
            HistoricalDayProgress.completion(
                scheduledTaskIDs: [parentID],
                childTaskIDsByParent: [
                    parentID: [completedChildID, skippedChildID],
                ],
                states: states
            ),
            ProgressDayCompletion(scheduledCount: 1, completedCount: 1)
        )
    }

    func testChildStateOverridesLegacyParentCompletion() {
        let parentID = UUID()
        let childID = UUID()
        let states: [UUID: CompletionRecordState] = [
            parentID: .complete,
            childID: .skipped,
        ]

        XCTAssertFalse(HistoricalDayProgress.isTaskComplete(
            taskID: parentID,
            childTaskIDs: [childID],
            states: states
        ))
    }

    private func completion(
        for snapshot: DaySnapshot,
        records: [CompletionRecord]
    ) -> ProgressDayCompletion {
        HistoricalDayProgress.completion(
            scheduledTaskIDs: snapshot.scheduledTaskIDs,
            childTaskIDsByParent: HistoricalProgressSnapshot(snapshot: snapshot).childTaskIDsByParent,
            records: records
        )
    }

    private func completedRun(in days: [ProgressDayCompletion]) -> Int {
        days.reduce(into: 0) { run, day in
            if day.scheduledCount == 0 {
                return
            }
            run = day.isComplete ? run + 1 : 0
        }
    }

    private func inMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedModelContainer.schema, configurations: [configuration])
    }

    private func requiredSnapshot(for date: Date, in context: ModelContext) throws -> DaySnapshot {
        let key = DaySnapshotService.dayKey(for: date, calendar: calendar)
        let snapshots = try context.fetch(FetchDescriptor<DaySnapshot>())
        return try XCTUnwrap(snapshots.first { $0.dayKey == key })
    }

    private func testDefaults() -> UserDefaults {
        let suiteName = "HistoricalProgressTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func utcDate(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
