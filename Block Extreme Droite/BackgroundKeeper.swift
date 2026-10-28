import CoreLocation

/// Keeps the app running in the background during a run. iOS only does that for apps using a background
/// service, and location is the one that fits: the updates are never read, they only hold the app awake.
@MainActor @Observable
final class BackgroundKeeper: NSObject, CLLocationManagerDelegate {
    private(set) var authorization: CLAuthorizationStatus
    private let manager = CLLocationManager()

    var isDenied: Bool { authorization == .denied || authorization == .restricted }

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
    }

    func requestAuthorization() {
        if authorization == .notDetermined { manager.requestWhenInUseAuthorization() }
    }

    func start() {
        guard authorization == .authorizedWhenInUse || authorization == .authorizedAlways else { return }
        manager.startUpdatingLocation()
    }

    func stop() { manager.stopUpdatingLocation() }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in authorization = status }
    }
}
