import SwiftUI

/// Session sheet: full-bleed artwork, title, one line of metadata, three quiet
/// actions and a floating play button. Everything else waits behind
/// « En savoir plus » so the screen invites a tap on play first.
struct SessionDetailView: View {
    let session: QuietoSession
    @ObservedObject var model: SessionsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var detailsExpanded = false
    @State private var transcriptExpanded = false
    @State private var showsAmbiences = false

    private let heroHeight: CGFloat = 430
    private var isCurrent: Bool { model.audioPlayer.currentSession?.id == session.id }
    private var isFavorite: Bool { model.favorites.contains(session.id) }

    private var minutes: Int {
        guard let pattern = session.breathingPattern, pattern.durationOptions.count > 1 else { return session.durationMinutes }
        return model.breathingMinutes[session.id] ?? pattern.durationOptions[0]
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            QuietoBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    VStack(alignment: .leading, spacing: QuietoSpacing.lg) {
                        Text(session.localizedIntention)
                            .font(QuietoFont.heading(.section, weight: .regular))
                            .foregroundStyle(QuietoColor.textPrimary.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                        actions
                        if session.readerMode == .guidedVoice, let value = model.downloads.progress[session.id], value < 1 {
                            HStack { ProgressView(value: value).tint(QuietoColor.mint); Button("Annuler") { model.downloads.cancel(session) } }
                                .font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                        }
                        if !isCurrent, let pattern = session.breathingPattern, pattern.durationOptions.count > 1 {
                            durationPicker(pattern)
                        }
                        if isCurrent { DetailPlayerControls(session: session, player: model.audioPlayer) }
                        details
                    }
                    .padding(.horizontal, QuietoSpacing.md)
                    .padding(.top, QuietoSpacing.md)
                    // Room for the floating play button.
                    .padding(.bottom, 120)
                    .frame(maxWidth: QuietoMetrics.contentMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
            .coordinateSpace(name: "detail")
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)

            closeButton
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingPlayButton(session: session, model: model, player: model.audioPlayer)
        }
        .sheet(isPresented: $showsAmbiences) {
            AmbiencePickerSheet(player: model.audioPlayer)
                .presentationDetents([.height(250)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(QuietoRadius.hero + 8)
                .presentationBackground { QuietoBackground(showsStars: false) }
        }
        .sensoryFeedback(.selection, trigger: isFavorite)
        .preferredColorScheme(.dark)
    }

    // MARK: Hero

    /// Artwork that stretches when pulled down, with the title set on its
    /// fading lower edge.
    private var hero: some View {
        GeometryReader { proxy in
            let minY = proxy.frame(in: .named("detail")).minY
            let pull = max(minY, 0)
            QuietoAssetImage(session.imageName, contentMode: .fill)
                .frame(width: proxy.size.width, height: heroHeight + pull)
                .clipped()
                .offset(y: -pull)
                .overlay {
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.25), location: 0),
                            .init(color: .clear, location: 0.25),
                            .init(color: QuietoColor.background.opacity(0.55), location: 0.68),
                            .init(color: QuietoColor.background, location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                    .offset(y: -pull)
                }
        }
        .frame(height: heroHeight)
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 8) {
                Text(session.title.quietoLocalized)
                    .font(QuietoFont.heading(.display, weight: .semibold))
                    .foregroundStyle(QuietoColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
                Text(verbatim: "\(QuietoLocalization.format("%d min", minutes)) · \(session.practiceType.rawValue.quietoLocalized)")
                    .font(QuietoFont.sans(.callout, weight: .medium))
                    .foregroundStyle(QuietoColor.textPrimary.opacity(0.75))
            }
            .padding(.horizontal, QuietoSpacing.md)
            .padding(.bottom, 4)
        }
        .accessibilityElement(children: .combine)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(QuietoColor.textPrimary)
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial, in: Circle())
                .frame(width: QuietoMetrics.minimumTapTarget, height: QuietoMetrics.minimumTapTarget)
        }
        .buttonStyle(QuietoPressStyle())
        .padding(.top, 14).padding(.trailing, 10)
        .accessibilityLabel("Fermer")
    }

    // MARK: Actions

    private var actions: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundAction(title: isFavorite ? "Dans les favoris" : "Favori", icon: isFavorite ? "heart.fill" : "heart", isActive: isFavorite, tint: QuietoColor.coral) {
                model.toggleFavorite(session)
            }
            RoundAction(title: "Ambiance", icon: "speaker.wave.2", isActive: model.audioPlayer.selectedAmbience != nil) {
                showsAmbiences = true
            }
            Menu {
                ForEach([5, 10, 20, 30, 45, 60], id: \.self) { minutes in
                    Button(QuietoLocalization.format("%d minutes", minutes)) { model.audioPlayer.setSleepTimer(minutes: minutes) }
                }
                Button("Désactiver") { model.audioPlayer.setSleepTimer(minutes: nil) }
            } label: {
                RoundActionLabel(
                    title: model.audioPlayer.timerRemaining.map { QuietoLocalization.format("Arrêt dans %d min", Int(ceil($0 / 60))) } ?? "Minuterie",
                    icon: "timer", isActive: model.audioPlayer.timerRemaining != nil
                )
            }
            .buttonStyle(QuietoPressStyle())
            if session.isDownloadAvailable {
                let downloaded = model.downloads.isDownloaded(session)
                RoundAction(title: downloaded ? "Supprimer" : "Télécharger", icon: downloaded ? "checkmark.circle" : "arrow.down", isActive: downloaded) {
                    model.toggleDownload(session)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func durationPicker(_ pattern: QuietoBreathingPattern) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Durée".quietoLocalized).font(QuietoFont.sans(.subhead, weight: .semibold)).foregroundStyle(QuietoColor.textSecondary)
            Picker("Durée", selection: Binding(
                get: { model.breathingMinutes[session.id] ?? pattern.durationOptions[0] },
                set: { model.breathingMinutes[session.id] = $0 }
            )) {
                ForEach(pattern.durationOptions.sorted(), id: \.self) { Text(QuietoLocalization.format("%d min", $0)).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Durée de l’exercice")
        }
    }

    // MARK: Details

    private var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().overlay(QuietoColor.divider)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { detailsExpanded.toggle() }
            } label: {
                HStack {
                    Text("En savoir plus".quietoLocalized).font(QuietoFont.sans(.body, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .rotationEffect(.degrees(detailsExpanded ? 180 : 0))
                }
                .foregroundStyle(QuietoColor.textPrimary)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)

            if detailsExpanded {
                VStack(alignment: .leading, spacing: QuietoSpacing.lg) {
                    Text(session.localizedLongDescription)
                        .font(QuietoFont.sans(.body)).foregroundStyle(QuietoColor.textSecondary).lineSpacing(5)
                    detailBlock("Avant de commencer") {
                        Text(session.localizedPreparation).font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary).lineSpacing(4)
                    }
                    detailBlock("Déroulé") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(session.localizedSteps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text(verbatim: "\(index + 1)").font(QuietoFont.sans(.caption, weight: .bold)).foregroundStyle(QuietoColor.mint)
                                        .frame(width: 24, height: 24).overlay(Circle().strokeBorder(QuietoColor.mint.opacity(0.5), lineWidth: 1))
                                    Text(step.quietoLocalized).font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    if session.readerMode == .guidedVoice {
                        DisclosureGroup(isExpanded: $transcriptExpanded) {
                            Text(session.localizedTranscript).font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary).lineSpacing(6).padding(.top, 12)
                        } label: {
                            Text("Transcription de la séance".quietoLocalized).font(QuietoFont.sans(.callout, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary)
                        }
                        .tint(QuietoColor.mint)
                    }
                }
                .padding(.bottom, QuietoSpacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Divider().overlay(QuietoColor.divider)
        }
    }

    private func detailBlock<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.quietoLocalized).quietoOverline().foregroundStyle(QuietoColor.textSecondary)
            content()
        }
    }
}

