import SwiftUI
import UIKit

/// Paper & Ink colour system.
///
/// Warm neutrals rather than a near-black ground, a non-neon ink-blue accent,
/// and state colours (success / warning / danger) kept separate from the accent
/// so "complete" and "overdue" can never resolve to the same hue.
///
/// Every token adapts to light and dark. Tokens that the widget also needs live
/// in the asset catalogue (both targets carry a copy); the rest are defined here
/// as dynamic colours.
enum LWColor {
    // MARK: Ground and surfaces

    /// The page. Warm off-white in light, warm charcoal in dark.
    static let surface = Color("TrainingBackground")

    /// Raised content blocks — the grouping device that replaces hairline-only
    /// separation. Slightly lighter than the ground in dark, slightly whiter in light.
    static let surfaceRaised = dynamic(light: 0xFDFCFA, dark: 0x24231F)

    /// Recessed wells: input fields, empty heatmap cells, track behind progress.
    static let surfaceSunken = dynamic(light: 0xEFEBE3, dark: 0x131211)

    /// Pressed / highlighted row state.
    static let surfacePressed = dynamic(light: 0xE8E3D9, dark: 0x2E2C27)

    // MARK: Ink

    /// Primary text.
    static let ink = Color("PrimaryText")

    /// Supporting text: details, metadata, captions.
    static let inkSecondary = Color("SecondaryText")

    /// De-emphasised text: disabled, placeholder, future dates.
    static let inkTertiary = dynamic(light: 0x9A938A, dark: 0x6E6960)

    /// Text drawn on top of `accent`.
    static let onAccent = dynamic(light: 0xFFFFFF, dark: 0x12161E)

    // MARK: Lines

    /// Hairline between rows.
    static let hairline = dynamic(light: 0xDDD7CB, dark: 0x34322D)

    /// Heavier rule used to separate major blocks.
    static let separator = dynamic(light: 0xC9C2B4, dark: 0x45423B)

    // MARK: Accent and states

    /// Interactive / brand. Deep ink blue.
    static let accent = Color("AccentColor")

    /// Accent at low emphasis — chips, selected backgrounds, fills behind accent text.
    static let accentMuted = dynamic(light: 0xE4E9F2, dark: 0x27303F)

    /// Task and day completion. Desaturated green: reads as a *state*, not a brand.
    static let success = Color("CompletionAccent")

    /// Low-emphasis success fill (heatmap floor, completed row tint).
    static let successMuted = dynamic(light: 0xE3EDE5, dark: 0x222C25)

    /// Approaching / attention. Clay.
    static let warning = dynamic(light: 0xB5713A, dark: 0xD4915C)

    /// Overdue / destructive. Kept distinct from `warning` and from `success`.
    static let danger = dynamic(light: 0xA8443A, dark: 0xD9756A)

    /// Skipped and other deliberately-neutral states.
    static let neutral = dynamic(light: 0x8A8377, dark: 0x7D766B)

    // MARK: Domain tints
    //
    // The six Log domains. Muted, equal in weight, and distinguishable from the
    // accent so a domain colour never reads as an interactive affordance.

    static let domainSleep = dynamic(light: 0x4C5B87, dark: 0x8B99C4)
    static let domainEating = dynamic(light: 0x8A6A32, dark: 0xC5A063)
    static let domainGoalkeeping = dynamic(light: 0x3E7168, dark: 0x74AFA4)
    static let domainLifting = dynamic(light: 0x8C4B3C, dark: 0xC58374)
    static let domainPosture = dynamic(light: 0x6A5A8C, dark: 0xA495C4)
    static let domainGrooming = dynamic(light: 0x5C7A46, dark: 0x9BB582)
    static let domainCertifications = dynamic(light: 0x7A5230, dark: 0xBE9163)

    // MARK: Construction

    /// Builds a colour that resolves per appearance.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(rgb: dark)
                    : UIColor(rgb: light)
            }
        )
    }
}

extension UIColor {
    fileprivate convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
