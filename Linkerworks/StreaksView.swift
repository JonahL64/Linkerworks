import Foundation
import SwiftData
import SwiftUI

private struct StreakProjectionRevision: Hashable {
    private struct RecordValue: Hashable {
        let id: UUID
        let date: Date
        let taskID: UUID
        let completedAt: Date
        let state: String
    }

    private struct SnapshotValue: Hashable {
        let dayKey: String
        let capturedAt: Date
    }

    private let records: [RecordValue]
    private let snapshots: [SnapshotValue]
    private let ignoredRecordIDs: [String]

    init(
        completionRecords: [CompletionRecord],
        daySnapshots: [DaySnapshot],
        ignoredRecordIDs: Set<UUID>
    ) {
        records = completionRecords.map {
            RecordValue(
                id: $0.id,
                date: $0.date,
                taskID: $0.taskId,
                completedAt: $0.completedAt,
                state: $0.state.rawValue
            )
        }
        snapshots = daySnapshots.map {
            SnapshotValue(dayKey: $0.dayKey, capturedAt: $0.capturedAt)
        }
        self.ignoredRecordIDs = ignoredRecordIDs.map(\.uuidString).sorted()
    }
}

/// A current streak is measured through yesterday. This avoids treating an
/// in-progress today as either a completed or broken streak.
struct StreaksView: View {
    @Query private var tasks: [TaskItem]
    @Query private var completionRecords: [CompletionRecord]
    @Query private var daySnapshots: [DaySnapshot]

    private let calendar = Calendar.current

    private var currentMonth: Date {
        calendar.dateInterval(of: .month, for: Date())?.start
            ?? calendar.startOfDay(for: Date())
    }

    @State private var showingHeatmapInfo = false
    @State private var summaryCache: StreakSummaryCache?

    var body: some View {
        let ignoredRecordIDs = GoalkeepingRestDay.ignoredRecordIDs()
        let revision = StreakProjectionRevision(
            completionRecords: completionRecords,
            daySnapshots: daySnapshots,
            ignoredRecordIDs: ignoredRecordIDs
        )
        let summary = summaryCache?.revision == revision
            ? summaryCache!.summary
            : makeSummary(ignoredRecordIDs: ignoredRecordIDs)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LWSpace.xl) {
                    streakBlock(summary: summary)

                    LWSection("Last 14 days") {
                        TrendStripView(
                            days: summary.recentDays(count: 14),
                            calendar: calendar
                        )
                        .padding(LWSpace.md)
                    }

                    LWSection(
                        "Completion heatmap",
                        accessory: AnyView(
                            Button {
                                showingHeatmapInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 14))
                                    .foregroundStyle(LWColor.inkTertiary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("How completion is counted")
                        )
                    ) {
                        CalendarHeatmapView(
                            month: currentMonth,
                            summary: summary,
                            calendar: calendar
                        )
                        .padding(LWSpace.md)
                    }

                    if let rollup = summary.currentWeekRollup {
                        LWSection("This week") {
                            WeekRollupRow(rollup: rollup)
                                .padding(LWSpace.md)
                        }
                    }
                }
                .padding(.horizontal, LWSpace.screenInset)
                .padding(.bottom, LWSpace.xxl)
            }
            .background(LWColor.surface)
            .navigationTitle("Progress")
            .alert("How completion is counted", isPresented: $showingHeatmapInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Skipped tasks are excluded from daily progress. Days with no scheduled tasks, or every task skipped, are neutral for streaks.")
            }
            .task(id: revision) {
                guard summaryCache?.revision != revision else { return }
                summaryCache = StreakSummaryCache(
                    revision: revision,
                    summary: makeSummary(ignoredRecordIDs: ignoredRecordIDs)
                )
            }
        }
        .trainingLogNavigation()
    }

    private func makeSummary(
        ignoredRecordIDs: Set<UUID>
    ) -> StreakSummary {
        StreakSummary(
            tasks: tasks,
            completionRecords: completionRecords,
            daySnapshots: daySnapshots,
            ignoredRecordIDs: ignoredRecordIDs,
            calendar: calendar
        )
    }

    /// The headline pair. Current streak leads at full display size; longest is
    /// supporting context rather than a co-equal number.
    private func streakBlock(summary: StreakSummary) -> some View {
        VStack(alignment: .leading, spacing: LWSpace.md) {
            VStack(alignment: .leading, spacing: LWSpace.xxs) {
                Text("Current streak")
                    .font(LWFont.caption)
                    .foregroundStyle(LWColor.inkSecondary)

                HStack(alignment: .firstTextBaseline, spacing: LWSpace.xs) {
                    Text(summary.currentStreak.formatted())
                        .font(LWFont.displayLarge)
                        .monospacedDigit()
                        .foregroundStyle(
                            summary.currentStreak > 0 ? LWColor.success : LWColor.ink
                        )
                        .contentTransition(.numericText())

                    Text(summary.currentStreak == 1 ? "day" : "days")
                        .font(LWFont.body)
                        .foregroundStyle(LWColor.inkSecondary)
                }
            }

            Divider().overlay(LWColor.hairline)

            HStack(spacing: LWSpace.xxs) {
                Text("Longest")
                    .font(LWFont.callout)
                    .foregroundStyle(LWColor.inkSecondary)
                Spacer(minLength: LWSpace.xs)
                Text("\(summary.longestStreak.formatted()) \(summary.longestStreak == 1 ? "day" : "days")")
                    .font(LWFont.calloutMedium)
                    .monospacedDigit()
                    .foregroundStyle(LWColor.ink)
            }
            .accessibilityElement(children: .combine)
        }
        .lwBlock(padding: LWSpace.lg, radius: LWRadius.xl)
        .accessibilityHint("Current streak is measured through yesterday.")
    }
}

