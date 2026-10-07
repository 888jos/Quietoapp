import SwiftUI

struct SessionsView: View {
    @ObservedObject var model: SessionsViewModel
    /// Rows shown in « Méditations »; « Voir plus » adds a page.
    @State private var shownCount = SessionsView.pageSize
    @State private var category: QuietoCategory?
    @State private var showingAllThemes = false
    private static let pageSize = 6

    /// Themes, « Tout voir » and the libraries open as pages pushed on this
    /// stack, not as sheets; only a session itself opens as a sheet.
    var body: some View {
        NavigationStack {
            page
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(item: $category) { category in
                    SessionListPage(title: category.rawValue, subtitle: category.summary, sessions: model.sessions(in: category), sessionModel: model)
                }
                .navigationDestination(isPresented: $showingAllThemes) { AllThemesPage(sessionModel: model) }
                .navigationDestination(item: $model.selectedLibrary) { library in
                    SessionListPage(title: library.rawValue, subtitle: nil, sessions: model.sessions(in: library), sessionModel: model)
                }
        }
        .tint(QuietoColor.mint)
    }

    private var page: some View {
        ZStack { QuietoBackground(); ScrollView { content.frame(maxWidth: QuietoMetrics.contentMaxWidth).padding(.horizontal, QuietoSpacing.md).padding(.top, QuietoSpacing.sm).padding(.bottom, 128) } }.safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 92) }
            .sheet(item: $model.selectedSession) { SessionDetailView(session: $0, model: model) }
            .alert("Quieto", isPresented: Binding(get: { model.feedback != nil }, set: { if !$0 { model.feedback = nil } })) { Button("OK") { model.feedback = nil } } message: { Text((model.feedback ?? "").quietoLocalized) }
            .onChange(of: model.filterKey) { _, _ in shownCount = Self.pageSize }
            .onAppear {
                #if DEBUG
                if let id = ProcessInfo.processInfo.environment["QUIETO_SESSION_DETAIL_ID"] {
                    model.selectedSession = model.catalog.sessions.first { $0.id == id }
                }
                if let id = ProcessInfo.processInfo.environment["QUIETO_AUTOPLAY_SESSION_ID"],
                   let session = model.catalog.sessions.first(where: { $0.id == id }) {
                    model.play(session)
                }
                #endif
            }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: QuietoSpacing.lg) {
            header
            searchField
            if model.query.isEmpty {
                quickStart
                separator
                forYouNow
                separator
                themes
                separator
                allSessions
                separator
                BreathingSection(model: model)
                separator
                ambiences
            } else {
                // Searching: the results come right under the field.
                allSessions
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Séances").font(QuietoFont.display)
                .lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            LibraryButton(symbol: "clock.arrow.circlepath", tint: QuietoColor.textPrimary, label: "Écoutées récemment") { model.selectedLibrary = .recent }
            LibraryButton(symbol: "arrow.down.circle.fill", tint: QuietoColor.mint, label: "Téléchargements") { model.selectedLibrary = .downloads }
            LibraryButton(symbol: "heart.fill", tint: QuietoColor.coral, label: "Favoris") { model.selectedLibrary = .favorites }
        }
    }

    private var separator: some View {
        Rectangle().fill(QuietoColor.divider).frame(height: 1)
    }

    private var searchField: some View {
        HStack { Image(systemName: "magnifyingglass"); TextField("", text: $model.query, prompt: Text("Une séance, un besoin…").foregroundStyle(QuietoColor.textSecondary)).foregroundStyle(QuietoColor.textPrimary).textInputAutocapitalization(.never); if !model.query.isEmpty { Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill") } } }.padding(13).foregroundStyle(QuietoColor.textSecondary).quietoSurface(cornerRadius: QuietoRadius.small).accessibilityLabel("Rechercher une séance")
    }

    private var forYouNow: some View {
        let recommendation = model.recommendation()
        return VStack(alignment: .leading, spacing: QuietoSpacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pour toi maintenant").quietoSectionTitle()
                Text(recommendation.moment.reason.quietoLocalized).font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
            }
            ForEach(recommendation.sessions.prefix(3)) { session in row(session) }
        }
    }

    private var quickStart: some View {
        VStack(alignment: .leading, spacing: QuietoSpacing.sm) {
            Text("Démarrage rapide").quietoSectionTitle()
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(QuietoGoal.allCases) { goal in
                    QuickStartTile(goal: goal) { model.quickStart(goal) }
                }
            }
        }
    }

    /// Same-size portrait cards, scrolled sideways (see `ThemeCard`).
    private var themes: some View {
        VStack(alignment: .leading, spacing: QuietoSpacing.sm) {
            HStack {
                Text("Thèmes").quietoSectionTitle()
                Spacer()
                Button { showingAllThemes = true } label: {
                    HStack(spacing: 4) { Text("Tout voir"); Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)) }
                        .font(QuietoFont.sans(.callout, weight: .medium)).foregroundStyle(QuietoColor.textPrimary)
                }
                .buttonStyle(.plain)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(QuietoCategory.allCases) { item in
                        ThemeCard(category: item, count: model.sessions(in: item).count) { category = item }
                    }
                }
                .padding(.trailing, QuietoSpacing.md)
            }
            .padding(.trailing, -QuietoSpacing.md)
        }
    }

    private var ambiences: some View {
        VStack(alignment: .leading, spacing: QuietoSpacing.sm) {
            Text("Sons d’ambiance").quietoSectionTitle()
            AmbienceRow(player: model.audioPlayer)
        }
    }

    /// A menu row with its result count; disabled when it would empty the list.
    private func filterOption(_ title: String, count: Int, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if selected { Label(title, systemImage: "checkmark") } else { Text(title) }
            Text(verbatim: "\(count)")
        }
        .disabled(count == 0 && !selected)
    }

    private var filters: some View {
        HStack(spacing: QuietoSpacing.sm) {
            // Each choice shows how many sessions it leaves, and choices that would
            // empty the list (e.g. a 1–5 min visualisation) are greyed out.
            Menu {
                ForEach(QuietoDurationFilter.allCases) { value in
                    filterOption(value.rawValue.quietoLocalized, count: model.resultCount(duration: value), selected: model.durationFilter == value) { model.durationFilter = value }
                }
            } label: { FilterChip(title: QuietoLocalization.format("Durée : %@", model.durationFilter.rawValue.quietoLocalized)) }
            Menu {
                filterOption("Tous les types".quietoLocalized, count: model.resultCount(practice: nil), selected: model.practiceFilter == nil) { model.practiceFilter = nil }
                ForEach(QuietoPracticeType.allCases.filter { $0 != .breathing }) { value in
                    filterOption(value.rawValue.quietoLocalized, count: model.resultCount(practice: value), selected: model.practiceFilter == value) { model.practiceFilter = value }
                }
            } label: { FilterChip(title: QuietoLocalization.format("Type : %@", (model.practiceFilter?.rawValue ?? "Tous").quietoLocalized)) }
            Spacer(minLength: 0)
        }
        .foregroundStyle(QuietoColor.textPrimary)
    }

    private var allSessions: some View {
        let sessions = model.filteredSessions
        return VStack(alignment: .leading, spacing: QuietoSpacing.sm) {
            HStack {
                Text((model.query.isEmpty && !model.hasActiveFilters ? "Méditations" : "Résultats").quietoLocalized).quietoSectionTitle()
                Spacer()
                if model.hasActiveFilters { Button("Tout effacer") { model.resetFilters() }.font(QuietoFont.sans(.subhead, weight: .semibold)).foregroundStyle(QuietoColor.mint) }
                Text(verbatim: "\(sessions.count)").font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.mint)
            }
            ScrollView(.horizontal, showsIndicators: false) { filters }
            if sessions.isEmpty {
                EmptyState(title: "Aucune séance trouvée", message: "Essaie un autre mot ou retire un filtre.")
                if model.hasActiveFilters {
                    QuietoOutlineButton(title: "Tout effacer", systemImage: "xmark") { model.resetFilters() }
                }
            } else {
                ForEach(sessions.prefix(shownCount)) { session in row(session) }
                if sessions.count > shownCount {
                    Button { shownCount += 10 } label: {
                        HStack(spacing: 6) { Text("Voir plus"); Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)) }
                            .font(QuietoFont.sans(.callout, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(QuietoColor.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    .accessibilityHint(min(10, sessions.count - shownCount) == 1 ? "1 séance de plus".quietoLocalized : QuietoLocalization.format("%d séances de plus", min(10, sessions.count - shownCount)))
                }
            }
        }
    }

    private func row(_ session: QuietoSession) -> some View {
        SessionRow(session: session, isFavorite: model.favorites.contains(session.id), isDownloaded: model.downloads.isDownloaded(session), action: { model.selectedSession = session }, play: { model.play(session) }, favorite: { model.toggleFavorite(session) })
    }

}

