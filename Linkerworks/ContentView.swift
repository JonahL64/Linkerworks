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
        .tint(TrainingLogTheme.primaryText)
        .toolbarBackground(TrainingLogTheme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .background(TrainingLogTheme.background)
        .preferredColorScheme(.dark)
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
    @State private var collapsedSectionIDs: Set<UUID> = []
    @State private var manuallyExpandedCompletedSectionIDs: Set<UUID> = []
    @State private var expandedLiftParentIDs: Set<UUID> = []
    @State private var undoState: CompletionUndo?
    @State private var isSavingCompletion = false
    @State private var currentTime = Date()
    @State private var favoriteAwaitingCategory: SavedMeal?

    private let calendar = Calendar.current

    private var today: Date {
        calendar.startOfDay(for: currentTime)
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

    private var completedTaskIDs: Set<UUID> {
        Set(
            completionRecords
                .filter {
                    calendar.isDate($0.date, inSameDayAs: today)
                        && $0.state == .complete
                }
                .map(\.taskId)
        )
    }

    private var skippedTaskIDs: Set<UUID> {
        Set(
            completionRecords
                .filter {
                    calendar.isDate($0.date, inSameDayAs: today)
                        && $0.state == .skipped
                }
                .map(\.taskId)
        )
    }

    private var todayRecords: [CompletionRecord] {
        completionRecords.filter { calendar.isDate($0.date, inSameDayAs: today) }
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
                && calendar.isDate($0.dueDate, inSameDayAs: today)
        })
    }

    private var overdueAssignmentCount: Int {
        assignments.filter {
            !$0.isDone
                && $0.dueDate != HomeworkSupport.noDueDate
                && calendar.startOfDay(for: $0.dueDate) < today
        }.count
    }

    private var activeWorkout: WorkoutSession? {
        workoutSessions.first { $0.state == .inProgress }
    }

    var body: some View {
        NavigationStack {
            List {
                SwiftUI.Section {
                    HStack(spacing: 14) {
                        ProgressRing(
                            progress: progress,
                            isPulsing: completionRingPulsing
                        )
                            .frame(width: 60, height: 60)
                            .accessibilityLabel("Today's progress")
                            .accessibilityValue("\(completedTopLevelTaskCount) of \(todayProgressCompletion.scheduledCount) top-level tasks completed")

                        VStack(alignment: .leading, spacing: 4) {
                            Text(today, format: .dateTime.weekday(.wide).month().day())
                                .font(.title3.weight(.semibold))
                            Text("\(completedTopLevelTaskCount) of \(todayProgressCompletion.scheduledCount) tasks complete")
                                .font(.subheadline)
                                .foregroundStyle(TrainingLogTheme.secondaryText)
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowSeparator(.hidden)
                }

                if homeworkIntegrationEnabled && (!dueTodayAssignments.isEmpty || overdueAssignmentCount > 0) {
                    SwiftUI.Section {
                        NavigationLink {
                            HomeworkView()
                        } label: {
                            HStack {
                                Text("DUE TODAY")
                                    .font(.caption.weight(.bold))
                                    .tracking(1.1)
                                Spacer()
                                if overdueAssignmentCount > 0 {
                                    Text("\(overdueAssignmentCount) overdue")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(TrainingLogTheme.completionAccent)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(TrainingLogTheme.secondaryText)
                            }
                        }
                        .buttonStyle(.plain)

                        ForEach(dueTodayAssignments.prefix(3)) { assignment in
                            dueTodayAssignmentRow(assignment)
                        }
                        if dueTodayAssignments.count > 3 {
                            Text("+\(dueTodayAssignments.count - 3) more due today")
                                .font(.caption)
                                .foregroundStyle(TrainingLogTheme.secondaryText)
                        }
                    }
                }

                if !savedMeals.isEmpty {
                    SwiftUI.Section("EATING") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(savedMeals.prefix(4))) { meal in
                                    Button { favoriteAwaitingCategory = meal } label: {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(meal.foodName).lineLimit(1)
                                            Text("\(meal.calories) kcal · \(meal.mealCategory.displayName)")
                                                .font(.caption).monospacedDigit()
                                                .foregroundStyle(TrainingLogTheme.secondaryText)
                                        }
                                        .frame(width: 145, alignment: .leading)
                                        .padding(10)
                                        .background(TrainingLogTheme.quietFill, in: RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Log \(meal.foodName)")
                                }
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }

                ForEach(RoutineDayPhase.allCases) { phase in
                    ForEach(todaySections) { section in
                        let phaseTasks = tasks(in: section).filter { $0.routinePhase == phase }
                        if !phaseTasks.isEmpty {
                            SwiftUI.Section {
                                if !isSectionCollapsed(section) {
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
                                phaseSectionHeader(phase, section: section)
                            }
                        }
                    }
                }
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
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(TrainingLogTheme.background)
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
            .overlay(alignment: .top) {
                if completionMomentVisible {
                    Text("DAY COMPLETE")
                        .font(.caption.weight(.bold))
                        .tracking(1.8)
                        .foregroundStyle(TrainingLogTheme.completionAccent)
                        .padding(.top, 8)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .bottom) {
                if let undoState {
                    undoToast(undoState)
                        .padding(.horizontal, TrainingLogTheme.contentInset)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onAppear {
                _ = captureTodayIfNeeded()
                collapseFinishedSections()
            }
            .onChange(of: completedTaskIDs) { _, _ in
                collapseFinishedSections()
            }
            .onChange(of: today) { _, _ in
                collapsedSectionIDs.removeAll()
                manuallyExpandedCompletedSectionIDs.removeAll()
                expandedLiftParentIDs.removeAll()
                _ = captureTodayIfNeeded()
                collapseFinishedSections()
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

    private func dueTodayAssignmentRow(_ assignment: Assignment) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(assignment.title)
                HStack(spacing: 4) {
                    if let course = assignment.course { Text(course.name) }
                    Text(assignment.dueDate, format: .dateTime.hour().minute())
                        .monospacedDigit()
                }
                .font(.caption)
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
                Image(systemName: assignment.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(assignment.isDone ? TrainingLogTheme.completionAccent : TrainingLogTheme.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(assignment.isDone ? "Mark \(assignment.title) incomplete" : "Mark \(assignment.title) complete")
        }
        .trainingLogRow()
    }

    private func phaseSectionHeader(_ phase: RoutineDayPhase, section: Section) -> some View {
        let phaseLabel = RoutinePhasePreferences.label(for: phase)
        let startGuidance = RoutinePhasePreferences.startGuidance(for: phase)
        let guidanceText = startGuidance.map { "From \($0)" } ?? "Flexible"

        return VStack(alignment: .leading, spacing: 2) {
            Text(phaseLabel)
                .trainingLogSectionLabel()
            Text(guidanceText)
                .font(.caption)
                .foregroundStyle(TrainingLogTheme.secondaryText)
            sectionHeader(section)
        }
    }

    private func tasks(in section: Section) -> [TaskItem] {
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

    private func children(of task: TaskItem) -> [TaskItem] {
        task.children
            .filter { !$0.isArchived }
            .sorted { lhs, rhs in
                lhs.sortOrder == rhs.sortOrder
                    ? lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                    : lhs.sortOrder < rhs.sortOrder
            }
    }

    private func isSectionComplete(_ section: Section) -> Bool {
        isSectionComplete(section, completedIDs: completedTaskIDs)
    }

    private func isSectionComplete(_ section: Section, completedIDs: Set<UUID>) -> Bool {
        let sectionTasks = tasks(in: section)
        return !sectionTasks.isEmpty && sectionTasks.allSatisfy {
            isTaskComplete($0, completedIDs: completedIDs)
        }
    }

    private func isSectionCollapsed(_ section: Section) -> Bool {
        collapsedSectionIDs.contains(section.id)
    }

    private func shouldHide(_ task: TaskItem) -> Bool {
        hideCompleted && isTaskComplete(task)
    }

    private func sectionHeader(_ section: Section) -> some View {
        let sectionTasks = tasks(in: section)
        let total = sectionTasks.count
        let completed = sectionTasks.filter {
            isTaskComplete($0)
        }.count

        return Button {
            if collapsedSectionIDs.contains(section.id) {
                collapsedSectionIDs.remove(section.id)
                if isSectionComplete(section) {
                    manuallyExpandedCompletedSectionIDs.insert(section.id)
                }
            } else {
                collapsedSectionIDs.insert(section.id)
                manuallyExpandedCompletedSectionIDs.remove(section.id)
            }
        } label: {
            HStack(spacing: 8) {
                Text(section.name)
                    .trainingLogSectionLabel()

                Spacer(minLength: 8)

                Text("\(completed)/\(total)")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(TrainingLogTheme.secondaryText)

                Image(systemName: isSectionCollapsed(section) ? "chevron.right" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TrainingLogTheme.secondaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(section.name), \(completed) of \(total) complete")
        .accessibilityHint(isSectionCollapsed(section) ? "Double tap to expand" : "Double tap to collapse")
    }

    private var nowDivider: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(TrainingLogTheme.divider)
                .frame(height: 1)
            Text("NOW")
                .font(.caption2.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(TrainingLogTheme.secondaryText)
            Rectangle()
                .fill(TrainingLogTheme.divider)
                .frame(height: 1)
        }
        .padding(.vertical, 6)
        .accessibilityLabel("Now. Upcoming tasks follow")
    }

    private func taskRow(_ task: TaskItem, isSubstep: Bool) -> some View {
        let isParentSummary = !isSubstep && !children(of: task).isEmpty
        let isCompleted = isTaskComplete(task)
        let isSkipped = isTaskSkipped(task)

        let label = HStack(alignment: .top, spacing: 12) {
            Image(systemName: isSkipped ? "forward.circle.fill" : (isCompleted ? "checkmark.circle.fill" : "circle"))
                .font(isSubstep ? .body : .title3)
                .foregroundStyle(
                    isSkipped
                        ? TrainingLogTheme.secondaryText
                        : isCompleted
                        ? TrainingLogTheme.completionAccent
                        : TrainingLogTheme.secondaryText
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .foregroundStyle(isSkipped ? TrainingLogTheme.secondaryText : TrainingLogTheme.primaryText)

                if !task.detail.isEmpty {
                    Text(task.detail)
                        .font(.caption)
                        .foregroundStyle(TrainingLogTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                if isSkipped {
                    Text("Skipped — excluded from progress")
                        .font(.caption)
                        .foregroundStyle(TrainingLogTheme.secondaryText)
                } else if isParentSummary {
                    Text(isCompleted ? "All sub-steps complete" : "Complete sub-steps")
                        .font(.caption)
                        .foregroundStyle(TrainingLogTheme.secondaryText)
                }
            }
            .contentShape(Rectangle())

            Spacer(minLength: 12)

        }

        if isParentSummary {
            return AnyView(
                label
                    .trainingLogRow()
                    .contentShape(Rectangle())
                    .gesture(parentControlGesture(for: task))
                    .animation(.snappy, value: isCompleted)
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
            .animation(.snappy, value: isCompleted)
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

        let completedSections = todaySections.filter {
            !isSectionComplete($0, completedIDs: beforeCompletedIDs)
                && isSectionComplete($0, completedIDs: projectedCompletedIDs)
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
                manuallyExpandedCompletedSectionIDs.subtract(completedSections.map(\.id))
                collapsedSectionIDs.formUnion(completedSections.map(\.id))
                if !shouldComplete {
                    collapsedSectionIDs.subtract(todaySections.filter {
                        !isSectionComplete($0, completedIDs: projectedCompletedIDs)
                    }.map(\.id))
                }
            }

            showUndo(snapshots: snapshots, taskIDs: taskIDs)
            if shouldComplete {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            if !completedSections.isEmpty {
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

    private func collapseFinishedSections() {
        let completedSectionIDs = Set(todaySections.filter {
            isSectionComplete($0)
        }.map(\.id))
        manuallyExpandedCompletedSectionIDs.formIntersection(completedSectionIDs)
        collapsedSectionIDs.formUnion(
            completedSectionIDs.subtracting(manuallyExpandedCompletedSectionIDs)
        )
        collapsedSectionIDs.subtract(
            Set(todaySections.map(\.id)).subtracting(completedSectionIDs)
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
        do {
            _ = try DaySnapshotService.captureIfNeeded(
                for: today,
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

    private func undoToast(_ undo: CompletionUndo) -> some View {
        HStack(spacing: 12) {
            Text("Completion changed")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TrainingLogTheme.primaryText)
            Spacer(minLength: 8)
            Button("Undo") {
                undoCompletion(undo)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(TrainingLogTheme.completionAccent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(TrainingLogTheme.quietFill, in: Capsule())
        .overlay {
            Capsule()
                .stroke(TrainingLogTheme.divider, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
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
                collapsedSectionIDs.subtract(todaySections.filter {
                    !isSectionComplete($0)
                }.map(\.id))
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
            HStack(spacing: 10) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(TrainingLogTheme.completionAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle)
                        .font(.subheadline.weight(.semibold))
                    Text("\(elapsedText(at: context.date))  ·  \(setCount) SETS")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(TrainingLogTheme.secondaryText)
                }
                Spacer()
                Text("RESUME")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TrainingLogTheme.completionAccent)
            }
            .padding(10)
            .background(TrainingLogTheme.background.opacity(0.98))
        }
    }

    private func elapsedText(at date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(workout.startedAt)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private var displayTitle: String {
        let title = workout.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? "WORKOUT IN PROGRESS" : title
    }
}

private struct ProgressRing: View {
    let progress: Double
    let isPulsing: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(TrainingLogTheme.divider, lineWidth: 8)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    TrainingLogTheme.completionAccent,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text(progress, format: .percent.precision(.fractionLength(0)))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .scaleEffect(isPulsing ? 1.12 : 1)
        .animation(
            .spring(response: 0.3, dampingFraction: 0.52),
            value: isPulsing
        )
        .animation(.easeOut(duration: 0.35), value: progress)
    }
}
