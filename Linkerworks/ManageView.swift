import SwiftData
import SwiftUI

struct ManageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Section.sortOrder) private var sections: [Section]

    @State private var showingArchived = false
    @State private var taskToEdit: TaskItem?
    @State private var showingAddTask = false
    @State private var saveErrorMessage: String?

    private var orderedSections: [Section] {
        sections.sorted { lhs, rhs in
            let lhsDay = lhs.daySchedule?.weekdayIndex ?? .max
            let rhsDay = rhs.daySchedule?.weekdayIndex ?? .max

            if lhsDay != rhsDay { return lhsDay < rhsDay }
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            List {
                SwiftUI.Section {
                    TrainingLogFilterTabs(
                        selection: $showingArchived,
                        firstTitle: "Active",
                        secondTitle: "Archived"
                    )
                    .listRowSeparator(.hidden)
                }

                ForEach(orderedSections) { section in
                    let sectionTasks = tasks(in: section)
                    if !sectionTasks.isEmpty {
                        ForEach(RoutineDayPhase.allCases) { phase in
                            let phaseTasks = sectionTasks.filter { $0.routinePhase == phase }
                            if !phaseTasks.isEmpty {
                                SwiftUI.Section("\(sectionTitle(for: section)) · \(RoutinePhasePreferences.label(for: phase))") {
                                    ForEach(phaseTasks) { task in
                                Button {
                                    taskToEdit = task
                                } label: {
                                    TaskSummaryRow(task: task)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: !showingArchived) {
                                    if showingArchived {
                                        Button("Restore") {
                                            restore(task)
                                        }
                                        .tint(TrainingLogTheme.primaryText)
                                    } else {
                                        Button("Archive") {
                                            archive(task)
                                        }
                                        .tint(TrainingLogTheme.primaryText)
                                    }
                                }
                            }
                                    .onMove { source, destination in
                                        reorder(phaseTasks, from: source, to: destination)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .trainingLogList()
            .listRowBackground(TrainingLogTheme.background)
            .navigationTitle("Manage")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !showingArchived {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddTask = true
                    } label: {
                        Label("Add Task", systemImage: "plus")
                    }
                    .disabled(showingArchived || orderedSections.isEmpty)
                }
            }
            .overlay {
                if orderedSections.allSatisfy({ tasks(in: $0).isEmpty }) {
                    ContentUnavailableView(
                        showingArchived ? "No Archived Tasks" : "No Active Tasks",
                        systemImage: showingArchived ? "archivebox" : "checklist"
                    )
                }
            }
            .sheet(isPresented: $showingAddTask) {
                TaskEditorView(task: nil, sections: orderedSections)
            }
            .sheet(item: $taskToEdit) { task in
                TaskEditorView(task: task, sections: orderedSections)
            }
            .alert(
                "Could Not Save Task",
                isPresented: Binding(
                    get: { saveErrorMessage != nil },
                    set: { if !$0 { saveErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "")
            }
        }
        .trainingLogNavigation()
    }

    private func tasks(in section: Section) -> [TaskItem] {
        section.tasks
            .filter {
                $0.isArchived == showingArchived && !$0.isSubstep && $0.parent == nil
            }
            .sorted { lhs, rhs in
                lhs.routinePhase.sortRank == rhs.routinePhase.sortRank
                    ? (lhs.sortOrder == rhs.sortOrder
                        ? lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                        : lhs.sortOrder < rhs.sortOrder)
                    : lhs.routinePhase.sortRank < rhs.routinePhase.sortRank
            }
    }

    private func sectionTitle(for section: Section) -> String {
        guard let weekday = section.daySchedule?.weekdayName else { return section.name }
        return "\(weekday) · \(section.name)"
    }

    private func reorder(_ tasks: [TaskItem], from source: IndexSet, to destination: Int) {
        guard !showingArchived else { return }

        var reordered = tasks
        reordered.move(fromOffsets: source, toOffset: destination)

        for (index, task) in reordered.enumerated() {
            task.sortOrder = index
        }
        saveChanges()
    }

    private func archive(_ task: TaskItem) {
        task.isArchived = true
        task.children.forEach { $0.isArchived = true }
        saveChanges()
    }

    private func restore(_ task: TaskItem) {
        task.isArchived = false
        task.children.forEach { $0.isArchived = false }
        saveChanges()
    }

    private func saveChanges() {
        do {
            try modelContext.save()
            WidgetTimeline.reloadAll()
        } catch {
            modelContext.rollback()
            saveErrorMessage = error.localizedDescription
        }
    }
}

private struct TaskSummaryRow: View {
    let task: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: LWSpace.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: LWSpace.xs) {
                Text(task.title)
                    .font(LWFont.body)
                    .foregroundStyle(LWColor.ink)

                Spacer(minLength: LWSpace.xs)

                LWChip(text: RoutinePhasePreferences.label(for: task.routinePhase))
            }

            if !task.detail.isEmpty {
                Text(task.detail)
                    .font(LWFont.caption)
                    .foregroundStyle(LWColor.inkSecondary)
                    .lineLimit(2)
            }
        }
        .trainingLogRow()
    }
}

@MainActor
private struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let task: TaskItem?
    let sections: [Section]

    @State private var title: String
    @State private var routinePhase: RoutineDayPhase
    @State private var detail: String
    @State private var selectedSectionID: UUID?
    @State private var selectedDomain: Domain
    @State private var selectedExtraDays: Set<String>
    @State private var existingSubsteps: [SubstepDraft]
    @State private var archivedExistingSubstepIDs: Set<UUID> = []
    @State private var pendingSubsteps: [SubstepDraft] = []
    @State private var saveErrorMessage: String?

    private let weekdays = [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
    ]

    init(task: TaskItem?, sections: [Section]) {
        self.task = task
        self.sections = sections
        _title = State(initialValue: task?.title ?? "")
        _routinePhase = State(initialValue: task?.routinePhase ?? .anytime)
        _detail = State(initialValue: task?.detail ?? "")
        _selectedSectionID = State(initialValue: task?.section?.id ?? sections.first?.id)
        let initialSection = task?.section ?? sections.first
        _selectedDomain = State(initialValue: task?.domain ?? Domain.inferred(
            for: task?.title ?? "",
            sectionName: initialSection?.name ?? ""
        ))
        let primaryDay = initialSection?.daySchedule?.weekdayName
        _selectedExtraDays = State(
            initialValue: Set(task?.daysOfWeek ?? []).subtracting(Set(primaryDay.map { [$0] } ?? []))
        )
        let initialSubsteps = task?.children
            .sorted { lhs, rhs in
                lhs.sortOrder == rhs.sortOrder
                    ? lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                    : lhs.sortOrder < rhs.sortOrder
            }
            .map(SubstepDraft.init(task:)) ?? []
        _existingSubsteps = State(initialValue: initialSubsteps)
        _archivedExistingSubstepIDs = State(
            initialValue: Set(task?.children.filter(\.isArchived).map(\.id) ?? [])
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("Task") {
                    TextField("Title", text: $title)

                    Picker("Section", selection: $selectedSectionID) {
                        ForEach(sections) { section in
                            Text(sectionLabel(for: section)).tag(Optional(section.id))
                        }
                    }
                    Picker("Part of day", selection: $routinePhase) {
                        ForEach(RoutineDayPhase.allCases) { phase in
                            Text(RoutinePhasePreferences.label(for: phase)).tag(phase)
                        }
                    }
                }

                SwiftUI.Section {
                    DisclosureGroup("Also schedule on other days") {
                        ForEach(weekdays.filter { $0 != primaryScheduledDay }, id: \.self) { weekday in
                            Toggle(
                                weekday,
                                isOn: Binding(
                                    get: { selectedExtraDays.contains(weekday) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedExtraDays.insert(weekday)
                                        } else {
                                            selectedExtraDays.remove(weekday)
                                        }
                                    }
                                )
                            )
                        }
                    }
                } footer: {
                    if let primaryScheduledDay {
                        Text("Scheduled on \(primaryScheduledDay) from the selected section.")
                    }
                }

                SwiftUI.Section {
                    DisclosureGroup("Details") {
                        TextField("Detail", text: $detail, axis: .vertical)
                            .lineLimit(2...5)
                        Picker("Domain", selection: $selectedDomain) {
                            ForEach(Domain.allCases) { domain in
                                Text(domain.displayName).tag(domain)
                            }
                        }
                    }
                }

                substepsSection

                if let task {
                    SwiftUI.Section {
                        if task.isArchived {
                            Button("Restore Task") {
                                restore(task)
                            }
                        } else {
                            Button("Archive Task") {
                                archive(task)
                            }
                        }
                    }
                }
            }
            .trainingLogForm()
            .listRowBackground(TrainingLogTheme.background)
            .navigationTitle(task == nil ? "Add Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedSectionID) { _, newSectionID in
                guard let section = sections.first(where: { $0.id == newSectionID }) else { return }
                if let primaryDay = section.daySchedule?.weekdayName {
                    selectedExtraDays.remove(primaryDay)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTask() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert(
                "Could Not Save Task",
                isPresented: Binding(
                    get: { saveErrorMessage != nil },
                    set: { if !$0 { saveErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "")
            }
        }
        .trainingLogNavigation()
    }

    @ViewBuilder
    private var substepsSection: some View {
        SwiftUI.Section("Lift Sub-Steps") {
            ForEach($existingSubsteps) { $substep in
                if !archivedExistingSubstepIDs.contains(substep.id) {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Sub-step title", text: $substep.title)
                        DisclosureGroup("Details") {
                            TextField("Detail", text: $substep.detail, axis: .vertical)
                                .lineLimit(1...3)
                        }
                        Button("Archive Sub-step") {
                            archivedExistingSubstepIDs.insert(substep.id)
                        }
                        .font(LWFont.caption)
                    }
                }
            }

            ForEach($pendingSubsteps) { $substep in
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Sub-step title", text: $substep.title)
                    DisclosureGroup("Details") {
                        TextField("Detail", text: $substep.detail, axis: .vertical)
                            .lineLimit(1...3)
                    }
                    Button("Remove Sub-step") {
                        pendingSubsteps.removeAll { $0.id == substep.id }
                    }
                    .font(LWFont.caption)
                }
            }

            Button {
                pendingSubsteps.append(SubstepDraft())
            } label: {
                Label("Add Sub-step", systemImage: "plus")
            }
            .disabled(selectedDomain != .lifting)

            if selectedDomain != .lifting {
                Text("Select the Lifting domain to add sub-steps.")
                    .font(LWFont.caption)
                    .foregroundStyle(TrainingLogTheme.secondaryText)
            }
        }
    }

    private func sectionLabel(for section: Section) -> String {
        guard let weekday = section.daySchedule?.weekdayName else { return section.name }
        return "\(weekday) · \(section.name)"
    }

    private var primaryScheduledDay: String? {
        guard
            let selectedSectionID,
            let section = sections.first(where: { $0.id == selectedSectionID })
        else { return nil }
        return section.daySchedule?.weekdayName
    }

    private func saveTask() {
        guard
            let sectionID = selectedSectionID,
            let selectedSection = sections.first(where: { $0.id == sectionID })
        else {
            saveErrorMessage = "Choose a section before saving this task."
            return
        }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let orderedDays = weekdays.filter {
            $0 == selectedSection.daySchedule?.weekdayName || selectedExtraDays.contains($0)
        }
        guard !orderedDays.isEmpty else {
            saveErrorMessage = "Choose at least one day for this task."
            return
        }
        guard existingSubsteps.allSatisfy({
            archivedExistingSubstepIDs.contains($0.id)
                || !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else {
            saveErrorMessage = "Every active sub-step needs a title."
            return
        }
        let hasActiveSubsteps = existingSubsteps.contains {
            !archivedExistingSubstepIDs.contains($0.id)
        } || !pendingSubsteps.isEmpty
        guard selectedDomain == .lifting || !hasActiveSubsteps else {
            saveErrorMessage = "Tasks with active lift sub-steps must use the Lifting domain."
            return
        }
        let savedTask: TaskItem

        if let task {
            let previousSection = task.section
            let previousPhase = task.routinePhase
            task.title = cleanTitle
            task.time = nil
            task.routinePhase = routinePhase
            task.detail = detail
            task.domain = selectedDomain
            // CompletionRecord values are intentionally not queried, edited, or deleted here.
            // Changing scheduled days applies only to future checklist occurrences.
            task.daysOfWeek = orderedDays

            if task.section?.id != selectedSection.id || previousPhase != routinePhase {
                task.section = selectedSection
                task.sortOrder = nextSortOrder(in: selectedSection, phase: routinePhase)
                normalizeSortOrders(in: previousSection)
            }
            savedTask = task
        } else {
            savedTask = TaskItem(
                title: cleanTitle,
                routinePhase: routinePhase,
                detail: detail,
                daysOfWeek: orderedDays,
                sortOrder: nextSortOrder(in: selectedSection, phase: routinePhase),
                domain: selectedDomain
            )
            selectedSection.tasks.append(savedTask)
            modelContext.insert(savedTask)
        }

        for draft in existingSubsteps {
            guard let existingSubstep = savedTask.children.first(where: { $0.id == draft.id }) else {
                continue
            }
            existingSubstep.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            existingSubstep.time = nil
            existingSubstep.routinePhase = routinePhase
            existingSubstep.detail = draft.detail
            existingSubstep.daysOfWeek = orderedDays
            existingSubstep.isArchived = archivedExistingSubstepIDs.contains(draft.id)
        }

        for draft in pendingSubsteps {
            let cleanSubstepTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanSubstepTitle.isEmpty else {
                saveErrorMessage = "Every added sub-step needs a title."
                return
            }

            let substep = TaskItem(
                title: cleanSubstepTitle,
                routinePhase: routinePhase,
                detail: draft.detail,
                daysOfWeek: orderedDays,
                sortOrder: nextSubstepSortOrder(in: savedTask),
                domain: selectedDomain,
                isSubstep: true
            )
            savedTask.children.append(substep)
            modelContext.insert(substep)
        }

        do {
            try modelContext.save()
            WidgetTimeline.reloadAll()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = error.localizedDescription
        }
    }

    private func archive(_ task: TaskItem) {
        task.isArchived = true
        task.children.forEach { $0.isArchived = true }
        saveAndDismiss()
    }

    private func restore(_ task: TaskItem) {
        task.isArchived = false
        task.children.forEach { $0.isArchived = false }
        saveAndDismiss()
    }

    private func saveAndDismiss() {
        do {
            try modelContext.save()
            WidgetTimeline.reloadAll()
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = error.localizedDescription
        }
    }

    private func nextSortOrder(in section: Section, phase: RoutineDayPhase) -> Int {
        (section.tasks
            .filter { !$0.isSubstep && $0.parent == nil && !$0.isArchived && $0.routinePhase == phase }
            .map(\.sortOrder)
            .max() ?? -1) + 1
    }

    private func nextSubstepSortOrder(in task: TaskItem) -> Int {
        (task.children.map(\.sortOrder).max() ?? -1) + 1
    }

    private func normalizeSortOrders(in section: Section?) {
        guard let section else { return }

        let activeTasks = section.tasks
            .filter { !$0.isArchived && !$0.isSubstep && $0.parent == nil }
            .sorted { $0.routinePhase.sortRank == $1.routinePhase.sortRank ? $0.sortOrder < $1.sortOrder : $0.routinePhase.sortRank < $1.routinePhase.sortRank }
        for phase in RoutineDayPhase.allCases {
            for (index, task) in activeTasks.filter({ $0.routinePhase == phase }).enumerated() {
                task.sortOrder = index
            }
        }
    }
}

private struct SubstepDraft: Identifiable {
    let id: UUID
    var title: String
    var detail: String

    init(id: UUID = UUID(), title: String = "", detail: String = "") {
        self.id = id
        self.title = title
        self.detail = detail
    }

    init(task: TaskItem) {
        self.init(id: task.id, title: task.title, detail: task.detail)
    }
}
