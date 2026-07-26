import SwiftData
import SwiftUI
import UIKit

enum HomeworkBucket: Int, CaseIterable, Identifiable {
    case overdue, today, tomorrow, thisWeek, later, noDueDate, done

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .overdue: "Overdue"
        case .today: "Today"
        case .tomorrow: "Tomorrow"
        case .thisWeek: "This week"
        case .later: "Later"
        case .noDueDate: "No due date"
        case .done: "Done"
        }
    }
}

enum HomeworkSupport {
    static let noDueDate = Date.distantFuture

    static func dueDate(for day: Date, time: Date, calendar: Calendar = .current) -> Date {
        calendar.date(
            bySettingHour: calendar.component(.hour, from: time),
            minute: calendar.component(.minute, from: time),
            second: 0,
            of: day
        ) ?? day
    }

    static func defaultDueDate(on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: 23, minute: 59, second: 0, of: day) ?? day
    }

    static func bucket(for assignment: Assignment, now: Date, calendar: Calendar = .current) -> HomeworkBucket {
        if assignment.isDone { return .done }
        if assignment.dueDate == noDueDate { return .noDueDate }
        let start = calendar.startOfDay(for: now)
        let dueDay = calendar.startOfDay(for: assignment.dueDate)
        if dueDay < start { return .overdue }
        if calendar.isDate(dueDay, inSameDayAs: start) { return .today }
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: start) else { return .later }
        if calendar.isDate(dueDay, inSameDayAs: tomorrow) { return .tomorrow }
        let weekEnd = calendar.dateInterval(of: .weekOfYear, for: start)?.end ?? tomorrow
        return dueDay < weekEnd ? .thisWeek : .later
    }

    static func ordered(_ assignments: [Assignment]) -> [Assignment] {
        assignments.sorted {
            if $0.dueDate != $1.dueDate { return $0.dueDate < $1.dueDate }
            let leftCourse = $0.course?.sortOrder ?? .max
            let rightCourse = $1.course?.sortOrder ?? .max
            if leftCourse != rightCourse { return leftCourse < rightCourse }
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}

struct HomeworkView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var assignments: [Assignment]
    @Query(sort: \Course.sortOrder) private var courses: [Course]

    @State private var selectedCourseID: UUID?
    @State private var assignmentToEdit: Assignment?
    @State private var showingNewAssignment = false
    @State private var showingCourses = false
    @State private var deletionCandidate: Assignment?
    @State private var saveError: String?
    @State private var doneExpanded = false
    @State private var now = Date()
    @State private var isBulkSelecting = false
    @State private var selectedAssignmentIDs: Set<UUID> = []
    @State private var showingBulkCoursePicker = false

    private let calendar = Calendar.current

    private var visibleAssignments: [Assignment] {
        assignments.filter { assignment in
            selectedCourseID == nil || assignment.course?.id == selectedCourseID
        }
    }

    var body: some View {
        List {
            if !courses.filter({ !$0.isArchived }).isEmpty {
                SwiftUI.Section {
                    courseFilters
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(TrainingLogTheme.background)
                }
            }

            ForEach(HomeworkBucket.allCases) { bucket in
                let items = assignments(in: bucket)
                if bucket == .done {
                    if !items.isEmpty {
                        SwiftUI.Section {
                            if doneExpanded {
                                ForEach(items) { assignmentRow($0) }
                            }
                        } header: {
                            Button { withAnimation { doneExpanded.toggle() } } label: {
                                HStack { Text("Done"); Spacer(); Image(systemName: doneExpanded ? "chevron.up" : "chevron.down") }
                            }
                            .buttonStyle(.plain)
                            .trainingLogSectionLabel()
                        }
                    }
                } else if !items.isEmpty {
                    SwiftUI.Section(bucket.title) {
                        ForEach(items) { assignmentRow($0) }
                    }
                }
            }

            if visibleAssignments.isEmpty {
                Text(selectedCourseID == nil ? "Nothing due. Enjoy it." : "Nothing due for this course.")
                    .foregroundStyle(TrainingLogTheme.secondaryText)
            }
        }
        .trainingLogList()
        .navigationTitle("Homework")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isBulkSelecting {
                    Button("Cancel") { endBulkSelection() }
                } else {
                    Button("Courses") { showingCourses = true }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isBulkSelecting {
                    Menu {
                        Button("Mark Done") { bulkMarkDone() }
                            .disabled(selectedAssignmentIDs.isEmpty)
                        Button("Push Due Date +1 Day") { bulkPostpone() }
                            .disabled(selectedAssignmentIDs.isEmpty)
                        Button("Reassign Course") { showingBulkCoursePicker = true }
                            .disabled(selectedAssignmentIDs.isEmpty)
                    } label: {
                        Label("Bulk actions", systemImage: "ellipsis.circle")
                    }
                } else {
                    HStack {
                        Button { isBulkSelecting = true } label: { Text("Select") }
                        Button { showingNewAssignment = true } label: { Label("Add Assignment", systemImage: "plus") }
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewAssignment) { AssignmentEditorView(assignment: nil, courses: courses) }
        .sheet(item: $assignmentToEdit) { AssignmentEditorView(assignment: $0, courses: courses) }
        .sheet(isPresented: $showingCourses) { CoursesView() }
        .sheet(isPresented: $showingBulkCoursePicker) {
            BulkCoursePicker(courses: courses.filter { !$0.isArchived }) { course in
                bulkReassign(to: course)
            }
        }
        .confirmationDialog("Delete assignment?", isPresented: Binding(get: { deletionCandidate != nil }, set: { if !$0 { deletionCandidate = nil } })) {
            Button("Delete", role: .destructive) { deleteCandidate() }
        } message: { Text("This cannot be undone.") }
        .alert("Unable to Save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(saveError ?? "") }
        .onAppear { now = Date() }
    }

    private var courseFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                courseChip(title: "All", color: nil, isSelected: selectedCourseID == nil) { selectedCourseID = nil }
                ForEach(courses.filter { !$0.isArchived }) { course in
                    courseChip(title: course.name, color: course.color, isSelected: selectedCourseID == course.id) {
                        selectedCourseID = selectedCourseID == course.id ? nil : course.id
                    }
                    .onLongPressGesture { selectedCourseID = course.id }
                }
            }
            .padding(.horizontal, TrainingLogTheme.contentInset)
            .padding(.vertical, 6)
        }
    }

    private func assignments(in bucket: HomeworkBucket) -> [Assignment] {
        let bucketed = visibleAssignments.filter {
            HomeworkSupport.bucket(for: $0, now: now, calendar: calendar) == bucket
        }
        let ordered = HomeworkSupport.ordered(bucketed)
        guard bucket == .done else { return ordered }
        let cutoff = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        return ordered.filter { ($0.completedAt ?? .distantPast) >= cutoff }
    }

    private func courseChip(title: String, color: Color?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let color { Circle().fill(color).frame(width: 7, height: 7) }
                Text(title).lineLimit(1)
            }
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? TrainingLogTheme.primaryText : TrainingLogTheme.secondaryText)
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(isSelected ? TrainingLogTheme.primaryText : .clear).frame(height: 2) }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func assignmentRow(_ assignment: Assignment) -> some View {
        HStack(spacing: 10) {
            if isBulkSelecting {
                Image(systemName: selectedAssignmentIDs.contains(assignment.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedAssignmentIDs.contains(assignment.id) ? TrainingLogTheme.completionAccent : TrainingLogTheme.secondaryText)
            }
            Rectangle().fill(assignment.course?.color ?? TrainingLogTheme.secondaryText).frame(width: 3)
            VStack(alignment: .leading, spacing: 3) {
                Text(assignment.title).strikethrough(assignment.isDone, color: TrainingLogTheme.secondaryText)
                HStack(spacing: 4) {
                    if let course = assignment.course { Text(course.name) }
                    if assignment.dueDate != HomeworkSupport.noDueDate {
                        Text("·")
                        Text(assignment.dueDate, format: .dateTime.hour().minute())
                            .monospacedDigit()
                            .foregroundStyle(assignment.usesDefaultTime ? TrainingLogTheme.secondaryText : TrainingLogTheme.primaryText)
                    }
                }
                .font(.caption)
                .foregroundStyle(TrainingLogTheme.secondaryText)
            }
            Spacer(minLength: 8)
            Button {
                if isBulkSelecting { toggleSelection(assignment) } else { toggleDone(assignment) }
            } label: {
                Image(systemName: assignment.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(assignment.isDone ? TrainingLogTheme.completionAccent : TrainingLogTheme.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(assignment.isDone ? "Mark \(assignment.title) incomplete" : "Mark \(assignment.title) complete")
        }
        .trainingLogRow()
        .contentShape(Rectangle())
        .onTapGesture {
            if isBulkSelecting { toggleSelection(assignment) } else { assignmentToEdit = assignment }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { postpone(assignment) } label: { Label("Tomorrow", systemImage: "arrow.right") }.tint(TrainingLogTheme.secondaryText)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { deletionCandidate = assignment } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func toggleDone(_ assignment: Assignment) {
        withAnimation {
            assignment.isDone.toggle()
            assignment.completedAt = assignment.isDone ? Date() : nil
            assignment.updatedAt = Date()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        save()
    }

    private func postpone(_ assignment: Assignment) {
        guard assignment.dueDate != HomeworkSupport.noDueDate else { return }
        assignment.dueDate = calendar.date(byAdding: .day, value: 1, to: assignment.dueDate) ?? assignment.dueDate
        assignment.updatedAt = Date()
        save()
    }

    private func toggleSelection(_ assignment: Assignment) {
        if selectedAssignmentIDs.contains(assignment.id) {
            selectedAssignmentIDs.remove(assignment.id)
        } else {
            selectedAssignmentIDs.insert(assignment.id)
        }
    }

    private var selectedAssignments: [Assignment] {
        assignments.filter { selectedAssignmentIDs.contains($0.id) }
    }

    private func bulkMarkDone() {
        for assignment in selectedAssignments where !assignment.isDone {
            assignment.isDone = true
            assignment.completedAt = Date()
            assignment.updatedAt = Date()
        }
        save()
        endBulkSelection()
    }

    private func bulkPostpone() {
        for assignment in selectedAssignments where assignment.dueDate != HomeworkSupport.noDueDate {
            assignment.dueDate = calendar.date(byAdding: .day, value: 1, to: assignment.dueDate) ?? assignment.dueDate
            assignment.updatedAt = Date()
        }
        save()
        endBulkSelection()
    }

    private func bulkReassign(to course: Course?) {
        for assignment in selectedAssignments {
            assignment.course = course
            assignment.updatedAt = Date()
        }
        save()
        showingBulkCoursePicker = false
        endBulkSelection()
    }

    private func endBulkSelection() {
        isBulkSelecting = false
        selectedAssignmentIDs.removeAll()
    }

    private func deleteCandidate() {
        if let deletionCandidate { modelContext.delete(deletionCandidate); save() }
        deletionCandidate = nil
    }

    private func save() {
        do { try modelContext.save(); WidgetTimeline.reloadAll() } catch { modelContext.rollback(); saveError = error.localizedDescription }
    }
}

private struct BulkCoursePicker: View {
    let courses: [Course]
    let onSelected: (Course?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button("No course") {
                    onSelected(nil)
                    dismiss()
                }
                ForEach(courses) { course in
                    Button {
                        onSelected(course)
                        dismiss()
                    } label: {
                        HStack {
                            Circle().fill(course.color).frame(width: 8, height: 8)
                            Text(course.name)
                        }
                    }
                }
            }
            .trainingLogList()
            .navigationTitle("Reassign Course")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } } }
        }
    }
}

@MainActor
private struct AssignmentEditorView: View {
    let assignment: Assignment?
    let courses: [Course]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title: String
    @State private var courseID: UUID?
    @State private var hasDueDate: Bool
    @State private var dueDay: Date
    @State private var dueTime: Date
    @State private var usesDefaultTime: Bool
    @State private var notes: String
    @State private var detailsOpen: Bool
    @State private var error: String?

    init(assignment: Assignment?, courses: [Course]) {
        self.assignment = assignment; self.courses = courses
        let date = assignment?.dueDate ?? HomeworkSupport.defaultDueDate(on: Date())
        _title = State(initialValue: assignment?.title ?? "")
        _courseID = State(initialValue: assignment?.course?.id)
        _hasDueDate = State(initialValue: assignment?.dueDate != HomeworkSupport.noDueDate)
        _dueDay = State(initialValue: date)
        _dueTime = State(initialValue: date)
        _usesDefaultTime = State(initialValue: assignment?.usesDefaultTime ?? true)
        _notes = State(initialValue: assignment?.notes ?? "")
        _detailsOpen = State(initialValue: assignment != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("Assignment") {
                    TextField("Assignment name", text: $title)
                    Picker("Course", selection: $courseID) {
                        Text("No course").tag(UUID?.none)
                        ForEach(courses.filter { !$0.isArchived || $0.id == assignment?.course?.id }) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Toggle("Due date", isOn: $hasDueDate)
                    if hasDueDate { DatePicker("Due date", selection: $dueDay, displayedComponents: .date) }
                }
                SwiftUI.Section {
                    DisclosureGroup("Details", isExpanded: $detailsOpen) {
                        if hasDueDate {
                            Toggle("Use 11:59 PM", isOn: $usesDefaultTime)
                            if !usesDefaultTime { DatePicker("Due time", selection: $dueTime, displayedComponents: .hourAndMinute) }
                        }
                        TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...5)
                    }
                }
            }
            .trainingLogForm()
            .navigationTitle(assignment == nil ? "Add Assignment" : "Edit Assignment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .alert("Check Assignment", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK", role: .cancel) {} } message: { Text(error ?? "") }
        }.trainingLogNavigation()
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { error = "Enter an assignment name."; return }
        let course = courses.first { $0.id == courseID }
        let finalDate = hasDueDate ? (usesDefaultTime ? HomeworkSupport.defaultDueDate(on: dueDay) : HomeworkSupport.dueDate(for: dueDay, time: dueTime)) : HomeworkSupport.noDueDate
        let item = assignment ?? Assignment(title: cleanTitle, dueDate: finalDate, sortOrder: (courses.flatMap(\.assignments).map(\.sortOrder).max() ?? -1) + 1)
        item.title = cleanTitle; item.course = course; item.dueDate = finalDate; item.usesDefaultTime = usesDefaultTime; item.notes = notes.isEmpty ? nil : notes; item.updatedAt = Date()
        if assignment == nil { modelContext.insert(item) }
        do { try modelContext.save(); WidgetTimeline.reloadAll(); dismiss() } catch let saveFailure { error = saveFailure.localizedDescription }
    }
}

