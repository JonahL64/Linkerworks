import SwiftData
import SwiftUI

@MainActor
struct CalendarPlanProjection {
    let eventsByDayKey: [String: [CalendarEvent]]
    let assignmentsByDayKey: [String: [Assignment]]
    let todosByDayKey: [String: [DailyTodo]]

    init(
        events: [CalendarEvent],
        assignments: [Assignment],
        todos: [DailyTodo],
        calendar: Calendar = .current
    ) {
        eventsByDayKey = Dictionary(
            grouping: events,
            by: { DaySnapshotService.dayKey(for: $0.date, calendar: calendar) }
        ).mapValues(Self.orderedEvents)
        assignmentsByDayKey = Dictionary(
            grouping: assignments.filter {
                !$0.isDone && $0.dueDate != HomeworkSupport.noDueDate
            },
            by: { DaySnapshotService.dayKey(for: $0.dueDate, calendar: calendar) }
        ).mapValues(HomeworkSupport.ordered)
        todosByDayKey = Dictionary(grouping: todos, by: \.scheduledDayKey)
            .mapValues(DailyTodoSupport.ordered)
    }

    static func orderedEvents(_ events: [CalendarEvent]) -> [CalendarEvent] {
        events.sorted { lhs, rhs in
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
}

private struct CalendarPlanRevision: Hashable {
    private struct EventValue: Hashable {
        let id: UUID
        let date: Date
        let startTime: Date?
        let isAllDay: Bool
        let sortOrder: Int
        let createdAt: Date
        let updatedAt: Date
    }

    private struct AssignmentValue: Hashable {
        let id: UUID
        let dueDate: Date
        let isDone: Bool
        let sortOrder: Int
        let courseSortOrder: Int?
        let createdAt: Date
        let updatedAt: Date
    }

    private struct TodoValue: Hashable {
        let id: UUID
        let scheduledDayKey: String
        let sortOrder: Int
        let createdAt: Date
        let updatedAt: Date
    }

    private let events: [EventValue]
    private let assignments: [AssignmentValue]
    private let todos: [TodoValue]

    init(
        events: [CalendarEvent],
        assignments: [Assignment],
        todos: [DailyTodo],
        includesAssignments: Bool
    ) {
        self.events = events.map {
            EventValue(
                id: $0.id,
                date: $0.date,
                startTime: $0.startTime,
                isAllDay: $0.isAllDay,
                sortOrder: $0.sortOrder,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
            )
        }
        self.assignments = includesAssignments ? assignments.map {
            AssignmentValue(
                id: $0.id,
                dueDate: $0.dueDate,
                isDone: $0.isDone,
                sortOrder: $0.sortOrder,
                courseSortOrder: $0.course?.sortOrder,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
            )
        } : []
        self.todos = todos.map {
            TodoValue(
                id: $0.id,
                scheduledDayKey: $0.scheduledDayKey,
                sortOrder: $0.sortOrder,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
            )
        }
    }
}

@MainActor
private struct CalendarPlanProjectionCache {
    let revision: CalendarPlanRevision
    let projection: CalendarPlanProjection
}

struct CalendarPlanView: View {
    @Binding var showingManageRoutine: Bool

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CalendarEvent.date) private var events: [CalendarEvent]
    @Query private var assignments: [Assignment]
    @Query private var dailyTodos: [DailyTodo]
    @Query private var certifications: [Certification]
    @AppStorage("homeworkIntegrationEnabled") private var homeworkIntegrationEnabled = true

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var displayedMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var isPresentingEditor = false
    @State private var eventToEdit: CalendarEvent?
    @State private var saveErrorMessage: String?
    @State private var projectionCache: CalendarPlanProjectionCache?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let firstIndex = max(calendar.firstWeekday - 1, 0)
        guard symbols.indices.contains(firstIndex) else { return symbols }
        return Array(symbols[firstIndex...]) + Array(symbols[..<firstIndex])
    }

    private var ownedExamEventIDs: Set<UUID> {
        Set(certifications.compactMap(\.automaticExamEventID))
    }

    var body: some View {
        let revision = CalendarPlanRevision(
            events: events,
            assignments: assignments,
            todos: dailyTodos,
            includesAssignments: homeworkIntegrationEnabled
        )
        let projection = projectionCache?.revision == revision
            ? projectionCache!.projection
            : makeProjection()

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LWSpace.xl) {
                    monthView(projection: projection)
                    agenda(for: selectedDate, showDateHeader: true, projection: projection)

                    Button {
                        showingManageRoutine = true
                    } label: {
                        Label("Manage routine", systemImage: "slider.horizontal.3")
                            .font(LWFont.calloutMedium)
                            .foregroundStyle(LWColor.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, LWSpace.sm)
                            .background(
                                LWColor.accentMuted,
                                in: RoundedRectangle(cornerRadius: LWRadius.md)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, LWSpace.screenInset)
                .padding(.top, LWSpace.xs)
                .padding(.bottom, LWSpace.xxl)
            }
            .background(LWColor.surface)
            .navigationTitle("Plan")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack {
                        Button("Today") { selectToday() }
                        NavigationLink("To-dos") { DailyTodosView(selectedDate: selectedDate) }
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
            .task(id: revision) {
                guard projectionCache?.revision != revision else { return }
                projectionCache = CalendarPlanProjectionCache(
                    revision: revision,
                    projection: makeProjection()
                )
            }
            .trainingLogNavigation()
        }
    }

