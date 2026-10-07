import SwiftUI

/// The current week under the greeting: a check for each day with a practice,
/// a cross for a day without, today circled, the days to come left empty.
struct WeekStrip: View {
    @ObservedObject var journey: AchievementsViewModel

    var body: some View {
        Button { journey.present() } label: {
            HStack(spacing: 0) {
                ForEach(journey.weekStatuses) { day in
                    VStack(spacing: 6) {
                        WeekDayDot(day: day)
                        Text(day.letter)
                            .font(QuietoFont.sans(.caption, weight: day.isToday ? .bold : .medium))
                            .foregroundStyle(day.isToday ? QuietoColor.textPrimary : QuietoColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel(day))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Ouvre ta série et ton calendrier")
    }

    private func accessibilityLabel(_ day: WeekDayStatus) -> String {
        let name = day.date.formatted(.dateTime.weekday(.wide).locale(QuietoLocalization.locale))
        let state: String = switch day.state {
        case .done: "pause faite"
        case .missed: "pas de pause"
        case .today: "aujourd’hui, pas encore de pause"
        case .upcoming: "à venir"
        }
        return QuietoLocalization.format("%@, %@", name, state.quietoLocalized)
    }
}

private struct WeekDayDot: View {
    let day: WeekDayStatus
    private let size: CGFloat = 34

    var body: some View {
        ZStack {
            switch day.state {
            case .done:
                Circle().fill(QuietoColor.mint)
                Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(QuietoColor.background)
            case .missed:
                Circle().fill(QuietoColor.surface)
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(QuietoColor.textSecondary.opacity(0.7))
            case .today:
                Circle().fill(QuietoColor.surface)
                Circle().stroke(QuietoColor.mint, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
            case .upcoming:
                Circle().stroke(QuietoColor.divider, lineWidth: 1.5)
            }
            if day.isToday && day.state == .done {
                Circle().stroke(QuietoColor.textPrimary, lineWidth: 2).padding(-4)
            }
        }
        .frame(width: size, height: size)
    }
}
