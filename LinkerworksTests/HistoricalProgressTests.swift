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
