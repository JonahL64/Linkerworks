import XCTest
import SwiftData
@testable import Linkerworks

@MainActor
final class WidgetProjectionTests: XCTestCase {
    func testRoutineDaySelectionProjectsTheSharedSelectedDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let defaults = UserDefaults(suiteName: "WidgetProjectionTests.\(UUID().uuidString)")!
        let selectedDay = calendar.date(from: DateComponents(year: 2026, month: 7, day: 20))!
        let widgetRefreshDay = calendar.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 3))!

        RoutineDaySelection.select(selectedDay, defaults: defaults, calendar: calendar)

        XCTAssertEqual(
            RoutineDaySelection.selectedDay(now: widgetRefreshDay, defaults: defaults, calendar: calendar),
            selectedDay
        )
        XCTAssertTrue(
            RoutineDaySelection.needsRolloverConfirmation(
                now: widgetRefreshDay,
                defaults: defaults,
                calendar: calendar
            )
        )
    }

    func testSelectedRoutineDayDrivesIntentStyleCompletion() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let defaults = UserDefaults(suiteName: "WidgetProjectionCompletionTests.\(UUID().uuidString)")!
        let selectedDay = calendar.date(from: DateComponents(year: 2026, month: 7, day: 25))!
        let container = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext
        let task = TaskItem(title: "Mobility", detail: "", daysOfWeek: ["Saturday"], sortOrder: 0, domain: .posture)
        context.insert(task)
        try context.save()
        RoutineDaySelection.select(selectedDay, defaults: defaults, calendar: calendar)

        try RoutineCompletionCommand.complete(
            taskID: task.id,
            in: context,
            routineDayDefaults: defaults,
            calendar: calendar
        )

        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<CompletionRecord>()).first)
        XCTAssertEqual(record.date, selectedDay)
    }

    func testRoutinePhasesSortInPersonalDayOrder() {
        XCTAssertEqual(
            [RoutineDayPhase.anytime, .evening, .morning, .afternoon, .midday]
                .sorted { $0.sortRank < $1.sortRank },
            [.morning, .midday, .afternoon, .evening, .anytime]
        )
    }

    func testLegacyRoutineTimeAndMalformedFallbackInferAFlexiblePhase() {
        XCTAssertEqual(RoutineDayPhase.inferred(legacyTime: "07:00"), .morning)
        XCTAssertEqual(RoutineDayPhase.inferred(legacyTime: "15:30"), .afternoon)
        XCTAssertEqual(RoutineDayPhase.inferred(legacyTime: "bad", sectionName: "Evening reset"), .evening)
        XCTAssertEqual(RoutineDayPhase.inferred(legacyTime: nil, sectionName: "Loose ends"), .anytime)
    }

    func testAssignmentSelectionKeepsNoDueDateOutOfDueProjection() {
        let dated = Assignment(title: "Essay", dueDate: Date(), sortOrder: 0)
        let none = Assignment(title: "Someday", dueDate: HomeworkSupport.noDueDate, sortOrder: 1)
        XCTAssertEqual([none, dated].filter { !$0.isDone && $0.dueDate != HomeworkSupport.noDueDate }.sorted { $0.dueDate < $1.dueDate }.first?.title, "Essay")
    }

    func testWidgetRefreshTargetsRouteToSeparateKinds() {
        XCTAssertEqual(
            WidgetTimeline.kind(for: .routine),
            WidgetTimeline.routineKind
        )
        XCTAssertEqual(
            WidgetTimeline.kind(for: .assignments),
            WidgetTimeline.assignmentKind
        )
        XCTAssertNotEqual(
            WidgetTimeline.kind(for: .routine),
            WidgetTimeline.kind(for: .assignments)
        )
    }

    func testAssignmentProjectionUsesStableTieBreakers() {
        let dueDate = Date(timeIntervalSince1970: 1_800_000_000)
        let laterCourse = Course(
            name: "Later course",
            colorHex: "#000000",
            sortOrder: 2
        )
        let firstCourse = Course(
            name: "First course",
            colorHex: "#FFFFFF",
            sortOrder: 0
        )
        let later = Assignment(
            title: "Later",
            course: laterCourse,
            dueDate: dueDate,
            sortOrder: 0
        )
        let first = Assignment(
            title: "First",
            course: firstCourse,
            dueDate: dueDate,
            sortOrder: 1
        )

        XCTAssertEqual(
            AssignmentProjection.ordered([later, first]).map(\.title),
            ["First", "Later"]
        )
    }

    func testCalendarPlanProjectionGroupsAndOrdersEachCollection() {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: Date())
        let allDay = CalendarEvent(
            title: "All day",
            date: day,
            isAllDay: true,
            sortOrder: 1
        )
        let timed = CalendarEvent(
            title: "Timed",
            date: day,
            startTime: day.addingTimeInterval(3_600),
            isAllDay: false,
            sortOrder: 0
        )
        let due = Assignment(title: "Due", dueDate: day, sortOrder: 0)
        let completed = Assignment(
            title: "Done",
            dueDate: day,
            isDone: true,
            sortOrder: 1
        )
        let laterTodo = DailyTodo(title: "Later", scheduledDate: day, sortOrder: 2)
        let firstTodo = DailyTodo(title: "First", scheduledDate: day, sortOrder: 0)

        let projection = CalendarPlanProjection(
            events: [timed, allDay],
            assignments: [completed, due],
            todos: [laterTodo, firstTodo],
            calendar: calendar
        )
        let key = DaySnapshotService.dayKey(for: day, calendar: calendar)

        XCTAssertEqual(projection.eventsByDayKey[key]?.map(\.title), ["All day", "Timed"])
        XCTAssertEqual(projection.assignmentsByDayKey[key]?.map(\.title), ["Due"])
        XCTAssertEqual(projection.todosByDayKey[key]?.map(\.title), ["First", "Later"])
    }

    func testWidgetCompletionOfLiftParentWritesTheSameChildRecordsAsToday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 7, day: 25, hour: 12))!
        let container = try ModelContainer(for: SharedModelContainer.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext
        let parent = TaskItem(title: "Lift", detail: "", daysOfWeek: ["Saturday"], sortOrder: 0, domain: .lifting)
        let firstChild = TaskItem(title: "Set 1", detail: "", daysOfWeek: ["Saturday"], sortOrder: 0, domain: .lifting, isSubstep: true, parent: parent)
        let secondChild = TaskItem(title: "Set 2", detail: "", daysOfWeek: ["Saturday"], sortOrder: 1, domain: .lifting, isSubstep: true, parent: parent)
        parent.children = [firstChild, secondChild]
        [parent, firstChild, secondChild].forEach(context.insert)
        try context.save()

        try RoutineCompletionCommand.complete(taskID: parent.id, at: date, in: context, calendar: calendar)

        let records = try context.fetch(FetchDescriptor<CompletionRecord>())
        XCTAssertEqual(Set(records.map(\.taskId)), Set([firstChild.id, secondChild.id]))
        XCTAssertTrue(TaskCompletion.isComplete(parent, completedTaskIDs: Set(records.map(\.taskId))))
    }

    func testLiftCompletionWritesChildRecordsWithHistoricalSnapshots() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 7, day: 25, hour: 12))!
        let container = try ModelContainer(for: SharedModelContainer.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext
        let parent = TaskItem(title: "Lift", detail: "", daysOfWeek: ["Saturday"], sortOrder: 0, domain: .lifting)
        let firstChild = TaskItem(title: "Set 1", detail: "", daysOfWeek: ["Saturday"], sortOrder: 0, domain: .lifting, isSubstep: true, parent: parent)
        let secondChild = TaskItem(title: "Set 2", detail: "", daysOfWeek: ["Saturday"], sortOrder: 1, domain: .lifting, isSubstep: true, parent: parent)
        parent.children = [firstChild, secondChild]
        let historicalSnapshots = (1...12).map { offset in
            DaySnapshot(
                dayKey: DaySnapshotService.dayKey(
                    for: calendar.date(byAdding: .day, value: -offset, to: date)!,
                    calendar: calendar
                ),
                scheduledTaskIDs: []
            )
        }
        [parent, firstChild, secondChild].forEach(context.insert)
        historicalSnapshots.forEach(context.insert)
        try context.save()

        try RoutineCompletionCommand.complete(taskID: parent.id, at: date, in: context, calendar: calendar)

        let records = try context.fetch(FetchDescriptor<CompletionRecord>())
        let snapshots = try context.fetch(FetchDescriptor<DaySnapshot>())
        XCTAssertEqual(Set(records.map(\.taskId)), Set([firstChild.id, secondChild.id]))
        XCTAssertEqual(snapshots.count, historicalSnapshots.count + 1)
    }
}
