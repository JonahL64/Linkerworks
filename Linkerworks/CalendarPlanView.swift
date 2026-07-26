import SwiftData
import SwiftUI

struct CalendarPlanView: View {
    @Binding var showingManageRoutine: Bool

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CalendarEvent.date) private var events: [CalendarEvent]
    @Query private var assignments: [Assignment]
    @Query(sort: \Certification.name) private var certifications: [Certification]
    @AppStorage("homeworkIntegrationEnabled") private var homeworkIntegrationEnabled = true

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var displayedMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var isPresentingEditor = false
    @State private var eventToEdit: CalendarEvent?
    @State private var saveErrorMessage: String?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let firstIndex = max(calendar.firstWeekday - 1, 0)
        guard symbols.indices.contains(firstIndex) else { return symbols }
        return Array(symbols[firstIndex...]) + Array(symbols[..<firstIndex])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    monthView
                    agenda(for: selectedDate, showDateHeader: true)

                    Button {
                        showingManageRoutine = true
                    } label: {
                        Label("Manage routine", systemImage: "slider.horizontal.3")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(TrainingLogTheme.secondaryText)
                }
                .padding()
            }
            .background(TrainingLogTheme.background)
            .navigationTitle("Plan")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack {
                        Button("Today") { selectToday() }
                        if homeworkIntegrationEnabled {
                            NavigationLink("Homework") { HomeworkView() }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        eventToEdit = nil
                        isPresentingEditor = true
                    } label: {
                        Label("Add Event", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingManageRoutine) {
                ManageView()
            }
            .sheet(isPresented: $isPresentingEditor, onDismiss: { eventToEdit = nil }) {
                CalendarEventEditorView(
                    event: eventToEdit,
                    selectedDate: selectedDate,
                    onSaved: saveEvent,
                    onDeleted: deleteEvent
                )
            }
            .alert("Unable to Save", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "")
            }
            .trainingLogNavigation()
        }
    }

    private var monthView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Previous month")

                Spacer()

                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(.title.weight(.semibold))

                Spacer()

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("Next month")
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TrainingLogTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(monthDates.enumerated()), id: \.offset) { _, date in
                    if let date {
                        Button {
                            select(date)
                        } label: {
                            CalendarDayCell(
                                date: date,
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                isToday: calendar.isDateInToday(date),
                                hasEvents: !events(on: date).isEmpty,
                                hasAssignments: homeworkIntegrationEnabled && !assignments(on: date).isEmpty,
                                hasCertificationExam: !certifications(on: date).isEmpty
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func agenda(for date: Date, showDateHeader: Bool) -> some View {
        let dailyEvents = events(on: date)
        let dailyAssignments = homeworkIntegrationEnabled ? assignments(on: date) : []

        VStack(alignment: .leading, spacing: 8) {
            if showDateHeader {
                HStack {
                    Text(date, format: .dateTime.weekday(.wide).month().day())
                        .font(.headline)
                    Spacer()
                }
            }

            if dailyEvents.isEmpty && dailyAssignments.isEmpty {
                Text("Nothing planned or due. Enjoy the space.")
                    .font(.subheadline)
                    .foregroundStyle(TrainingLogTheme.secondaryText)
                    .padding(.vertical, 6)
            } else {
                ForEach(dailyEvents) { event in
                    Button {
                        eventToEdit = event
                        isPresentingEditor = true
                    } label: {
                        CalendarEventRow(event: event)
                    }
                    .buttonStyle(.plain)
                }
                ForEach(dailyAssignments) { assignment in
                    CalendarAssignmentRow(assignment: assignment)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var monthDates: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: displayedMonth)
        let leadingCount = (firstWeekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leadingCount) + range.compactMap { day in
            calendar.date(bySetting: .day, value: day, of: displayedMonth)
        }
    }

    private func events(on date: Date) -> [CalendarEvent] {
        events
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay {
                    return lhs.isAllDay
                }

                let lhsTime = lhs.startTime ?? .distantPast
                let rhsTime = rhs.startTime ?? .distantPast
                if lhsTime != rhsTime {
                    return lhsTime < rhsTime
                }
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    private func assignments(on date: Date) -> [Assignment] {
        HomeworkSupport.ordered(
            assignments.filter {
                !$0.isDone
                    && $0.dueDate != HomeworkSupport.noDueDate
                    && calendar.isDate($0.dueDate, inSameDayAs: date)
            }
        )
    }

    private func certifications(on date: Date) -> [Certification] {
        certifications.filter { certification in
            guard let targetDate = certification.targetDate else { return false }
            return calendar.isDate(targetDate, inSameDayAs: date)
        }
    }

    private func select(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
        displayedMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
    }

    private func selectToday() {
        select(Date())
    }

    private func moveMonth(by offset: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: newMonth) else { return }
        let selectedDay = min(calendar.component(.day, from: selectedDate), dayRange.count)
        displayedMonth = newMonth
        selectedDate = calendar.date(bySetting: .day, value: selectedDay, of: newMonth) ?? newMonth
    }

    private func saveEvent(_ event: CalendarEvent?, _ draft: CalendarEventDraft) -> Bool {
        let normalizedDate = calendar.startOfDay(for: draft.date)
        let startTime = draft.isAllDay ? nil : time(draft.startTime, on: normalizedDate)
        let endTime = draft.isAllDay
            ? nil
            : draft.endTime.map { time($0, on: normalizedDate) }

        if let event {
            event.title = draft.title
            event.date = normalizedDate
            event.startTime = startTime
            event.endTime = endTime
            event.isAllDay = draft.isAllDay
            event.notes = draft.notes
            event.updatedAt = Date()
        } else {
            let sortOrder = events(on: normalizedDate).map(\.sortOrder).max().map { $0 + 1 } ?? 0
            modelContext.insert(CalendarEvent(
                title: draft.title,
                date: normalizedDate,
                startTime: startTime,
                endTime: endTime,
                isAllDay: draft.isAllDay,
                notes: draft.notes,
                sortOrder: sortOrder
            ))
        }

        guard saveContext() else { return false }
        select(normalizedDate)
        return true
    }

    private func deleteEvent(_ event: CalendarEvent) -> Bool {
        modelContext.delete(event)
        return saveContext()
    }

    private func saveContext() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            saveErrorMessage = error.localizedDescription
            return false
        }
    }

    private func time(_ time: Date, on date: Date) -> Date {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: 0,
            of: date
        ) ?? date
    }
}

private struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool
    let hasAssignments: Bool
    let hasCertificationExam: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text(date, format: .dateTime.day())
                .font(.body.weight(isSelected ? .semibold : .regular))
            HStack(spacing: 3) {
                Circle()
                    .fill(hasEvents ? TrainingLogTheme.primaryText : .clear)
                    .frame(width: 4, height: 4)
                RoundedRectangle(cornerRadius: 1)
                    .fill(hasAssignments ? TrainingLogTheme.completionAccent : .clear)
                    .frame(width: 7, height: 3)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(hasCertificationExam ? .orange : .clear)
            }
        }
        .foregroundStyle(isSelected ? TrainingLogTheme.background : TrainingLogTheme.primaryText)
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 6)
                    .fill(TrainingLogTheme.primaryText)
            }
        }
        .overlay {
            if isToday && !isSelected {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(TrainingLogTheme.secondaryText, lineWidth: 1)
            }
        }
        .accessibilityLabel(date.formatted(date: .long, time: .omitted))
        .accessibilityValue(hasEvents || hasAssignments || hasCertificationExam ? "\(hasEvents ? "Has events" : "")\(hasEvents && (hasAssignments || hasCertificationExam) ? ", " : "")\(hasAssignments ? "Has assignments due" : "")\(hasAssignments && hasCertificationExam ? ", " : "")\(hasCertificationExam ? "Certification exam" : "")" : "Nothing scheduled")
    }
}

