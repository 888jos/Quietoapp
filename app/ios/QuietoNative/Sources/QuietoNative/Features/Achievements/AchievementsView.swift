import SwiftUI

/// "Ton parcours": streak, calendar, figures and every badge.
struct AchievementsView: View {
    @ObservedObject var model: AchievementsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                QuietoBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: QuietoSpacing.lg) {
                        streakCard
                        calendarCard
                        figures
                        ForEach(model.categories) { category in
                            badgeSection(category)
                        }
                        Text("Les badges récompensent la régularité, jamais la performance. Une pause d’une minute compte autant qu’une longue séance.")
                            .font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
                    }
                    .frame(maxWidth: QuietoMetrics.contentMaxWidth)
                    .padding(QuietoSpacing.md)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(Text("Ton parcours"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fermer") { dismiss() } } }
            .sheet(item: $model.selectedBadge) { state in
                BadgeDetailView(state: state, progress: model.progressLabel(for: state))
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .preferredColorScheme(.dark)
        .foregroundStyle(QuietoColor.textPrimary)
    }

    private var streakCard: some View {
        QuietoCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Image(systemName: model.streak.practicedToday ? "leaf.fill" : "leaf")
                        .font(.system(size: 28, weight: .medium)).foregroundStyle(QuietoColor.mint)
                        .frame(width: 58, height: 58).background(QuietoColor.surfaceRaised, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.streakTitle).font(QuietoFont.heading(.title, weight: .semibold))
                        Text(model.streakMessage).font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Divider().overlay(QuietoColor.divider)
                HStack {
                    Label(model.restDayLabel, systemImage: model.streak.restDayUsedThisWeek ? "moon.fill" : "moon")
                    Spacer()
                    Text(QuietoLocalization.format("Record : %@", AchievementsViewModel.daysLabel(model.streak.best)))
                }
                .font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var calendarCard: some View {
        QuietoCard {
            VStack(spacing: 12) {
                HStack {
                    Button { model.showPreviousMonth() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .disabled(!model.canShowPreviousMonth).accessibilityLabel("Mois précédent")
                    Spacer()
                    VStack(spacing: 2) {
                        Text(model.monthTitle).font(QuietoFont.heading(.section, weight: .semibold))
                        Text(model.practiceDaysThisMonth == 1 ? "1 jour de pratique".quietoLocalized : QuietoLocalization.format("%d jours de pratique", model.practiceDaysThisMonth))
                            .font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
                    }
                    Spacer()
                    Button { model.showNextMonth() } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                        .disabled(!model.canShowNextMonth).accessibilityLabel("Mois suivant")
                }
                .foregroundStyle(QuietoColor.mint)
                let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(model.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol).font(QuietoFont.sans(.overline, weight: .semibold)).foregroundStyle(QuietoColor.textSecondary)
                    }
                    ForEach(Array(model.monthDays.enumerated()), id: \.offset) { _, day in
                        if let day { CalendarDayCell(day: day) } else { Color.clear.frame(height: 34) }
                    }
                }
            }
        }
    }

    private var figures: some View {
        let stats = model.summary.stats
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            figure("leaf", value: stats.count(.meditation), label: "méditations")
            figure("wind", value: stats.count(.breathing), label: "respirations")
            figure("waveform", value: stats.count(.sound), label: "sons écoutés")
            figure("clock", value: stats.totalMinutes, label: "min de pause")
        }
    }

    private func figure(_ symbol: String, value: Int, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.title3).foregroundStyle(QuietoColor.mint).frame(width: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "\(value)").font(QuietoFont.heading(.section, weight: .semibold))
                Text(label.quietoLocalized).font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .quietoSurface(cornerRadius: QuietoRadius.card)
        .accessibilityElement(children: .combine)
    }

    private func badgeSection(_ category: BadgeCategory) -> some View {
        let badges = model.badges(in: category)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(category.title.quietoLocalized).quietoSectionTitle()
                Spacer()
                Text(verbatim: "\(badges.filter(\.isUnlocked).count)/\(badges.count)").font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12)], spacing: 16) {
                ForEach(badges) { state in
                    Button { model.selectedBadge = state } label: {
                        VStack(spacing: 8) {
                            BadgeMedal(state: state)
                            Text(state.badge.isHidden && !state.isUnlocked ? "???" : state.badge.title.quietoLocalized)
                                .font(QuietoFont.sans(.caption, weight: .medium))
                                .foregroundStyle(state.isUnlocked ? QuietoColor.textPrimary : QuietoColor.textSecondary)
                                .multilineTextAlignment(.center).lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityLabel(for: state))
                }
            }
        }
    }

    private func accessibilityLabel(for state: BadgeState) -> String {
        if state.badge.isHidden && !state.isUnlocked { return "Badge surprise".quietoLocalized }
        let status = state.isUnlocked ? "débloqué".quietoLocalized : model.progressLabel(for: state)
        return QuietoLocalization.format("%@, %@", state.badge.title.quietoLocalized, status)
    }
}

private struct CalendarDayCell: View {
    let day: PracticeCalendarDay

    var body: some View {
        Text(verbatim: "\(day.dayNumber)")
            .font(QuietoFont.sans(.subhead, weight: day.isPracticed ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(day.isPracticed ? QuietoColor.background : (day.isFuture ? QuietoColor.textSecondary.opacity(0.4) : QuietoColor.textSecondary))
            .frame(maxWidth: .infinity, minHeight: 34)
            .background {
                if day.isPracticed {
                    Circle().fill(QuietoColor.mint.opacity(day.minutes >= 10 ? 1 : 0.75))
                }
            }
            .overlay { if day.isToday { Circle().stroke(QuietoColor.mint, lineWidth: 1.5) } }
            .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let date = day.date.formatted(Date.FormatStyle(date: .complete, time: .omitted).locale(QuietoLocalization.locale))
        guard day.isPracticed else { return date }
        return QuietoLocalization.format("%@, %@", date, QuietoLocalization.format("%d min de pause", day.minutes))
    }
}

private struct BadgeDetailView: View {
    let state: BadgeState
    let progress: String

    private var isMystery: Bool { state.badge.isHidden && !state.isUnlocked }

    var body: some View {
        ZStack {
            QuietoBackground()
            VStack(spacing: 16) {
                BadgeMedal(state: state, size: 110).padding(.top, 28)
                Text(isMystery ? "Badge surprise".quietoLocalized : state.badge.title.quietoLocalized)
                    .font(QuietoFont.heading(.title, weight: .semibold))
                Text(isMystery ? "Continue à ton rythme : celui-ci se révélera au bon moment.".quietoLocalized : state.badge.detail.quietoLocalized)
                    .font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 28)
                if !isMystery {
                    if state.isUnlocked {
                        Label(progress, systemImage: "checkmark.seal.fill").font(QuietoFont.sans(.callout, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                    } else {
                        VStack(spacing: 6) {
                            ProgressView(value: state.fraction).tint(QuietoColor.mint).frame(maxWidth: 220)
                            Text(progress).font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary).monospacedDigit()
                        }
                    }
                }
                Spacer()
            }
            .foregroundStyle(QuietoColor.textPrimary)
        }
        .preferredColorScheme(.dark)
    }
}