    private func makeProjection() -> CalendarPlanProjection {
        CalendarPlanProjection(
            events: events,
            assignments: homeworkIntegrationEnabled ? assignments : [],
            todos: dailyTodos,
            calendar: calendar
        )
    }

    private func monthView(projection: CalendarPlanProjection) -> some View {
        VStack(alignment: .leading, spacing: LWSpace.sm) {
            HStack {
                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(LWFont.title)
                    .foregroundStyle(LWColor.ink)

                Spacer()

                HStack(spacing: LWSpace.xs) {
                    Button {
                        moveMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .background(LWColor.surfaceSunken, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Previous month")

                    Button {
                        moveMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .background(LWColor.surfaceSunken, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Next month")
                }
                .foregroundStyle(LWColor.ink)
            }

            LazyVGrid(columns: columns, spacing: LWSpace.xxs) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(LWColor.inkTertiary)
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
                                hasEvents: !events(on: date, projection: projection).isEmpty,
                                hasAssignments: homeworkIntegrationEnabled && !assignments(on: date, projection: projection).isEmpty,
                                hasTodos: !todos(on: date, projection: projection).isEmpty
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
    private func agenda(
        for date: Date,
        showDateHeader: Bool,
        projection: CalendarPlanProjection
    ) -> some View {
        let dailyEvents = events(on: date, projection: projection)
        let dailyAssignments = homeworkIntegrationEnabled
            ? assignments(on: date, projection: projection)
            : []
        let dailyTodos = todos(on: date, projection: projection)

        VStack(alignment: .leading, spacing: LWSpace.xs) {
            if showDateHeader {
                Text(date, format: .dateTime.weekday(.wide).month().day())
                    .font(LWFont.heading)
                    .foregroundStyle(LWColor.inkSecondary)
                    .padding(.horizontal, LWSpace.xxs)
            }

            VStack(alignment: .leading, spacing: 0) {
                if dailyEvents.isEmpty && dailyAssignments.isEmpty && dailyTodos.isEmpty {
                    Text("Nothing planned or due. Enjoy the space.")
                        .font(LWFont.callout)
                        .foregroundStyle(LWColor.inkSecondary)
                        .padding(LWSpace.md)
                } else {
                    ForEach(Array(dailyEvents.enumerated()), id: \.element.id) { index, event in
                        if index > 0 { LWRowDivider() }
                        if ownedExamEventIDs.contains(event.id) {
                            CalendarEventRow(event: event)
                                .padding(.horizontal, LWSpace.md)
                        } else {
                            Button {
                                eventToEdit = event
                                isPresentingEditor = true
                            } label: {
                                CalendarEventRow(event: event)
                                    .padding(.horizontal, LWSpace.md)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    ForEach(Array(dailyAssignments.enumerated()), id: \.element.id) { index, assignment in
                        if index > 0 || !dailyEvents.isEmpty { LWRowDivider() }
                        CalendarAssignmentRow(assignment: assignment)
                            .padding(.horizontal, LWSpace.md)
                    }
                    ForEach(Array(dailyTodos.enumerated()), id: \.element.id) { index, todo in
                        if index > 0 || !dailyEvents.isEmpty || !dailyAssignments.isEmpty { LWRowDivider() }
                        NavigationLink {
                            DailyTodosView(selectedDate: date)
                        } label: {
                            CalendarDailyTodoRow(todo: todo)
                                .padding(.horizontal, LWSpace.md)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LWColor.surfaceRaised, in: RoundedRectangle(cornerRadius: LWRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: LWRadius.lg)
                    .stroke(LWColor.hairline, lineWidth: LWStroke.hairline)
            )
        }
    }

    private var monthDates: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: displayedMonth)
        let leadingCount = (firstWeekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leadingCount) + range.compactMap { day in
            calendar.date(bySetting: .day, value: day, of: displayedMonth)
        }
    }

    private func events(
        on date: Date,
        projection: CalendarPlanProjection
    ) -> [CalendarEvent] {
        projection.eventsByDayKey[DaySnapshotService.dayKey(for: date, calendar: calendar)] ?? []
    }

    private func assignments(
        on date: Date,
        projection: CalendarPlanProjection
    ) -> [Assignment] {
        projection.assignmentsByDayKey[DaySnapshotService.dayKey(for: date, calendar: calendar)] ?? []
    }

    private func todos(
        on date: Date,
        projection: CalendarPlanProjection
    ) -> [DailyTodo] {
        projection.todosByDayKey[DailyTodoSupport.dayKey(for: date, calendar: calendar)] ?? []
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
        if let event, ownedExamEventIDs.contains(event.id) {
            saveErrorMessage = "Update this exam from Certifications."
            return false
        }
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
            let sortOrder = events
                .filter { calendar.isDate($0.date, inSameDayAs: normalizedDate) }
                .map(\.sortOrder)
                .max()
                .map { $0 + 1 } ?? 0
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
        guard !ownedExamEventIDs.contains(event.id) else {
            saveErrorMessage = "Delete this exam from Certifications."
            return false
        }
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
    let hasTodos: Bool

    var body: some View {
        VStack(spacing: LWSpace.xxs) {
            Text(date, format: .dateTime.day())
                .font(isSelected ? LWFont.calloutMedium : LWFont.callout)
                .monospacedDigit()

            // Events include certification exams once they have been synchronized.
            HStack(spacing: 3) {
                Circle()
                    .fill(hasEvents ? (isSelected ? LWColor.onAccent : LWColor.accent) : .clear)
                    .frame(width: 4, height: 4)
                RoundedRectangle(cornerRadius: 1)
                    .fill(hasAssignments ? (isSelected ? LWColor.onAccent : LWColor.warning) : .clear)
                    .frame(width: 7, height: 3)
                RoundedRectangle(cornerRadius: LWRadius.sm)
                    .stroke(hasTodos ? (isSelected ? LWColor.onAccent : LWColor.inkSecondary) : .clear, lineWidth: LWStroke.emphasis)
                    .frame(width: 5, height: 5)
            }
            .frame(height: 4)
        }
        .foregroundStyle(isSelected ? LWColor.onAccent : LWColor.ink)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: LWRadius.sm)
                    .fill(LWColor.accent)
            }
        }
        .overlay {
            if isToday && !isSelected {
                RoundedRectangle(cornerRadius: LWRadius.sm)
                    .stroke(LWColor.accent, lineWidth: LWStroke.emphasis)
            }
        }
        .animation(LWMotion.toggle, value: isSelected)
        .accessibilityLabel(date.formatted(date: .long, time: .omitted))
        .accessibilityValue(
            hasEvents || hasAssignments || hasTodos
                ? "\(hasEvents ? "Has events" : "")\(hasEvents && (hasAssignments || hasTodos) ? ", " : "")\(hasAssignments ? "Has assignments due" : "")\(hasAssignments && hasTodos ? ", " : "")\(hasTodos ? "Has to-dos" : "")"
                : "Nothing scheduled"
        )
    }
}

private struct CalendarEventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .top, spacing: LWSpace.sm) {
            Text(timeLabel)
                .font(LWFont.monoSmall)
                .monospacedDigit()
                .foregroundStyle(LWColor.inkSecondary)
                .frame(width: 76, alignment: .leading)

            Rectangle()
                .fill(LWColor.accent.opacity(0.5))
                .frame(width: 2)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(LWFont.callout)
                    .foregroundStyle(LWColor.ink)
                if !event.notes.isEmpty {
                    Text(event.notes)
                        .font(LWFont.caption)
                        .foregroundStyle(LWColor.inkSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, LWSpace.xs)
        .frame(minHeight: LWSpace.minTapTarget, alignment: .leading)
        .contentShape(Rectangle())
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
        HStack(alignment: .top, spacing: LWSpace.sm) {
            Text("Due")
                .font(LWFont.captionMedium)
                .foregroundStyle(LWColor.warning)
                .frame(width: 76, alignment: .leading)

            Rectangle()
                .fill(LWColor.warning.opacity(0.5))
                .frame(width: 2)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.title)
                    .font(LWFont.callout)
                    .foregroundStyle(LWColor.ink)
                HStack(spacing: LWSpace.xxs) {
                    if let course = assignment.course { Text(course.name) }
                    Text(assignment.dueDate, format: .dateTime.hour().minute())
                        .monospacedDigit()
                }
                .font(LWFont.caption)
                .foregroundStyle(LWColor.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, LWSpace.xs)
        .frame(minHeight: LWSpace.minTapTarget, alignment: .leading)
        .accessibilityLabel("Assignment due: \(assignment.title)")
    }
}

private struct CalendarDailyTodoRow: View {
    let todo: DailyTodo

    var body: some View {
        HStack(alignment: .top, spacing: LWSpace.sm) {
            Text(todo.isCompleted ? "Done" : "To-do")
                .font(LWFont.captionMedium)
                .foregroundStyle(todo.isCompleted ? LWColor.success : LWColor.inkSecondary)
                .frame(width: 76, alignment: .leading)

            Rectangle()
                .fill((todo.isCompleted ? LWColor.success : LWColor.inkSecondary).opacity(0.5))
                .frame(width: 2)
                .clipShape(Capsule())

            Text(todo.title)
                .font(LWFont.callout)
                .foregroundStyle(todo.isCompleted ? LWColor.inkSecondary : LWColor.ink)
                .strikethrough(todo.isCompleted, color: LWColor.inkTertiary)

            Spacer(minLength: 0)
        }
        .padding(.vertical, LWSpace.xs)
        .frame(minHeight: LWSpace.minTapTarget, alignment: .leading)
        .accessibilityLabel("To-do: \(todo.title), \(todo.isCompleted ? "completed" : "not completed")")
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
