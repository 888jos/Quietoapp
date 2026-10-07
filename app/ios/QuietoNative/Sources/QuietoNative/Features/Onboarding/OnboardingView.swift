import SwiftUI
import UIKit

struct OnboardingView: View {
    @ObservedObject var model: OnboardingViewModel
    @Environment(\.openURL) private var openURL
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            QuietoBackground()
            VStack(spacing: 0) {
                if showsHeader { header }
                content
                    .id(model.step)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            .frame(maxWidth: QuietoMetrics.contentMaxWidth)
        }
        .foregroundStyle(QuietoColor.textPrimary)
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.3), value: model.step)
        .alert("Quieto", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("OK") { model.message = nil }
        } message: { Text((model.message ?? "").quietoLocalized) }
    }

    private var showsHeader: Bool { ![.splash, .welcome, .building].contains(model.step) }

    private var header: some View {
        HStack(spacing: 14) {
            Button(action: model.back) { Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold)).frame(width: 36, height: 36) }
                .opacity(model.canGoBack ? 1 : 0).disabled(!model.canGoBack)
                .accessibilityLabel("Retour")
            OnboardingProgressBar(value: model.progress)
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, QuietoSpacing.md).padding(.top, 8).padding(.bottom, 4)
    }

    // MARK: Layout helpers

    private func page<Body: View, Footer: View>(@ViewBuilder body: () -> Body, @ViewBuilder footer: () -> Footer) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                body().padding(.horizontal, QuietoSpacing.lg).padding(.top, 28).padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: 6) { footer() }.padding(.horizontal, QuietoSpacing.lg).padding(.bottom, 12)
        }
    }

    private func info(_ title: String, _ text: String, symbol: String, cta: String = "Continuer") -> some View {
        page {
            VStack(alignment: .leading, spacing: 28) {
                Image(systemName: symbol).font(.system(size: 44, weight: .light)).foregroundStyle(QuietoColor.mint)
                OnboardingTitle(title: title, subtitle: text)
            }
            .padding(.top, 60)
        } footer: {
            OnboardingPrimaryButton(title: cta, action: model.next)
        }
    }

    // MARK: Steps

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .splash: splash
        case .promise:
            info("Prends quelques minutes pour toi.", "Réponds à quelques questions : on construit ta pause sur mesure, avec des séances qui te ressemblent.", symbol: "sparkles", cta: "C’est parti")
        case .offer: offer
        case .firstName: firstName
        case .stressBefore:
            page {
                VStack(alignment: .leading, spacing: 40) {
                    OnboardingTitle(title: "Ton niveau de stress cette semaine ?", subtitle: "De 0 (calme) à 10 (au maximum).")
                    OnboardingScale(value: $model.answers.stressBefore)
                }
            } footer: { OnboardingPrimaryButton(title: "Continuer", action: model.next) }
        case .notAlone:
            info("Ce que tu ressens est fréquent.", "Stress, sommeil en vrac, pensées qui tournent : beaucoup de gens le vivent. La bonne nouvelle, c’est que ça se travaille, quelques minutes par jour.", symbol: "person.2")
        case .crisisSupport: crisisSupport
        case .breathIntro:
            info("Essayons ensemble.", "Une minute de respiration : inspire 4 secondes, expire 6 secondes. Laisse le cercle te guider.", symbol: "wind", cta: "Je suis prêt·e")
        case .breathing: breathing
        case .stressAfter:
            page {
                VStack(alignment: .leading, spacing: 40) {
                    OnboardingTitle(title: "Et maintenant ?", subtitle: "Ton niveau de stress, juste après cette minute.")
                    OnboardingScale(value: Binding(get: { model.answers.stressAfter ?? model.answers.stressBefore }, set: { model.answers.stressAfter = $0 }))
                }
            } footer: { OnboardingPrimaryButton(title: "Continuer", action: model.next) }
        case .breathResult: breathResult
        case .louaneIntro: louaneIntro
        case .louaneAsk: louaneAsk
        case .louaneReply: louaneReply
        case .health: health
        case .reminders: reminders
        case .commitment: commitment
        case .account: account
        case .privacy:
            info("Ce qui t’appartient reste à toi.", "Tes réponses servent seulement à adapter Quieto. Tes données Apple Santé ne quittent jamais ton iPhone. Rien n’est vendu, et tu peux tout exporter ou supprimer depuis ton profil.", symbol: "lock.shield")
        case .building: building
        case .profileSummary: profileSummary
        case .plan: planView
        case .projection: projection
        case .included: included
        case .trialTimeline: trialTimeline
        case .paywall: paywall(relaunch: false)
        case .relaunch: paywall(relaunch: true)
        case .welcome: welcome
        default:
            question
        }
    }

    private var splash: some View {
        VStack(spacing: 18) {
            Spacer()
            Circle().fill(QuietoColor.mint.opacity(0.25)).frame(width: 120, height: 120)
                .overlay(Circle().stroke(QuietoColor.mint.opacity(0.6), lineWidth: 1))
                .phaseAnimator([0.85, 1.05]) { view, scale in view.scaleEffect(scale) } animation: { _ in .easeInOut(duration: 2) }
            Text("quieto").font(QuietoFont.heading(.hero, weight: .semibold))
            Text("Respire. On s’occupe du reste.").font(QuietoFont.sans(.body)).foregroundStyle(QuietoColor.textSecondary)
            Spacer()
        }
        .task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if model.step == .splash { model.next() }
        }
    }

    private var offer: some View {
        page {
            VStack(alignment: .leading, spacing: 22) {
                OnboardingTitle(title: "Ce qui t’attend dans Quieto")
                ForEach([
                    ("headphones", "Des séances guidées", "Méditation, relaxation, visualisation, de 1 à 20 minutes."),
                    ("wind", "Des respirations", "Pour redescendre en une minute, n’importe où."),
                    ("bubble.left.and.bubble.right", "Louane", "Ton espace pour parler, jour et nuit. Une IA bienveillante, pas un professionnel de santé."),
                    ("calendar", "Un programme pour toi", "Construit à partir de tes réponses.")
                ], id: \.0) { item in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: item.0).font(.system(size: 20)).foregroundStyle(QuietoColor.mint).frame(width: 30)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.1.quietoLocalized).font(QuietoFont.sans(.body, weight: .semibold))
                            Text(item.2.quietoLocalized).font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
                        }
                    }
                }
            }
        } footer: { OnboardingPrimaryButton(title: "Continuer", action: model.next) }
    }

    private var firstName: some View {
        page {
            VStack(alignment: .leading, spacing: 28) {
                OnboardingTitle(title: "Comment veux-tu qu’on t’appelle ?", subtitle: "Ton prénom, ou un surnom. C’est facultatif.")
                TextField("", text: $model.answers.firstName, prompt: Text("Ton prénom").foregroundStyle(QuietoColor.textSecondary))
                    .font(QuietoFont.heading(.title, weight: .semibold)).textContentType(.givenName).submitLabel(.continue)
                    .focused($focused).onSubmit(model.next)
                    .padding(16).quietoSurface(cornerRadius: QuietoRadius.card)
            }
        } footer: {
            OnboardingPrimaryButton(title: model.answers.firstName.trimmingCharacters(in: .whitespaces).isEmpty ? "Passer" : "Continuer") {
                model.answers.firstName = String(model.answers.firstName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
                focused = false
                model.next()
            }
        }
        .onAppear { focused = true }
    }

    @ViewBuilder
    private var question: some View {
        if let question = OnboardingContent.question(for: model.step, firstName: model.answers.firstName) {
            let step = model.step
            page {
                VStack(alignment: .leading, spacing: 24) {
                    OnboardingTitle(title: question.title, subtitle: question.subtitle)
                    VStack(spacing: 10) {
                        ForEach(question.options) { option in
                            OnboardingOptionRow(option: option, selected: model.isSelected(option, for: step), multiple: question.multiple) {
                                UISelectionFeedbackGenerator().selectionChanged()
                                model.select(option, for: step, multiple: question.multiple)
                            }
                        }
                    }
                    if step == .safety {
                        Text("Ta réponse reste sur ton iPhone. Elle sert seulement à t’orienter vers la bonne aide si besoin.")
                            .font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                    }
                }
            } footer: {
                if question.multiple {
                    OnboardingPrimaryButton(title: "Continuer", enabled: model.hasAnswer(for: step), action: model.next)
                }
            }
        }
    }

    private var crisisSupport: some View {
        page {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: "heart.text.square").font(.system(size: 44, weight: .light)).foregroundStyle(QuietoColor.mint)
                OnboardingTitle(title: "Merci de l’avoir dit. Tu n’as pas à porter ça seul·e.", subtitle: "Des personnes formées peuvent t’écouter maintenant, gratuitement, 24h/24.")
                QuietoPrimaryButton(title: QuietoLocalization.format("Appeler le %@", CrisisLine.current.primaryNumber), systemImage: "phone.fill") {
                    openURL(CrisisLine.current.primaryURL)
                }
                Text(CrisisLine.current.explanation)
                    .font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
                if CrisisLine.current.hotline != nil {
                    Button(QuietoLocalization.format("Appeler le %@", CrisisLine.current.emergency)) { openURL(CrisisLine.current.emergencyURL) }.font(QuietoFont.sans(.callout, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                }
            }
        } footer: {
            OnboardingSecondaryButton(title: "Continuer vers Quieto", action: model.continueAfterCrisis)
        }
    }

    private var breathing: some View {
        VStack(spacing: 30) {
            Spacer()
            OnboardingBreathingCircle(totalSeconds: 60) { model.next() }
            Spacer()
            OnboardingSecondaryButton(title: "Terminer maintenant", action: model.next).padding(.bottom, 12)
        }
    }

    private var breathResult: some View {
        let drop = model.stressDrop
        return info(
            drop == 1 ? "−1 point en une minute." : drop > 1 ? QuietoLocalization.format("−%d points en une minute.", drop) : "Une minute, et c’est un début.",
            drop > 0 ? "C’est ce que fait une respiration lente : elle envoie au corps le signal qu’il peut relâcher. Imagine quelques minutes par jour." : "Le calme vient avec la pratique. Quelques minutes par jour suffisent à sentir la différence.",
            symbol: "chart.line.downtrend.xyaxis"
        )
    }

    private var louaneIntro: some View {
        page {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) { LouaneMark(size: 34); Text("Louane").font(QuietoFont.sans(.body, weight: .semibold)) }
                OnboardingBubbles(bubbles: OnboardingLouaneScript.intro(model.answers))
            }
        } footer: { OnboardingPrimaryButton(title: "Lui répondre", action: model.next) }
    }

    private var louaneAsk: some View {
        page {
            VStack(alignment: .leading, spacing: 20) {
                OnboardingBubbles(bubbles: ["Qu’est-ce qui te pèse le plus en ce moment ?"])
                TextField("", text: $model.louaneDraft, prompt: Text("Écris librement…").foregroundStyle(QuietoColor.textSecondary), axis: .vertical)
                    .lineLimit(3...6).focused($focused)
                    .font(QuietoFont.sans(.body)).padding(14).quietoSurface(cornerRadius: QuietoRadius.card)
                Text("Une IA, pas un professionnel de santé.").font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
            }
        } footer: {
            OnboardingPrimaryButton(title: model.louaneDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Passer" : "Envoyer") {
                focused = false
                model.submitLouane()
            }
        }
    }

    private var louaneReply: some View {
        page {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) { LouaneMark(size: 34); Text("Louane").font(QuietoFont.sans(.body, weight: .semibold)) }
                OnboardingBubbles(bubbles: model.louaneReply.isEmpty ? OnboardingLouaneScript.reply(to: "", answers: model.answers, firstSession: nil) : model.louaneReply)
            }
        } footer: { OnboardingPrimaryButton(title: "Continuer", action: model.next) }
    }

    private var health: some View {
        page {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "heart.fill").font(.system(size: 44)).foregroundStyle(QuietoColor.coral)
                OnboardingTitle(title: "Relier Apple Santé ?", subtitle: "Quieto enregistre tes séances en minutes de pleine conscience, et peut tenir compte de ton sommeil. Ces données restent sur ton iPhone.")
            }
            .padding(.top, 40)
        } footer: {
            OnboardingPrimaryButton(title: model.isWorking ? "…" : "Relier Apple Santé", enabled: !model.isWorking, action: model.requestHealth)
            OnboardingSecondaryButton(title: "Plus tard", action: model.next)
        }
    }

    private var reminders: some View {
        page {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "bell.badge").font(.system(size: 44, weight: .light)).foregroundStyle(QuietoColor.mint)
                OnboardingTitle(title: "Un rappel doux, chaque jour ?", subtitle: "Les gens qui pratiquent à heure fixe tiennent plus facilement. Tu pourras le changer à tout moment.")
                DatePicker("Heure du rappel", selection: Binding(
                    get: { Calendar.current.date(bySettingHour: model.answers.reminderHour, minute: model.answers.reminderMinute, second: 0, of: .now) ?? .now },
                    set: { date in
                        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                        model.answers.reminderHour = parts.hour ?? 21
                        model.answers.reminderMinute = parts.minute ?? 30
                    }
                ), displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel).labelsHidden().colorScheme(.dark).frame(maxWidth: .infinity)
            }
        } footer: {
            OnboardingPrimaryButton(title: model.isWorking ? "…" : "Activer le rappel", enabled: !model.isWorking, action: model.requestReminders)
            OnboardingSecondaryButton(title: "Pas maintenant", action: model.next)
        }
    }

    private var commitment: some View {
        let minutes = Int(model.answers.single(.minutes) ?? "5") ?? 5
        return page {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "hand.raised").font(.system(size: 44, weight: .light)).foregroundStyle(QuietoColor.mint)
                OnboardingTitle(title: "Un engagement envers toi.", subtitle: QuietoLocalization.format("Pendant 7 jours, je prends %d minutes pour moi. Rien de plus, rien de moins.", minutes))
            }
            .padding(.top, 40)
        } footer: {
            OnboardingHoldButton(title: "Maintiens pour t’engager") {
                model.answers.committed = true
                Task { try? await Task.sleep(nanoseconds: 600_000_000); model.next() }
            }
        }
    }

    private var account: some View {
        page {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "icloud.and.arrow.up").font(.system(size: 44, weight: .light)).foregroundStyle(QuietoColor.mint)
                OnboardingTitle(title: "Garder ta progression ?", subtitle: "Avec ton compte Apple, tu retrouves ton programme et tes échanges avec Louane sur un nouvel iPhone. Tu avais déjà un compte Quieto ? Il sera retrouvé.")
            }
            .padding(.top, 40)
        } footer: {
            Button(action: model.signInWithApple) {
                HStack { Image(systemName: "apple.logo"); Text((model.isWorking ? "Connexion…" : "Continuer avec Apple").quietoLocalized).font(QuietoFont.sans(.body, weight: .semibold)) }
                    .foregroundStyle(.black).frame(maxWidth: .infinity).frame(minHeight: 54).background(.white, in: Capsule())
            }
            .buttonStyle(.plain).disabled(model.isWorking)
            OnboardingSecondaryButton(title: "Plus tard", action: model.next)
        }
    }

    private var building: some View {
        VStack(spacing: 28) {
            Spacer()
            ProgressView().controlSize(.large).tint(QuietoColor.mint)
            Text("Je prépare ton programme…").font(QuietoFont.heading(.title, weight: .semibold))
            OnboardingBuildingChecklist()
            Spacer()
        }
        .padding(.horizontal, 28)
        .onAppear { model.buildPlan() }
    }

    private var profileSummary: some View {
        let answers = model.answers
        let rows: [(String, String)] = [
            ("target", OnboardingContent.label(.goal, answers.single(.goal)) ?? "Retrouver du calme"),
            ("clock", OnboardingContent.label(.hardestTime, answers.single(.hardestTime)) ?? "À tout moment"),
            ("timer", OnboardingContent.label(.minutes, answers.single(.minutes)) ?? "5 minutes"),
            ("figure.mind.and.body", OnboardingContent.label(.experience, answers.single(.experience)) ?? "Débutant·e")
        ]
        return page {
            VStack(alignment: .leading, spacing: 22) {
                OnboardingTitle(title: answers.firstName.isEmpty ? "Ton profil" : QuietoLocalization.format("Ton profil, %@", answers.firstName))
                ForEach(rows, id: \.0) { row in
                    HStack(spacing: 14) {
                        Image(systemName: row.0).foregroundStyle(QuietoColor.mint).frame(width: 28)
                        Text(row.1.quietoLocalized).font(QuietoFont.sans(.body, weight: .medium))
                        Spacer()
                    }
                    .padding(16).quietoSurface(cornerRadius: QuietoRadius.card)
                }
            }
        } footer: { OnboardingPrimaryButton(title: "Voir mon programme", action: model.next) }
    }

    /// The plan reveal: the recommended plan, why, its first week, and two
    /// other plans for « Ce n’est pas tout à fait ça ? ».
    private var planView: some View {
        page {
            VStack(alignment: .leading, spacing: 16) {
                if let plan = model.plan {
                    Text((plan.isRecommended ? "Ton plan recommandé" : "Le plan que tu as choisi").quietoLocalized)
                        .font(QuietoFont.sans(.caption, weight: .semibold)).foregroundStyle(QuietoColor.mint).textCase(.uppercase)
                    OnboardingTitle(title: plan.title, subtitle: plan.promise)
                    if plan.isRecommended, let reason = OnboardingPlanBuilder.reason(for: plan.planID, answers: model.answers) {
                        Label(QuietoLocalization.format("Parce que tu as dit « %@ ».", reason.quietoLocalized), systemImage: "quote.opening")
                            .font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
                    }
                    Text(planSummary(plan)).font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                    ForEach(Array(plan.firstSteps.enumerated()), id: \.element.id) { index, step in
                        OnboardingSessionRow(day: index + 1, session: step.session, isFirst: index == 0)
                    }
                    if model.showsPlanAlternatives {
                        ForEach(plan.alternatives) { id in
                            let alternative = PlanCatalog.plan(id)
                            Button { model.choosePlan(id) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: alternative.symbol).foregroundStyle(QuietoColor.mint).frame(width: 28)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(alternative.title.quietoLocalized).font(QuietoFont.sans(.body, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary)
                                        Text(alternative.promise.quietoLocalized).font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(QuietoColor.textSecondary)
                                }
                                .padding(14).quietoSurface(cornerRadius: QuietoRadius.card)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Button("Ce n’est pas tout à fait ça ?") { model.showsPlanAlternatives = true }
                            .font(QuietoFont.sans(.callout, weight: .medium)).foregroundStyle(QuietoColor.mint)
                    }
                }
            }
        } footer: { OnboardingPrimaryButton(title: "Continuer", action: model.next) }
    }

    private func planSummary(_ plan: OnboardingPlanBuilder.Plan) -> String {
        plan.state.includesDiscovery
            ? QuietoLocalization.format("4 semaines, précédées d’une semaine pour découvrir les bases. Rythme : %@.", plan.state.rhythm.localizedName.lowercased(with: QuietoLocalization.locale))
            : QuietoLocalization.format("4 semaines pour avancer à ton rythme. Rythme : %@.", plan.state.rhythm.localizedName.lowercased(with: QuietoLocalization.locale))
    }

    private var projection: some View {
        page {
            VStack(alignment: .leading, spacing: 22) {
                OnboardingTitle(title: "Là où tu peux aller", subtitle: "Avec une pratique régulière, le stress a tendance à baisser au fil des semaines.")
                OnboardingProjectionChart(start: model.answers.stressBefore)
                    .padding(16).quietoSurface(cornerRadius: QuietoRadius.card)
                Text("Courbe illustrative, pas une promesse. Chaque parcours est différent.").font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
            }
        } footer: { OnboardingPrimaryButton(title: "Continuer", action: model.next) }
    }

    private var included: some View {
        page {
            VStack(alignment: .leading, spacing: 18) {
                OnboardingTitle(title: "Tout est inclus")
                ForEach(["Toutes les séances guidées et respirations", "Louane, jour et nuit", "Ton programme personnalisé", "Les séances hors ligne", "De nouvelles séances régulièrement"], id: \.self) { item in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(QuietoColor.mint)
                        Text(item.quietoLocalized).font(QuietoFont.sans(.body))
                    }
                }
            }
        } footer: { OnboardingPrimaryButton(title: "Continuer", action: model.next) }
    }

    private var trialTimeline: some View {
        let reminderDay = max(1, OnboardingLinks.trialDays - 2)
        let items: [(String, String, String)] = [
            ("lock.open.fill", "Aujourd’hui", "Accès complet à Quieto. Ta première séance t’attend."),
            ("bell.fill", QuietoLocalization.format("Jour %d", reminderDay), "On te prévient que ton essai se termine bientôt."),
            ("star.fill", QuietoLocalization.format("Jour %d", OnboardingLinks.trialDays), "Ton abonnement démarre. Résiliable à tout moment, en deux taps, avant cette date.")
        ]
        return page {
            VStack(alignment: .leading, spacing: 26) {
                OnboardingTitle(title: QuietoLocalization.format("%d jours pour essayer, sans engagement", OnboardingLinks.trialDays))
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 16) {
                            VStack(spacing: 0) {
                                Image(systemName: item.0).font(.system(size: 15)).foregroundStyle(QuietoColor.background)
                                    .frame(width: QuietoMetrics.playSmall, height: QuietoMetrics.playSmall).background(QuietoColor.mintFill, in: Circle())
                                if index < items.count - 1 { Rectangle().fill(QuietoColor.mint.opacity(0.4)).frame(width: 3, height: 46) }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.1.quietoLocalized).font(QuietoFont.sans(.body, weight: .semibold))
                                Text(item.2.quietoLocalized).font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
                            }
                        }
                    }
                }
            }
        } footer: { OnboardingPrimaryButton(title: "Continuer", action: model.next) }
    }

    private func paywall(relaunch: Bool) -> some View {
        page {
            VStack(alignment: .leading, spacing: 22) {
                OnboardingTitle(
                    title: relaunch ? "Ton programme t’attend." : (model.answers.firstName.isEmpty ? "Ton programme est prêt." : QuietoLocalization.format("%@, ton programme est prêt.", model.answers.firstName)),
                    subtitle: relaunch
                        ? QuietoLocalization.format("%@ : 4 semaines pensées pour toi, Louane et toutes les respirations. Essaie gratuitement, tu peux arrêter quand tu veux.", (model.plan?.title ?? "Ton programme").quietoLocalized)
                        : QuietoLocalization.format("Commence ton essai gratuit de %d jours pour tout débloquer.", OnboardingLinks.trialDays)
                )
                if let first = model.plan?.firstSteps.first { OnboardingSessionRow(day: 1, session: first.session, isFirst: true) }
                if let note = model.paywallNote {
                    Text(note.quietoLocalized).font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
                }
            }
        } footer: {
            OnboardingPrimaryButton(title: "Commencer mon essai gratuit", action: model.presentPaywall)
            OnboardingSecondaryButton(title: "Restaurer mes achats", action: model.restore)
            Text(CrisisLine.current.helpLine).font(QuietoFont.sans(.overline)).foregroundStyle(QuietoColor.textSecondary).multilineTextAlignment(.center)
            OnboardingLegalLinks()
        }
        .onAppear { if !relaunch { model.presentPaywall() } }
    }

    private var welcome: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "sparkles").font(.system(size: 46, weight: .light)).foregroundStyle(QuietoColor.mint)
            Text(model.answers.firstName.isEmpty ? "Bienvenue dans Quieto.".quietoLocalized : QuietoLocalization.format("Bienvenue, %@.", model.answers.firstName))
                .font(QuietoFont.heading(.display, weight: .semibold)).multilineTextAlignment(.center)
            Text("Ta première séance t’attend. Installe-toi, on commence doucement.").font(QuietoFont.sans(.body)).foregroundStyle(QuietoColor.textSecondary).multilineTextAlignment(.center)
            Spacer()
            OnboardingPrimaryButton(title: "Commencer ma première séance") { model.finish(playFirstSession: true) }
            OnboardingSecondaryButton(title: "Découvrir l’app") { model.finish(playFirstSession: false) }
        }
        .padding(.horizontal, QuietoSpacing.lg).padding(.bottom, 12)
        .task { await model.scheduleTrialEndingReminder() }
    }
}

private struct OnboardingBuildingChecklist: View {
    @State private var done = 0
    private let items = ["Analyse de tes réponses", "Choix des séances", "Réglage des durées", "Ton programme sur 7 jours"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 12) {
                    Image(systemName: index < done ? "checkmark.circle.fill" : "circle").foregroundStyle(index < done ? QuietoColor.mint : QuietoColor.textSecondary)
                    Text(item.quietoLocalized).font(QuietoFont.sans(.body)).foregroundStyle(index < done ? QuietoColor.textPrimary : QuietoColor.textSecondary)
                }
            }
        }
        .task {
            for index in items.indices {
                try? await Task.sleep(nanoseconds: 950_000_000)
                withAnimation(.easeOut(duration: 0.25)) { done = index + 1 }
            }
        }
    }
}
