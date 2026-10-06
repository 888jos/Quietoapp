import SwiftUI

struct LouaneView: View {
    @StateObject private var model: LouaneViewModel
    @FocusState private var focused: Bool
    @State private var showSuggestions = true
    @State private var followsLatestMessage = true

    init(audioPlayer: QuietoAudioPlayer) { _model = StateObject(wrappedValue: LouaneViewModel(audioPlayer: audioPlayer)) }

    var body: some View {
        ZStack { QuietoColor.background.ignoresSafeArea(); VStack(spacing: 0) { header; disclaimer; conversation; composer }.frame(maxWidth: QuietoMetrics.contentMaxWidth) }
            .sheet(isPresented: $model.isMenuPresented) { LouaneMenuView(model: model) }
            .sheet(isPresented: $model.isMemoryPresented) { LouaneMemoryView(model: model) }
            .sheet(isPresented: $model.isInfoPresented) { LouaneInfoView() }
            .sheet(isPresented: $model.isHistoryPresented) { LouaneHistoryView(model: model) }
            .alert("Supprimer cette conversation ?", isPresented: $model.isDeleteConfirmationPresented) { Button("Annuler", role: .cancel) {}; Button("Supprimer", role: .destructive) { model.deleteConversation() } } message: { Text("Elle sera retirée de cet appareil. Cela ne garantit pas la suppression des copies déjà traitées par les prestataires du service.") }
            .alert("Suppression de la conversation", isPresented: Binding(get: { model.deletionError != nil }, set: { if !$0 { model.deletionError = nil } })) { Button("OK") {} } message: { Text((model.deletionError ?? "").quietoLocalized) }
    }

    private var header: some View { HStack(spacing: 12) { LouaneMark(size: 30); VStack(alignment: .leading, spacing: 0) { Text("Louane").font(QuietoFont.sans(19, weight: .semibold)); Text("Ton espace pour parler").font(QuietoFont.sans(13)).foregroundStyle(QuietoColor.textSecondary) }; Spacer(); Button { model.isMenuPresented = true } label: { Image(systemName: "ellipsis").font(.title3) }.accessibilityLabel("Menu de Louane") }.padding(.horizontal, QuietoSpacing.md).padding(.vertical, 12).foregroundStyle(QuietoColor.textPrimary) }
    private var disclaimer: some View { HStack(spacing: 8) { Image(systemName: "info.circle"); Text("Une IA, pas un professionnel de santé.").font(QuietoFont.sans(12)) }.foregroundStyle(QuietoColor.textSecondary).frame(maxWidth: .infinity).padding(9).background(QuietoColor.surface, in: Capsule()).padding(.horizontal, QuietoSpacing.md) }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if model.messages.isEmpty { welcome.id("top") }
                        ForEach(model.messages) { message in MessageBubble(message: message, model: model).id(message.id) }
                        if model.isSending {
                            HStack {
                                LouaneMark(size: 22)
                                ProgressView().tint(QuietoColor.mint)
                                Text("Louane prépare sa réponse…").font(QuietoFont.sans(13)).foregroundStyle(QuietoColor.textSecondary)
                                Spacer()
                                Button("Arrêter") { model.cancelResponse() }.font(QuietoFont.sans(13, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                            }.padding(.horizontal, QuietoSpacing.md)
                        }
                        if case .failed = model.status { ErrorRetryView { if let last = model.messages.last(where: { $0.author == .user }) { model.retry(last) } } }
                        Color.clear.frame(height: 1).id("conversation-bottom")
                    }
                    .padding(.horizontal, QuietoSpacing.md).padding(.vertical, 18)
                }
                .simultaneousGesture(DragGesture().onChanged { value in
                    if value.translation.height > 8 { followsLatestMessage = false }
                })
                .onChange(of: model.messages.count) { _, _ in
                    guard followsLatestMessage else { return }
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("conversation-bottom", anchor: .bottom) }
                }
                if !followsLatestMessage && !model.messages.isEmpty {
                    Button {
                        followsLatestMessage = true
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("conversation-bottom", anchor: .bottom) }
                    } label: {
                        Image(systemName: "arrow.down").foregroundStyle(QuietoColor.background).frame(width: 38, height: 38).background(QuietoColor.mint, in: Circle())
                    }
                    .accessibilityLabel("Revenir au dernier message")
                    .padding(12)
                }
            }
        }
    }
    private var welcome: some View { VStack(alignment: .leading, spacing: 14) { Text("Parler, puis trouver ta prochaine pause.").font(QuietoFont.serif(29, weight: .semibold)); Text("Tu peux écrire ce qui te traverse. Louane ne diagnostique pas et ne remplace pas une aide professionnelle.").font(QuietoFont.sans(15)).foregroundStyle(QuietoColor.textSecondary); if showSuggestions { HStack { SuggestionButton(title: "J’ai besoin de souffler") { model.draft = "J’ai besoin de souffler" }; SuggestionButton(title: "M’aider à décrocher") { model.draft = "M’aider à décrocher" } } } }.padding(.vertical, 20) }
    private var composer: some View { HStack(alignment: .bottom, spacing: 8) { TextField("Écris à Louane…", text: $model.draft, axis: .vertical).lineLimit(1...5).focused($focused).onChange(of: model.draft) { _, _ in model.saveDraft() }.padding(13).background(QuietoColor.surface, in: RoundedRectangle(cornerRadius: 20)); Button { focused = false; model.send() } label: { Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold)).foregroundStyle(QuietoColor.background).frame(width: 42, height: 42).background(QuietoColor.mint, in: Circle()) }.disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isSending).opacity(model.draft.isEmpty ? 0.5 : 1) }.padding(.horizontal, QuietoSpacing.md).padding(.vertical, 10).background(QuietoColor.background) }
}

