import Foundation
import SwiftData
import SwiftUI

enum CertificationSupport {
    static func daysUntil(_ targetDate: Date?, from date: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard let targetDate else { return nil }
        return calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: targetDate)
        ).day
    }

    static func expiresWithin90Days(_ expiresOn: Date?, from date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let expiresOn, let lastDay = calendar.date(byAdding: .day, value: 90, to: calendar.startOfDay(for: date)) else { return false }
        let expiry = calendar.startOfDay(for: expiresOn)
        return expiry >= calendar.startOfDay(for: date) && expiry <= lastDay
    }

    static func completionCount(taskID: UUID?, records: [CompletionRecord], endingOn date: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let taskID, let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: date)) else { return 0 }
        let end = calendar.startOfDay(for: date)
        return records.filter { record in
            let recordDay = calendar.startOfDay(for: record.date)
            return record.taskId == taskID && record.state == .complete && recordDay >= start && recordDay <= end
        }.count
    }

    static func eligibleRoutineTasks(from tasks: [TaskItem]) -> [TaskItem] {
        tasks.filter { !$0.isArchived && !$0.isSubstep && $0.parent == nil }
    }

    static func ownedExamEvent(for certification: Certification, in events: [CalendarEvent]) -> CalendarEvent? {
        guard let eventID = certification.automaticExamEventID else { return nil }
        return events.first { $0.id == eventID }
    }

    static func needsExamEventBackfill(_ certification: Certification, events: [CalendarEvent]) -> Bool {
        guard certification.targetDate != nil else { return false }
        return ownedExamEvent(for: certification, in: events) == nil
    }
}

enum CertificationExamEventBackfill {
    @discardableResult
    static func apply(in modelContext: ModelContext, calendar: Calendar = .current) throws -> Bool {
        let certifications = try modelContext.fetch(FetchDescriptor<Certification>())
        let events = try modelContext.fetch(FetchDescriptor<CalendarEvent>())
        var eventsByID = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
        var nextSortOrderByDay = Dictionary(grouping: events, by: { calendar.startOfDay(for: $0.date) })
            .mapValues { ($0.map(\.sortOrder).max() ?? -1) + 1 }
        var changed = false

        for certification in certifications {
            guard
                CertificationSupport.needsExamEventBackfill(certification, events: Array(eventsByID.values)),
                let targetDate = certification.targetDate
            else { continue }

            let normalizedDate = calendar.startOfDay(for: targetDate)
            let sortOrder = nextSortOrderByDay[normalizedDate] ?? 0
            let event = CalendarEvent(
                title: certification.name,
                date: normalizedDate,
                isAllDay: true,
                sortOrder: sortOrder
            )
            nextSortOrderByDay[normalizedDate] = sortOrder + 1
            modelContext.insert(event)
            certification.automaticExamEventID = event.id
            eventsByID[event.id] = event
            changed = true
        }

        if changed { try modelContext.save() }
        return changed
    }
}

struct CertificationsTrackerView: View {
    @State private var showingNewCertificationEditor = false

    var body: some View {
        DomainTrackerView(
            domain: .certifications,
            leadingContent: AnyView(CertificationsHeaderView {
                // This view owns the add presentation. Keeping the state here
                // prevents the nested List content from attempting a second
                // presentation while its navigation transition is in flight.
                guard !showingNewCertificationEditor else { return }
                showingNewCertificationEditor = true
            })
        )
        .sheet(isPresented: $showingNewCertificationEditor) {
            CertificationEditorView(certification: nil)
        }
    }
}

private struct CertificationsHeaderView: View {
    @Query(sort: \Certification.name) private var certifications: [Certification]
    let addCertification: () -> Void

    var body: some View {
        SwiftUI.Section("Certifications") {
            if certifications.isEmpty {
                Text("Add a certification to plan its milestones and link a routine study task.")
                    .foregroundStyle(TrainingLogTheme.secondaryText)
            } else {
                ForEach(certifications) { certification in
                    NavigationLink { CertificationDetailView(certification: certification) } label: {
                        CertificationRow(certification: certification)
                    }
                }
            }
            Button("Add certification", systemImage: "plus", action: addCertification)
                .foregroundStyle(TrainingLogTheme.primaryText)
        }
    }
}

private struct CertificationRow: View {
    let certification: Certification
    private var orderedMilestones: [CertMilestone] { certification.milestones.sorted { $0.sortOrder < $1.sortOrder } }

