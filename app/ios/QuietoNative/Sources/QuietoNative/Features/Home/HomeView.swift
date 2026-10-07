import SwiftUI

struct HomeView: View {
    @ObservedObject var model: HomeViewModel
    /// Streak and badges; nil in previews.
    var journey: AchievementsViewModel?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            page.toolbar(.hidden, for: .navigationBar)
        }
        .tint(QuietoColor.mint)
    }

    private var page: some View {
        ZStack(alignment: .bottom) {
            QuietoBackground()
            // Vertical only: the carousels bleed past the margin, which let the
            // whole page slide sideways.
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: QuietoSpacing.xl) {
                    HomeHeader(firstName: model.snapshot.firstName, journey: journey)
                    content
                    #if DEBUG
                    if let replay = model.onReplayOnboarding {
                        Button(action: replay) {
                            Label("Debug · Revoir l’onboarding", systemImage: "ladybug")
                                .font(QuietoFont.sans(.callout, weight: .semibold))
                                .foregroundStyle(QuietoColor.background)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.orange, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    #endif
                    // iOS 26's translucent tab bar floats over scroll content.
                    // Keep the last section fully readable above it.
                    Color.clear.frame(height: 128)
                }
                .frame(maxWidth: QuietoMetrics.contentMaxWidth)
                .padding(.horizontal, QuietoSpacing.md)
                .padding(.top, QuietoSpacing.sm)
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.horizontal)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .refreshable { await model.refresh() }
            .task { await model.refresh() }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 92) }
        .overlay(alignment: .top) {
            if let lastAction = model.lastAction {
                Text(lastAction.quietoLocalized)
                    .font(QuietoFont.sans(.subhead, weight: .medium))
                    .foregroundStyle(QuietoColor.background)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(QuietoColor.mintFill, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { model.lastAction = nil }
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: model.lastAction)
        .accessibilityLabel("Accueil Quieto")
    }

    @ViewBuilder private var content: some View {
        if model.snapshot.isLoading {
            ProgressView().tint(QuietoColor.mint).frame(maxWidth: .infinity).padding(.vertical, 80)
        } else if let errorMessage = model.snapshot.errorMessage {
            ErrorState(message: errorMessage.quietoLocalized) { Task { await model.refresh() } }
        } else {
            if model.snapshot.isOffline { OfflineBanner() }
            TodayHero(
                session: model.snapshot.nextSession,
                program: model.snapshot.program,
                step: pair(model.snapshot.nextStep, model.snapshot.program?.totalDays),
                onPlay: { session in model.play(session, source: "home_next") },
                onOpenProgram: model.openProgram
            )
            if model.snapshot.program == nil { EmptyProgramCard(onCreate: model.openLouane) }
            AntiStressButton(model: model)
            ExpressCarousel { session in model.play(session, source: "home_express") }
            LouaneCard(onOpen: model.openLouane)
            if let recent = model.snapshot.progress.lastListened {
                RecentSessionCard(session: recent, listenedAt: model.snapshot.progress.lastListenedAt) { model.play(recent, source: "home_recent") }
            }
        }
    }
}

private func pair<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
    guard let a, let b else { return nil }
    return (a, b)
}

#Preview("Accueil — données de démonstration") {
    HomeView(model: HomeViewModel())
}

private struct HomeHeader: View {
    let firstName: String?
    let journey: AchievementsViewModel?

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch (hour, firstName) {
        case (5..<12, let name?): return QuietoLocalization.format("Bonjour %@", name)
        case (5..<12, nil): return "Bonjour".quietoLocalized
        case (12..<18, let name?): return QuietoLocalization.format("Bon après-midi %@", name)
        case (12..<18, nil): return "Bon après-midi".quietoLocalized
        case (_, let name?): return QuietoLocalization.format("Bonsoir %@", name)
        case (_, nil): return "Bonsoir".quietoLocalized
        }
    }

    /// "Mercredi 7 octobre": only the first letter is capitalised.
    private var today: String {
        let text = Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(QuietoLocalization.locale))
        return text.prefix(1).uppercased(with: QuietoLocalization.locale) + text.dropFirst()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(today)
                        .font(QuietoFont.sans(.subhead, weight: .medium)).foregroundStyle(QuietoColor.textSecondary)
                    Text(verbatim: greeting)
                        .font(QuietoFont.display).foregroundStyle(QuietoColor.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer()
                if let journey { HeaderStreak(journey: journey) }
            }
            .accessibilityElement(children: .contain)
            if let journey { WeekStrip(journey: journey) }
        }
    }
}

/// Observes the journey on its own so the header updates with the streak.
private struct HeaderStreak: View {
    @ObservedObject var journey: AchievementsViewModel
    var body: some View { StreakChip(streak: journey.streak) { journey.present() } }
}

private struct OfflineBanner: View {
    var body: some View {
        Label("Hors ligne · tes données locales restent disponibles", systemImage: "wifi.slash")
            .font(QuietoFont.sans(.subhead, weight: .medium)).foregroundStyle(QuietoColor.textSecondary)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(QuietoColor.surfaceRaised, in: Capsule())
    }
}

private struct ErrorState: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        QuietoCard {
            VStack(alignment: .leading, spacing: QuietoSpacing.sm) {
                Label("Accueil indisponible", systemImage: "moon.zzz").font(QuietoFont.sans(.body, weight: .semibold))
                Text(message.quietoLocalized).font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
                QuietoOutlineButton(title: "Réessayer", systemImage: "arrow.clockwise", action: retry)
            }
        }
    }
}
