import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

private let todayDeepLink = URL(string: "linkerworks://today")!

/// Widget half of the Paper & Ink palette.
///
/// The widget target cannot see the app's `LWColor`, so the shared tokens live in
/// both asset catalogues under the same names. Keep the two catalogues in step
/// — a colour added here must be added there.
private enum WidgetTheme {
    static let background = Color("TrainingBackground")
    static let surfaceRaised = Color("SurfaceRaised")
    static let surfaceSunken = Color("SurfaceSunken")
    static let hairline = Color("Hairline")
    static let primaryText = Color("PrimaryText")
    static let secondaryText = Color("SecondaryText")
    static let accent = Color("AccentColor")
    static let completionAccent = Color("CompletionAccent")

    /// Fallback for an assignment with no course colour.
    static let neutralCourse = Color("SecondaryText")

    enum Typography {
        static let display = Font.system(size: 22, weight: .medium, design: .serif)
        static let title = Font.system(size: 16, weight: .semibold, design: .serif)
        static let body = Font.system(size: 14, weight: .medium)
        static let detail = Font.system(size: 12)
        static let caption = Font.system(size: 11, weight: .medium)
        static let metric = Font.system(size: 11, weight: .medium, design: .monospaced)
    }

    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let radius: CGFloat = 12
    }
}

struct LinkerworksWidgetEntry: TimelineEntry {
    enum LoadState { case loaded, unavailable }
    struct NextTask: Identifiable {
        let id: UUID
        let title: String
    }
    struct DueAssignment {
        let title: String
        let dueDate: Date
        let courseName: String?
        let courseColorHex: String?
    }

    let date: Date
    let routineDay: Date
    let tasks: [NextTask]
    let completedCount: Int
    let scheduledCount: Int
    let isNeutralDay: Bool
    let assignment: DueAssignment?
    let loadState: LoadState
    var nextTask: NextTask? { tasks.first }
    var routineDayKey: String { DaySnapshotService.dayKey(for: routineDay) }

    static let placeholder = LinkerworksWidgetEntry(date: .now, routineDay: .now, tasks: [NextTask(id: UUID(), title: "Mobility")], completedCount: 14, scheduledCount: 22, isNeutralDay: false, assignment: DueAssignment(title: "Lab report", dueDate: .now, courseName: "Biology", courseColorHex: "#4FB3C4"), loadState: .loaded)
    static func unavailable(at date: Date) -> Self { .init(date: date, routineDay: RoutineDaySelection.selectedDay(now: date), tasks: [], completedCount: 0, scheduledCount: 0, isNeutralDay: false, assignment: nil, loadState: .unavailable) }
    static func assignmentUnavailable(at date: Date) -> Self { .init(date: date, routineDay: Calendar.current.startOfDay(for: date), tasks: [], completedCount: 0, scheduledCount: 0, isNeutralDay: false, assignment: nil, loadState: .unavailable) }
}

enum LinkerworksWidgetContent {
    case routine
    case assignments
}

struct LinkerworksWidgetProvider: TimelineProvider {
    typealias Entry = LinkerworksWidgetEntry
    let content: LinkerworksWidgetContent

