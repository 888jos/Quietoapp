import SwiftUI

// MARK: - Shared pieces

/// The night sky with a few stars rising slowly: the calm way Quieto
/// celebrates (no confetti). Static with « Réduire les animations ».
struct CelebrationBackdrop: View {
    var intensity: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Star { let x: Double; let speed: Double; let size: Double; let phase: Double }
    private static let stars: [Star] = (0..<34).map { index in
        let seed = Double(index)
        return Star(
            x: (seed * 0.618).truncatingRemainder(dividingBy: 1),
            speed: 0.025 + (seed * 0.37).truncatingRemainder(dividingBy: 1) * 0.04,
            size: 1.5 + (seed * 0.73).truncatingRemainder(dividingBy: 1) * 2.5,
            phase: (seed * 0.41).truncatingRemainder(dividingBy: 1)
        )
    }

    var body: some View {
        ZStack {
            QuietoBackground()
            RadialGradient(colors: [QuietoColor.mint.opacity(0.22 * intensity), .clear], center: .center, startRadius: 10, endRadius: 320)
                .offset(y: -80)
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    for star in Self.stars {
                        let progress = (star.phase + time * star.speed).truncatingRemainder(dividingBy: 1)
                        let y = size.height * (1 - progress)
                        let x = size.width * star.x + sin(time * 0.6 + star.phase * 6) * 8
                        let alpha = sin(progress * .pi) * 0.75 * intensity
                        let rect = CGRect(x: x, y: y, width: star.size, height: star.size)
                        context.fill(Path(ellipseIn: rect), with: .color(QuietoColor.mintLight.opacity(alpha)))
                    }
                }
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

/// Elements of a celebration arrive one after the other.
private struct Staggered: ViewModifier {
    let index: Int
    let appeared: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 14)
            .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.55, dampingFraction: 0.82).delay(0.12 + Double(index) * 0.15), value: appeared)
    }
}

extension View {
    fileprivate func staggered(_ index: Int, _ appeared: Bool) -> some View { modifier(Staggered(index: index, appeared: appeared)) }
}

/// Full-screen layout: content in the middle, buttons at the bottom.
private struct CelebrationPage<Content: View, Buttons: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let buttons: Buttons

    var body: some View {
        VStack(spacing: QuietoSpacing.lg) {
            Spacer(minLength: QuietoSpacing.lg)
            content
            Spacer(minLength: QuietoSpacing.lg)
            VStack(spacing: 12) { buttons }
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(QuietoColor.textPrimary)
        .padding(.horizontal, QuietoSpacing.md)
        .padding(.bottom, QuietoSpacing.lg)
        .frame(maxWidth: QuietoMetrics.contentMaxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Number that rolls from one value to the next.
struct RollingNumber: View {
    let from: Int
    let to: Int
    var font: Font = QuietoFont.heading(.numeral, weight: .bold)
    @State private var value: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(from: Int, to: Int, font: Font = QuietoFont.heading(.numeral, weight: .bold)) {
        self.from = from; self.to = to; self.font = font
        _value = State(initialValue: from)
    }

    var body: some View {
        Text(verbatim: "\(value)")
            .font(font)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(value)))
            .onAppear {
                guard from != to else { return }
                withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.7).delay(0.45)) { value = to }
            }
            .onChange(of: to) { _, newValue in withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { value = newValue } }
    }
}