/// Fourteen-day completion trend. Gives the screen a sense of direction that two
/// standalone numbers and a month grid could not.
private struct TrendStripView: View {
    let days: [(date: Date, completion: ProgressDayCompletion)]
    let calendar: Calendar

    private var maxHeight: CGFloat { 64 }

    var body: some View {
        VStack(alignment: .leading, spacing: LWSpace.xs) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, entry in
                    let pct = entry.completion.scheduledCount == 0
                        ? 0
                        : entry.completion.percentage

                    VStack(spacing: LWSpace.xxs) {
                        Spacer(minLength: 0)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                entry.completion.scheduledCount == 0
                                    ? LWColor.surfaceSunken
                                    : (pct >= 1 ? LWColor.success : LWColor.accent.opacity(0.55))
                            )
                            .frame(height: max(3, maxHeight * pct))

                        Text(entry.date, format: .dateTime.day())
                            .font(.system(size: 9))
                            .monospacedDigit()
                            .foregroundStyle(
                                calendar.isDateInToday(entry.date)
                                    ? LWColor.accent
                                    : LWColor.inkTertiary
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: maxHeight + 16)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Completion trend for the last 14 days")
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
        VStack(alignment: .leading, spacing: LWSpace.sm) {
            Text(month, format: .dateTime.month(.wide).year())
                .font(LWFont.titleSmall)
                .foregroundStyle(LWColor.ink)

            LazyVGrid(columns: columns, spacing: LWSpace.xxs) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(LWColor.inkTertiary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let completion = summary.completion(for: date)
                        LWHeatCell(
                            day: calendar.component(.day, from: date),
                            percentage: completion.percentage,
                            hasSchedule: completion.scheduledCount > 0,
                            isFuture: date > calendar.startOfDay(for: Date()),
                            isToday: calendar.isDateInToday(date)
                        )
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            date.formatted(.dateTime.weekday(.wide).month().day().year())
                        )
                        .accessibilityValue(
                            completion.scheduledCount == 0
                                ? "No scheduled tasks, or all tasks skipped"
                                : "\(completion.completedCount) of \(completion.scheduledCount) tasks completed"
                        )
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }
}

private struct WeekRollupRow: View {
    let rollup: WeekRollup

