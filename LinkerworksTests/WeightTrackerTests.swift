import Foundation
import XCTest

@testable import Linkerworks

@MainActor
final class WeightTrackerTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    func testWeightEntryNormalizesToCalendarDay() {
        let entry = WeightEntry(
            date: date(2026, 7, 27, 18, 45),
            pounds: 182.4,
            calendar: calendar
        )

        XCTAssertEqual(entry.date, date(2026, 7, 27, 0, 0))
        XCTAssertEqual(entry.dayKey, "2026-07-27")
    }

    func testSameDayLookupSelectsDeterministicExistingRecord() {
        let first = WeightEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            date: date(2026, 7, 27, 8, 0),
            pounds: 182,
            createdAt: date(2026, 7, 1, 8, 0),
            calendar: calendar
        )
        let duplicate = WeightEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            date: date(2026, 7, 27, 20, 0),
            pounds: 181.5,
            createdAt: date(2026, 7, 2, 8, 0),
            calendar: calendar
        )

        XCTAssertEqual(
            WeightEntrySupport.entry(on: date(2026, 7, 27, 12, 0), from: [duplicate, first], calendar: calendar)?.id,
            first.id
        )
    }

    func testOrderedHistoryIsChronologicalAndDoesNotFillGaps() {
        let later = WeightEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            date: date(2026, 7, 30, 8, 0),
            pounds: 180.8,
            createdAt: date(2026, 7, 30, 8, 0),
            calendar: calendar
        )
        let earlier = WeightEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            date: date(2026, 7, 27, 8, 0),
            pounds: 182,
            createdAt: date(2026, 7, 27, 8, 0),
            calendar: calendar
        )

        let ordered = WeightEntrySupport.ordered([later, earlier])
        XCTAssertEqual(ordered.map(\.id), [earlier.id, later.id])
        XCTAssertEqual(ordered.count, 2)
        XCTAssertFalse(ordered.contains { $0.dayKey == "2026-07-28" })
    }

    func testDayKeyKeepsARecordedDayStableAcrossTimeZones() {
        var origin = Calendar(identifier: .gregorian)
        origin.timeZone = TimeZone(identifier: "America/New_York")!
        var destination = Calendar(identifier: .gregorian)
        destination.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let entry = WeightEntry(
            date: origin.date(from: DateComponents(year: 2026, month: 7, day: 27, hour: 8))!,
            pounds: 182,
            calendar: origin
        )

        let displayed = WeightEntrySupport.displayDate(for: entry, calendar: destination)
        XCTAssertEqual(entry.dayKey, "2026-07-27")
        XCTAssertTrue(destination.isDate(displayed, inSameDayAs: destination.date(from: DateComponents(year: 2026, month: 7, day: 27, hour: 8))!))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