private struct CalendarEventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(timeLabel)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(TrainingLogTheme.secondaryText)
                .frame(width: 76, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                if !event.notes.isEmpty {
                    Text(event.notes)
                        .font(.caption)
                        .foregroundStyle(TrainingLogTheme.secondaryText)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(TrainingLogTheme.divider)
                .frame(height: 1)
        }
    }

    private var timeLabel: String {
        guard !event.isAllDay, let startTime = event.startTime else { return "All day" }
        let start = startTime.formatted(date: .omitted, time: .shortened)
        guard let endTime = event.endTime else { return start }
        return "\(start)–\(endTime.formatted(date: .omitted, time: .shortened))"
    }
}

private struct CalendarAssignmentRow: View {
    let assignment: Assignment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("Due")
                .font(.caption.weight(.semibold))
                .foregroundStyle(TrainingLogTheme.completionAccent)
                .frame(width: 76, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.title)
                HStack(spacing: 4) {
                    if let course = assignment.course { Text(course.name) }
                    Text(assignment.dueDate, format: .dateTime.hour().minute())
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(TrainingLogTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(TrainingLogTheme.divider).frame(height: 1) }
        .accessibilityLabel("Assignment due: \(assignment.title)")
    }
}

private struct CalendarEventDraft {
    var title: String
    var date: Date
    var isAllDay: Bool
    var startTime: Date
    var endTime: Date?
    var notes: String
}

