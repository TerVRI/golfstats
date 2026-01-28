import XCTest
@testable import RoundCaddy

/// Tests for AppSettings model
final class AppSettingsTests: XCTestCase {
    
    // MARK: - Default Values Tests
    
    func testDefaultSettings() {
        let settings = AppSettings.default
        
        // Notification Preferences
        XCTAssertTrue(settings.roundReminderEnabled)
        XCTAssertTrue(settings.weatherAlertEnabled)
        XCTAssertTrue(settings.teeTimeReminderEnabled)
        XCTAssertTrue(settings.achievementNotificationsEnabled)
        XCTAssertTrue(settings.socialNotificationsEnabled)
        XCTAssertFalse(settings.marketingNotificationsEnabled)
        
        // Sound & Haptics
        XCTAssertTrue(settings.soundEnabled)
        XCTAssertTrue(settings.hapticFeedbackEnabled)
        XCTAssertFalse(settings.voiceAnnouncementsEnabled)
        
        // Privacy
        XCTAssertFalse(settings.shareRoundsPublicly)
        XCTAssertTrue(settings.showOnLeaderboards)
        XCTAssertTrue(settings.allowFriendRequests)
        
        // Display
        XCTAssertTrue(settings.keepScreenOnDuringRound)
        XCTAssertFalse(settings.autoAdvanceHole)
        XCTAssertTrue(settings.showYardageMarkers)
        XCTAssertTrue(settings.showHazardWarnings)
        XCTAssertEqual(settings.mapStylePreference, .satellite)
        
        // Data & Storage
        XCTAssertTrue(settings.autoBackupEnabled)
        XCTAssertTrue(settings.offlineDownloadOnWiFiOnly)
    }
    
    func testAppSettingsCodable() throws {
        var settings = AppSettings()
        settings.roundReminderEnabled = false
        settings.soundEnabled = false
        settings.shareRoundsPublicly = true
        settings.mapStylePreference = .hybrid
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppSettings.self, from: data)
        
        XCTAssertFalse(decoded.roundReminderEnabled)
        XCTAssertFalse(decoded.soundEnabled)
        XCTAssertTrue(decoded.shareRoundsPublicly)
        XCTAssertEqual(decoded.mapStylePreference, .hybrid)
    }
    
    func testAppSettingsEquatable() {
        let settings1 = AppSettings.default
        let settings2 = AppSettings.default
        
        XCTAssertEqual(settings1, settings2)
        
        var settings3 = AppSettings.default
        settings3.soundEnabled = false
        
        XCTAssertNotEqual(settings1, settings3)
    }
    
    // MARK: - MapStylePreference Tests
    
    func testMapStylePreferenceDisplayName() {
        XCTAssertEqual(MapStylePreference.satellite.displayName, "Satellite")
        XCTAssertEqual(MapStylePreference.standard.displayName, "Standard")
        XCTAssertEqual(MapStylePreference.hybrid.displayName, "Hybrid")
    }
    
    func testMapStylePreferenceCodable() throws {
        let styles: [MapStylePreference] = [.satellite, .standard, .hybrid]
        
        for style in styles {
            let encoder = JSONEncoder()
            let data = try encoder.encode(style)
            
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(MapStylePreference.self, from: data)
            
            XCTAssertEqual(decoded, style)
        }
    }
}