/// A badge that goes from grey to colour while its ring closes, then a
/// light sweeps across it. Surprises turn over from a question mark.
struct BadgeReveal: View {
    let state: BadgeState
    var size: CGFloat = 168
    @State private var revealed = false
    @State private var shine = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().fill(QuietoColor.mint.opacity(revealed ? 0.16 : 0)).frame(width: size * 1.45, height: size * 1.45).blur(radius: 18)
            Circle()
                .trim(from: 0, to: revealed ? 1 : 0)
                .stroke(QuietoColor.mint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size + 22, height: size + 22)
            ZStack {
                if state.badge.isHidden && !revealed {
                    Circle().fill(QuietoColor.surfaceRaised)
                    Image(systemName: "questionmark").font(.system(size: size * 0.36, weight: .medium)).foregroundStyle(QuietoColor.aurora)
                } else {
                    BadgeMedal(state: BadgeState(badge: state.badge, unlockedAt: .now, current: 1, target: 1), size: size)
                        .saturation(revealed ? 1 : 0)
                        .opacity(revealed ? 1 : 0.55)
                }
            }
            .frame(width: size, height: size)
            .overlay {
                LinearGradient(colors: [.clear, .white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: size * 0.4)
                    .rotationEffect(.degrees(20))
                    .offset(x: shine ? size : -size)
                    .blendMode(.plusLighter)
            }
            .clipShape(Circle())
            .rotation3DEffect(.degrees(state.badge.isHidden && !reduceMotion ? (revealed ? 360 : 180) : 0), axis: (x: 0, y: 1, z: 0))
            .scaleEffect(revealed || reduceMotion ? 1 : 0.86)
        }
        .frame(width: size * 1.45, height: size * 1.45)
        .accessibilityHidden(true)
        .sensoryFeedback(.success, trigger: revealed)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.8, dampingFraction: 0.72).delay(0.35)) { revealed = true }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).delay(1.15)) { shine = true }
        }
    }
}

/// The seven days of the week; today fills with a beat of delay.
struct CelebrationWeek: View {
    let week: [WeekDayStatus]
    var animateToday = true
    var size: CGFloat = 30
    @State private var filled = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(week) { day in
                VStack(spacing: 5) {
                    WeekDayDot(day: day.isToday && animateToday && !filled ? WeekDayStatus(date: day.date, letter: day.letter, state: .today, isToday: true) : day, size: size)
                        .scaleEffect(day.isToday && filled ? 1.0 : (day.isToday && animateToday ? 0.9 : 1))
                    Text(day.letter).font(QuietoFont.sans(.caption, weight: day.isToday ? .bold : .medium))
                        .foregroundStyle(day.isToday ? QuietoColor.textPrimary : QuietoColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
        .sensoryFeedback(.impact(weight: .light), trigger: filled)
        .onAppear { withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.9)) { filled = true } }
    }
}

// MARK: - 1 & 2 · End of session: streak +1, plan step, badges

/// Under « Bien joué »: what this session changed.
struct SessionProgressBlock: View {
    let outcome: SessionOutcome
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 14) {
            if outcome.dayAdded {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "leaf.fill").font(.system(size: 22, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                        RollingNumber(from: outcome.streakBefore, to: outcome.streak.current, font: QuietoFont.heading(.display, weight: .bold))
                        Text((outcome.streak.current > 1 ? "jours de suite" : "jour de suite").quietoLocalized)
                            .font(QuietoFont.sans(.callout, weight: .semibold)).foregroundStyle(QuietoColor.textSecondary)
                    }
                    if !outcome.week.isEmpty { CelebrationWeek(week: outcome.week, size: 26) }
                    Text(Self.streakLine(outcome.streak.current)).font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .quietoSurface(cornerRadius: QuietoRadius.card)
                .staggered(0, appeared)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(QuietoLocalization.format("Série : %@", AchievementsViewModel.daysLabel(outcome.streak.current)))
            }
            if let step = outcome.planStep {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(step.planTitle.quietoLocalized).font(QuietoFont.sans(.callout, weight: .semibold))
                        Spacer()
                        Text(QuietoLocalization.format("Étape %d sur %d", step.number, step.total)).font(QuietoFont.sans(.subhead, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                    }
                    PlanProgressBar(value: step.number, total: step.total)
                    if let wait = step.waitLabel {
                        Text(wait).font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                    }
                }
                .multilineTextAlignment(.leading)
                .padding(14)
                .quietoSurface(cornerRadius: QuietoRadius.card)
                .staggered(1, appeared)
            }
            if !outcome.badges.isEmpty {
                HStack(spacing: 10) {
                    ForEach(outcome.badges.prefix(3)) { badge in
                        BadgeMedal(state: BadgeState(badge: badge, unlockedAt: .now, current: 1, target: 1), size: 34)
                    }
                    Text(outcome.badges.count == 1
                         ? QuietoLocalization.format("Nouveau badge : %@", outcome.badges[0].title.quietoLocalized)
                         : QuietoLocalization.format("%d nouveaux badges", outcome.badges.count))
                        .font(QuietoFont.sans(.subhead, weight: .semibold))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .quietoSurface(cornerRadius: QuietoRadius.card)
                .staggered(2, appeared)
            }
        }
        .onAppear { appeared = true }
    }

    static func streakLine(_ days: Int) -> String {
        switch days {
        case ...1: "Ta série commence aujourd’hui."
        case 2: "Deux jours de suite. Tu prends le rythme."
        default:
            if let next = StreakMilestones.next(after: days) {
                QuietoLocalization.format("Prochain cap : %@.", AchievementsViewModel.daysLabel(next))
            } else {
                "Tu prends soin de toi chaque jour."
            }
        }
    }
}