@MainActor
private struct CalendarEventEditorView: View {
    let event: CalendarEvent?
    let selectedDate: Date
    let onSaved: (CalendarEvent?, CalendarEventDraft) -> Bool
    let onDeleted: (CalendarEvent) -> Bool

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var date: Date
    @State private var isAllDay: Bool
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var hasEndTime: Bool
    @State private var notes: String
    @State private var validationMessage: String?
    @State private var isConfirmingDeletion = false

    init(
        event: CalendarEvent?,
        selectedDate: Date,
        onSaved: @escaping (CalendarEvent?, CalendarEventDraft) -> Bool,
        onDeleted: @escaping (CalendarEvent) -> Bool
    ) {
        let calendar = Calendar.current
        let defaultStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        let defaultEnd = calendar.date(byAdding: .hour, value: 1, to: defaultStart) ?? defaultStart

        self.event = event
        self.selectedDate = selectedDate
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        _title = State(initialValue: event?.title ?? "")
        _date = State(initialValue: event?.date ?? selectedDate)
        _isAllDay = State(initialValue: event?.isAllDay ?? true)
        _startTime = State(initialValue: event?.startTime ?? defaultStart)
        _endTime = State(initialValue: event?.endTime ?? defaultEnd)
        _hasEndTime = State(initialValue: event?.endTime != nil || event == nil)
        _notes = State(initialValue: event?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("Event") {
                    TextField("Title", text: $title)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                SwiftUI.Section {
                    DisclosureGroup("Time & notes") {
                        Picker("Time", selection: $isAllDay) {
                            Text("All day").tag(true)
                            Text("Timed").tag(false)
                        }

                        if !isAllDay {
                        DatePicker("Starts", selection: $startTime, displayedComponents: .hourAndMinute)
                        Toggle("End time", isOn: $hasEndTime)
                        if hasEndTime {
                            DatePicker("Ends", selection: $endTime, displayedComponents: .hourAndMinute)
                        }
                        }

                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }

                if event != nil {
                    SwiftUI.Section {
                        Button("Delete Event", role: .destructive) {
                            isConfirmingDeletion = true
                        }
                    }
                }
            }
            .trainingLogForm()
            .navigationTitle(event == nil ? "Add Event" : "Edit Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .alert("Check Event", isPresented: Binding(
                get: { validationMessage != nil },
                set: { if !$0 { validationMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage ?? "")
            }
            .confirmationDialog(
                "Delete this event?",
                isPresented: $isConfirmingDeletion,
                titleVisibility: .visible
            ) {
                Button("Delete Event", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
        .trainingLogNavigation()
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            validationMessage = "Enter an event title."
            return
        }
        guard isAllDay || !hasEndTime || endTime >= startTime else {
            validationMessage = "The end time must be the same as or later than the start time."
            return
        }

        let didSave = onSaved(event, CalendarEventDraft(
            title: trimmedTitle,
            date: date,
            isAllDay: isAllDay,
            startTime: startTime,
            endTime: hasEndTime ? endTime : nil,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        if didSave {
            dismiss()
        } else {
            validationMessage = "The event could not be saved. Try again."
        }
    }

    private func delete() {
        guard let event else { return }
        if onDeleted(event) {
            dismiss()
        } else {
            validationMessage = "The event could not be deleted. Try again."
        }
    }
}
