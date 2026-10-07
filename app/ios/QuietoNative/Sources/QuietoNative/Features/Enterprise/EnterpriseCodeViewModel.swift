import Foundation

@MainActor
final class EnterpriseCodeViewModel: ObservableObject {
    enum Step: Equatable {
        case entry
        /// The code matches this company; the person confirms before taking a seat.
        case confirm(company: String)
        case activated(company: String)
    }

    @Published var code = ""
    @Published private(set) var step: Step = .entry
    @Published private(set) var isWorking = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var needsAppleAccount = false

    private let service: EnterpriseAccessServicing
    private let subscriptions: SubscriptionServicing
    private let auth: AuthServicing

    init(service: EnterpriseAccessServicing, subscriptions: SubscriptionServicing, auth: AuthServicing) {
        self.service = service
        self.subscriptions = subscriptions
        self.auth = auth
    }

    var isAvailable: Bool { service.isConfigured }
    /// Codes are short and case-insensitive; the server normalises them too.
    var canSubmit: Bool { code.filter { $0.isLetter || $0.isNumber }.count >= 6 && !isWorking }

    func reset() {
        code = ""
        step = .entry
        errorMessage = nil
        needsAppleAccount = false
    }

    func check() async {
        await run { [self] in
            let company = try await service.preview(code: code)
            step = .confirm(company: company)
        }
    }

    func activate() async {
        await run { [self] in
            let company = try await service.activate(code: code)
            // The server now answers Premium: lift the paywall right away.
            await subscriptions.syncNow()
            step = .activated(company: company)
        }
    }

    func signInWithApple() async {
        await run { [self] in
            try await auth.signInWithApple()
            needsAppleAccount = false
            errorMessage = nil
        }
    }

    private func run(_ work: @escaping () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await work()
        } catch let error as EnterpriseAccessError {
            if case .needsAppleAccount = error { needsAppleAccount = true }
            errorMessage = error.errorDescription
        } catch {
            errorMessage = EnterpriseAccessError.unavailable.errorDescription
        }
    }
}
