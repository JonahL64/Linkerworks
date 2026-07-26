import Foundation
import SwiftData
import WidgetKit

enum WidgetTimeline {
    static let routineKind = "LinkerworksWidget"
    static let assignmentKind = "LinkerworksAssignmentWidget"

    static func reloadAll() {
        WidgetCenter.shared.reloadTimelines(ofKind: routineKind)
        WidgetCenter.shared.reloadTimelines(ofKind: assignmentKind)
    }
}

/// The routine date is intentionally shared outside SwiftData so the app and
/// WidgetKit extension keep the same late-night working context. It is a
/// temporary selection, never a rewrite of dates stored in completion history.
enum RoutineDaySelection {
    static let selectedDayKey = "selectedRoutineDay"
    static let rolloverPromptDayKey = "routineDayRolloverPromptDay"

    static func selectedDay(
        now: Date = .now,
        defaults: UserDefaults? = sharedDefaults,
        calendar: Calendar = .current
    ) -> Date {
        guard let value = defaults?.string(forKey: selectedDayKey),
              let storedDay = DaySnapshotService.date(for: value, calendar: calendar) else {
            return calendar.startOfDay(for: now)
        }
        return calendar.startOfDay(for: storedDay)
    }

    static func hasSavedSelection(defaults: UserDefaults? = sharedDefaults) -> Bool {
        defaults?.string(forKey: selectedDayKey) != nil
    }

    static func select(
        _ date: Date,
        defaults: UserDefaults? = sharedDefaults,
        calendar: Calendar = .current
    ) {
        defaults?.set(DaySnapshotService.dayKey(for: date, calendar: calendar), forKey: selectedDayKey)
    }

    static func needsRolloverConfirmation(
        now: Date = .now,
        defaults: UserDefaults? = sharedDefaults,
        calendar: Calendar = .current
    ) -> Bool {
        guard defaults?.string(forKey: selectedDayKey) != nil else { return false }
        let selected = selectedDay(now: now, defaults: defaults, calendar: calendar)
        let calendarDay = calendar.startOfDay(for: now)
        guard selected < calendarDay else { return false }
        return defaults?.string(forKey: rolloverPromptDayKey) != DaySnapshotService.dayKey(for: calendarDay, calendar: calendar)
    }

    /// Suppresses repeat prompting only for the present calendar day. A later
    /// date always gets a fresh explicit decision.
    static func deferRollover(
        for calendarDay: Date,
        defaults: UserDefaults? = sharedDefaults,
        calendar: Calendar = .current
    ) {
        defaults?.set(
            DaySnapshotService.dayKey(for: calendarDay, calendar: calendar),
            forKey: rolloverPromptDayKey
        )
    }

    private static let sharedDefaults = UserDefaults(
        suiteName: SharedModelContainer.appGroupIdentifier
    )
}

/// The only persistence mutation for a routine completion state. It is shared
/// by Today and WidgetKit so child-derived lift completion never diverges.
enum RoutineCompletionCommand {
    static func apply(
        taskIDs: Set<UUID>,
        recordTaskIDs: Set<UUID>,
        date: Date,
        state: CompletionRecordState?,
        in context: ModelContext,
        calendar: Calendar = .current
    ) throws {
        _ = try DaySnapshotService.captureIfNeeded(for: date, in: context, calendar: calendar)
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }
        let records = try context.fetch(FetchDescriptor<CompletionRecord>(predicate: #Predicate {
            $0.date >= start && $0.date < end
        }))
        records.filter { taskIDs.contains($0.taskId) }.forEach(context.delete)
        if let state {
            recordTaskIDs.forEach { context.insert(CompletionRecord(date: date, taskId: $0, state: state)) }
        }
        try context.save()
        WidgetTimeline.reloadAll()
    }

    /// Completes an incomplete task at the point of action. Parent tasks with
    /// active children write child records, exactly as Today's parent control.
    static func complete(
        taskID: UUID,
        at date: Date? = nil,
        in context: ModelContext,
        routineDayDefaults: UserDefaults? = nil,
        calendar: Calendar = .current
    ) throws {
        let completionDate: Date
        if let date {
            completionDate = date
        } else if let routineDayDefaults {
            completionDate = RoutineDaySelection.selectedDay(
                defaults: routineDayDefaults,
                calendar: calendar
            )
        } else {
            completionDate = RoutineDaySelection.selectedDay(calendar: calendar)
        }
        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        guard let task = tasks.first(where: { $0.id == taskID && !$0.isArchived }) else {
            throw RoutineCompletionError.taskUnavailable
        }
        let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let weekdayIndex = calendar.component(.weekday, from: completionDate) - 1
        guard weekdayNames.indices.contains(weekdayIndex), task.daysOfWeek.contains(weekdayNames[weekdayIndex]) else {
            throw RoutineCompletionError.taskUnavailable
        }
        let children = task.children.filter { !$0.isArchived }
        let recordIDs = children.isEmpty ? Set([task.id]) : Set(children.map(\.id))
        let affectedIDs = recordIDs.union([task.id])
        try apply(taskIDs: affectedIDs, recordTaskIDs: recordIDs, date: completionDate, state: .complete, in: context)
    }

}

