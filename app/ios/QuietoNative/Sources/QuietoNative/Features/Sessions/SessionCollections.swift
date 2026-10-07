import SwiftUI

/// Square icon button of the Séances header: recent, downloads, favourites.
struct LibraryButton: View {
    let symbol: String
    let tint: Color
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .quietoSurface(cornerRadius: QuietoRadius.small)
        }
        .buttonStyle(QuietoPressStyle())
        .accessibilityLabel(label.quietoLocalized)
    }
}

/// Portrait theme card. Every card has the same size whatever the length of
/// its text, so the horizontal row stays even.
struct ThemeCard: View {
    static let size = CGSize(width: 220, height: 318)

    let category: QuietoCategory
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                QuietoAssetImage(category.artwork, contentMode: .fill)
                    .frame(width: Self.size.width, height: 168).clipped()
                VStack(alignment: .leading, spacing: 6) {
                    Text(category.rawValue.quietoLocalized)
                        .font(QuietoFont.heading(.section, weight: .semibold))
                        .foregroundStyle(QuietoColor.textPrimary)
                        .lineLimit(2).minimumScaleFactor(0.8)
                    Text(category.summary.quietoLocalized)
                        .font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                        .lineLimit(3)
                    Spacer(minLength: 0)
                    Text(count == 1 ? "1 séance".quietoLocalized : QuietoLocalization.format("%d séances", count))
                        .font(QuietoFont.sans(.caption, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                }
                .padding(14)
                .frame(width: Self.size.width, height: Self.size.height - 168, alignment: .topLeading)
            }
            .frame(width: Self.size.width, height: Self.size.height)
            .background(QuietoColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: QuietoRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Fixed-size card for a situation (« Ce que tu ressens »).
struct SituationCard: View {
    let situation: QuietoSituation
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: situation.themes.first?.symbol ?? "sparkles")
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                Text(situation.rawValue.quietoLocalized)
                    .font(QuietoFont.heading(.card, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary)
                    .lineLimit(3).minimumScaleFactor(0.85)
                Text(situation.subtitle.quietoLocalized)
                    .font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary).lineLimit(2)
                Spacer(minLength: 0)
                Text(count == 1 ? "1 séance".quietoLocalized : QuietoLocalization.format("%d séances", count))
                    .font(QuietoFont.sans(.caption, weight: .semibold)).foregroundStyle(QuietoColor.mint)
            }
            .padding(14)
            .frame(width: 220, height: 196, alignment: .topLeading)
            .quietoSurface(cornerRadius: QuietoRadius.card)
        }
        .buttonStyle(.plain)
    }
}

/// Sessions of a theme, a situation or a library, with their own detail sheet
/// so a tab never depends on another tab's presentation state.
struct SessionListContent: View {
    let subtitle: String?
    let sessions: [QuietoSession]
    @ObservedObject var sessionModel: SessionsViewModel
    @State private var selected: QuietoSession?

    var body: some View {
        ZStack {
            QuietoBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: QuietoSpacing.sm) {
                    if let subtitle {
                        Text(subtitle.quietoLocalized).font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
                    }
                    if sessions.isEmpty {
                        EmptyState(title: "Rien ici pour l’instant", message: "Ta bibliothèque se remplira au fil de tes écoutes.")
                    } else {
                        ForEach(sessions) { session in
                            SessionRow(
                                session: session,
                                isFavorite: sessionModel.favorites.contains(session.id),
                                isDownloaded: sessionModel.downloads.isDownloaded(session),
                                action: { selected = session },
                                play: { sessionModel.play(session) },
                                favorite: { sessionModel.toggleFavorite(session) }
                            )
                        }
                    }
                }
                .padding(QuietoSpacing.md)
                .padding(.bottom, 120)
            }
        }
        .sheet(item: $selected) { SessionDetailView(session: $0, model: sessionModel) }
    }
}

struct SessionListSheet: View {
    let title: String
    let subtitle: String?
    let sessions: [QuietoSession]
    @ObservedObject var sessionModel: SessionsViewModel

    var body: some View {
        NavigationStack {
            SessionListContent(subtitle: subtitle, sessions: sessions, sessionModel: sessionModel)
                .navigationTitle(Text(title.quietoLocalized))
                .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(.dark)
    }
}

/// A pushed page listing the sessions of a theme, a situation or a library.
struct SessionListPage: View {
    let title: String
    let subtitle: String?
    let sessions: [QuietoSession]
    @ObservedObject var sessionModel: SessionsViewModel

    var body: some View {
        SessionListContent(subtitle: subtitle, sessions: sessions, sessionModel: sessionModel)
            .navigationTitle(Text(title.quietoLocalized))
            .navigationBarTitleDisplayMode(.large)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

/// Every theme as a two-column grid, pushed from « Tout voir ».
struct AllThemesPage: View {
    @ObservedObject var sessionModel: SessionsViewModel

    private func sessionCount(_ count: Int) -> String {
        count == 1 ? "1 séance".quietoLocalized : QuietoLocalization.format("%d séances", count)
    }

    var body: some View {
        ZStack {
            QuietoBackground()
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(QuietoCategory.allCases) { category in
                        NavigationLink {
                            SessionListPage(title: category.rawValue, subtitle: category.summary, sessions: sessionModel.sessions(in: category), sessionModel: sessionModel)
                        } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                QuietoAssetImage(category.artwork, contentMode: .fill)
                                    .frame(height: 110).frame(maxWidth: .infinity).clipped()
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(category.rawValue.quietoLocalized)
                                        .font(QuietoFont.heading(.card, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary)
                                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                                    Text(sessionCount(sessionModel.sessions(in: category).count))
                                        .font(QuietoFont.sans(.caption, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                                }
                                .padding(11)
                                .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
                            }
                            .background(QuietoColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: QuietoRadius.card, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: QuietoRadius.card, style: .continuous).strokeBorder(QuietoColor.divider, lineWidth: 1))
                        }
                        .buttonStyle(QuietoPressStyle())
                    }
                }
                .padding(QuietoSpacing.md)
                .padding(.bottom, 128)
            }
        }
        .navigationTitle(Text("Thèmes".quietoLocalized))
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}
