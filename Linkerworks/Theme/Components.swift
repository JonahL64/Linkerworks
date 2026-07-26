import SwiftUI

// MARK: - Task state

/// Presentational state for a checklist row. Kept separate from the data layer
/// so the row component has no SwiftData dependency.
enum LWTaskState {
    case pending
    case complete
    case skipped
    /// A parent whose children drive its completion — not directly tappable.
    case parentIncomplete
    case parentComplete

    var isComplete: Bool {
        self == .complete || self == .parentComplete
    }

    var isParent: Bool {
        self == .parentIncomplete || self == .parentComplete
    }
}

// MARK: - Check control

/// The completion affordance. Replaces the stock `checkmark.circle.fill` SF
/// symbol with a drawn mark that carries the app's completion animation.
struct LWCheckControl: View {
    let state: LWTaskState
    var size: CGFloat = 24

    private var ringColor: Color {
        switch state {
        case .complete, .parentComplete: return LWColor.success
        case .skipped: return LWColor.neutral
        case .pending, .parentIncomplete: return LWColor.separator
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(state.isComplete ? LWColor.success : Color.clear)

            Circle()
                .strokeBorder(ringColor, lineWidth: state.isComplete ? 0 : LWStroke.emphasis)

            switch state {
            case .complete, .parentComplete:
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.46, weight: .bold))
                    .foregroundStyle(LWColor.surface)
                    .transition(.scale.combined(with: .opacity))
            case .skipped:
                Rectangle()
                    .fill(LWColor.neutral)
                    .frame(width: size * 0.42, height: LWStroke.emphasis)
            case .pending, .parentIncomplete:
                EmptyView()
            }
        }
        .frame(width: size, height: size)
        .animation(LWMotion.toggle, value: state)
    }
}

// MARK: - Progress

/// Ring used for the Today hero. Serif numeral inside, sunken track behind.
struct LWProgressRing: View {
    let progress: Double
    var size: CGFloat = 96
    var isPulsing: Bool = false
    var showsLabel: Bool = true

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(LWColor.surfaceSunken, lineWidth: LWStroke.ring)

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    clamped >= 1 ? LWColor.success : LWColor.accent,
                    style: StrokeStyle(lineWidth: LWStroke.ring, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if showsLabel {
                Text(clamped, format: .percent.precision(.fractionLength(0)))
                    .font(size >= 80 ? LWFont.displaySmall : LWFont.titleSmall)
                    .monospacedDigit()
                    .foregroundStyle(LWColor.ink)
                    .contentTransition(.numericText())
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(isPulsing ? 1.06 : 1)
        .animation(LWMotion.celebrate, value: isPulsing)
        .animation(LWMotion.value, value: clamped)
    }
}

/// Slim horizontal progress. For phase headers and inline summaries.
struct LWProgressBar: View {
    let progress: Double
    var tint: Color = LWColor.accent
    var height: CGFloat = 4

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(LWColor.surfaceSunken)
                Capsule()
                    .fill(clamped >= 1 ? LWColor.success : tint)
                    .frame(width: geo.size.width * clamped)
            }
        }
        .frame(height: height)
        .animation(LWMotion.value, value: clamped)
        .accessibilityHidden(true)
    }
}

// MARK: - Stat block

/// A single large metric. Serif numeral, label beneath.
struct LWStatBlock: View {
    let label: String
    let value: String
    var unit: String?
    var tint: Color = LWColor.ink