    func placeholder(in context: Context) -> Entry { .placeholder }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(context.isPreview ? .placeholder : loadEntry(at: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date(); completion(Timeline(entries: [loadEntry(at: now)], policy: .after(nextRefresh(after: now))))
    }

    private func loadEntry(at date: Date) -> Entry {
        switch content {
        case .routine:
            return loadRoutineEntry(at: date)
        case .assignments:
            return loadAssignmentEntry(at: date)
        }
    }

    private func loadRoutineEntry(at date: Date) -> Entry {
        do {
            let context = ModelContext(try SharedModelContainer.make())
            let calendar = Calendar.current
            let routineDay = RoutineDaySelection.selectedDay(now: date, calendar: calendar)
            let dayStart = calendar.startOfDay(for: routineDay)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return .unavailable(at: date) }
            let weekday = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][calendar.component(.weekday, from: routineDay) - 1]
            let records = try context.fetch(FetchDescriptor<CompletionRecord>(predicate: #Predicate { $0.date >= dayStart && $0.date < dayEnd }))
            let states = HistoricalDayProgress.stateByTaskID(records)
            let completedTaskIDs = Set(states.compactMap { $0.value == .complete ? $0.key : nil })
            let activeTasks = FetchDescriptor<TaskItem>(predicate: #Predicate { !$0.isArchived })
            let tasks = try context.fetch(activeTasks).filter { !$0.isSubstep && $0.parent == nil && $0.daysOfWeek.contains(weekday) }
            let incomplete = tasks.filter { task in
                let children = task.children.filter { !$0.isArchived }
                let skipped = states[task.id] == .skipped || (!children.isEmpty && children.allSatisfy { states[$0.id] == .skipped })
                return !skipped && !TaskCompletion.isComplete(task, completedTaskIDs: completedTaskIDs)
            }.sorted { taskOrder($0, $1, on: routineDay) }
            let completion = HistoricalDayProgress.completion(scheduledTaskIDs: tasks.map(\.id), childTaskIDsByParent: DaySnapshotService.childTaskIDsByParent(for: tasks), states: states)
            return Entry(date: date, routineDay: routineDay, tasks: incomplete.prefix(3).map { .init(id: $0.id, title: $0.title) }, completedCount: completion.completedCount, scheduledCount: completion.scheduledCount, isNeutralDay: completion.scheduledCount == 0, assignment: nil, loadState: .loaded)
        } catch { return .unavailable(at: date) }
    }

    private func loadAssignmentEntry(at date: Date) -> Entry {
        do {
            let context = ModelContext(try SharedModelContainer.make())
            let noDueDate = Date.distantFuture
            var nearestDescriptor = FetchDescriptor<Assignment>(
                predicate: #Predicate { !$0.isDone && $0.dueDate < noDueDate },
                sortBy: [SortDescriptor(\.dueDate)]
            )
            nearestDescriptor.fetchLimit = 1
            let nearestDueDate = try context.fetch(nearestDescriptor).first?.dueDate
            let assignment: Assignment?
            if let nearestDueDate {
                let ties = try context.fetch(FetchDescriptor<Assignment>(predicate: #Predicate {
                    !$0.isDone && $0.dueDate == nearestDueDate
                }))
                assignment = AssignmentProjection.ordered(ties).first
            } else {
                assignment = nil
            }
            return Entry(date: date, routineDay: Calendar.current.startOfDay(for: date), tasks: [], completedCount: 0, scheduledCount: 0, isNeutralDay: false, assignment: assignment.map { .init(title: $0.title, dueDate: $0.dueDate, courseName: $0.course?.name, courseColorHex: $0.course?.colorHex) }, loadState: .loaded)
        } catch { return .assignmentUnavailable(at: date) }
    }

    private func taskOrder(_ lhs: TaskItem, _ rhs: TaskItem, on date: Date) -> Bool {
        if lhs.routinePhase.sortRank != rhs.routinePhase.sortRank { return lhs.routinePhase.sortRank < rhs.routinePhase.sortRank }
        if lhs.section?.sortOrder != rhs.section?.sortOrder { return (lhs.section?.sortOrder ?? .max) < (rhs.section?.sortOrder ?? .max) }
        if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }
    private func nextRefresh(after date: Date) -> Date { min(Calendar.current.date(byAdding: .hour, value: 1, to: date) ?? date.addingTimeInterval(3600), Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date)) ?? date.addingTimeInterval(3600)) }
}

