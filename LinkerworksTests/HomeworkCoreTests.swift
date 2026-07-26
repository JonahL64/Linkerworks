import Foundation
import XCTest

@testable import Linkerworks

@MainActor
final class HomeworkCoreTests: XCTestCase {
    private var calendar: Calendar { var value = Calendar(identifier: .gregorian); value.timeZone = TimeZone(secondsFromGMT: 0)!; return value }

    func testBucketsAcrossMidnightBoundary() {
        let now = date(2026, 7, 25, 0, 5)
        let overdue = Assignment(title: "Before", dueDate: date(2026, 7, 24, 23, 59), sortOrder: 0)
        let today = Assignment(title: "After", dueDate: date(2026, 7, 25, 0, 6), sortOrder: 1)
        XCTAssertEqual(HomeworkSupport.bucket(for: overdue, now: now, calendar: calendar), .overdue)
        XCTAssertEqual(HomeworkSupport.bucket(for: today, now: now, calendar: calendar), .today)
    }

    func testDefaultTimeRoundTrip() {
        let due = HomeworkSupport.defaultDueDate(on: date(2026, 7, 25, 8, 0), calendar: calendar)
        let assignment = Assignment(title: "Essay", dueDate: due, usesDefaultTime: true, sortOrder: 0)
        XCTAssertTrue(assignment.usesDefaultTime)
        XCTAssertEqual(calendar.component(.hour, from: assignment.dueDate), 23)
        XCTAssertEqual(calendar.component(.minute, from: assignment.dueDate), 59)
    }

    func testSortUsesCreatedAtThenIDAsStableTies() {
        let due = date(2026, 7, 25, 23, 59); let early = date(2026, 7, 1, 8, 0); let late = date(2026, 7, 2, 8, 0)
        let course = Course(name: "CS", colorHex: "#D9A441", sortOrder: 0)
        let first = Assignment(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, title: "First", course: course, dueDate: due, sortOrder: 0, createdAt: early)
        let second = Assignment(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, title: "Second", course: course, dueDate: due, sortOrder: 0, createdAt: late)
        XCTAssertEqual(HomeworkSupport.ordered([second, first]).map(\.id), [first.id, second.id])
    }

    func testRoutineProgressIsByteIdenticalWhenAssignmentsExist() {
        let taskID = UUID()
        let record = CompletionRecord(date: date(2026, 7, 25, 9, 0), taskId: taskID)
        let baseline = HistoricalDayProgress.completion(
            scheduledTaskIDs: [taskID],
            childTaskIDsByParent: [:],
            records: [record]
        )
        let assignments = [
            Assignment(title: "Essay", dueDate: date(2026, 7, 25, 23, 59), sortOrder: 0),
            Assignment(title: "Lab", dueDate: date(2026, 7, 24, 23, 59), sortOrder: 1),
        ]

        // Assignment data is deliberately not an input to the routine-only calculation
        // shared by the Today ring, snapshots, streaks, and heatmap.
        XCTAssertEqual(assignments.count, 2)
        let defaults = UserDefaults.standard
        let key = "homeworkIntegrationEnabled"
        let priorSetting = defaults.object(forKey: key)
        defer {
            if let priorSetting {
                defaults.set(priorSetting, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.set(false, forKey: key)
        let withHomeworkHidden = HistoricalDayProgress.completion(
            scheduledTaskIDs: [taskID],
            childTaskIDsByParent: [:],
            records: [record]
        )
        defaults.set(true, forKey: key)
        let withHomeworkShown = HistoricalDayProgress.completion(
            scheduledTaskIDs: [taskID],
            childTaskIDsByParent: [:],
            records: [record]
        )

        XCTAssertEqual(
            Array(String(reflecting: baseline).utf8),
            Array(String(reflecting: withHomeworkHidden).utf8),
            "Routine progress must remain byte-identical while homework is hidden."
        )
        XCTAssertEqual(
            Array(String(reflecting: baseline).utf8),
            Array(String(reflecting: withHomeworkShown).utf8),
            "Routine progress must remain byte-identical while homework is shown."
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date { calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))! }
}
