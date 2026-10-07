import SwiftUI

/// A badge as a round medal: filled when earned, a progress ring otherwise.
struct BadgeMedal: View {
    let state: BadgeState
    var size: CGFloat = 64

    private var isMystery: Bool { state.badge.isHidden && !state.isUnlocked }

    var body: some View {
        ZStack {
            Circle()
                .fill(state.isUnlocked
                      ? AnyShapeStyle(LinearGradient(colors: [QuietoColor.mint, QuietoColor.mint.opacity(0.62)], startPoint: .topLeading, endPoint: .bottomTrailing))
                      : AnyShapeStyle(QuietoColor.surfaceRaised))
            if !state.isUnlocked {
                Circle().stroke(QuietoColor.divider, lineWidth: 3)
                if !isMystery, state.fraction > 0 {
                    Circle()
                        .trim(from: 0, to: state.fraction)
                        .stroke(QuietoColor.mint.opacity(0.85), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
            }
            if isMystery {
                Image(systemName: "questionmark")
                    .font(.system(size: size * 0.38, weight: .medium))
                    .foregroundStyle(QuietoColor.textSecondary.opacity(0.7))
            } else if let artwork = badgeArtwork {
                Image(uiImage: artwork)
                    .resizable().scaledToFit()
                    .padding(size * 0.06)
                    .saturation(state.isUnlocked ? 1 : 0.18)
                    .opacity(state.isUnlocked ? 1 : 0.48)
            } else {
                Image(systemName: state.badge.symbol)
                    .font(.system(size: size * 0.38, weight: .medium))
                    .foregroundStyle(state.isUnlocked ? QuietoColor.background : QuietoColor.textSecondary.opacity(0.55))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var badgeArtwork: UIImage? {
        if let image = UIImage(named: state.badge.artworkName) { return image }
        let name = state.badge.artworkName as NSString
        guard let path = Bundle.main.path(forResource: name.deletingPathExtension, ofType: name.pathExtension) else { return nil }
        return UIImage(contentsOfFile: path)
    }
}

/// Compact streak indicator for the home header.
struct StreakChip: View {
    let streak: StreakStatus
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: streak.practicedToday ? "leaf.fill" : "leaf")
                    .font(.system(size: 14, weight: .semibold))
                Text(verbatim: "\(streak.current)")
                    .font(QuietoFont.sans(.callout, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(streak.practicedToday ? QuietoColor.background : QuietoColor.mint)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(streak.practicedToday ? AnyShapeStyle(QuietoColor.mint) : AnyShapeStyle(QuietoColor.surfaceRaised), in: Capsule())
            .overlay(Capsule().stroke(QuietoColor.mint.opacity(streak.practicedToday ? 0 : 0.45), lineWidth: 1))
            .frame(minHeight: QuietoMetrics.minimumTapTarget)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(QuietoLocalization.format("Série : %@", AchievementsViewModel.daysLabel(streak.current)))
        .accessibilityHint("Ouvre ton parcours".quietoLocalized)
    }
}

/// Profile card: latest badges, opening the full collection.
struct ProfileBadgesCard: View {
    @ObservedObject var journey: AchievementsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: QuietoSpacing.sm) {
            Text("Tes badges").quietoSectionTitle()
            Button { journey.present() } label: {
                QuietoCard {
                    HStack(spacing: 12) {
                        if journey.summary.recentlyUnlocked.isEmpty {
                            Image(systemName: "rosette").font(.system(size: 26, weight: .light)).foregroundStyle(QuietoColor.mint)
                            Text("Ta première pause débloque ton premier badge.").font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
                        } else {
                            HStack(spacing: -10) {
                                ForEach(journey.summary.recentlyUnlocked) { BadgeMedal(state: $0, size: 42).overlay(Circle().stroke(QuietoColor.surface, lineWidth: 2)) }
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(journey.collectionLabel).font(QuietoFont.sans(.callout, weight: .semibold))
                                Text(QuietoLocalization.format("Meilleure série : %@", AchievementsViewModel.daysLabel(journey.streak.best)))
                                    .font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

/// Discreet banner announcing a badge, at the top of the screen.
struct BadgeUnlockBanner: View {
    @ObservedObject var celebration: BadgeCelebrationViewModel
    var onOpen: (() -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let badge = celebration.current {
                Button {
                    celebration.dismiss()
                    onOpen?()
                } label: {
                    HStack(spacing: 12) {
                        BadgeMedal(state: BadgeState(badge: badge, unlockedAt: .now, current: 1, target: 1), size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Nouveau badge").quietoOverline().foregroundStyle(QuietoColor.mint)
                            Text(badge.title.quietoLocalized).font(QuietoFont.heading(.section, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: QuietoRadius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: QuietoRadius.card, style: .continuous).stroke(QuietoColor.mint.opacity(0.35)))
                    .shadow(color: .black.opacity(0.3), radius: 14, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, QuietoSpacing.md)
                .frame(maxWidth: QuietoMetrics.contentMaxWidth)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                .accessibilityLabel(QuietoLocalization.format("Nouveau badge : %@", badge.title.quietoLocalized))
                .id(badge.id)
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.85), value: celebration.current)
    }
}

private struct BadgeCelebrationKey: EnvironmentKey {
    static let defaultValue: BadgeCelebrationViewModel? = nil
}

extension EnvironmentValues {
    /// Set at the root; sheets inherit it so a badge earned behind a sheet is still seen.
    var badgeCelebration: BadgeCelebrationViewModel? {
        get { self[BadgeCelebrationKey.self] }
        set { self[BadgeCelebrationKey.self] = newValue }
    }
}

private struct BadgeCelebrationOverlay: ViewModifier {
    @Environment(\.badgeCelebration) private var celebration
    let topPadding: CGFloat
    let onOpen: (() -> Void)?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let celebration { BadgeUnlockBanner(celebration: celebration, onOpen: onOpen).padding(.top, topPadding) }
        }
    }
}

extension View {
    /// Shows newly unlocked badges on top of this screen.
    func badgeCelebrationOverlay(topPadding: CGFloat = 4, onOpen: (() -> Void)? = nil) -> some View {
        modifier(BadgeCelebrationOverlay(topPadding: topPadding, onOpen: onOpen))
    }
}
