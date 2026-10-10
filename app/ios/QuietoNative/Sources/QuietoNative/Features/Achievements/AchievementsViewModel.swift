import Combine
import Foundation

/// One day in the home's week strip. A meditation, a breathing exercise or a
/// background sound makes a day `done` (a check-in alone does not).
struct WeekDayStatus: Identifiable, Equatable {
    enum State: Equatable { case done, missed, today, upcoming }
    let date: Date
    let letter: String
    let state: State
    let isToday: Bool
    var id: Date { date }
}

struct PracticeCalendarDay: Identifiable, Equatable {
    let date: Date
    let dayNumber: Int
    let minutes: Int
    let isPracticed: Bool
    let isToday: Bool
    let isFuture: Bool
    var id: Date { date }
}

/// "Ton parcours": streak, practice calendar, figures and the badge collection.
/// One instance, observed by the home, the profile and the sheet itself.
@MainActor
final class AchievementsViewModel: ObservableObject {
    @Published private(set) var summary: AchievementSummary
    @Published var isPresented = false
    @Published var selectedBadge: BadgeState?
    /// First day of the month shown in the calendar.
    @Published private(set) var displayedMonth: Date

    private let calendar: Calendar
    private let now: () -> Date
    private var cancellables = Set<AnyCancellable>()

    init(center: AchievementCenter, calendar: Calendar = .autoupdatingCurrent, now: @escaping () -> Date = Date.init) {
        self.calendar = calendar
        self.now = now
        summary = center.summary
        displayedMonth = calendar.dateInterval(of: .month, for: now())?.start ?? now()
        center.$summary
            .sink { [weak self] in self?.summary = $0 }
            .store(in: &cancellables)
    }

    func present() {
        displayedMonth = calendar.dateInterval(of: .month, for: now())?.start ?? now()
        isPresented = true
    }

    /// Same calendar, with the weekday names of the displayed language.
    private var displayCalendar: Calendar {
        var localized = calendar
        localized.locale = QuietoLocalization.locale
        return localized
    }

    // MARK: Streak

    var streak: StreakStatus { summary.streak }

    var streakTitle: String {
        streak.current == 0 ? "Ta série commence ici".quietoLocalized : Self.daysLabel(streak.current)
    }

    /// Encouraging, never guilt-inducing.
    var streakMessage: String {
        if summary.stats.practiceCount == 0 { return "Ta première pause lance ta série.".quietoLocalized }
        if streak.current == 0 { return "Une pause aujourd’hui relance ta série, à ton rythme.".quietoLocalized }
        if streak.practicedToday { return "Ta pause du jour est faite. À demain, si tu en as envie.".quietoLocalized }
        if streak.isAtRisk { return "Une courte pause aujourd’hui garde ta série vivante.".quietoLocalized }
        return "Une pause aujourd’hui prolonge ta série. Sinon, ton jour de repos la protège.".quietoLocalized
    }

    var restDayLabel: String {
        (streak.restDayUsedThisWeek ? "Jour de repos utilisé cette semaine" : "1 jour de repos disponible cette semaine").quietoLocalized
    }

    static func daysLabel(_ days: Int) -> String {
        QuietoLocalization.format(days > 1 ? "%d jours" : "%d jour", days)
    }

    // MARK: This week

