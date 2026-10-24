import UIKit
import AppTrackingTransparency
import AdSupport
import FirebaseAnalytics

@MainActor
final class TrackingAuthorizationManager {
    static let shared = TrackingAuthorizationManager()
    private var isRequesting = false
    private(set) var canCollectAnalytics = false

    /// Keep Analytics off until the current system permission has been checked.
    func prepareForFirebaseConfiguration() {
        Analytics.setAnalyticsCollectionEnabled(false)
#if targetEnvironment(macCatalyst)
        setConsent(allowed: false)
#else
        setConsent(allowed: ATTrackingManager.trackingAuthorizationStatus == .authorized)
#endif
    }

    /// Call after Firebase initialization and when returning from Settings.
    func refreshAuthorization() {
        var allowed = false
#if !targetEnvironment(macCatalyst)
        if ATTrackingManager.trackingAuthorizationStatus == .authorized {
            // Read IDFA only after permission. Never log or persist it ourselves.
            let idfa = ASIdentifierManager.shared().advertisingIdentifier
            allowed = idfa != UUID(uuidString: "00000000-0000-0000-0000-000000000000")
        }
#endif
        canCollectAnalytics = allowed
        setConsent(allowed: allowed)
        Analytics.setAnalyticsCollectionEnabled(allowed)
    }

    /// The homepage calls this once after a short delay. Declining never blocks use.
    func requestIDFAAuthorization() {
#if !targetEnvironment(macCatalyst)
        guard UIApplication.shared.applicationState == .active, !isRequesting else { return }
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            refreshAuthorization()
            return
        }
        isRequesting = true
        ATTrackingManager.requestTrackingAuthorization { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRequesting = false
                self?.refreshAuthorization()
            }
        }
#endif
    }

    private func setConsent(allowed: Bool) {
        let status: ConsentStatus = allowed ? .granted : .denied
        Analytics.setConsent([
            .analyticsStorage: status,
            .adStorage: status,
            .adUserData: status,
            .adPersonalization: .denied
        ])
    }
}
