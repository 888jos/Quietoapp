import SwiftUI

struct SessionDetailView: View {
    let session: QuietoSession
    @ObservedObject var model: SessionsViewModel
    @State private var transcriptExpanded = false

    private var isCurrent: Bool { model.audioPlayer.currentSession?.id == session.id }

    var body: some View {
        ZStack {
            QuietoColor.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: QuietoSpacing.lg) {
                    QuietoAssetImage(session.imageName, contentMode: .fill)
                        .frame(maxWidth: .infinity).frame(height: 250).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.title.quietoLocalized).font(QuietoFont.serif(34, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            MetadataChip(text: "\(session.durationMinutes) min", icon: "clock")
                            MetadataChip(text: session.practiceType.rawValue, icon: "waveform")
                            MetadataChip(text: session.pillar.rawValue, icon: session.pillar.symbol)
                        }
                    }

                    Text(session.intention.quietoLocalized).font(QuietoFont.serif(23)).fixedSize(horizontal: false, vertical: true)
                    Text(session.longDescription.quietoLocalized).font(QuietoFont.sans(16)).foregroundStyle(QuietoColor.textSecondary).lineSpacing(5)

                    HStack(spacing: 10) {
                        Button { model.toggleFavorite(session) } label: {
                            Label(model.favorites.contains(session.id) ? "Dans les favoris" : "Favori", systemImage: model.favorites.contains(session.id) ? "bookmark.fill" : "bookmark")
                        }
                        Button { model.toggleDownload(session) } label: {
                            Label(model.downloads.isDownloaded(session) ? "Supprimer" : "Télécharger", systemImage: model.downloads.isDownloaded(session) ? "trash" : "arrow.down.circle")
                        }
                    }
                    .font(QuietoFont.sans(13, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                    .buttonStyle(.bordered).buttonBorderShape(.capsule)

                    if let value = model.downloads.progress[session.id], value < 1 {
                        HStack { ProgressView(value: value).tint(QuietoColor.mint); Button("Annuler") { model.downloads.cancel(session) } }
                            .font(QuietoFont.sans(13)).foregroundStyle(QuietoColor.textSecondary)
                    }

                    if isCurrent { playerControls } else {
                        QuietoPrimaryButton(title: "Écouter avec la voix Apple", systemImage: "play.fill") { model.play(session) }
                    }

                    detailSection(title: "Avant de commencer", icon: "figure.mind.and.body") {
                        Text(session.preparation.quietoLocalized).font(QuietoFont.sans(15)).foregroundStyle(QuietoColor.textSecondary).lineSpacing(4)
                    }
                    detailSection(title: "Déroulé", icon: "list.number") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(session.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)").font(QuietoFont.sans(12, weight: .bold)).foregroundStyle(QuietoColor.background)
                                        .frame(width: 24, height: 24).background(QuietoColor.mint, in: Circle())
                                    Text(step.quietoLocalized).font(QuietoFont.sans(15)).foregroundStyle(QuietoColor.textSecondary)
                                }
                            }
                        }
                    }

                    ambienceSection

                    DisclosureGroup(isExpanded: $transcriptExpanded) {
                        Text(session.transcript).font(QuietoFont.sans(15)).foregroundStyle(QuietoColor.textSecondary).lineSpacing(6).padding(.top, 12)
                    } label: {
                        Label("Transcription de la séance", systemImage: "text.quote")
                            .font(QuietoFont.serif(21, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary)
                    }
                    .tint(QuietoColor.mint)

                    timerMenu
                }
                .frame(maxWidth: QuietoMetrics.contentMaxWidth)
                .padding(QuietoSpacing.md).padding(.bottom, 44)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var playerControls: some View {
        QuietoCard {
            VStack(spacing: 14) {
                if model.audioPlayer.isLoading { ProgressView("Préparation de la voix Apple…").tint(QuietoColor.mint) }
                Slider(value: Binding(get: { model.audioPlayer.position }, set: { model.audioPlayer.seek(to: $0) }), in: 0...max(model.audioPlayer.duration, 1)).tint(QuietoColor.mint)
                HStack {
                    Text(format(model.audioPlayer.position)); Spacer(); Text("−\(format(max(0, model.audioPlayer.duration - model.audioPlayer.position)))")
                }.font(QuietoFont.sans(12)).foregroundStyle(QuietoColor.textSecondary)
                HStack(spacing: 30) {
                    Button { model.audioPlayer.skip(by: -15) } label: { Image(systemName: "gobackward.15") }
                    Button { model.audioPlayer.toggle() } label: {
                        Image(systemName: model.audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 21, weight: .semibold)).foregroundStyle(QuietoColor.background)
                            .frame(width: 54, height: 54).background(QuietoColor.mint, in: Circle())
                    }
                    Button { model.audioPlayer.skip(by: 15) } label: { Image(systemName: "goforward.15") }
                }.font(.system(size: 22)).foregroundStyle(QuietoColor.textPrimary)
            }
        }
    }

    private var ambienceSection: some View {
        detailSection(title: "Ajouter une ambiance", icon: "speaker.wave.2") {
            Text("Les boucles sont originales, embarquées dans l’app et fonctionnent hors ligne.")
                .font(QuietoFont.sans(13)).foregroundStyle(QuietoColor.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(QuietoAmbience.all) { ambience in
                        Button { model.audioPlayer.selectedAmbience == ambience ? model.audioPlayer.stopAmbience() : model.audioPlayer.playAmbience(ambience) } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                QuietoAssetImage(ambience.assetName, contentMode: .fill).frame(width: 108, height: 82).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
                                Text(ambience.title.quietoLocalized).font(QuietoFont.sans(13, weight: .semibold)).lineLimit(1)
                                Text(ambience.subtitle.quietoLocalized).font(QuietoFont.sans(11)).foregroundStyle(QuietoColor.textSecondary).lineLimit(1)
                            }.frame(width: 108, alignment: .leading)
                        }.buttonStyle(.plain).overlay(alignment: .topTrailing) {
                            if model.audioPlayer.selectedAmbience == ambience { Image(systemName: "speaker.wave.2.fill").font(.caption).foregroundStyle(QuietoColor.background).padding(7).background(QuietoColor.mint, in: Circle()).padding(5) }
                        }
                    }
                }
            }
            if model.audioPlayer.selectedAmbience != nil {
                HStack {
                    Image(systemName: "speaker.fill")
                    Slider(value: Binding(get: { model.audioPlayer.ambienceVolume }, set: { model.audioPlayer.ambienceVolume = $0 }), in: 0...0.7)
                    Image(systemName: "speaker.wave.3.fill")
                }
                    .foregroundStyle(QuietoColor.textSecondary).tint(QuietoColor.mint)
            }
        }
    }

    private var timerMenu: some View {
        Menu {
            ForEach([5, 10, 20, 30, 45, 60], id: \.self) { minutes in Button("\(minutes) minutes") { model.audioPlayer.setSleepTimer(minutes: minutes) } }
            Button("Désactiver") { model.audioPlayer.setSleepTimer(minutes: nil) }
        } label: {
            Label(model.audioPlayer.timerRemaining.map { "Arrêt dans \(Int(ceil($0 / 60))) min" } ?? "Programmer l’arrêt", systemImage: "timer")
                .font(QuietoFont.sans(15, weight: .semibold)).foregroundStyle(QuietoColor.mint)
        }
    }

    private func detailSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        QuietoCard { VStack(alignment: .leading, spacing: 12) { Label(title, systemImage: icon).font(QuietoFont.serif(21, weight: .semibold)); content() } }
    }

    private func format(_ seconds: Double) -> String { String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60) }
}

