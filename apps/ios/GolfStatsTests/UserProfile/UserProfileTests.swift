import XCTest
@testable import RoundCaddy

/// Tests for UserProfile model and related enums
final class UserProfileTests: XCTestCase {
    
    // MARK: - UserProfile Tests
    
    func testUserProfileCreation() {
        let userId = "test-user-123"
        let profile = UserProfile.new(userId: userId)
        
        XCTAssertEqual(profile.userId, userId)
        XCTAssertNotNil(profile.id)
        XCTAssertNil(profile.birthday)
        XCTAssertNil(profile.gender)
        XCTAssertEqual(profile.handedness, .right)
        XCTAssertNil(profile.handicapIndex)
        XCTAssertEqual(profile.skillLevel, .intermediate)
        XCTAssertEqual(profile.driverDistance, 220)
        XCTAssertEqual(profile.playingFrequency, .occasional)
        XCTAssertEqual(profile.preferredTees, .white)
        XCTAssertEqual(profile.distanceUnit, .yards)
        XCTAssertEqual(profile.temperatureUnit, .fahrenheit)
        XCTAssertFalse(profile.onboardingCompleted)
    }
    
    func testAgeCalculation() {
        var profile = UserProfile.new(userId: "test")
        
        // No birthday set
        XCTAssertNil(profile.age)
        
        // Set birthday to 30 years ago
        let thirtyYearsAgo = Calendar.current.date(byAdding: .year, value: -30, to: Date())!
        profile.birthday = thirtyYearsAgo
        XCTAssertEqual(profile.age, 30)
        
        // Set birthday to 25 years and 6 months ago
        let twentyFiveAndHalf = Calendar.current.date(byAdding: .month, value: -306, to: Date())!
        profile.birthday = twentyFiveAndHalf
        XCTAssertEqual(profile.age, 25)
    }
    
    func testEstimatedAverageScore() {
        var profile = UserProfile.new(userId: "test")
        
        // No handicap
        XCTAssertNil(profile.estimatedAverageScore)
        
        // Set handicap of 10
        profile.handicapIndex = 10.0
        XCTAssertEqual(profile.estimatedAverageScore, 82) // 72 + 10
        
        // Set handicap of 18.5
        profile.handicapIndex = 18.5
        XCTAssertEqual(profile.estimatedAverageScore, 91) // 72 + 19 (rounded)
    }
    
    func testUserProfileCodable() throws {
        var profile = UserProfile.new(userId: "test-user")
        profile.birthday = Date(timeIntervalSince1970: 820454400) // Jan 1, 1996
        profile.gender = .male
        profile.handicapIndex = 12.5
        profile.targetHandicap = 8.0
        profile.skillLevel = .advanced
        profile.driverDistance = 250
        profile.playingFrequency = .frequent
        profile.preferredTees = .blue
        profile.distanceUnit = .meters
        profile.temperatureUnit = .celsius
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(profile)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(UserProfile.self, from: data)
        
        XCTAssertEqual(decoded.userId, profile.userId)
        XCTAssertEqual(decoded.gender, .male)
        XCTAssertEqual(decoded.handicapIndex, 12.5)
        XCTAssertEqual(decoded.targetHandicap, 8.0)
        XCTAssertEqual(decoded.skillLevel, .advanced)
        XCTAssertEqual(decoded.driverDistance, 250)
        XCTAssertEqual(decoded.playingFrequency, .frequent)
        XCTAssertEqual(decoded.preferredTees, .blue)
        XCTAssertEqual(decoded.distanceUnit, .meters)
        XCTAssertEqual(decoded.temperatureUnit, .celsius)
    }
    
    // MARK: - SkillLevel Tests
    
    func testSkillLevelFromHandicap() {
        // Beginner: 30-54
        XCTAssertEqual(SkillLevel.from(handicap: 35), .beginner)
        XCTAssertEqual(SkillLevel.from(handicap: 54), .beginner)
        
        // Casual: 20-30
        XCTAssertEqual(SkillLevel.from(handicap: 25), .casual)
        XCTAssertEqual(SkillLevel.from(handicap: 20), .casual)
        
        // Intermediate: 10-20
        XCTAssertEqual(SkillLevel.from(handicap: 15), .intermediate)
        XCTAssertEqual(SkillLevel.from(handicap: 10), .intermediate)
        
        // Advanced: 5-10
        XCTAssertEqual(SkillLevel.from(handicap: 7), .advanced)
        XCTAssertEqual(SkillLevel.from(handicap: 5), .advanced)
        
        // Expert: 0-5
        XCTAssertEqual(SkillLevel.from(handicap: 2), .expert)
        XCTAssertEqual(SkillLevel.from(handicap: 0), .expert)
        
        // Tour Pro: -5 to 0
        XCTAssertEqual(SkillLevel.from(handicap: -2), .tourPro)
        XCTAssertEqual(SkillLevel.from(handicap: -5), .tourPro)
    }
    