/// Progress of the plan, filling once the screen is shown.
struct PlanProgressBar: View {
    let value: Int
    let total: Int
    @State private var shown = 0.0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(QuietoColor.divider)
                Capsule().fill(QuietoColor.mintFill).frame(width: proxy.size.width * shown)
            }
        }
        .frame(height: 8)
        .onAppear {
            shown = Double(max(0, value - 1)) / Double(max(total, 1))
            withAnimation(.easeInOut(duration: 0.8).delay(0.6)) { shown = Double(value) / Double(max(total, 1)) }
        }
    }
}

// MARK: - 3 · Streak milestone

struct StreakMilestoneView: View {
    let days: Int
    let best: Int
    let badge: Badge?
    let onClose: () -> Void
    @State private var appeared = false
    @State private var breathe = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CelebrationPage {
            VStack(spacing: 18) {
                ZStack {
                    Circle().fill(QuietoColor.mint.opacity(0.14)).frame(width: 230, height: 230).scaleEffect(breathe ? 1.06 : 0.94).blur(radius: 6)
                    Circle().stroke(QuietoColor.mint.opacity(0.35), lineWidth: 1.5).frame(width: 200, height: 200).scaleEffect(breathe ? 1.03 : 0.97)
                    RollingNumber(from: max(0, days - 1), to: days, font: QuietoFont.heading(110, weight: .bold))
                        .foregroundStyle(QuietoColor.mintLight)
                        .quietoGlow(radius: 24)
                }
                .staggered(0, appeared)
                Text("jours de suite".quietoLocalized).font(QuietoFont.heading(.title)).staggered(1, appeared)
                Text(StreakMilestones.line(for: days).quietoLocalized).font(QuietoFont.sans(.body)).foregroundStyle(QuietoColor.textSecondary).staggered(2, appeared)
                HStack(spacing: 12) {
                    if let badge {
                        BadgeMedal(state: BadgeState(badge: badge, unlockedAt: .now, current: 1, target: 1), size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Nouveau badge").quietoOverline().foregroundStyle(QuietoColor.mint)
                            Text(badge.title.quietoLocalized).font(QuietoFont.sans(.callout, weight: .semibold))
                        }
                        Spacer(minLength: 0)
                    }
                    VStack(alignment: badge == nil ? .center : .trailing, spacing: 2) {
                        Text("Meilleure série").quietoOverline().foregroundStyle(QuietoColor.textSecondary)
                        Text(AchievementsViewModel.daysLabel(best)).font(QuietoFont.sans(.callout, weight: .semibold))
                    }
                    .frame(maxWidth: badge == nil ? .infinity : nil)
                }
                .multilineTextAlignment(.leading)
                .padding(14)
                .quietoSurface(cornerRadius: QuietoRadius.card)
                .staggered(3, appeared)
                if let next = StreakMilestones.next(after: days) {
                    Text(QuietoLocalization.format("Prochain cap : %@.", AchievementsViewModel.daysLabel(next)))
                        .font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary).staggered(4, appeared)
                }
            }
        } buttons: {
            QuietoPrimaryButton(title: "Continuer", systemImage: nil, action: onClose)
        }
        .background(CelebrationBackdrop())
        .sensoryFeedback(.success, trigger: appeared)
        .accessibilityElement(children: .contain)
        .onAppear {
            appeared = true
            UIAccessibility.post(notification: .announcement, argument: QuietoLocalization.format("Série : %@", AchievementsViewModel.daysLabel(days)))
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}

// MARK: - 4 & 5 · Badges (surprises turn over)

struct BadgeUnlockedView: View {
    let badges: [BadgeState]
    let unlockedCount: Int
    let totalCount: Int
    /// The next badge of the same family, for « Prochain : … ».
    let next: (Badge) -> BadgeState?
    let onCollection: () -> Void
    let onClose: () -> Void
    @State private var page = 0

