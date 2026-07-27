import Charts
import Foundation
import SwiftData
import SwiftUI

struct WeightView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.date) private var weightEntries: [WeightEntry]

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var isPresentingEditor = false
    @State private var entryToEdit: WeightEntry?
    @State private var entryToDelete: WeightEntry?
    @State private var saveErrorMessage: String?

    private let calendar = Calendar.current

    private var orderedEntries: [WeightEntry] {
        WeightEntrySupport.ordered(weightEntries)
    }

    private var selectedEntry: WeightEntry? {
        WeightEntrySupport.entry(on: selectedDate, from: weightEntries, calendar: calendar)
    }

    var body: some View {
        List {
            entrySection
            chartSection
            historySection
        }
        .trainingLogList()
        .listRowBackground(LWColor.surface)
        .navigationTitle("Weight")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    entryToEdit = selectedEntry
                    isPresentingEditor = true
                } label: {
                    Label(selectedEntry == nil ? "Add Weight" : "Edit Weight", systemImage: selectedEntry == nil ? "plus" : "pencil")
                }
            }
        }
        .sheet(isPresented: $isPresentingEditor, onDismiss: { entryToEdit = nil }) {
            WeightEntryEditorView(
                entry: entryToEdit,
                selectedDate: selectedDate,
                onSaved: saveEntry
            )
        }
        .confirmationDialog(
            "Delete weight entry?",
            isPresented: Binding(
                get: { entryToDelete != nil },
                set: { if !$0 { entryToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let entryToDelete {
                    delete(entryToDelete)
                }
                entryToDelete = nil
            }
        } message: {
            Text("This removes the recorded weight for that day.")
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

    private var entrySection: some View {
        SwiftUI.Section("Daily weigh-in") {
            DatePicker("Day", selection: $selectedDate, displayedComponents: .date)

            Button {
                entryToEdit = selectedEntry
                isPresentingEditor = true
            } label: {
                HStack(spacing: LWSpace.sm) {
                    Image(systemName: "scalemass")
                        .foregroundStyle(LWColor.accent)
                        .frame(width: LWSpace.minTapTarget, height: LWSpace.minTapTarget)
                        .background(LWColor.accentMuted, in: RoundedRectangle(cornerRadius: LWRadius.md))

                    VStack(alignment: .leading, spacing: LWSpace.xxs) {
                        Text(selectedEntry == nil ? "Add weight" : "Recorded weight")
                            .font(LWFont.bodyStrong)
                            .foregroundStyle(LWColor.ink)
                        Text(selectedEntry.map { weightText($0.pounds) } ?? "No weight recorded")
                            .font(LWFont.callout)
                            .monospacedDigit()
                            .foregroundStyle(LWColor.inkSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(LWFont.captionMedium)
                        .foregroundStyle(LWColor.inkTertiary)
                }
                .trainingLogRow()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selectedEntry == nil ? "Add weight for selected day" : "Edit weight for selected day")
            .accessibilityValue(selectedEntry.map { weightText($0.pounds) } ?? "No weight recorded")
        }
    }

    @ViewBuilder
    private var chartSection: some View {
        SwiftUI.Section("Trend") {
            switch orderedEntries.count {
            case 0:
                LWEmptyState(
                    title: "No weight history yet",
                    message: "Add a daily weigh-in to begin your history.",
                    systemImage: "chart.xyaxis.line"
                )
                .listRowBackground(LWColor.surface)
            case 1:
                VStack(alignment: .leading, spacing: LWSpace.sm) {
                    LWStatBlock(label: "Latest", value: weightNumber(orderedEntries[0].pounds), unit: "lb", tint: LWColor.accent)
                    WeightTrendChart(entries: orderedEntries, calendar: calendar)
                    Text("Log one more day to see your trend. Your recorded weight is shown without estimating any missing days.")
                        .font(LWFont.callout)
                        .foregroundStyle(LWColor.inkSecondary)
                }
                .lwBlock()
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Weight history")
                .accessibilityValue("One entry, \(weightText(orderedEntries[0].pounds))")
                .listRowBackground(LWColor.surface)
            default:
                WeightTrendChart(entries: orderedEntries, calendar: calendar)
                    .listRowBackground(LWColor.surface)
            }
        }
    }

    private var historySection: some View {
        SwiftUI.Section("History") {
            if orderedEntries.isEmpty {
                Text("Your recorded weigh-ins will appear here.")
                    .font(LWFont.callout)
                    .foregroundStyle(LWColor.inkSecondary)
            } else {
                ForEach(orderedEntries.reversed()) { entry in
                    Button {
                        entryToEdit = entry
                        isPresentingEditor = true
                    } label: {
                        HStack(spacing: LWSpace.sm) {
                            VStack(alignment: .leading, spacing: LWSpace.xxs) {
                                Text(WeightEntrySupport.displayDate(for: entry, calendar: calendar).formatted(date: .abbreviated, time: .omitted))
                                    .font(LWFont.bodyMedium)
                                    .foregroundStyle(LWColor.ink)
                                Text("Tap to edit")
                                    .font(LWFont.caption)
                                    .foregroundStyle(LWColor.inkSecondary)
                            }
                            Spacer()
                            Text(weightText(entry.pounds))
                                .font(LWFont.mono)
                                .monospacedDigit()
                                .foregroundStyle(LWColor.ink)
                        }
                        .trainingLogRow()
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            entryToDelete = entry
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .accessibilityLabel("\(WeightEntrySupport.displayDate(for: entry, calendar: calendar).formatted(date: .long, time: .omitted)), \(weightText(entry.pounds))")
                    .accessibilityHint("Double tap to edit. Swipe up or down for delete.")
                }
            }
        }
    }

    private func saveEntry(_ entry: WeightEntry?, _ draft: WeightEntryDraft) -> Bool {
        let normalizedDate = calendar.startOfDay(for: draft.date)
        let dayKey = WeightEntrySupport.dayKey(for: draft.date, calendar: calendar)
        let sameDayEntries = WeightEntrySupport.entries(on: normalizedDate, from: weightEntries, calendar: calendar)
        let existing = sameDayEntries.first

        if let existing {
            existing.date = normalizedDate
            existing.dayKey = dayKey
            existing.pounds = draft.pounds
            let sourceID = entry?.id
            for duplicate in sameDayEntries where duplicate.id != existing.id && duplicate.id != sourceID {
                modelContext.delete(duplicate)
            }
            if let entry, entry.id != existing.id {
                modelContext.delete(entry)
            }
        } else if let entry {
            entry.date = normalizedDate
            entry.dayKey = dayKey
            entry.pounds = draft.pounds
        } else {
            modelContext.insert(WeightEntry(date: normalizedDate, pounds: draft.pounds, calendar: calendar))
        }

        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            saveErrorMessage = error.localizedDescription
            return false
        }
    }

    private func delete(_ entry: WeightEntry) {
        modelContext.delete(entry)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            saveErrorMessage = error.localizedDescription
        }
    }
}

private struct WeightTrendChart: View {
    let entries: [WeightEntry]
    let calendar: Calendar

    var body: some View {
        Chart(entries) { entry in
            if entries.count > 1 {
                LineMark(
                    x: .value("Day", WeightEntrySupport.displayDate(for: entry, calendar: calendar)),
                    y: .value("Weight", entry.pounds)
                )
                .foregroundStyle(LWColor.accent)
                .lineStyle(StrokeStyle(lineWidth: LWStroke.emphasis, lineCap: .round, lineJoin: .round))
            }

            PointMark(
                x: .value("Day", WeightEntrySupport.displayDate(for: entry, calendar: calendar)),
                y: .value("Weight", entry.pounds)
            )
            .foregroundStyle(LWColor.accent)
            .symbolSize(LWSpace.chartPointArea)
        }
        .chartYAxisLabel("Pounds", alignment: .leading)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: LWStroke.hairline))
                    .foregroundStyle(LWColor.hairline)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(LWFont.micro)
                    .foregroundStyle(LWColor.inkSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: LWStroke.hairline))
                    .foregroundStyle(LWColor.hairline)
                AxisValueLabel()
                    .font(LWFont.micro)
                    .foregroundStyle(LWColor.inkSecondary)
            }
        }
        .frame(height: LWSpace.chartHeight)
        .padding(LWSpace.md)
        .background(LWColor.surfaceRaised, in: RoundedRectangle(cornerRadius: LWRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: LWRadius.lg)
                .stroke(LWColor.hairline, lineWidth: LWStroke.hairline)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entries.count > 1 ? "Weight trend" : "Weight history")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(entries.count > 1
            ? "The chart connects only recorded daily weigh-ins in chronological order."
            : "One recorded weigh-in. Add another day to see a trend.")
    }

    private var accessibilityValue: String {
        entries.map {
            "\(WeightEntrySupport.displayDate(for: $0, calendar: calendar).formatted(date: .abbreviated, time: .omitted)), \(weightText($0.pounds))"
        }.joined(separator: "; ")
    }
}

