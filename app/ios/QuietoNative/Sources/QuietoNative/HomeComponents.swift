import SwiftUI

struct NextSessionCard: View {
    let session: QuietoSession?
    let onPlay: (QuietoSession) -> Void

    var body: some View {
        if let session {
            QuietoCard {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        QuietoAssetImage(session.imageName, contentMode: .fill).frame(height: 208).clipped()
                        Text("TA PROCHAINE SÉANCE")
                            .font(QuietoFont.sans(11, weight: .bold)).tracking(1)
                            .foregroundStyle(QuietoColor.background)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(QuietoColor.mint, in: Capsule()).padding(12)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.title.quietoLocalized).font(QuietoFont.serif(27, weight: .medium)).foregroundStyle(QuietoColor.textPrimary)
                        Text("\(session.durationMinutes) min · Étape 3 sur 7").font(QuietoFont.sans(14)).foregroundStyle(QuietoColor.textSecondary)
                        QuietoPrimaryButton(title: "Commencer ma séance", systemImage: "play.fill") { onPlay(session) }
                            .padding(.top, 8)
                    }
                    .padding(.top, 14)
                }
            }
            .accessibilityElement(children: .contain)
        } else {
            EmptySessionCard()
        }
    }
}

private struct EmptySessionCard: View {
    var body: some View {
        QuietoCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Une pause quand tu seras prêt·e").font(QuietoFont.serif(24, weight: .semibold))
                Text("Explore les séances Quieto pour choisir ce dont tu as besoin aujourd’hui.").font(QuietoFont.sans(14)).foregroundStyle(QuietoColor.textSecondary)
            }
        }
    }
}

struct ProgramSummary: View {
    let program: QuietoProgram
    let onOpen: () -> Void
    let onAdjust: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: QuietoSpacing.sm) {
            HStack {
                Text("Ton programme").quietoSectionTitle()
                Spacer()
                Button("Voir le parcours", action: onOpen)
                    .font(QuietoFont.sans(14, weight: .medium)).foregroundStyle(QuietoColor.textSecondary)
            }
            QuietoCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(program.title.quietoLocalized).font(QuietoFont.serif(21, weight: .medium))
                    ProgressSegments(completed: program.completedDays.count, total: program.totalDays)
                    HStack {
                        Text("\(program.completedDays.count) séance\(program.completedDays.count == 1 ? "" : "s") terminée\(program.completedDays.count == 1 ? "" : "s")")
                        Spacer()
                        Button("Adapter mon rythme", action: onAdjust)
                            .foregroundStyle(QuietoColor.mint)
                    }
                    .font(QuietoFont.sans(13, weight: .medium)).foregroundStyle(QuietoColor.textSecondary)
                }
            }
        }
    }
}

private struct ProgressSegments: View {
    let completed: Int
    let total: Int
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Capsule().fill(index < completed ? QuietoColor.mint : QuietoColor.textPrimary.opacity(0.16)).frame(height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Progression : \(completed) sur \(total) jours")
    }
}

struct EmptyProgramCard: View {
    let onCreate: () -> Void
    var body: some View {
        QuietoCard {
            HStack(spacing: 14) {
                Image(systemName: "sparkles").font(.system(size: 23)).foregroundStyle(QuietoColor.mint)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Crée ton programme").font(QuietoFont.serif(22, weight: .semibold))
                    Text("Louane peut t’aider à trouver un rythme simple.").font(QuietoFont.sans(14)).foregroundStyle(QuietoColor.textSecondary)
                }
                Spacer()
                Button(action: onCreate) { Image(systemName: "chevron.right").foregroundStyle(QuietoColor.mint) }.accessibilityLabel("Créer un programme")
            }
        }
    }
}