    var body: some View {
        VStack(alignment: .leading, spacing: LWSpace.xxs) {
            Text(label)
                .font(LWFont.caption)
                .foregroundStyle(LWColor.inkSecondary)

            HStack(alignment: .firstTextBaseline, spacing: LWSpace.xxs) {
                Text(value)
                    .font(LWFont.display)
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())

                if let unit {
                    Text(unit)
                        .font(LWFont.callout)
                        .foregroundStyle(LWColor.inkSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(unit.map { "\(value) \($0)" } ?? value)
    }
}

// MARK: - Heatmap cell

/// One day in the completion heatmap. Uses a stepped ramp rather than a linear
/// opacity fade, which used to render low values as indistinguishable mud.
struct LWHeatCell: View {
    let day: Int
    let percentage: Double
    let hasSchedule: Bool
    let isFuture: Bool
    let isToday: Bool

    private var fill: Color {
        guard !isFuture else { return .clear }
        guard hasSchedule else { return LWColor.surfaceSunken }
        switch percentage {
        case ..<0.01: return LWColor.surfaceSunken
        case ..<0.34: return LWColor.successMuted
        case ..<0.67: return LWColor.success.opacity(0.45)
        case ..<1.0: return LWColor.success.opacity(0.72)
        default: return LWColor.success
        }
    }

    private var textColor: Color {
        if isFuture { return LWColor.inkTertiary }
        if hasSchedule, percentage >= 0.67 { return LWColor.surface }
        return LWColor.inkSecondary
    }

    var body: some View {
        RoundedRectangle(cornerRadius: LWRadius.sm)
            .fill(fill)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if isFuture {
                    RoundedRectangle(cornerRadius: LWRadius.sm)
                        .strokeBorder(LWColor.hairline, lineWidth: LWStroke.hairline)
                }
                if isToday {
                    RoundedRectangle(cornerRadius: LWRadius.sm)
                        .strokeBorder(LWColor.accent, lineWidth: LWStroke.emphasis)
                }
            }
            .overlay {
                Text("\(day)")
                    .font(LWFont.micro)
                    .monospacedDigit()
                    .foregroundStyle(textColor)
            }
    }
}

// MARK: - Chip

/// Small labelled pill. Used for counts, domains, courses.
struct LWChip: View {
    let text: String
    var tint: Color = LWColor.inkSecondary
    var fill: Color = LWColor.surfaceSunken

    var body: some View {
        Text(text)
            .font(LWFont.micro)
            .foregroundStyle(tint)
            .padding(.horizontal, LWSpace.xs)
            .padding(.vertical, LWSpace.xxs)
            .background(fill, in: Capsule())
    }
}

// MARK: - Tabs

/// Two-way filter control. Replaces `TrainingLogFilterTabs`.
struct LWSegmentedTabs: View {
    @Binding var selection: Bool
    let firstTitle: String
    let secondTitle: String

    var body: some View {
        HStack(spacing: LWSpace.xxs) {
            tab(firstTitle, isSelected: !selection) { selection = false }
            tab(secondTitle, isSelected: selection) { selection = true }
        }
        .padding(LWSpace.xxs)
        .background(LWColor.surfaceSunken, in: Capsule())
    }

    private func tab(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(LWFont.calloutMedium)
                .foregroundStyle(isSelected ? LWColor.ink : LWColor.inkSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, LWSpace.xs)
                .background {
                    if isSelected {
                        Capsule().fill(LWColor.surfaceRaised)
                    }
                }
        }
        .buttonStyle(.plain)
        .animation(LWMotion.toggle, value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Empty state

struct LWEmptyState: View {
    let title: String
    var message: String?
    var systemImage: String = "tray"

    var body: some View {
        VStack(spacing: LWSpace.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(LWColor.inkTertiary)

            Text(title)
                .font(LWFont.titleSmall)
                .foregroundStyle(LWColor.ink)
                .multilineTextAlignment(.center)

            if let message {
                Text(message)
                    .font(LWFont.callout)
                    .foregroundStyle(LWColor.inkSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(LWSpace.xl)
    }
}

// MARK: - Toast

/// Transient confirmation with an optional action (undo).
struct LWToast: View {
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: LWSpace.sm) {
            Text(message)
                .font(LWFont.calloutMedium)
                .foregroundStyle(LWColor.ink)

            Spacer(minLength: LWSpace.xs)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(LWFont.calloutMedium)
                    .foregroundStyle(LWColor.accent)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, LWSpace.md)
        .padding(.vertical, LWSpace.sm)
        .background(LWColor.surfaceRaised, in: Capsule())
        .overlay(Capsule().stroke(LWColor.hairline, lineWidth: LWStroke.hairline))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}

// MARK: - Banner

/// Persistent inline banner — active workout, sync notice.
struct LWBanner: View {
    let title: String
    var subtitle: String?
    var tint: Color = LWColor.accent
    var systemImage: String?

    var body: some View {
        HStack(spacing: LWSpace.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(LWFont.calloutMedium)
                    .foregroundStyle(LWColor.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(LWFont.caption)
                        .foregroundStyle(LWColor.inkSecondary)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: LWSpace.xs)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LWColor.inkTertiary)
        }
        .padding(.horizontal, LWSpace.md)
        .padding(.vertical, LWSpace.sm)
        .background(LWColor.surfaceRaised, in: RoundedRectangle(cornerRadius: LWRadius.md))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(tint)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: LWRadius.md))
        }
        .overlay(
            RoundedRectangle(cornerRadius: LWRadius.md)
                .stroke(LWColor.hairline, lineWidth: LWStroke.hairline)
        )
    }
}

// MARK: - Section container

/// A titled group of content sitting on a raised surface. The grouping device
/// that replaces hairline-only separation, without becoming a card dashboard.
struct LWSection<Content: View>: View {
    let title: String?
    var accessory: AnyView?
    @ViewBuilder var content: Content

    init(
        _ title: String? = nil,
        accessory: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.accessory = accessory
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LWSpace.xs) {
            if title != nil || accessory != nil {
                HStack(alignment: .firstTextBaseline) {
                    if let title {
                        Text(title).lwSectionHeading()
                    }
                    Spacer(minLength: LWSpace.xs)
                    if let accessory {
                        accessory
                    }
                }
                .padding(.horizontal, LWSpace.xxs)
            }

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LWColor.surfaceRaised, in: RoundedRectangle(cornerRadius: LWRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: LWRadius.lg)
                    .stroke(LWColor.hairline, lineWidth: LWStroke.hairline)
            )
        }
    }
}

/// Hairline divider for use between rows inside an `LWSection`.
struct LWRowDivider: View {
    var inset: CGFloat = LWSpace.md

    var body: some View {
        Rectangle()
            .fill(LWColor.hairline)
            .frame(height: LWStroke.hairline)
            .padding(.leading, inset)
    }
}
