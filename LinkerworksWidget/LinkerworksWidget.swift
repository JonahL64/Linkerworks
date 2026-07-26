import SwiftData
import SwiftUI
import WidgetKit

private let todayDeepLink = URL(string: "linkerworks://today")!

private enum WidgetTheme {
    static let background = Color("TrainingBackground")
    static let primaryText = Color("PrimaryText")
    static let secondaryText = Color("SecondaryText")
    static let completionAccent = Color("CompletionAccent")
}

struct LinkerworksWidgetEntry: TimelineEntry {
    enum LoadState { case loaded, unavailable }
    struct NextTask: Identifiable {
        let id: UUID
        let title: String
        let time: String?
    }
    struct DueAssignment {
        let title: String
        let dueDate: Date
        let courseName: String?
        let courseColorHex: String?
    }

    let date: Date
    let tasks: [NextTask]
    let completedCount: Int
    let scheduledCount: Int
    let isNeutralDay: Bool
    let assignment: DueAssignment?
    let loadState: LoadState
    var nextTask: NextTask? { tasks.first }

    static let placeholder = LinkerworksWidgetEntry(date: .now, tasks: [NextTask(id: UUID(), title: "Mobility", time: "18:00")], completedCount: 14, scheduledCount: 22, isNeutralDay: false, assignment: DueAssignment(title: "Lab report", dueDate: .now, courseName: "Biology", courseColorHex: "#4FB3C4"), loadState: .loaded)
    static func unavailable(at date: Date) -> Self { .init(date: date, tasks: [], completedCount: 0, scheduledCount: 0, isNeutralDay: false, assignment: nil, loadState: .unavailable) }
}

struct LinkerworksWidgetProvider: TimelineProvider {
    typealias Entry = LinkerworksWidgetEntry
    func placeholder(in context: Context) -> Entry { .placeholder }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(context.isPreview ? .placeholder : loadEntry(at: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date(); completion(Timeline(entries: [loadEntry(at: now)], policy: .after(nextRefresh(after: now))))
    }

    private func loadEntry(at date: Date) -> Entry {
        do {
            let context = ModelContext(try SharedModelContainer.make())
            let calendar = Calendar.current
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return .unavailable(at: date) }
            let weekday = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][calendar.component(.weekday, from: date) - 1]
            let records = try context.fetch(FetchDescriptor<CompletionRecord>(predicate: #Predicate { $0.date >= dayStart && $0.date < dayEnd }))
            let states = HistoricalDayProgress.stateByTaskID(records)
            let tasks = try context.fetch(FetchDescriptor<TaskItem>()).filter { !$0.isArchived && !$0.isSubstep && $0.parent == nil && $0.daysOfWeek.contains(weekday) }
            let incomplete = tasks.filter { task in
                let children = task.children.filter { !$0.isArchived }
                let skipped = states[task.id] == .skipped || (!children.isEmpty && children.allSatisfy { states[$0.id] == .skipped })
                return !skipped && !TaskCompletion.isComplete(task, completedTaskIDs: Set(states.filter { $0.value == .complete }.map(\.key)))
            }.sorted { taskOrder($0, $1, on: date) }
            let completion = HistoricalDayProgress.completion(scheduledTaskIDs: tasks.map(\.id), childTaskIDsByParent: DaySnapshotService.childTaskIDsByParent(for: tasks), records: records)
            let assignment = try context.fetch(FetchDescriptor<Assignment>()).filter { !$0.isDone && $0.dueDate != .distantFuture }.sorted { $0.dueDate < $1.dueDate }.first
            return Entry(date: date, tasks: incomplete.prefix(3).map { .init(id: $0.id, title: $0.title, time: $0.time) }, completedCount: completion.completedCount, scheduledCount: completion.scheduledCount, isNeutralDay: completion.scheduledCount == 0, assignment: assignment.map { .init(title: $0.title, dueDate: $0.dueDate, courseName: $0.course?.name, courseColorHex: $0.course?.colorHex) }, loadState: .loaded)
        } catch { return .unavailable(at: date) }
    }

    private func taskOrder(_ lhs: TaskItem, _ rhs: TaskItem, on date: Date) -> Bool {
        WidgetRoutineSortKey(timeText: lhs.time, on: date, now: date, sectionOrder: lhs.section?.sortOrder ?? .max, taskOrder: lhs.sortOrder, title: lhs.title)
            < WidgetRoutineSortKey(timeText: rhs.time, on: date, now: date, sectionOrder: rhs.section?.sortOrder ?? .max, taskOrder: rhs.sortOrder, title: rhs.title)
    }
    private func nextRefresh(after date: Date) -> Date { min(Calendar.current.date(byAdding: .hour, value: 1, to: date) ?? date.addingTimeInterval(3600), Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date)) ?? date.addingTimeInterval(3600)) }
}

