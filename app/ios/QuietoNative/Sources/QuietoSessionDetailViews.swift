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
                            MetadataChip(text: session.practiceType.rawValue.quietoLocalized, icon: "waveform")
                            MetadataChip(text: session.pillar.rawValue.quietoLocalized, icon: session.pillar.symbol)
                        }
                    }

                    Text(session.localizedIntention).font(QuietoFont.serif(23)).fixedSize(horizontal: false, vertical: true)
                    Text(session.localizedLongDescription).font(QuietoFont.sans(16)).foregroundStyle(QuietoColor.textSecondary).lineSpacing(5)

                    HStack(spacing: 10) {
                        Button { model.toggleFavorite(session) } label: {
                            Label(model.favorites.contains(session.id) ? "Dans les favoris" : "Favori", systemImage: model.favorites.contains(session.id) ? "bookmark.fill" : "bookmark")
                        }
                        if session.isDownloadAvailable {
                            Button { model.toggleDownload(session) } label: {
                                Label(model.downloads.isDownloaded(session) ? "Supprimer" : "Télécharger", systemImage: model.downloads.isDownloaded(session) ? "trash" : "arrow.down.circle")
                            }
                        }
                    }
                    .font(QuietoFont.sans(13, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                    .buttonStyle(.bordered).buttonBorderShape(.capsule)

                    if session.readerMode == .guidedVoice && !session.isDownloadAvailable {
                        Label("Lecture disponible ; téléchargement hors ligne après publication du fichier audio.", systemImage: "icloud.slash")
                            .font(QuietoFont.sans(12)).foregroundStyle(QuietoColor.textSecondary)
                    }

                    if session.readerMode == .guidedVoice, let value = model.downloads.progress[session.id], value < 1 {
                        HStack { ProgressView(value: value).tint(QuietoColor.mint); Button("Annuler") { model.downloads.cancel(session) } }
                            .font(QuietoFont.sans(13)).foregroundStyle(QuietoColor.textSecondary)
                    }

                    if isCurrent { playerControls } else {
                        QuietoPrimaryButton(
                            title: session.readerMode == .breathing ? "Commencer la respiration" : "Écouter la méditation",
                            systemImage: "play.fill"
                        ) { model.play(session) }
                    }

                    detailSection(title: "Avant de commencer", icon: "figure.mind.and.body") {
                        Text(session.localizedPreparation).font(QuietoFont.sans(15)).foregroundStyle(QuietoColor.textSecondary).lineSpacing(4)
                    }
                    detailSection(title: "Déroulé", icon: "list.number") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(session.localizedSteps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)").font(QuietoFont.sans(12, weight: .bold)).foregroundStyle(QuietoColor.background)
                                        .frame(width: 24, height: 24).background(QuietoColor.mint, in: Circle())
                                    Text(step.quietoLocalized).font(QuietoFont.sans(15)).foregroundStyle(QuietoColor.textSecondary)
                                }
                            }
                        }
                    }

                    ambienceSection

                    if session.readerMode == .guidedVoice {
                        DisclosureGroup(isExpanded: $transcriptExpanded) {
                            Text(session.localizedTranscript).font(QuietoFont.sans(15)).foregroundStyle(QuietoColor.textSecondary).lineSpacing(6).padding(.top, 12)
                        } label: {
                            Label("Transcription de la séance", systemImage: "text.quote")
                                .font(QuietoFont.serif(21, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary)
                        }
                        .tint(QuietoColor.mint)
                    }

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
                if session.readerMode == .breathing {
                    BreathingVisual(session: session, player: model.audioPlayer).frame(height: 190)
                }
                if model.audioPlayer.isLoading, session.readerMode == .guidedVoice { ProgressView("Préparation de la méditation…").tint(QuietoColor.mint) }
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
                Button("Ouvrir le lecteur") { model.audioPlayer.presentFullPlayer() }
                    .font(QuietoFont.sans(13, weight: .semibold)).foregroundStyle(QuietoColor.mint)
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

struct LibraryView: View { let title: String; let sessions: [QuietoSession]; @ObservedObject var model: SessionsViewModel; var body: some View { NavigationStack { ZStack { QuietoColor.background.ignoresSafeArea(); ScrollView { VStack(alignment: .leading) { Text(title.quietoLocalized).font(QuietoFont.serif(32, weight: .semibold)); if sessions.isEmpty { EmptyState(title: "Rien ici pour l’instant", message: "Ta bibliothèque se remplira au fil de tes écoutes.") } else { ForEach(sessions) { session in SessionRow(session: session, isFavorite: model.favorites.contains(session.id), isDownloaded: model.downloads.isDownloaded(session), action: { model.selectedSession = session }, play: { model.play(session) }, favorite: { model.toggleFavorite(session) }) } } }.padding(QuietoSpacing.md) } }.navigationTitle(Text(title.quietoLocalized)).navigationBarTitleDisplayMode(.inline) } } }

struct MiniPlayerView: View {
    @ObservedObject var player: QuietoAudioPlayer
    let open: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Button(action: open) {
                HStack(spacing: 10) {
                    QuietoAssetImage(player.currentSession?.imageName ?? "RecentSession", contentMode: .fill).frame(width: 42, height: 42).clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(player.currentSession?.title ?? "").font(QuietoFont.sans(13, weight: .semibold)).lineLimit(1)
                        ProgressView(value: player.duration > 0 ? player.position / player.duration : 0).tint(QuietoColor.mint)
                    }
                }
            }.buttonStyle(.plain)
            Button { player.toggle() } label: { Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").foregroundStyle(QuietoColor.mint).frame(width: 34, height: 34) }
                .accessibilityLabel(player.isPlaying ? "Mettre en pause" : "Reprendre")
        }
        .padding(10).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(QuietoColor.divider) }
        .padding(.horizontal, 12).shadow(radius: 12)
    }
}

