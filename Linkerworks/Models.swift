import Foundation
import SwiftData

enum MealCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case breakfast
    case lunch
    case dinner
    case snack
    case other

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

enum WorkoutSessionState: String, Codable, Sendable {
    case inProgress
    case completed
}

enum CompletionRecordState: String, Codable, Sendable {
    case complete
    case skipped
}

@Model
final class Course {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var term: String
    var isArchived: Bool
    var sortOrder: Int
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Assignment.course)
    var assignments: [Assignment]

    init(id: UUID = UUID(), name: String, colorHex: String, term: String = "", isArchived: Bool = false, sortOrder: Int, createdAt: Date = Date(), assignments: [Assignment] = []) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.term = term
        self.isArchived = isArchived
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.assignments = assignments
    }
}

@Model
final class Assignment {
    @Attribute(.unique) var id: UUID
    var title: String
    var course: Course?
    var dueDate: Date
    var usesDefaultTime: Bool
    var isDone: Bool
    var completedAt: Date?
    var notes: String?
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, course: Course? = nil, dueDate: Date, usesDefaultTime: Bool = true, isDone: Bool = false, completedAt: Date? = nil, notes: String? = nil, sortOrder: Int, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.course = course
        self.dueDate = dueDate
        self.usesDefaultTime = usesDefaultTime
        self.isDone = isDone
        self.completedAt = isDone ? (completedAt ?? Date()) : nil
        self.notes = notes
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class CalendarEvent {
    @Attribute(.unique) var id: UUID
    var title: String
    var date: Date
    var startTime: Date?
    var endTime: Date?
    var isAllDay: Bool
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        startTime: Date? = nil,
        endTime: Date? = nil,
        isAllDay: Bool = true,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sortOrder: Int
    ) {
        let calendar = Calendar.current
        let normalizedDate = calendar.startOfDay(for: date)

        self.id = id
        self.title = title
        self.date = normalizedDate
        self.startTime = isAllDay ? nil : Self.time(startTime, on: normalizedDate, calendar: calendar)
        self.endTime = isAllDay ? nil : Self.time(endTime, on: normalizedDate, calendar: calendar)
        self.isAllDay = isAllDay
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
    }

    private static func time(_ time: Date?, on date: Date, calendar: Calendar) -> Date? {
        guard let time else { return nil }
        let components = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: date
        )
    }
}

@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var time: String?
    var detail: String
    var daysOfWeek: [String]
    var sortOrder: Int
    var domainRawValue: String
    var isSubstep: Bool
    var isArchived: Bool
    var section: Section?
    var parent: TaskItem?

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.parent)
    var children: [TaskItem]

    var domain: Domain {
        get { Domain(rawValue: domainRawValue) ?? .sleep }
        set { domainRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        time: String? = nil,
        detail: String,
        section: Section? = nil,
        daysOfWeek: [String],
        sortOrder: Int,
        domain: Domain,
        isSubstep: Bool = false,
        isArchived: Bool = false,
        parent: TaskItem? = nil,
        children: [TaskItem] = []
    ) {
        self.id = id
        self.title = title
        self.time = time
        self.detail = detail
        self.section = section
        self.daysOfWeek = daysOfWeek
        self.sortOrder = sortOrder
        self.domainRawValue = domain.rawValue
        self.isSubstep = isSubstep
        self.isArchived = isArchived
        self.parent = parent
        self.children = children
    }
}

@Model
final class Section {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortOrder: Int
    var daySchedule: DaySchedule?

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.section)
    var tasks: [TaskItem]

    init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int,
        daySchedule: DaySchedule? = nil,
        tasks: [TaskItem] = []
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.daySchedule = daySchedule
        self.tasks = tasks
    }
}

@Model
final class DaySchedule {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var weekdayName: String
    var weekdayIndex: Int
    var goalkeepingFocus: String
    var liftPlan: String
    var targetCalories: Int
    var targetProteinGrams: Int
    var targetFatGrams: Int
    var targetCarbohydrateGrams: Int
    var targetFiberGrams: Int

    @Relationship(deleteRule: .cascade, inverse: \Section.daySchedule)
    var sections: [Section]