    private var doneCount: Int { orderedMilestones.filter(\.isDone).count }

    var body: some View {
        VStack(alignment: .leading, spacing: LWSpace.xs) {
            Text(certification.name)
                .font(LWFont.bodyMedium)
                .foregroundStyle(LWColor.ink)

            HStack(spacing: LWSpace.xs) {
                if let days = CertificationSupport.daysUntil(certification.targetDate) {
                    Text(days >= 0
                        ? "Exam in \(days) day\(days == 1 ? "" : "s")"
                        : "Exam was \(-days) day\(-days == 1 ? "" : "s") ago")
                        .font(LWFont.caption)
                        .monospacedDigit()
                        .foregroundStyle(days >= 0 ? LWColor.inkSecondary : LWColor.danger)
                }

                if CertificationSupport.expiresWithin90Days(certification.expiresOn) {
                    LWChip(
                        text: "Expires \(certification.expiresOn!.formatted(.dateTime.month().day()))",
                        tint: LWColor.warning,
                        fill: LWColor.warning.opacity(0.12)
                    )
                }
            }

            if !orderedMilestones.isEmpty {
                HStack(spacing: LWSpace.xs) {
                    LWProgressBar(
                        progress: Double(doneCount) / Double(orderedMilestones.count),
                        tint: Domain.certifications.tint
                    )
                    Text("\(doneCount)/\(orderedMilestones.count)")
                        .font(LWFont.monoSmall)
                        .monospacedDigit()
                        .foregroundStyle(LWColor.inkSecondary)
                }
            }
        }
        .trainingLogRow()
    }
}