    var body: some View {
        CelebrationPage {
            TabView(selection: $page) {
                ForEach(Array(badges.enumerated()), id: \.element.id) { index, state in
                    BadgeUnlockedPage(state: state, next: next(state.badge)).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: badges.count > 1 ? .always : .never))
            .frame(minHeight: 520)
            Text(QuietoLocalization.format("%d badges sur %d", unlockedCount, totalCount))
                .font(QuietoFont.sans(.subhead, weight: .semibold)).foregroundStyle(QuietoColor.textSecondary)
        } buttons: {
            if page < badges.count - 1 {
                QuietoPrimaryButton(title: "Suivant", systemImage: nil) { withAnimation { page += 1 } }
            } else {
                QuietoPrimaryButton(title: "Continuer", systemImage: nil, action: onClose)
            }
            QuietoOutlineButton(title: "Voir ma collection", systemImage: "rosette", action: onCollection)
        }
        .background(CelebrationBackdrop(intensity: badges.contains { $0.badge.isHidden } ? 0.7 : 1))
    }
}

private struct BadgeUnlockedPage: View {
    let state: BadgeState
    let next: BadgeState?
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 14) {
            BadgeReveal(state: state)
            Text((state.badge.isHidden ? "Badge surprise" : "Nouveau badge").quietoLocalized)
                .quietoOverline().foregroundStyle(state.badge.isHidden ? QuietoColor.aurora : QuietoColor.mint)
                .staggered(0, appeared)
            Text(state.badge.title.quietoLocalized).font(QuietoFont.heading(.display, weight: .semibold)).staggered(1, appeared)
            Text(state.badge.detail.quietoLocalized).font(QuietoFont.sans(.body)).foregroundStyle(QuietoColor.textSecondary).staggered(2, appeared)
            if let next {
                HStack(spacing: 12) {
                    BadgeMedal(state: next, size: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(QuietoLocalization.format("Prochain : %@", next.badge.title.quietoLocalized)).font(QuietoFont.sans(.subhead, weight: .semibold))
                        ProgressView(value: next.fraction).tint(QuietoColor.mint)
                    }
                    Text(verbatim: "\(next.current)/\(next.target)").font(QuietoFont.sans(.caption, weight: .semibold)).foregroundStyle(QuietoColor.textSecondary).monospacedDigit()
                }
                .multilineTextAlignment(.leading)
                .padding(14)
                .quietoSurface(cornerRadius: QuietoRadius.card)
                .staggered(3, appeared)
            }
        }
        .padding(.horizontal, 2)
        .onAppear {
            appeared = true
            UIAccessibility.post(notification: .announcement, argument: QuietoLocalization.format("Nouveau badge : %@", state.badge.title.quietoLocalized))
        }
    }
}

// MARK: - 8 · Welcome back

struct WelcomeBackView: View {
    let best: Int
    let daysAway: Int
    let onClose: () -> Void
    @State private var appeared = false
    @State private var sunrise = false

