import SwiftUI

struct ProgramView: View {
    @ObservedObject var model: ProgramViewModel
    /// Shared with the Séances tab so favourites and downloads stay in sync.
    @ObservedObject var sessionModel: SessionsViewModel
    /// Playback state only (which row shows "pause").
    @ObservedObject var audioPlayer: QuietoAudioPlayer
    @State private var selectedSession: QuietoSession?
    @State private var showingRhythm = false
    @State private var situation: QuietoSituation?

    var body: some View {
        NavigationStack {
            ZStack {
                QuietoBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: QuietoSpacing.lg) {
                        header
                        if model.isLoading && model.sessions.isEmpty {
                            ProgressView("Chargement du programme…".quietoLocalized).tint(QuietoColor.mint).frame(maxWidth: .infinity).padding(.vertical, 80)
                        } else if !model.hasProgram {
                            emptyProgram
                        } else {
                            if let error = model.loadError {
                                Label(error.quietoLocalized, systemImage: "wifi.slash").font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                            }
                            progressCard
                        }
                        separator
                        situations
                        if model.hasProgram, !model.sessions.isEmpty {
                            separator
                            sessionsList
                            rhythmCard
                        }
                        Color.clear.frame(height: 128)
                    }
                    .frame(maxWidth: QuietoMetrics.contentMaxWidth)
                    .padding(.horizontal, QuietoSpacing.md)
                    .padding(.top, QuietoSpacing.sm)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 92) }
            .navigationBarHidden(true)
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session, model: sessionModel)
            }
            .navigationDestination(item: $situation) { situation in
                SessionListPage(title: situation.rawValue, subtitle: situation.subtitle, sessions: sessionModel.sessions(for: situation), sessionModel: sessionModel)
            }
            .confirmationDialog("Adapter mon rythme", isPresented: $showingRhythm, titleVisibility: .visible) {
                ForEach(ProgramViewModel.ProgramRhythm.allCases) { rhythm in
                    Button(QuietoLocalization.format("%@ · %@", rhythm.localizedName, rhythm.localizedDetail)) { model.saveRhythm(rhythm) }
                }
                Button("Annuler", role: .cancel) {}
            }
            .overlay(alignment: .top) {
                if let feedback = model.feedback {
                    Text(feedback.quietoLocalized)
                        .font(QuietoFont.sans(.subhead, weight: .medium))
                        .foregroundStyle(QuietoColor.background)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(QuietoColor.mintFill, in: Capsule())
                        .padding(.top, 8)
                        .onTapGesture { model.feedback = nil }
                }
            }
            .task { await model.load() }
        }
    }

    private var emptyProgram: some View {
        QuietoCard {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "map").font(.system(size: 28)).foregroundStyle(QuietoColor.mint)
                Text("Commencer un parcours").font(QuietoFont.heading(.title, weight: .semibold))
                Text("Sept étapes alternent méditation, respiration et relaxation. Tu pourras changer le rythme à tout moment.")
                    .font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
                QuietoPrimaryButton(title: "Créer mon programme", systemImage: "plus") {
                    Task { await model.createProgram() }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Programme").font(QuietoFont.heading(.display, weight: .semibold))
                .lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 8)
        }
        .padding(.top, 6)
    }

    private var separator: some View {
        Rectangle().fill(QuietoColor.divider).frame(height: 1)
    }

    /// What the person is going through, each card opening its sessions.
    private var situations: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ce que tu ressens").font(QuietoFont.section)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(QuietoSituation.featured) { item in
                        SituationCard(situation: item, count: sessionModel.sessions(for: item).count) { situation = item }
                    }
                }
                .padding(.trailing, QuietoSpacing.md)
            }
            .padding(.trailing, -QuietoSpacing.md)
        }
    }

    private var progressCard: some View {
        QuietoCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.title.quietoLocalized).font(QuietoFont.heading(.section, weight: .semibold))
                        Text(QuietoLocalization.format("%d séances terminées sur %d", model.completedCount, model.sessions.count))
                            .font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                    }
                    Spacer()
                    Text(verbatim: (Double(model.completedCount) / Double(max(model.sessions.count, 1))).formatted(.percent.precision(.fractionLength(0)).locale(QuietoLocalization.locale)))
                        .font(QuietoFont.sans(.callout, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                }
                ProgressView(value: Double(model.completedCount), total: Double(max(model.sessions.count, 1)))
                    .tint(QuietoColor.mint)
                if let next = model.nextSession {
                    QuietoPrimaryButton(title: QuietoLocalization.format("Continuer · %d min", next.durationMinutes), systemImage: "play.fill") { play(next) }
                } else {
                    Label("Programme terminé", systemImage: "checkmark.seal.fill")
                        .font(QuietoFont.sans(.callout, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                }
            }
        }
    }

    private var sessionsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Les étapes de ton parcours").font(QuietoFont.section)
            ForEach(Array(model.sessions.enumerated()), id: \.element.id) { index, session in
                Button { selectedSession = session } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(model.completedIDs.contains(session.id) ? QuietoColor.mint : QuietoColor.surfaceRaised)
                            if model.completedIDs.contains(session.id) {
                                Image(systemName: "checkmark").foregroundStyle(QuietoColor.background)
                            } else {
                                Text(verbatim: "\(index + 1)").foregroundStyle(QuietoColor.textPrimary)
                            }
                        }
                        .font(.system(size: 13, weight: .semibold)).frame(width: 34, height: 34)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.title.quietoLocalized).font(QuietoFont.heading(.card, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary)
                            Text(QuietoLocalization.format("%d min · %@", session.durationMinutes, session.practiceType.rawValue.quietoLocalized))
                                .font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
                        }
                        Spacer()
                        Button { play(session) } label: {
                            Image(systemName: audioPlayer.currentSession?.id == session.id && audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(QuietoColor.background)
                                .frame(width: QuietoMetrics.playSmall, height: QuietoMetrics.playSmall).background(QuietoColor.mintFill, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(QuietoLocalization.format("Lire %@", session.title.quietoLocalized))
                    }
                    .padding(13)
                    .quietoSurface(cornerRadius: QuietoMetrics.cornerRadius)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var rhythmCard: some View {
        Button { showingRhythm = true } label: {
            QuietoCard {
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3").foregroundStyle(QuietoColor.mint).frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Adapter mon rythme").font(QuietoFont.sans(.callout, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary)
                        Text(QuietoLocalization.format("%@ · %@", model.rhythm.localizedName, model.rhythm.localizedDetail)).font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(QuietoColor.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func play(_ session: QuietoSession) {
        sessionModel.play(session)
    }
}