private struct MetadataChip: View {
    let text: String
    let icon: String
    var body: some View { Label(text, systemImage: icon).font(QuietoFont.sans(12, weight: .medium)).foregroundStyle(QuietoColor.textSecondary).padding(.horizontal, 10).padding(.vertical, 7).background(QuietoColor.surface, in: Capsule()) }
}

struct LibraryView: View { let title: String; let sessions: [QuietoSession]; @ObservedObject var model: SessionsViewModel; var body: some View { NavigationStack { ZStack { QuietoColor.background.ignoresSafeArea(); ScrollView { VStack(alignment: .leading) { Text(title).font(QuietoFont.serif(32, weight: .semibold)); if sessions.isEmpty { EmptyState(title: "Rien ici pour l’instant", message: "Ta bibliothèque se remplira au fil de tes écoutes.") } else { ForEach(sessions) { session in SessionRow(session: session, isFavorite: model.favorites.contains(session.id), isDownloaded: model.downloads.isDownloaded(session), action: { model.selectedSession = session }, play: { model.play(session) }, favorite: { model.toggleFavorite(session) }) } } }.padding(QuietoSpacing.md) } }.navigationTitle(title).navigationBarTitleDisplayMode(.inline) } } }

struct MiniPlayerView: View { @ObservedObject var player: QuietoAudioPlayer; var body: some View { HStack(spacing: 10) { QuietoAssetImage(player.currentSession?.imageName ?? "RecentSession", contentMode: .fill).frame(width: 42, height: 42).clipShape(RoundedRectangle(cornerRadius: 8)); VStack(alignment: .leading) { Text(player.currentSession?.title ?? "").font(QuietoFont.sans(13, weight: .semibold)).lineLimit(1); ProgressView(value: player.duration > 0 ? player.position / player.duration : 0).tint(QuietoColor.mint) }; Button { player.toggle() } label: { Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").foregroundStyle(QuietoColor.mint) } }.padding(10).background(QuietoColor.surface, in: RoundedRectangle(cornerRadius: 14)).overlay { RoundedRectangle(cornerRadius: 14).stroke(QuietoColor.divider) }.padding(.horizontal, 12).shadow(radius: 12) } }

struct EmptyState: View { let title: String; let message: String; var body: some View { VStack(spacing: 8) { Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(QuietoColor.mint); Text(title).font(QuietoFont.serif(21, weight: .semibold)); Text(message).font(QuietoFont.sans(14)).foregroundStyle(QuietoColor.textSecondary).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(28).background(QuietoColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 14)) } }
