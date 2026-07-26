import Foundation
import XCTest

@testable import Linkerworks

@MainActor
final class CertificationTests: XCTestCase {
    private var calendar: Calendar { var value = Calendar(identifier: .gregorian); value.timeZone = TimeZone(secondsFromGMT: 0)!; return value }

    func testExpiryWindowIsInclusive() {
        let today = date(2026, 7, 25)
        XCTAssertTrue(CertificationSupport.expiresWithin90Days(date(2026, 10, 23), from: today, calendar: calendar))
        XCTAssertFalse(CertificationSupport.expiresWithin90Days(date(2026, 10, 24), from: today, calendar: calendar))
        XCTAssertFalse(CertificationSupport.expiresWithin90Days(date(2026, 7, 24), from: today, calendar: calendar))
    }

    func testCountdownAndMilestoneProgress() {
        let today = date(2026, 7, 25)
        XCTAssertEqual(CertificationSupport.daysUntil(date(2026, 7, 30), from: today, calendar: calendar), 5)
        XCTAssertNil(CertificationSupport.daysUntil(nil, from: today, calendar: calendar))
        let certification = Certification(name: "Security+", milestones: [CertMilestone(title: "Read", isDone: true, sortOrder: 0), CertMilestone(title: "Practice", sortOrder: 1)])
        XCTAssertEqual(certification.milestones.filter(\.isDone).count, 1)
    }

    func testThirtyDayCountUsesOnlyCompleteLinkedRecords() {
        let taskID = UUID(); let today = date(2026, 7, 25)
        let records = [
            CompletionRecord(date: date(2026, 7, 25), taskId: taskID, state: .complete),
            CompletionRecord(date: date(2026, 6, 26), taskId: taskID, state: .complete),
            CompletionRecord(date: date(2026, 6, 25), taskId: taskID, state: .complete),
            CompletionRecord(date: date(2026, 7, 24), taskId: taskID, state: .skipped),
            CompletionRecord(date: date(2026, 7, 25), taskId: UUID(), state: .complete),
        ]
        XCTAssertEqual(CertificationSupport.completionCount(taskID: taskID, records: records, endingOn: today, calendar: calendar), 2)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date { calendar.date(from: DateComponents(year: year, month: month, day: day))! }
}
