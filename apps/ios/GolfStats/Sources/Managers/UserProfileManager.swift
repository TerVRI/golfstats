import Foundation
import Combine

/// Manages user profile data and app settings
/// Handles local persistence and server sync
@MainActor
class UserProfileManager: ObservableObject {
    static let shared = UserProfileManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var userProfile: UserProfile?
    @Published private(set) var appSettings: AppSettings = .default
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published var needsOnboarding = false
    
    // MARK: - Private Properties
    
    private let profileKey = "user_profile"
    private let settingsKey = "app_settings"
    private let onboardingCompletedKey = "onboarding_completed"
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        loadLocalData()
    }
    
    // MARK: - Profile Management
    
    /// Load profile from local storage
    private func loadLocalData() {
        // Load profile
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.userProfile = profile
            self.needsOnboarding = !profile.onboardingCompleted
        }
        
        // Load settings
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.appSettings = settings
        }
    }
    
    /// Initialize profile for a new user
    func initializeProfile(userId: String) {
        if userProfile == nil {
            userProfile = UserProfile.new(userId: userId)
            needsOnboarding = true
            saveProfileLocally()
        }
    }
    
    /// Update the user profile
    func updateProfile(_ profile: UserProfile) {
        var updated = profile
        updated.updatedAt = Date()
        self.userProfile = updated
        saveProfileLocally()
    }
    
    /// Update specific profile fields
    func updateProfile(
        birthday: Date? = nil,
        gender: Gender? = nil,
        handedness: Handedness? = nil,
        handicapIndex: Double? = nil,
        targetHandicap: Double? = nil,
        skillLevel: SkillLevel? = nil,
        driverDistance: Int? = nil,
        playingFrequency: PlayingFrequency? = nil,
        preferredTees: TeeColor? = nil,
        distanceUnit: DistanceUnit? = nil,
        temperatureUnit: TemperatureUnit? = nil,
        speedUnit: SpeedUnit? = nil
    ) {
        guard var profile = userProfile else { return }
        
        if let birthday = birthday { profile.birthday = birthday }
        if let gender = gender { profile.gender = gender }
        if let handedness = handedness { profile.handedness = handedness }
        if let handicapIndex = handicapIndex { profile.handicapIndex = handicapIndex }
        if let targetHandicap = targetHandicap { profile.targetHandicap = targetHandicap }
        if let skillLevel = skillLevel { profile.skillLevel = skillLevel }
        if let driverDistance = driverDistance { profile.driverDistance = driverDistance }
        if let playingFrequency = playingFrequency { profile.playingFrequency = playingFrequency }
        if let preferredTees = preferredTees { profile.preferredTees = preferredTees }
        if let distanceUnit = distanceUnit { profile.distanceUnit = distanceUnit }
        if let temperatureUnit = temperatureUnit { profile.temperatureUnit = temperatureUnit }
        if let speedUnit = speedUnit { profile.speedUnit = speedUnit }
        
        profile.updatedAt = Date()
        self.userProfile = profile
        saveProfileLocally()
    }
    
    /// Mark onboarding as complete
    func completeOnboarding() {
        guard var profile = userProfile else { return }
        profile.onboardingCompleted = true
        profile.updatedAt = Date()
        self.userProfile = profile
        self.needsOnboarding = false
        saveProfileLocally()
        
        // Sync to server
        Task {
            await syncProfileToServer()
        }
    }
    
    /// Save profile to local storage
    private func saveProfileLocally() {
        guard let profile = userProfile else { return }
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
    }
    
    // MARK: - Settings Management
    
    /// Update app settings
    func updateSettings(_ settings: AppSettings) {
        self.appSettings = settings
        saveSettingsLocally()
    }
    
    /// Update individual settings
    func updateSettings(
        roundReminderEnabled: Bool? = nil,
        weatherAlertEnabled: Bool? = nil,
        teeTimeReminderEnabled: Bool? = nil,
        achievementNotificationsEnabled: Bool? = nil,
        socialNotificationsEnabled: Bool? = nil,
        marketingNotificationsEnabled: Bool? = nil,
        soundEnabled: Bool? = nil,
        hapticFeedbackEnabled: Bool? = nil,
        voiceAnnouncementsEnabled: Bool? = nil,
        shareRoundsPublicly: Bool? = nil,
        showOnLeaderboards: Bool? = nil,
        allowFriendRequests: Bool? = nil,
        keepScreenOnDuringRound: Bool? = nil,
        autoAdvanceHole: Bool? = nil,
        showYardageMarkers: Bool? = nil,
        showHazardWarnings: Bool? = nil,
        mapStylePreference: MapStylePreference? = nil,
        autoBackupEnabled: Bool? = nil,
        offlineDownloadOnWiFiOnly: Bool? = nil
    ) {
        var settings = appSettings
        
        if let v = roundReminderEnabled { settings.roundReminderEnabled = v }
        if let v = weatherAlertEnabled { settings.weatherAlertEnabled = v }
        if let v = teeTimeReminderEnabled { settings.teeTimeReminderEnabled = v }
        if let v = achievementNotificationsEnabled { settings.achievementNotificationsEnabled = v }
        if let v = socialNotificationsEnabled { settings.socialNotificationsEnabled = v }
        if let v = marketingNotificationsEnabled { settings.marketingNotificationsEnabled = v }
        if let v = soundEnabled { settings.soundEnabled = v }
        if let v = hapticFeedbackEnabled { settings.hapticFeedbackEnabled = v }
        if let v = voiceAnnouncementsEnabled { settings.voiceAnnouncementsEnabled = v }
        if let v = shareRoundsPublicly { settings.shareRoundsPublicly = v }
        if let v = showOnLeaderboards { settings.showOnLeaderboards = v }
        if let v = allowFriendRequests { settings.allowFriendRequests = v }
        if let v = keepScreenOnDuringRound { settings.keepScreenOnDuringRound = v }
        if let v = autoAdvanceHole { settings.autoAdvanceHole = v }
        if let v = showYardageMarkers { settings.showYardageMarkers = v }
        if let v = showHazardWarnings { settings.showHazardWarnings = v }
        if let v = mapStylePreference { settings.mapStylePreference = v }
        if let v = autoBackupEnabled { settings.autoBackupEnabled = v }
        if let v = offlineDownloadOnWiFiOnly { settings.offlineDownloadOnWiFiOnly = v }
        
        self.appSettings = settings
        saveSettingsLocally()
    }
    
    /// Save settings to local storage
    private func saveSettingsLocally() {
        if let data = try? JSONEncoder().encode(appSettings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }
    
    // MARK: - Server Sync
    
    /// Sync profile to server
    func syncProfileToServer(authHeaders: [String: String] = [:]) async {
        guard let profile = userProfile else { return }
        
        isLoading = true
        error = nil
        
        do {
            try await DataService.shared.saveUserProfile(profile, authHeaders: authHeaders)
            print("✅ Profile synced to server")
        } catch {
            self.error = "Failed to sync profile: \(error.localizedDescription)"
            print("❌ Profile sync failed: \(error)")
        }
        
        isLoading = false
    }
    
    /// Fetch profile from server
    func fetchProfileFromServer(userId: String, authHeaders: [String: String]) async {
        isLoading = true
        error = nil
        
        do {
            if let profile = try await DataService.shared.fetchUserProfile(
                userId: userId,
                authHeaders: authHeaders
            ) {
                self.userProfile = profile
                self.needsOnboarding = !profile.onboardingCompleted
                saveProfileLocally()
                print("✅ Profile fetched from server")
            } else {
                // No profile on server, create one
                initializeProfile(userId: userId)
            }
        } catch {
            self.error = "Failed to fetch profile: \(error.localizedDescription)"
            print("❌ Profile fetch failed: \(error)")
            
            // Fall back to local or create new
            if userProfile == nil {
                initializeProfile(userId: userId)
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Issue Reporting
    
    /// Submit an issue report
    func submitIssueReport(
        roundId: String?,
        courseId: String?,
        holeNumber: Int?,
        issueTypes: [IssueType],
        additionalDetails: String?,
        userId: String,
        authHeaders: [String: String]
    ) async throws {
        let report = IssueReport(
            userId: userId,
            roundId: roundId,
            courseId: courseId,
            holeNumber: holeNumber,
            issueTypes: issueTypes,
            additionalDetails: additionalDetails
        )
        
        try await DataService.shared.submitIssueReport(report, authHeaders: authHeaders)
    }
    
    // MARK: - Convenience Accessors
    
    var distanceUnit: DistanceUnit {
        userProfile?.distanceUnit ?? .yards
    }
    
    var temperatureUnit: TemperatureUnit {
        userProfile?.temperatureUnit ?? .fahrenheit
    }
    
    var speedUnit: SpeedUnit {
        userProfile?.speedUnit ?? .mph
    }
    
    var handicap: Double? {
        userProfile?.handicapIndex
    }
    
    var handedness: Handedness {
        userProfile?.handedness ?? .right
    }
    
    /// Format distance according to user preference
    func formatDistance(_ yards: Double) -> String {
        distanceUnit.format(yards)
    }
    
    /// Format temperature according to user preference
    func formatTemperature(_ fahrenheit: Double) -> String {
        temperatureUnit.format(fahrenheit)
    }
    
    /// Format wind speed according to user preference
    func formatSpeed(_ mph: Double) -> String {
        speedUnit.format(mph)
    }
    
    // MARK: - Reset
    
    /// Clear all local data (for sign out)
    func clearLocalData() {
        userProfile = nil
        appSettings = .default
        needsOnboarding = false
        UserDefaults.standard.removeObject(forKey: profileKey)
        UserDefaults.standard.removeObject(forKey: settingsKey)
    }
}
