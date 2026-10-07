import SwiftUI

/// Title row shared by the home sections, with an optional trailing link.
struct HomeSectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.quietoLocalized).quietoSectionTitle()
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle.quietoLocalized)
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                    }
                }
                .font(QuietoFont.sans(.callout, weight: .medium)).foregroundStyle(QuietoColor.textSecondary)
            }
        }
    }
}

/// The session of the day, full width: artwork, title and programme progress
/// sit on the image, with a single play button.
struct TodayHero: View {
    let session: QuietoSession?
    let program: QuietoProgram?
    /// Step of the programme (1-based) and its length, nil outside a programme.
    var step: (current: Int, total: Int)?
    let onPlay: (QuietoSession) -> Void
    let onOpenProgram: () -> Void

    private var detail: String {
        guard let session else { return "" }
        if let opensOn = program?.opensOn {
            return QuietoLocalization.format("%d min · %@", session.durationMinutes, PlanSchedule.waitLabel(until: opensOn))
        }
        let context = step.map { QuietoLocalization.format("Étape %d sur %d", $0.current, $0.total) } ?? session.practiceType.rawValue.quietoLocalized
        return QuietoLocalization.format("%d min · %@", session.durationMinutes, context)
    }

    var body: some View {
        if let session {
            VStack(alignment: .leading, spacing: 12) {
                Button { onPlay(session) } label: { artwork(session) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(QuietoLocalization.format("%@, %@", session.title.quietoLocalized, detail))
                    .accessibilityHint("Ouvre la séance")
                if let program {
                    Button(action: onOpenProgram) {
                        HStack(spacing: 6) {
                            Text(program.title.quietoLocalized).lineLimit(1)
                            Spacer(minLength: 8)
                            Text("Voir le parcours".quietoLocalized)
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                        }
                        .font(QuietoFont.sans(.subhead, weight: .medium)).foregroundStyle(QuietoColor.textSecondary)
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            EmptySessionCard()
        }
    }

    private func artwork(_ session: QuietoSession) -> some View {
        Color.clear
            .frame(height: 340)
            .overlay { QuietoAssetImage(session.imageName, contentMode: .fill) }
            .overlay {
                LinearGradient(colors: [.clear, .clear, QuietoColor.background.opacity(0.55), QuietoColor.background.opacity(0.95)], startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .topLeading) {
                Text("TA PROCHAINE SÉANCE".quietoLocalized)
                    .quietoOverline()
                    .foregroundStyle(QuietoColor.textPrimary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .environment(\.colorScheme, .dark)
                    .padding(14)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(session.title.quietoLocalized)
                                .font(QuietoFont.heading(.title)).foregroundStyle(QuietoColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(detail).font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textPrimary.opacity(0.75))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "play.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(QuietoColor.background)
                            .frame(width: QuietoMetrics.playMedium, height: QuietoMetrics.playMedium)
                            .background(QuietoColor.mintFill, in: Circle())
                            .quietoGlow(radius: 14)
                    }
                    if let step { ProgressSegments(completed: program?.completedDays.count ?? step.current - 1, total: step.total) }
                }
                .padding(18)
            }
            .clipShape(RoundedRectangle(cornerRadius: QuietoRadius.hero, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: QuietoRadius.hero, style: .continuous))
    }
}

private struct EmptySessionCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Une pause quand tu seras prêt·e").font(QuietoFont.heading(.title))
            Text("Explore les séances Quieto pour choisir ce dont tu as besoin aujourd’hui.").font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .quietoSurface(cornerRadius: QuietoRadius.hero)
    }
}

private struct ProgressSegments: View {
    let completed: Int
    let total: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Capsule().fill(index < completed ? QuietoColor.mint : QuietoColor.textPrimary.opacity(0.22)).frame(height: 4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(QuietoLocalization.format("Progression : %d sur %d jours", completed, total))
    }
}

/// Without a programme: a single quiet row towards Louane.
struct EmptyProgramCard: View {
    let onCreate: () -> Void
    var body: some View {
        Button(action: onCreate) {
            HStack(spacing: 14) {
                Image(systemName: "sparkles").font(.system(size: 20)).foregroundStyle(QuietoColor.mint)
                    .frame(width: 44, height: 44).background(QuietoColor.surfaceRaised, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Crée ton programme").font(QuietoFont.heading(.card))
                    Text("Louane peut t’aider à trouver un rythme simple.").font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(QuietoColor.textSecondary)
            }
            .foregroundStyle(QuietoColor.textPrimary)
            .padding(14)
            .quietoSurface(cornerRadius: QuietoRadius.card)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Créer un programme")
    }
}

/// The anti-stress button of the home screen: one soft, breathing orb to tap
/// when things overflow. It opens the eight situations, then the matching sessions.
struct AntiStressButton: View {
    @ObservedObject var model: HomeViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExploring = false
    @State private var pulse = false

    var body: some View {
        Button { isExploring = true } label: {
            HStack(spacing: 18) {
                orb
                VStack(alignment: .leading, spacing: 6) {
                    Text("Anti-stress".quietoLocalized).quietoOverline().foregroundStyle(QuietoColor.mint)
                    Text("J’ai besoin d’une pause".quietoLocalized)
                        .font(QuietoFont.heading(.card)).foregroundStyle(QuietoColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Dis ce que tu traverses, Quieto te propose la bonne séance.".quietoLocalized)
                        .font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(QuietoColor.textSecondary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .quietoSurface(cornerRadius: QuietoRadius.hero)
        }
        .buttonStyle(QuietoPressStyle())
        .sensoryFeedback(.impact(weight: .medium), trigger: isExploring)
        .accessibilityLabel("J’ai besoin d’une pause".quietoLocalized)
        .accessibilityHint("Choisis ce que tu traverses".quietoLocalized)
        .navigationDestination(isPresented: $isExploring) { NeedExplorerView(model: model) }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    /// A mint orb with two rings that breathe slowly, like a calm pulse.
    private var orb: some View {
        ZStack {
            Circle().stroke(QuietoColor.mint.opacity(0.18), lineWidth: 1.5)
                .frame(width: 96, height: 96).scaleEffect(pulse ? 1.08 : 0.9)
            Circle().stroke(QuietoColor.mint.opacity(0.32), lineWidth: 1.5)
                .frame(width: 78, height: 78).scaleEffect(pulse ? 1.04 : 0.94)
            Circle().fill(QuietoColor.mintFill).frame(width: 60, height: 60)
                .quietoGlow(radius: pulse ? 20 : 12)
            Image(systemName: "hand.tap.fill").font(.system(size: 22, weight: .semibold)).foregroundStyle(QuietoColor.background)
        }
        .frame(width: 96, height: 96)
        .accessibilityHidden(true)
    }
}

/// Short sessions to use right now, as artwork tiles.
struct ExpressCarousel: View {
    let onPlay: (QuietoSession) -> Void
    private let sessions: [QuietoSession] = {
        let catalog = SessionCatalog().sessions
        return ["new_long_exhale", "express_5", "express_1", "express_2", "express_6", "express_7"]
            .compactMap { id in catalog.first { $0.id == id } }
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: QuietoSpacing.sm) {
            HomeSectionHeader(title: "Une pause express")
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(sessions) { session in
                        Button { onPlay(session) } label: { tile(session) }
                            .buttonStyle(.plain)
                            .accessibilityLabel(QuietoLocalization.format("%@, %d min", session.title.quietoLocalized, session.durationMinutes))
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, QuietoSpacing.md, for: .scrollContent)
            .padding(.horizontal, -QuietoSpacing.md)
        }
    }

    private func tile(_ session: QuietoSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear.frame(width: 148, height: 148)
                .overlay { QuietoAssetImage(session.imageName, contentMode: .fill) }
                .overlay(alignment: .bottomLeading) {
                    Text(QuietoLocalization.format("%d min", session.durationMinutes))
                        .font(QuietoFont.sans(.caption, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .environment(\.colorScheme, .dark)
                        .padding(8)
                }
                .clipShape(RoundedRectangle(cornerRadius: QuietoRadius.card, style: .continuous))
            Text(session.title.quietoLocalized)
                .font(QuietoFont.heading(.card)).foregroundStyle(QuietoColor.textPrimary)
                .lineLimit(2).multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 148, alignment: .leading)
        }
    }
}

struct NeedExplorerView: View {
    @ObservedObject var model: HomeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selection: QuietoSituation?

    init(model: HomeViewModel, selection: QuietoSituation? = nil) {
        self.model = model
        _selection = State(initialValue: selection)
    }

    /// Pushed from the home screen. Picking a situation swaps the content in
    /// place; « Retour » then goes back to the grid before leaving the page.
    var body: some View {
        ZStack {
            QuietoBackground()
            ScrollView {
                Group { if let selection { recommendations(for: selection) } else { needGrid } }
                    .frame(maxWidth: QuietoMetrics.contentMaxWidth).padding(QuietoSpacing.md).padding(.bottom, 128)
            }
        }
        .badgeCelebrationOverlay()
        .navigationTitle(Text((selection == nil ? "Ton besoin du moment" : "Ta pause, maintenant").quietoLocalized))
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(selection != nil)
        .toolbar {
            if selection != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button { withAnimation(.easeInOut(duration: 0.25)) { selection = nil } } label: { Label("Retour", systemImage: "chevron.left") }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selection)
    }

    private var needGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pas besoin de trouver le mot parfait. Choisis ce qui ressemble le plus à maintenant.").font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(QuietoSituation.featured) { situation in
                    Button { selection = situation; model.checkIn(situation) } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            if let imageName = model.sessions(for: situation).first?.imageName {
                                QuietoAssetImage(imageName, contentMode: .fill).frame(height: 106).clipped().clipShape(RoundedRectangle(cornerRadius: QuietoRadius.small))
                            }
                            Text(situation.rawValue.quietoLocalized).font(QuietoFont.heading(.card, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary).fixedSize(horizontal: false, vertical: true)
                        }.frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading).padding(9)
                            .quietoSurface(cornerRadius: QuietoRadius.card)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func recommendations(for situation: QuietoSituation) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if let imageName = model.sessions(for: situation).first?.imageName {
                QuietoAssetImage(imageName, contentMode: .fill).frame(maxWidth: .infinity).frame(height: 190).clipped().clipShape(RoundedRectangle(cornerRadius: QuietoRadius.card))
            }
            Text(situation.rawValue.quietoLocalized).font(QuietoFont.heading(.title, weight: .semibold))
            Text(situation.subtitle.quietoLocalized).font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
            if let planned = model.snapshot.nextSession {
                Label(QuietoLocalization.format("Ta séance prévue « %@ » reste inchangée.", planned.title.quietoLocalized), systemImage: "checkmark.shield")
                    .font(QuietoFont.sans(.subhead, weight: .medium)).foregroundStyle(QuietoColor.mint)
            }
            Text("Séances proposées").quietoSectionTitle()
            ForEach(model.sessions(for: situation)) { session in
                Button { model.play(session, source: "daily_checkin"); dismiss() } label: {
                    HStack(spacing: 12) {
                        QuietoAssetImage(session.imageName, contentMode: .fill).frame(width: 76, height: 66).clipped().clipShape(RoundedRectangle(cornerRadius: QuietoRadius.small))
                        VStack(alignment: .leading, spacing: 4) { Text(session.title.quietoLocalized).font(QuietoFont.heading(.card, weight: .semibold)); Text(QuietoLocalization.format("%d min · %@", session.durationMinutes, session.practiceType.rawValue.quietoLocalized)).font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary) }
                        Spacer(); Image(systemName: "play.fill").foregroundStyle(QuietoColor.background).frame(width: QuietoMetrics.playSmall, height: QuietoMetrics.playSmall).background(QuietoColor.mintFill, in: Circle())
                    }.foregroundStyle(QuietoColor.textPrimary).padding(10).quietoSurface(cornerRadius: QuietoRadius.card)
                }.buttonStyle(.plain)
            }
            Text("Ou simplement un son").quietoSectionTitle()
            ForEach(model.ambiences(for: situation)) { ambience in
                Button { model.play(ambience, source: "daily_checkin"); dismiss() } label: {
                    HStack(spacing: 12) {
                        QuietoAssetImage(ambience.assetName, contentMode: .fill).frame(width: 68, height: 58).clipped().clipShape(RoundedRectangle(cornerRadius: QuietoRadius.small))
                        VStack(alignment: .leading, spacing: 3) { Text(ambience.title.quietoLocalized).font(QuietoFont.sans(.callout, weight: .semibold)); Text(ambience.subtitle.quietoLocalized).font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary) }
                        Spacer(); Image(systemName: "waveform").foregroundStyle(QuietoColor.mint)
                    }.foregroundStyle(QuietoColor.textPrimary).padding(10).quietoSurface(cornerRadius: QuietoRadius.card)
                }.buttonStyle(.plain)
            }
        }
    }
}

/// Discreet entry towards Louane, with her own mark.
struct LouaneCard: View {
    let onOpen: () -> Void
    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                LouaneMark(size: 24)
                    .frame(width: 48, height: 48)
                    .background(QuietoColor.mint.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Besoin d’en parler ?").font(QuietoFont.heading(.card))
                    Text("Louane peut t’aider à trouver ta pause.").font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(QuietoColor.textSecondary)
            }
            .foregroundStyle(QuietoColor.textPrimary)
            .padding(14)
            .quietoSurface(cornerRadius: QuietoRadius.card)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Parler à Louane")
    }
}

struct RecentSessionCard: View {
    let session: QuietoSession
    let listenedAt: Date?
    let onPlay: () -> Void

    private var listened: String {
        guard let listenedAt else { return "Déjà écoutée".quietoLocalized }
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDateInToday(listenedAt) { return "Écoutée aujourd’hui".quietoLocalized }
        if calendar.isDateInYesterday(listenedAt) { return "Écoutée hier".quietoLocalized }
        return QuietoLocalization.format("Écoutée le %@", listenedAt.formatted(.dateTime.day().month(.wide).locale(QuietoLocalization.locale)))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: QuietoSpacing.sm) {
            HomeSectionHeader(title: "À retrouver")
            Button(action: onPlay) {
                HStack(spacing: 12) {
                    QuietoAssetImage(session.imageName, contentMode: .fill).frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: QuietoRadius.card, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.title.quietoLocalized).font(QuietoFont.heading(.card)).foregroundStyle(QuietoColor.textPrimary).lineLimit(1)
                        Text(QuietoLocalization.format("%d min · %@", session.durationMinutes, listened)).font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "play.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary)
                        .frame(width: 36, height: 36).background(QuietoColor.surfaceRaised, in: Circle())
                }
                .padding(10).quietoSurface(cornerRadius: QuietoRadius.card)
            }
            .buttonStyle(.plain)
        }
    }
}