enum RoutineCompletionError: LocalizedError {
    case taskUnavailable

    var errorDescription: String? {
        "This task is no longer available for the selected routine day."
    }
}

enum Domain: String, Codable, CaseIterable, Identifiable, Sendable {
    case sleep
    case eating
    case goalkeeping
    case lifting
    case posture
    case grooming
    case certifications

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sleep: "Sleep"
        case .eating: "Eating"
        case .goalkeeping: "Goalkeeping"
        case .lifting: "Lifting"
        case .posture: "Posture"
        case .grooming: "Grooming"
        case .certifications: "Certifications"
        }
    }

    static func inferred(for title: String, sectionName: String = "") -> Domain {
        let source = "\(title) \(sectionName)".lowercased()

        if source.contains("sleep") || source.contains("bed") { return .sleep }
        if source.contains("eat") || source.contains("meal") || source.contains("food") || source.contains("macro") { return .eating }
        if source.contains("goalkeep") || source.contains("goalie") || source.contains("save") { return .goalkeeping }
        if source.contains("lift") || source.contains("workout") || source.contains("exercise") || source.contains("run") || source.contains("gym") { return .lifting }
        if source.contains("posture") || source.contains("stretch") || source.contains("mobility") { return .posture }
        if source.contains("groom") || source.contains("shav") || source.contains("brush") || source.contains("skin") { return .grooming }
        return .sleep
    }
}

enum TaskCompletion {
    /// A parent with active children is driven by those children once any child
    /// has a record for the day. Older parent-only records remain compatible.
    static func isComplete(_ task: TaskItem, completedTaskIDs: Set<UUID>) -> Bool {
        let activeChildren = task.children.filter { !$0.isArchived }
        guard !activeChildren.isEmpty else {
            return completedTaskIDs.contains(task.id)
        }

        if activeChildren.contains(where: { completedTaskIDs.contains($0.id) }) {
            return activeChildren.allSatisfy { completedTaskIDs.contains($0.id) }
        }
        return completedTaskIDs.contains(task.id)
    }
}

/// Date-specific Goalkeeping rest-day support. The returned IDs match the
/// completion units used by progress: a lift-style parent contributes children,
/// while ordinary tasks contribute their own record ID.
enum GoalkeepingRestDay {
    private struct StoredState: Codable {
        var isActive: Bool
        var recordIDs: [UUID]
    }

    private static let stateKeyPrefix = "goalkeepingRestDay."

    static func scheduledTasks(from tasks: [TaskItem]) -> [TaskItem] {
        tasks.filter { $0.domain == .goalkeeping }
    }

    static func completionUnitTaskIDs(for tasks: [TaskItem]) -> Set<UUID> {
        Set(tasks.flatMap { task in
            let children = task.children.filter { !$0.isArchived }
            return children.isEmpty ? [task.id] : children.map(\.id)
        })
    }

    static func isRestDay(
        tasks: [TaskItem],
        date: Date,
        defaults: UserDefaults? = sharedDefaults,
        calendar: Calendar = .current
    ) -> Bool {
        guard !completionUnitTaskIDs(for: tasks).isEmpty else { return false }
        return storedState(for: date, defaults: defaults, calendar: calendar)?.isActive == true
    }

    static func setRestDay(
        _ isRestDay: Bool,
        tasks: [TaskItem],
        date: Date,
        in context: ModelContext,
        defaults: UserDefaults? = sharedDefaults,
        calendar: Calendar = .current
    ) throws {
        let taskIDs = completionUnitTaskIDs(for: tasks)
        guard !taskIDs.isEmpty else { return }
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }

        var stored = storedState(for: date, defaults: defaults, calendar: calendar)
            ?? StoredState(isActive: false, recordIDs: [])

        guard isRestDay else {
            stored.isActive = false
            save(stored, for: date, defaults: defaults, calendar: calendar)
            WidgetTimeline.reloadAll()
            return
        }

