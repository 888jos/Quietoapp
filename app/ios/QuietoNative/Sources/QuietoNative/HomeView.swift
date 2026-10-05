import SwiftUI

struct HomeView: View {
    @ObservedObject var model: HomeViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            QuietoColor.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: QuietoSpacing.lg) {
                    HomeHeader(firstName: model.snapshot.firstName)
                    content
                    // iOS 26's translucent tab bar floats over scroll content.
                    // Keep the last section fully readable above it.
                    Color.clear.frame(height: 128)
                }
                .frame(maxWidth: QuietoMetrics.contentMaxWidth)
                .padding(.horizontal, QuietoSpacing.md)
                .padding(.top, QuietoSpacing.sm)
            }
            .refreshable { await model.refresh() }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 92) }
        .overlay(alignment: .top) {
            if let lastAction = model.lastAction {
                Text(lastAction)
                    .font(QuietoFont.sans(13, weight: .medium))
                    .foregroundStyle(QuietoColor.background)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(QuietoColor.mint, in: Capsule())
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
            ErrorState(message: errorMessage) { Task { await model.refresh() } }
        } else {
            if model.snapshot.isOffline { OfflineBanner() }
            NextSessionCard(session: model.snapshot.nextSession) { session in model.play(session, source: "home_next") }
            if let program = model.snapshot.program {
                ProgramSummary(program: program, onOpen: model.openProgram, onAdjust: model.adjustRhythm)
            } else {
                EmptyProgramCard(onCreate: model.openLouane)
            }
            ExpressSection { session in model.play(session, source: "home_express") }
            CheckInSection(model: model)
            LouaneCard(onOpen: model.openLouane)
            if let recent = model.snapshot.progress.lastListened {
                RecentSessionCard(session: recent) { model.play(recent, source: "home_recent") }
            }
        }
    }
}

#Preview("Accueil — données de démonstration") {
    HomeView(model: HomeViewModel())
}

private struct HomeHeader: View {
    let firstName: String?

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Bonjour"
        case 12..<18: return "Bon après-midi"
        default: return "Bonsoir"
        }
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("quieto").font(QuietoFont.serif(28, weight: .bold)).foregroundStyle(QuietoColor.textPrimary)
                Text("\(greeting)\(firstName.map { " \($0)" } ?? "")")
                    .font(QuietoFont.sans(16)).foregroundStyle(QuietoColor.textSecondary)
                Text("Une prochaine étape claire.")
                    .font(QuietoFont.display).foregroundStyle(QuietoColor.textPrimary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button {} label: {
                Image(systemName: "bell").font(.system(size: 20, weight: .light)).foregroundStyle(QuietoColor.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Notifications")
        }
    }
}

private struct OfflineBanner: View {
    var body: some View {
        Label("Hors ligne · tes données locales restent disponibles", systemImage: "wifi.slash")
            .font(QuietoFont.sans(13, weight: .medium)).foregroundStyle(QuietoColor.textSecondary)
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
                Label("Accueil indisponible", systemImage: "moon.zzz").font(QuietoFont.sans(16, weight: .semibold))
                Text(message).font(QuietoFont.sans(14)).foregroundStyle(QuietoColor.textSecondary)
                QuietoOutlineButton(title: "Réessayer", systemImage: "arrow.clockwise", action: retry)
            }
        }
    }
}
