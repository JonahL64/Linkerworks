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
}

struct CertificationsTrackerView: View {
    var body: some View {
        DomainTrackerView(domain: .certifications, leadingContent: AnyView(CertificationsHeaderView()))
    }
}

private struct CertificationsHeaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Certification.name) private var certifications: [Certification]
    @State private var showingEditor = false

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
            Button("Add certification", systemImage: "plus") { showingEditor = true }
                .foregroundStyle(TrainingLogTheme.primaryText)
        }
        .sheet(isPresented: $showingEditor) {
            CertificationEditorView(certification: nil) { certification in
                modelContext.insert(certification)
                do { try modelContext.save(); return true } catch { modelContext.rollback(); return false }
            }
        }
    }
}

private struct CertificationRow: View {
    let certification: Certification
    private var orderedMilestones: [CertMilestone] { certification.milestones.sorted { $0.sortOrder < $1.sortOrder } }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(certification.name)
            if let days = CertificationSupport.daysUntil(certification.targetDate) {
                Text(days >= 0 ? "Exam in \(days) day\(days == 1 ? "" : "s")" : "Exam was \(-days) day\(-days == 1 ? "" : "s") ago")
                    .font(.caption).monospacedDigit().foregroundStyle(TrainingLogTheme.secondaryText)
            }
            Text("\(orderedMilestones.filter(\.isDone).count) of \(orderedMilestones.count) milestones")
                .font(.caption).foregroundStyle(TrainingLogTheme.secondaryText)
            if CertificationSupport.expiresWithin90Days(certification.expiresOn) {
                Text("Expires \(certification.expiresOn!, format: .dateTime.month().day().year())")
                    .font(.caption.weight(.semibold)).foregroundStyle(.orange)
            }
        }
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
                        .foregroundStyle(.orange)
                }
            }
            SwiftUI.Section("Milestones") {
                ForEach(orderedMilestones, id: \.persistentModelID) { milestone in
                    Button { toggle(milestone) } label: {
                        Label(milestone.title, systemImage: milestone.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(milestone.isDone ? TrainingLogTheme.completionAccent : TrainingLogTheme.primaryText)
                    }.buttonStyle(.plain)
                }
                HStack { TextField("Add milestone", text: $milestoneTitle); Button("Add", action: addMilestone).disabled(milestoneTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
            SwiftUI.Section("Routine study") {
                if let linkedTask { Text(linkedTask.title) } else { Text("No linked study task").foregroundStyle(TrainingLogTheme.secondaryText) }
                LabeledContent("Completed (30 days)", value: "\(CertificationSupport.completionCount(taskID: certification.linkedTaskID, records: records))")
            }
            if let notes = certification.notes, !notes.isEmpty { SwiftUI.Section("Notes") { Text(notes) } }
        }
        .trainingLogList().navigationTitle(certification.name)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { showingEditor = true } } }
        .sheet(isPresented: $showingEditor) { CertificationEditorView(certification: certification) { _ in do { try modelContext.save(); return true } catch { modelContext.rollback(); return false } } }
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

private struct CertificationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskItem.title) private var tasks: [TaskItem]
    let certification: Certification?
    let onSaved: (Certification) -> Bool
    @State private var name: String
    @State private var hasTargetDate: Bool
    @State private var targetDate: Date
    @State private var status: String
    @State private var hasExpiry: Bool
    @State private var expiresOn: Date
    @State private var linkedTaskID: UUID?
    @State private var notes: String
    @State private var saveError = false

    init(certification: Certification?, onSaved: @escaping (Certification) -> Bool) {
        self.certification = certification; self.onSaved = onSaved
        _name = State(initialValue: certification?.name ?? "")
        _hasTargetDate = State(initialValue: certification?.targetDate != nil); _targetDate = State(initialValue: certification?.targetDate ?? Date())
        _status = State(initialValue: certification?.status ?? "planned")
        _hasExpiry = State(initialValue: certification?.expiresOn != nil); _expiresOn = State(initialValue: certification?.expiresOn ?? Date())
        _linkedTaskID = State(initialValue: certification?.linkedTaskID); _notes = State(initialValue: certification?.notes ?? "")
    }
    var body: some View {
        NavigationStack { Form {
            SwiftUI.Section("Certification") { TextField("Name", text: $name); Picker("Status", selection: $status) { ForEach(["planned", "studying", "scheduled", "passed", "lapsed"], id: \.self) { Text($0.capitalized).tag($0) } } }
            SwiftUI.Section("Dates") { Toggle("Exam date", isOn: $hasTargetDate); if hasTargetDate { DatePicker("Target", selection: $targetDate, displayedComponents: .date) }; Toggle("Expiration date", isOn: $hasExpiry); if hasExpiry { DatePicker("Expires", selection: $expiresOn, displayedComponents: .date) } }
            SwiftUI.Section("Routine study") { Picker("Linked task", selection: $linkedTaskID) { Text("None").tag(UUID?.none); ForEach(tasks.filter { $0.domain == .certifications && !$0.isArchived && !$0.isSubstep }) { Text($0.title).tag(Optional($0.id)) } } }
            SwiftUI.Section("Notes") { TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...6) }
        }.trainingLogForm().navigationTitle(certification == nil ? "Add Certification" : "Edit Certification").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }.alert("Unable to Save", isPresented: $saveError) { Button("OK", role: .cancel) {} } message: { Text("The certification could not be saved. Try again.") } }.trainingLogNavigation()
    }
    private func save() { let value = certification ?? Certification(name: name.trimmingCharacters(in: .whitespacesAndNewlines)); value.name = name.trimmingCharacters(in: .whitespacesAndNewlines); value.targetDate = hasTargetDate ? targetDate : nil; value.status = status; value.expiresOn = hasExpiry ? expiresOn : nil; value.linkedTaskID = linkedTaskID; value.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines); if onSaved(value) { dismiss() } else { saveError = true } }
}