    init(
        id: UUID = UUID(),
        weekdayName: String,
        weekdayIndex: Int,
        goalkeepingFocus: String,
        liftPlan: String,
        targetCalories: Int,
        targetProteinGrams: Int,
        targetFatGrams: Int,
        targetCarbohydrateGrams: Int,
        targetFiberGrams: Int,
        sections: [Section] = []
    ) {
        self.id = id
        self.weekdayName = weekdayName
        self.weekdayIndex = weekdayIndex
        self.goalkeepingFocus = goalkeepingFocus
        self.liftPlan = liftPlan
        self.targetCalories = targetCalories
        self.targetProteinGrams = targetProteinGrams
        self.targetFatGrams = targetFatGrams
        self.targetCarbohydrateGrams = targetCarbohydrateGrams
        self.targetFiberGrams = targetFiberGrams
        self.sections = sections
    }

    var topLevelTaskCount: Int {
        sections.reduce(0) { count, section in
            count + section.tasks.filter { !$0.isSubstep && $0.parent == nil }.count
        }
    }

    var substepCount: Int {
        sections.reduce(0) { count, section in
            count + section.tasks.reduce(0) { $0 + $1.children.count }
        }
    }
}

@Model
final class CompletionRecord {
    @Attribute(.unique) var id: UUID
    var date: Date
    var taskId: UUID
    var completedAt: Date
    /// A stored default keeps pre-skip records readable after SwiftData's
    /// lightweight schema migration. Unknown legacy values are complete too.
    var stateRawValue: String = CompletionRecordState.complete.rawValue

    var state: CompletionRecordState {
        get { CompletionRecordState(rawValue: stateRawValue) ?? .complete }
        set { stateRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        date: Date,
        taskId: UUID,
        completedAt: Date = Date(),
        state: CompletionRecordState = .complete
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.taskId = taskId
        self.completedAt = completedAt
        self.stateRawValue = state.rawValue
    }
}

@Model
final class Certification {
    @Attribute(.unique) var id: UUID
    var name: String
    var targetDate: Date?
    var status: String
    var expiresOn: Date?
    var linkedTaskID: UUID?
    var notes: String?

    @Relationship(deleteRule: .cascade)
    var milestones: [CertMilestone]

    init(
        id: UUID = UUID(), name: String, targetDate: Date? = nil,
        status: String = "planned", expiresOn: Date? = nil,
        linkedTaskID: UUID? = nil, notes: String? = nil,
        milestones: [CertMilestone] = []
    ) {
        self.id = id
        self.name = name
        self.targetDate = targetDate
        self.status = status
        self.expiresOn = expiresOn
        self.linkedTaskID = linkedTaskID
        self.notes = notes
        self.milestones = milestones
    }
}

@Model
final class CertMilestone {
    var title: String
    var isDone: Bool
    var completedAt: Date?
    var sortOrder: Int

    init(title: String, isDone: Bool = false, completedAt: Date? = nil, sortOrder: Int) {
        self.title = title
        self.isDone = isDone
        self.completedAt = isDone ? (completedAt ?? Date()) : nil
        self.sortOrder = sortOrder
    }
}

/// Immutable record of the routine that was eligible on a calendar day.
/// `scheduledTaskIDs` contains top-level completion units only.
@Model
final class DaySnapshot {
    @Attribute(.unique) var dayKey: String
    var scheduledTaskIDs: [UUID]
    var capturedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \DaySnapshotCompletionUnit.daySnapshot)
    var completionUnits: [DaySnapshotCompletionUnit]

    init(
        dayKey: String,
        scheduledTaskIDs: [UUID],
        capturedAt: Date = Date(),
        completionUnits: [DaySnapshotCompletionUnit] = []
    ) {
        self.dayKey = dayKey
        self.scheduledTaskIDs = scheduledTaskIDs
        self.capturedAt = capturedAt
        self.completionUnits = completionUnits
    }
}

/// Child IDs that defined a lift parent's single completion unit at capture.
/// This is deliberately separate from TaskItem relationships so edits to a
/// routine cannot reinterpret an already captured day.
@Model
final class DaySnapshotCompletionUnit {
    @Attribute(.unique) var id: UUID
    var parentTaskID: UUID
    var childTaskIDs: [UUID]
    var daySnapshot: DaySnapshot?

    init(
        id: UUID = UUID(),
        parentTaskID: UUID,
        childTaskIDs: [UUID],
        daySnapshot: DaySnapshot? = nil
    ) {
        self.id = id
        self.parentTaskID = parentTaskID
        self.childTaskIDs = childTaskIDs
        self.daySnapshot = daySnapshot
    }
}