private struct FilterChip: View { let title: String; var body: some View { HStack { Text(title.quietoLocalized).font(QuietoFont.sans(.caption)); Image(systemName: "chevron.down").font(QuietoFont.sans(.caption)) }.padding(.horizontal, 10).frame(height: 40).quietoSurface(cornerRadius: QuietoRadius.small) } }
struct SessionRow: View { let session: QuietoSession; let isFavorite: Bool; let isDownloaded: Bool; let action: () -> Void; let play: () -> Void; let favorite: () -> Void; var body: some View { HStack(spacing: 12) { Button(action: action) { HStack(spacing: 12) { QuietoAssetImage(session.imageName, contentMode: .fill).frame(width: 72, height: 58).clipShape(RoundedRectangle(cornerRadius: QuietoRadius.small)); VStack(alignment: .leading, spacing: 4) { Text(session.title.quietoLocalized).font(QuietoFont.heading(.card, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary).lineLimit(2); Text(QuietoLocalization.format("%d min · %@", session.durationMinutes, session.practiceType.rawValue.quietoLocalized)).font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary) } }.frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain); Button(action: favorite) { Image(systemName: isFavorite ? "heart.fill" : "heart").font(.system(size: 22, weight: .medium)).foregroundStyle(isFavorite ? QuietoColor.coral : QuietoColor.textSecondary).frame(width: QuietoMetrics.minimumTapTarget, height: QuietoMetrics.minimumTapTarget).contentShape(Rectangle()).contentTransition(.symbolEffect(.replace)) }.buttonStyle(QuietoPressStyle()).sensoryFeedback(.selection, trigger: isFavorite).accessibilityLabel((isFavorite ? "Retirer des favoris" : "Ajouter aux favoris").quietoLocalized); Button(action: play) { Image(systemName: "play.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(QuietoColor.background).frame(width: QuietoMetrics.playSmall, height: QuietoMetrics.playSmall).background(QuietoColor.mintFill, in: Circle()) }.buttonStyle(.plain).accessibilityLabel(QuietoLocalization.format("Lire %@", session.title.quietoLocalized)) }.padding(.vertical, 8).overlay(alignment: .bottom) { Rectangle().fill(QuietoColor.divider).frame(height: 1) } } }

private struct QuickStartTile: View {
    let goal: QuietoGoal
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                QuietoAssetImage(goal.artwork, contentMode: .fill)
                    .frame(width: 58, height: 58).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: QuietoRadius.card, style: .continuous))
                Text(goal.rawValue.quietoLocalized)
                    .font(QuietoFont.sans(.callout, weight: .medium))
                    .foregroundStyle(QuietoColor.textPrimary)
                    .lineLimit(2).minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(9)
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            .quietoSurface(cornerRadius: QuietoRadius.card)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Lance une séance courte".quietoLocalized)
    }
}


/// Breathing exercises, under the meditations: calmest first, a few at a time.
/// Each card previews its rhythm as the roller-coaster curve it plays full screen.
private struct BreathingSection: View {
    @ObservedObject var model: SessionsViewModel
    @State private var shown = 4

