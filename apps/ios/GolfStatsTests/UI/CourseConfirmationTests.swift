import XCTest
import SwiftUI
import CoreLocation
@testable import RoundCaddy

final class CourseConfirmationTests: XCTestCase {
    
    func testHoleDataEntryInitialization() {
        // HoleDataEntry uses default initializer
        var holeDataEntry = HoleDataEntry(holeNumber: 1, par: 4, yardage: 0)
        holeDataEntry.yardage = 380
        
        XCTAssertEqual(holeDataEntry.holeNumber, 1)
        XCTAssertEqual(holeDataEntry.par, 4)
        XCTAssertEqual(holeDataEntry.yardage, 380)
        XCTAssertNotNil(holeDataEntry.id)
    }
    
    func testHoleConfirmationGPSMarking() {
        var confirmation = HoleConfirmation(holeNumber: 1)
        
        // Mark tee box location
        let teeBoxLocation = CLLocationCoordinate2D(latitude: 36.5725, longitude: -121.9486)
        confirmation.markedTeeBox = teeBoxLocation
        
        XCTAssertNotNil(confirmation.markedTeeBox)
        XCTAssertEqual(confirmation.markedTeeBox?.latitude, 36.5725)
        XCTAssertEqual(confirmation.markedTeeBox?.longitude, -121.9486)
    }
    
    func testHoleConfirmationMultipleLocations() {
        var confirmation = HoleConfirmation(holeNumber: 1)
        
        confirmation.markedTeeBox = CLLocationCoordinate2D(latitude: 36.5725, longitude: -121.9486)
        confirmation.markedGreenCenter = CLLocationCoordinate2D(latitude: 36.5730, longitude: -121.9490)
        confirmation.markedGreenFront = CLLocationCoordinate2D(latitude: 36.5728, longitude: -121.9490)
        confirmation.markedGreenBack = CLLocationCoordinate2D(latitude: 36.5732, longitude: -121.9490)
        
        XCTAssertNotNil(confirmation.markedTeeBox)
        XCTAssertNotNil(confirmation.markedGreenCenter)
        XCTAssertNotNil(confirmation.markedGreenFront)
        XCTAssertNotNil(confirmation.markedGreenBack)
    }
    
    func testHoleConfirmationJSONConversion() {
        var confirmation = HoleConfirmation(holeNumber: 1)
        confirmation.dimensionsMatch = true
        confirmation.teeLocationsMatch = true
        confirmation.greenLocationsMatch = true
        confirmation.hazardLocationsMatch = false
        confirmation.markedTeeBox = CLLocationCoordinate2D(latitude: 36.5725, longitude: -121.9486)
        confirmation.notes = "Test notes"
        
        let json = confirmation.toJSON()
        
        XCTAssertEqual(json["hole_number"] as? Int, 1)
        XCTAssertEqual(json["dimensions_match"] as? Bool, true)
        XCTAssertEqual(json["tee_locations_match"] as? Bool, true)
        XCTAssertEqual(json["green_locations_match"] as? Bool, true)
        XCTAssertEqual(json["hazard_locations_match"] as? Bool, false)
        XCTAssertNotNil(json["marked_tee_box"])
        XCTAssertEqual(json["notes"] as? String, "Test notes")
    }
}

// Extension for test convenience initializer
extension HoleConfirmation {
    init(holeNumber: Int) {
        // Use memberwise initializer with defaults
        self.init(
            holeNumber: holeNumber,
            dimensionsMatch: false,
            teeLocationsMatch: false,
            greenLocationsMatch: false,
            hazardLocationsMatch: false,
            markedTeeBox: nil,
            markedGreenCenter: nil,
            markedGreenFront: nil,
            markedGreenBack: nil,
            markedHazards: [],
            notes: ""
        )
    }
}

// Note: HoleDataEntry has a let id property, so we can't create a custom initializer
// Tests will use the default initializer and set properties after creation