struct LinkerworksWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LinkerworksWidgetEntry
    var body: some View { Group { switch family { case .accessoryCircular: circular; case .accessoryRectangular: rectangular; case .systemMedium: medium; default: small } }.widgetURL(todayDeepLink).foregroundStyle(WidgetTheme.primaryText).containerBackground(WidgetTheme.background, for: .widget) }
    private var small: some View { VStack(alignment: .leading, spacing: 6) { Text("NEXT").font(.caption.weight(.semibold)).foregroundStyle(WidgetTheme.secondaryText); content(task: entry.nextTask) }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading) }
    private var medium: some View { HStack(spacing: 14) { ProgressView(value: Double(entry.completedCount), total: Double(max(entry.scheduledCount, 1))).tint(WidgetTheme.completionAccent).frame(width: 52).overlay { Text("\(entry.completedCount)/\(entry.scheduledCount)").font(.caption2).monospacedDigit() }; VStack(alignment: .leading, spacing: 5) { Text("NEXT").font(.caption.weight(.semibold)).foregroundStyle(WidgetTheme.secondaryText); if entry.loadState == .loaded { ForEach(entry.tasks) { task in Button(intent: CompleteRoutineTaskIntent(taskID: task.id.uuidString)) { HStack { Image(systemName: "circle"); Text(task.title).lineLimit(1); Spacer(); if let time = task.time { Text(time).monospacedDigit().foregroundStyle(WidgetTheme.secondaryText) } } }.buttonStyle(.plain) } } else { Text("Open Linkerworks to load today").font(.caption) } } }.frame(maxWidth: .infinity, maxHeight: .infinity) }
    @ViewBuilder private func content(task: LinkerworksWidgetEntry.NextTask?) -> some View { if entry.loadState == .unavailable { Text("Open Linkerworks to load today").font(.caption).foregroundStyle(WidgetTheme.secondaryText) } else if let task { Button(intent: CompleteRoutineTaskIntent(taskID: task.id.uuidString)) { VStack(alignment: .leading) { Text(task.title).font(.headline.weight(.semibold)).lineLimit(2); if let time = task.time { Text(time).font(.caption).monospacedDigit().foregroundStyle(WidgetTheme.secondaryText) } } }.buttonStyle(.plain) } else if entry.isNeutralDay { Label("No tasks to count", systemImage: "minus.circle.fill").font(.subheadline) } else { Label("Day complete", systemImage: "checkmark.circle.fill").foregroundStyle(WidgetTheme.completionAccent) } }
    private var circular: some View { Group { if entry.loadState == .unavailable { Image(systemName: "exclamationmark") } else if let task = entry.nextTask { Text(task.title).font(.system(size: 10)).lineLimit(2).minimumScaleFactor(0.35) } else { Image(systemName: entry.isNeutralDay ? "minus" : "checkmark") } }.widgetAccentable() }
    private var rectangular: some View { VStack(alignment: .leading, spacing: 2) { if entry.loadState == .unavailable { Label("Open Linkerworks", systemImage: "exclamationmark.circle") } else if let task = entry.nextTask { Text("\(entry.completedCount)/\(entry.scheduledCount) · Next: \(task.title)").font(.caption).lineLimit(1) } else { Text(entry.isNeutralDay ? "No tasks to count" : "Day complete").font(.caption) } }.frame(maxWidth: .infinity, alignment: .leading) }
}

struct LinkerworksWidget: Widget { let kind = WidgetTimeline.routineKind; var body: some WidgetConfiguration { StaticConfiguration(kind: kind, provider: LinkerworksWidgetProvider()) { LinkerworksWidgetEntryView(entry: $0) }.configurationDisplayName("Next Task").description("Today’s routine progress and next work.").supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular]) } }

struct LinkerworksAssignmentWidget: Widget { let kind = WidgetTimeline.assignmentKind; var body: some WidgetConfiguration { StaticConfiguration(kind: kind, provider: LinkerworksWidgetProvider()) { entry in AssignmentWidgetView(entry: entry) }.configurationDisplayName("Next Assignment Due").description("Your nearest unfinished assignment.").supportedFamilies([.systemSmall, .systemMedium]) } }
private struct AssignmentWidgetView: View { let entry: LinkerworksWidgetEntry; var body: some View { VStack(alignment: .leading, spacing: 6) { Text("DUE NEXT").font(.caption.weight(.semibold)).foregroundStyle(WidgetTheme.secondaryText); if entry.loadState == .unavailable { Text("Open Linkerworks to load assignments").font(.caption) } else if let item = entry.assignment { HStack(spacing: 6) { Circle().fill(Color(hex: item.courseColorHex ?? "#7A857F")).frame(width: 8, height: 8); Text(item.courseName ?? "No course").font(.caption).foregroundStyle(WidgetTheme.secondaryText) }; Text(item.title).font(.headline).lineLimit(2); Text(item.dueDate, format: .dateTime.weekday(.abbreviated).hour().minute()).font(.caption).monospacedDigit() } else { Label("Nothing due", systemImage: "checkmark.circle").font(.subheadline) } }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).widgetURL(todayDeepLink).containerBackground(WidgetTheme.background, for: .widget) } }
private extension Color { init(hex: String) { let value = UInt64(hex.dropFirst(), radix: 16) ?? 0; self.init(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255) } }