struct NowPlayingView: View {
    @ObservedObject var player: QuietoAudioPlayer
    private var session: QuietoSession? { player.currentSession }
    var body: some View {
        ZStack {
            QuietoColor.background.ignoresSafeArea()
            if let session {
                ScrollView {
                    VStack(spacing: 22) {
                        Capsule().fill(QuietoColor.textSecondary.opacity(0.55)).frame(width: 42, height: 5).padding(.top, 8)
                        QuietoAssetImage(session.imageName, contentMode: .fill).frame(maxWidth: 330).aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)).shadow(color: .black.opacity(0.25), radius: 22, y: 10)
                        VStack(spacing: 7) { Text(session.title.quietoLocalized).font(QuietoFont.serif(30, weight: .semibold)).multilineTextAlignment(.center); Text("Quieto · \(session.practiceType.rawValue.quietoLocalized)").font(QuietoFont.sans(14)).foregroundStyle(QuietoColor.textSecondary) }
                        if session.readerMode == .breathing { BreathingVisual(session: session, player: player).frame(height: 160) }
                        Slider(value: Binding(get: { player.position }, set: { player.seek(to: $0) }), in: 0...max(player.duration, 1)).tint(QuietoColor.mint)
                        HStack { Text(time(player.position)); Spacer(); Text("−\(time(max(0, player.duration - player.position)))") }.font(QuietoFont.sans(12)).foregroundStyle(QuietoColor.textSecondary)
                        HStack(spacing: 38) {
                            Button { player.skip(by: -15) } label: { Image(systemName: "gobackward.15") }
                            Button { player.toggle() } label: { Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 28, weight: .semibold)).foregroundStyle(QuietoColor.background).frame(width: 70, height: 70).background(QuietoColor.mint, in: Circle()) }
                            Button { player.skip(by: 15) } label: { Image(systemName: "goforward.15") }
                        }.font(.system(size: 25)).foregroundStyle(QuietoColor.textPrimary)
                        HStack(spacing: 12) {
                            Image(systemName: "timer")
                            Menu { ForEach([5, 10, 20, 30, 45, 60], id: \.self) { min in Button("\(min) min") { player.setSleepTimer(minutes: min) } }; Button("Désactiver") { player.setSleepTimer(minutes: nil) } } label: { Text(player.timerRemaining.map { "Arrêt dans \(Int(ceil($0 / 60))) min" } ?? "Minuterie") }
                        }.font(QuietoFont.sans(14, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                        if let ambience = player.selectedAmbience { Text("\("Ambiance".quietoLocalized) · \(ambience.title.quietoLocalized)").font(QuietoFont.sans(13)).foregroundStyle(QuietoColor.textSecondary) }
                        if session.readerMode == .guidedVoice {
                            Text(session.localizedTranscript).font(QuietoFont.sans(15)).foregroundStyle(QuietoColor.textSecondary).lineSpacing(5).frame(maxWidth: 560, alignment: .leading)
                        }
                    }.padding(.horizontal, 22).padding(.bottom, 38)
                }
            } else { EmptyState(title: "Aucune séance", message: "Choisis une séance pour commencer.") }
        }.preferredColorScheme(.dark)
    }
    private func time(_ seconds: Double) -> String { String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60) }
}