struct CertificationDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.title) private var tasks: [TaskItem]
    @Query(sort: \CompletionRecord.completedAt, order: .reverse) private var records: [CompletionRecord]
    let certification: Certification
    @State private var showingEditor = false
    @State private var milestoneTitle = ""
    @State private var saveError = false

    private var linkedTask: TaskItem? { tasks.first { $0.id == certification.linkedTaskID } }
    private var orderedMilestones: [CertMilestone] { certification.milestones.sorted { $0.sortOrder != $1.sortOrder ? $0.sortOrder < $1.sortOrder : $0.title < $1.title } }

    var body: some View {
        List {
            SwiftUI.Section("Certification") {
                if let days = CertificationSupport.daysUntil(certification.targetDate) {
                    LabeledContent("Exam", value: days >= 0 ? "\(days) days away" : "\(-days) days ago")
                } else { Text("No exam date set").foregroundStyle(TrainingLogTheme.secondaryText) }
                LabeledContent("Status", value: certification.status.capitalized)
                if CertificationSupport.expiresWithin90Days(certification.expiresOn) {
                    Text("Expires \(certification.expiresOn!, format: .dateTime.month().day().year())")
                        .foregroundStyle(LWColor.warning)
                }
            }
            SwiftUI.Section("Milestones") {
                ForEach(orderedMilestones, id: \.persistentModelID) { milestone in
                    Button {
                        toggle(milestone)
                    } label: {
                        HStack(spacing: LWSpace.sm) {
                            LWCheckControl(
                                state: milestone.isDone ? .complete : .pending,
                                size: 22
                            )
                            Text(milestone.title)
                                .font(LWFont.callout)
                                .foregroundStyle(
                                    milestone.isDone ? LWColor.inkSecondary : LWColor.ink
                                )
                            Spacer(minLength: 0)
                        }
                        .trainingLogRow()
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: LWSpace.xs) {
                    TextField("Add milestone", text: $milestoneTitle)
                    Button("Add", action: addMilestone)
                        .font(LWFont.calloutMedium)
                        .foregroundStyle(LWColor.accent)
                        .disabled(milestoneTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            SwiftUI.Section("Routine study") {
                if let linkedTask { Text(linkedTask.title) } else { Text("No linked study task").foregroundStyle(TrainingLogTheme.secondaryText) }
                LabeledContent("Completed (30 days)", value: "\(CertificationSupport.completionCount(taskID: certification.linkedTaskID, records: records))")
            }
            if let notes = certification.notes, !notes.isEmpty { SwiftUI.Section("Notes") { Text(notes) } }
        }
        .trainingLogList()
        .navigationTitle(certification.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEditor = true }
            }
        }
        .sheet(isPresented: $showingEditor) {
            CertificationEditorView(certification: certification)
        }
        .alert("Unable to Save", isPresented: $saveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The milestone change could not be saved. Try again.")
        }
    }

    private func toggle(_ milestone: CertMilestone) {
        let wasDone = milestone.isDone
        let previousCompletion = milestone.completedAt
        milestone.isDone.toggle()
        milestone.completedAt = milestone.isDone ? Date() : nil
        do {
            try modelContext.save()
        } catch {
            milestone.isDone = wasDone
            milestone.completedAt = previousCompletion
            modelContext.rollback()
            saveError = true
        }
    }

    private func addMilestone() {
        let title = milestoneTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let milestone = CertMilestone(
            title: title,
            sortOrder: (orderedMilestones.map(\.sortOrder).max() ?? -1) + 1
        )
        certification.milestones.append(milestone)
        do {
            try modelContext.save()
            milestoneTitle = ""
        } catch {
            certification.milestones.removeAll { $0.persistentModelID == milestone.persistentModelID }
            modelContext.delete(milestone)
            modelContext.rollback()
            saveError = true
        }
    }
}

@MainActor
private struct CertificationEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskItem.title) private var tasks: [TaskItem]
    @Query(sort: \Section.sortOrder) private var sections: [Section]
    @Query(sort: \CalendarEvent.date) private var calendarEvents: [CalendarEvent]
    let certification: Certification?
    @State private var name: String
    @State private var hasTargetDate: Bool
    @State private var targetDate: Date
    @State private var status: String
    @State private var hasExpiry: Bool
    @State private var expiresOn: Date
    @State private var linkedTaskID: UUID?
    @State private var notes: String
    @State private var saveError = false
    @State private var showingStudyTaskEditor = false
    @State private var isConfirmingDeletion = false

    init(certification: Certification?) {
        self.certification = certification
        _name = State(initialValue: certification?.name ?? "")
        _hasTargetDate = State(initialValue: certification?.targetDate != nil)
        _targetDate = State(initialValue: certification?.targetDate ?? Date())
        _status = State(initialValue: certification?.status ?? "planned")
        _hasExpiry = State(initialValue: certification?.expiresOn != nil)
        _expiresOn = State(initialValue: certification?.expiresOn ?? Date())
        _linkedTaskID = State(initialValue: certification?.linkedTaskID)
        _notes = State(initialValue: certification?.notes ?? "")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var eligibleTasks: [TaskItem] {
        CertificationSupport.eligibleRoutineTasks(from: tasks)
    }

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
            Form {
                SwiftUI.Section("Certification") {
                    TextField("Name", text: $name)
                    Picker("Status", selection: $status) {
                        ForEach(["planned", "studying", "scheduled", "passed", "lapsed"], id: \.self) {
                            Text($0.capitalized).tag($0)
                        }
                    }
                }

                SwiftUI.Section("Dates") {
                    Toggle("Exam date", isOn: $hasTargetDate)
                    if hasTargetDate {
                        DatePicker("Target", selection: $targetDate, displayedComponents: .date)
                    }
                    Toggle("Expiration date", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Expires", selection: $expiresOn, displayedComponents: .date)
                    }
                }

                SwiftUI.Section("Routine study") {
                    Picker("Linked task", selection: $linkedTaskID) {
                        Text("None").tag(UUID?.none)
                        ForEach(eligibleTasks) {
                            Text($0.title).tag(Optional($0.id))
                        }
                    }
                    Button("Create study task", systemImage: "plus") {
                        showingStudyTaskEditor = true
                    }
                    .foregroundStyle(LWColor.accent)
                }

                SwiftUI.Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .trainingLogForm()
            .navigationTitle(certification == nil ? "Add Certification" : "Edit Certification")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if certification != nil {
                    Button("Delete certification", role: .destructive) {
                        isConfirmingDeletion = true
                    }
                    .frame(minHeight: LWSpace.minTapTarget)
                }
            }
            .alert("Unable to Save", isPresented: $saveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The certification could not be saved. Try again.")
            }
            .confirmationDialog(
                "Delete this certification?",
                isPresented: $isConfirmingDeletion,
                titleVisibility: .visible
            ) {
                Button("Delete certification", role: .destructive, action: deleteCertification)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Its automatic exam event will also be removed. Routine tasks and their history will remain.")
            }
            .sheet(isPresented: $showingStudyTaskEditor) {
                StudyTaskEditorView(sections: orderedSections) { task in
                    linkedTaskID = task.id
                }
            }
        }
        .trainingLogNavigation()
    }

    private func save() {
        let isNewCertification = certification == nil
        let value = certification ?? Certification(name: trimmedName)
        if isNewCertification {
            modelContext.insert(value)
        }
        value.name = trimmedName
        value.targetDate = hasTargetDate ? Calendar.current.startOfDay(for: targetDate) : nil
        value.status = status
        value.expiresOn = hasExpiry ? expiresOn : nil
        value.linkedTaskID = linkedTaskID

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        value.notes = trimmedNotes.isEmpty ? nil : trimmedNotes

        synchronizeExamEvent(for: value)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = true
        }
    }

    private func synchronizeExamEvent(for certification: Certification) {
        guard let targetDate = certification.targetDate else {
            if let event = CertificationSupport.ownedExamEvent(for: certification, in: calendarEvents) {
                modelContext.delete(event)
            }
            certification.automaticExamEventID = nil
            return
        }

        if let event = CertificationSupport.ownedExamEvent(for: certification, in: calendarEvents) {
            let normalizedDate = Calendar.current.startOfDay(for: targetDate)
            if !Calendar.current.isDate(event.date, inSameDayAs: normalizedDate) {
                event.sortOrder = calendarEvents
                    .filter { $0.id != event.id && Calendar.current.isDate($0.date, inSameDayAs: normalizedDate) }
                    .map(\.sortOrder)
                    .max()
                    .map { $0 + 1 } ?? 0
            }
            event.title = certification.name
            event.date = normalizedDate
            event.startTime = nil
            event.endTime = nil
            event.isAllDay = true
            event.updatedAt = Date()
            return
        }

        let event = CalendarEvent(
            title: certification.name,
            date: targetDate,
            isAllDay: true,
            sortOrder: calendarEvents
                .filter { Calendar.current.isDate($0.date, inSameDayAs: targetDate) }
                .map(\.sortOrder)
                .max()
                .map { $0 + 1 } ?? 0
        )
        modelContext.insert(event)
        certification.automaticExamEventID = event.id
    }

    private func deleteCertification() {
        guard let certification else { return }
        if let event = CertificationSupport.ownedExamEvent(for: certification, in: calendarEvents) {
            modelContext.delete(event)
        }
        modelContext.delete(certification)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = true
        }
    }
}

