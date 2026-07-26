import SwiftUI

/// Paper & Ink type scale.
///
/// Two voices, used consistently:
///
/// - **Serif** for display numerals and screen titles. This is the app's
///   identity; no third-party font is bundled, the system serif carries it.
/// - **System sans** for everything else, with monospaced digits reserved for
///   times and metrics so columns align.
///
/// Call sites should use these names rather than `.font(.caption)` etc. so the
/// scale stays adjustable from one place.
enum LWFont {
    // MARK: Display — large numerals (streak counts, progress percentage)

    static let displayLarge = Font.system(size: 52, weight: .medium, design: .serif)
    static let display = Font.system(size: 38, weight: .medium, design: .serif)
    static let displaySmall = Font.system(size: 26, weight: .medium, design: .serif)

    // MARK: Titles — screen and major section headings

    static let title = Font.system(size: 28, weight: .semibold, design: .serif)
    static let titleSmall = Font.system(size: 20, weight: .semibold, design: .serif)

    /// Section heading. Sentence case, normal tracking — deliberately *not* the
    /// tracked-out uppercase micro-label this app used to lean on.
    static let heading = Font.system(size: 15, weight: .semibold)

    // MARK: Body

    static let body = Font.system(size: 17)
    static let bodyMedium = Font.system(size: 17, weight: .medium)
    static let bodyStrong = Font.system(size: 17, weight: .semibold)

    /// Row detail text, secondary descriptions.
    static let callout = Font.system(size: 15)
    static let calloutMedium = Font.system(size: 15, weight: .medium)

    /// Metadata, counts, hints.
    static let caption = Font.system(size: 13)
    static let captionMedium = Font.system(size: 13, weight: .medium)

    /// Smallest supported size. Use sparingly.
    static let micro = Font.system(size: 11, weight: .medium)

    // MARK: Numerals

    /// Times and metrics. Always pair with `.monospacedDigit()` at the call site
    /// when the value updates in place.
    static let mono = Font.system(size: 15, design: .monospaced)
    static let monoSmall = Font.system(size: 13, design: .monospaced)
}

extension View {
    /// Screen-level section heading: sentence case, secondary ink.
    func lwSectionHeading() -> some View {
        font(LWFont.heading)
            .foregroundStyle(LWColor.inkSecondary)
    }

    /// Row detail / supporting copy.
    func lwDetail() -> some View {
        font(LWFont.callout)
            .foregroundStyle(LWColor.inkSecondary)
    }

    /// Metadata and hints.
    func lwCaption() -> some View {
        font(LWFont.caption)
            .foregroundStyle(LWColor.inkSecondary)
    }
}
