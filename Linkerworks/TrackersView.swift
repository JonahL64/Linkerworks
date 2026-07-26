import Foundation
import SwiftData
import SwiftUI

struct TrackersView: View {
    var body: some View {
        NavigationStack {
            List {
                SwiftUI.Section {
                    NavigationLink {
                        WorkoutView()
                    } label: {
                        LogDestinationRow(
                            title: "Workout",
                            detail: "Start, resume, and review sessions",
                            symbol: "dumbbell.fill"
                        )
                    }

                    NavigationLink {
                        NutritionView()
                    } label: {
                        LogDestinationRow(
                            title: "Nutrition",
                            detail: "Meals, macros, and daily totals",
                            symbol: "fork.knife"
                        )
                    }
                } header: {
                    Text("Log")
                        .trainingLogSectionLabel()
                }

                SwiftUI.Section {
                    ForEach(Domain.allCases.filter { $0 != .eating && $0 != .lifting }) { domain in
                        NavigationLink {
                            DomainTrackerView(domain: domain)
                        } label: {
                            Label(domain.displayName, systemImage: domain.symbolName)
                                .foregroundStyle(TrainingLogTheme.primaryText)
                                .trainingLogRow()
                        }
                    }
                } header: {
                    Text("Trackers")
                        .trainingLogSectionLabel()
                }
            }
            .trainingLogList()
            .listRowBackground(TrainingLogTheme.background)
            .navigationTitle("Log")
        }
        .trainingLogNavigation()
    }
}

private struct LogDestinationRow: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol)
                .font(.body.weight(.semibold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(TrainingLogTheme.secondaryText)
        }
        .foregroundStyle(TrainingLogTheme.primaryText)
        .trainingLogRow()
    }
}

private struct DomainTrackerView: View {
    let domain: Domain

    @Query(sort: \TaskItem.title) private var tasks: [TaskItem]
    @Query(sort: \CompletionRecord.completedAt, order: .reverse)
    private var completionRecords: [CompletionRecord]
    @Query(sort: \DomainReference.sourceName) private var references: [DomainReference]
    @Query(sort: \DaySchedule.weekdayIndex) private var daySchedules: [DaySchedule]

    private let calendar = Calendar.current

    private var domainTasks: [TaskItem] {
        tasks.filter { $0.domain == domain }
    }

    private var taskByID: [UUID: TaskItem] {
        Dictionary(uniqueKeysWithValues: domainTasks.map { ($0.id, $0) })
    }

    private var domainRecords: [CompletionRecord] {
        completionRecords.filter { taskByID[$0.taskId] != nil }
    }

    private var domainCompletions: [CompletionRecord] {
        domainRecords.filter { $0.state == .complete }
    }

    private var domainSkips: [CompletionRecord] {
        domainRecords.filter { $0.state == .skipped }
    }

    private var domainReferences: [DomainReference] {
        references.filter { $0.domain == domain }
    }

    private var taskSummaries: [TaskSummary] {
        let countsByTaskID = Dictionary(grouping: domainCompletions, by: \.taskId)
        let groupedTasks = Dictionary(grouping: domainTasks, by: \.title)

        return groupedTasks.map { title, grouped in
            let count = grouped.reduce(0) { total, task in
                total + (countsByTaskID[task.id]?.count ?? 0)
            }
            return TaskSummary(
                title: title,
                scheduledDays: Set(grouped.flatMap(\.daysOfWeek)),
                completionCount: count
            )
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        List {
            completionHistory

            if domain == .eating {
                macroTargets
            }

            referenceContent
        }
        .trainingLogList()
        .listRowBackground(TrainingLogTheme.background)
        .navigationTitle(domain.displayName)
    }

    @ViewBuilder
    private var completionHistory: some View {
        SwiftUI.Section("Completion History") {
            LabeledContent("Task items", value: "\(domainTasks.count)")
            LabeledContent("Recorded completions", value: "\(domainCompletions.count)")
            LabeledContent("Skipped", value: "\(domainSkips.count)")

            if domainRecords.isEmpty {
                Text("No completions or skips recorded yet.")
                    .foregroundStyle(TrainingLogTheme.secondaryText)
            } else {
                ForEach(domainRecords) { record in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(taskByID[record.taskId]?.title ?? "Archived task")
                            if record.state == .skipped {
                                Text("Skipped")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(TrainingLogTheme.secondaryText)
                            }
                        }
                        Text(record.completedAt, format: .dateTime.weekday(.abbreviated).month().day().year().hour().minute())
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(TrainingLogTheme.secondaryText)
                    }
                }
            }
        }

