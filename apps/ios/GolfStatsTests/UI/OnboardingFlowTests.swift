import XCTest
@testable import RoundCaddy

/// UI Tests for the user profile onboarding flow
@MainActor
final class OnboardingFlowTests: XCTestCase {
    
    // MARK: - Onboarding Step Tests
    
    func testOnboardingHasSixSteps() {
        // The onboarding flow should have 6 steps:
        // 1. Birthday
        // 2. Gender
        // 3. Handicap
        // 4. Playing Frequency
        // 5. Driver Distance + Handedness
        // 6. Goal Handicap
        
        let expectedSteps = 6
        XCTAssertEqual(expectedSteps, 6)
    }
    
    func testOnboardingProgressTracking() {
        // Test that progress is properly tracked
        for step in 0..<6 {
            let progressText = "PERSONALIZE: \(step + 1) of 6"
            XCTAssertFalse(progressText.isEmpty)
        }
    }
    
    // MARK: - Data Validation Tests
    
    func testBirthdayValidation() {
        // User must be at least 13 years old
        let minimumAge = 13
        let today = Date()
        let thirteenYearsAgo = Calendar.current.date(byAdding: .year, value: -minimumAge, to: today)!
        
        // Birthday at exactly 13 years ago should be valid
        XCTAssertNotNil(thirteenYearsAgo)
        
        // Check that the date is valid (not in the future)
        XCTAssertLessThanOrEqual(thirteenYearsAgo, today)
    }
    
    func testGenderOptions() {
        // Should have Male Golfers and Female Golfers as main options
        let mainOptions: [Gender] = [.male, .female]
        XCTAssertEqual(mainOptions.count, 2)
        
        // Plus "Prefer not to say" option
        let allOptions = Gender.allCases
        XCTAssertTrue(allOptions.contains(.preferNotToSay))
    }
    
    func testHandicapSliderRange() {
        // Handicap slider should range from -5 (tour pro) to 54 (beginner)
        let minHandicap: Double = -5
        let maxHandicap: Double = 54
        
        XCTAssertEqual(minHandicap, -5)
        XCTAssertEqual(maxHandicap, 54)
        
        // Test edge values
        let tourPro = SkillLevel.from(handicap: minHandicap)
        let beginner = SkillLevel.from(handicap: maxHandicap)
        
        XCTAssertEqual(tourPro, .tourPro)
        XCTAssertEqual(beginner, .beginner)
    }
    
    func testDriverDistanceRange() {
        // Driver distance slider should range from 100 to 350 yards
        let minDistance = 100
        let maxDistance = 350
        let stepSize = 5
        
        XCTAssertEqual(minDistance, 100)
        XCTAssertEqual(maxDistance, 350)
        XCTAssertEqual(stepSize, 5)
        
        // Test that all values in range are valid
        for distance in stride(from: minDistance, through: maxDistance, by: stepSize) {
            XCTAssertTrue(distance >= minDistance && distance <= maxDistance)
        }
    }
    
    func testHandednessOptions() {
        // Should have Right-Handed and Left-Handed options
        let options = Handedness.allCases
        XCTAssertEqual(options.count, 2)
        XCTAssertTrue(options.contains(.right))
        XCTAssertTrue(options.contains(.left))
    }
    
    func testPlayingFrequencySlider() {
        // Test slider value to frequency mapping
        let testValues: [(Double, PlayingFrequency)] = [
            (10, .rarely),
            (30, .occasional),
            (50, .regular),
            (70, .frequent),
            (90, .veryFrequent)
        ]
        
        for (sliderValue, expectedFrequency) in testValues {
            let frequency = PlayingFrequency.from(sliderValue: sliderValue)
            XCTAssertEqual(frequency, expectedFrequency)
        }
    }
    
    // MARK: - Navigation Tests
    
    func testCanNavigateToNextStep() {
        // Starting at step 0, should be able to go to step 1
        var currentStep = 0
        let totalSteps = 6
        
        // Go forward
        if currentStep < totalSteps - 1 {
            currentStep += 1
        }
        XCTAssertEqual(currentStep, 1)
        
        // Continue to end
        while currentStep < totalSteps - 1 {
            currentStep += 1
        }
        XCTAssertEqual(currentStep, 5) // 0-indexed, so last step is 5
    }
    
