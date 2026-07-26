import SwiftUI

struct SettingsView: View {
    @AppStorage("homeworkIntegrationEnabled") private var homeworkIntegrationEnabled = true

    var body: some View {
        List {
            SwiftUI.Section("Homework") {
                Toggle("Show homework", isOn: $homeworkIntegrationEnabled)
                Text("Turn this off during breaks or after graduation. Your courses and assignments stay saved, but homework is hidden from Today and Plan.")
                    .font(.footnote)
                    .foregroundStyle(TrainingLogTheme.secondaryText)
            }
        }
        .trainingLogList()
        .navigationTitle("Settings")
        .trainingLogNavigation()
    }
}
