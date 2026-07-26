import XCTest
import SwiftData
@testable import Linkerworks

@MainActor
final class WidgetProjectionTests: XCTestCase {
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
}