@MainActor
private struct StudyTaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let sections: [Section]
    let onCreated: (TaskItem) -> Void

    @State private var title = ""
    @State private var selectedSectionID: UUID?
    @State private var saveErrorMessage: String?

    init(sections: [Section], onCreated: @escaping (TaskItem) -> Void) {
        self.sections = sections
        self.onCreated = onCreated
        _selectedSectionID = State(initialValue: sections.first?.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("Study task") {
                    TextField("Task name", text: $title)
                    Picker("Routine section", selection: $selectedSectionID) {
                        ForEach(sections) { section in
                            Text(sectionLabel(for: section)).tag(Optional(section.id))
                        }
                    }
                }
            }
            .trainingLogForm()
            .navigationTitle("Create Study Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: createTask)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedSectionID == nil)
                }
            }
            .alert("Could Not Save Task", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "")
            }
        }
        .trainingLogNavigation()
    }

    private func sectionLabel(for section: Section) -> String {
        guard let weekday = section.daySchedule?.weekdayName else { return section.name }
        return "\(weekday) · \(section.name)"
    }

    private func createTask() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !cleanTitle.isEmpty,
            let sectionID = selectedSectionID,
            let section = sections.first(where: { $0.id == sectionID }),
            let weekday = section.daySchedule?.weekdayName
        else {
            saveErrorMessage = "Choose a routine section before saving this task."
            return
        }

        let sortOrder = (section.tasks
            .filter { !$0.isArchived && !$0.isSubstep && $0.parent == nil && $0.routinePhase == .anytime }
            .map(\.sortOrder)
            .max() ?? -1) + 1
        let task = TaskItem(
            title: cleanTitle,
            routinePhase: .anytime,
            detail: "",
            daysOfWeek: [weekday],
            sortOrder: sortOrder,
            domain: .certifications
        )
        section.tasks.append(task)
        modelContext.insert(task)

        do {
            try modelContext.save()
            WidgetTimeline.reloadRoutine()
            onCreated(task)
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = error.localizedDescription
        }
    }
}
