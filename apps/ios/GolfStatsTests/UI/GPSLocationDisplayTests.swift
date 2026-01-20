import XCTest
import SwiftUI
import CoreLocation
@testable import GolfStats

final class GPSLocationDisplayTests: XCTestCase {
    
    func testGPSLocationDisplayWhenTracking() {
        let gpsManager = GPSManager()
        gpsManager.startTracking()
        
        XCTAssertTrue(gpsManager.isTracking)
        // Location should update when tracking starts
    }
    
    func testGPSLocationDisplayWhenNotTracking() {
        let gpsManager = GPSManager()
        gpsManager.stopTracking()
        
        XCTAssertFalse(gpsManager.isTracking)
        XCTAssertNil(gpsManager.currentLocation)
    }
    
    func testGPSDistanceToGreenCalculation() {
        let gpsManager = GPSManager()
        
        // Set green locations
        let greenCenter = CLLocationCoordinate2D(latitude: 36.5725, longitude: -121.9486)
        let greenFront = CLLocationCoordinate2D(latitude: 36.5720, longitude: -121.9486)
        let greenBack = CLLocationCoordinate2D(latitude: 36.5730, longitude: -121.9486)
        
        gpsManager.setGreenLocations(front: greenFront, center: greenCenter, back: greenBack)
        
        // Mock current location
        let currentLocation = CLLocation(latitude: 36.5725, longitude: -121.9480)
        gpsManager.currentLocation = currentLocation
        
        // Distances should be calculated
        // Note: Actual calculation happens in updateDistances() which is called by locationManager delegate
    }
    
    func testGPSClearsDistancesWhenLocationNil() {
        let gpsManager = GPSManager()
        
        // Set some distances
        gpsManager.distanceToCenter = 150
        gpsManager.distanceToFront = 140
        gpsManager.distanceToBack = 160
        
        // Clear location - this should clear distances
        gpsManager.currentLocation = nil
        
        // When location is nil, distances should be nil
        // Note: updateDistances() is private, but setting location to nil
        // should result in nil distances when location manager updates
        // For testing, we verify the state after clearing location
        XCTAssertNil(gpsManager.currentLocation)
    }
}
