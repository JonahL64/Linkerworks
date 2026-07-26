import SwiftUI

struct SettingsView: View {
    @AppStorage("homeworkIntegrationEnabled") private var homeworkIntegrationEnabled = true

    @State private var labels = Dictionary(uniqueKeysWithValues: RoutineDayPhase.allCases.map {
        ($0, RoutinePhasePreferences.label(for: $0))
    })
    @State private var starts = Dictionary(uniqueKeysWithValues: RoutineDayPhase.allCases.map {
        ($0, RoutinePhasePreferences.startGuidance(for: $0) ?? "")
    })
    @State private var phaseSaveError: String?

    var body: some View {
        List {
            SwiftUI.Section("Routine day phases") {
                Text("These are personal cues, not due times. Routine tasks never become overdue.")
                    .font(LWFont.caption)
                    .foregroundStyle(TrainingLogTheme.secondaryText)

                ForEach(RoutineDayPhase.allCases) { phase in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(phase.defaultLabel, text: binding(for: phase, in: $labels))
                        if phase != .anytime {
                            TextField(
                                "Starts at",
                                text: binding(for: phase, in: $starts),
                                prompt: Text(RoutinePhasePreferences.defaultStartGuidance(for: phase) ?? "")
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        }
                    }
                    .padding(.vertical, 3)
                }

                Button("Save routine phases") { saveRoutinePhases() }
                    .font(LWFont.calloutMedium)
                    .foregroundStyle(LWColor.accent)
            }

            SwiftUI.Section("Homework") {
                Toggle("Show homework", isOn: $homeworkIntegrationEnabled)
                Text("Turn this off during breaks or after graduation. Your courses and assignments stay saved, but homework is hidden from Today and Plan.")
                    .font(LWFont.caption)
                    .foregroundStyle(TrainingLogTheme.secondaryText)
            }
        }
        .trainingLogList()
        .navigationTitle("Settings")
        .trainingLogNavigation()
        .alert("Could Not Save Routine Phases", isPresented: Binding(
            get: { phaseSaveError != nil },
            set: { if !$0 { phaseSaveError = nil } }
        )) {
            Button("OK", role: .cancel) { phaseSaveError = nil }
        } message: {
            Text(phaseSaveError ?? "")
        }
    }

    private func binding(
        for phase: RoutineDayPhase,
        in dictionary: Binding<[RoutineDayPhase: String]>
    ) -> Binding<String> {
        Binding(
            get: { dictionary.wrappedValue[phase] ?? "" },
            set: { dictionary.wrappedValue[phase] = $0 }
        )
    }

    private func saveRoutinePhases() {
        let cleanedLabels = labels.mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard cleanedLabels.values.allSatisfy({ !$0.isEmpty }) else {
            phaseSaveError = "Each day phase needs a name."
            return
        }
        guard Set(cleanedLabels.values.map { $0.lowercased() }).count == cleanedLabels.count else {
            phaseSaveError = "Day phase names must be different."
            return
        }

        let ordered = [RoutineDayPhase.morning, .midday, .afternoon, .evening]
        let cleanedStarts = starts.mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let minuteValues = ordered.map { phase -> Int? in
            let value = cleanedStarts[phase] ?? ""
            if phase == .morning && (value.isEmpty || value.caseInsensitiveCompare("wake") == .orderedSame) {
                return 0
            }
            return clockMinutes(value)
        }
        guard !minuteValues.contains(where: { $0 == nil }) else {
            phaseSaveError = "Use ascending 24-hour start times (for example 11:30, 14:30, 18:00). Morning may be Wake."
            return
        }
        let minutes = minuteValues.compactMap { $0 }
        guard zip(minutes, minutes.dropFirst()).allSatisfy({ $0 < $1 }) else {
            phaseSaveError = "Use ascending 24-hour start times (for example 11:30, 14:30, 18:00). Morning may be Wake."
            return
        }

        let defaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier) ?? .standard
        for phase in RoutineDayPhase.allCases {
            defaults.set(cleanedLabels[phase], forKey: RoutinePhasePreferences.labelKey(for: phase))
            if phase != .anytime {
                defaults.set(cleanedStarts[phase], forKey: RoutinePhasePreferences.startKey(for: phase))
            }
        }
        labels = cleanedLabels
        starts = cleanedStarts
    }

    private func clockMinutes(_ value: String) -> Int? {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return hour * 60 + minute
    }
}