    var body: some View {
        VStack(alignment: .leading, spacing: LWSpace.sm) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: LWSpace.xxs) {
                    Text(rollup.start, format: .dateTime.month(.abbreviated).day())
                    Text("–").foregroundStyle(LWColor.inkTertiary)
                    Text(rollup.end, format: .dateTime.month(.abbreviated).day())
                }
                .font(LWFont.callout)
                .foregroundStyle(LWColor.inkSecondary)

                Spacer(minLength: LWSpace.xs)

                if rollup.scheduledCount > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: LWSpace.xxs) {
                        Text(rollup.percentage, format: .percent.precision(.fractionLength(0)))
                            .font(LWFont.displaySmall)
                            .monospacedDigit()
                            .foregroundStyle(LWColor.ink)

                        Text("(\(rollup.completedCount)/\(rollup.scheduledCount))")
                            .font(LWFont.caption)
                            .monospacedDigit()
                            .foregroundStyle(LWColor.inkTertiary)
                    }
                }
            }

            if rollup.scheduledCount == 0 {
                Text("No scheduled tasks this week, or all were skipped.")
                    .font(LWFont.callout)
                    .foregroundStyle(LWColor.inkSecondary)
            } else {
                LWProgressBar(progress: rollup.percentage, height: 6)
            }
        }
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

@MainActor
private struct StreakSummaryCache {
    let revision: StreakProjectionRevision
    let summary: StreakSummary
}

@MainActor
private struct StreakSummary {
    private let tasks: [TaskItem]
    private let statesByDayKey: [String: [UUID: CompletionRecordState]]
    private let snapshotsByDayKey: [String: HistoricalProgressSnapshot]
    private let historyStartDate: Date?
    private let calendar: Calendar

    init(
        tasks: [TaskItem],
        completionRecords: [CompletionRecord],
        daySnapshots: [DaySnapshot],
        ignoredRecordIDs: Set<UUID>? = nil,
        calendar: Calendar
    ) {
        self.tasks = tasks
        self.calendar = calendar
        statesByDayKey = CompletionRecordDayIndex(
            records: completionRecords,
            ignoredRecordIDs: ignoredRecordIDs ?? GoalkeepingRestDay.ignoredRecordIDs(),
            calendar: calendar
        ).statesByDayKey
        snapshotsByDayKey = Dictionary(grouping: daySnapshots, by: \.dayKey)
            .compactMapValues { snapshots in
                snapshots.last.map { HistoricalProgressSnapshot(snapshot: $0) }
            }
        let snapshotDates = daySnapshots.compactMap {
            DaySnapshotService.date(for: $0.dayKey, calendar: calendar)
        }
        historyStartDate = (completionRecords.map(\.date) + snapshotDates).min()
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
        if let snapshot = snapshotsByDayKey[key] {
            input = snapshot
        } else if calendar.isDateInToday(date) {
            // Today is the only permitted live-schedule fallback before capture.
            input = HistoricalProgressSnapshot(tasks: tasks, date: date, calendar: calendar)
        } else {
            return ProgressDayCompletion(scheduledCount: 0, completedCount: 0)
        }
        return HistoricalDayProgress.completion(
            scheduledTaskIDs: input.scheduledTaskIDs,
            childTaskIDsByParent: input.childTaskIDsByParent,
            states: statesByDayKey[key] ?? [:]
        )
    }

    /// The last `count` days ending today, oldest first. Backs the trend strip.
    func recentDays(count: Int) -> [(date: Date, completion: ProgressDayCompletion)] {
        (0..<count).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }
            return (date: day, completion: completion(for: day))
        }
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
        historyStartDate
    }
}