@Model
final class MealEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var mealCategoryRawValue: String
    var foodName: String
    var calories: Int
    var proteinGrams: Int
    var carbohydrateGrams: Int
    var fatGrams: Int
    var fiberGrams: Int
    var createdAt: Date
    var sortOrder: Int

    var mealCategory: MealCategory {
        get { MealCategory(rawValue: mealCategoryRawValue) ?? .other }
        set { mealCategoryRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        date: Date,
        mealCategory: MealCategory,
        foodName: String,
        calories: Int,
        proteinGrams: Int,
        carbohydrateGrams: Int,
        fatGrams: Int,
        fiberGrams: Int,
        createdAt: Date = Date(),
        sortOrder: Int
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.mealCategoryRawValue = mealCategory.rawValue
        self.foodName = foodName
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}

@Model
final class DailyMacroTarget {
    static let singletonKey = "daily"

    @Attribute(.unique) var key: String
    var calories: Int
    var proteinGrams: Int
    var carbohydrateGrams: Int
    var fatGrams: Int
    var fiberGrams: Int

    init(
        key: String = DailyMacroTarget.singletonKey,
        calories: Int = 4_005,
        proteinGrams: Int = 150,
        carbohydrateGrams: Int = 525,
        fatGrams: Int = 145,
        fiberGrams: Int = 40
    ) {
        self.key = key
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
    }
}

@Model
final class SavedMeal {
    @Attribute(.unique) var id: UUID
    var mealCategoryRawValue: String
    var foodName: String
    var calories: Int
    var proteinGrams: Int
    var carbohydrateGrams: Int
    var fatGrams: Int
    var fiberGrams: Int
    var createdAt: Date
    var sortOrder: Int

    var mealCategory: MealCategory {
        get { MealCategory(rawValue: mealCategoryRawValue) ?? .other }
        set { mealCategoryRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        mealCategory: MealCategory,
        foodName: String,
        calories: Int,
        proteinGrams: Int,
        carbohydrateGrams: Int,
        fatGrams: Int,
        fiberGrams: Int,
        createdAt: Date = Date(),
        sortOrder: Int
    ) {
        self.id = id
        self.mealCategoryRawValue = mealCategory.rawValue
        self.foodName = foodName
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}

@Model
final class WorkoutSession {
    static let inProgressKey = "in-progress-workout"

    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var inProgressKeyRawValue: String
    var startedAt: Date
    var finishedAt: Date?
    var title: String?
    var notes: String?
    var stateRawValue: String

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.session)
    var exercises: [WorkoutExercise]

    var state: WorkoutSessionState {
        get { WorkoutSessionState(rawValue: stateRawValue) ?? .inProgress }
        set {
            stateRawValue = newValue.rawValue
            inProgressKeyRawValue = newValue == .inProgress
                ? Self.inProgressKey
                : "completed-\(id.uuidString)"
        }
    }

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        finishedAt: Date? = nil,
        title: String? = nil,
        notes: String? = nil,
        state: WorkoutSessionState = .inProgress,
        exercises: [WorkoutExercise] = []
    ) {
        self.id = id
        self.inProgressKeyRawValue = state == .inProgress
            ? Self.inProgressKey
            : "completed-\(id.uuidString)"
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.title = title
        self.notes = notes
        self.stateRawValue = state.rawValue
        self.exercises = exercises
    }
}

@Model
final class WorkoutExercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortOrder: Int
    var session: WorkoutSession?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exercise)
    var sets: [WorkoutSet]

    init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int,
        session: WorkoutSession? = nil,
        sets: [WorkoutSet] = []
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.session = session
        self.sets = sets
    }
}

@Model
final class WorkoutSet {
    @Attribute(.unique) var id: UUID
    var setOrder: Int
    var reps: Int
    var load: Double?
    var isCompleted: Bool
    var completedAt: Date?
    var exercise: WorkoutExercise?

    init(
        id: UUID = UUID(),
        setOrder: Int,
        reps: Int,
        load: Double? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        exercise: WorkoutExercise? = nil
    ) {
        self.id = id
        self.setOrder = setOrder
        self.reps = reps
        self.load = load
        self.isCompleted = isCompleted
        self.completedAt = isCompleted ? (completedAt ?? Date()) : nil
        self.exercise = exercise
    }
}

/// Preserves each mixed-type table from reference.json without flattening it.
/// `sourceName` distinguishes tables that share a tracker domain, such as
/// Brushing, Skincare, and Shaving within Grooming.
@Model
final class DomainReference {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var sourceName: String
    var domainRawValue: String
    var rowsJSON: Data

    var domain: Domain {
        get { Domain(rawValue: domainRawValue) ?? .sleep }
        set { domainRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        sourceName: String,
        domain: Domain,
        rowsJSON: Data
    ) {
        self.id = id
        self.sourceName = sourceName
        self.domainRawValue = domain.rawValue
        self.rowsJSON = rowsJSON
    }
}
