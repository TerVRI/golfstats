import Foundation
import CoreLocation
import Combine

class GPSManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var distanceToGreenFront: Int = 0
    @Published var distanceToGreenCenter: Int = 0
    @Published var distanceToGreenBack: Int = 0
    @Published var lastShotDistance: Int?
    @Published var isTracking = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // Demo green location - in real app, this comes from course data
    var greenCenter: CLLocation?
    var greenFront: CLLocation?
    var greenBack: CLLocation?
    
    private var lastShotLocation: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 1 // meters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
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
    
    func markShot() {
        lastShotLocation = currentLocation
    }
    
    func calculateLastShotDistance() -> Int? {
        guard let lastShot = lastShotLocation, let current = currentLocation else {
            return nil
        }
        let meters = lastShot.distance(from: current)
        return Int(meters * 1.09361) // Convert to yards
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        updateDistances()
        
        if lastShotLocation != nil {
            lastShotDistance = calculateLastShotDistance()
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            startTracking()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    private func updateDistances() {
        guard let current = currentLocation else { return }
        
        if let front = greenFront {
            distanceToGreenFront = Int(current.distance(from: front) * 1.09361)
        }
        if let center = greenCenter {
            distanceToGreenCenter = Int(current.distance(from: center) * 1.09361)
        }
        if let back = greenBack {
            distanceToGreenBack = Int(current.distance(from: back) * 1.09361)
        }
    }
    
    func setGreenLocations(front: CLLocation?, center: CLLocation?, back: CLLocation?) {
        greenFront = front
        greenCenter = center
        greenBack = back
        updateDistances()
    }
}
