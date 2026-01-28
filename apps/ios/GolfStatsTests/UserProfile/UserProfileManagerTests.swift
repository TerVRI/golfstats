import XCTest
@testable import RoundCaddy

/// Tests for UserProfileManager
@MainActor
final class UserProfileManagerTests: XCTestCase {
    
    var sut: UserProfileManager!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = UserProfileManager()
        // Clear any existing data
        UserDefaults.standard.removeObject(forKey: "user_profile")
        UserDefaults.standard.removeObject(forKey: "app_settings")
    }
    
    override func tearDown() async throws {
        // Clean up
        UserDefaults.standard.removeObject(forKey: "user_profile")
        UserDefaults.standard.removeObject(forKey: "app_settings")
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Profile Initialization Tests
    
    func testInitializeProfile() {
        let userId = "test-user-123"
        
        XCTAssertNil(sut.userProfile)
        
        sut.initializeProfile(userId: userId)
        
        XCTAssertNotNil(sut.userProfile)
        XCTAssertEqual(sut.userProfile?.userId, userId)
        XCTAssertTrue(sut.needsOnboarding)
    }
    
    func testInitializeProfileDoesNotOverwrite() {
        let userId1 = "user-1"
        let userId2 = "user-2"
        
        sut.initializeProfile(userId: userId1)
        let originalId = sut.userProfile?.id
        
        // Try to initialize again - should not overwrite
        sut.initializeProfile(userId: userId2)
        
        XCTAssertEqual(sut.userProfile?.id, originalId)
        XCTAssertEqual(sut.userProfile?.userId, userId1)
    }
    
    // MARK: - Profile Update Tests
    
    func testUpdateProfileFields() {
        sut.initializeProfile(userId: "test-user")
        
        sut.updateProfile(
            birthday: Date(timeIntervalSince1970: 820454400),
            gender: .male,
            handedness: .left,
            handicapIndex: 15.5,
            targetHandicap: 10.0,
            skillLevel: .intermediate,
            driverDistance: 250,
            playingFrequency: .frequent,
            preferredTees: .blue,
            distanceUnit: .meters,
            temperatureUnit: .celsius,
            speedUnit: .kph
        )
        
        XCTAssertNotNil(sut.userProfile?.birthday)
        XCTAssertEqual(sut.userProfile?.gender, .male)
        XCTAssertEqual(sut.userProfile?.handedness, .left)
        XCTAssertEqual(sut.userProfile?.handicapIndex, 15.5)
        XCTAssertEqual(sut.userProfile?.targetHandicap, 10.0)
        XCTAssertEqual(sut.userProfile?.skillLevel, .intermediate)
        XCTAssertEqual(sut.userProfile?.driverDistance, 250)
        XCTAssertEqual(sut.userProfile?.playingFrequency, .frequent)
        XCTAssertEqual(sut.userProfile?.preferredTees, .blue)
        XCTAssertEqual(sut.userProfile?.distanceUnit, .meters)
        XCTAssertEqual(sut.userProfile?.temperatureUnit, .celsius)
        XCTAssertEqual(sut.userProfile?.speedUnit, .kph)
    }
    
    func testPartialProfileUpdate() {
        sut.initializeProfile(userId: "test-user")
        
        // Set initial values
        sut.updateProfile(handicapIndex: 15.0, driverDistance: 220)
        
        // Update only handicap - driver distance should stay the same
        sut.updateProfile(handicapIndex: 12.0)
        
        XCTAssertEqual(sut.userProfile?.handicapIndex, 12.0)
        XCTAssertEqual(sut.userProfile?.driverDistance, 220)
    }
    
    func testCompleteOnboarding() {
        sut.initializeProfile(userId: "test-user")
        XCTAssertTrue(sut.needsOnboarding)
        XCTAssertFalse(sut.userProfile?.onboardingCompleted ?? true)
        
        sut.completeOnboarding()
        
        XCTAssertFalse(sut.needsOnboarding)
        XCTAssertTrue(sut.userProfile?.onboardingCompleted ?? false)
    }
    
    // MARK: - Settings Tests
    
    func testUpdateSettings() {
        sut.updateSettings(
            roundReminderEnabled: false,
            weatherAlertEnabled: true,
            soundEnabled: false,
            hapticFeedbackEnabled: true,
            shareRoundsPublicly: true,
            keepScreenOnDuringRound: false
        )
        
        XCTAssertFalse(sut.appSettings.roundReminderEnabled)
        XCTAssertTrue(sut.appSettings.weatherAlertEnabled)
        XCTAssertFalse(sut.appSettings.soundEnabled)
        XCTAssertTrue(sut.appSettings.hapticFeedbackEnabled)
        XCTAssertTrue(sut.appSettings.shareRoundsPublicly)
        XCTAssertFalse(sut.appSettings.keepScreenOnDuringRound)
    }
    
    func testAppSettingsDefault() {
        let settings = AppSettings.default
        
        XCTAssertTrue(settings.roundReminderEnabled)
        XCTAssertTrue(settings.weatherAlertEnabled)
        XCTAssertTrue(settings.soundEnabled)
        XCTAssertTrue(settings.hapticFeedbackEnabled)
        XCTAssertFalse(settings.shareRoundsPublicly)
        XCTAssertTrue(settings.keepScreenOnDuringRound)
        XCTAssertFalse(settings.marketingNotificationsEnabled)
    }
    
    // MARK: - Convenience Accessor Tests
    
    func testDistanceUnitAccessor() {
        XCTAssertEqual(sut.distanceUnit, .yards) // Default when no profile
        
        sut.initializeProfile(userId: "test")
        sut.updateProfile(distanceUnit: .meters)
        
        XCTAssertEqual(sut.distanceUnit, .meters)
    }
    
    func testTemperatureUnitAccessor() {
        XCTAssertEqual(sut.temperatureUnit, .fahrenheit) // Default
        
        sut.initializeProfile(userId: "test")
        sut.updateProfile(temperatureUnit: .celsius)
        
        XCTAssertEqual(sut.temperatureUnit, .celsius)
    }
    
    func testHandicapAccessor() {
        XCTAssertNil(sut.handicap) // No profile
        
        sut.initializeProfile(userId: "test")
        XCTAssertNil(sut.handicap) // Profile but no handicap
        
        sut.updateProfile(handicapIndex: 12.5)
        XCTAssertEqual(sut.handicap, 12.5)
    }
    
    func testFormatDistance() {
        sut.initializeProfile(userId: "test")
        
        // Default is yards
        XCTAssertEqual(sut.formatDistance(150), "150yd")
        
        // Switch to meters
        sut.updateProfile(distanceUnit: .meters)
        XCTAssertEqual(sut.formatDistance(150), "137m")
    }
    
    func testFormatTemperature() {
        sut.initializeProfile(userId: "test")
        
        // Default is Fahrenheit
        XCTAssertEqual(sut.formatTemperature(72), "72°F")
        
        // Switch to Celsius
        sut.updateProfile(temperatureUnit: .celsius)
        XCTAssertEqual(sut.formatTemperature(72), "22°C")
    }
    
    // MARK: - Persistence Tests
    
    func testProfilePersistence() {
        sut.initializeProfile(userId: "test-user")
        sut.updateProfile(
            handicapIndex: 15.0,
            driverDistance: 250,
            preferredTees: .blue
        )
        
        // Create new manager instance - should load from UserDefaults
        let newManager = UserProfileManager()
        
        XCTAssertNotNil(newManager.userProfile)
        XCTAssertEqual(newManager.userProfile?.userId, "test-user")
        XCTAssertEqual(newManager.userProfile?.handicapIndex, 15.0)
        XCTAssertEqual(newManager.userProfile?.driverDistance, 250)
        XCTAssertEqual(newManager.userProfile?.preferredTees, .blue)
    }
    
    func testSettingsPersistence() {
        sut.updateSettings(
            soundEnabled: false,
            mapStylePreference: .hybrid
        )
        
        // Create new manager instance
        let newManager = UserProfileManager()
        
        XCTAssertFalse(newManager.appSettings.soundEnabled)
        XCTAssertEqual(newManager.appSettings.mapStylePreference, .hybrid)
    }
    
    func testClearLocalData() {
        sut.initializeProfile(userId: "test-user")
        sut.updateProfile(handicapIndex: 15.0)
        sut.updateSettings(soundEnabled: false)
        
        XCTAssertNotNil(sut.userProfile)
        XCTAssertFalse(sut.appSettings.soundEnabled)
        
        sut.clearLocalData()
        
        XCTAssertNil(sut.userProfile)
        XCTAssertTrue(sut.appSettings.soundEnabled) // Back to default
        XCTAssertFalse(sut.needsOnboarding)
    }
}
