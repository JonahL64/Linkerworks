import SwiftData
import XCTest

@testable import Linkerworks

@MainActor
final class ManageRoutineTests: XCTestCase {
    func testMultiDayTaskAppearsInEveryMatchingManageSection() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let sunday = DaySchedule(
            weekdayName: "Sunday",
            weekdayIndex: 0,
            goalkeepingFocus: "",
            liftPlan: "",
            targetCalories: 0,
            targetProteinGrams: 0,
            targetFatGrams: 0,
            targetCarbohydrateGrams: 0,
            targetFiberGrams: 0
        )
        let monday = DaySchedule(
            weekdayName: "Monday",
            weekdayIndex: 1,
            goalkeepingFocus: "",
            liftPlan: "",
            targetCalories: 0,
            targetProteinGrams: 0,
            targetFatGrams: 0,
            targetCarbohydrateGrams: 0,
            targetFiberGrams: 0
        )
        let morning = Section(name: "Morning", sortOrder: 0, daySchedule: sunday)
        let mondayMorning = Section(name: "Morning", sortOrder: 0, daySchedule: monday)
        let mondayTask = TaskItem(
            title: "Monday task",
            routinePhase: .morning,
            detail: "",
            section: mondayMorning,
            daysOfWeek: ["Monday"],
            sortOrder: 1,
            domain: .sleep
        )
        let task = TaskItem(
            title: "Daily task",
            routinePhase: .morning,
            detail: "",
            section: morning,
            daysOfWeek: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
            sortOrder: 0,
            domain: .sleep
        )

        context.insert(sunday)
        context.insert(monday)
        context.insert(morning)
        context.insert(mondayMorning)
        context.insert(mondayTask)
        context.insert(task)
        try context.save()

        let savedTasks = try context.fetch(FetchDescriptor<TaskItem>())
        let sundayTasks = ManageRoutineProjection.tasks(savedTasks, in: morning, showingArchived: false)
        let mondayTasks = ManageRoutineProjection.tasks(savedTasks, in: mondayMorning, showingArchived: false)

        XCTAssertEqual(sundayTasks.map(\.id), [task.id])
        XCTAssertEqual(mondayTasks.map(\.id), [task.id, mondayTask.id])
        XCTAssertEqual(ManageRoutineProjection.nextSortOrder(savedTasks, in: mondayMorning, phase: .morning), 2)
        XCTAssertEqual(mondayTasks.first?.routinePhase, .morning)
        XCTAssertEqual(mondayTasks.first?.daysOfWeek, ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])

        task.isArchived = true
        try context.save()

        XCTAssertFalse(ManageRoutineProjection.tasks(savedTasks, in: mondayMorning, showingArchived: false).contains { $0.id == task.id })
        XCTAssertEqual(ManageRoutineProjection.tasks(savedTasks, in: mondayMorning, showingArchived: true).map(\.id), [task.id])
    }

    private func inMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SharedModelContainer.schema, configurations: [configuration])
    }
}
