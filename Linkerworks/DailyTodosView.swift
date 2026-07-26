import SwiftData
import SwiftUI
import UIKit

/// Date-based, one-off commitments. It intentionally owns neither routine
/// records nor homework data.
@MainActor
struct DailyTodosView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [DailyTodo]

    @State private var selectedDate: Date
    @State private var todoToEdit: DailyTodo?
    @State private var showingNewTodo = false
    @State private var deletionCandidate: DailyTodo?
    @State private var saveError: String?

    private let calendar = Calendar.current

    init(selectedDate: Date = Date()) {
        _selectedDate = State(initialValue: Calendar.current.startOfDay(for: selectedDate))
    }

    private var todosForSelectedDate: [DailyTodo] {
        DailyTodoSupport.todos(on: selectedDate, from: todos, calendar: calendar)
    }

    private var pendingTodos: [DailyTodo] {
        todosForSelectedDate.filter { !$0.isCompleted }
    }

    private var completedTodos: [DailyTodo] {
        todosForSelectedDate.filter(\.isCompleted)
    }

    var body: some View {
        List {
            SwiftUI.Section {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .font(LWFont.callout)
                    .tint(LWColor.accent)
            }

            SwiftUI.Section("To-dos") {
                if pendingTodos.isEmpty {
                    Text("Nothing to do yet.")
                        .font(LWFont.callout)
                        .foregroundStyle(LWColor.inkSecondary)
                } else {
                    ForEach(pendingTodos) { todo in
                        todoRow(todo)
                    }
                }
            }

            if !completedTodos.isEmpty {
                SwiftUI.Section("Done") {
                    ForEach(completedTodos) { todo in
                        todoRow(todo)
                    }
                }
            }
        }
        .trainingLogList()
        .navigationTitle("To-dos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    todoToEdit = nil
                    showingNewTodo = true
                } label: {
                    Label("Add to-do", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewTodo) {
            DailyTodoEditorView(todo: nil, selectedDate: selectedDate)
        }
        .sheet(item: $todoToEdit) { todo in
            DailyTodoEditorView(todo: todo, selectedDate: selectedDate)
        }
        .confirmationDialog(
            "Delete to-do?",
            isPresented: Binding(get: { deletionCandidate != nil }, set: { if !$0 { deletionCandidate = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteTodo() }
            Button("Cancel", role: .cancel) { deletionCandidate = nil }
        } message: {
            Text("This permanently removes only this to-do.")
        }
        .alert("Unable to Save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
        .trainingLogNavigation()
    }

    private func todoRow(_ todo: DailyTodo) -> some View {
        HStack(spacing: LWSpace.sm) {
            Button { toggle(todo) } label: {
                LWCheckControl(state: todo.isCompleted ? .complete : .pending)
            }
            .buttonStyle(.plain)
            .frame(minWidth: LWSpace.minTapTarget, minHeight: LWSpace.minTapTarget)
            .accessibilityLabel(todo.isCompleted ? "Mark \(todo.title) incomplete" : "Mark \(todo.title) complete")

            Button { todoToEdit = todo } label: {
                VStack(alignment: .leading, spacing: LWSpace.xxs) {
                    Text(todo.title)
                        .font(LWFont.body)
                        .foregroundStyle(todo.isCompleted ? LWColor.inkSecondary : LWColor.ink)
                        .strikethrough(todo.isCompleted, color: LWColor.inkTertiary)
                    if todo.isCompleted, let completedAt = todo.completedAt {
                        Text("Completed \(completedAt, format: .dateTime.hour().minute())")
                            .font(LWFont.caption)
                            .monospacedDigit()
                            .foregroundStyle(LWColor.inkSecondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: LWSpace.minTapTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(todo.title)")
        }
        .trainingLogRow()
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { deletionCandidate = todo } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func toggle(_ todo: DailyTodo) {
        todo.isCompleted.toggle()
        todo.completedAt = todo.isCompleted ? Date() : nil
        todo.updatedAt = Date()
        save { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }

    private func deleteTodo() {
        guard let deletionCandidate else { return }
        modelContext.delete(deletionCandidate)
        save()
        self.deletionCandidate = nil
    }

    private func save(afterSave: (() -> Void)? = nil) {
        do {
            try modelContext.save()
            afterSave?()
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
        }
    }
}

@MainActor
struct DailyTodoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var todos: [DailyTodo]

    let todo: DailyTodo?
    @State private var title: String
    @State private var scheduledDate: Date
    @State private var validationMessage: String?
    @State private var saveError: String?

    private let calendar = Calendar.current

    init(todo: DailyTodo?, selectedDate: Date) {
        self.todo = todo
        _title = State(initialValue: todo?.title ?? "")
        _scheduledDate = State(initialValue: DailyTodoSupport.date(
            for: todo?.scheduledDayKey ?? DailyTodoSupport.dayKey(for: selectedDate)
        ) ?? Calendar.current.startOfDay(for: selectedDate))
    }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("To-do") {
                    TextField("What needs doing?", text: $title, axis: .vertical)
                        .font(LWFont.body)
                        .lineLimit(1...3)
                    DatePicker("Date", selection: $scheduledDate, displayedComponents: .date)
                        .font(LWFont.callout)
                }

                if let validationMessage {
                    Text(validationMessage)
                        .font(LWFont.caption)
                        .foregroundStyle(LWColor.danger)
                }
            }
            .scrollContentBackground(.hidden)
            .background(LWColor.surface)
            .navigationTitle(todo == nil ? "New to-do" : "Edit to-do")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .alert("Unable to Save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            validationMessage = "Enter a to-do before saving."
            return
        }

        let normalizedDate = DailyTodoSupport.normalizedDate(scheduledDate, calendar: calendar)
        let normalizedDayKey = DailyTodoSupport.dayKey(for: normalizedDate, calendar: calendar)
        if let todo {
            let movedToNewDate = todo.scheduledDayKey != normalizedDayKey
            todo.title = cleanTitle
            todo.scheduledDate = normalizedDate
            todo.scheduledDayKey = normalizedDayKey
            if movedToNewDate {
                todo.sortOrder = nextSortOrder(on: normalizedDate, excluding: todo.id)
            }
            todo.updatedAt = Date()
        } else {
            modelContext.insert(DailyTodo(
                title: cleanTitle,
                scheduledDate: normalizedDate,
                sortOrder: nextSortOrder(on: normalizedDate),
                calendar: calendar
            ))
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
        }
    }

    private func nextSortOrder(on date: Date, excluding todoID: UUID? = nil) -> Int {
        let highestOrder = DailyTodoSupport.todos(on: date, from: todos, calendar: calendar)
            .filter { $0.id != todoID }
            .map(\.sortOrder)
            .max()
        return highestOrder == Int.max ? 0 : (highestOrder.map { $0 + 1 } ?? 0)
    }
}
