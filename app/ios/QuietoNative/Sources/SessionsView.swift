import SwiftUI

struct SessionsView: View {
    @StateObject private var model: SessionsViewModel
    @State private var showFilters = false

    init(audioPlayer: QuietoAudioPlayer) { _model = StateObject(wrappedValue: SessionsViewModel(audioPlayer: audioPlayer)) }

    var body: some View {
        ZStack { QuietoColor.background.ignoresSafeArea(); ScrollView { content.frame(maxWidth: QuietoMetrics.contentMaxWidth).padding(.horizontal, QuietoSpacing.md).padding(.top, QuietoSpacing.sm).padding(.bottom, 128) } }.safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 92) }
            .sheet(item: $model.selectedSession) { SessionDetailView(session: $0, model: model) }
            .sheet(item: $model.selectedLibrary) { library in LibraryView(title: library.rawValue, sessions: model.librarySessions, model: model) }
            .alert("Quieto", isPresented: Binding(get: { model.feedback != nil }, set: { if !$0 { model.feedback = nil } })) { Button("OK") { model.feedback = nil } } message: { Text((model.feedback ?? "").quietoLocalized) }
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
            VStack(alignment: .leading, spacing: 3) { Text("quieto").font(QuietoFont.serif(22, weight: .semibold)); Text("Séances").font(QuietoFont.serif(34, weight: .semibold)); Text("Trouve ta pause.").font(QuietoFont.serif(30, weight: .semibold)); Text("Selon ton besoin, à ton rythme.").font(QuietoFont.sans(16)).foregroundStyle(QuietoColor.textSecondary) }
            HStack { Image(systemName: "magnifyingglass"); TextField("", text: $model.query, prompt: Text("Une séance, un besoin…").foregroundStyle(QuietoColor.textSecondary)).foregroundStyle(QuietoColor.textPrimary).textInputAutocapitalization(.never); if !model.query.isEmpty { Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill") } } }.padding(13).foregroundStyle(QuietoColor.textSecondary).background(QuietoColor.surface, in: RoundedRectangle(cornerRadius: 13)).accessibilityLabel("Rechercher une séance")
            VStack(alignment: .leading, spacing: QuietoSpacing.sm) {
                Text("Ce que tu vis maintenant").quietoSectionTitle()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(QuietoSituation.allCases) { situation in
                            SituationCard(situation: situation, selected: model.selectedSituation == situation) {
                                model.selectSituation(situation)
                            }
                        }
                    }.padding(.horizontal, 1)
                }
            }
            VStack(alignment: .leading, spacing: QuietoSpacing.sm) {
                Text("Explorer par thème").quietoSectionTitle()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(QuietoTheme.allCases) { theme in
                            ThemeChip(theme: theme, selected: model.selectedTheme == theme) { model.selectTheme(theme) }
                        }
                    }.padding(.horizontal, 1)
                }
            }
            VStack(alignment: .leading, spacing: QuietoSpacing.sm) { Text("Quatre façons de souffler").quietoSectionTitle(); LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: QuietoSpacing.sm) { ForEach(QuietoPillar.allCases) { pillar in PillarCard(pillar: pillar, selected: model.selectedPillar == pillar) { model.selectedPillar = model.selectedPillar == pillar ? nil : pillar } } } }
            HStack(spacing: QuietoSpacing.sm) { Menu { ForEach(QuietoDurationFilter.allCases) { value in Button(value.rawValue.quietoLocalized) { model.durationFilter = value } } } label: { FilterChip(title: "\("Durée".quietoLocalized) : \(model.durationFilter.rawValue.quietoLocalized)") }; Menu { Button("Tous les types") { model.practiceFilter = nil }; ForEach(QuietoPracticeType.allCases) { value in Button(value.rawValue.quietoLocalized) { model.practiceFilter = value } } } label: { FilterChip(title: "\("Type".quietoLocalized) : \((model.practiceFilter?.rawValue ?? "Tous").quietoLocalized)") }; Button { showFilters.toggle() } label: { Image(systemName: "slider.horizontal.3").frame(width: 42, height: 40).background(QuietoColor.surface, in: RoundedRectangle(cornerRadius: 12)) }.accessibilityLabel("Filtres avancés") }.foregroundStyle(QuietoColor.textPrimary)
            if showFilters {
                HStack {
                    Text("Les résultats combinent la situation, le thème, le pilier, la durée et le type.").font(QuietoFont.sans(13)).foregroundStyle(QuietoColor.textSecondary)
                    Spacer()
                    if model.hasActiveFilters { Button("Tout effacer") { model.resetFilters() }.font(QuietoFont.sans(13, weight: .semibold)).foregroundStyle(QuietoColor.mint) }
                }
            }
            VStack(alignment: .leading, spacing: QuietoSpacing.sm) { HStack { Text(model.query.isEmpty ? "Pour toi maintenant" : "Résultats").quietoSectionTitle(); Spacer(); Text("\(model.filteredSessions.count)").font(QuietoFont.sans(14)).foregroundStyle(QuietoColor.mint) }; if model.filteredSessions.isEmpty { EmptyState(title: "Aucune séance trouvée", message: "Essaie un autre mot ou retire un filtre.") } else { ForEach(model.filteredSessions) { session in SessionRow(session: session, isFavorite: model.favorites.contains(session.id), isDownloaded: model.downloads.isDownloaded(session), action: { model.selectedSession = session }, play: { model.play(session) }, favorite: { model.toggleFavorite(session) }) } } }
            library
            section(title: "Une pause courte", subtitle: "Quand tu as quelques minutes.", sessions: model.shortSessions)
            section(title: "Découvrir une autre approche", subtitle: nil, sessions: model.catalog.sessions.filter { $0.pillar != model.selectedPillar }.prefix(2).map { $0 })
        }
    }

    private var library: some View { VStack(alignment: .leading, spacing: QuietoSpacing.sm) { Text("Ta bibliothèque").quietoSectionTitle(); VStack(spacing: 0) { ForEach([QuietoLibrary.favorites, .downloads, .recent]) { item in Button { model.selectedLibrary = item } label: { HStack { Image(systemName: item == .favorites ? "bookmark" : item == .downloads ? "arrow.down" : "clock").frame(width: 25); Text(item.rawValue.quietoLocalized); Spacer(); Text("\(model.libraryCounts[item] ?? 0)").foregroundStyle(QuietoColor.textSecondary); Image(systemName: "chevron.right").font(.caption) }.padding(14).contentShape(Rectangle()) }.buttonStyle(.plain); if item != .recent { Divider().overlay(QuietoColor.divider) } } }.background(QuietoColor.surface, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(QuietoColor.textPrimary) } }
    private func section(title: String, subtitle: String?, sessions: [QuietoSession]) -> some View { VStack(alignment: .leading, spacing: QuietoSpacing.sm) { Text(title.quietoLocalized).quietoSectionTitle(); if let subtitle { Text(subtitle.quietoLocalized).font(QuietoFont.sans(14)).foregroundStyle(QuietoColor.textSecondary) }; ForEach(sessions) { session in SessionRow(session: session, isFavorite: model.favorites.contains(session.id), isDownloaded: model.downloads.isDownloaded(session), action: { model.selectedSession = session }, play: { model.play(session) }, favorite: { model.toggleFavorite(session) }) } } }
}

