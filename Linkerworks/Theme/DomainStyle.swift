import SwiftUI

/// Visual identity for the Log domains.
///
/// Previously every domain rendered as an identical navigation row, which made
/// the Log tab a wall of undifferentiated text. Each domain now carries a tint
/// and a symbol so it is recognisable at a glance.
extension Domain {
    var tint: Color {
        switch self {
        case .sleep: LWColor.domainSleep
        case .eating: LWColor.domainEating
        case .goalkeeping: LWColor.domainGoalkeeping
        case .lifting: LWColor.domainLifting
        case .posture: LWColor.domainPosture
        case .grooming: LWColor.domainGrooming
        case .certifications: LWColor.domainCertifications
        }
    }

    /// One-line description of what the domain records.
    var blurb: String {
        switch self {
        case .sleep: "Bed and wake times, consistency"
        case .eating: "Meals, macros, and daily totals"
        case .goalkeeping: "Sessions, drills, and reference"
        case .lifting: "Workouts, sets, and reference"
        case .posture: "Mobility, stretching, and cues"
        case .grooming: "Routine upkeep"
        case .certifications: "Progress toward each certification"
        }
    }
}

/// Circular domain badge. The tint appears as a soft disc behind the symbol so
/// it reads as identity rather than as an interactive control.
struct LWDomainBadge: View {
    let domain: Domain
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            Circle()
                .fill(domain.tint.opacity(0.14))
            Image(systemName: domain.symbolName)
                .font(.system(size: size * 0.44, weight: .medium))
                .foregroundStyle(domain.tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