@MainActor
private struct CoursesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Course.sortOrder) private var courses: [Course]
    @State private var editorCourse: Course?
    @State private var showingNew = false
    @State private var showingArchived = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(courses.filter { $0.isArchived == showingArchived }) { course in
                    HStack { Circle().fill(course.color).frame(width: 10, height: 10); Text(course.name); Spacer(); Text(course.term).foregroundStyle(TrainingLogTheme.secondaryText) }
                        .contentShape(Rectangle()).onTapGesture { editorCourse = course }
                        .swipeActions {
                            Button(showingArchived ? "Restore" : "Archive") {
                                course.isArchived.toggle()
                                save()
                            }
                            .tint(TrainingLogTheme.secondaryText)
                        }
                }
                .onMove(perform: move)
            }
            .trainingLogList().navigationTitle("Courses")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(showingArchived ? "Active" : "Archived") { showingArchived.toggle() } }
                ToolbarItem(placement: .topBarTrailing) { Button { showingNew = true } label: { Label("Add Course", systemImage: "plus") } }
            }
            .sheet(isPresented: $showingNew) { CourseEditorView(course: nil) }
            .sheet(item: $editorCourse) { CourseEditorView(course: $0) }
        }.trainingLogNavigation()
    }
    private func move(from: IndexSet, to: Int) { var items = courses.filter { $0.isArchived == showingArchived }; items.move(fromOffsets: from, toOffset: to); for (index, item) in items.enumerated() { item.sortOrder = index }; save() }
    private func save() {
        do {
            try modelContext.save()
            WidgetTimeline.reloadAll()
        } catch {
            modelContext.rollback()
        }
    }
}

