import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: HomeViewModel
    @StateObject private var audioPlayer: QuietoAudioPlayer
    @ObservedObject private var subscriptions = QuietoSuperwallService.shared
    @ObservedObject private var backend = QuietoSupabaseService.shared
    @StateObject private var onboarding = OnboardingViewModel()

    init() {
        let player = QuietoAudioPlayer()
        let homeModel = HomeViewModel(services: .native(audioPlayer: player))
        #if DEBUG
        if let requestedTab = ProcessInfo.processInfo.environment["QUIETO_START_TAB"],
           let tab = QuietoTab.allCases.first(where: { $0.rawValue.lowercased() == requestedTab.lowercased() }) {
            homeModel.selectedTab = tab
        }
        #endif
        _audioPlayer = StateObject(wrappedValue: player)
        _model = StateObject(wrappedValue: homeModel)
    }

    var body: some View {
        if onboarding.isCompleted {
            app
        } else {
            OnboardingView(model: onboarding)
                .onAppear {
                    onboarding.setFinishHandler { session in
                        model.selectedTab = .home
                        if let session { audioPlayer.play(session, localURL: QuietoDownloadStore.shared.localURL(for: session)) }
                    }
                }
        }
    }

    private var app: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            TabView(selection: $model.selectedTab) {
                HomeView(model: model).tag(QuietoTab.home).tabItem { Label("Accueil", systemImage: "house.fill") }
                ProgramView(audioPlayer: audioPlayer).tag(QuietoTab.programme).tabItem { Label("Programme", systemImage: "calendar") }
                SessionsView(audioPlayer: audioPlayer).tag(QuietoTab.sessions).tabItem { Label("Séances", systemImage: "headphones") }
                LouaneView(audioPlayer: audioPlayer).tag(QuietoTab.louane).tabItem { Label("Louane", systemImage: "link") }
                ProfileView().tag(QuietoTab.profile).tabItem { Label("Profil", systemImage: "person") }
            }
            if audioPlayer.currentSession != nil { MiniPlayerView(player: audioPlayer) { audioPlayer.presentFullPlayer() }.padding(.bottom, 58) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(QuietoColor.textPrimary)
        .background(QuietoColor.background.ignoresSafeArea())
        .tint(QuietoColor.mint)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $audioPlayer.isFullPlayerPresented) {
            NowPlayingView(player: audioPlayer)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .overlay {
            // Hard paywall: nothing behind this is reachable without an entitlement.
            if subscriptions.access != .subscribed {
                HardPaywallView(subscriptions: subscriptions, backend: backend)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: subscriptions.access)
        .onChange(of: subscriptions.access) { _, access in
            if access == .locked { audioPlayer.stop(); audioPlayer.isFullPlayerPresented = false }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { audioPlayer.keepAudioSessionAlive() }
            // Renewals, refunds and expirations that happened while away.
            if phase == .active { subscriptions.syncWithServer() }
        }
    }
}

struct NativePlaceholderView: View {
    let tab: QuietoTab
    let message: String

    var body: some View {
        ZStack {
            QuietoColor.background.ignoresSafeArea()
            VStack(spacing: QuietoSpacing.md) {
                Image(systemName: tab.systemImage).font(.system(size: 30, weight: .light)).foregroundStyle(QuietoColor.mint)
                Text(tab.rawValue.quietoLocalized).font(QuietoFont.serif(32, weight: .semibold))
                Text(message.quietoLocalized).font(QuietoFont.sans(16)).foregroundStyle(QuietoColor.textSecondary).multilineTextAlignment(.center).padding(.horizontal, 32)
            }
        }
    }
}