        _ = try DaySnapshotService.captureIfNeeded(for: date, in: context, calendar: calendar)
        let records = try context.fetch(FetchDescriptor<CompletionRecord>(predicate: #Predicate {
            $0.date >= start && $0.date < end
        }))
        let states = HistoricalDayProgress.stateByTaskID(
            records,
            ignoredRecordIDs: Set(stored.recordIDs)
        )
        for taskID in taskIDs where states[taskID] != .skipped {
            let record = CompletionRecord(date: date, taskId: taskID, state: .skipped)
            context.insert(record)
            stored.recordIDs.append(record.id)
        }
        stored.isActive = true
        try context.save()
        save(stored, for: date, defaults: defaults, calendar: calendar)
        WidgetTimeline.reloadAll()
    }

    static func ignoredRecordIDs(defaults: UserDefaults? = sharedDefaults) -> Set<UUID> {
        guard let defaults else { return [] }
        let states = defaults.dictionaryRepresentation().compactMap { entry -> StoredState? in
            guard entry.key.hasPrefix(stateKeyPrefix),
                  let data = entry.value as? Data else { return nil }
            return try? JSONDecoder().decode(StoredState.self, from: data)
        }
        return Set(states.filter { !$0.isActive }.flatMap(\.recordIDs))
    }

    private static func storedState(
        for date: Date,
        defaults: UserDefaults?,
        calendar: Calendar
    ) -> StoredState? {
        guard let data = defaults?.data(forKey: stateKey(for: date, calendar: calendar)) else { return nil }
        return try? JSONDecoder().decode(StoredState.self, from: data)
    }

    private static func save(
        _ state: StoredState,
        for date: Date,
        defaults: UserDefaults?,
        calendar: Calendar
    ) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults?.set(data, forKey: stateKey(for: date, calendar: calendar))
    }

    private static func stateKey(for date: Date, calendar: Calendar) -> String {
        stateKeyPrefix + DaySnapshotService.dayKey(for: date, calendar: calendar)
    }

    private static let sharedDefaults = UserDefaults(
        suiteName: SharedModelContainer.appGroupIdentifier
    )
}

struct ProgressDayCompletion: Equatable {
    let scheduledCount: Int
    let completedCount: Int

    var percentage: Double {
        guard scheduledCount > 0 else { return 0 }
        return Double(completedCount) / Double(scheduledCount)
    }

    var isComplete: Bool {
        scheduledCount > 0 && completedCount == scheduledCount
    }
}

/// Pure historical calculation used by Progress and focused regression tests.
/// A skipped top-level task is removed from the day. For a lifted parent,
/// skipped children are removed from its captured completion unit; when every
/// child is skipped, the parent is removed too.
enum HistoricalDayProgress {
    static func completion(
        scheduledTaskIDs: [UUID],
        childTaskIDsByParent: [UUID: [UUID]],
        records: [CompletionRecord]
    ) -> ProgressDayCompletion {
        let states = stateByTaskID(records)
        var scheduledCount = 0
        var completedCount = 0

        for taskID in scheduledTaskIDs {
            if states[taskID] == .skipped {
                continue
            }

            let childIDs = childTaskIDsByParent[taskID] ?? []
            guard !childIDs.isEmpty else {
                scheduledCount += 1
                if states[taskID] == .complete {
                    completedCount += 1
                }
                continue
            }

            let childStates = childIDs.compactMap { states[$0] }
            if childStates.isEmpty {
                // Parent-only completions predate the substep interaction.
                scheduledCount += 1
                if states[taskID] == .complete {
                    completedCount += 1
                }
                continue
            }

            let activeChildIDs = childIDs.filter { states[$0] != .skipped }
            guard !activeChildIDs.isEmpty else {
                continue
            }

            scheduledCount += 1
            if activeChildIDs.allSatisfy({ states[$0] == .complete }) {
                completedCount += 1
            }
        }

        return ProgressDayCompletion(
            scheduledCount: scheduledCount,
            completedCount: completedCount
        )
    }

    static func stateByTaskID(
        _ records: [CompletionRecord],
        ignoredRecordIDs: Set<UUID> = GoalkeepingRestDay.ignoredRecordIDs()
    ) -> [UUID: CompletionRecordState] {
        records
            .filter { !ignoredRecordIDs.contains($0.id) }
            .sorted {
                $0.completedAt == $1.completedAt
                    ? $0.id.uuidString < $1.id.uuidString
                    : $0.completedAt < $1.completedAt
            }
            .reduce(into: [:]) { states, record in
                states[record.taskId] = record.state
            }
    }
}

struct HistoricalProgressSnapshot {
    let scheduledTaskIDs: [UUID]
    let childTaskIDsByParent: [UUID: [UUID]]

