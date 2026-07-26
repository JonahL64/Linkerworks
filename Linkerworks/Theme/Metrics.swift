import SwiftUI

/// Spacing, shape and elevation constants. 4pt base grid.
///
/// Replaces the two ad-hoc constants the old theme carried (`contentInset: 16`,
/// `rowSpacing: 12`) and the inline `.padding(.vertical, 6/8/14)` scattered
/// through the views.
enum LWSpace {
    /// 4 — hairline gaps, icon-to-label in dense rows.
    static let xxs: CGFloat = 4
    /// 8 — within a tight cluster.
    static let xs: CGFloat = 8
    /// 12 — standard intra-row gap.
    static let sm: CGFloat = 12
    /// 16 — screen inset, standard block padding.
    static let md: CGFloat = 16
    /// 20 — generous block padding.
    static let lg: CGFloat = 20
    /// 28 — between major sections.
    static let xl: CGFloat = 28
    /// 40 — above a screen's first section, below its last.
    static let xxl: CGFloat = 40

    /// Horizontal inset from the screen edge.
    static let screenInset: CGFloat = 16

    /// Vertical padding inside a standard list row.
    static let rowVertical: CGFloat = 12

    /// Minimum height for a tappable row. Below 44 fails Apple's target guidance;
    /// the old checklist rows were routinely under this.
    static let minTapTarget: CGFloat = 44
}

enum LWRadius {
    /// 6 — chips, heatmap cells, small fills.
    static let sm: CGFloat = 6
    /// 10 — buttons, inputs.
    static let md: CGFloat = 10
    /// 14 — content blocks.
    static let lg: CGFloat = 14
    /// 20 — sheets, the Today hero.
    static let xl: CGFloat = 20
}

enum LWStroke {
    /// Hairline. Rendered at 1px on the device scale.
    static let hairline: CGFloat = 1
    /// Emphasis border (selected states).
    static let emphasis: CGFloat = 1.5
    /// Progress ring / bar thickness.
    static let ring: CGFloat = 10
}

/// Motion vocabulary. One place so timings stay coherent.
enum LWMotion {
    /// State flips: checking a task, toggling a filter.
    static let toggle = Animation.snappy(duration: 0.22, extraBounce: 0.05)
    /// Layout changes: expanding a phase, inserting a row.
    static let layout = Animation.smooth(duration: 0.3)
    /// Value changes: progress ring, counters.
    static let value = Animation.easeOut(duration: 0.45)
    /// Transient UI: toasts, banners.
    static let transient = Animation.spring(response: 0.36, dampingFraction: 0.82)
    /// The day-complete celebration.
    static let celebrate = Animation.spring(response: 0.55, dampingFraction: 0.6)
}

extension View {
    /// Standard raised content block: padded, rounded, on `surfaceRaised`.
    func lwBlock(padding: CGFloat = LWSpace.md, radius: CGFloat = LWRadius.lg) -> some View {
        self
            .padding(padding)
            .background(LWColor.surfaceRaised, in: RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(LWColor.hairline, lineWidth: LWStroke.hairline)
            )
    }
}
