import SwiftUI

struct LouaneView: View {
    @ObservedObject var model: LouaneViewModel
    @FocusState private var focused: Bool
    @State private var showSuggestions = true
    @State private var followsLatestMessage = true
    @Environment(\.quietoMiniPlayerVisible) private var miniPlayerVisible

    var body: some View {
        ZStack { QuietoBackground(); VStack(spacing: 0) { header; disclaimer; conversation; composer }.frame(maxWidth: QuietoMetrics.contentMaxWidth) }
            .sheet(isPresented: $model.isMenuPresented) { LouaneMenuView(model: model) }
            .sheet(isPresented: $model.isMemoryPresented) { LouaneMemoryView(model: model) }
            .sheet(isPresented: $model.isInfoPresented) { LouaneInfoView() }
            .sheet(isPresented: $model.isHistoryPresented) { LouaneHistoryView(model: model) }
            .alert("Supprimer cette conversation ?", isPresented: $model.isDeleteConfirmationPresented) { Button("Annuler", role: .cancel) {}; Button("Supprimer", role: .destructive) { model.deleteConversation() } } message: { Text("Elle sera retirée de cet appareil. Cela ne garantit pas la suppression des copies déjà traitées par les prestataires du service.") }
            .alert("Suppression de la conversation", isPresented: Binding(get: { model.deletionError != nil }, set: { if !$0 { model.deletionError = nil } })) { Button("OK") {} } message: { Text((model.deletionError ?? "").quietoLocalized) }
    }

    /// Same header as the other tabs: a Faro display title and a square icon button.
    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Louane").font(QuietoFont.display)
                Text("Ton espace pour parler").font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
            }
            Spacer(minLength: 8)
            LibraryButton(symbol: "ellipsis", tint: QuietoColor.textPrimary, label: "Menu de Louane") { model.isMenuPresented = true }
        }
        .padding(.horizontal, QuietoSpacing.md)
        .padding(.top, QuietoSpacing.sm)
        .padding(.bottom, QuietoSpacing.sm)
        .foregroundStyle(QuietoColor.textPrimary)
    }
    private var disclaimer: some View { HStack(spacing: 8) { Image(systemName: "info.circle"); Text("Une IA, pas un professionnel de santé.").font(QuietoFont.sans(.caption)) }.foregroundStyle(QuietoColor.textSecondary).frame(maxWidth: .infinity).padding(9).background(QuietoColor.surface, in: Capsule()).padding(.horizontal, QuietoSpacing.md) }

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
                                Text("Louane prépare sa réponse…").font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                                Spacer()
                                Button("Arrêter") { model.cancelResponse() }.font(QuietoFont.sans(.subhead, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                            }.padding(.horizontal, QuietoSpacing.md)
                        }
                        if case .failed(let reason) = model.status { ErrorRetryView(reason: reason) { if let last = model.messages.last(where: { $0.author == .user }) { model.retry(last) } } }
                        if case .limited(let notice) = model.status { LimitNoticeView(text: notice) }
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
                        Image(systemName: "arrow.down").foregroundStyle(QuietoColor.background).frame(width: QuietoMetrics.playSmall, height: QuietoMetrics.playSmall).background(QuietoColor.mintFill, in: Circle())
                    }
                    .accessibilityLabel("Revenir au dernier message")
                    .padding(12)
                }
            }
        }
    }
    private var welcome: some View { VStack(alignment: .leading, spacing: 14) { Text("Parler, puis trouver ta prochaine pause.").font(QuietoFont.heading(.title, weight: .semibold)); Text("Tu peux écrire ce qui te traverse. Louane ne diagnostique pas et ne remplace pas une aide professionnelle.").font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary); if showSuggestions { HStack { SuggestionButton(title: "J’ai besoin de souffler") { model.draft = "J’ai besoin de souffler".quietoLocalized }; SuggestionButton(title: "M’aider à décrocher") { model.draft = "M’aider à décrocher".quietoLocalized } } } }.padding(.vertical, 20) }
    private var canSend: Bool { !model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.isSending }

    /// One opaque pill with the send button inside it. It sits directly on the
    /// sky, without a band of its own, so the night stays dark down to the tab bar.
    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Écris à Louane…", text: $model.draft, axis: .vertical)
                .lineLimit(1...5)
                .font(QuietoFont.sans(.body))
                .focused($focused)
                .onChange(of: model.draft) { _, _ in model.saveDraft() }
                .padding(.leading, 18)
                .padding(.vertical, 12)
            Button { focused = false; model.send() } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(canSend ? QuietoColor.background : QuietoColor.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(canSend ? AnyShapeStyle(QuietoColor.mintFill) : AnyShapeStyle(QuietoColor.textPrimary.opacity(0.1)), in: Circle())
                    .frame(width: QuietoMetrics.minimumTapTarget, height: QuietoMetrics.minimumTapTarget)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("Envoyer")
            .padding(.trailing, 2)
            .padding(.bottom, 1)
        }
        .background(QuietoColor.surfaceSolid, in: RoundedRectangle(cornerRadius: QuietoRadius.hero, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: QuietoRadius.hero, style: .continuous).strokeBorder(focused ? QuietoColor.mint.opacity(0.45) : QuietoColor.divider, lineWidth: 1) }
        .animation(.easeOut(duration: 0.2), value: focused)
        .animation(.easeOut(duration: 0.15), value: canSend)
        .padding(.horizontal, QuietoSpacing.md)
        .padding(.top, 6)
        // The mini player floats just above the tab bar: keep the composer above it.
        .padding(.bottom, miniPlayerVisible ? 84 : 10)
        .animation(.easeOut(duration: 0.25), value: miniPlayerVisible)
    }
}