    init(snapshot: DaySnapshot) {
        scheduledTaskIDs = snapshot.scheduledTaskIDs
        childTaskIDsByParent = Dictionary(grouping: snapshot.completionUnits, by: \.parentTaskID)
            .mapValues { units in units.last?.childTaskIDs ?? [] }
    }

    init(tasks: [TaskItem], date: Date, calendar: Calendar) {
        let scheduledTasks = DaySnapshotService.scheduledTopLevelTasks(
            from: tasks,
            on: date,
            calendar: calendar
        )
        scheduledTaskIDs = scheduledTasks.map(\.id)
        childTaskIDsByParent = DaySnapshotService.childTaskIDsByParent(for: scheduledTasks)
    }
}

enum DaySnapshotService {
    static let backfillMarkerKey = "historicalProgressSnapshotBackfillVersion"
    static let backfillVersion = 1

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
              let day = Int(parts[2]) else {
            return nil
        }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    @discardableResult
    static func captureIfNeeded(
        for date: Date,
        in modelContext: ModelContext,
        calendar: Calendar = .current,
        capturedAt: Date = Date()
    ) throws -> DaySnapshot {
        let key = dayKey(for: date, calendar: calendar)
        if let existing = try modelContext.fetch(FetchDescriptor<DaySnapshot>())
            .first(where: { $0.dayKey == key }) {
            return existing
        }

        let tasks = try modelContext.fetch(FetchDescriptor<TaskItem>())
        let scheduledTasks = scheduledTopLevelTasks(from: tasks, on: date, calendar: calendar)
        let snapshot = DaySnapshot(
            dayKey: key,
            scheduledTaskIDs: scheduledTasks.map(\.id),
            capturedAt: capturedAt
        )
        let units = childTaskIDsByParent(for: scheduledTasks).map {
            DaySnapshotCompletionUnit(parentTaskID: $0.key, childTaskIDs: $0.value, daySnapshot: snapshot)
        }
        snapshot.completionUnits = units
        modelContext.insert(snapshot)
        units.forEach(modelContext.insert)
        return snapshot
    }

    /// Backfill only the dates with legacy records. The marker is written only
    /// after SwiftData saves, and unique day keys make retries harmless.
    @discardableResult
    static func backfillIfNeeded(
        in modelContext: ModelContext,
        defaults: UserDefaults,
        calendar: Calendar = .current
    ) throws -> Bool {
        guard defaults.integer(forKey: backfillMarkerKey) < backfillVersion else {
            return false
        }

        let records = try modelContext.fetch(FetchDescriptor<CompletionRecord>())
        let existingSnapshotKeys = Set(
            try modelContext.fetch(FetchDescriptor<DaySnapshot>()).map(\.dayKey)
        )
        let tasks = try modelContext.fetch(FetchDescriptor<TaskItem>())
        let keysAndDates = Dictionary(grouping: records) {
            dayKey(for: $0.date, calendar: calendar)
        }
        for (key, recordsOnDay) in keysAndDates where !existingSnapshotKeys.contains(key) {
            guard let date = recordsOnDay.first?.date else { continue }
            let scheduledTasks = scheduledTopLevelTasks(from: tasks, on: date, calendar: calendar)
            let snapshot = DaySnapshot(
                dayKey: key,
                scheduledTaskIDs: scheduledTasks.map(\.id)
            )
            let units = childTaskIDsByParent(for: scheduledTasks).map {
                DaySnapshotCompletionUnit(
                    parentTaskID: $0.key,
                    childTaskIDs: $0.value,
                    daySnapshot: snapshot
                )
            }
            snapshot.completionUnits = units
            modelContext.insert(snapshot)
            units.forEach(modelContext.insert)
        }
        try modelContext.save()
        defaults.set(backfillVersion, forKey: backfillMarkerKey)
        return true
    }

    static func scheduledTopLevelTasks(
        from tasks: [TaskItem],
        on date: Date,
        calendar: Calendar
    ) -> [TaskItem] {
        let weekdayNames = [
            "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
        ]
        let index = calendar.component(.weekday, from: date) - 1
        guard weekdayNames.indices.contains(index) else { return [] }
        let weekday = weekdayNames[index]
        return tasks.filter {
            !$0.isArchived
                && !$0.isSubstep
                && $0.parent == nil
                && $0.daysOfWeek.contains(weekday)
        }
    }

    static func childTaskIDsByParent(for tasks: [TaskItem]) -> [UUID: [UUID]] {
        Dictionary(uniqueKeysWithValues: tasks.compactMap { task in
            let childIDs = task.children.filter { !$0.isArchived }.map(\.id)
            return childIDs.isEmpty ? nil : (task.id, childIDs)
        })
    }
}
