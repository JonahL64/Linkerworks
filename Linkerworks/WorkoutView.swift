import Foundation
import SwiftData
import SwiftUI

struct WorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .reverse)
    private var workoutSessions: [WorkoutSession]

    @State private var isPresentingExerciseEditor = false
    @State private var isPresentingNewWorkoutEditor = false
    @State private var isPresentingSessionEditor = false
    @State private var saveErrorMessage: String?

    private var activeWorkout: WorkoutSession? {
        workoutSessions.first { $0.state == .inProgress }
    }

    private var completedWorkouts: [WorkoutSession] {
        workoutSessions.filter { $0.state == .completed }
    }

    var body: some View {
        List {
            if let activeWorkout {
                activeWorkoutContent(activeWorkout)
            } else {
                startWorkoutContent
            }

            workoutHistoryContent

            SwiftUI.Section {
                NavigationLink {
                    WorkoutReferenceView()
                } label: {
                    Label("Lifting Reference", systemImage: "book")
                }
            }
        }
        .trainingLogList()
        .listRowBackground(TrainingLogTheme.background)
        .navigationTitle("Workout")
        .toolbar {
            if let activeWorkout {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") {
                        finish(activeWorkout)
                    }
                    .foregroundStyle(TrainingLogTheme.completionAccent)
                }
            }
        }
        .sheet(isPresented: $isPresentingExerciseEditor) {
            if let activeWorkout {
                WorkoutExerciseEditorView(
                    exercise: nil,
                    onSaved: { name in addExercise(named: name, to: activeWorkout) }
                )
            }
        }
        .sheet(isPresented: $isPresentingNewWorkoutEditor) {
            StartWorkoutEditorView(
                canRepeat: { title in mostRecentFinishedWorkout(titled: title) != nil },
                onSaved: startWorkout(title:firstExerciseNamed:),
                onRepeat: repeatLastWorkout(titled:)
            )
        }
        .sheet(isPresented: $isPresentingSessionEditor) {
            if let activeWorkout {
                WorkoutSessionEditorView(
                    workout: activeWorkout,
                    onSaved: { title, notes in
                        saveWorkoutDetails(for: activeWorkout, title: title, notes: notes)
                    }
                )
            }
        }
        .alert("Unable to Save", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private func activeWorkoutContent(_ workout: WorkoutSession) -> some View {
        SwiftUI.Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(workout.title?.nonEmpty ?? "WORKOUT IN PROGRESS")
                    .font(.headline)
                Text(workout.startedAt, format: .dateTime.weekday(.abbreviated).month().day().hour().minute())
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(TrainingLogTheme.secondaryText)
                if let notes = workout.notes?.nonEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(TrainingLogTheme.secondaryText)
                }
            }

            Button {
                isPresentingSessionEditor = true
            } label: {
                Label("Edit Details", systemImage: "square.and.pencil")
            }
        }

        SwiftUI.Section("Exercises") {
            let exercises = orderedExercises(for: workout)
            if exercises.isEmpty {
                Text("Add an exercise to start logging sets.")
                    .foregroundStyle(TrainingLogTheme.secondaryText)
            } else {
                ForEach(exercises) { exercise in
                    NavigationLink {
                        WorkoutExerciseView(exercise: exercise)
                    } label: {
                        WorkoutExerciseRow(exercise: exercise)
                    }
                }
                .onMove { source, destination in
                    reorderExercises(source: source, destination: destination, in: workout)
                }
                .onDelete { offsets in
                    deleteExercises(offsets, from: exercises)
                }
            }

            Button {
                isPresentingExerciseEditor = true
            } label: {
                Label("Add Exercise", systemImage: "plus")
            }
        }
    }

    private var startWorkoutContent: some View {
        SwiftUI.Section {
            Text("No workout in progress.")
                .foregroundStyle(TrainingLogTheme.secondaryText)
            Button {
                isPresentingNewWorkoutEditor = true
            } label: {
                Label("Start Workout", systemImage: "play.fill")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(TrainingLogTheme.primaryText)
            .trainingLogRow()
        }
    }

    @ViewBuilder
    private var workoutHistoryContent: some View {
        SwiftUI.Section("Workout History") {
            if completedWorkouts.isEmpty {
                Text("Completed workouts will stay here.")
                    .foregroundStyle(TrainingLogTheme.secondaryText)
            } else {
                ForEach(completedWorkouts) { workout in
                    NavigationLink {
                        CompletedWorkoutDetailView(workout: workout)
                    } label: {
                        CompletedWorkoutRow(workout: workout)
                    }
                }
            }
        }
    }

    private func orderedExercises(for workout: WorkoutSession) -> [WorkoutExercise] {
        workout.exercises.sorted { lhs, rhs in
            lhs.sortOrder == rhs.sortOrder
                ? lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                : lhs.sortOrder < rhs.sortOrder
        }
    }

    private func startWorkout(title: String?, firstExerciseNamed name: String) -> Bool {
        guard activeWorkout == nil else { return false }
        let workout = WorkoutSession(title: title)
        modelContext.insert(workout)
        modelContext.insert(WorkoutExercise(name: name, sortOrder: 0, session: workout))
        return saveContext()
    }

    private func mostRecentFinishedWorkout(titled title: String) -> WorkoutSession? {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else { return nil }
        return completedWorkouts
            .filter {
            $0.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(normalizedTitle) == .orderedSame
            }
            .filter { !$0.exercises.isEmpty }
            .max { lhs, rhs in
                (lhs.finishedAt ?? lhs.startedAt) < (rhs.finishedAt ?? rhs.startedAt)
            }
    }

    private func repeatLastWorkout(titled title: String) -> Bool {
        guard activeWorkout == nil, let source = mostRecentFinishedWorkout(titled: title) else { return false }

        let workout = WorkoutSession(title: title.trimmingCharacters(in: .whitespacesAndNewlines))
        modelContext.insert(workout)
        for sourceExercise in orderedExercises(for: source) {
            let exercise = WorkoutExercise(
                name: sourceExercise.name,
                sortOrder: sourceExercise.sortOrder,
                session: workout
            )
            modelContext.insert(exercise)
            for sourceSet in sourceExercise.sets.sorted(by: { lhs, rhs in
                lhs.setOrder == rhs.setOrder ? lhs.id.uuidString < rhs.id.uuidString : lhs.setOrder < rhs.setOrder
            }) {
                modelContext.insert(WorkoutSet(
                    setOrder: sourceSet.setOrder,
                    reps: sourceSet.reps,
                    load: sourceSet.load,
                    isCompleted: false,
                    exercise: exercise
                ))
            }
        }
        return saveContext()
    }

    private func addExercise(named name: String, to workout: WorkoutSession) -> Bool {
        guard workout.state == .inProgress else {
            saveErrorMessage = "Completed workouts cannot be changed."
            return false
        }
        let sortOrder = (workout.exercises.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(WorkoutExercise(name: name, sortOrder: sortOrder, session: workout))
        return saveContext()
    }

    private func saveWorkoutDetails(for workout: WorkoutSession, title: String?, notes: String?) -> Bool {
        guard workout.state == .inProgress else {
            saveErrorMessage = "Completed workouts cannot be changed."
            return false
        }
        workout.title = title
        workout.notes = notes
        return saveContext()
    }

    private func reorderExercises(source: IndexSet, destination: Int, in workout: WorkoutSession) {
        guard workout.state == .inProgress else {
            saveErrorMessage = "Completed workouts cannot be changed."
            return
        }
        var exercises = orderedExercises(for: workout)
        exercises.move(fromOffsets: source, toOffset: destination)
        for (index, exercise) in exercises.enumerated() {
            exercise.sortOrder = index
        }
        _ = saveContext()
    }

    private func deleteExercises(_ offsets: IndexSet, from exercises: [WorkoutExercise]) {
        guard exercises.allSatisfy({ $0.session?.state == .inProgress }) else {
            saveErrorMessage = "Completed workouts cannot be changed."
            return
        }
        for index in offsets {
            modelContext.delete(exercises[index])
        }
        _ = saveContext()
    }

    private func finish(_ workout: WorkoutSession) {
        guard workout.state == .inProgress else { return }
        workout.state = .completed
        workout.finishedAt = Date()
        _ = saveContext()
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
}

private struct WorkoutExerciseRow: View {
    let exercise: WorkoutExercise

    private var orderedSets: [WorkoutSet] {
        exercise.sets.sorted { $0.setOrder < $1.setOrder }
    }

    var body: some View {
        let completedCount = orderedSets.filter(\.isCompleted).count
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
            Text("\(completedCount) / \(orderedSets.count) SETS")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(TrainingLogTheme.secondaryText)
        }
    }
}

private struct CompletedWorkoutRow: View {
    let workout: WorkoutSession

    private var exerciseCount: Int { workout.exercises.count }
    private var setCount: Int { workout.exercises.reduce(0) { $0 + $1.sets.count } }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workout.title?.nonEmpty ?? "Workout")
            if let finishedAt = workout.finishedAt {
                Text(finishedAt, format: .dateTime.weekday(.abbreviated).month().day().year().hour().minute())
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(TrainingLogTheme.secondaryText)
            }
            Text("\(exerciseCount) EXERCISES · \(setCount) SETS")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(TrainingLogTheme.secondaryText)
        }
    }
}

