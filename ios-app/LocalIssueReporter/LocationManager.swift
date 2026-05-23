import Combine
import CoreLocation
import Foundation

// LocationManager is separate from ContentView because Core Location uses a
// delegate object to send permission and location updates back to the app.
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // @Published tells SwiftUI to refresh views when these values change.
    @Published var latestLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var locationErrorMessage: String?

    private let coreLocationManager = CLLocationManager()

    override init() {
        authorizationStatus = coreLocationManager.authorizationStatus
        super.init()
        // The delegate line says: send Core Location callbacks to this object.
        coreLocationManager.delegate = self
        coreLocationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    // Requests permission to access the user's current location while the app is open.
    // iOS shows the permission dialog the first time this is called.
    func requestLocationPermission() {
        authorizationStatus = coreLocationManager.authorizationStatus

        if authorizationStatus == .notDetermined {
            coreLocationManager.requestWhenInUseAuthorization()
        }
    }

    // Starts a one-time location lookup. This is enough for a report app because
    // the app only needs the location at the moment the user sends or prepares a report.
    func requestCurrentLocation() {
        authorizationStatus = coreLocationManager.authorizationStatus

        switch authorizationStatus {
        case .notDetermined:
            requestLocationPermission()
        case .authorizedWhenInUse, .authorizedAlways:
            coreLocationManager.requestLocation()
        case .denied, .restricted:
            locationErrorMessage = "Location permission is not available. Enable it in Settings to include coordinates."
        @unknown default:
            locationErrorMessage = "Location permission has an unknown status."
        }
    }

    // Called by iOS whenever the location permission changes. If permission is granted,
    // the app immediately requests the current location so the report can include coordinates.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            coreLocationManager.requestLocation()
        }
    }

    // Called by iOS after requestLocation() succeeds. The newest location is stored
    // in a published property so SwiftUI automatically updates the screen.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        latestLocation = locations.last
        locationErrorMessage = nil
    }

    // Called by iOS if the location lookup fails, such as when GPS is unavailable.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationErrorMessage = "Could not get current location: \(error.localizedDescription)"
    }
}
