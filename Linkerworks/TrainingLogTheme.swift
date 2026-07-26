import SwiftUI

enum TrainingLogTheme {
    static let background = Color("TrainingBackground")
    static let primaryText = Color("PrimaryText")
    static let secondaryText = Color("SecondaryText")
    static let completionAccent = Color("CompletionAccent")
    static let divider = primaryText.opacity(0.14)
    static let quietFill = primaryText.opacity(0.055)
    static let pressedFill = primaryText.opacity(0.10)
    static let destructive = Color(red: 0.90, green: 0.54, blue: 0.54)

    static let contentInset: CGFloat = 16
    static let rowSpacing: CGFloat = 12
}

struct TrainingLogFilterTabs: View {
    @Binding var selection: Bool
    let firstTitle: String
    let secondTitle: String

    var body: some View {
        HStack(spacing: 20) {
            tab(firstTitle, isSelected: !selection) { selection = false }
            tab(secondTitle, isSelected: selection) { selection = true }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(TrainingLogTheme.divider)
                .frame(height: 1)
        }
    }

    private func tab(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? TrainingLogTheme.primaryText : TrainingLogTheme.secondaryText)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(isSelected ? TrainingLogTheme.primaryText : .clear)
                        .frame(height: 2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension View {
    func trainingLogNavigation() -> some View {
        self
            .foregroundStyle(TrainingLogTheme.primaryText)
            .tint(TrainingLogTheme.primaryText)
            .preferredColorScheme(.dark)
            .toolbarBackground(TrainingLogTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarTitleDisplayMode(.large)
    }

    func trainingLogList() -> some View {
        self
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(TrainingLogTheme.background)
            .foregroundStyle(TrainingLogTheme.primaryText)
            .tint(TrainingLogTheme.primaryText)
            .listSectionSeparatorTint(TrainingLogTheme.divider)
            .listRowSeparatorTint(TrainingLogTheme.divider)
    }

    func trainingLogForm() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(TrainingLogTheme.background)
            .foregroundStyle(TrainingLogTheme.primaryText)
            .tint(TrainingLogTheme.primaryText)
            .listSectionSeparatorTint(TrainingLogTheme.divider)
    }

    func trainingLogRow() -> some View {
        self
            .padding(.vertical, 6)
            .contentShape(Rectangle())
    }

    func trainingLogSectionLabel() -> some View {
        self
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.9)
            .foregroundStyle(TrainingLogTheme.secondaryText)
    }
}
