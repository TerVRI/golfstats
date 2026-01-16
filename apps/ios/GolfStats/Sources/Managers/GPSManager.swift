import Foundation
import CoreLocation
import Combine

class GPSManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking = false
    @Published var error: String?
    
    // Distances to green
    @Published var distanceToFront: Int?
    @Published var distanceToCenter: Int?
    @Published var distanceToBack: Int?
    
    // Shot tracking
    @Published var lastShotLocation: CLLocation?
    @Published var lastShotDistance: Int?
    
    // Current hole green locations
    var greenFront: CLLocationCoordinate2D?
    var greenCenter: CLLocationCoordinate2D?
    var greenBack: CLLocationCoordinate2D?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 1 // Update every meter
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    // MARK: - Tracking Control
    
    func startTracking() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestAuthorization()
            return
        }
        locationManager.startUpdatingLocation()
        isTracking = true
    }
    
    func stopTracking() {
        locationManager.stopUpdatingLocation()
        isTracking = false
    }
    
    // MARK: - Shot Tracking
    
    func markShot() {
        lastShotLocation = currentLocation
        lastShotDistance = nil
    }
    
    func calculateLastShotDistance() {
        guard let lastShot = lastShotLocation, let current = currentLocation else {
            lastShotDistance = nil
            return
        }
        let meters = lastShot.distance(from: current)
        lastShotDistance = metersToYards(meters)
    }
    
    // MARK: - Green Setup
    
    func setGreenLocations(front: CLLocationCoordinate2D?, center: CLLocationCoordinate2D?, back: CLLocationCoordinate2D?) {
        greenFront = front
        greenCenter = center
        greenBack = back
        updateDistances()
    }
    
    func clearGreenLocations() {
        greenFront = nil
        greenCenter = nil
        greenBack = nil
        distanceToFront = nil
        distanceToCenter = nil
        distanceToBack = nil
    }
    
    // MARK: - Distance Calculations
    
    private func updateDistances() {
        guard let current = currentLocation else {
            distanceToFront = nil
            distanceToCenter = nil
            distanceToBack = nil
            return
        }
        
        if let front = greenFront {
            let frontLocation = CLLocation(latitude: front.latitude, longitude: front.longitude)
            distanceToFront = metersToYards(current.distance(from: frontLocation))
        }
        
        if let center = greenCenter {
            let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
            distanceToCenter = metersToYards(current.distance(from: centerLocation))
        }
        
        if let back = greenBack {
            let backLocation = CLLocation(latitude: back.latitude, longitude: back.longitude)
            distanceToBack = metersToYards(current.distance(from: backLocation))
        }
    }
    
    private func metersToYards(_ meters: Double) -> Int {
        Int(meters * 1.09361)
    }
    
    // MARK: - Utility
    
    func distanceTo(_ coordinate: CLLocationCoordinate2D) -> Int? {
        guard let current = currentLocation else { return nil }
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return metersToYards(current.distance(from: target))
    }
    
    func distanceBetween(_ from: CLLocationCoordinate2D, _ to: CLLocationCoordinate2D) -> Int {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return metersToYards(fromLocation.distance(from: toLocation))
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Filter out inaccurate readings
        guard location.horizontalAccuracy >= 0 && location.horizontalAccuracy < 50 else { return }
        
        currentLocation = location
        updateDistances()
        calculateLastShotDistance()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if isTracking {
                locationManager.startUpdatingLocation()
            }
        case .denied, .restricted:
            error = "Location access denied. Please enable in Settings."
            stopTracking()
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = "Location error: \(error.localizedDescription)"
    }
}
