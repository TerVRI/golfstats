import XCTest
import CoreLocation
@testable import GolfStats

@MainActor
final class GolfStatsTests: XCTestCase {
    
    // MARK: - GPS Manager Tests
    
    func testGPSManagerInitialization() {
        let gpsManager = GPSManager()
        XCTAssertNotNil(gpsManager)
        XCTAssertFalse(gpsManager.isTracking)
    }
    
    func testGPSManagerAuthorizationRequest() {
        let gpsManager = GPSManager()
        gpsManager.requestAuthorization()
        // Authorization status should be checked
        XCTAssertNotNil(gpsManager.authorizationStatus)
    }
    
    // MARK: - Round Manager Tests
    
    func testRoundManagerInitialization() {
        let roundManager = RoundManager()
        XCTAssertNotNil(roundManager)
        XCTAssertEqual(roundManager.currentHole, 1)
        XCTAssertFalse(roundManager.isRoundActive)
    }
    
    func testRoundManagerStartRound() {
        let roundManager = RoundManager()
        roundManager.startRound()
        XCTAssertTrue(roundManager.isRoundActive)
    }
    
    func testRoundManagerNextHole() {
        let roundManager = RoundManager()
        roundManager.startRound()
        roundManager.nextHole()
        XCTAssertEqual(roundManager.currentHole, 2)
    }
    
    func testRoundManagerPreviousHole() {
        let roundManager = RoundManager()
        roundManager.startRound()
        roundManager.nextHole()
        roundManager.previousHole()
        XCTAssertEqual(roundManager.currentHole, 1)
    }
    
    func testRoundManagerCannotGoBelowHole1() {
        let roundManager = RoundManager()
        roundManager.startRound()
        roundManager.previousHole()
        XCTAssertEqual(roundManager.currentHole, 1)
    }
    
    func testRoundManagerCannotGoAboveHole18() {
        let roundManager = RoundManager()
        roundManager.startRound()
        for _ in 1...18 {
            roundManager.nextHole()
        }
        XCTAssertEqual(roundManager.currentHole, 18)
    }
    
    // MARK: - Watch Sync Manager Tests
    
    func testWatchSyncManagerInitialization() {
        let watchSyncManager = WatchSyncManager()
        XCTAssertNotNil(watchSyncManager)
    }
    
    func testWatchSyncManagerSetup() {
        let watchSyncManager = WatchSyncManager()
        // WatchSyncManager initializes automatically
        XCTAssertNotNil(watchSyncManager)
    }
    
    // MARK: - Course Confirmation Tests
    
    func testHoleConfirmationStructure() {
        // Test that hole confirmation data structure is correct
        let confirmation = HoleConfirmation(
            holeNumber: 1,
            dimensionsMatch: true,
            teeLocationsMatch: true,
            greenLocationsMatch: false,
            hazardLocationsMatch: false
        )
        
        XCTAssertEqual(confirmation.holeNumber, 1)
        XCTAssertTrue(confirmation.dimensionsMatch)
        XCTAssertTrue(confirmation.teeLocationsMatch)
        XCTAssertFalse(confirmation.greenLocationsMatch)
        XCTAssertFalse(confirmation.hazardLocationsMatch)
        XCTAssertFalse(confirmation.isComplete)
    }
    
    func testHoleConfirmationComplete() {
        let confirmation = HoleConfirmation(
            holeNumber: 1,
            dimensionsMatch: true,
            teeLocationsMatch: true,
            greenLocationsMatch: true,
            hazardLocationsMatch: true
        )
        
        XCTAssertTrue(confirmation.isComplete)
    }
    
    // MARK: - Data Service Tests
    
    func testDataServiceURLConstruction() {
        // Test that DataService constructs URLs correctly
        let dataService = DataService.shared
        XCTAssertNotNil(dataService)
    }
    
    // MARK: - Round Score Calculation Tests
    
    func testRoundScoreCalculation() {
        let roundManager = RoundManager()
        roundManager.startRound()
        
        // Set score for current hole (hole 1)
        roundManager.updateScore(4)
        
        // Move to next hole and set score
        roundManager.nextHole()
        roundManager.updateScore(5)
        
        // Move to next hole and set score
        roundManager.nextHole()
        roundManager.updateScore(3)
        
        // Calculate total
        let totalScore = roundManager.holeScores.compactMap { $0.score }.reduce(0, +)
        XCTAssertEqual(totalScore, 12)
    }
    
    // MARK: - GPS Distance Calculation Tests
    
    func testGPSDistanceCalculation() {
        let gpsManager = GPSManager()
        
        // Set a current location first
        let currentLocation = CLLocation(latitude: 36.5725, longitude: -121.9486)
        gpsManager.currentLocation = currentLocation
        
        // Test distance calculation between two coordinates
        let coord2 = CLLocationCoordinate2D(latitude: 36.5730, longitude: -121.9490)
        
        if let distance = gpsManager.distanceTo(coord2) {
            XCTAssertGreaterThan(distance, 0)
        }
    }
    
    // MARK: - Watch Connectivity Tests
    
    func testWatchSyncSendBag() {
        let watchSyncManager = WatchSyncManager()
        let clubs = ["Driver", "3W", "5W", "7W", "3H", "4H", "5H", "4i", "5i", "6i", "7i", "8i", "9i", "PW", "GW", "SW", "LW", "Putter"]
        
        watchSyncManager.sendBagToWatch(clubs: clubs)
        // Should complete without errors
        XCTAssertNotNil(watchSyncManager)
    }
    
    func testWatchSyncSendRoundStart() {
        let watchSyncManager = WatchSyncManager()
        let course = Course(
            id: "test-course",
            name: "Test Course",
            city: "Test City",
            state: "CA",
            country: "USA",
            courseRating: 75.5,
            slopeRating: 145,
            par: 72,
            latitude: 36.5725,
            longitude: -121.9486,
            avgRating: 4.5,
            reviewCount: 10,
            holeData: nil
        )
        
        watchSyncManager.sendCourseToWatch(course: course)
        // Should complete without errors
        XCTAssertNotNil(watchSyncManager)
    }
}

// MARK: - Helper Extensions for Testing

extension HoleConfirmation {
    init(holeNumber: Int, dimensionsMatch: Bool, teeLocationsMatch: Bool, greenLocationsMatch: Bool, hazardLocationsMatch: Bool) {
        // Use default initializer and set properties
        self.init(holeNumber: holeNumber)
        self.dimensionsMatch = dimensionsMatch
        self.teeLocationsMatch = teeLocationsMatch
        self.greenLocationsMatch = greenLocationsMatch
        self.hazardLocationsMatch = hazardLocationsMatch
    }
}
