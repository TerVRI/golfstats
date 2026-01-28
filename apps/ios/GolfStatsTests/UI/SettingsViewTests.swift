import XCTest
@testable import RoundCaddy

/// Tests for Settings views functionality
@MainActor
final class SettingsViewTests: XCTestCase {
    
    var userProfileManager: UserProfileManager!
    
    override func setUp() async throws {
        try await super.setUp()
        userProfileManager = UserProfileManager()
        // Clear any existing data
        UserDefaults.standard.removeObject(forKey: "user_profile")
        UserDefaults.standard.removeObject(forKey: "app_settings")
        UserDefaults.standard.removeObject(forKey: "round_preferences")
    }
    
    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "user_profile")
        UserDefaults.standard.removeObject(forKey: "app_settings")
        UserDefaults.standard.removeObject(forKey: "round_preferences")
        userProfileManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Settings Categories Tests
    
    func testSettingsCategoriesExist() {
        // Main settings categories that should exist
        let categories = [
            "Profile",
            "Golf Preferences",
            "App Settings",
            "Data & Storage",
            "Connected Services",
            "Help & Support",
            "About"
        ]
        
        XCTAssertEqual(categories.count, 7)
        XCTAssertTrue(categories.contains("Profile"))
        XCTAssertTrue(categories.contains("Golf Preferences"))
        XCTAssertTrue(categories.contains("App Settings"))
    }
    
    // MARK: - Units Settings Tests
    
    func testDistanceUnitOptions() {
        let options = DistanceUnit.allCases
        XCTAssertEqual(options.count, 2)
        XCTAssertTrue(options.contains(.yards))
        XCTAssertTrue(options.contains(.meters))
    }
    
    func testTemperatureUnitOptions() {
        let options = TemperatureUnit.allCases
        XCTAssertEqual(options.count, 2)
        XCTAssertTrue(options.contains(.fahrenheit))
        XCTAssertTrue(options.contains(.celsius))
    }
    
    func testSpeedUnitOptions() {
        let options = SpeedUnit.allCases
        XCTAssertEqual(options.count, 3)
        XCTAssertTrue(options.contains(.mph))
        XCTAssertTrue(options.contains(.kph))
        XCTAssertTrue(options.contains(.mps))
    }
    
    func testChangingDistanceUnit() {
        userProfileManager.initializeProfile(userId: "test")
        
        XCTAssertEqual(userProfileManager.distanceUnit, .yards)
        
        userProfileManager.updateProfile(distanceUnit: .meters)
        
        XCTAssertEqual(userProfileManager.distanceUnit, .meters)
    }
    
    // MARK: - Notification Settings Tests
    
    func testNotificationSettings() {
        let settings = AppSettings.default
        
        // Check all notification settings exist
        XCTAssertTrue(settings.roundReminderEnabled)
        XCTAssertTrue(settings.weatherAlertEnabled)
        XCTAssertTrue(settings.teeTimeReminderEnabled)
        XCTAssertTrue(settings.achievementNotificationsEnabled)
        XCTAssertTrue(settings.socialNotificationsEnabled)
        XCTAssertFalse(settings.marketingNotificationsEnabled)
    }
    
    func testToggleNotificationSetting() {
        userProfileManager.updateSettings(roundReminderEnabled: false)
        XCTAssertFalse(userProfileManager.appSettings.roundReminderEnabled)
        
        userProfileManager.updateSettings(roundReminderEnabled: true)
        XCTAssertTrue(userProfileManager.appSettings.roundReminderEnabled)
    }
    
    func testEnableAllNotifications() {
        userProfileManager.updateSettings(
            roundReminderEnabled: true,
            weatherAlertEnabled: true,
            teeTimeReminderEnabled: true,
            achievementNotificationsEnabled: true,
            socialNotificationsEnabled: true
        )
        
        let settings = userProfileManager.appSettings
        XCTAssertTrue(settings.roundReminderEnabled)
        XCTAssertTrue(settings.weatherAlertEnabled)
        XCTAssertTrue(settings.teeTimeReminderEnabled)
        XCTAssertTrue(settings.achievementNotificationsEnabled)
        XCTAssertTrue(settings.socialNotificationsEnabled)
    }
    
    func testDisableAllNotifications() {
        userProfileManager.updateSettings(
            roundReminderEnabled: false,
            weatherAlertEnabled: false,
            teeTimeReminderEnabled: false,
            achievementNotificationsEnabled: false,
            socialNotificationsEnabled: false,
            marketingNotificationsEnabled: false
        )
        
        let settings = userProfileManager.appSettings
        XCTAssertFalse(settings.roundReminderEnabled)
        XCTAssertFalse(settings.weatherAlertEnabled)
        XCTAssertFalse(settings.teeTimeReminderEnabled)
        XCTAssertFalse(settings.achievementNotificationsEnabled)
        XCTAssertFalse(settings.socialNotificationsEnabled)
        XCTAssertFalse(settings.marketingNotificationsEnabled)
    }
    
    // MARK: - Privacy Settings Tests
    
    func testPrivacySettingsDefaults() {
        let settings = AppSettings.default
        
        // Privacy-first defaults
        XCTAssertFalse(settings.shareRoundsPublicly)
        XCTAssertTrue(settings.showOnLeaderboards) // Opt-in by default for competitive users
        XCTAssertTrue(settings.allowFriendRequests)
    }
    
    func testTogglePrivacySettings() {
        userProfileManager.updateSettings(
            shareRoundsPublicly: true,
            showOnLeaderboards: false,
            allowFriendRequests: false
        )
        
        XCTAssertTrue(userProfileManager.appSettings.shareRoundsPublicly)
        XCTAssertFalse(userProfileManager.appSettings.showOnLeaderboards)
        XCTAssertFalse(userProfileManager.appSettings.allowFriendRequests)
    }
    
    // MARK: - Sound & Haptics Tests
    
    func testSoundHapticsDefaults() {
        let settings = AppSettings.default
        
        XCTAssertTrue(settings.soundEnabled)
        XCTAssertTrue(settings.hapticFeedbackEnabled)
        XCTAssertFalse(settings.voiceAnnouncementsEnabled)
    }
    
    func testToggleSoundSettings() {
        userProfileManager.updateSettings(
            soundEnabled: false,
            hapticFeedbackEnabled: false,
            voiceAnnouncementsEnabled: true
        )
        
        XCTAssertFalse(userProfileManager.appSettings.soundEnabled)
        XCTAssertFalse(userProfileManager.appSettings.hapticFeedbackEnabled)
        XCTAssertTrue(userProfileManager.appSettings.voiceAnnouncementsEnabled)
    }
    
    // MARK: - Round Preferences Tests
    
    func testRoundModeOptions() {
        let modes = RoundMode.allCases
        
        XCTAssertEqual(modes.count, 3)
        XCTAssertTrue(modes.contains(.quickScore))
        XCTAssertTrue(modes.contains(.fullTracking))
        XCTAssertTrue(modes.contains(.tournament))
    }
    
    func testRoundModeFeatures() {
        // Quick Score - minimal features
        let quickScore = RoundMode.quickScore.features
        XCTAssertFalse(quickScore.gpsEnabled)
        XCTAssertFalse(quickScore.shotTracking)
        XCTAssertTrue(quickScore.puttsTracking)
        
        // Full Tracking - most features
        let fullTracking = RoundMode.fullTracking.features
        XCTAssertTrue(fullTracking.gpsEnabled)
        XCTAssertTrue(fullTracking.shotTracking)
        XCTAssertTrue(fullTracking.watchSync)
        XCTAssertFalse(fullTracking.attestation)
        
        // Tournament - all features
        let tournament = RoundMode.tournament.features
        XCTAssertTrue(tournament.gpsEnabled)
        XCTAssertTrue(tournament.strokeIndex)
        XCTAssertTrue(tournament.handicapAdjustment)
        XCTAssertTrue(tournament.attestation)
    }
    
    func testTeeColorOptions() {
        let tees = TeeColor.allCases
        
        XCTAssertEqual(tees.count, 7)
        XCTAssertTrue(tees.contains(.black))
        XCTAssertTrue(tees.contains(.blue))
        XCTAssertTrue(tees.contains(.white))
        XCTAssertTrue(tees.contains(.yellow))
        XCTAssertTrue(tees.contains(.red))
        XCTAssertTrue(tees.contains(.gold))
        XCTAssertTrue(tees.contains(.green))
    }
    
    // MARK: - Map Style Tests
    
    func testMapStylePreferenceOptions() {
        let styles = MapStylePreference.allCases
        
        XCTAssertEqual(styles.count, 3)
        XCTAssertTrue(styles.contains(.satellite))
        XCTAssertTrue(styles.contains(.standard))
        XCTAssertTrue(styles.contains(.hybrid))
    }
    
    func testChangeMapStylePreference() {
        userProfileManager.updateSettings(mapStylePreference: .hybrid)
        XCTAssertEqual(userProfileManager.appSettings.mapStylePreference, .hybrid)
        
        userProfileManager.updateSettings(mapStylePreference: .standard)
        XCTAssertEqual(userProfileManager.appSettings.mapStylePreference, .standard)
    }
    
    // MARK: - Data & Backup Tests
    
    func testDataBackupDefaults() {
        let settings = AppSettings.default
        
        XCTAssertTrue(settings.autoBackupEnabled)
        XCTAssertTrue(settings.offlineDownloadOnWiFiOnly)
    }
    
    func testToggleBackupSettings() {
        userProfileManager.updateSettings(
            autoBackupEnabled: false,
            offlineDownloadOnWiFiOnly: false
        )
        
        XCTAssertFalse(userProfileManager.appSettings.autoBackupEnabled)
        XCTAssertFalse(userProfileManager.appSettings.offlineDownloadOnWiFiOnly)
    }
    
    // MARK: - Display Settings Tests
    
    func testDisplaySettingsDefaults() {
        let settings = AppSettings.default
        
        XCTAssertTrue(settings.keepScreenOnDuringRound)
        XCTAssertFalse(settings.autoAdvanceHole)
        XCTAssertTrue(settings.showYardageMarkers)
        XCTAssertTrue(settings.showHazardWarnings)
    }
    
    func testToggleDisplaySettings() {
        userProfileManager.updateSettings(
            keepScreenOnDuringRound: false,
            autoAdvanceHole: true,
            showYardageMarkers: false,
            showHazardWarnings: false
        )
        
        XCTAssertFalse(userProfileManager.appSettings.keepScreenOnDuringRound)
        XCTAssertTrue(userProfileManager.appSettings.autoAdvanceHole)
        XCTAssertFalse(userProfileManager.appSettings.showYardageMarkers)
        XCTAssertFalse(userProfileManager.appSettings.showHazardWarnings)
    }
}
