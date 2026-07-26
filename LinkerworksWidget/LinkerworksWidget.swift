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
    enum LoadState {
        case loaded
        case unavailable
    }

    struct NextTask {
        let title: String
    }

    let date: Date
    let nextTask: NextTask?
    let isNeutralDay: Bool
    let loadState: LoadState

    static let placeholder = LinkerworksWidgetEntry(
        date: .now,
        nextTask: NextTask(title: "Afternoon training"),
        isNeutralDay: false,
        loadState: .loaded
    )

    static func unavailable(at date: Date) -> LinkerworksWidgetEntry {
        LinkerworksWidgetEntry(
            date: date,
            nextTask: nil,
            isNeutralDay: false,
            loadState: .unavailable
        )
    }
}

struct LinkerworksWidgetProvider: TimelineProvider {
    typealias Entry = LinkerworksWidgetEntry

    func placeholder(in context: Context) -> Entry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(loadEntry(at: .now))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date()
        let entry = loadEntry(at: now)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh(after: now))))
    }

    private func loadEntry(at date: Date) -> Entry {
        do {
            let container = try SharedModelContainer.make()
            let context = ModelContext(container)
            let calendar = Calendar.current
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                return .unavailable(at: date)
            }

            let weekdayNames = [
                "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
            ]
            let weekdayIndex = calendar.component(.weekday, from: date) - 1
            guard weekdayNames.indices.contains(weekdayIndex) else {
                return .unavailable(at: date)
            }
            let weekdayName = weekdayNames[weekdayIndex]

            let completionDescriptor = FetchDescriptor<CompletionRecord>(
                predicate: #Predicate { record in
                    record.date >= dayStart && record.date < dayEnd
                }
            )
            let todayRecords = try context.fetch(completionDescriptor)
            let completedTaskIDs = Set(
                todayRecords
                    .filter { $0.state == .complete }
                    .map(\.taskId)
            )
            let skippedTaskIDs = Set(
                todayRecords
                    .filter { $0.state == .skipped }
                    .map(\.taskId)
            )

            // This intentionally matches Today/Streaks: archived tasks and substeps
            // do not count, and lift parents derive completion from their children.
            let topLevelTasks = try context.fetch(FetchDescriptor<TaskItem>())
                .filter {
                    !$0.isArchived
                        && !$0.isSubstep
                        && $0.parent == nil
                        && $0.daysOfWeek.contains(weekdayName)
                }
            func isSkipped(_ task: TaskItem) -> Bool {
                if skippedTaskIDs.contains(task.id) {
                    return true
                }
                let activeChildIDs = task.children
                    .filter { !$0.isArchived }
                    .map(\.id)
                return !activeChildIDs.isEmpty
                    && activeChildIDs.allSatisfy { skippedTaskIDs.contains($0) }
            }

            let nextTask = topLevelTasks
                .filter {
                    !isSkipped($0)
                        && !TaskCompletion.isComplete($0, completedTaskIDs: completedTaskIDs)
                }
                .sorted { lhs, rhs in
                    let lhsDate = scheduledDate(for: lhs, on: date) ?? .distantFuture
                    let rhsDate = scheduledDate(for: rhs, on: date) ?? .distantFuture
                    if lhsDate != rhsDate {
                        return lhsDate < rhsDate
                    }
                    if lhs.sortOrder != rhs.sortOrder {
                        return lhs.sortOrder < rhs.sortOrder
                    }
                    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }
                .first
                .map { Entry.NextTask(title: $0.title) }

            return Entry(
                date: date,
                nextTask: nextTask,
                isNeutralDay: topLevelTasks.allSatisfy(isSkipped),
                loadState: .loaded
            )
        } catch {
#if DEBUG
            print("Widget could not read the shared SwiftData store: \(error.localizedDescription)")
#endif
            return .unavailable(at: date)
        }
    }

    private func scheduledDate(for task: TaskItem, on date: Date) -> Date? {
        guard let time = task.time else { return nil }
        let components = time.split(separator: ":", omittingEmptySubsequences: false)
        guard
            components.count == 2,
            let hour = Int(components[0]),
            let minute = Int(components[1]),
            (0...23).contains(hour),
            (0...59).contains(minute)
        else {
            return nil
        }

        return Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: date
        )
    }

    private func nextRefresh(after date: Date) -> Date {
        let calendar = Calendar.current
        let hourlyRefresh = calendar.date(byAdding: .hour, value: 1, to: date) ?? date.addingTimeInterval(3_600)
        let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: date)
        ) ?? hourlyRefresh
        return min(hourlyRefresh, tomorrow)
    }
}

struct LinkerworksWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: LinkerworksWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circularAccessory
            case .accessoryRectangular:
                rectangularAccessory
            default:
                homeScreenWidget
            }
        }
        .widgetURL(todayDeepLink)
        .foregroundStyle(WidgetTheme.primaryText)
        .containerBackground(WidgetTheme.background, for: .widget)
    }

    private var homeScreenWidget: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NEXT")
                .font(.caption.weight(.semibold))
                .foregroundStyle(WidgetTheme.secondaryText)

            if entry.loadState == .unavailable {
                Text("Open Linkerworks to load today")
                    .font(.caption)
                    .foregroundStyle(WidgetTheme.secondaryText)
            } else if let nextTask = entry.nextTask {
                Text(nextTask.title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(3)
            } else if entry.isNeutralDay {
                Label("No tasks to count", systemImage: "minus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WidgetTheme.secondaryText)
            } else {
                Label("Day complete", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WidgetTheme.completionAccent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var circularAccessory: some View {
        Group {
            if entry.loadState == .unavailable {
                Image(systemName: "exclamationmark")
            } else if let nextTask = entry.nextTask {
                Text(nextTask.title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.35)
            } else if entry.isNeutralDay {
                Image(systemName: "minus")
            } else {
                Image(systemName: "checkmark")
            }
        }
            .widgetAccentable()
        .accessibilityLabel(accessoryAccessibilityLabel)
    }

    private var rectangularAccessory: some View {
        VStack(alignment: .leading, spacing: 2) {
            if entry.loadState == .unavailable {
                Label("Open Linkerworks", systemImage: "exclamationmark.circle")
                    .font(.headline)
            } else {
                if let nextTask = entry.nextTask {
                    Text("Next")
                        .font(.caption)
                        .foregroundStyle(WidgetTheme.secondaryText)
                    Text(nextTask.title)
                        .font(.caption)
                        .lineLimit(1)
                } else if entry.isNeutralDay {
                    Label("No tasks to count", systemImage: "minus.circle")
                        .font(.caption)
                } else {
                    Label("Day complete", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(accessoryAccessibilityLabel)
    }

    private var accessoryAccessibilityLabel: String {
        guard entry.loadState == .loaded else {
            return "Linkerworks data unavailable. Open the app to load today."
        }
        if let nextTask = entry.nextTask {
            return "Next task: \(nextTask.title)."
        }
        if entry.isNeutralDay {
            return "No scheduled tasks to count today."
        }
        return "Day complete."
    }
}

struct LinkerworksWidget: Widget {
    let kind = "LinkerworksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LinkerworksWidgetProvider()) { entry in
            LinkerworksWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Next Task")
        .description("See the next thing to do today.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
        ])
    }
}

#Preview(as: .systemSmall) {
    LinkerworksWidget()
} timeline: {
    LinkerworksWidgetEntry.placeholder
}

#Preview(as: .accessoryRectangular) {
    LinkerworksWidget()
} timeline: {
    LinkerworksWidgetEntry.placeholder
}
