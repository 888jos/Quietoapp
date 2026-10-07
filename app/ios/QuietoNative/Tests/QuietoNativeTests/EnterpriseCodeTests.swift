import XCTest
@testable import QuietoNative

@MainActor
private final class FakeEnterpriseAccess: EnterpriseAccessServicing {
    var isConfigured = true
    var company = "Cofonde"
    var error: EnterpriseAccessError?
    private(set) var activations: [String] = []

    func preview(code: String) async throws -> String {
        if let error { throw error }
        return company
    }
    func activate(code: String) async throws -> String {
        if let error { throw error }
        activations.append(code)
        return company
    }
}

@MainActor
final class EnterpriseCodeTests: XCTestCase {
    func testCodeIsPreviewedThenActivatedAndThePaywallRefreshes() async {
        let service = FakeEnterpriseAccess()
        let subscriptions = FakeSubscriptions()
        let model = EnterpriseCodeViewModel(service: service, subscriptions: subscriptions, auth: FakeAuth())
        model.code = "ab3"
        XCTAssertFalse(model.canSubmit, "Too short to be a company code")
        model.code = "QTO-AB3K7P"
        XCTAssertTrue(model.canSubmit)

        await model.check()
        XCTAssertEqual(model.step, .confirm(company: "Cofonde"))
        XCTAssertTrue(service.activations.isEmpty, "A preview never takes a seat")

        await model.activate()
        XCTAssertEqual(model.step, .activated(company: "Cofonde"))
        XCTAssertEqual(service.activations, ["QTO-AB3K7P"])
        XCTAssertEqual(subscriptions.syncCount, 1, "The server now grants Premium: sync to lift the paywall")
    }

    func testRefusalShowsTheServerMessage() async {
        let service = FakeEnterpriseAccess()
        service.error = .refused("Toutes les places de ton entreprise sont prises. Parles-en à ta RH.")
        let model = EnterpriseCodeViewModel(service: service, subscriptions: FakeSubscriptions(), auth: FakeAuth())
        model.code = "QTO-AB3K7P"
        await model.check()
        XCTAssertEqual(model.step, .entry)
        XCTAssertEqual(model.errorMessage, "Toutes les places de ton entreprise sont prises. Parles-en à ta RH.")
        XCTAssertFalse(model.needsAppleAccount)
    }

    func testAnonymousAccountIsAskedToSignInWithApple() async {
        let service = FakeEnterpriseAccess()
        service.error = .needsAppleAccount("Connecte-toi avec Apple pour garder ton accès si tu changes de téléphone.")
        let auth = FakeAuth()
        let model = EnterpriseCodeViewModel(service: service, subscriptions: FakeSubscriptions(), auth: auth)
        model.code = "QTO-AB3K7P"
        await model.check()
        XCTAssertTrue(model.needsAppleAccount)

        await model.signInWithApple()
        XCTAssertEqual(auth.state, .authenticated(userID: "apple", email: nil))
        XCTAssertFalse(model.needsAppleAccount)
        XCTAssertNil(model.errorMessage)
    }
}