        SwiftUI.Section("Domain Task Items") {
            if taskSummaries.isEmpty {
                Text("No tasks are assigned to this domain.")
                    .foregroundStyle(TrainingLogTheme.secondaryText)
            } else {
                ForEach(taskSummaries) { task in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                        Text(task.scheduleDescription)
                            .font(.caption)
                            .foregroundStyle(TrainingLogTheme.secondaryText)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var macroTargets: some View {
        SwiftUI.Section("Daily Macro Targets") {
            ForEach(daySchedules) { schedule in
                VStack(alignment: .leading, spacing: 5) {
                    Text(schedule.weekdayName)
                        .font(.headline)
                    Text("\(schedule.targetCalories) kcal · Protein \(schedule.targetProteinGrams) g · Fat \(schedule.targetFatGrams) g")
                    Text("Carbohydrates \(schedule.targetCarbohydrateGrams) g · Fiber \(schedule.targetFiberGrams) g")
                }
                .font(.subheadline)
            }
        }
    }

    @ViewBuilder
    private var referenceContent: some View {
        if domainReferences.isEmpty {
            SwiftUI.Section("Reference") {
                Text("No reference content is available for this domain.")
                    .foregroundStyle(TrainingLogTheme.secondaryText)
            }
        } else {
            ForEach(domainReferences) { reference in
                SwiftUI.Section(reference.sourceName) {
                    ReferenceRowsView(rowsJSON: reference.rowsJSON)
                }
            }
        }
    }
}

private struct TaskSummary: Identifiable {
    let title: String
    let scheduledDays: Set<String>
    let completionCount: Int

    var id: String { title }

    var scheduleDescription: String {
        let dayOrder = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let days = dayOrder.filter(scheduledDays.contains).joined(separator: ", ")
        let completionLabel = completionCount == 1 ? "completion" : "completions"
        return "Scheduled: \(days) · \(completionCount) \(completionLabel)"
    }
}

/// Decodes the raw array-of-arrays reference tables without imposing one schema
/// on every tracker. One-cell rows remain readable notes or section labels;
/// multi-cell rows retain their column layout in a horizontally scrollable grid.
private struct ReferenceRowsView: View {
    let rowsJSON: Data

    private var rows: [[ReferenceValue]] {
        (try? JSONDecoder().decode([[ReferenceValue]].self, from: rowsJSON)) ?? []
    }

    private var firstTableRowIndex: Int? {
        rows.indices.first { rows[$0].nonEmptyCount > 1 }
    }

    var body: some View {
        if rows.isEmpty {
            Text("This reference could not be decoded.")
                .foregroundStyle(TrainingLogTheme.secondaryText)
        } else {
            ForEach(rows.indices, id: \.self) { index in
                let row = rows[index]
                if row.nonEmptyCount <= 1 {
                    ReferenceNoteRow(
                        text: row.firstNonEmptyText ?? "",
                        isTitle: index == 0,
                        isSectionLabel: index != 0 && row.isSectionLabel
                    )
                } else {
                    ReferenceGridRow(
                        cells: row,
                        isHeader: isHeaderRow(at: index)
                    )
                }
            }
        }
    }

    private func isHeaderRow(at index: Int) -> Bool {
        if index == firstTableRowIndex { return true }

        guard index > 0 else { return false }
        let previousRow = rows[index - 1]
        return previousRow.nonEmptyCount == 1 && previousRow.isSectionLabel
    }
}

private struct ReferenceNoteRow: View {
    let text: String
    let isTitle: Bool
    let isSectionLabel: Bool

    var body: some View {
        Text(text)
            .font(isTitle ? .headline : (isSectionLabel ? .subheadline.weight(.semibold) : .body))
            .foregroundStyle(
                isTitle || isSectionLabel
                    ? TrainingLogTheme.primaryText
                    : TrainingLogTheme.secondaryText
            )
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ReferenceGridRow: View {
    let cells: [ReferenceValue]
    let isHeader: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(cells.indices, id: \.self) { index in
                    Text(cells[index].displayText)
                        .font(isHeader ? .caption.weight(.semibold) : .caption)
                        .foregroundStyle(
                            isHeader
                                ? TrainingLogTheme.secondaryText
                                : TrainingLogTheme.primaryText
                        )
                        .frame(width: 132, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private enum ReferenceValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else {
            throw DecodingError.typeMismatch(
                ReferenceValue.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Expected a scalar reference value.")
            )
        }
    }

    var displayText: String {
        switch self {
        case let .string(value):
            return value
        case let .number(value):
            if value.rounded() == value { return String(Int(value)) }
            return value.formatted(.number.precision(.fractionLength(0...2)))
        case let .bool(value):
            return value ? "Yes" : "No"
        case .null:
            return ""
        }
    }
}

private extension Array where Element == ReferenceValue {
    var nonEmptyCount: Int {
        filter {
            if case .null = $0 { return false }
            return !$0.displayText.isEmpty
        }.count
    }

    var firstNonEmptyText: String? {
        first { value in
            if case .null = value { return false }
            return !value.displayText.isEmpty
        }?.displayText
    }

    var isSectionLabel: Bool {
        guard let text = firstNonEmptyText else { return false }
        let letters = text.filter(\.isLetter)
        guard !letters.isEmpty else { return false }
        return text == text.uppercased() || text.hasPrefix("CUE ") || text.hasPrefix("TRACK ")
    }
}

private extension Domain {
    var symbolName: String {
        switch self {
        case .sleep: "bed.double"
        case .eating: "fork.knife"
        case .goalkeeping: "soccerball"
        case .lifting: "dumbbell"
        case .posture: "figure.stand"
        case .grooming: "scissors"
        }
    }
}