@MainActor
private struct WeightEntryEditorView: View {
    let entry: WeightEntry?
    let selectedDate: Date
    let onSaved: (WeightEntry?, WeightEntryDraft) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var pounds: String
    @State private var validationMessage: String?

    init(
        entry: WeightEntry?,
        selectedDate: Date,
        onSaved: @escaping (WeightEntry?, WeightEntryDraft) -> Bool
    ) {
        self.entry = entry
        self.selectedDate = selectedDate
        self.onSaved = onSaved
        _date = State(initialValue: entry?.date ?? selectedDate)
        _pounds = State(initialValue: entry.map { editableWeightNumber($0.pounds) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("Weigh-in") {
                    DatePicker("Day", selection: $date, displayedComponents: .date)
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("0.0", text: $pounds)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: LWSpace.numericFieldWidth)
                        Text("lb")
                            .foregroundStyle(LWColor.inkSecondary)
                    }
                }
            }
            .trainingLogForm()
            .navigationTitle(entry == nil ? "Add Weight" : "Edit Weight")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .alert("Check Weight", isPresented: Binding(
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
        guard let pounds = parsedWeight(pounds), pounds.isFinite, pounds > 0 else {
            validationMessage = "Enter a positive weight in pounds."
            return
        }

        if onSaved(entry, WeightEntryDraft(date: date, pounds: pounds)) {
            dismiss()
        } else {
            validationMessage = "The weight could not be saved. Try again."
        }
    }
}

private struct WeightEntryDraft {
    let date: Date
    let pounds: Double
}

private func weightNumber(_ pounds: Double) -> String {
    pounds.formatted(.number.precision(.fractionLength(0...1)))
}

private func editableWeightNumber(_ pounds: Double) -> String {
    pounds.formatted(.number.precision(.fractionLength(0...16)))
}

private func parsedWeight(_ input: String) -> Double? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = .current
    guard let number = formatter.number(from: trimmed) else { return nil }
    return number.doubleValue
}

private func weightText(_ pounds: Double) -> String {
    "\(weightNumber(pounds)) lb"
}