private struct WorkoutExerciseView: View {
    private enum SetEntryField: Hashable { case reps, load }

    @Environment(\.modelContext) private var modelContext
    let exercise: WorkoutExercise

    @State private var isPresentingExerciseEditor = false
    @State private var isPresentingSetEditor = false
    @State private var setToEdit: WorkoutSet?
    @State private var saveErrorMessage: String?
    @State private var quickReps = ""
    @State private var quickLoad = ""
    @State private var quickEntryError: String?
    @FocusState private var focusedSetEntryField: SetEntryField?

    private var orderedSets: [WorkoutSet] {
        exercise.sets.sorted { lhs, rhs in
            lhs.setOrder == rhs.setOrder ? lhs.id.uuidString < rhs.id.uuidString : lhs.setOrder < rhs.setOrder
        }
    }

    private var isWorkoutInProgress: Bool {
        exercise.session?.state == .inProgress
    }

    private var sessionVolume: Double {
        exercise.sets.filter(\.isCompleted).reduce(0) { $0 + (Double($1.reps) * ($1.load ?? 0)) }
    }

    private var mostRecentCompletion: Date? {
        exercise.session?.exercises.flatMap(\.sets).compactMap(\.completedAt).max()
    }

    var body: some View {
        List {
            SwiftUI.Section {
                exerciseSummaryHeader
            }

            if isWorkoutInProgress {
                SwiftUI.Section("Quick Log") {
                    quickSetEntry
                    Button("Log Set") {
                        submitQuickSet()
                    }
                    .buttonStyle(.bordered)
                    if let quickEntryError {
                        Text(quickEntryError)
                            .font(.caption)
                            .foregroundStyle(TrainingLogTheme.completionAccent)
                    }
                }
            }

            SwiftUI.Section("Sets") {
                if orderedSets.isEmpty {
                    Text("Add a set to log reps and optional load.")
                        .foregroundStyle(TrainingLogTheme.secondaryText)
                } else {
                    ForEach(orderedSets) { workoutSet in
                        WorkoutSetRow(
                            workoutSet: workoutSet,
                            onToggleCompletion: { toggleCompletion(for: workoutSet) },
                            onEdit: {
                                setToEdit = workoutSet
                                isPresentingSetEditor = true
                            }
                        )
                    }
                    .onMove { source, destination in
                        reorderSets(source: source, destination: destination)
                    }
                    .onDelete { offsets in
                        deleteSets(offsets)
                    }
                }

                if isWorkoutInProgress {
                    Button {
                        addRepeatedCompletedSet()
                    } label: {
                        Label(
                            orderedSets.contains(where: \.isCompleted) ? "Add Repeated Completed Set" : "Log Your First Set",
                            systemImage: "plus.circle.fill"
                        )
                        .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(TrainingLogTheme.primaryText)
                    .trainingLogRow()
                }
            }
        }
        .onAppear {
            seedQuickEntryFromLatestSet()
        }
        .trainingLogList()
        .listRowBackground(TrainingLogTheme.background)
        .navigationTitle(exercise.name)
        .toolbar {
            if isWorkoutInProgress {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingExerciseEditor = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingExerciseEditor) {
            WorkoutExerciseEditorView(
                exercise: exercise,
                onSaved: { name in renameExercise(name) }
            )
        }
        .sheet(isPresented: $isPresentingSetEditor, onDismiss: { setToEdit = nil }) {
            WorkoutSetEditorView(
                workoutSet: setToEdit,
                onSaved: saveSet
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
    }

    private func renameExercise(_ name: String) -> Bool {
        guard isWorkoutInProgress else {
            saveErrorMessage = "Completed workouts cannot be changed."
            return false
        }
        exercise.name = name
        return saveContext()
    }

    private var exerciseSummaryHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(sessionVolume.displayText) VOLUME")
                .font(.headline)
                .monospacedDigit()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(restText(at: context.date))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(TrainingLogTheme.secondaryText)
            }
        }
    }

    private var quickSetEntry: some View {
        HStack(spacing: 10) {
            TextField("Reps", text: $quickReps)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .submitLabel(.next)
                .focused($focusedSetEntryField, equals: .reps)
                .onSubmit { focusedSetEntryField = .load }
                .monospacedDigit()
                .frame(maxWidth: .infinity)
            TextField("Load", text: $quickLoad)
                .keyboardType(.numbersAndPunctuation)
                .submitLabel(.done)
                .focused($focusedSetEntryField, equals: .load)
                .onSubmit { submitQuickSet() }
                .monospacedDigit()
                .frame(maxWidth: .infinity)
            Text("LOAD")
                .font(.caption)
                .foregroundStyle(TrainingLogTheme.secondaryText)
        }
    }

    private func restText(at date: Date) -> String {
        guard let mostRecentCompletion else { return "REST —" }
        let seconds = max(0, Int(date.timeIntervalSince(mostRecentCompletion)))
        return String(format: "REST %02d:%02d", seconds / 60, seconds % 60)
    }

    private func seedQuickEntryFromLatestSet() {
        guard let latestSet = orderedSets.last else { return }
        quickReps = String(latestSet.reps)
        quickLoad = latestSet.load.map { $0.displayText } ?? ""
    }

    private func submitQuickSet() {
        guard let reps = Int(quickReps.trimmingCharacters(in: .whitespacesAndNewlines)), reps >= 0 else {
            quickEntryError = "Enter zero or a positive whole number of reps."
            focusedSetEntryField = .reps
            return
        }
        let trimmedLoad = quickLoad.trimmingCharacters(in: .whitespacesAndNewlines)
        let load: Double?
        if trimmedLoad.isEmpty {
            load = nil
        } else if let parsed = Double(normalizedLoad(trimmedLoad)), parsed.isFinite, parsed >= 0 {
            load = parsed
        } else {
            quickEntryError = "Load must be blank or a nonnegative number."
            focusedSetEntryField = .load
            return
        }

        guard isWorkoutInProgress else { return }
        let setOrder = (exercise.sets.map(\.setOrder).max() ?? -1) + 1
        modelContext.insert(WorkoutSet(
            setOrder: setOrder,
            reps: reps,
            load: load,
            isCompleted: true,
            completedAt: Date(),
            exercise: exercise
        ))
        if saveContext() {
            quickEntryError = nil
            focusedSetEntryField = .reps
        }
    }

    private func saveSet(_ workoutSet: WorkoutSet?, _ reps: Int, _ load: Double?, _ isCompleted: Bool) -> Bool {
        guard isWorkoutInProgress else {
            saveErrorMessage = "Completed workouts cannot be changed."
            return false
        }
        if let workoutSet {
            workoutSet.reps = reps
            workoutSet.load = load
            workoutSet.isCompleted = isCompleted
            workoutSet.completedAt = isCompleted ? (workoutSet.completedAt ?? Date()) : nil
        } else {
            let setOrder = (exercise.sets.map(\.setOrder).max() ?? -1) + 1
            modelContext.insert(WorkoutSet(
                setOrder: setOrder,
                reps: reps,
                load: load,
                isCompleted: isCompleted,
                exercise: exercise
            ))
        }
        return saveContext()
    }

    private func addRepeatedCompletedSet() {
        guard let priorSet = orderedSets.last(where: \.isCompleted) else {
            focusedSetEntryField = .reps
            return
        }

        guard isWorkoutInProgress else {
            saveErrorMessage = "Completed workouts cannot be changed."
            return
        }

        let setOrder = (exercise.sets.map(\.setOrder).max() ?? -1) + 1
        modelContext.insert(WorkoutSet(
            setOrder: setOrder,
            reps: priorSet.reps,
            load: priorSet.load,
            isCompleted: true,
            completedAt: Date(),
            exercise: exercise
        ))
        if saveContext() {
            seedQuickEntryFromLatestSet()
        }
    }

    private func toggleCompletion(for workoutSet: WorkoutSet) {
        guard isWorkoutInProgress else {
            saveErrorMessage = "Completed workouts cannot be changed."
            return
        }
        workoutSet.isCompleted.toggle()
        workoutSet.completedAt = workoutSet.isCompleted ? Date() : nil
        if saveContext() {
            seedQuickEntryFromLatestSet()
        }
    }

    private func reorderSets(source: IndexSet, destination: Int) {
        guard isWorkoutInProgress else {
            saveErrorMessage = "Completed workouts cannot be changed."
            return
        }
        var sets = orderedSets
        sets.move(fromOffsets: source, toOffset: destination)
        for (index, workoutSet) in sets.enumerated() {
            workoutSet.setOrder = index
        }
        _ = saveContext()
    }

    private func deleteSets(_ offsets: IndexSet) {
        guard isWorkoutInProgress else {
            saveErrorMessage = "Completed workouts cannot be changed."
            return
        }
        let setsToDelete = offsets.map { orderedSets[$0] }
        var survivingSets = orderedSets
        survivingSets.remove(atOffsets: offsets)
        for workoutSet in setsToDelete {
            modelContext.delete(workoutSet)
        }
        for (index, workoutSet) in survivingSets.enumerated() {
            workoutSet.setOrder = index
        }
        _ = saveContext()
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

    private func normalizedLoad(_ value: String) -> String {
        let separator = Locale.current.decimalSeparator ?? "."
        return separator == "." ? value : value.replacingOccurrences(of: separator, with: ".")
    }
}

private struct WorkoutSetRow: View {
    let workoutSet: WorkoutSet
    let onToggleCompletion: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleCompletion) {
                Image(systemName: workoutSet.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(workoutSet.isCompleted ? TrainingLogTheme.completionAccent : TrainingLogTheme.secondaryText)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("SET \(workoutSet.setOrder + 1)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(TrainingLogTheme.secondaryText)
                    Text(workoutSet.summary)
                        .monospacedDigit()
                        .foregroundStyle(TrainingLogTheme.primaryText)
                    if let completedAt = workoutSet.completedAt {
                        Text(completedAt, format: .dateTime.hour().minute())
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(TrainingLogTheme.completionAccent)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}

private struct CompletedWorkoutDetailView: View {
    let workout: WorkoutSession

    private var exercises: [WorkoutExercise] {
        workout.exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        List {
            SwiftUI.Section {
                if let finishedAt = workout.finishedAt {
                    LabeledContent("Completed") {
                        Text(finishedAt, format: .dateTime.month().day().year().hour().minute())
                            .monospacedDigit()
                    }
                }
                if let notes = workout.notes?.nonEmpty {
                    Text(notes)
                        .foregroundStyle(TrainingLogTheme.secondaryText)
                }
            }

            ForEach(exercises) { exercise in
                SwiftUI.Section(exercise.name) {
                    let sets = exercise.sets.sorted { $0.setOrder < $1.setOrder }
                    if sets.isEmpty {
                        Text("No sets recorded.")
                            .foregroundStyle(TrainingLogTheme.secondaryText)
                    } else {
                        ForEach(sets) { workoutSet in
                            HStack {
                                Image(systemName: workoutSet.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(workoutSet.isCompleted ? TrainingLogTheme.completionAccent : TrainingLogTheme.secondaryText)
                                Text("SET \(workoutSet.setOrder + 1)")
                                    .font(.caption.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(TrainingLogTheme.secondaryText)
                                Spacer()
                                Text(workoutSet.summary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
        .trainingLogList()
        .listRowBackground(TrainingLogTheme.background)
        .navigationTitle(workout.title?.nonEmpty ?? "Workout")
    }
}

@MainActor
private struct WorkoutSessionEditorView: View {
    let workout: WorkoutSession
    let onSaved: (String?, String?) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var notes: String
    @State private var validationMessage: String?

    init(workout: WorkoutSession, onSaved: @escaping (String?, String?) -> Bool) {
        self.workout = workout
        self.onSaved = onSaved
        _title = State(initialValue: workout.title ?? "")
        _notes = State(initialValue: workout.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section {
                    TextField("Title (optional)", text: $title)
                    TextEditor(text: $notes)
                        .frame(minHeight: 110)
                } header: {
                    Text("Workout")
                } footer: {
                    Text("Notes are optional and stay with this workout in history.")
                }
            }
            .trainingLogForm()
            .navigationTitle("Workout Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .alert("Unable to Save", isPresented: Binding(
                get: { validationMessage != nil },
                set: { if !$0 { validationMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage ?? "")
            }
        }
        .trainingLogNavigation()
    }

    private func save() {
        if onSaved(title.trimmedOrNil, notes.trimmedOrNil) {
            dismiss()
        } else {
            validationMessage = "The workout could not be saved. Try again."
        }
    }
}

@MainActor
private struct StartWorkoutEditorView: View {
    let canRepeat: (String) -> Bool
    let onSaved: (String?, String) -> Bool
    let onRepeat: (String) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var exerciseName = ""
    @State private var validationMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section {
                    TextField("Workout title (optional)", text: $title)
                    TextField("Exercise name", text: $exerciseName)
                } header: {
                    Text("First Exercise")
                } footer: {
                    Text("A matching titled workout can be repeated with its exercise and set structure.")
                }

                if let workoutTitle = title.trimmedOrNil, canRepeat(workoutTitle) {
                    SwiftUI.Section {
                        Button {
                            repeatLastWorkout(named: workoutTitle)
                        } label: {
                            Label("Repeat Last Workout", systemImage: "arrow.clockwise")
                                .font(.body.weight(.semibold))
                        }
                    }
                }
            }
            .trainingLogForm()
            .navigationTitle("Start Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { save() }
                }
            }
            .alert("Check Exercise", isPresented: Binding(
                get: { validationMessage != nil },
                set: { if !$0 { validationMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage ?? "")
            }
        }
        .trainingLogNavigation()
    }

    private func save() {
        guard let name = exerciseName.trimmedOrNil else {
            validationMessage = "Enter an exercise name."
            return
        }
        if onSaved(title.trimmedOrNil, name) {
            dismiss()
        } else {
            validationMessage = "The workout could not be started. Try again."
        }
    }

    private func repeatLastWorkout(named title: String) {
        if onRepeat(title) {
            dismiss()
        } else {
            validationMessage = "The last workout could not be repeated. Try again."
        }
    }
}

private struct WorkoutReferenceView: View {
    @Query(sort: \DomainReference.sourceName) private var references: [DomainReference]

    private var liftingReferences: [DomainReference] {
        references.filter { $0.domain == .lifting }
    }

    var body: some View {
        List {
            if liftingReferences.isEmpty {
                Text("No lifting reference is available.")
                    .foregroundStyle(TrainingLogTheme.secondaryText)
            } else {
                ForEach(liftingReferences) { reference in
                    SwiftUI.Section(reference.sourceName) {
                        WorkoutReferenceTextRows(rowsJSON: reference.rowsJSON)
                    }
                }
            }
        }
        .trainingLogList()
        .listRowBackground(TrainingLogTheme.background)
        .navigationTitle("Lifting Reference")
    }
}

private struct WorkoutReferenceTextRows: View {
    let rowsJSON: Data

    private var rows: [[String]] {
        guard let rawRows = try? JSONSerialization.jsonObject(with: rowsJSON) as? [[Any]] else { return [] }
        return rawRows.map { row in
            row.compactMap { value in
                if let text = value as? String { return text }
                if let number = value as? NSNumber { return number.stringValue }
                return nil
            }
        }
    }

    var body: some View {
        if rows.isEmpty {
            Text("This reference could not be decoded.")
                .foregroundStyle(TrainingLogTheme.secondaryText)
        } else {
            ForEach(rows.indices, id: \.self) { index in
                Text(rows[index].joined(separator: " · "))
                    .foregroundStyle(index == 0 ? TrainingLogTheme.primaryText : TrainingLogTheme.secondaryText)
            }
        }
    }
}

@MainActor
private struct WorkoutExerciseEditorView: View {
    let exercise: WorkoutExercise?
    let onSaved: (String) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var validationMessage: String?

    init(exercise: WorkoutExercise?, onSaved: @escaping (String) -> Bool) {
        self.exercise = exercise
        self.onSaved = onSaved
        _name = State(initialValue: exercise?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("Exercise") {
                    TextField("Exercise name", text: $name)
                }
            }
            .trainingLogForm()
            .navigationTitle(exercise == nil ? "Add Exercise" : "Rename Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .alert("Check Exercise", isPresented: Binding(
                get: { validationMessage != nil },
                set: { if !$0 { validationMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage ?? "")
            }
        }
        .trainingLogNavigation()
    }

    private func save() {
        guard let trimmedName = name.trimmedOrNil else {
            validationMessage = "Enter an exercise name."
            return
        }
        if onSaved(trimmedName) {
            dismiss()
        } else {
            validationMessage = "The exercise could not be saved. Try again."
        }
    }
}

@MainActor
private struct WorkoutSetEditorView: View {
    let workoutSet: WorkoutSet?
    let onSaved: (WorkoutSet?, Int, Double?, Bool) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var reps: String
    @State private var load: String
    @State private var isCompleted: Bool
    @State private var validationMessage: String?

    init(
        workoutSet: WorkoutSet?,
        onSaved: @escaping (WorkoutSet?, Int, Double?, Bool) -> Bool
    ) {
        self.workoutSet = workoutSet
        self.onSaved = onSaved
        _reps = State(initialValue: workoutSet.map { String($0.reps) } ?? "")
        _load = State(initialValue: workoutSet?.load.map(Self.loadText) ?? "")
        _isCompleted = State(initialValue: workoutSet?.isCompleted ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("Set") {
                    numberField("Reps", value: $reps, suffix: "reps")
                    numberField("Load", value: $load, suffix: "optional")
                    Toggle("Set completed", isOn: $isCompleted)
                }
            }
            .trainingLogForm()
            .navigationTitle(workoutSet == nil ? "Add Set" : "Edit Set")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .alert("Check Set", isPresented: Binding(
                get: { validationMessage != nil },
                set: { if !$0 { validationMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage ?? "")
            }
        }
        .trainingLogNavigation()
    }

    private func numberField(_ title: String, value: Binding<String>, suffix: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(maxWidth: 100)
            Text(suffix)
                .foregroundStyle(TrainingLogTheme.secondaryText)
        }
    }

    private func save() {
        guard let parsedReps = Int(reps), parsedReps >= 0 else {
            validationMessage = "Enter zero or a positive whole number of reps."
            return
        }

        let trimmedLoad = load.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedLoad: Double?
        if trimmedLoad.isEmpty {
            parsedLoad = nil
        } else if let value = Double(normalizedLoad(trimmedLoad)), value.isFinite, value >= 0 {
            parsedLoad = value
        } else {
            validationMessage = "Load must be blank or a nonnegative number."
            return
        }

        if onSaved(workoutSet, parsedReps, parsedLoad, isCompleted) {
            dismiss()
        } else {
            validationMessage = "The set could not be saved. Try again."
        }
    }

    private static func loadText(_ load: Double) -> String {
        load.displayText
    }

    private func normalizedLoad(_ value: String) -> String {
        let separator = Locale.current.decimalSeparator ?? "."
        return separator == "." ? value : value.replacingOccurrences(of: separator, with: ".")
    }
}

private extension WorkoutSet {
    var summary: String {
        if let load {
            return "\(reps) REPS · \(load.displayText) LOAD"
        }
        return "\(reps) REPS"
    }
}

private extension Double {
    var displayText: String {
        guard isFinite else { return "—" }
        if rounded() == self, self <= Double(Int.max), self >= Double(Int.min) {
            return String(Int(self))
        }
        return String(self)
    }
}

private extension String {
    var nonEmpty: String? {
        trimmedOrNil
    }

    var trimmedOrNil: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
