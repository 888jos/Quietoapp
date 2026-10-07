import AmplitudeSwift
import Foundation

/// Product analytics in Amplitude (US data region). The project API key is
/// public and ingestion-only; it comes from `AMPLITUDE_API_KEY` in
/// `project.yml`. Without it the client stays unset and nothing is sent.
///
/// Created once by `AppContainer`: a second `Amplitude` instance would open a
/// second identity and storage silo.
final class QuietoAmplitude {
    private let amplitude: Amplitude?

    init() {
        #if DEBUG
        // Unit tests run inside the app: their events must not reach the production project.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            amplitude = nil
            return
        }
        #endif
        guard let key = Bundle.main.object(forInfoDictionaryKey: "AMPLITUDE_API_KEY") as? String,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !key.hasPrefix("REPLACE_") else {
            print("[amplitude] API key is not set — no events will be sent")
            amplitude = nil
            return
        }
        // Data minimisation: no IP address, city, DMA or carrier, the country is enough.
        let tracking = TrackingOptions().disableTrackIpAddress().disableTrackCity().disableTrackDMA().disableTrackCarrier()
        amplitude = Amplitude(configuration: Configuration(apiKey: key, serverZone: .US, trackingOptions: tracking))
    }

    func track(_ event: String, properties: [String: String]) {
        amplitude?.track(eventType: event, eventProperties: Self.typed(properties))
    }

    /// The Supabase user id, also used by Superwall: one person, one id everywhere.
    func identify(userID: String) {
        amplitude?.setUserId(userId: userID)
    }

    func setUserProperties(_ properties: [String: String]) {
        guard let amplitude, !properties.isEmpty else { return }
        let identify = Identify()
        Self.typed(properties).forEach { identify.set(property: $0.key, value: $0.value) }
        amplitude.identify(identify: identify)
    }

    /// Sign-out and account deletion: the next events start a new anonymous user.
    func reset() {
        amplitude?.reset()
    }

    /// Call sites pass strings; numbers are sent as numbers so Amplitude can
    /// average durations and counts.
    private static func typed(_ properties: [String: String]) -> [String: Any] {
        properties.mapValues { value -> Any in
            if let int = Int(value) { return int }
            if let double = Double(value), value.contains(".") { return double }
            return value
        }
    }
}