struct BreathingVisual: View {
    let session: QuietoSession
    @ObservedObject var player: QuietoAudioPlayer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var pattern: QuietoBreathingPattern { session.breathingPattern ?? .coherence }
    private var state: (label: String, progress: Double, cycleProgress: Double, cycle: Int) {
        let cycle = max(pattern.cycleDuration, 1)
        let elapsed = max(player.position, 0).truncatingRemainder(dividingBy: cycle)
        var cursor = 0.0
        for phase in pattern.phases {
            if elapsed < cursor + phase.seconds {
                return (phase.label, (elapsed - cursor) / phase.seconds, elapsed / cycle, Int(player.position / cycle) + 1)
            }
            cursor += phase.seconds
        }
        return (pattern.phases.last?.label ?? "Respire", 1, 1, Int(player.position / cycle) + 1)
    }
    var body: some View {
        VStack(spacing: 12) {
            Text(state.label.quietoLocalized)
                .font(QuietoFont.serif(27, weight: .semibold))
                .contentTransition(.numericText())
            GeometryReader { proxy in
                let inset: CGFloat = 16
                let markerPoint = point(at: state.cycleProgress, size: proxy.size, inset: inset)
                ZStack {
                    Canvas { context, size in
                        var guide = Path()
                        guide.move(to: point(at: 0, size: size, inset: inset))
                        for step in 1...160 {
                            guide.addLine(to: point(at: Double(step) / 160, size: size, inset: inset))
                        }
                        context.stroke(guide, with: .color(QuietoColor.mint.opacity(0.45)), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }
                    Circle()
                        .fill(QuietoColor.mint)
                        .frame(width: 18, height: 18)
                        .shadow(color: QuietoColor.mint.opacity(0.45), radius: reduceMotion ? 0 : 9)
                        .position(markerPoint)
                }
            }
            .frame(height: 105)
            Text("\("Cycle".quietoLocalized) \(state.cycle) · \((session.breathingPattern?.rawValue ?? "Respiration guidée").quietoLocalized)").font(QuietoFont.sans(12)).foregroundStyle(QuietoColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(state.label.quietoLocalized), \("Cycle".quietoLocalized) \(state.cycle)")
    }

    private func point(at progress: Double, size: CGSize, inset: CGFloat) -> CGPoint {
        let bounded = max(0, min(1, progress))
        let usableHeight = max(1, size.height - inset * 2)
        return CGPoint(
            x: inset + CGFloat(bounded) * max(1, size.width - inset * 2),
            y: inset + (1 - CGFloat(breathLevel(at: bounded))) * usableHeight
        )
    }

    /// Produces the inhale/hold/exhale profile: climb, plateau, descent, plateau.
    private func breathLevel(at cycleProgress: Double) -> Double {
        let targetTime = max(0, min(1, cycleProgress)) * pattern.cycleDuration
        var cursor = 0.0
        var level = pattern.phases.first?.label == "Expire" ? 1.0 : 0.0
        for phase in pattern.phases {
            let end = cursor + phase.seconds
            let target: Double
            switch phase.label {
            case "Inspire": target = 1
            case "Expire": target = 0
            default: target = level
            }
            if targetTime <= end {
                let local = phase.seconds > 0 ? (targetTime - cursor) / phase.seconds : 1
                let eased = 0.5 - cos(max(0, min(1, local)) * .pi) / 2
                return level + (target - level) * eased
            }
            level = target
            cursor = end
        }
        return level
    }
}

struct EmptyState: View { let title: String; let message: String; var body: some View { VStack(spacing: 8) { Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(QuietoColor.mint); Text(title.quietoLocalized).font(QuietoFont.serif(21, weight: .semibold)); Text(message.quietoLocalized).font(QuietoFont.sans(14)).foregroundStyle(QuietoColor.textSecondary).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(28).background(QuietoColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 14)) } }
