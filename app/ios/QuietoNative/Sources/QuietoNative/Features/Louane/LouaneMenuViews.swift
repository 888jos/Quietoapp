import SwiftUI

struct LouaneMenuView: View {
    @ObservedObject var model: LouaneViewModel
    var body: some View { NavigationStack { ZStack { QuietoBackground(); ScrollView { VStack(alignment: .leading, spacing: 18) { LouaneMark(size: 28); Text("Ton échange").font(QuietoFont.heading(.title, weight: .semibold)); menuButton("Nouvelle conversation", "square.and.pencil") { model.newConversation(); model.isMenuPresented = false }; menuButton("Historique des échanges", "clock") { model.isHistoryPresented = true; model.isMenuPresented = false }; VStack(spacing: 0) { Toggle(isOn: $model.temporaryConversation) { Label("Conversation temporaire", systemImage: "lock") }.tint(QuietoColor.mint).padding(14); Text("Le mode temporaire n’ajoute pas cet échange à l’historique local. Il ne garantit pas l’effacement chez les prestataires du service.").font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary).padding(.horizontal, 14).padding(.bottom, 14); Divider().overlay(QuietoColor.divider); menuButton("Mémoire de Louane", "externaldrive") { model.isMemoryPresented = true; model.isMenuPresented = false } }.quietoSurface(cornerRadius: QuietoRadius.card); menuButton("À propos de Louane", "info.circle") { model.isInfoPresented = true; model.isMenuPresented = false }; menuButton("Signaler une réponse", "flag") { model.reportLatestResponse(); model.isReportPresented = true }; Button { model.isDeleteConfirmationPresented = true; model.isMenuPresented = false } label: { Label("Supprimer cette conversation", systemImage: "trash").frame(maxWidth: .infinity, alignment: .leading).padding(15) }.foregroundStyle(QuietoColor.danger).quietoSurface(cornerRadius: QuietoRadius.card); Text("Aucune clé secrète ni contenu sensible n’est envoyé aux analytics natifs de cette cible.").font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary) }.padding(QuietoSpacing.md) } }.navigationTitle("Louane").navigationBarTitleDisplayMode(.inline) }.alert("Signaler une réponse", isPresented: $model.isReportPresented) { Button("Fermer", role: .cancel) {} } message: { Text((model.reportMessage ?? "Le signalement est en cours…").quietoLocalized) } }
    private func menuButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View { Button(action: action) { Label(title.quietoLocalized, systemImage: icon).frame(maxWidth: .infinity, alignment: .leading).padding(15) }.foregroundStyle(QuietoColor.textPrimary).quietoSurface(cornerRadius: QuietoRadius.card) }
}

struct LouaneMemoryView: View { @ObservedObject var model: LouaneViewModel; @State private var value = ""; var body: some View { NavigationStack { Form { Section("Ce que Louane retient") { TextEditor(text: $value).frame(minHeight: 140); Text("Cette mémoire est synchronisée avec ton compte Quieto quand le réseau est disponible. Tu peux la corriger ou la supprimer ici.").font(QuietoFont.sans(.caption)).foregroundStyle(.secondary) }; Section { Button("Enregistrer") { model.saveMemory(value) }; Button("Supprimer la mémoire", role: .destructive) { model.deleteMemory(); value = "" } } }.font(QuietoFont.sans(.body)).scrollContentBackground(.hidden).background(QuietoBackground()).navigationTitle("Mémoire de Louane").task { await model.refreshMemory(); value = model.memory.text } } }
}

struct LouaneInfoView: View { var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 16) { LouaneMark(size: 34); Text("Louane est une IA conçue pour offrir un espace de parole et aider à trouver une prochaine pause.").font(QuietoFont.heading(.section, weight: .semibold)); Text("Elle ne diagnostique pas, ne traite pas et ne remplace pas un professionnel de santé. En cas de danger immédiat ou de détresse, contacte les services d’urgence ou une aide humaine adaptée à ton pays.").font(QuietoFont.sans(.body)).foregroundStyle(QuietoColor.textSecondary); Text("Le backend Quieto conserve les règles de sécurité et les limites d’usage. Cette cible native ne contient aucune clé secrète.").font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary) }.padding(QuietoSpacing.md) }.background(QuietoBackground()).navigationTitle("À propos de Louane").navigationBarTitleDisplayMode(.inline) } }
}

struct LouaneHistoryView: View {
    @ObservedObject var model: LouaneViewModel
    var body: some View {
        NavigationStack {
            ZStack {
                QuietoBackground()
                if let error = model.historyError {
                    EmptyState(title: "Historique indisponible", message: error)
                } else if model.history.isEmpty {
                    EmptyState(title: "Aucun échange enregistré", message: "Tes conversations non temporaires apparaîtront ici.")
                } else {
                    List(model.history) { item in
                        Button { Task { await model.openConversation(item) } } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.title?.isEmpty == false ? item.title! : "Conversation".quietoLocalized).font(QuietoFont.sans(.body, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary).lineLimit(2)
                                Text(item.updatedAt.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(QuietoLocalization.locale))).font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
                            }
                        }
                        .listRowBackground(QuietoColor.surface)
                    }.scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Historique des échanges").navigationBarTitleDisplayMode(.inline)
            .task { await model.loadHistory() }
        }
    }
}