    func testSkillLevelHandicapRanges() {
        XCTAssertTrue(SkillLevel.beginner.handicapRange.contains(40))
        XCTAssertFalse(SkillLevel.beginner.handicapRange.contains(20))
        
        XCTAssertTrue(SkillLevel.expert.handicapRange.contains(3))
        XCTAssertFalse(SkillLevel.expert.handicapRange.contains(10))
    }
    
    // MARK: - PlayingFrequency Tests
    
    func testPlayingFrequencyFromSlider() {
        XCTAssertEqual(PlayingFrequency.from(sliderValue: 5), .rarely)
        XCTAssertEqual(PlayingFrequency.from(sliderValue: 30), .occasional)
        XCTAssertEqual(PlayingFrequency.from(sliderValue: 50), .regular)
        XCTAssertEqual(PlayingFrequency.from(sliderValue: 70), .frequent)
        XCTAssertEqual(PlayingFrequency.from(sliderValue: 90), .veryFrequent)
    }
    
    func testPlayingFrequencyRoundsPerYear() {
        XCTAssertEqual(PlayingFrequency.rarely.roundsPerYear, 3)
        XCTAssertEqual(PlayingFrequency.occasional.roundsPerYear, 10)
        XCTAssertEqual(PlayingFrequency.regular.roundsPerYear, 23)
        XCTAssertEqual(PlayingFrequency.frequent.roundsPerYear, 40)
        XCTAssertEqual(PlayingFrequency.veryFrequent.roundsPerYear, 60)
    }
    
    // MARK: - DistanceUnit Tests
    
    func testDistanceUnitConversion() {
        // Yards should stay the same
        XCTAssertEqual(DistanceUnit.yards.convert(yards: 150), 150)
        
        // Meters conversion (1 yard = 0.9144 meters)
        XCTAssertEqual(DistanceUnit.meters.convert(yards: 100), 91.44, accuracy: 0.01)
        XCTAssertEqual(DistanceUnit.meters.convert(yards: 200), 182.88, accuracy: 0.01)
    }
    
    func testDistanceUnitFormatting() {
        XCTAssertEqual(DistanceUnit.yards.format(150), "150yd")
        XCTAssertEqual(DistanceUnit.meters.format(150), "137m") // ~137.16 rounded
    }
    
    // MARK: - TemperatureUnit Tests
    
    func testTemperatureUnitConversion() {
        // Fahrenheit should stay the same
        XCTAssertEqual(TemperatureUnit.fahrenheit.convert(fahrenheit: 72), 72)
        
        // Celsius conversion
        XCTAssertEqual(TemperatureUnit.celsius.convert(fahrenheit: 32), 0, accuracy: 0.1)
        XCTAssertEqual(TemperatureUnit.celsius.convert(fahrenheit: 72), 22.22, accuracy: 0.1)
        XCTAssertEqual(TemperatureUnit.celsius.convert(fahrenheit: 100), 37.78, accuracy: 0.1)
    }
    
    func testTemperatureUnitFormatting() {
        XCTAssertEqual(TemperatureUnit.fahrenheit.format(72), "72°F")
        XCTAssertEqual(TemperatureUnit.celsius.format(72), "22°C")
    }
    
    // MARK: - SpeedUnit Tests
    
    func testSpeedUnitConversion() {
        // MPH should stay the same
        XCTAssertEqual(SpeedUnit.mph.convert(mph: 10), 10)
        
        // KPH conversion (1 mph = 1.60934 kph)
        XCTAssertEqual(SpeedUnit.kph.convert(mph: 10), 16.09, accuracy: 0.1)
        
        // MPS conversion (1 mph = 0.44704 mps)
        XCTAssertEqual(SpeedUnit.mps.convert(mph: 10), 4.47, accuracy: 0.1)
    }
    
    // MARK: - Gender Tests
    
    func testGenderComparisonGroup() {
        XCTAssertEqual(Gender.male.comparisonGroup, "Male Golfers")
        XCTAssertEqual(Gender.female.comparisonGroup, "Female Golfers")
        XCTAssertEqual(Gender.other.comparisonGroup, "All Golfers")
        XCTAssertEqual(Gender.preferNotToSay.comparisonGroup, "All Golfers")
    }
    
    // MARK: - Handedness Tests
    
    func testHandednessShortName() {
        XCTAssertEqual(Handedness.right.shortName, "RH")
        XCTAssertEqual(Handedness.left.shortName, "LH")
    }
    
    // MARK: - TeeColor Tests
    
    func testTeeColorDisplayNames() {
        XCTAssertEqual(TeeColor.black.displayName, "Black (Championship)")
        XCTAssertEqual(TeeColor.blue.displayName, "Blue (Back)")
        XCTAssertEqual(TeeColor.white.displayName, "White (Middle)")
        XCTAssertEqual(TeeColor.red.displayName, "Red (Forward)")
    }
}