private struct SituationCard: View {
    let situation: QuietoSituation
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Image(systemName: situation.themes.first?.symbol ?? "sparkles")
                    Spacer()
                    if selected { Image(systemName: "checkmark.circle.fill") }
                }.foregroundStyle(QuietoColor.mint)
                Text(situation.rawValue.quietoLocalized)
                    .font(QuietoFont.serif(18, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text(situation.subtitle.quietoLocalized)
                    .font(QuietoFont.sans(12)).foregroundStyle(QuietoColor.textSecondary).lineLimit(2)
            }
            .frame(width: 224, height: 116, alignment: .topLeading).padding(13)
            .background(selected ? QuietoColor.surfaceRaised : QuietoColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(selected ? QuietoColor.mint : QuietoColor.divider, lineWidth: selected ? 1.5 : 1) }
        }.buttonStyle(.plain)
    }
}

private struct ThemeChip: View {
    let theme: QuietoTheme
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(theme.rawValue.quietoLocalized, systemImage: theme.symbol)
                .font(QuietoFont.sans(13, weight: .medium))
                .foregroundStyle(selected ? QuietoColor.background : QuietoColor.textPrimary)
                .padding(.horizontal, 12).frame(height: 38)
                .background(selected ? QuietoColor.mint : QuietoColor.surface, in: Capsule())
                .overlay { if !selected { Capsule().stroke(QuietoColor.divider) } }
        }.buttonStyle(.plain)
    }
}