    var body: some View {
        CelebrationPage {
            VStack(spacing: 18) {
                // A sun rising behind a soft horizon line.
                ZStack(alignment: .bottom) {
                    RadialGradient(colors: [QuietoColor.mint.opacity(sunrise ? 0.35 : 0), .clear], center: .bottom, startRadius: 0, endRadius: 150)
                        .frame(width: 300, height: 150)
                    Circle().fill(LinearGradient(colors: [QuietoColor.mintLight, QuietoColor.mint.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 130, height: 130)
                        .offset(y: sunrise ? 20 : 120)
                        .mask(LinearGradient(colors: [.black, .black, .black.opacity(0)], startPoint: .top, endPoint: .bottom).frame(height: 150))
                    Capsule().fill(LinearGradient(colors: [.clear, QuietoColor.mint.opacity(0.7), .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 260, height: 2)
                }
                .frame(width: 300, height: 150)
                .clipped()
                Text("Content·e de te revoir".quietoLocalized).font(QuietoFont.heading(.display, weight: .semibold)).staggered(0, appeared)
                Text("On repart d’aujourd’hui, à ton rythme. Revenir fait partie du chemin.".quietoLocalized)
                    .font(QuietoFont.sans(.body)).foregroundStyle(QuietoColor.textSecondary).staggered(1, appeared)
                if best > 1 {
                    Label(QuietoLocalization.format("Ta meilleure série reste : %@", AchievementsViewModel.daysLabel(best)), systemImage: "leaf.fill")
                        .font(QuietoFont.sans(.callout, weight: .semibold))
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .quietoSurface(cornerRadius: QuietoRadius.card)
                        .staggered(2, appeared)
                }
            }
        } buttons: {
            QuietoPrimaryButton(title: "Continuer", systemImage: nil, action: onClose)
        }
        .background(CelebrationBackdrop(intensity: 0.6))
        .onAppear {
            appeared = true
            withAnimation(.easeOut(duration: 1.6).delay(0.2)) { sunrise = true }
        }
    }
}

// MARK: - 9 · A week of the plan

struct PlanWeekDoneView: View {
    let recap: PlanWeekRecap
    let onContinue: () -> Void
    @State private var appeared = false
    @State private var lit = false

    var body: some View {
        CelebrationPage {
            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    ForEach(0..<recap.weeksTotal, id: \.self) { index in
                        Capsule()
                            .fill(index < recap.weeksDone - 1 || (index == recap.weeksDone - 1 && lit) ? AnyShapeStyle(QuietoColor.mintFill) : AnyShapeStyle(QuietoColor.divider))
                            .frame(height: 10)
                            .shadow(color: index == recap.weeksDone - 1 && lit ? QuietoColor.mint.opacity(0.7) : .clear, radius: 8)
                    }
                }
                .padding(.horizontal, 24)
                Text(recap.planTitle.quietoLocalized).quietoOverline().foregroundStyle(QuietoColor.mint).staggered(0, appeared)
                Text(recap.week == 0 ? "Semaine Découverte terminée".quietoLocalized : QuietoLocalization.format("Semaine %d terminée", recap.week))
                    .font(QuietoFont.heading(.display, weight: .semibold)).staggered(1, appeared)
                VStack(spacing: 8) {
                    ForEach(Array(recap.sessions.enumerated()), id: \.offset) { _, session in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(QuietoColor.mint)
                            Text(session.title.quietoLocalized).font(QuietoFont.sans(.callout))
                            Spacer()
                            Text(QuietoLocalization.format("%d min", session.durationMinutes)).font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
                        }
                    }
                }
                .multilineTextAlignment(.leading)
                .padding(14)
                .quietoSurface(cornerRadius: QuietoRadius.card)
                .staggered(2, appeared)
                if let phase = recap.nextPhase {
                    HStack(alignment: .top, spacing: 10) {
                        LouaneMark(size: 22)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(QuietoLocalization.format("Ensuite : %@", phase.title.quietoLocalized)).font(QuietoFont.sans(.callout, weight: .semibold))
                            Text(phase.louaneNote.quietoLocalized).font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .staggered(3, appeared)
                }
            }
        } buttons: {
            QuietoPrimaryButton(title: recap.week == 0 ? "Commencer mon plan" : QuietoLocalization.format("Commencer la semaine %d", recap.week + 1), systemImage: nil, action: onContinue)
        }
        .background(CelebrationBackdrop(intensity: 0.8))
        .sensoryFeedback(.success, trigger: lit)
        .onAppear {
            appeared = true
            withAnimation(.easeInOut(duration: 0.7).delay(0.5)) { lit = true }
        }
    }
}

// MARK: - 10 · Plan finished

struct PlanFinishedView: View {
    let recap: PlanRecap
    let onNextPlan: () -> Void
    let onClose: () -> Void
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                PlanFinishedTitle(recap: recap).tag(0)
                PlanFinishedFigures(recap: recap).tag(1)
                if recap.stress.count >= 2 { PlanFinishedStress(levels: recap.stress).tag(2) }
                PlanFinishedLouane(recap: recap).tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            VStack(spacing: 12) {
                if page == 3 {
                    QuietoPrimaryButton(title: "Choisir mon prochain plan", systemImage: "map", action: onNextPlan)
                    QuietoOutlineButton(title: "Fermer", systemImage: nil, action: onClose)
                } else {
                    QuietoPrimaryButton(title: "Suivant", systemImage: nil) {
                        withAnimation { page = page == 1 && recap.stress.count < 2 ? 3 : page + 1 }
                    }
                }
            }
            .padding(.horizontal, QuietoSpacing.md)
            .padding(.bottom, QuietoSpacing.lg)
            .frame(maxWidth: QuietoMetrics.contentMaxWidth)
        }
        .foregroundStyle(QuietoColor.textPrimary)
        .multilineTextAlignment(.center)
        .background(CelebrationBackdrop(intensity: 1.3))
    }
}

