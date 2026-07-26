import SwiftUI

/// Compatibility surface over the Paper & Ink system in `Theme/`.
///
/// The names here predate the redesign and are still referenced widely. They now
/// resolve to `LWColor` / `LWSpace` tokens, so existing call sites pick up the
/// new palette without edits. New code should use `LWColor` and `LWSpace`
/// directly.
enum TrainingLogTheme {
    static let background = LWColor.surface
    static let primaryText = LWColor.ink
    static let secondaryText = LWColor.inkSecondary

    /// Historically the single green accent, used for both completion *and*
    /// interactive emphasis. It now means completion only — interactive
    /// emphasis is `LWColor.accent`.
    static let completionAccent = LWColor.success

    static let divider = LWColor.hairline
    static let quietFill = LWColor.surfaceSunken
    static let pressedFill = LWColor.surfacePressed
    static let destructive = LWColor.danger

    static let contentInset = LWSpace.screenInset
    static let rowSpacing = LWSpace.sm
}

/// Retained name; now a thin wrapper over `LWSegmentedTabs`.
struct TrainingLogFilterTabs: View {
    @Binding var selection: Bool
    let firstTitle: String
    let secondTitle: String

    var body: some View {
        LWSegmentedTabs(
            selection: $selection,
            firstTitle: firstTitle,
            secondTitle: secondTitle
        )
    }
}

extension View {
    /// Navigation chrome. No longer forces dark mode — the palette adapts, so
    /// the app follows the system appearance.
    func trainingLogNavigation() -> some View {
        self
            .foregroundStyle(LWColor.ink)
            .tint(LWColor.accent)
            .toolbarBackground(LWColor.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarTitleDisplayMode(.large)
    }

    func trainingLogList() -> some View {
        self
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(LWColor.surface)
            .foregroundStyle(LWColor.ink)
            .tint(LWColor.accent)
            .listSectionSeparatorTint(LWColor.hairline)
            .listRowSeparatorTint(LWColor.hairline)
    }

    func trainingLogForm() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(LWColor.surface)
            .foregroundStyle(LWColor.ink)
            .tint(LWColor.accent)
            .listSectionSeparatorTint(LWColor.hairline)
    }

    /// Standard row padding, with a real minimum tap target.
    func trainingLogRow() -> some View {
        self
            .padding(.vertical, LWSpace.xs)
            .frame(minHeight: LWSpace.minTapTarget, alignment: .leading)
            .contentShape(Rectangle())
    }

    /// Section label. Sentence case at readable size — the tracked-out uppercase
    /// micro-caps this used to render were the app's most obvious design tic.
    func trainingLogSectionLabel() -> some View {
        self
            .font(LWFont.heading)
            .foregroundStyle(LWColor.inkSecondary)
    }
}