private struct MessageBubble: View { let message: LouaneMessage; @ObservedObject var model: LouaneViewModel; var body: some View { VStack(alignment: message.author == .user ? .trailing : .leading, spacing: 8) { HStack(alignment: .top, spacing: 8) { if message.author == .louane { LouaneMark(size: 22).padding(.top, 5) }; Text(verbatim: message.text).font(QuietoFont.sans(.body)).foregroundStyle(message.author == .user ? QuietoColor.background : QuietoColor.textPrimary).padding(13).background(message.author == .user ? QuietoColor.mint : QuietoColor.surface, in: RoundedRectangle(cornerRadius: QuietoRadius.card)); if message.author == .user { Spacer(minLength: 35) } }.frame(maxWidth: .infinity, alignment: message.author == .user ? .trailing : .leading); if let rec = message.recommendation, model.session(for: rec) != nil || model.ambience(for: rec) != nil { LouaneLaunchCard(session: model.session(for: rec), ambience: model.ambience(for: rec), reason: rec.reason) { model.play(rec) } } }.frame(maxWidth: .infinity, alignment: message.author == .user ? .trailing : .leading) } }
private struct SuggestionButton: View { let title: String; let action: () -> Void; var body: some View { Button(title.quietoLocalized, action: action).font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textPrimary).padding(.horizontal, 10).padding(.vertical, 9).background(QuietoColor.surface, in: Capsule()) } }
private struct LimitNoticeView: View { let text: String; var body: some View { HStack(alignment: .top, spacing: 8) { Image(systemName: "moon.zzz"); Text(text.quietoLocalized).font(QuietoFont.sans(.subhead)) }.foregroundStyle(QuietoColor.textSecondary).padding(12).quietoSurface(cornerRadius: QuietoRadius.card).padding(.horizontal, QuietoSpacing.md) } }
private struct ErrorRetryView: View { let reason: String; let action: () -> Void; var body: some View { VStack(alignment: .leading, spacing: 6) { HStack { Text("Louane n’a pas pu répondre.").font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary); Button("Réessayer", action: action).foregroundStyle(QuietoColor.mint) }; if !reason.isEmpty { Text(verbatim: reason).font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary) }; Text(LouaneServiceError.crisisLine).font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary) }.padding(.horizontal, QuietoSpacing.md) } }
