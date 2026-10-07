import Combine
import XCTest
@testable import QuietoNative

/// ViewModels built only from fakes: no Supabase, Superwall or system prompt.
@MainActor
final class InjectedViewModelTests: XCTestCase {
    // MARK: Storage

    func testActivityStoreKeepsTheExistingStorageFormatAndDropsOldEvents() {
        let defaults = makeTestDefaults()
        let old = Date().addingTimeInterval(-90 * 86_400).timeIntervalSince1970
        defaults.set([["id": "sleep_1", "seconds": 300, "date": old]], forKey: "quieto.native.activity.events")
        let store = ActivityStore(defaults: defaults)
        XCTAssertEqual(store.completedSessionIDs, ["sleep_1"])

        store.record(sessionID: "meditation_05", seconds: 120)

        XCTAssertEqual(store.events.map(\.sessionID), ["meditation_05"])
        let raw = defaults.array(forKey: "quieto.native.activity.events") as? [[String: Any]]
        XCTAssertEqual(raw?.first?["id"] as? String, "meditation_05")
        XCTAssertEqual(raw?.first?["seconds"] as? Int, 120)
    }

    func testPreferencesReadValuesWrittenUnderTheLegacyKeys() {
        let defaults = makeTestDefaults()
        defaults.set("Camille", forKey: "quieto.profile.firstName")
        defaults.set(7, forKey: "quieto.profile.reminderHour")
        let preferences = QuietoPreferences(defaults: defaults)
        XCTAssertEqual(preferences.firstName, "Camille")
        XCTAssertEqual(preferences.reminder.hour, 7)
        XCTAssertEqual(preferences.reminder.minute, 30)
        XCTAssertEqual(preferences.reminder.weekdays, Set(1...7))
    }

    // MARK: Playback

    func testCompletedSessionIsRecordedEverywhereAndAnnounced() async {
        let activity = ActivityStore(defaults: makeTestDefaults())
        let health = FakeHealth()
        let backend = FakeBackend()
        let tracker = PlaybackTracker(activity: activity, health: health, progress: backend)
        var announced: [String] = []
        let subscription = tracker.completions.sink { announced.append($0) }
        let session = SessionCatalog().sessions[0]

        tracker.sessionCompleted(session, listenedSeconds: 90)
        await Task.yield()

        XCTAssertEqual(activity.completedSessionIDs, [session.id])
        XCTAssertEqual(health.recordedSeconds, [90])
        XCTAssertEqual(announced, [session.id])
        XCTAssertEqual(backend.completions.first?.0, session.id)
        subscription.cancel()
    }

    // MARK: Sessions

    func testFavoritesArePersistedAndSynchronised() async {
        let preferences = QuietoPreferences(defaults: makeTestDefaults())
        let backend = FakeBackend()
        let model = makeSessionsViewModel(preferences: preferences, progress: backend)
        let session = SessionCatalog().sessions[0]

        model.toggleFavorite(session)
        await Task.yield()

        XCTAssertEqual(preferences.favoriteSessionIDs, [session.id])
        XCTAssertEqual(backend.favorites.first?.0, session.id)
        XCTAssertEqual(backend.favorites.first?.1, true)
    }

    // MARK: Programme

    func testProgrammeMovesOnlyWithTheStepOfTheDay() {
        let preferences = QuietoPreferences(defaults: makeTestDefaults())
        preferences.planState = QuietoPlanState(planID: .sleep, startedAt: .now, rhythm: .sustained, prefersShort: false, includesDiscovery: false)
        let completions = PassthroughSubject<String, Never>()
        let analytics = FakeAnalytics()
        let model = ProgramViewModel(catalog: SessionCatalog(), preferences: preferences, activity: ActivityStore(defaults: makeTestDefaults()), repository: nil, completions: completions.eraseToAnyPublisher(), analytics: analytics)
        XCTAssertEqual(model.title, "Mieux dormir")
        XCTAssertEqual(model.nextSession?.id, "screen_off")

        model.sessionCompleted("sleep_2")
        XCTAssertEqual(model.completedCount, 0, "Une autre séance ne fait pas avancer le plan.")

        model.sessionCompleted("screen_off")
        XCTAssertEqual(model.completedCount, 1)
        XCTAssertEqual(preferences.planState?.completions.keys.sorted(), [1])
        guard case .locked(let next, _) = model.today else { return XCTFail("L’étape suivante s’ouvre demain.") }
        XCTAssertEqual(next.session.id, "express_4")
        XCTAssertTrue(analytics.events.contains("plan_day_completed"))
    }