private struct PlanFinishedTitle: View {
    let recap: PlanRecap
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            BadgeReveal(state: BadgeState(badge: Badge.all.first { $0.id == "program_finished" }!, unlockedAt: .now, current: 1, target: 1), size: 150)
            Text("Plan terminé").quietoOverline().foregroundStyle(QuietoColor.mint).staggered(0, appeared)
            Text(QuietoLocalization.format("Tu as terminé « %@ »", recap.planTitle.quietoLocalized)).font(QuietoFont.heading(.display, weight: .semibold)).staggered(1, appeared)
            Text("Quatre semaines à prendre soin de toi. Ce chemin, c’est toi qui l’as fait.".quietoLocalized)
                .font(QuietoFont.sans(.body)).foregroundStyle(QuietoColor.textSecondary).staggered(2, appeared)
            Spacer()
        }
        .padding(.horizontal, QuietoSpacing.md)
        .onAppear { appeared = true }
    }
}

private struct PlanFinishedFigures: View {
    let recap: PlanRecap
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Ton plan en chiffres").font(QuietoFont.heading(.title, weight: .semibold))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                figure(recap.days, "étapes faites", 0)
                figure(recap.minutes, "minutes pour toi", 1)
                figure(recap.sessions, "séances différentes", 2)
                figure(4, "semaines", 3)
            }
            if let favourite = recap.favourite {
                HStack(spacing: 12) {
                    QuietoAssetImage(favourite.imageName, contentMode: .fill).frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: QuietoRadius.small))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Ta séance préférée").quietoOverline().foregroundStyle(QuietoColor.mint)
                        Text(favourite.title.quietoLocalized).font(QuietoFont.sans(.callout, weight: .semibold))
                    }
                    Spacer(minLength: 0)
                }
                .multilineTextAlignment(.leading)
                .padding(12)
                .quietoSurface(cornerRadius: QuietoRadius.card)
                .staggered(4, appeared)
            }
            Spacer()
        }
        .padding(.horizontal, QuietoSpacing.md)
        .onAppear { appeared = true }
    }

    private func figure(_ value: Int, _ label: String, _ index: Int) -> some View {
        VStack(spacing: 4) {
            RollingNumber(from: 0, to: value, font: QuietoFont.heading(.hero, weight: .bold)).foregroundStyle(QuietoColor.mintLight)
            Text(label.quietoLocalized).font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 110)
        .quietoSurface(cornerRadius: QuietoRadius.card)
        .staggered(index, appeared)
    }
}

private struct PlanFinishedStress: View {
    let levels: [Int]
    @State private var drawn = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Ton stress, au fil du plan").font(QuietoFont.heading(.title, weight: .semibold))
            GeometryReader { proxy in
                let points = levels.enumerated().map { index, level in
                    CGPoint(x: proxy.size.width * CGFloat(index) / CGFloat(max(1, levels.count - 1)),
                            y: proxy.size.height * (1 - CGFloat(level) / 10))
                }
                ZStack {
                    Path { path in
                        guard let first = points.first else { return }
                        path.move(to: first)
                        points.dropFirst().forEach { path.addLine(to: $0) }
                    }
                    .trim(from: 0, to: drawn ? 1 : 0)
                    .stroke(QuietoColor.mint, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                        VStack(spacing: 4) {
                            Text(verbatim: "\(levels[index])").font(QuietoFont.sans(.callout, weight: .bold))
                            Circle().fill(QuietoColor.mintLight).frame(width: 12, height: 12)
                        }
                        .position(x: point.x, y: point.y - 12)
                        .opacity(drawn ? 1 : 0)
                    }
                }
            }
            .frame(height: 180)
            .padding(.horizontal, 24)
            HStack {
                Text("Début").font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
                Spacer()
                Text("Fin").font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
            }
            .padding(.horizontal, 24)
            Text(stressLine).font(QuietoFont.sans(.body)).foregroundStyle(QuietoColor.textSecondary)
            Text("Ce que tu as noté, sans valeur médicale. Tes réponses restent sur ton iPhone.".quietoLocalized)
                .font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
            Spacer()
        }
        .padding(.horizontal, QuietoSpacing.md)
        .onAppear { withAnimation(.easeInOut(duration: 1.2).delay(0.3)) { drawn = true } }
    }

    private var stressLine: String {
        guard let first = levels.first, let last = levels.last else { return "" }
        if last < first { return QuietoLocalization.format("De %d à %d : ton stress a baissé pendant ces quatre semaines.", first, last) }
        return "Certaines périodes pèsent plus que d’autres. Continuer à prendre ces pauses reste précieux.".quietoLocalized
    }
}