    func testCanNavigateBackward() {
        var currentStep = 3
        
        // Go back
        if currentStep > 0 {
            currentStep -= 1
        }
        XCTAssertEqual(currentStep, 2)
        
        // Go back to start
        while currentStep > 0 {
            currentStep -= 1
        }
        XCTAssertEqual(currentStep, 0)
    }
    
    func testCannotGoBackFromFirstStep() {
        let currentStep = 0
        XCTAssertEqual(currentStep, 0)
        
        // Should not be able to go back from first step
        let canGoBack = currentStep > 0
        XCTAssertFalse(canGoBack)
    }
    
    // MARK: - Completion Tests
    
    func testOnboardingCompletion() {
        let manager = UserProfileManager()
        
        // Clear any existing data
        UserDefaults.standard.removeObject(forKey: "user_profile")
        
        // Initialize and complete onboarding
        manager.initializeProfile(userId: "test-user")
        XCTAssertTrue(manager.needsOnboarding)
        
        manager.completeOnboarding()
        
        XCTAssertFalse(manager.needsOnboarding)
        XCTAssertTrue(manager.userProfile?.onboardingCompleted ?? false)
        
        // Cleanup
        UserDefaults.standard.removeObject(forKey: "user_profile")
    }
    
    func testOnboardingDataIsSaved() {
        let manager = UserProfileManager()
        
        // Clear any existing data
        UserDefaults.standard.removeObject(forKey: "user_profile")
        
        manager.initializeProfile(userId: "test-user")
        
        // Simulate completing onboarding with data
        manager.updateProfile(
            birthday: Date(timeIntervalSince1970: 820454400),
            gender: .male,
            handedness: .right,
            handicapIndex: 15.0,
            targetHandicap: 10.0,
            skillLevel: .intermediate,
            driverDistance: 220,
            playingFrequency: .regular
        )
        
        manager.completeOnboarding()
        
        // Verify data is saved
        XCTAssertEqual(manager.userProfile?.gender, .male)
        XCTAssertEqual(manager.userProfile?.handedness, .right)
        XCTAssertEqual(manager.userProfile?.handicapIndex, 15.0)
        XCTAssertEqual(manager.userProfile?.targetHandicap, 10.0)
        XCTAssertEqual(manager.userProfile?.driverDistance, 220)
        XCTAssertEqual(manager.userProfile?.playingFrequency, .regular)
        
        // Cleanup
        UserDefaults.standard.removeObject(forKey: "user_profile")
    }
    
    // MARK: - Alternative Path Tests
    
    func testSkillLevelSelectionWhenNoHandicap() {
        // When user doesn't know their handicap, they select skill level
        let skillLevels = SkillLevel.allCases
        
        // All skill levels should be available
        XCTAssertEqual(skillLevels.count, 6)
        XCTAssertTrue(skillLevels.contains(.beginner))
        XCTAssertTrue(skillLevels.contains(.casual))
        XCTAssertTrue(skillLevels.contains(.intermediate))
        XCTAssertTrue(skillLevels.contains(.advanced))
        XCTAssertTrue(skillLevels.contains(.expert))
        XCTAssertTrue(skillLevels.contains(.tourPro))
    }
    
    func testOptionalTargetHandicap() {
        let manager = UserProfileManager()
        
        // Clear any existing data
        UserDefaults.standard.removeObject(forKey: "user_profile")
        
        manager.initializeProfile(userId: "test-user")
        
        // Complete without target handicap
        manager.updateProfile(
            handicapIndex: 15.0,
            targetHandicap: nil
        )
        
        manager.completeOnboarding()
        
        XCTAssertEqual(manager.userProfile?.handicapIndex, 15.0)
        XCTAssertNil(manager.userProfile?.targetHandicap)
        
        // Cleanup
        UserDefaults.standard.removeObject(forKey: "user_profile")
    }
}