    func testChangingPlanStartsAtDayOneAndIsTracked() async {
        let preferences = QuietoPreferences(defaults: makeTestDefaults())
        var state = QuietoPlanState(planID: .sleep, startedAt: .now, rhythm: .gentle, prefersShort: true, includesDiscovery: false)
        state.completions = [1: .now]
        preferences.planState = state
        let backend = FakeBackend()
        let analytics = FakeAnalytics()
        let model = ProgramViewModel(catalog: SessionCatalog(), preferences: preferences, activity: ActivityStore(defaults: makeTestDefaults()), repository: backend, completions: Empty().eraseToAnyPublisher(), analytics: analytics)

        model.start(.mind, source: "test")
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(preferences.planState?.planID, .mind)
        XCTAssertEqual(preferences.planState?.completions, [:])
        XCTAssertEqual(preferences.planState?.rhythm, .gentle, "Le rythme choisi est gardé.")
        XCTAssertEqual(model.completedCount, 0)
        XCTAssertEqual(analytics.events.last.map { $0 }, "plan_switched")
        XCTAssertEqual(backend.startedPlans.map(\.planID), [.mind])
        XCTAssertNotNil(preferences.planState?.remoteID)
    }

    func testPlanIsRestoredFromTheAccountOnANewIPhone() async {
        let backend = FakeBackend()
        var remote = QuietoPlanState(planID: .anxiety, startedAt: .now, rhythm: .regular, prefersShort: false, includesDiscovery: false)
        remote.completions = [1: .now.addingTimeInterval(-86_400)]
        remote.remoteID = UUID()
        backend.remoteProgram = QuietoRemoteProgram(id: remote.remoteID!, title: "Apaiser l’anxiété", sessions: [], completedSessionIDs: [], rhythm: "Régulier", plan: remote)
        let preferences = QuietoPreferences(defaults: makeTestDefaults())
        let model = ProgramViewModel(catalog: SessionCatalog(), preferences: preferences, activity: ActivityStore(defaults: makeTestDefaults()), repository: backend, completions: Empty().eraseToAnyPublisher())

        await model.load()

        XCTAssertEqual(model.state?.planID, .anxiety)
        XCTAssertEqual(model.completedCount, 1)
        XCTAssertEqual(preferences.planState?.remoteID, remote.remoteID)
    }

    func testProgrammeStaysAvailableOfflineWhenTheServerFails() async {
        let backend = FakeBackend()
        backend.programError = URLError(.notConnectedToInternet)
        let preferences = QuietoPreferences(defaults: makeTestDefaults())
        preferences.planState = QuietoPlanState(planID: .stress, startedAt: .now, rhythm: .regular, prefersShort: false, includesDiscovery: false)
        let model = ProgramViewModel(catalog: SessionCatalog(), preferences: preferences, activity: ActivityStore(defaults: makeTestDefaults()), repository: backend, completions: Empty().eraseToAnyPublisher())

        await model.load()

        XCTAssertTrue(model.hasProgram)
        XCTAssertFalse(model.sessions.isEmpty)
        XCTAssertNotNil(model.loadError)
    }

    // MARK: Profile

    private func makeProfile(preferences: QuietoPreferences, auth: FakeAuth? = nil, downloads: FakeDownloads = FakeDownloads(), reminders: FakeReminders = FakeReminders(), subscriptions: FakeSubscriptions? = nil, health: FakeHealth? = nil, louaneMemory: InMemoryLouaneMemory? = nil) -> ProfileViewModel {
        ProfileViewModel(
            preferences: preferences,
            auth: auth ?? FakeAuth(),
            account: FakeBackend(),
            louane: FakeBackend(),
            louaneMemory: louaneMemory ?? InMemoryLouaneMemory(),
            subscriptions: subscriptions ?? FakeSubscriptions(),
            reminders: reminders,
            health: health ?? FakeHealth(),
            localData: LocalDataWiper(preferences: preferences, downloads: downloads, louaneMemory: InMemoryLouaneMemory())
        )
    }