    var body: some View {
        let exercises = model.breathingGroups.flatMap(\.sessions)
        VStack(alignment: .leading, spacing: QuietoSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Respiration".quietoLocalized).quietoSectionTitle()
                Spacer()
                Text(verbatim: "\(exercises.count)").font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.mint)
            }
            ForEach(exercises.prefix(shown)) { session in
                BreathingCard(session: session, minutes: model.breathingMinutes[session.id] ?? session.breathingPattern?.durationOptions.first ?? session.durationMinutes) {
                    model.selectedSession = session
                } start: {
                    model.play(session)
                }
            }
            if exercises.count > shown {
                Button { withAnimation(.easeOut(duration: 0.25)) { shown = exercises.count } } label: {
                    HStack(spacing: 6) { Text("Voir plus".quietoLocalized); Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)) }
                        .font(QuietoFont.sans(.callout, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(QuietoColor.surface, in: Capsule())
                }
                .buttonStyle(QuietoPressStyle())
                .padding(.top, 4)
            }
        }
    }
}

private struct BreathingCard: View {
    let session: QuietoSession
    let minutes: Int
    let open: () -> Void
    let start: () -> Void

    private var pattern: QuietoBreathingPattern { session.breathingPattern ?? .coherence }

    var body: some View {
        HStack(spacing: 14) {
            Button(action: open) {
                HStack(spacing: 14) {
                    BreathingCurvePreview(pattern: pattern)
                        .frame(width: 84, height: 60)
                        .background(QuietoColor.backgroundDeep.opacity(0.6), in: RoundedRectangle(cornerRadius: QuietoRadius.card, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: QuietoRadius.card, style: .continuous).strokeBorder(QuietoColor.divider, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.title.quietoLocalized)
                            .font(QuietoFont.sans(.body, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary)
                            .lineLimit(1).minimumScaleFactor(0.85)
                        Text(verbatim: pattern.fixedCycles != nil
                             ? "\(pattern.rhythm.quietoLocalized) · \(QuietoLocalization.format("%d cycles", pattern.fixedCycles ?? 0))"
                             : "\(pattern.rhythm.quietoLocalized) · \(QuietoLocalization.format("%d min", minutes))")
                            .font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary).monospacedDigit()
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(QuietoPressStyle())
            Button(action: start) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(QuietoColor.background)
                    .frame(width: QuietoMetrics.playSmall, height: QuietoMetrics.playSmall).background(QuietoColor.mintFill, in: Circle())
                    .frame(width: QuietoMetrics.minimumTapTarget, height: QuietoMetrics.minimumTapTarget)
            }
            .buttonStyle(QuietoPressStyle())
            .accessibilityLabel(QuietoLocalization.format("Commencer %@", session.title.quietoLocalized))
        }
        .padding(10)
        .quietoSurface(cornerRadius: QuietoRadius.card)
    }
}

/// Two cycles of a pattern drawn as a small static curve.
struct BreathingCurvePreview: View {
    let pattern: QuietoBreathingPattern

    var body: some View {
        Canvas { context, size in
            let inset: CGFloat = 10
            let height = size.height - inset * 2
            if pattern == .counting {
                // No imposed rhythm: a calm row of dots, one per breath.
                for index in 0..<5 {
                    let x = inset + (size.width - inset * 2) * CGFloat(index) / 4
                    context.fill(Path(ellipseIn: CGRect(x: x - 3, y: size.height / 2 - 3, width: 6, height: 6)), with: .color(QuietoColor.mint.opacity(0.4 + 0.15 * Double(index))))
                }
                return
            }
            let span = pattern.cycleDuration * 2
            let total = QuietoBreathingPattern.leadIn + span * 4
            var path = Path()
            let steps = 60
            for step in 0...steps {
                let t = QuietoBreathingPattern.leadIn + span * Double(step) / Double(steps)
                let level = pattern.moment(at: t, total: total).level
                let point = CGPoint(x: inset + (size.width - inset * 2) * CGFloat(step) / CGFloat(steps), y: inset + (1 - CGFloat(level)) * height)
                if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            context.stroke(path, with: .color(QuietoColor.mint.opacity(0.18)), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .linearGradient(Gradient(colors: [QuietoColor.mint.opacity(0.5), QuietoColor.mintLight]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
