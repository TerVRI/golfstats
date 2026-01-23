import Foundation
import CoreLocation
import Combine

class GPSManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // Singleton for shared access
    static let shared = GPSManager()
    
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
        
        // SCREENSHOT_MODE: Set demo distances for App Store screenshots
        // Uncomment and set to true when capturing App Store screenshots
        // #if DEBUG
        // let screenshotMode = false
        // if screenshotMode {
        //     setupDemoDistances()
        //     return
        // }
        // #endif
    }
    
    /// Set up demo distances for App Store screenshots
    private func setupDemoDistances() {
        distanceToGreenFront = 142
        distanceToGreenCenter = 156
        distanceToGreenBack = 171
        lastShotDistance = 267  // Nice drive distance
        isTracking = true
        // Pretend we're authorized so no permission dialog shows
        authorizationStatus = .authorizedWhenInUse
    }
    
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startTracking() {
        // In demo mode, skip actual location tracking
        #if DEBUG
        if distanceToGreenCenter > 0 {
            // Already have demo distances, skip real tracking
            return
        }
        #endif
        
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
        if let clError = error as? CLError, clError.code == .denied {
            // Stop spamming logs if user denied location
            locationManager.stopUpdatingLocation()
            isTracking = false
        }
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