struct ExpressSection: View {
    let onPlay: (QuietoSession) -> Void
    private let sessions = SessionCatalog().sessions.filter { ["new_long_exhale", "express_2"].contains($0.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: QuietoSpacing.sm) {
            Text("Une pause express").quietoSectionTitle()
            HStack(spacing: 10) {
                ForEach(sessions) { session in
                    Button { onPlay(session) } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: session.id == "breathing_1" ? "wind" : "leaf").font(.system(size: 24, weight: .light)).foregroundStyle(QuietoColor.textPrimary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title.quietoLocalized).font(QuietoFont.serif(17, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary).lineLimit(1)
                                Text(session.subtitle).font(QuietoFont.sans(13)).foregroundStyle(QuietoColor.textSecondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(QuietoColor.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                        .background(QuietoColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(QuietoColor.divider, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct CheckInSection: View {
    @ObservedObject var model: HomeViewModel
    @State private var showingExplorer = false

    var body: some View {
        VStack(alignment: .leading, spacing: QuietoSpacing.md) {
            Divider().overlay(QuietoColor.divider)
            QuietoCard {
                VStack(alignment: .leading, spacing: 13) {
                    Label("Ton point du jour", systemImage: "sparkles").font(QuietoFont.sans(13, weight: .bold)).foregroundStyle(QuietoColor.mint)
                    Text("Qu’est-ce qui prend le plus de place aujourd’hui ?")
                        .font(QuietoFont.serif(25, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                    Text("Choisis une situation concrète. Quieto te proposera des séances et des sons adaptés, sans modifier ton programme.")
                        .font(QuietoFont.sans(14)).foregroundStyle(QuietoColor.textSecondary).lineSpacing(3)
                    QuietoPrimaryButton(title: "Trouver la pause qui me ferait du bien", systemImage: "arrow.right") { showingExplorer = true }
                }
            }
        }
        .sheet(isPresented: $showingExplorer) { NeedExplorerView(model: model).presentationDetents([.large]).presentationDragIndicator(.visible) }
    }
}

private struct NeedExplorerView: View {
    @ObservedObject var model: HomeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selection: QuietoNeed?

    var body: some View {
        NavigationStack {
            ZStack {
                QuietoColor.background.ignoresSafeArea()
                ScrollView {
                    Group { if let selection { recommendations(for: selection) } else { needGrid } }
                        .frame(maxWidth: QuietoMetrics.contentMaxWidth).padding(QuietoSpacing.md).padding(.bottom, 36)
                }
            }
            .navigationTitle(selection == nil ? "Ton besoin du moment" : "Ta pause, maintenant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { if selection != nil { Button("Retour") { selection = nil } } }
                ToolbarItem(placement: .topBarTrailing) { Button("Fermer") { dismiss() } }
            }
        }.preferredColorScheme(.dark)
    }

    private var needGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pas besoin de trouver le mot parfait. Choisis ce qui ressemble le plus à maintenant.").font(QuietoFont.sans(15)).foregroundStyle(QuietoColor.textSecondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(QuietoNeed.allCases) { need in
                    Button { selection = need } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            QuietoAssetImage(need.imageName, contentMode: .fill).frame(height: 106).clipped().clipShape(RoundedRectangle(cornerRadius: 13))
                            Text(need.rawValue).font(QuietoFont.serif(18, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary).fixedSize(horizontal: false, vertical: true)
                        }.frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading).padding(9)
                            .background(QuietoColor.surface, in: RoundedRectangle(cornerRadius: 16)).overlay { RoundedRectangle(cornerRadius: 16).stroke(QuietoColor.divider) }
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func recommendations(for need: QuietoNeed) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            QuietoAssetImage(need.imageName, contentMode: .fill).frame(maxWidth: .infinity).frame(height: 190).clipped().clipShape(RoundedRectangle(cornerRadius: 18))
            Text(need.rawValue).font(QuietoFont.serif(30, weight: .semibold))
            Text(need.explanation).font(QuietoFont.sans(15)).foregroundStyle(QuietoColor.textSecondary)
            if let planned = model.snapshot.nextSession {
                Label("Ta séance prévue « \(planned.title) » reste inchangée.", systemImage: "checkmark.shield")
                    .font(QuietoFont.sans(13, weight: .medium)).foregroundStyle(QuietoColor.mint)
            }
            Text("Séances proposées").quietoSectionTitle()
            ForEach(model.sessions(for: need)) { session in
                Button { model.play(session, source: "daily_checkin"); dismiss() } label: {
                    HStack(spacing: 12) {
                        QuietoAssetImage(session.imageName, contentMode: .fill).frame(width: 76, height: 66).clipped().clipShape(RoundedRectangle(cornerRadius: 11))
                        VStack(alignment: .leading, spacing: 4) { Text(session.title.quietoLocalized).font(QuietoFont.serif(19, weight: .semibold)); Text("\(session.durationMinutes) min · \(session.practiceType.rawValue.quietoLocalized)").font(QuietoFont.sans(12)).foregroundStyle(QuietoColor.textSecondary) }
                        Spacer(); Image(systemName: "play.fill").foregroundStyle(QuietoColor.background).frame(width: 34, height: 34).background(QuietoColor.mint, in: Circle())
                    }.foregroundStyle(QuietoColor.textPrimary).padding(10).background(QuietoColor.surface, in: RoundedRectangle(cornerRadius: 15))
                }.buttonStyle(.plain)
            }
            Text("Ou simplement un son").quietoSectionTitle()
            ForEach(model.ambiences(for: need)) { ambience in
                Button { model.play(ambience, source: "daily_checkin"); dismiss() } label: {
                    HStack(spacing: 12) {
                        QuietoAssetImage(ambience.assetName, contentMode: .fill).frame(width: 68, height: 58).clipped().clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) { Text(ambience.title.quietoLocalized).font(QuietoFont.sans(15, weight: .semibold)); Text(ambience.subtitle.quietoLocalized).font(QuietoFont.sans(12)).foregroundStyle(QuietoColor.textSecondary) }
                        Spacer(); Image(systemName: "waveform").foregroundStyle(QuietoColor.mint)
                    }.foregroundStyle(QuietoColor.textPrimary).padding(10).background(QuietoColor.surface, in: RoundedRectangle(cornerRadius: 15))
                }.buttonStyle(.plain)
            }
        }
    }
}

struct LouaneCard: View {
    let onOpen: () -> Void
    var body: some View {
        QuietoCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 13) {
                    LouaneSymbol()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Besoin d’en parler ?").font(QuietoFont.serif(24, weight: .semibold))
                        Text("Louane peut t’aider à trouver ta pause.").font(QuietoFont.sans(14)).foregroundStyle(QuietoColor.textSecondary)
                    }
                }
                QuietoOutlineButton(title: "Parler à Louane", systemImage: "chevron.right", action: onOpen)
            }
        }
    }
}

private struct LouaneSymbol: View {
    var body: some View {
        Image(systemName: "link").font(.system(size: 32, weight: .light)).foregroundStyle(QuietoColor.mint).accessibilityHidden(true)
    }
}

struct RecentSessionCard: View {
    let session: QuietoSession
    let onPlay: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: QuietoSpacing.sm) {
            Divider().overlay(QuietoColor.divider)
            Text("À retrouver").quietoSectionTitle()
            Button(action: onPlay) {
                HStack(spacing: 12) {
                    QuietoAssetImage(session.imageName, contentMode: .fill).frame(width: 76, height: 66).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(session.title.quietoLocalized).font(QuietoFont.serif(20, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary)
                        Text("\(session.durationMinutes) min · Écoutée hier").font(QuietoFont.sans(13)).foregroundStyle(QuietoColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "play.fill").font(.system(size: 15, weight: .semibold)).foregroundStyle(QuietoColor.background).frame(width: 34, height: 34).background(QuietoColor.textPrimary, in: Circle())
                }
                .padding(10).background(QuietoColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}
