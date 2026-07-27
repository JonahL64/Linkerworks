import Foundation
import SwiftData

/// A flexible portion of the day for routine tasks. Its stable identity is
/// separate from the label a person chooses in Settings.
enum RoutineDayPhase: String, CaseIterable, Codable, Identifiable, Sendable {
    case anytime
    case morning
    case midday
    case afternoon
    case evening

    var id: String { rawValue }

    var sortRank: Int {
        switch self {
        case .morning: 0
        case .midday: 1
        case .afternoon: 2
        case .evening: 3
        case .anytime: 4
        }
    }

    var defaultLabel: String { rawValue.capitalized }

    static func inferred(legacyTime: String?, sectionName: String? = nil) -> RoutineDayPhase {
        if let legacyTime, let minutes = legacyMinutes(legacyTime) {
            switch minutes {
            case ..<690: return .morning
            case ..<870: return .midday
            case ..<1080: return .afternoon
            default: return .evening
            }
        }

        let section = (sectionName ?? "").uppercased()
        if section.contains("WAKE") || section.contains("MORNING") { return .morning }
        if section.contains("MIDDAY") || section.contains("NOON") { return .midday }
        if section.contains("AFTERNOON") { return .afternoon }
        if section.contains("EVENING") || section.contains("BED") || section.contains("NIGHT") { return .evening }
        return .anytime
    }

    private static func legacyMinutes(_ value: String) -> Int? {
        let parts = value.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return hour * 60 + minute
    }
}

enum RoutinePhasePreferences {
    static func label(for phase: RoutineDayPhase, defaults: UserDefaults = sharedDefaults) -> String {
        let value = defaults.string(forKey: labelKey(for: phase))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? phase.defaultLabel : value
    }

    static func startGuidance(for phase: RoutineDayPhase, defaults: UserDefaults = sharedDefaults) -> String? {
        guard phase != .anytime else { return nil }
        let value = defaults.string(forKey: startKey(for: phase))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? defaultStartGuidance(for: phase) : value
    }

    static func labelKey(for phase: RoutineDayPhase) -> String {
        "routinePhase.\(phase.rawValue).label"
    }

    static func startKey(for phase: RoutineDayPhase) -> String {
        "routinePhase.\(phase.rawValue).start"
    }

    static func defaultStartGuidance(for phase: RoutineDayPhase) -> String? {
        switch phase {
        case .anytime: nil
        case .morning: "Wake"
        case .midday: "11:30"
        case .afternoon: "14:30"
        case .evening: "18:00"
        }
    }

    private static let sharedDefaults = UserDefaults(
        suiteName: SharedModelContainer.appGroupIdentifier
    ) ?? .standard
}

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

/// A one-off commitment for a specific calendar day. This deliberately has no
/// relationship to routine tasks or homework assignments, so it cannot alter
/// routine history, progress, or streak calculations.
@Model
final class DailyTodo {
    @Attribute(.unique) var id: UUID
    var title: String
    var scheduledDate: Date
    /// Stable calendar-day identity. `scheduledDate` remains useful for editing,
    /// while this key preserves the intended local day across timezone changes.
    var scheduledDayKey: String
    var isCompleted: Bool
    var completedAt: Date?
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        scheduledDate: Date,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        sortOrder: Int,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.id = id
        self.title = title
        self.scheduledDate = calendar.startOfDay(for: scheduledDate)
        self.scheduledDayKey = DailyTodoSupport.dayKey(for: scheduledDate, calendar: calendar)
        self.isCompleted = isCompleted
        self.completedAt = isCompleted ? (completedAt ?? Date()) : nil
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum DailyTodoSupport {
    static func normalizedDate(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func date(for dayKey: String, calendar: Calendar = .current) -> Date? {
        let parts = dayKey.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    static func todos(on date: Date, from todos: [DailyTodo], calendar: Calendar = .current) -> [DailyTodo] {
        let dayKey = dayKey(for: date, calendar: calendar)
        return ordered(todos.filter { $0.scheduledDayKey == dayKey })
    }

    static func ordered(_ todos: [DailyTodo]) -> [DailyTodo] {
        todos.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
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
    /// Legacy-only storage retained for additive SwiftData migration. Routine
    /// times are cleared on launch and are not used for new tasks.
    var routinePhaseRawValue: String = "anytime"
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

    var routinePhase: RoutineDayPhase {
        get { RoutineDayPhase(rawValue: routinePhaseRawValue) ?? .anytime }
        set { routinePhaseRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        time: String? = nil,
        routinePhase: RoutineDayPhase = .anytime,
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
        self.routinePhaseRawValue = routinePhase.rawValue
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
    /// The identity of the all-day CalendarEvent maintained for this exam.
    /// This is intentionally an ID rather than a title/date lookup: both of
    /// those values are user-editable and may collide with manual events.
    var automaticExamEventID: UUID?

    @Relationship(deleteRule: .cascade)
    var milestones: [CertMilestone]

    init(
        id: UUID = UUID(), name: String, targetDate: Date? = nil,
        status: String = "planned", expiresOn: Date? = nil,
        linkedTaskID: UUID? = nil, notes: String? = nil,
        automaticExamEventID: UUID? = nil,
        milestones: [CertMilestone] = []
    ) {
        self.id = id
        self.name = name
        self.targetDate = targetDate
        self.status = status
        self.expiresOn = expiresOn
        self.linkedTaskID = linkedTaskID
        self.notes = notes
        self.automaticExamEventID = automaticExamEventID
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

/// A single manually recorded body-weight measurement for a calendar day.
///
/// The UI upserts through `WeightEntrySupport` so the store contains at most
/// one entry for a day. Keeping the date normalized makes that invariant
/// straightforward to enforce and keeps chart/history projection deterministic.
@Model
final class WeightEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    @Attribute(.unique) var dayKey: String
    var pounds: Double
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        pounds: Double,
        createdAt: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.id = id
        self.date = calendar.startOfDay(for: date)
        self.dayKey = WeightEntrySupport.dayKey(for: date, calendar: calendar)
        self.pounds = pounds
        self.createdAt = createdAt
    }
}

enum WeightEntrySupport {
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func date(for dayKey: String, calendar: Calendar = .current) -> Date? {
        let parts = dayKey.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    static func displayDate(for entry: WeightEntry, calendar: Calendar = .current) -> Date {
        date(for: entry.dayKey, calendar: calendar) ?? entry.date
    }

    static func entry(
        on date: Date,
        from entries: [WeightEntry],
        calendar: Calendar = .current
    ) -> WeightEntry? {
        entries(on: date, from: entries, calendar: calendar).first
    }

    static func entries(
        on date: Date,
        from entries: [WeightEntry],
        calendar: Calendar = .current
    ) -> [WeightEntry] {
        let key = dayKey(for: date, calendar: calendar)
        return ordered(entries.filter { $0.dayKey == key })
    }

    static func ordered(_ entries: [WeightEntry]) -> [WeightEntry] {
        entries.sorted { lhs, rhs in
            if lhs.dayKey != rhs.dayKey { return lhs.dayKey < rhs.dayKey }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
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
