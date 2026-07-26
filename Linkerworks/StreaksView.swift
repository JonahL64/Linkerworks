import Foundation
import SwiftData
import SwiftUI

/// A current streak is measured through yesterday. This avoids treating an
/// in-progress today as either a completed or broken streak.
struct StreaksView: View {
    @Query private var tasks: [TaskItem]
    @Query private var completionRecords: [CompletionRecord]
    @Query private var daySnapshots: [DaySnapshot]

    private let calendar = Calendar.current

    private var summary: StreakSummary {
        StreakSummary(
            tasks: tasks,
            completionRecords: completionRecords,
            daySnapshots: daySnapshots,
            calendar: calendar
        )
    }

    private var currentMonth: Date {
        calendar.dateInterval(of: .month, for: Date())?.start
            ?? calendar.startOfDay(for: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(spacing: 28) {
                        streakValue("Current Streak", days: summary.currentStreak)
                        streakValue("Longest Streak", days: summary.longestStreak)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Completion heatmap")
                            .trainingLogSectionLabel()

                        CalendarHeatmapView(
                            month: currentMonth,
                            summary: summary,
                            calendar: calendar
                        )
                    }

                    if let rollup = summary.currentWeekRollup {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("This week")
                                .trainingLogSectionLabel()
                            WeekRollupRow(rollup: rollup)
                        }
                    }
                }
                .padding()
            }
            .background(TrainingLogTheme.background)
            .navigationTitle("Progress")
        }
        .trainingLogNavigation()
    }

    private func streakValue(_ title: String, days: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .trainingLogSectionLabel()
            Text(days.formatted())
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(days == 1 ? "day" : "days")
                .font(.subheadline)
                .foregroundStyle(TrainingLogTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

private struct CalendarHeatmapView: View {
    let month: Date
    let summary: StreakSummary
    let calendar: Calendar

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 4),
        count: 7
    )

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let firstIndex = max(calendar.firstWeekday - 1, 0)
        guard symbols.indices.contains(firstIndex) else { return symbols }
        return Array(symbols[firstIndex...]) + Array(symbols[..<firstIndex])
    }

    private var monthDays: [Date?] {
        guard
            let range = calendar.range(of: .day, in: .month, for: month),
            let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else {
            return []
        }

        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingEmptyCells = (weekday - calendar.firstWeekday + 7) % 7
        let leading = Array<Date?>(repeating: nil, count: leadingEmptyCells)
        let days = range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        }
        return leading + days.map(Optional.some)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(month, format: .dateTime.month(.wide).year())
                .font(.subheadline.weight(.semibold))

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(TrainingLogTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        HeatmapDayCell(
                            date: date,
                            completion: summary.completion(for: date),
                            isFuture: date > calendar.startOfDay(for: Date()),
                            isToday: calendar.isDateInToday(date)
                        )
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }

            Text("Skipped tasks are excluded from daily progress. Days with no scheduled tasks, or every task skipped, are neutral for streaks.")
                .font(.caption)
                .foregroundStyle(TrainingLogTheme.secondaryText)
        }
    }
}

private struct HeatmapDayCell: View {
    let date: Date
    let completion: ProgressDayCompletion
    let isFuture: Bool
    let isToday: Bool

    private var fill: Color {
        guard !isFuture else { return .clear }
        guard completion.scheduledCount > 0 else { return TrainingLogTheme.quietFill }
        return TrainingLogTheme.completionAccent.opacity(0.12 + (0.88 * completion.percentage))
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(fill)
            if isToday {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(TrainingLogTheme.primaryText, lineWidth: 1)
            }
            VStack(spacing: 1) {
                Text(date, format: .dateTime.day())
                    .font(.caption.weight(.semibold))
                if !isFuture, completion.scheduledCount > 0 {
                    Text(completion.percentage, format: .percent.precision(.fractionLength(0)))
                        .font(.system(size: 8))
                }
            }
            .foregroundStyle(isFuture ? TrainingLogTheme.secondaryText.opacity(0.5) : TrainingLogTheme.primaryText)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            date.formatted(.dateTime.weekday(.wide).month().day().year())
        )
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        if isFuture {
            return "Future day"
        }
        if completion.scheduledCount == 0 {
            return "No scheduled tasks, or all tasks skipped"
        }
        return "\(completion.completedCount) of \(completion.scheduledCount) tasks completed"
    }
}

private struct WeekRollupRow: View {
    let rollup: WeekRollup