struct LinkerworksWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LinkerworksWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            case .systemMedium: medium
            default: small
            }
        }
        .widgetURL(todayDeepLink)
        .foregroundStyle(WidgetTheme.primaryText)
        .containerBackground(WidgetTheme.background, for: .widget)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.Space.xs) {
            header
            content(task: entry.nextTask)
        }
        .padding(WidgetTheme.Space.sm)
        .background(WidgetTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: WidgetTheme.Space.radius))
        .overlay {
            RoundedRectangle(cornerRadius: WidgetTheme.Space.radius)
                .stroke(WidgetTheme.hairline, lineWidth: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: WidgetTheme.Space.md) {
            progressRing

            VStack(alignment: .leading, spacing: WidgetTheme.Space.xs) {
                header

                if entry.loadState == .loaded {
                    if let task = entry.nextTask {
                        Button(intent: CompleteRoutineTaskIntent(
                            taskID: task.id.uuidString,
                            routineDayKey: entry.routineDayKey
                        )) {
                            HStack(spacing: WidgetTheme.Space.xs) {
                                Circle()
                                    .strokeBorder(WidgetTheme.accent, lineWidth: 1.5)
                                    .frame(width: 14, height: 14)
                                Text(task.title)
                                    .font(WidgetTheme.Typography.body)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                    } else {
                        content(task: nil)
                    }
                } else {
                    Text("Open Linkerworks to load your routine")
                        .font(WidgetTheme.Typography.detail)
                        .foregroundStyle(WidgetTheme.secondaryText)
                }
            }
        }
        .padding(WidgetTheme.Space.md)
        .background(WidgetTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: WidgetTheme.Space.radius))
        .overlay {
            RoundedRectangle(cornerRadius: WidgetTheme.Space.radius)
                .stroke(WidgetTheme.hairline, lineWidth: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Sentence-case section label — the widget used a tracked-out "NEXT".
    private var header: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.Space.xxs) {
            Text(entry.routineDay, format: .dateTime.weekday(.wide))
                .font(WidgetTheme.Typography.title)
                .foregroundStyle(WidgetTheme.primaryText)
            Text("Next")
                .font(WidgetTheme.Typography.caption)
                .foregroundStyle(WidgetTheme.accent)
        }
    }

    /// Ring rather than a bar: matches the Today hero.
    private var progressRing: some View {
        let fraction = entry.scheduledCount > 0
            ? Double(entry.completedCount) / Double(entry.scheduledCount)
            : 0

        return ZStack {
            Circle()
                .stroke(WidgetTheme.surfaceSunken, lineWidth: 6)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    fraction >= 1 ? WidgetTheme.completionAccent : WidgetTheme.accent,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(entry.completedCount)/\(entry.scheduledCount)")
                .font(WidgetTheme.Typography.metric)
                .monospacedDigit()
        }
        .frame(width: 56, height: 56)
    }

    @ViewBuilder
    private func content(task: LinkerworksWidgetEntry.NextTask?) -> some View {
        if entry.loadState == .unavailable {
            Text("Open Linkerworks to load your routine")
                .font(WidgetTheme.Typography.detail)
                .foregroundStyle(WidgetTheme.secondaryText)
        } else if let task {
            Button(intent: CompleteRoutineTaskIntent(
                taskID: task.id.uuidString,
                routineDayKey: entry.routineDayKey
            )) {
                Text(task.title)
                    .font(WidgetTheme.Typography.title)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        } else if entry.isNeutralDay {
            Label("No tasks to count", systemImage: "minus.circle")
                .font(WidgetTheme.Typography.body)
                .foregroundStyle(WidgetTheme.secondaryText)
        } else {
            Label("Day complete", systemImage: "checkmark.circle.fill")
                .font(WidgetTheme.Typography.body)
                .foregroundStyle(WidgetTheme.completionAccent)
        }
    }

    private var circular: some View {
        Group {
            if entry.loadState == .unavailable {
                Image(systemName: "exclamationmark")
            } else if let task = entry.nextTask {
                Text(task.title)
                    .font(WidgetTheme.Typography.caption)
                    .lineLimit(2)
                    .minimumScaleFactor(0.35)
            } else {
                Image(systemName: entry.isNeutralDay ? "minus" : "checkmark")
            }
        }
        .widgetAccentable()
        .accessibilityLabel("\(entry.routineDay.formatted(.dateTime.weekday(.wide))). \(entry.nextTask?.title ?? (entry.isNeutralDay ? "No tasks to count" : "Day complete"))")
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.Space.xxs) {
            Text(entry.routineDay, format: .dateTime.weekday(.abbreviated))
                .font(WidgetTheme.Typography.caption)
                .foregroundStyle(WidgetTheme.secondaryText)
            if entry.loadState == .unavailable {
                Label("Open Linkerworks", systemImage: "exclamationmark.circle")
            } else if let task = entry.nextTask {
                Text("\(entry.completedCount)/\(entry.scheduledCount) · Next: \(task.title)")
                    .font(WidgetTheme.Typography.detail)
                    .lineLimit(1)
            } else {
                Text(entry.isNeutralDay ? "No tasks to count" : "Day complete")
                    .font(WidgetTheme.Typography.detail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LinkerworksWidget: Widget { let kind = WidgetTimeline.routineKind; var body: some WidgetConfiguration { StaticConfiguration(kind: kind, provider: LinkerworksWidgetProvider(content: .routine)) { LinkerworksWidgetEntryView(entry: $0) }.configurationDisplayName("Next Task").description("Today’s routine progress and next work.").supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular]) } }

struct LinkerworksAssignmentWidget: Widget { let kind = WidgetTimeline.assignmentKind; var body: some WidgetConfiguration { StaticConfiguration(kind: kind, provider: LinkerworksWidgetProvider(content: .assignments)) { entry in AssignmentWidgetView(entry: entry) }.configurationDisplayName("Next Assignment Due").description("Your nearest unfinished assignment.").supportedFamilies([.systemSmall, .systemMedium]) } }
private struct AssignmentWidgetView: View {
    let entry: LinkerworksWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.Space.xs) {
            Text("Due next")
                .font(WidgetTheme.Typography.caption)
                .foregroundStyle(WidgetTheme.accent)

            if entry.loadState == .unavailable {
                Text("Open Linkerworks to load assignments")
                    .font(WidgetTheme.Typography.detail)
                    .foregroundStyle(WidgetTheme.secondaryText)
            } else if let item = entry.assignment {
                HStack(spacing: WidgetTheme.Space.xs) {
                    Circle()
                        .fill(item.courseColorHex.map(Color.init(hex:)) ?? WidgetTheme.neutralCourse)
                        .frame(width: 8, height: 8)
                    Text(item.courseName ?? "No course")
                        .font(WidgetTheme.Typography.detail)
                        .foregroundStyle(WidgetTheme.secondaryText)
                }

                Text(item.title)
                    .font(WidgetTheme.Typography.title)
                    .lineLimit(2)

                Text(item.dueDate, format: .dateTime.weekday(.abbreviated).hour().minute())
                    .font(WidgetTheme.Typography.metric)
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.secondaryText)
            } else {
                Label("Nothing due", systemImage: "checkmark.circle")
                    .font(WidgetTheme.Typography.body)
                    .foregroundStyle(WidgetTheme.completionAccent)
            }
        }
        .padding(WidgetTheme.Space.md)
        .background(WidgetTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: WidgetTheme.Space.radius))
        .overlay {
            RoundedRectangle(cornerRadius: WidgetTheme.Space.radius)
                .stroke(WidgetTheme.hairline, lineWidth: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(todayDeepLink)
        .containerBackground(WidgetTheme.background, for: .widget)
    }
}

private extension Color {
    init(hex: String) {
        let value = UInt64(hex.dropFirst(), radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 255) / 255,
            green: Double((value >> 8) & 255) / 255,
            blue: Double(value & 255) / 255
        )
    }
}