@MainActor
private struct CourseEditorView: View {
    let course: Course?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Course.sortOrder) private var courses: [Course]
    @State private var name: String
    @State private var term: String
    @State private var colorHex: String
    @State private var error: String?
    private let palette = ["#D9A441", "#4FB3C4", "#8E7BD1", "#D9705C", "#6E8BA8", "#C46A8E", "#B8A184", "#7F8A93"]
    init(course: Course?) { self.course = course; _name = State(initialValue: course?.name ?? ""); _term = State(initialValue: course?.term ?? ""); _colorHex = State(initialValue: course?.colorHex ?? "#D9A441") }
    var body: some View { NavigationStack { Form { SwiftUI.Section("Course") { TextField("Course name", text: $name); TextField("Term", text: $term); Picker("Color", selection: $colorHex) { ForEach(palette, id: \.self) { hex in HStack { Circle().fill(Color(hex: hex)).frame(width: 12, height: 12); Text(hex) }.tag(hex) } } } }.trainingLogForm().navigationTitle(course == nil ? "Add Course" : "Edit Course").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } } }.alert("Check Course", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK", role: .cancel) {} } message: { Text(error ?? "") } }.trainingLogNavigation() }
    private func save() { let clean = name.trimmingCharacters(in: .whitespacesAndNewlines); guard !clean.isEmpty else { error = "Enter a course name."; return }; let item = course ?? Course(name: clean, colorHex: colorHex, term: term, sortOrder: (courses.map(\.sortOrder).max() ?? -1) + 1); item.name = clean; item.term = term; item.colorHex = colorHex; if course == nil { modelContext.insert(item) }; do { try modelContext.save(); WidgetTimeline.reloadAll(); dismiss() } catch let saveFailure { error = saveFailure.localizedDescription } }
}

private extension Course { var color: Color { Color(hex: colorHex) } }
private extension Color { init(hex: String) { let value = UInt64(hex.dropFirst(), radix: 16) ?? 0; self.init(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255) } }
