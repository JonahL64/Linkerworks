import SwiftData
import SwiftUI
import UIKit
import WidgetKit

struct ContentView: View {
    @State private var selectedTab: AppTab = .today
    @State private var showingManageRoutine = false

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "checklist")
                }
                .tag(AppTab.today)

            CalendarPlanView(showingManageRoutine: $showingManageRoutine)
                .tabItem {
                    Label("Plan", systemImage: "calendar")
                }
                .tag(AppTab.plan)

            TrackersView()
                .tabItem {
                    Label("Log", systemImage: "chart.bar")
                }
                .tag(AppTab.log)

            StreaksView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(AppTab.progress)
        }
        .tint(LWColor.accent)
        .toolbarBackground(LWColor.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .background(LWColor.surface)
        .onOpenURL { url in
            guard url.scheme == "linkerworks", url.host == "today" else { return }
            showingManageRoutine = false
            selectedTab = .today
        }
    }
}

private enum AppTab: Hashable {
    case today
    case plan
    case log
    case progress
}

@MainActor
private struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DaySchedule.weekdayIndex) private var daySchedules: [DaySchedule]
    @Query(sort: \CompletionRecord.completedAt) private var completionRecords: [CompletionRecord]
    @Query private var assignments: [Assignment]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var workoutSessions: [WorkoutSession]
    @Query(sort: \SavedMeal.sortOrder) private var savedMeals: [SavedMeal]

    @AppStorage("todayHideCompleted") private var hideCompleted = false
    @AppStorage("homeworkIntegrationEnabled") private var homeworkIntegrationEnabled = true
    @State private var saveErrorMessage: String?
    @State private var completionMomentVisible = false
    @State private var completionRingPulsing = false
    @State private var collapsedPhases: Set<RoutineDayPhase> = []
    @State private var manuallyExpandedCompletedPhases: Set<RoutineDayPhase> = []
    @State private var expandedLiftParentIDs: Set<UUID> = []
    @State private var undoState: CompletionUndo?
    @State private var isSavingCompletion = false
    @State private var currentTime = Date()
    @State private var favoriteAwaitingCategory: SavedMeal?
    @State private var routineDay = RoutineDaySelection.selectedDay()
    @State private var showingRolloverConfirmation = false
    @State private var goalkeepingRestDayRevision = 0

    private let calendar = Calendar.current

    private var today: Date {
        calendar.startOfDay(for: routineDay)
    }

    private var calendarDay: Date {
        calendar.startOfDay(for: currentTime)
    }

    private var isHoldingPriorRoutineDay: Bool {
        today < calendarDay
    }

    private var todaySchedule: DaySchedule? {
        let weekdayIndex = calendar.component(.weekday, from: today) - 1
        return daySchedules.first { $0.weekdayIndex == weekdayIndex }
    }

    private var todayWeekdayName: String {
        let weekdayIndex = calendar.component(.weekday, from: today) - 1
        let weekdayNames = [
            "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
        ]
        return weekdayNames.indices.contains(weekdayIndex) ? weekdayNames[weekdayIndex] : ""
    }

    private var todaySections: [Section] {
        daySchedules
            .flatMap(\.sections)
            .filter { !tasks(in: $0).isEmpty }
            .sorted { lhs, rhs in
            lhs.sortOrder == rhs.sortOrder
                ? lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                : lhs.sortOrder < rhs.sortOrder
            }
    }

    private var topLevelTasks: [TaskItem] {
        todaySections.flatMap { tasks(in: $0) }
    }

    private var scheduledGoalkeepingTasks: [TaskItem] {
        GoalkeepingRestDay.scheduledTasks(
            from: daySchedules.flatMap(\.sections).flatMap { baseTasks(in: $0) }
        )
    }

    private var isGoalkeepingRestDay: Bool {
        _ = goalkeepingRestDayRevision
        return GoalkeepingRestDay.isRestDay(
            tasks: scheduledGoalkeepingTasks,
            date: today,
            calendar: calendar
        )
    }

    private var completedTaskIDs: Set<UUID> {
        Set(
            todayRecords
                .filter { $0.state == .complete }
                .map(\.taskId)
        )
    }

    private var skippedTaskIDs: Set<UUID> {
        Set(
            todayRecords
                .filter { $0.state == .skipped }
                .map(\.taskId)
        )
    }

    private var todayRecords: [CompletionRecord] {
        let ignoredRecordIDs = GoalkeepingRestDay.ignoredRecordIDs()
        return completionRecords.filter {
            calendar.isDate($0.date, inSameDayAs: today)
                && !ignoredRecordIDs.contains($0.id)
        }
    }

    private var todayProgressCompletion: ProgressDayCompletion {
        HistoricalDayProgress.completion(
            scheduledTaskIDs: topLevelTasks.map(\.id),
            childTaskIDsByParent: DaySnapshotService.childTaskIDsByParent(for: topLevelTasks),
            records: todayRecords
        )
    }

    private var completedTopLevelTaskCount: Int {
        todayProgressCompletion.completedCount
    }

    private var progress: Double {
        guard todayProgressCompletion.scheduledCount > 0 else { return 0 }
        return Double(completedTopLevelTaskCount) / Double(todayProgressCompletion.scheduledCount)
    }

    private var dueTodayAssignments: [Assignment] {
        HomeworkSupport.ordered(assignments.filter {
            !$0.isDone
                && $0.dueDate != HomeworkSupport.noDueDate
                && calendar.isDate($0.dueDate, inSameDayAs: calendarDay)
        })
    }

    private var overdueAssignmentCount: Int {
        assignments.filter {
            !$0.isDone
                && $0.dueDate != HomeworkSupport.noDueDate
                && calendar.startOfDay(for: $0.dueDate) < calendarDay
        }.count
    }

    private var activeWorkout: WorkoutSession? {
        workoutSessions.first { $0.state == .inProgress }
    }

    var body: some View {
        NavigationStack {
            List {
                SwiftUI.Section {
                    todayHero
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(
                            top: LWSpace.xs,
                            leading: 0,
                            bottom: LWSpace.lg,
                            trailing: 0
                        ))
                }

                if homeworkIntegrationEnabled && (!dueTodayAssignments.isEmpty || overdueAssignmentCount > 0) {
                    dueTodaySection
                }

                if !savedMeals.isEmpty {
                    savedMealsSection
                }

                routinePhaseSections
            }
            .trainingLogList()
            .listRowBackground(TrainingLogTheme.background)
            .safeAreaInset(edge: .top, spacing: 0) {
                if let activeWorkout {
                    NavigationLink {
                        WorkoutView()
                    } label: {
                        ActiveWorkoutBanner(workout: activeWorkout)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, LWSpace.screenInset)
                    .padding(.vertical, LWSpace.xs)
                    .background(LWColor.surface)
                }
            }
            .navigationTitle("Today")
            .confirmationDialog(
                "Log \(favoriteAwaitingCategory?.foodName ?? "meal") as",
                isPresented: Binding(get: { favoriteAwaitingCategory != nil }, set: { if !$0 { favoriteAwaitingCategory = nil } })
            ) {
                ForEach(MealCategory.allCases) { category in
                    Button(category.displayName) {
                        if let meal = favoriteAwaitingCategory { quickLogFavorite(meal, as: category) }
                        favoriteAwaitingCategory = nil
                    }
                }
                Button("Cancel", role: .cancel) { favoriteAwaitingCategory = nil }
            }
            .confirmationDialog(
                "Are you on the next day?",
                isPresented: $showingRolloverConfirmation,
                titleVisibility: .visible
            ) {
                Button("Keep working on \(today.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))") {
                    deferRollover()
                }
                Button("Start \(calendarDay.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))") {
                    startCalendarDay()
                }
                Button("Cancel", role: .cancel) {
                    deferRollover()
                }
            } message: {
                Text("Your routine is still set to \(today.formatted(.dateTime.weekday(.wide).month(.wide).day())).")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        hideCompleted.toggle()
                    } label: {
                        Image(systemName: hideCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                    }
                    .accessibilityLabel(hideCompleted ? "Show completed tasks" : "Hide completed tasks")
                    .accessibilityHint("Toggles completed tasks in the Today checklist")
                }
            }
            .overlay {
                if todaySchedule == nil {
                    ContentUnavailableView(
                        "No Schedule for Today",
                        systemImage: "calendar.badge.exclamationmark"
                    )
                }
            }
            .alert(
                "Could Not Save Completion",
                isPresented: Binding(
                    get: { saveErrorMessage != nil },
                    set: { if !$0 { saveErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "")
            }
            .overlay {
                if completionMomentVisible {
                    DayCompleteMoment()
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .bottom) {
                if let undoState {
                    LWToast(
                        message: "Completion changed",
                        actionTitle: "Undo",
                        action: { undoCompletion(undoState) }
                    )
                    .padding(.horizontal, LWSpace.screenInset)
                    .padding(.bottom, LWSpace.sm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onAppear {
                routineDay = RoutineDaySelection.selectedDay(now: currentTime, calendar: calendar)
                if !RoutineDaySelection.hasSavedSelection() {
                    RoutineDaySelection.select(routineDay, calendar: calendar)
                }
                _ = captureTodayIfNeeded()
                collapseFinishedPhases()
                updateRolloverConfirmation()
            }
            .onChange(of: completedTaskIDs) { _, _ in
                collapseFinishedPhases()
            }
            .onChange(of: today) { _, _ in
                collapsedPhases.removeAll()
                manuallyExpandedCompletedPhases.removeAll()
                expandedLiftParentIDs.removeAll()
                _ = captureTodayIfNeeded()
                collapseFinishedPhases()
            }
            .onChange(of: currentTime) { _, _ in
                updateRolloverConfirmation()
            }
            .task {
                while !Task.isCancelled {
                    currentTime = Date()
                    try? await Task.sleep(nanoseconds: 60_000_000_000)
                }
            }
            .trainingLogNavigation()
        }
    }

    /// The next thing to actually do — first scheduled task that is neither
    /// complete nor skipped, in routine order.
    private var nextTask: TaskItem? {
        topLevelTasks.first { !isTaskComplete($0) && !isTaskSkipped($0) }
    }

    /// Screen header. Progress is the point of this app, so it gets real estate:
    /// date, a large ring, and the next task promoted above the fold.
    private var todayHero: some View {
        VStack(alignment: .leading, spacing: LWSpace.md) {
            HStack(alignment: .center, spacing: LWSpace.lg) {
                VStack(alignment: .leading, spacing: LWSpace.xxs) {
                    Text(today, format: .dateTime.weekday(.wide))
                        .font(LWFont.title)
                        .foregroundStyle(LWColor.ink)

                    Text(today, format: .dateTime.month(.wide).day())
                        .font(LWFont.callout)
                        .foregroundStyle(LWColor.inkSecondary)

                    Text("\(completedTopLevelTaskCount) of \(todayProgressCompletion.scheduledCount) complete")
                        .font(LWFont.caption)
                        .monospacedDigit()
                        .foregroundStyle(LWColor.inkSecondary)
                        .padding(.top, LWSpace.xxs)
                }

                Spacer(minLength: LWSpace.sm)

                LWProgressRing(
                    progress: progress,
                    size: 92,
                    isPulsing: completionRingPulsing
                )
                .accessibilityLabel("Today's progress")
                .accessibilityValue("\(completedTopLevelTaskCount) of \(todayProgressCompletion.scheduledCount) top-level tasks completed")
            }

            if let nextTask {
                Divider().overlay(LWColor.hairline)

                VStack(alignment: .leading, spacing: LWSpace.xxs) {
                    Text("Next")
                        .font(LWFont.caption)
                        .foregroundStyle(LWColor.accent)

                    Text(nextTask.title)
                        .font(LWFont.bodyStrong)
                        .foregroundStyle(LWColor.ink)

                    if !nextTask.detail.isEmpty {
                        Text(nextTask.detail)
                            .font(LWFont.callout)
                            .foregroundStyle(LWColor.inkSecondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Next up: \(nextTask.title)")
            }

            if isHoldingPriorRoutineDay {
                Divider().overlay(LWColor.hairline)

                Button {
                    startCalendarDay()
                } label: {
                    Label(
                        "Start \(calendarDay.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))",
                        systemImage: "arrow.right.circle"
                    )
                    .font(LWFont.calloutMedium)
                    .foregroundStyle(LWColor.accent)
                    .frame(minHeight: LWSpace.minTapTarget, alignment: .leading)
                }
                .buttonStyle(.plain)
            }

            if !scheduledGoalkeepingTasks.isEmpty {
                Divider().overlay(LWColor.hairline)

                HStack(spacing: LWSpace.sm) {
                    VStack(alignment: .leading, spacing: LWSpace.xxs) {
                        Text("Goalkeeping")
                            .font(LWFont.bodyStrong)
                            .foregroundStyle(LWColor.ink)
                        Text(isGoalkeepingRestDay ? "Rest day — excluded from progress" : "Scheduled for this routine day")
                            .font(LWFont.caption)
                            .foregroundStyle(LWColor.inkSecondary)
                    }

                    Spacer(minLength: LWSpace.xs)

                    Button(isGoalkeepingRestDay ? "Goalkeeping today" : "Rest day") {
                        setGoalkeepingRestDay(!isGoalkeepingRestDay)
                    }
                    .font(LWFont.captionMedium)
                    .foregroundStyle(isGoalkeepingRestDay ? LWColor.accent : LWColor.inkSecondary)
                    .frame(minHeight: LWSpace.minTapTarget)
                    .buttonStyle(.plain)
                    .accessibilityHint(isGoalkeepingRestDay ? "Restores goalkeeping tasks" : "Skips goalkeeping only for this routine day")
                }
            }
        }
        .lwBlock(padding: LWSpace.lg, radius: LWRadius.xl)
    }

    private var dueTodaySection: some View {
        SwiftUI.Section {
            NavigationLink {
                HomeworkView()
            } label: {
                HStack(spacing: LWSpace.xs) {
                    Text("Due today")
                        .font(LWFont.heading)
                        .foregroundStyle(LWColor.ink)
                    Spacer(minLength: LWSpace.xs)
                    if overdueAssignmentCount > 0 {
                        LWChip(
                            text: "\(overdueAssignmentCount) overdue",
                            tint: LWColor.danger,
                            fill: LWColor.danger.opacity(0.12)
                        )
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LWColor.inkTertiary)
                }
            }
            .buttonStyle(.plain)

            ForEach(dueTodayAssignments.prefix(3)) { assignment in
                dueTodayAssignmentRow(assignment)
            }
            if dueTodayAssignments.count > 3 {
                Text("+\(dueTodayAssignments.count - 3) more due today")
                    .font(LWFont.caption)
                    .foregroundStyle(TrainingLogTheme.secondaryText)
            }
        }
    }

    private var savedMealsSection: some View {
        SwiftUI.Section("Eating") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LWSpace.xs) {
                    ForEach(Array(savedMeals.prefix(4))) { meal in
                        Button { favoriteAwaitingCategory = meal } label: {
                            VStack(alignment: .leading, spacing: LWSpace.xxs) {
                                Text(meal.foodName)
                                    .font(LWFont.calloutMedium)
                                    .foregroundStyle(LWColor.ink)
                                    .lineLimit(1)
                                Text("\(meal.calories) kcal · \(meal.mealCategory.displayName)")
                                    .font(LWFont.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(LWColor.inkSecondary)
                            }
                            .frame(width: 150, alignment: .leading)
                            .padding(LWSpace.sm)
                            .background(
                                LWColor.surfaceRaised,
                                in: RoundedRectangle(cornerRadius: LWRadius.md)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: LWRadius.md)
                                    .stroke(LWColor.hairline, lineWidth: LWStroke.hairline)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Log \(meal.foodName)")
                    }
                }
            }
            .padding(.vertical, 3)
        }
    }

    private var routinePhaseSections: some View {
        ForEach(RoutineDayPhase.allCases) { phase in
            let phaseTasks = routineTasks(in: phase)
            if !phaseTasks.isEmpty {
                SwiftUI.Section {
                    if !isPhaseCollapsed(phase) {
                        ForEach(phaseTasks) { task in
                            if !shouldHide(task) {
                                VStack(alignment: .leading, spacing: 8) {
                                    taskRow(task, isSubstep: false)

                                    if expandedLiftParentIDs.contains(task.id) {
                                        ForEach(children(of: task)) { child in
                                            if !shouldHide(child) {
                                                taskRow(child, isSubstep: true)
                                                    .padding(.leading, 28)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                } header: {
                    phaseSectionHeader(phase, tasks: phaseTasks)
                }
            }
        }
    }

    private func dueTodayAssignmentRow(_ assignment: Assignment) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(assignment.title)
                HStack(spacing: 4) {
                    if let course = assignment.course { Text(course.name) }
                    Text(assignment.dueDate, format: .dateTime.hour().minute())
                        .monospacedDigit()
                }
                .font(LWFont.caption)
                .foregroundStyle(TrainingLogTheme.secondaryText)
            }
            Spacer(minLength: 8)
            Button {
                assignment.isDone.toggle()
                assignment.completedAt = assignment.isDone ? Date() : nil
                assignment.updatedAt = Date()
                do {
                    try modelContext.save()
                    WidgetTimeline.reloadAll()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } catch {
                    modelContext.rollback()
                    saveErrorMessage = error.localizedDescription
                }
            } label: {
                LWCheckControl(state: assignment.isDone ? .complete : .pending)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(assignment.isDone ? "Mark \(assignment.title) incomplete" : "Mark \(assignment.title) complete")
        }
        .trainingLogRow()
    }

    private func phaseSectionHeader(_ phase: RoutineDayPhase, tasks: [TaskItem]) -> some View {
        let phaseLabel = RoutinePhasePreferences.label(for: phase)
        let startGuidance = RoutinePhasePreferences.startGuidance(for: phase)
        let guidanceText = startGuidance.map { "From \($0)" } ?? "Flexible"
        let completed = tasks.filter { isTaskComplete($0) }.count

        return Button {
            if collapsedPhases.contains(phase) {
                collapsedPhases.remove(phase)
                if isPhaseComplete(phase) {
                    manuallyExpandedCompletedPhases.insert(phase)
                }
            } else {
                collapsedPhases.insert(phase)
                manuallyExpandedCompletedPhases.remove(phase)
            }
        } label: {
            VStack(alignment: .leading, spacing: LWSpace.xs) {
                HStack(spacing: LWSpace.xs) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(phaseLabel)
                            .font(LWFont.heading)
                            .foregroundStyle(LWColor.ink)
                        Text(guidanceText)
                            .font(LWFont.caption)
                            .foregroundStyle(LWColor.inkSecondary)
                    }

                    Spacer(minLength: LWSpace.xs)

                    Text("\(completed)/\(tasks.count)")
                        .font(LWFont.monoSmall)
                        .monospacedDigit()
                        .foregroundStyle(LWColor.inkSecondary)

                    Image(systemName: isPhaseCollapsed(phase) ? "chevron.right" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LWColor.inkTertiary)
                }

                LWProgressBar(
                    progress: tasks.isEmpty ? 0 : Double(completed) / Double(tasks.count)
                )
            }
            .padding(.vertical, LWSpace.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(phaseLabel), \(completed) of \(tasks.count) complete")
        .accessibilityHint(isPhaseCollapsed(phase) ? "Double tap to expand" : "Double tap to collapse")
    }

    private func baseTasks(in section: Section) -> [TaskItem] {
        section.tasks
            .filter {
                !$0.isArchived
                    && !$0.isSubstep
                    && $0.parent == nil
                    && $0.daysOfWeek.contains(todayWeekdayName)
            }
            .sorted { lhs, rhs in
                lhs.routinePhase.sortRank == rhs.routinePhase.sortRank
                    ? (lhs.sortOrder == rhs.sortOrder
                        ? lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                        : lhs.sortOrder < rhs.sortOrder)
                    : lhs.routinePhase.sortRank < rhs.routinePhase.sortRank
            }
    }

    private func tasks(in section: Section) -> [TaskItem] {
        baseTasks(in: section).filter { task in
            !isGoalkeepingRestDay || task.domain != .goalkeeping
        }
    }

    private func children(of task: TaskItem) -> [TaskItem] {
        task.children
            .filter { !$0.isArchived }
            .sorted { lhs, rhs in
                lhs.sortOrder == rhs.sortOrder
                    ? lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                    : lhs.sortOrder < rhs.sortOrder
            }
    }

    private func routineTasks(in phase: RoutineDayPhase) -> [TaskItem] {
        todaySections.flatMap { tasks(in: $0) }
            .filter { $0.routinePhase == phase }
    }

    private func isPhaseComplete(_ phase: RoutineDayPhase) -> Bool {
        isPhaseComplete(phase, completedIDs: completedTaskIDs)
    }

    private func isPhaseComplete(_ phase: RoutineDayPhase, completedIDs: Set<UUID>) -> Bool {
        let phaseTasks = routineTasks(in: phase)
        return !phaseTasks.isEmpty && phaseTasks.allSatisfy {
            isTaskComplete($0, completedIDs: completedIDs)
        }
    }

    private func isPhaseCollapsed(_ phase: RoutineDayPhase) -> Bool {
        collapsedPhases.contains(phase)
    }

    private func shouldHide(_ task: TaskItem) -> Bool {
        hideCompleted && isTaskComplete(task)
    }

    /// Current-time marker. An accent rule with the actual time, rather than a
    /// tracked-out "NOW" caption.
    private var nowDivider: some View {
        HStack(spacing: LWSpace.xs) {
            Circle()
                .fill(LWColor.accent)
                .frame(width: 5, height: 5)

            Text(currentTime, format: .dateTime.hour().minute())
                .font(LWFont.monoSmall)
                .monospacedDigit()
                .foregroundStyle(LWColor.accent)

            Rectangle()
                .fill(LWColor.accent.opacity(0.35))
                .frame(height: LWStroke.hairline)
        }
        .padding(.vertical, LWSpace.xxs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Now. Upcoming tasks follow")
    }

    private func taskRow(_ task: TaskItem, isSubstep: Bool) -> some View {
        let isParentSummary = !isSubstep && !children(of: task).isEmpty
        let isCompleted = isTaskComplete(task)
        let isSkipped = isTaskSkipped(task)

        let state: LWTaskState = {
            if isSkipped { return .skipped }
            if isParentSummary { return isCompleted ? .parentComplete : .parentIncomplete }
            return isCompleted ? .complete : .pending
        }()

        let label = HStack(alignment: .top, spacing: LWSpace.sm) {
            LWCheckControl(state: state, size: isSubstep ? 20 : 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: LWSpace.xxs) {
                Text(task.title)
                    .font(isSubstep ? LWFont.callout : LWFont.body)
                    .foregroundStyle(
                        isSkipped
                            ? LWColor.inkTertiary
                            : isCompleted ? LWColor.inkSecondary : LWColor.ink
                    )
                    .strikethrough(isSkipped, color: LWColor.inkTertiary)

                if !task.detail.isEmpty {
                    Text(task.detail)
                        .font(LWFont.caption)
                        .foregroundStyle(LWColor.inkSecondary)
                        .multilineTextAlignment(.leading)
                }

                if isSkipped {
                    Text("Skipped — excluded from progress")
                        .font(LWFont.caption)
                        .foregroundStyle(LWColor.inkTertiary)
                } else if isParentSummary {
                    Text(isCompleted ? "All sub-steps complete" : "Complete sub-steps")
                        .font(LWFont.caption)
                        .foregroundStyle(LWColor.inkSecondary)
                }
            }
            .contentShape(Rectangle())

            Spacer(minLength: LWSpace.sm)

        }

        if isParentSummary {
            return AnyView(
                label
                    .trainingLogRow()
                    .contentShape(Rectangle())
                    .gesture(parentControlGesture(for: task))
                    .animation(LWMotion.toggle, value: isCompleted)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(task.title), \(isSkipped ? "Skipped" : (isCompleted ? "Completed from sub-steps" : "Sub-steps incomplete"))")
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        skipAction(for: task, isSkipped: isSkipped)
                    }
            )
        }

        return AnyView(
            Button {
                toggleCompletion(for: task)
            } label: {
                label
            }
            .buttonStyle(.plain)
            .trainingLogRow()
            .accessibilityLabel(isSubstep ? "Sub-step: \(task.title)" : task.title)
            .accessibilityValue(isSkipped ? "Skipped" : (isCompleted ? "Completed" : "Not completed"))
            .accessibilityHint("Double tap to \(isCompleted ? "mark incomplete" : "mark complete")")
            .animation(LWMotion.toggle, value: isCompleted)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                skipAction(for: task, isSkipped: isSkipped)
            }
        )
    }

    @ViewBuilder
    private func skipAction(for task: TaskItem, isSkipped: Bool) -> some View {
        Button {
            toggleSkip(for: task)
        } label: {
            Label(isSkipped ? "Unskip" : "Skip", systemImage: isSkipped ? "arrow.uturn.backward" : "forward.fill")
        }
        .tint(TrainingLogTheme.secondaryText)
        .accessibilityLabel(isSkipped ? "Unskip \(task.title)" : "Skip \(task.title)")
    }

    private func toggleCompletion(for task: TaskItem) {
        applyCompletionChange(
            taskIDs: Set([task.id]).union(task.parent.map { [$0.id] } ?? []),
            shouldComplete: !completedTaskIDs.contains(task.id),
            completionTaskIDs: Set([task.id])
        )
    }

    private func toggleSkip(for task: TaskItem) {
        let activeChildren = children(of: task)
        let taskIDs: Set<UUID>
        let recordTaskIDs: Set<UUID>
        if !activeChildren.isEmpty {
            taskIDs = Set(activeChildren.map(\.id)).union([task.id])
            recordTaskIDs = Set(activeChildren.map(\.id))
        } else {
            taskIDs = Set([task.id]).union(task.parent.map { [$0.id] } ?? [])
            recordTaskIDs = [task.id]
        }
        applyCompletionChange(
            taskIDs: taskIDs,
            shouldComplete: false,
            completionTaskIDs: recordTaskIDs,
            recordState: isTaskSkipped(task) ? nil : .skipped
        )
    }

    private func toggleLiftParentCompletion(for parent: TaskItem) {
        let activeChildren = children(of: parent)
        guard !activeChildren.isEmpty else {
            toggleCompletion(for: parent)
            return
        }

        applyCompletionChange(
            taskIDs: Set(activeChildren.map(\.id)).union([parent.id]),
            shouldComplete: !isTaskComplete(parent),
            completionTaskIDs: Set(activeChildren.map(\.id))
        )
    }

    private func parentControlGesture(for task: TaskItem) -> some Gesture {
        LongPressGesture(minimumDuration: 0.45)
            .exclusively(before: TapGesture())
            .onEnded { value in
                switch value {
                case .first:
                    withAnimation(.snappy) {
                        if expandedLiftParentIDs.contains(task.id) {
                            expandedLiftParentIDs.remove(task.id)
                        } else {
                            expandedLiftParentIDs.insert(task.id)
                        }
                    }
                case .second:
                    toggleLiftParentCompletion(for: task)
                }
            }
    }

    private func applyCompletionChange(
        taskIDs: Set<UUID>,
        shouldComplete: Bool,
        completionTaskIDs: Set<UUID>? = nil,
        recordState: CompletionRecordState? = nil
    ) {
        let recordTaskIDs = completionTaskIDs ?? taskIDs
        guard !isSavingCompletion else { return }
        isSavingCompletion = true
        defer { isSavingCompletion = false }

        let matchingRecords = completionRecords.filter {
            taskIDs.contains($0.taskId) && calendar.isDate($0.date, inSameDayAs: today)
        }
        let snapshots = matchingRecords.map(CompletionRecordSnapshot.init)
        let beforeCompletedIDs = completedTaskIDs
        let resultingState = shouldComplete ? CompletionRecordState.complete : recordState

        var projectedCompletedIDs = beforeCompletedIDs
        if shouldComplete {
            projectedCompletedIDs.formUnion(recordTaskIDs)
        } else {
            projectedCompletedIDs.subtract(taskIDs)
        }

        let completedPhases = RoutineDayPhase.allCases.filter {
            !isPhaseComplete($0, completedIDs: beforeCompletedIDs)
                && isPhaseComplete($0, completedIDs: projectedCompletedIDs)
        }
        let completesFinalTopLevelTask = shouldComplete
            && !topLevelTasks.isEmpty
            && completedTopLevelTaskCount < todayProgressCompletion.scheduledCount
            && topLevelTasks.allSatisfy {
                TaskCompletion.isComplete($0, completedTaskIDs: projectedCompletedIDs)
            }

        do {
            try RoutineCompletionCommand.apply(
                taskIDs: taskIDs,
                recordTaskIDs: recordTaskIDs,
                date: today,
                state: resultingState,
                in: modelContext,
                calendar: calendar
            )

            withAnimation(.snappy) {
                manuallyExpandedCompletedPhases.subtract(completedPhases)
                collapsedPhases.formUnion(completedPhases)
                if !shouldComplete {
                    collapsedPhases.subtract(RoutineDayPhase.allCases.filter {
                        !isPhaseComplete($0, completedIDs: projectedCompletedIDs)
                    })
                }
            }

            showUndo(snapshots: snapshots, taskIDs: taskIDs)
            if shouldComplete {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            if !completedPhases.isEmpty {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            if completesFinalTopLevelTask {
                showCompletionMoment()
                playDayCompleteHaptic()
            }
        } catch {
            modelContext.rollback()
            saveErrorMessage = error.localizedDescription
        }
    }

    private func quickLogFavorite(_ meal: SavedMeal, as category: MealCategory) {
        let order = mealEntriesForToday(category: category).map(\.sortOrder).max().map { $0 + 1 } ?? 0
        modelContext.insert(MealEntry(
            date: today,
            mealCategory: category,
            foodName: meal.foodName,
            calories: meal.calories,
            proteinGrams: meal.proteinGrams,
            carbohydrateGrams: meal.carbohydrateGrams,
            fatGrams: meal.fatGrams,
            fiberGrams: meal.fiberGrams,
            sortOrder: order
        ))
        do { try modelContext.save() } catch { modelContext.rollback(); saveErrorMessage = error.localizedDescription }
    }

    private func mealEntriesForToday(category: MealCategory) -> [MealEntry] {
        let descriptor = FetchDescriptor<MealEntry>()
        return (try? modelContext.fetch(descriptor))?.filter {
            calendar.isDate($0.date, inSameDayAs: today) && $0.mealCategory == category
        } ?? []
    }

    private func collapseFinishedPhases() {
        let completedPhases = Set(RoutineDayPhase.allCases.filter {
            isPhaseComplete($0)
        })
        manuallyExpandedCompletedPhases.formIntersection(completedPhases)
        collapsedPhases.formUnion(
            completedPhases.subtracting(manuallyExpandedCompletedPhases)
        )
        collapsedPhases.subtract(
            Set(RoutineDayPhase.allCases).subtracting(completedPhases)
        )
    }

    private func isTaskSkipped(_ task: TaskItem) -> Bool {
        if skippedTaskIDs.contains(task.id) {
            return true
        }
        let activeChildren = children(of: task)
        return !activeChildren.isEmpty && activeChildren.allSatisfy { skippedTaskIDs.contains($0.id) }
    }

    private func isTaskComplete(_ task: TaskItem, completedIDs: Set<UUID>? = nil) -> Bool {
        if let completedIDs {
            return TaskCompletion.isComplete(task, completedTaskIDs: completedIDs)
        }
        return HistoricalDayProgress.completion(
            scheduledTaskIDs: [task.id],
            childTaskIDsByParent: DaySnapshotService.childTaskIDsByParent(for: [task]),
            records: todayRecords
        ).isComplete
    }

    private func captureTodayIfNeeded() -> Bool {
        captureDayIfNeeded(today)
    }

    private func captureDayIfNeeded(_ date: Date) -> Bool {
        do {
            _ = try DaySnapshotService.captureIfNeeded(
                for: date,
                in: modelContext,
                calendar: calendar
            )
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            saveErrorMessage = error.localizedDescription
            return false
        }
    }

    private func updateRolloverConfirmation() {
        showingRolloverConfirmation = RoutineDaySelection.needsRolloverConfirmation(
            now: currentTime,
            calendar: calendar
        )
    }

    private func deferRollover() {
        RoutineDaySelection.deferRollover(for: calendarDay, calendar: calendar)
        showingRolloverConfirmation = false
    }

    private func startCalendarDay() {
        let newDay = calendarDay
        guard captureDayIfNeeded(newDay) else { return }
        RoutineDaySelection.select(newDay, calendar: calendar)
        routineDay = newDay
        showingRolloverConfirmation = false
        undoState = nil
        WidgetTimeline.reloadAll()
    }

    private func setGoalkeepingRestDay(_ isRestDay: Bool) {
        guard !isSavingCompletion else { return }
        isSavingCompletion = true
        defer { isSavingCompletion = false }

        do {
            try GoalkeepingRestDay.setRestDay(
                isRestDay,
                tasks: scheduledGoalkeepingTasks,
                date: today,
                in: modelContext,
                calendar: calendar
            )
            goalkeepingRestDayRevision += 1
            collapseFinishedPhases()
        } catch {
            modelContext.rollback()
            saveErrorMessage = error.localizedDescription
        }
    }

    private func showUndo(snapshots: [CompletionRecordSnapshot], taskIDs: Set<UUID>) {
        let undo = CompletionUndo(snapshots: snapshots, taskIDs: taskIDs)
        withAnimation(.snappy) {
            undoState = undo
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard undoState?.id == undo.id else { return }
            withAnimation(.snappy) {
                undoState = nil
            }
        }
    }

    private func undoCompletion(_ undo: CompletionUndo) {
        let currentRecords = completionRecords.filter {
            undo.taskIDs.contains($0.taskId) && calendar.isDate($0.date, inSameDayAs: today)
        }
        currentRecords.forEach(modelContext.delete)
        undo.snapshots.forEach { snapshot in
            modelContext.insert(snapshot.record)
        }

        do {
            try modelContext.save()
            WidgetTimeline.reloadAll()
            withAnimation(.snappy) {
                undoState = nil
                collapsedPhases.subtract(RoutineDayPhase.allCases.filter {
                    !isPhaseComplete($0)
                })
            }
        } catch {
            modelContext.rollback()
            saveErrorMessage = error.localizedDescription
        }
    }

    private func playDayCompleteHaptic() {
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        let light = UIImpactFeedbackGenerator(style: .light)
        let medium = UIImpactFeedbackGenerator(style: .medium)
        heavy.prepare()
        light.prepare()
        medium.prepare()
        heavy.impactOccurred(intensity: 0.9)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            light.impactOccurred(intensity: 0.55)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            medium.impactOccurred(intensity: 0.75)
        }
    }

    private func showCompletionMoment() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.52)) {
            completionMomentVisible = true
            completionRingPulsing = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_050_000_000)
            withAnimation(.easeOut(duration: 0.25)) {
                completionMomentVisible = false
                completionRingPulsing = false
            }
        }
    }
}

private struct CompletionRecordSnapshot {
    let id: UUID
    let date: Date
    let taskID: UUID
    let completedAt: Date
    let state: CompletionRecordState

    init(_ record: CompletionRecord) {
        id = record.id
        date = record.date
        taskID = record.taskId
        completedAt = record.completedAt
        state = record.state
    }

    var record: CompletionRecord {
        CompletionRecord(id: id, date: date, taskId: taskID, completedAt: completedAt, state: state)
    }
}

private struct CompletionUndo: Identifiable {
    let id = UUID()
    let snapshots: [CompletionRecordSnapshot]
    let taskIDs: Set<UUID>
}

private struct ActiveWorkoutBanner: View {
    let workout: WorkoutSession

    private var setCount: Int {
        workout.exercises.reduce(0) { $0 + $1.sets.count }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            LWBanner(
                title: displayTitle,
                subtitle: "\(elapsedText(at: context.date))  ·  \(setCount) sets",
                tint: LWColor.warning,
                systemImage: "figure.strengthtraining.traditional"
            )
        }
    }

    private func elapsedText(at date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(workout.startedAt)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private var displayTitle: String {
        let title = workout.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? "Workout in progress" : title
    }
}

/// The one signature beat: finishing every task for the day.
///
/// A serif mark that scales in over a dimmed screen, rather than the caption-sized
/// string that used to fade in at the top edge.
private struct DayCompleteMoment: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            LWColor.surface.opacity(0.86)
                .ignoresSafeArea()

            VStack(spacing: LWSpace.md) {
                ZStack {
                    Circle()
                        .strokeBorder(LWColor.success, lineWidth: 2)
                        .frame(width: 96, height: 96)
                        .scaleEffect(appeared ? 1 : 0.7)
                        .opacity(appeared ? 1 : 0)

                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(LWColor.success)
                        .scaleEffect(appeared ? 1 : 0.4)
                }

                VStack(spacing: LWSpace.xxs) {
                    Text("Day complete")
                        .font(LWFont.title)
                        .foregroundStyle(LWColor.ink)

                    Text("Every scheduled task done.")
                        .font(LWFont.callout)
                        .foregroundStyle(LWColor.inkSecondary)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Day complete. Every scheduled task done.")
        .onAppear {
            withAnimation(LWMotion.celebrate) { appeared = true }
        }
    }
}