    private var currentWeekDays: [Date] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now()) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
    }

    /// Sessions, breathings and sounds practised since the start of the week.
    var weekPracticeCount: Int {
        currentWeekDays.reduce(0) { $0 + (summary.stats.practicesByDay[$1] ?? 0) }
    }

    var weekMinutes: Int {
        currentWeekDays.reduce(0) { $0 + (summary.stats.secondsByDay[$1] ?? 0) } / 60
    }

    var weekPracticeDays: Int {
        currentWeekDays.filter { summary.stats.practiceDays.contains($0) }.count
    }

    /// The seven days of the current week for the home: done, missed, today or to come.
    var weekStatuses: [WeekDayStatus] {
        Self.weekStatuses(practiceDays: summary.stats.practiceDays, now: now(), calendar: calendar)
    }

    /// Also used by the end-of-session screen, with the journal just updated.
    static func weekStatuses(practiceDays: Set<Date>, now: Date, calendar: Calendar) -> [WeekDayStatus] {
        var displayCalendar = calendar
        displayCalendar.locale = QuietoLocalization.locale
        let today = calendar.startOfDay(for: now)
        let symbols = displayCalendar.veryShortStandaloneWeekdaySymbols
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
        return days.map { day in
            let practiced = practiceDays.contains(day)
            let state: WeekDayStatus.State
            if day > today { state = .upcoming }
            else if practiced { state = .done }
            else if day == today { state = .today }
            else { state = .missed }
            let weekday = calendar.component(.weekday, from: day)
            return WeekDayStatus(date: day, letter: symbols[weekday - 1], state: state, isToday: day == today)
        }
    }

    // MARK: Badges

    var categories: [BadgeCategory] { BadgeCategory.allCases }

    func badges(in category: BadgeCategory) -> [BadgeState] { summary.badges(in: category) }

    var collectionLabel: String {
        QuietoLocalization.format("%d badges sur %d", summary.unlockedCount, summary.totalCount)
    }

    func progressLabel(for state: BadgeState) -> String {
        if let date = state.unlockedAt {
            return QuietoLocalization.format("Débloqué le %@", date.formatted(Date.FormatStyle(date: .long, time: .omitted).locale(QuietoLocalization.locale)))
        }
        return QuietoLocalization.format("%d / %d", state.current, state.target)
    }

    // MARK: Calendar

    var monthTitle: String {
        let text = displayedMonth.formatted(.dateTime.month(.wide).year().locale(QuietoLocalization.locale))
        return text.prefix(1).uppercased(with: QuietoLocalization.locale) + text.dropFirst()
    }

    var canShowNextMonth: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return false }
        return next <= now()
    }

    var canShowPreviousMonth: Bool {
        guard let first = summary.stats.practiceDays.min() else { return false }
        return displayedMonth > first
    }

    func showPreviousMonth() {
        guard canShowPreviousMonth, let previous = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
        displayedMonth = previous
    }

    func showNextMonth() {
        guard canShowNextMonth, let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
        displayedMonth = next
    }

    /// Weekday initials starting with the locale's first day of the week.
    var weekdaySymbols: [String] {
        let symbols = displayCalendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    /// Days of the displayed month, with `nil` before the first one so that
    /// each falls under its weekday.
    var monthDays: [PracticeCalendarDay?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let today = calendar.startOfDay(for: now())
        let leading = (calendar.component(.weekday, from: displayedMonth) - calendar.firstWeekday + 7) % 7
        let days: [PracticeCalendarDay?] = range.compactMap { day in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: displayedMonth) else { return nil }
            return PracticeCalendarDay(
                date: date,
                dayNumber: day,
                minutes: (summary.stats.secondsByDay[date] ?? 0) / 60,
                isPracticed: summary.stats.practiceDays.contains(date),
                isToday: date == today,
                isFuture: date > today
            )
        }
        return Array(repeating: nil, count: leading) + days
    }

    var practiceDaysThisMonth: Int {
        monthDays.compactMap { $0 }.filter(\.isPracticed).count
    }
}

/// Queues newly unlocked badges and shows them one at a time.
@MainActor
final class BadgeCelebrationViewModel: ObservableObject {
    @Published private(set) var current: Badge?
    /// Haptic and VoiceOver announcement, once per badge even when two
    /// banners (tabs and player) observe this model.
    var onShow: ((Badge) -> Void)?

    private var queue: [Badge] = []
    private var dismissTask: Task<Void, Never>?
    private let displayDuration: TimeInterval
    private var cancellables = Set<AnyCancellable>()

    init(unlocks: AnyPublisher<[Badge], Never>, displayDuration: TimeInterval = 4) {
        self.displayDuration = displayDuration
        unlocks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.enqueue($0) }
            .store(in: &cancellables)
    }

    func enqueue(_ badges: [Badge]) {
        queue.append(contentsOf: badges)
        if current == nil { showNext() }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
        // Leaves a beat between two banners.
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            self?.showNext()
        }
    }

    private func showNext() {
        guard current == nil, !queue.isEmpty else { return }
        let badge = queue.removeFirst()
        current = badge
        onShow?(badge)
        let duration = displayDuration
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }
}