    func testEnablingRemindersSchedulesAndPersistsThem() async {
        let preferences = QuietoPreferences(defaults: makeTestDefaults())
        let reminders = FakeReminders()
        let model = makeProfile(preferences: preferences, reminders: reminders)

        await model.setReminders(true)

        XCTAssertTrue(model.remindersEnabled)
        XCTAssertTrue(preferences.reminder.isEnabled)
        XCTAssertEqual(reminders.scheduled.count, 1)
    }

    func testRefusedNotificationsKeepRemindersOff() async {
        let preferences = QuietoPreferences(defaults: makeTestDefaults())
        let reminders = FakeReminders()
        reminders.grants = false
        let model = makeProfile(preferences: preferences, reminders: reminders)

        await model.setReminders(true)

        XCTAssertFalse(model.remindersEnabled)
        XCTAssertFalse(preferences.reminder.isEnabled)
        XCTAssertTrue(reminders.scheduled.isEmpty)
    }

    func testSigningOutWipesLocalDataAndReturnsToAnonymous() async throws {
        let defaults = makeTestDefaults()
        let preferences = QuietoPreferences(defaults: defaults)
        preferences.firstName = "Camille"
        let auth = FakeAuth()
        auth.state = .authenticated(userID: "apple", email: nil)
        let downloads = FakeDownloads()
        let model = makeProfile(preferences: preferences, auth: auth, downloads: downloads)

        model.signOut()
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(auth.signOutCount, 1)
        XCTAssertEqual(downloads.deleteAllCount, 1)
        XCTAssertEqual(preferences.firstName, "")
        XCTAssertTrue(model.isAnonymous)
    }

    func testFailedSignOutKeepsTheAccountAndItsLocalData() async throws {
        let preferences = QuietoPreferences(defaults: makeTestDefaults())
        preferences.firstName = "Camille"
        let auth = FakeAuth()
        auth.state = .authenticated(userID: "apple", email: nil)
        auth.signOutError = URLError(.notConnectedToInternet)
        let downloads = FakeDownloads()
        let model = makeProfile(preferences: preferences, auth: auth, downloads: downloads)

        model.signOut()
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(downloads.deleteAllCount, 0)
        XCTAssertEqual(preferences.firstName, "Camille")
    }

    func testProfileShowsTheSubscriptionReadFromStoreKit() async {
        let subscriptions = FakeSubscriptions(access: .subscribed)
        let renewal = Date(timeIntervalSince1970: 1_800_000_000)
        subscriptions.details = QuietoSubscriptionDetails(status: .trial, planName: "Quieto annuel", price: "89,99 € / an", date: renewal)
        let model = makeProfile(preferences: QuietoPreferences(defaults: makeTestDefaults()), subscriptions: subscriptions)

        await model.refreshSubscription()

        XCTAssertEqual(model.subscription?.status, .trial)
        XCTAssertEqual(model.subscription?.planName, "Quieto annuel")
        XCTAssertTrue(model.subscriptionSummary.contains(renewal.formatted(.dateTime.day().month(.abbreviated))))
    }

    func testProfileReadsTheRealHealthAndNotificationStatus() async {
        let health = FakeHealth()
        health.healthSummary = QuietoHealthSummary(mindfulMinutesThisWeek: 42, quietoMinutesThisWeek: 30, lastNightSleepMinutes: 430)
        let reminders = FakeReminders()
        reminders.grants = false
        let preferences = QuietoPreferences(defaults: makeTestDefaults())
        preferences.reminder = ReminderSettings(isEnabled: true, hour: 21, minute: 30, weekdays: Set(1...7))
        let model = makeProfile(preferences: preferences, reminders: reminders, health: health)

        await model.refreshLiveStatus()
        XCTAssertFalse(model.healthConnected)
        XCTAssertNil(model.healthSummary, "Nothing is read from Health before the person was asked")
        XCTAssertEqual(model.notificationStatus, .denied)
        XCTAssertEqual(model.reminderSummary, "Bloqués dans Réglages".quietoLocalized)

        await model.connectHealth()
        XCTAssertTrue(model.healthConnected)
        XCTAssertEqual(model.healthSummary?.mindfulMinutesThisWeek, 42)
        XCTAssertEqual(model.healthSummary?.lastNightSleepMinutes, 430)
    }

    func testDeletingLouaneMemoryStopsSendingItFromThisIPhone() async {
        let memory = InMemoryLouaneMemory()
        memory.update("À l’inscription, elle a écrit : « je dors mal »")
        let model = makeProfile(preferences: QuietoPreferences(defaults: makeTestDefaults()), louaneMemory: memory)

        await model.loadMemory()
        XCTAssertEqual(model.memoryText, memory.text)
        model.deleteMemory()

        XCTAssertEqual(memory.text, "", "The local copy is what Louane receives")
        XCTAssertEqual(model.memoryText, "")
    }

