import SwiftUI

struct ProgramView: View {
    @ObservedObject var model: ProgramViewModel
    /// Shared with the Séances tab so favourites and downloads stay in sync.
    @ObservedObject var sessionModel: SessionsViewModel
    /// Playback state only (which row shows "pause").
    @ObservedObject var audioPlayer: QuietoAudioPlayer
    @State private var selectedSession: QuietoSession?
    @State private var showingRhythm = false
    @State private var confirmingRestart = false
    @State private var situation: QuietoSituation?

    var body: some View {
        NavigationStack {
            ZStack {
                QuietoBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: QuietoSpacing.lg) {
                        header
                        if model.isLoading && !model.hasProgram {
                            ProgressView("Chargement du programme…".quietoLocalized).tint(QuietoColor.mint).frame(maxWidth: .infinity).padding(.vertical, 80)
                        } else if !model.hasProgram {
                            PlanPickerList(recommended: model.recommendation?.plan, current: nil) { model.start($0, source: "programme_tab") }
                        } else {
                            if let error = model.loadError {
                                Label(error.quietoLocalized, systemImage: "wifi.slash").font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                            }
                            if let checkpoint = model.dueStressCheckpoint {
                                StressCheckCard(checkpoint: checkpoint, onSave: model.recordStress)
                                    .id(checkpoint)
                            }
                            todayCard
                        }
                        separator
                        situations
                        if model.hasProgram, !model.steps.isEmpty {
                            separator
                            weeksList
                            settingsCards
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
            .sheet(isPresented: $model.isPlanPickerPresented) {
                NavigationStack {
                    ScrollView {
                        PlanPickerList(recommended: model.recommendation?.plan, current: model.state?.planID) { model.start($0, source: "programme_switch") }
                            .padding(QuietoSpacing.md)
                    }
                    .background(QuietoBackground())
                    .navigationTitle(Text("Changer de plan".quietoLocalized))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { model.isPlanPickerPresented = false } } }
                }
                .presentationDetents([.large])
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
            .confirmationDialog("Recommencer ce plan au jour 1 ?", isPresented: $confirmingRestart, titleVisibility: .visible) {
                Button("Recommencer") { model.restart() }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Tes écoutes et tes badges restent acquis.")
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

    /// The plan, its progress and the step of the day.
    private var todayCard: some View {
        QuietoCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.title.quietoLocalized).font(QuietoFont.heading(.section, weight: .semibold))
                        Text(QuietoLocalization.format("%d étapes faites sur %d", model.completedCount, model.totalCount))
                            .font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                    }
                    Spacer()
                    Text(verbatim: (Double(model.completedCount) / Double(max(model.totalCount, 1))).formatted(.percent.precision(.fractionLength(0)).locale(QuietoLocalization.locale)))
                        .font(QuietoFont.sans(.callout, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                }
                ProgressView(value: Double(model.completedCount), total: Double(max(model.totalCount, 1)))
                    .tint(QuietoColor.mint)
                switch model.today {
                case .available(let step):
                    stepIntro(step)
                    QuietoPrimaryButton(title: QuietoLocalization.format("Étape du jour · %d min", step.session.durationMinutes), systemImage: "play.fill") { play(step.session) }
                case .locked(let next, let opensOn):
                    Label(PlanSchedule.waitLabel(until: opensOn), systemImage: "checkmark.circle.fill")
                        .font(QuietoFont.sans(.callout, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                    Text(QuietoLocalization.format("Prochaine étape : %@", next.session.title.quietoLocalized))
                        .font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                case .finished:
                    Label("Plan terminé", systemImage: "checkmark.seal.fill")
                        .font(QuietoFont.sans(.callout, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                    if model.stressProgression.count > 1 { stressProgression }
                    Text("Continue avec un autre plan, ou refais celui-ci à ton rythme.")
                        .font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                    QuietoPrimaryButton(title: "Choisir mon prochain plan", systemImage: "map") { model.isPlanPickerPresented = true }
                case nil:
                    EmptyView()
                }
            }
        }
    }

    /// The stress check-ins of the plan, side by side, and what changed.
    private var stressProgression: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ton stress au fil du plan").font(QuietoFont.sans(.callout, weight: .semibold))
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(model.stressProgression, id: \.checkpoint) { item in
                    VStack(spacing: 6) {
                        Text(verbatim: "\(item.level)").font(QuietoFont.sans(.callout, weight: .semibold))
                        RoundedRectangle(cornerRadius: 6)
                            .fill(item.checkpoint == .end ? AnyShapeStyle(QuietoColor.mintFill) : AnyShapeStyle(QuietoColor.surfaceRaised))
                            .frame(height: CGFloat(max(item.level, 1)) * 8)
                        Text(item.checkpoint.label.quietoLocalized).font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
            if let summary = model.stressSummary {
                Text(summary).font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
            }
        }
    }

    private func stepIntro(_ step: PlanSchedule.Step) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(QuietoLocalization.format("Étape %d · %@", position(of: step), step.session.title.quietoLocalized))
                .font(QuietoFont.sans(.body, weight: .semibold))
            HStack(alignment: .top, spacing: 8) {
                LouaneMark(size: 18)
                Text(step.day.phase.louaneNote.quietoLocalized).font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
            }
        }
    }

    private var weeksList: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Les étapes de ton plan").font(QuietoFont.section)
            ForEach(model.weeks, id: \.number) { week in
                VStack(alignment: .leading, spacing: 10) {
                    Text(QuietoLocalization.format("Semaine %d · %@", week.number, week.phase.title.quietoLocalized))
                        .font(QuietoFont.sans(.caption, weight: .semibold)).foregroundStyle(QuietoColor.mint).textCase(.uppercase)
                    ForEach(week.steps) { step in stepRow(step) }
                }
            }
        }
    }

    /// 1-based rank among the steps that count with this rhythm (free days
    /// left out with « Régulier » and « Doux »), as in « 3 étapes faites sur 20 ».
    private func position(of step: PlanSchedule.Step) -> Int {
        (model.steps.firstIndex(of: step) ?? 0) + 1
    }

    private func isToday(_ step: PlanSchedule.Step) -> Bool {
        if case .available(let current) = model.today { return current == step }
        return false
    }

    private func stepRow(_ step: PlanSchedule.Step) -> some View {
        let isCurrent = isToday(step)
        let isPlaying = audioPlayer.currentSession?.id == step.session.id && audioPlayer.isPlaying
        return Button { selectedSession = step.session } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(step.isCompleted ? QuietoColor.mint : QuietoColor.surfaceRaised)
                    if step.isCompleted {
                        Image(systemName: "checkmark").foregroundStyle(QuietoColor.background)
                    } else {
                        Text(verbatim: "\(position(of: step))").foregroundStyle(QuietoColor.textPrimary)
                    }
                }
                .font(.system(size: 13, weight: .semibold)).frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(step.session.title.quietoLocalized).font(QuietoFont.heading(.card, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary)
                    Text(QuietoLocalization.format("%d min · %@", step.session.durationMinutes, (step.day.kind == .free ? "Jour libre" : step.session.practiceType.rawValue).quietoLocalized))
                        .font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
                }
                Spacer()
                Button { play(step.session) } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(isCurrent ? QuietoColor.background : QuietoColor.textPrimary)
                        .frame(width: QuietoMetrics.playSmall, height: QuietoMetrics.playSmall)
                        .background(isCurrent ? AnyShapeStyle(QuietoColor.mintFill) : AnyShapeStyle(QuietoColor.surfaceRaised), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(QuietoLocalization.format(isPlaying ? "Mettre en pause %@" : "Lire %@", step.session.title.quietoLocalized))
            }
            .padding(13)
            .quietoSurface(cornerRadius: QuietoMetrics.cornerRadius)
            .overlay {
                if isCurrent { RoundedRectangle(cornerRadius: QuietoMetrics.cornerRadius).strokeBorder(QuietoColor.mint.opacity(0.6), lineWidth: 1) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue((step.isCompleted ? "Faite" : (isCurrent ? "Étape du jour" : "")).quietoLocalized)
    }

    private var settingsCards: some View {
        VStack(spacing: 10) {
            settingRow(title: "Adapter mon rythme", detail: QuietoLocalization.format("%@ · %@", model.rhythm.localizedName, model.rhythm.localizedDetail), symbol: "slider.horizontal.3") { showingRhythm = true }
            QuietoCard {
                Toggle(isOn: Binding(get: { model.state?.prefersShort ?? false }, set: model.setPrefersShort)) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Versions courtes").font(QuietoFont.sans(.callout, weight: .semibold))
                        Text("Les longues séances sont remplacées par une version de 5 minutes ou moins.").font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
                    }
                }
                .tint(QuietoColor.mint)
            }
            settingRow(title: "Changer de plan", detail: "Tes écoutes et tes badges restent acquis.", symbol: "map") { model.isPlanPickerPresented = true }
            Button("Recommencer ce plan au jour 1") { confirmingRestart = true }
                .font(QuietoFont.sans(.subhead, weight: .medium)).foregroundStyle(QuietoColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }

    private func settingRow(title: String, detail: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            QuietoCard {
                HStack(spacing: 12) {
                    Image(systemName: symbol).foregroundStyle(QuietoColor.mint).frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title.quietoLocalized).font(QuietoFont.sans(.callout, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary)
                        Text(detail.quietoLocalized).font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(QuietoColor.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func play(_ session: QuietoSession) {
        sessionModel.playOrPause(session)
    }
}

/// The six plans, the recommended one first and marked.
struct PlanPickerList: View {
    let recommended: QuietoPlanID?
    let current: QuietoPlanID?
    let onChoose: (QuietoPlanID) -> Void

    private var ordered: [QuietoPlan] {
        guard let recommended else { return PlanCatalog.all }
        return PlanCatalog.all.filter { $0.id == recommended } + PlanCatalog.all.filter { $0.id != recommended }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choisis ton plan").font(QuietoFont.heading(.title, weight: .semibold))
            Text("4 semaines, une étape par jour à ton rythme. Tu pourras changer à tout moment.")
                .font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
            ForEach(ordered) { plan in
                Button { onChoose(plan.id) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: plan.symbol).font(.system(size: 20)).foregroundStyle(QuietoColor.mint).frame(width: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(plan.title.quietoLocalized).font(QuietoFont.sans(.body, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary)
                                if plan.id == recommended {
                                    Text("Pour toi").font(QuietoFont.sans(.caption, weight: .semibold)).foregroundStyle(QuietoColor.background)
                                        .padding(.horizontal, 7).padding(.vertical, 2).background(QuietoColor.mintFill, in: Capsule())
                                }
                            }
                            Text(plan.promise.quietoLocalized).font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                            if plan.id == current {
                                Text("Ton plan actuel").font(QuietoFont.sans(.caption, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(QuietoColor.textSecondary)
                    }
                    .padding(14)
                    .quietoSurface(cornerRadius: QuietoRadius.card)
                }
                .buttonStyle(.plain)
                .disabled(plan.id == current)
            }
        }
    }
}

/// The 0-10 slider of the onboarding, asked again on day 0, day 14 and the
/// last day of the plan. The answer stays on the iPhone.
struct StressCheckCard: View {
    let checkpoint: StressCheckpoint
    let onSave: (Int) -> Void
    @State private var value: Double = 5

    var body: some View {
        QuietoCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(checkpoint.title.quietoLocalized).font(QuietoFont.sans(.caption, weight: .semibold)).foregroundStyle(QuietoColor.mint).textCase(.uppercase)
                    Text("Ton niveau de stress cette semaine ?".quietoLocalized).font(QuietoFont.heading(.card, weight: .semibold))
                    Text("De 0 (calme) à 10 (au maximum).".quietoLocalized).font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                }
                OnboardingScale(value: $value)
                QuietoPrimaryButton(title: "Enregistrer", systemImage: "checkmark") { onSave(Int(value.rounded())) }
                Text("Ta réponse reste sur cet iPhone.").font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
            }
        }
    }
}