/// Circle icon with its caption, the secondary actions of the session sheet.
private struct RoundAction: View {
    let title: String
    let icon: String
    var isActive = false
    var tint: Color = QuietoColor.mint
    let action: () -> Void

    var body: some View {
        Button(action: action) { RoundActionLabel(title: title, icon: icon, isActive: isActive, tint: tint) }
            .buttonStyle(QuietoPressStyle())
    }
}

private struct RoundActionLabel: View {
    let title: String
    let icon: String
    var isActive = false
    var tint: Color = QuietoColor.mint

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isActive ? tint : QuietoColor.textPrimary)
                .frame(width: 50, height: 50)
                .background(isActive ? AnyShapeStyle(tint.opacity(0.14)) : AnyShapeStyle(QuietoColor.surface), in: Circle())
                .overlay(Circle().strokeBorder(isActive ? tint.opacity(0.45) : QuietoColor.divider, lineWidth: 1))
            Text(title.quietoLocalized)
                .font(QuietoFont.sans(.caption, weight: .medium))
                .foregroundStyle(isActive ? tint : QuietoColor.textSecondary)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// The play button floats above the content, with the sky fading in behind it
/// so the text slides under without a hard edge.
private struct FloatingPlayButton: View {
    let session: QuietoSession
    @ObservedObject var model: SessionsViewModel
    @ObservedObject var player: QuietoAudioPlayer

