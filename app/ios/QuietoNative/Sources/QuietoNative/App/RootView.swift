import SwiftUI

struct RootView: View {
    let container: AppContainer
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var model: RootViewModel
    @ObservedObject private var home: HomeViewModel
    @ObservedObject private var onboarding: OnboardingViewModel
    /// Playback state for the mini player and the full-screen player sheet.
    @ObservedObject private var audioPlayer: QuietoAudioPlayer
    @ObservedObject private var journey: AchievementsViewModel
    /// Accessibility settings chosen in the profile.
    @ObservedObject private var profile: ProfileViewModel

    init(container: AppContainer) {
        self.container = container
        model = container.root
        home = container.home
        onboarding = container.onboarding
        audioPlayer = container.audioPlayer
        journey = container.journey
        profile = container.profile
    }

    var body: some View {
        Group {
            if onboarding.isCompleted {
                app
            } else {
                OnboardingView(model: onboarding)
                    #if DEBUG
                    .overlay(alignment: .topTrailing) { debugSkipOnboarding }
                    #endif
            }
        }
        // Rebuilt when the language changes in the profile, so no text keeps the old language.
        // Same for the gender: every text is agreed again.
        .id(QuietoLocalization.languageCode + (profile.language?.rawValue ?? "") + QuietoGender.current.rawValue)
        .environment(\.locale, QuietoLocalization.locale)
    }

    #if DEBUG
    /// Floats over the onboarding without moving anything: skips it entirely.
    private var debugSkipOnboarding: some View {
        Button(action: onboarding.skipForDebug) {
            Label("Skip", systemImage: "forward.end.fill")
                .labelStyle(.iconOnly)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 44, height: 44)
                .background(Color.orange, in: Circle())
                .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Debug · Passer l’onboarding")
        .padding(.top, 52)
        .padding(.trailing, 12)
    }
    #endif

    private var app: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            TabView(selection: $home.selectedTab) {
                HomeView(model: home, journey: journey).tag(QuietoTab.home).tabItem { Label("Accueil", systemImage: "house.fill") }
                ProgramView(model: container.program, sessionModel: container.sessions, audioPlayer: audioPlayer).tag(QuietoTab.programme).tabItem { Label("Programme", systemImage: "calendar") }
                SessionsView(model: container.sessions).tag(QuietoTab.sessions).tabItem { Label("Séances", systemImage: "headphones") }
                LouaneView(model: container.louane).environment(\.quietoMiniPlayerVisible, audioPlayer.currentSession != nil || audioPlayer.selectedAmbience != nil).tag(QuietoTab.louane).tabItem { Label("Louane", systemImage: "message") }
                ProfileView(model: container.profile, journey: journey, enterprise: container.enterpriseCode).tag(QuietoTab.profile).tabItem { Label("Profil", systemImage: "person") }
            }
            if audioPlayer.currentSession != nil { MiniPlayerView(player: audioPlayer) { audioPlayer.presentFullPlayer() }.padding(.bottom, 58) }
            else if audioPlayer.selectedAmbience != nil { AmbienceMiniPlayerView(player: audioPlayer).padding(.bottom, 58) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(QuietoColor.textPrimary)
        .background(QuietoBackground())
        .tint(QuietoColor.mint)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $audioPlayer.isAmbiencePlayerPresented) {
            AmbiencePlayerView(player: audioPlayer)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $audioPlayer.isFullPlayerPresented) {
            NowPlayingView(player: audioPlayer)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $journey.isPresented) {
            AchievementsView(model: journey)
                .presentationDragIndicator(.visible)
        }
        .badgeCelebrationOverlay { journey.present() }
        .environment(\.badgeCelebration, container.celebration)
        .overlay {
            if model.isLocked {
                HardPaywallView(model: container.paywall, profile: profile, enterprise: container.enterpriseCode)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: model.access)
        .onChange(of: scenePhase) { _, phase in model.scenePhaseChanged(phase) }
        // Breathing exercises play full screen, above any open sheet.
        .onChange(of: audioPlayer.breathingStarts) { _, _ in BreathingExercisePresenter.present(player: audioPlayer) }
        // A guided session heard to its end asks how the person feels.
        .onChange(of: audioPlayer.guidedCompletions) { _, _ in SessionFeedbackPresenter.present(player: audioPlayer) }
        .dynamicTypeSize(profile.largerText ? .xLarge ... .accessibility3 : .xSmall ... .accessibility5)
        .transaction { transaction in
            if profile.reduceMotion { transaction.animation = nil }
        }
    }
}

struct NativePlaceholderView: View {
    let tab: QuietoTab
    let message: String

    var body: some View {
        ZStack {
            QuietoBackground()
            VStack(spacing: QuietoSpacing.md) {
                Image(systemName: tab.systemImage).font(.system(size: 30, weight: .light)).foregroundStyle(QuietoColor.mint)
                Text(tab.rawValue.quietoLocalized).font(QuietoFont.heading(.display, weight: .semibold))
                Text(message.quietoLocalized).font(QuietoFont.sans(.body)).foregroundStyle(QuietoColor.textSecondary).multilineTextAlignment(.center).padding(.horizontal, 32)
            }
        }
    }
}
