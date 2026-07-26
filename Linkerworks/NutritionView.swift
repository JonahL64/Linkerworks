import Foundation
import SwiftData
import SwiftUI

struct NutritionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealEntry.date, order: .reverse) private var mealEntries: [MealEntry]
    @Query(sort: \DailyMacroTarget.key) private var macroTargets: [DailyMacroTarget]
    @Query(sort: \SavedMeal.foodName) private var savedMeals: [SavedMeal]

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var isPresentingEntryEditor = false
    @State private var entryToEdit: MealEntry?
    @State private var isPresentingTargetEditor = false
    @State private var saveErrorMessage: String?

    private let calendar = Calendar.current

    private var entriesForSelectedDate: [MealEntry] {
        mealEntries.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var currentTarget: MacroValues {
        guard let target = macroTargets.first(where: { $0.key == DailyMacroTarget.singletonKey }) else {
            return .defaultTarget
        }
        return MacroValues(target: target)
    }

    private var dailyTotals: MacroValues {
        entriesForSelectedDate.reduce(.zero) { partialResult, entry in
            partialResult.adding(MacroValues(entry: entry))
        }
    }

    var body: some View {
        List {
            dateSection
            totalSection
            savedMealsSection
            SwiftUI.Section {
                NavigationLink {
                    NutritionReferenceView()
                } label: {
                    Label("Routine Reference", systemImage: "book")
                }
            }

            ForEach(MealCategory.allCases) { category in
                mealSection(for: category)
            }
        }
        .trainingLogList()
        .listRowBackground(TrainingLogTheme.background)
        .navigationTitle("Nutrition")
        .onAppear(perform: ensureDefaultTarget)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isPresentingTargetEditor = true
                } label: {
                    Label("Targets", systemImage: "target")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    entryToEdit = nil
                    isPresentingEntryEditor = true
                } label: {
                    Label("Add Meal", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingEntryEditor, onDismiss: { entryToEdit = nil }) {
            MealEntryEditorView(
                entry: entryToEdit,
                selectedDate: selectedDate,
                onSaved: saveEntry
            )
        }
        .sheet(isPresented: $isPresentingTargetEditor) {
            MacroTargetEditorView(target: macroTargets.first { $0.key == DailyMacroTarget.singletonKey })
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

    private var dateSection: some View {
        SwiftUI.Section {
            DatePicker("Day", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
        }
    }

    private var totalSection: some View {
        SwiftUI.Section("Daily Total") {
            NutritionSummaryRow(label: "Calories", logged: dailyTotals.calories, target: currentTarget.calories, unit: "kcal")
            NutritionSummaryRow(label: "Protein", logged: dailyTotals.proteinGrams, target: currentTarget.proteinGrams, unit: "g")
            NutritionSummaryRow(label: "Carbohydrates", logged: dailyTotals.carbohydrateGrams, target: currentTarget.carbohydrateGrams, unit: "g")
            NutritionSummaryRow(label: "Fat", logged: dailyTotals.fatGrams, target: currentTarget.fatGrams, unit: "g")
            NutritionSummaryRow(label: "Fiber", logged: dailyTotals.fiberGrams, target: currentTarget.fiberGrams, unit: "g")
        }
    }

    @ViewBuilder
    private var savedMealsSection: some View {
        if !savedMeals.isEmpty {
            SwiftUI.Section("Saved Meals") {
                ForEach(savedMeals) { meal in
                    Button {
                        quickLog(meal)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(meal.foodName)
                            Text("\(meal.calories) kcal · \(meal.mealCategory.displayName)")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(TrainingLogTheme.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                    .trainingLogRow()
                    .accessibilityLabel("Log \(meal.foodName) for \(selectedDate.formatted(date: .long, time: .omitted))")
                }
            }
        }
    }

    @ViewBuilder
    private func mealSection(for category: MealCategory) -> some View {
        let categoryEntries = entriesForSelectedDate
            .filter { $0.mealCategory == category }
            .sorted { lhs, rhs in
                lhs.sortOrder == rhs.sortOrder
                    ? lhs.createdAt < rhs.createdAt
                    : lhs.sortOrder < rhs.sortOrder
            }

        SwiftUI.Section(category.displayName) {
            if categoryEntries.isEmpty {
                Text("No \(category.displayName.lowercased()) logged.")
                    .foregroundStyle(TrainingLogTheme.secondaryText)
            } else {
                ForEach(categoryEntries) { entry in
                    HStack(spacing: 12) {
                        Button {
                            entryToEdit = entry
                            isPresentingEntryEditor = true
                        } label: {
                            MealEntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 0)

                        Button {
                            saveFavorite(entry)
                        } label: {
                            Image(systemName: "star")
                                .foregroundStyle(TrainingLogTheme.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Save \(entry.foodName) as favorite")
                    }
                    .trainingLogRow()
                }
                .onDelete { offsets in
                    delete(offsets, from: categoryEntries)
                }
            }
        }
    }

    private func delete(_ offsets: IndexSet, from entries: [MealEntry]) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
        _ = saveContext()
    }

    private func saveEntry(_ entry: MealEntry?, _ draft: MealEntryDraft) -> Bool {
        if let entry {
            entry.date = calendar.startOfDay(for: draft.date)
            entry.mealCategory = draft.category
            entry.foodName = draft.foodName
            entry.calories = draft.calories
            entry.proteinGrams = draft.proteinGrams
            entry.carbohydrateGrams = draft.carbohydrateGrams
            entry.fatGrams = draft.fatGrams
            entry.fiberGrams = draft.fiberGrams
        } else {
            let sortOrder = mealEntries
                .filter { calendar.isDate($0.date, inSameDayAs: draft.date) }
                .filter { $0.mealCategory == draft.category }
                .map(\.sortOrder)
                .max()
                .map { $0 + 1 } ?? 0
            modelContext.insert(MealEntry(
                date: draft.date,
                mealCategory: draft.category,
                foodName: draft.foodName,
                calories: draft.calories,
                proteinGrams: draft.proteinGrams,
                carbohydrateGrams: draft.carbohydrateGrams,
                fatGrams: draft.fatGrams,
                fiberGrams: draft.fiberGrams,
                sortOrder: sortOrder
            ))
        }

        return saveContext()
    }

    private func quickLog(_ meal: SavedMeal) {
        let sortOrder = mealEntries
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .filter { $0.mealCategory == meal.mealCategory }
            .map(\.sortOrder)
            .max()
            .map { $0 + 1 } ?? 0
        modelContext.insert(MealEntry(
            date: selectedDate,
            mealCategory: meal.mealCategory,
            foodName: meal.foodName,
            calories: meal.calories,
            proteinGrams: meal.proteinGrams,
            carbohydrateGrams: meal.carbohydrateGrams,
            fatGrams: meal.fatGrams,
            fiberGrams: meal.fiberGrams,
            sortOrder: sortOrder
        ))
        _ = saveContext()
    }

    private func saveFavorite(_ entry: MealEntry) {
        guard !savedMeals.contains(where: { meal in
            meal.mealCategory == entry.mealCategory
                && meal.foodName.caseInsensitiveCompare(entry.foodName) == .orderedSame
                && meal.calories == entry.calories
                && meal.proteinGrams == entry.proteinGrams
                && meal.carbohydrateGrams == entry.carbohydrateGrams
                && meal.fatGrams == entry.fatGrams
                && meal.fiberGrams == entry.fiberGrams
        }) else {
            return
        }

        modelContext.insert(SavedMeal(
            mealCategory: entry.mealCategory,
            foodName: entry.foodName,
            calories: entry.calories,
            proteinGrams: entry.proteinGrams,
            carbohydrateGrams: entry.carbohydrateGrams,
            fatGrams: entry.fatGrams,
            fiberGrams: entry.fiberGrams,
            sortOrder: savedMeals.count
        ))
        _ = saveContext()
    }

    private func ensureDefaultTarget() {
        guard !macroTargets.contains(where: { $0.key == DailyMacroTarget.singletonKey }) else { return }
        modelContext.insert(DailyMacroTarget())
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

private struct NutritionSummaryRow: View {
    let label: String
    let logged: Int
    let target: Int
    let unit: String

    private var status: String {
        guard target > 0 else { return "\(logged) \(unit) logged" }
        let difference = target - logged
        if difference > 0 { return "\(difference) \(unit) remaining" }
        if difference < 0 { return "\(abs(difference)) \(unit) over" }
        return "Met"
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(logged) / \(target) \(unit)")
                    .monospacedDigit()
                Text(status)
                    .font(.caption)
                    .foregroundStyle(TrainingLogTheme.secondaryText)
            }
        }
    }
}

private struct MealEntryRow: View {
    let entry: MealEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.foodName)
            Text("\(entry.calories) kcal · P \(entry.proteinGrams)g · C \(entry.carbohydrateGrams)g · F \(entry.fatGrams)g · Fiber \(entry.fiberGrams)g")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(TrainingLogTheme.secondaryText)
        }
    }
}

@MainActor
private struct MealEntryEditorView: View {
    let entry: MealEntry?
    let selectedDate: Date
    let onSaved: (MealEntry?, MealEntryDraft) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var category: MealCategory
    @State private var entryDate: Date
    @State private var foodName: String
    @State private var calories: String
    @State private var proteinGrams: String
    @State private var carbohydrateGrams: String
    @State private var fatGrams: String
    @State private var fiberGrams: String
    @State private var showsDetails: Bool
    @State private var validationMessage: String?

    init(
        entry: MealEntry?,
        selectedDate: Date,
        onSaved: @escaping (MealEntry?, MealEntryDraft) -> Bool
    ) {
        self.entry = entry
        self.selectedDate = selectedDate
        self.onSaved = onSaved
        _category = State(initialValue: entry?.mealCategory ?? .breakfast)
        _entryDate = State(initialValue: entry?.date ?? selectedDate)
        _foodName = State(initialValue: entry?.foodName ?? "")
        _calories = State(initialValue: entry.map { String($0.calories) } ?? "")
        _proteinGrams = State(initialValue: entry.map { String($0.proteinGrams) } ?? "0")
        _carbohydrateGrams = State(initialValue: entry.map { String($0.carbohydrateGrams) } ?? "0")
        _fatGrams = State(initialValue: entry.map { String($0.fatGrams) } ?? "0")
        _fiberGrams = State(initialValue: entry.map { String($0.fiberGrams) } ?? "0")
        _showsDetails = State(initialValue: entry != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("Meal") {
                    TextField("Food name", text: $foodName)
                    macroField("Calories", value: $calories, suffix: "kcal")
                }

                SwiftUI.Section {
                    DisclosureGroup("Details", isExpanded: $showsDetails) {
                        DatePicker("Day", selection: $entryDate, displayedComponents: .date)
                        Picker("Category", selection: $category) {
                            ForEach(MealCategory.allCases) { category in
                                Text(category.displayName).tag(category)
                            }
                        }
                        macroField("Protein", value: $proteinGrams, suffix: "g")
                        macroField("Carbohydrates", value: $carbohydrateGrams, suffix: "g")
                        macroField("Fat", value: $fatGrams, suffix: "g")
                        macroField("Fiber", value: $fiberGrams, suffix: "g")
                    }
                }
            }
            .trainingLogForm()
            .navigationTitle(entry == nil ? "Add Meal" : "Edit Meal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .alert("Check Meal", isPresented: Binding(
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

    private func macroField(_ title: String, value: Binding<String>, suffix: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: value)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text(suffix)
                .foregroundStyle(TrainingLogTheme.secondaryText)
        }
    }

    private func save() {
        let trimmedName = foodName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationMessage = "Enter a food name."
            return
        }
        guard let calories = Int(calories),
              let proteinGrams = Int(proteinGrams),
              let carbohydrateGrams = Int(carbohydrateGrams),
              let fatGrams = Int(fatGrams),
              let fiberGrams = Int(fiberGrams),
              [calories, proteinGrams, carbohydrateGrams, fatGrams, fiberGrams].allSatisfy({ $0 >= 0 }) else {
            validationMessage = "Enter zero or a positive whole number for every macro."
            return
        }

        let didSave = onSaved(entry, MealEntryDraft(
            date: entryDate,
            category: category,
            foodName: trimmedName,
            calories: calories,
            proteinGrams: proteinGrams,
            carbohydrateGrams: carbohydrateGrams,
            fatGrams: fatGrams,
            fiberGrams: fiberGrams
        ))
        if didSave {
            dismiss()
        } else {
            validationMessage = "The meal could not be saved. Try again."
        }
    }
}

@MainActor
private struct MacroTargetEditorView: View {
    let target: DailyMacroTarget?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var calories: String
    @State private var proteinGrams: String
    @State private var carbohydrateGrams: String
    @State private var fatGrams: String
    @State private var fiberGrams: String
    @State private var validationMessage: String?

    init(target: DailyMacroTarget?) {
        self.target = target
        _calories = State(initialValue: String(target?.calories ?? MacroValues.defaultTarget.calories))
        _proteinGrams = State(initialValue: String(target?.proteinGrams ?? MacroValues.defaultTarget.proteinGrams))
        _carbohydrateGrams = State(initialValue: String(target?.carbohydrateGrams ?? MacroValues.defaultTarget.carbohydrateGrams))
        _fatGrams = State(initialValue: String(target?.fatGrams ?? MacroValues.defaultTarget.fatGrams))
        _fiberGrams = State(initialValue: String(target?.fiberGrams ?? MacroValues.defaultTarget.fiberGrams))
    }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("Daily Targets") {
                    targetField("Calories", value: $calories, suffix: "kcal")
                    targetField("Protein", value: $proteinGrams, suffix: "g")
                    targetField("Carbohydrates", value: $carbohydrateGrams, suffix: "g")
                    targetField("Fat", value: $fatGrams, suffix: "g")
                    targetField("Fiber", value: $fiberGrams, suffix: "g")
                }
            }
            .trainingLogForm()
            .navigationTitle("Macro Targets")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .alert("Check Targets", isPresented: Binding(
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

    private func targetField(_ title: String, value: Binding<String>, suffix: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: value)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text(suffix)
                .foregroundStyle(TrainingLogTheme.secondaryText)
        }
    }

    private func save() {
        guard let calories = Int(calories),
              let proteinGrams = Int(proteinGrams),
              let carbohydrateGrams = Int(carbohydrateGrams),
              let fatGrams = Int(fatGrams),
              let fiberGrams = Int(fiberGrams),
              [calories, proteinGrams, carbohydrateGrams, fatGrams, fiberGrams].allSatisfy({ $0 >= 0 }) else {
            validationMessage = "Targets must be zero or positive whole numbers."
            return
        }

        let target = target ?? DailyMacroTarget()
        target.calories = calories
        target.proteinGrams = proteinGrams
        target.carbohydrateGrams = carbohydrateGrams
        target.fatGrams = fatGrams
        target.fiberGrams = fiberGrams
        if self.target == nil {
            modelContext.insert(target)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            validationMessage = error.localizedDescription
        }
    }
}

private struct MealEntryDraft {
    let date: Date
    let category: MealCategory
    let foodName: String
    let calories: Int
    let proteinGrams: Int
    let carbohydrateGrams: Int
    let fatGrams: Int
    let fiberGrams: Int
}

private struct NutritionReferenceView: View {
    @Query(sort: \DomainReference.sourceName) private var references: [DomainReference]

    private var eatingReferences: [DomainReference] {
        references.filter { $0.domain == .eating }
    }

    var body: some View {
        List {
            if eatingReferences.isEmpty {
                Text("No routine reference is available.")
                    .foregroundStyle(TrainingLogTheme.secondaryText)
            } else {
                ForEach(eatingReferences) { reference in
                    SwiftUI.Section(reference.sourceName) {
                        ReferenceTextRows(rowsJSON: reference.rowsJSON)
                    }
                }
            }
        }
        .trainingLogList()
        .listRowBackground(TrainingLogTheme.background)
        .navigationTitle("Nutrition Reference")
    }
}

private struct ReferenceTextRows: View {
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

private struct MacroValues {
    var calories: Int
    var proteinGrams: Int
    var carbohydrateGrams: Int
    var fatGrams: Int
    var fiberGrams: Int

    static let zero = MacroValues(calories: 0, proteinGrams: 0, carbohydrateGrams: 0, fatGrams: 0, fiberGrams: 0)
    static let defaultTarget = MacroValues(calories: 4_005, proteinGrams: 150, carbohydrateGrams: 525, fatGrams: 145, fiberGrams: 40)

    init(calories: Int, proteinGrams: Int, carbohydrateGrams: Int, fatGrams: Int, fiberGrams: Int) {
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
    }

    init(entry: MealEntry) {
        self.init(calories: entry.calories, proteinGrams: entry.proteinGrams, carbohydrateGrams: entry.carbohydrateGrams, fatGrams: entry.fatGrams, fiberGrams: entry.fiberGrams)
    }

    init(target: DailyMacroTarget) {
        self.init(calories: target.calories, proteinGrams: target.proteinGrams, carbohydrateGrams: target.carbohydrateGrams, fatGrams: target.fatGrams, fiberGrams: target.fiberGrams)
    }

    func adding(_ other: MacroValues) -> MacroValues {
        MacroValues(
            calories: saturatingAdd(calories, other.calories),
            proteinGrams: saturatingAdd(proteinGrams, other.proteinGrams),
            carbohydrateGrams: saturatingAdd(carbohydrateGrams, other.carbohydrateGrams),
            fatGrams: saturatingAdd(fatGrams, other.fatGrams),
            fiberGrams: saturatingAdd(fiberGrams, other.fiberGrams)
        )
    }

    private func saturatingAdd(_ lhs: Int, _ rhs: Int) -> Int {
        let result = lhs.addingReportingOverflow(rhs)
        if !result.overflow { return result.partialValue }
        return rhs >= 0 ? .max : .min
    }
}