    private var isCurrent: Bool { player.currentSession?.id == session.id }

    var body: some View {
        Button {
            if isCurrent { player.toggle() } else { model.play(session) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isCurrent && player.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 16, weight: .semibold))
                Text(title.quietoLocalized).font(QuietoFont.sans(.body, weight: .semibold))
            }
            .foregroundStyle(QuietoColor.background)
            .frame(maxWidth: .infinity, minHeight: QuietoMetrics.controlHeight)
            .background(QuietoColor.mintFill, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
            .quietoGlow(radius: 18)
        }
        .buttonStyle(QuietoPressStyle())
        .sensoryFeedback(.impact(weight: .medium), trigger: player.isPlaying)
        .frame(maxWidth: QuietoMetrics.contentMaxWidth)
        .padding(.horizontal, QuietoSpacing.md)
        .padding(.top, 28)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(colors: [QuietoColor.backgroundDeep.opacity(0), QuietoColor.backgroundDeep.opacity(0.92)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var title: String {
        if isCurrent { return player.isPlaying ? "Mettre en pause" : "Reprendre" }
        return session.readerMode == .breathing ? "Commencer la respiration" : "Écouter la méditation"
    }
}

/// Ambience under the session, opened from its « Ambiance » action: the same
/// compact tiles as the Séances tab, an « Aucune » tile and the volume.
private struct AmbiencePickerSheet: View {
    @ObservedObject var player: QuietoAudioPlayer

    var body: some View {
        VStack(alignment: .leading, spacing: QuietoSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Ambiance".quietoLocalized).quietoSectionTitle()
                Spacer()
                if let ambience = player.selectedAmbience {
                    Label(ambience.title.quietoLocalized, systemImage: player.isAmbiencePlaying ? "speaker.wave.2.fill" : "pause.fill")
                        .font(QuietoFont.sans(.subhead, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                }
            }
            AmbienceRow(player: player, showsNoneTile: true)
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill").font(.system(size: 13))
                Slider(value: Binding(get: { player.ambienceVolume }, set: { player.ambienceVolume = $0 }), in: 0...0.7)
                Image(systemName: "speaker.wave.3.fill").font(.system(size: 13))
            }
            .foregroundStyle(QuietoColor.textSecondary).tint(QuietoColor.mint)
            .padding(.horizontal, 16)
            .frame(height: 48)
            .quietoSurface(cornerRadius: QuietoRadius.card)
            .disabled(player.selectedAmbience == nil)
            .opacity(player.selectedAmbience == nil ? 0.45 : 1)
            .accessibilityLabel("Volume de l’ambiance".quietoLocalized)
        }
        .padding(.horizontal, QuietoSpacing.md)
        .padding(.top, QuietoSpacing.lg)
        .foregroundStyle(QuietoColor.textPrimary)
        .animation(.easeInOut(duration: 0.2), value: player.selectedAmbience)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}


struct EmptyState: View { let title: String; let message: String; var body: some View { VStack(spacing: 8) { Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(QuietoColor.mint); Text(title.quietoLocalized).font(QuietoFont.heading(.section, weight: .semibold)); Text(message.quietoLocalized).font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(28).quietoSurface(cornerRadius: QuietoRadius.card) } }

/// Observes the player directly so the time and the play button follow playback.
private struct DetailPlayerControls: View {
    let session: QuietoSession
    @ObservedObject var player: QuietoAudioPlayer

    var body: some View {
        QuietoCard {
            VStack(spacing: 14) {
                if session.readerMode == .breathing {
                    BreathingVisual(session: session, player: player)
                }
                if player.isLoading, session.readerMode == .guidedVoice { ProgressView("Préparation de la méditation…").tint(QuietoColor.mint) }
                Slider(value: Binding(get: { player.position }, set: { player.seek(to: $0) }), in: 0...max(player.duration, 1)).tint(QuietoColor.mint)
                HStack {
                    Text(verbatim: format(player.position)); Spacer(); Text(verbatim: "−\(format(max(0, player.duration - player.position)))")
                }.font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
                // Play / pause is the floating button of the sheet.
                HStack(spacing: 56) {
                    Button { player.skip(by: -15) } label: { Image(systemName: "gobackward.15") }
                    Button { player.skip(by: 15) } label: { Image(systemName: "goforward.15") }
                }.font(.system(size: 22)).foregroundStyle(QuietoColor.textPrimary)
                Button("Ouvrir le lecteur") { player.presentFullPlayer() }
                    .font(QuietoFont.sans(.subhead, weight: .semibold)).foregroundStyle(QuietoColor.mint)
            }
        }
    }


    private func format(_ seconds: Double) -> String { String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60) }
}
