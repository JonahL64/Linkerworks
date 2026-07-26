import Foundation
import XCTest

@testable import Linkerworks

@MainActor
final class DailyTodoTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    func testScheduledDateNormalizesTimeToOneCalendarDay() {
        let todo = DailyTodo(
            title: "Call dentist",
            scheduledDate: date(2026, 7, 26, 23, 45),
            sortOrder: 0,
            calendar: calendar
        )

        XCTAssertEqual(todo.scheduledDate, date(2026, 7, 26, 0, 0))
        XCTAssertEqual(
            DailyTodoSupport.todos(on: date(2026, 7, 26, 5, 30), from: [todo], calendar: calendar).map(\.id),
            [todo.id]
        )
    }

    func testOrderingUsesSortOrderThenCreationAndID() {
        let day = date(2026, 7, 26, 0, 0)
        let early = date(2026, 7, 1, 8, 0)
        let late = date(2026, 7, 2, 8, 0)
        let first = DailyTodo(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            title: "First",
            scheduledDate: day,
            sortOrder: 0,
            createdAt: early,
            calendar: calendar
        )
        let second = DailyTodo(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            title: "Second",
            scheduledDate: day,
            sortOrder: 0,
            createdAt: late,
            calendar: calendar
        )
        let laterOrder = DailyTodo(title: "Later", scheduledDate: day, sortOrder: 1, calendar: calendar)

        XCTAssertEqual(DailyTodoSupport.ordered([laterOrder, second, first]).map(\.id), [first.id, second.id, laterOrder.id])
    }

    func testCompletionAndReopenTransitionTimestamp() {
        let todo = DailyTodo(title: "Pick up prescription", scheduledDate: date(2026, 7, 26, 8, 0), sortOrder: 0, calendar: calendar)
        XCTAssertFalse(todo.isCompleted)
        XCTAssertNil(todo.completedAt)

        let completedAt = date(2026, 7, 26, 12, 10)
        todo.isCompleted = true
        todo.completedAt = completedAt
        XCTAssertTrue(todo.isCompleted)
        XCTAssertEqual(todo.completedAt, completedAt)

        todo.isCompleted = false
        todo.completedAt = nil
        XCTAssertFalse(todo.isCompleted)
        XCTAssertNil(todo.completedAt)
    }

    func testFutureTodoIsOnlyVisibleOnItsScheduledDate() {
        let today = date(2026, 7, 26, 9, 0)
        let future = DailyTodo(title: "Pack bag", scheduledDate: date(2026, 7, 29, 14, 0), sortOrder: 0, calendar: calendar)

        XCTAssertTrue(DailyTodoSupport.todos(on: today, from: [future], calendar: calendar).isEmpty)
        XCTAssertEqual(
            DailyTodoSupport.todos(on: date(2026, 7, 29, 0, 5), from: [future], calendar: calendar).map(\.id),
            [future.id]
        )
    }

    func testScheduledDayKeyStaysStableAcrossTimezoneChanges() {
        var origin = Calendar(identifier: .gregorian)
        origin.timeZone = TimeZone(identifier: "America/New_York")!
        var destination = Calendar(identifier: .gregorian)
        destination.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let scheduled = origin.date(from: DateComponents(year: 2026, month: 7, day: 26, hour: 9))!
        let todo = DailyTodo(title: "Travel day", scheduledDate: scheduled, sortOrder: 0, calendar: origin)
        let destinationDay = destination.date(from: DateComponents(year: 2026, month: 7, day: 26, hour: 9))!

        XCTAssertEqual(todo.scheduledDayKey, "2026-07-26")
        XCTAssertEqual(
            DailyTodoSupport.todos(on: destinationDay, from: [todo], calendar: destination).map(\.id),
            [todo.id]
        )
    }

    func testSelectedRoutineDayKeepsPriorDayTodosVisibleAfterMidnight() {
        let defaults = UserDefaults(suiteName: "DailyTodoRolloverTests.\(UUID().uuidString)")!
        let priorDay = date(2026, 7, 26, 22, 0)
        let afterMidnight = date(2026, 7, 27, 3, 0)
        let todo = DailyTodo(title: "Finish laundry", scheduledDate: priorDay, sortOrder: 0, calendar: calendar)
        RoutineDaySelection.select(priorDay, defaults: defaults, calendar: calendar)

        let selectedDay = RoutineDaySelection.selectedDay(
            now: afterMidnight,
            defaults: defaults,
            calendar: calendar
        )
        XCTAssertEqual(DailyTodoSupport.todos(on: selectedDay, from: [todo], calendar: calendar).map(\.id), [todo.id])
        XCTAssertTrue(DailyTodoSupport.todos(on: afterMidnight, from: [todo], calendar: calendar).isEmpty)
    }

    func testRoutineProgressIsUnchangedWhenTodosExist() {
        let taskID = UUID()
        let record = CompletionRecord(date: date(2026, 7, 26, 9, 0), taskId: taskID)
        let baseline = HistoricalDayProgress.completion(
            scheduledTaskIDs: [taskID],
            childTaskIDsByParent: [:],
            records: [record]
        )
        let todos = [
            DailyTodo(title: "Errand", scheduledDate: date(2026, 7, 26, 10, 0), sortOrder: 0, calendar: calendar),
            DailyTodo(title: "Future errand", scheduledDate: date(2026, 7, 27, 10, 0), sortOrder: 0, calendar: calendar),
        ]

        XCTAssertEqual(todos.count, 2)
        let withTodos = HistoricalDayProgress.completion(
            scheduledTaskIDs: [taskID],
            childTaskIDsByParent: [:],
            records: [record]
        )
        XCTAssertEqual(withTodos, baseline)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