    var body: some View {
        HStack {
            Text(rollup.start, format: .dateTime.month(.abbreviated).day())
            Text("–")
                .foregroundStyle(TrainingLogTheme.secondaryText)
            Text(rollup.end, format: .dateTime.month(.abbreviated).day())
            Spacer()
            if rollup.scheduledCount == 0 {
                    Text("No scheduled tasks or all skipped")
                    .foregroundStyle(TrainingLogTheme.secondaryText)
            } else {
                Text(rollup.percentage, format: .percent.precision(.fractionLength(0)))
                    .fontWeight(.semibold)
                Text("(\(rollup.completedCount)/\(rollup.scheduledCount))")
                    .font(.caption)
                    .foregroundStyle(TrainingLogTheme.secondaryText)
            }
        }
        .font(.subheadline)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

private struct WeekRollup {
    let start: Date
    let end: Date
    let scheduledCount: Int
    let completedCount: Int

    var percentage: Double {
        guard scheduledCount > 0 else { return 0 }
        return Double(completedCount) / Double(scheduledCount)
    }
}

private struct StreakSummary {
    private let tasks: [TaskItem]
    private let completionRecords: [CompletionRecord]
    private let daySnapshots: [DaySnapshot]
    private let calendar: Calendar

    init(
        tasks: [TaskItem],
        completionRecords: [CompletionRecord],
        daySnapshots: [DaySnapshot],
        calendar: Calendar
    ) {
        self.tasks = tasks
        self.completionRecords = completionRecords
        self.daySnapshots = daySnapshots
        self.calendar = calendar
    }

    var currentStreak: Int {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return 0
        }
        return completedRun(endingOn: yesterday)
    }

    var longestStreak: Int {
        guard let historyStart = historyStart else { return 0 }

        var longest = 0
        var activeRun = 0
        var day = calendar.startOfDay(for: historyStart)

        while day <= today {
            let completion = completion(for: day)
            if completion.scheduledCount == 0 {
                // Unscheduled days are absent from a streak rather than breaks.
            } else if completion.isComplete {
                activeRun += 1
                longest = max(longest, activeRun)
            } else {
                activeRun = 0
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = nextDay
        }
        return longest
    }

    func completion(for date: Date) -> ProgressDayCompletion {
        let key = DaySnapshotService.dayKey(for: date, calendar: calendar)
        let input: HistoricalProgressSnapshot
        if let snapshot = daySnapshots.first(where: { $0.dayKey == key }) {
            input = HistoricalProgressSnapshot(snapshot: snapshot)
        } else if calendar.isDateInToday(date) {
            // Today is the only permitted live-schedule fallback before capture.
            input = HistoricalProgressSnapshot(tasks: tasks, date: date, calendar: calendar)
        } else {
            return ProgressDayCompletion(scheduledCount: 0, completedCount: 0)
        }
        let records = completionRecords.filter { calendar.isDate($0.date, inSameDayAs: date) }
        return HistoricalDayProgress.completion(
            scheduledTaskIDs: input.scheduledTaskIDs,
            childTaskIDsByParent: input.childTaskIDsByParent,
            records: records
        )
    }

    var currentWeekRollup: WeekRollup? {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: today) else { return nil }
        guard let end = calendar.date(byAdding: .day, value: 6, to: interval.start) else { return nil }

        var scheduledCount = 0
        var completedCount = 0
        var day = interval.start
        while day <= today {
            let completion = completion(for: day)
            scheduledCount += completion.scheduledCount
            completedCount += completion.completedCount
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }
        return WeekRollup(
            start: interval.start,
            end: end,
            scheduledCount: scheduledCount,
            completedCount: completedCount
        )
    }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private func completedRun(endingOn endDate: Date) -> Int {
        guard let historyStart = historyStart else { return 0 }

        var streak = 0
        var day = calendar.startOfDay(for: endDate)
        let start = calendar.startOfDay(for: historyStart)

        while day >= start {
            let completion = completion(for: day)
            if completion.scheduledCount == 0 {
                // Unscheduled days neither increment nor break the run.
            } else if completion.isComplete {
                streak += 1
            } else {
                return streak
            }

            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else {
                break
            }
            day = previousDay
        }
        return streak
    }

    private var historyStart: Date? {
        let snapshotDates = daySnapshots.compactMap {
            DaySnapshotService.date(for: $0.dayKey, calendar: calendar)
        }
        return (completionRecords.map(\.date) + snapshotDates).min()
    }
}