private struct PlanFinishedLouane: View {
    let recap: PlanRecap
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            LouaneMark(size: 54).staggered(0, appeared)
            Text("Un mot de Louane").quietoOverline().foregroundStyle(QuietoColor.mint).staggered(1, appeared)
            Text(QuietoLocalization.format("Bravo pour ces %d étapes. Garde les gestes qui t’ont fait du bien, ils sont à toi maintenant. Quand tu veux, on continue avec un nouveau plan.", recap.days))
                .font(QuietoFont.heading(.section, weight: .regular))
                .staggered(2, appeared)
            Spacer()
        }
        .padding(.horizontal, QuietoSpacing.md)
        .onAppear { appeared = true }
    }
}

// MARK: - 6, 7 & 11 · Home notices

struct HomeNoticeCard: View {
    let notice: HomeNotice
    let onPlay: (QuietoSession) -> Void
    let onOpenJourney: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            content
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(QuietoColor.textSecondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fermer")
        }
        .padding(14)
        .background(background, in: RoundedRectangle(cornerRadius: QuietoRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: QuietoRadius.card, style: .continuous).stroke(QuietoColor.mint.opacity(0.25)))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var background: some ShapeStyle {
        switch notice {
        case .streakAtRisk: AnyShapeStyle(QuietoColor.mint.opacity(0.14))
        default: AnyShapeStyle(QuietoColor.surface)
        }
    }

    @ViewBuilder private var content: some View {
        switch notice {
        case .restDayUsed(let streak):
            Image(systemName: "moon.stars.fill").font(.system(size: 22)).foregroundStyle(QuietoColor.mint).frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text("Ta série tient toujours").font(QuietoFont.sans(.callout, weight: .semibold))
                Text(QuietoLocalization.format("Hier comptait comme ton jour de repos de la semaine. %@ et on continue.", AchievementsViewModel.daysLabel(streak)))
                    .font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
            }
            Spacer(minLength: 0)
        case .streakAtRisk(let streak, let quick):
            Image(systemName: "leaf").font(.system(size: 22, weight: .semibold)).foregroundStyle(QuietoColor.mint).frame(width: 30)
            VStack(alignment: .leading, spacing: 8) {
                Text(QuietoLocalization.format("Une pause de 2 minutes garde ta série de %@.", AchievementsViewModel.daysLabel(streak)))
                    .font(QuietoFont.sans(.callout, weight: .semibold))
                if let quick {
                    Button { onPlay(quick) } label: {
                        Label(quick.title.quietoLocalized, systemImage: "play.fill")
                            .font(QuietoFont.sans(.subhead, weight: .semibold)).foregroundStyle(QuietoColor.background)
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(QuietoColor.mintFill, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        case .weeklyRecap(let week, let minutes, let practices, let next):
            VStack(alignment: .leading, spacing: 10) {
                Text("Ta semaine").quietoOverline().foregroundStyle(QuietoColor.mint)
                CelebrationWeek(week: week, animateToday: false, size: 24)
                Text(QuietoLocalization.format("%d pauses · %d min pour toi", practices, minutes)).font(QuietoFont.sans(.callout, weight: .semibold))
                if let next {
                    Button(action: onOpenJourney) {
                        HStack(spacing: 8) {
                            BadgeMedal(state: next, size: 26)
                            Text(QuietoLocalization.format("Prochain badge : %@", next.badge.title.quietoLocalized)).font(QuietoFont.sans(.subhead))
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(QuietoColor.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