private struct PillarCard: View { let pillar: QuietoPillar; let selected: Bool; let action: () -> Void; var body: some View { Button(action: action) { HStack(spacing: 10) { Image(systemName: pillar.symbol).font(.system(size: 23, weight: .light)); VStack(alignment: .leading) { Text(pillar.rawValue.quietoLocalized).font(QuietoFont.serif(18, weight: .semibold)); Text(pillar.subtitle.quietoLocalized).font(QuietoFont.sans(11)).foregroundStyle(QuietoColor.textSecondary).lineLimit(1) } }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(QuietoColor.surface, in: RoundedRectangle(cornerRadius: 13)).overlay { RoundedRectangle(cornerRadius: 13).stroke(selected ? QuietoColor.mint : QuietoColor.divider, lineWidth: selected ? 1.5 : 1) } }.buttonStyle(.plain).foregroundStyle(selected ? QuietoColor.mint : QuietoColor.textPrimary) } }
private struct FilterChip: View { let title: String; var body: some View { HStack { Text(title.quietoLocalized).font(QuietoFont.sans(12)); Image(systemName: "chevron.down").font(.caption) }.padding(.horizontal, 10).frame(height: 40).background(QuietoColor.surface, in: RoundedRectangle(cornerRadius: 12)).overlay { RoundedRectangle(cornerRadius: 12).stroke(QuietoColor.divider) } } }
struct SessionRow: View { let session: QuietoSession; let isFavorite: Bool; let isDownloaded: Bool; let action: () -> Void; let play: () -> Void; let favorite: () -> Void; var body: some View { HStack(spacing: 12) { Button(action: action) { HStack(spacing: 12) { QuietoAssetImage(session.imageName, contentMode: .fill).frame(width: 72, height: 58).clipShape(RoundedRectangle(cornerRadius: 10)); VStack(alignment: .leading, spacing: 4) { Text(session.title.quietoLocalized).font(QuietoFont.serif(18, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary).lineLimit(2); Text("\(session.durationMinutes) min · \(session.practiceType.rawValue.quietoLocalized)").font(QuietoFont.sans(12)).foregroundStyle(QuietoColor.textSecondary) } }.frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain); Button(action: favorite) { Image(systemName: isFavorite ? "bookmark.fill" : "bookmark").foregroundStyle(isFavorite ? QuietoColor.mint : QuietoColor.textSecondary) }.buttonStyle(.plain).accessibilityLabel(isFavorite ? "Retirer des favoris" : "Ajouter aux favoris"); Button(action: play) { Image(systemName: "play.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(QuietoColor.background).frame(width: 36, height: 36).background(QuietoColor.mint, in: Circle()) }.buttonStyle(.plain).accessibilityLabel("Lire \(session.title.quietoLocalized)") }.padding(.vertical, 8).overlay(alignment: .bottom) { Rectangle().fill(QuietoColor.divider).frame(height: 1) } } }