    func testAmbienceVolumeIsSavedAndAppliedToThePlayer() {
        let preferences = QuietoPreferences(defaults: makeTestDefaults())
        let model = makeProfile(preferences: preferences)
        var applied: Double?
        model.onAmbienceVolumeChanged = { applied = $0 }

        model.setAmbienceVolume(0.6)

        XCTAssertEqual(preferences.ambienceVolume, 0.6)
        XCTAssertEqual(applied, 0.6)
        XCTAssertEqual(model.ambienceSummary, 0.6.formatted(.percent.locale(QuietoLocalization.locale)))
    }

    // MARK: Paywall and root

    func testPaywallOffersAppleSignInOnlyToAnonymousAccounts() {
        let auth = FakeAuth()
        let model = PaywallViewModel(subscriptions: FakeSubscriptions(), auth: auth)
        XCTAssertTrue(model.canSignIn)
        auth.state = .authenticated(userID: "apple", email: nil)
        XCTAssertFalse(model.canSignIn)
        auth.isConfigured = false
        auth.state = .anonymous(userID: "anon")
        XCTAssertFalse(model.canSignIn)
    }

    func testPaywallPresentsOnlyWhenLocked() {
        let subscriptions = FakeSubscriptions(access: .checking)
        let model = PaywallViewModel(subscriptions: subscriptions, auth: FakeAuth())
        model.presentIfLocked()
        XCTAssertEqual(subscriptions.paywallPresentations, 0)
        subscriptions.access = .locked
        model.presentIfLocked()
        XCTAssertEqual(subscriptions.paywallPresentations, 1)
    }

    func testRootLocksTheAppAndSyncsWhenBackInForeground() {
        let subscriptions = FakeSubscriptions(access: .subscribed)
        let model = RootViewModel(subscriptions: subscriptions, audioPlayer: QuietoAudioPlayer(preferences: QuietoPreferences(defaults: makeTestDefaults())))
        XCTAssertFalse(model.isLocked)
        subscriptions.access = .locked
        XCTAssertTrue(model.isLocked)
        model.scenePhaseChanged(.active)
        XCTAssertEqual(subscriptions.syncCount, 1)
    }

    // MARK: Louane and onboarding

    func testMissingSubscriptionAsksTheSubscriptionLayerToRecheck() async throws {
        let subscriptions = FakeSubscriptions(access: .subscribed)
        let model = makeLouaneViewModel(backend: AlwaysPremiumRequired(), subscriptions: subscriptions)
        model.draft = "Bonjour"
        model.send()
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(subscriptions.syncCount, 1)
    }

    func testConversationIsSavedOnlyWhenNotTemporary() async throws {
        let backend = FakeBackend()
        let model = makeLouaneViewModel(repository: backend)
        model.temporaryConversation = true
        model.draft = "Bonjour"
        model.send()
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertTrue(backend.savedMessages.isEmpty)
    }

    func testOnboardingWritesTheLouaneNoteIntoTheSharedMemory() {
        let preferences = QuietoPreferences(defaults: makeTestDefaults())
        preferences.onboardingStep = OnboardingStep.louaneAsk.rawValue
        let memory = InMemoryLouaneMemory()
        let model = makeOnboardingViewModel(preferences: preferences, louaneMemory: memory)
        model.louaneDraft = "Le travail me stresse"
        model.submitLouane()
        XCTAssertTrue(memory.text.contains("Le travail me stresse"))
    }

    func testFinishingOnboardingIsPersisted() {
        let preferences = QuietoPreferences(defaults: makeTestDefaults())
        let model = makeOnboardingViewModel(preferences: preferences)
        var finished = false
        model.setFinishHandler { _ in finished = true }
        model.finish(playFirstSession: false)
        XCTAssertTrue(model.isCompleted)
        XCTAssertTrue(preferences.isOnboardingCompleted)
        XCTAssertTrue(finished)
    }
}

private struct AlwaysPremiumRequired: LouaneBackendProviding {
    func send(message: String, history: [LouaneMessage], temporary: Bool) async throws -> LouaneBackendReply {
        throw LouaneServiceError.premiumRequired
    }
}