private struct MessageBubble: View { let message: LouaneMessage; @ObservedObject var model: LouaneViewModel; var body: some View { VStack(alignment: message.author == .user ? .trailing : .leading, spacing: 8) { HStack(alignment: .top, spacing: 8) { if message.author == .louane { LouaneMark(size: 22).padding(.top, 5) }; Text(message.text).font(QuietoFont.sans(16)).foregroundStyle(message.author == .user ? QuietoColor.background : QuietoColor.textPrimary).padding(13).background(message.author == .user ? QuietoColor.mint : QuietoColor.surface, in: RoundedRectangle(cornerRadius: 16)); if message.author == .user { Spacer(minLength: 35) } }.frame(maxWidth: .infinity, alignment: message.author == .user ? .trailing : .leading); if let rec = message.recommendation, let session = model.session(for: rec) { RecommendationCard(session: session, reason: rec.reason) { model.play(rec) } } }.frame(maxWidth: .infinity, alignment: message.author == .user ? .trailing : .leading) } }
private struct RecommendationCard: View { let session: QuietoSession; let reason: String; let play: () -> Void; var body: some View { HStack(spacing: 12) { QuietoAssetImage(session.imageName, contentMode: .fill).frame(width: 94, height: 76).clipShape(RoundedRectangle(cornerRadius: 10)); VStack(alignment: .leading, spacing: 4) { Text(session.title.quietoLocalized).font(QuietoFont.serif(18, weight: .semibold)); Text("\(session.durationMinutes) min · \(session.practiceType.rawValue.quietoLocalized)").font(QuietoFont.sans(12)).foregroundStyle(QuietoColor.textSecondary); if !reason.isEmpty { Text(reason).font(QuietoFont.sans(12)).foregroundStyle(QuietoColor.textSecondary).lineLimit(2) } }; Spacer(); Button(action: play) { Image(systemName: "play.fill").foregroundStyle(QuietoColor.background).frame(width: 38, height: 38).background(QuietoColor.mint, in: Circle()) } }.padding(12).background(QuietoColor.surface, in: RoundedRectangle(cornerRadius: 16)).overlay { RoundedRectangle(cornerRadius: 16).stroke(QuietoColor.divider) } } }
private struct SuggestionButton: View { let title: String; let action: () -> Void; var body: some View { Button(title, action: action).font(QuietoFont.sans(12)).foregroundStyle(QuietoColor.textPrimary).padding(.horizontal, 10).padding(.vertical, 9).background(QuietoColor.surface, in: Capsule()) } }
private struct ErrorRetryView: View { let action: () -> Void; var body: some View { HStack { Text("Louane n’a pas pu répondre.").font(QuietoFont.sans(13)).foregroundStyle(QuietoColor.textSecondary); Button("Réessayer", action: action).foregroundStyle(QuietoColor.mint) }.padding(.horizontal, QuietoSpacing.md) } }
