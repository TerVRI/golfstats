import SwiftUI

/// Unified settings screen that consolidates all app settings
struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var userProfileManager: UserProfileManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section {
                    NavigationLink(destination: EditProfileView()) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.2))
                                    .frame(width: 50, height: 50)
                                Text(authManager.currentUser?.initials ?? "G")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(authManager.currentUser?.displayName ?? "Golfer")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                if let handicap = userProfileManager.userProfile?.handicapIndex {
                                    Text("Handicap: \(String(format: "%.1f", handicap))")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                } else {
                                    Text("Edit Profile")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Profile")
                }
                
                // Golf Preferences Section
                Section {
                    NavigationLink(destination: RoundPreferencesView()) {
                        SettingsRow(
                            icon: "flag.fill",
                            iconColor: .green,
                            title: "Round Preferences",
                            subtitle: "Default mode, tees, scoring options"
                        )
                    }
                    
                    NavigationLink(destination: UnitsSettingsView()) {
                        SettingsRow(
                            icon: "ruler",
                            iconColor: .blue,
                            title: "Units & Measurements",
                            subtitle: "\(userProfileManager.distanceUnit.displayName), \(userProfileManager.temperatureUnit.abbreviation)"
                        )
                    }
                    
                    NavigationLink(destination: AICaddieSettingsView()) {
                        SettingsRow(
                            icon: "brain.head.profile",
                            iconColor: .purple,
                            title: "AI Caddie",
                            subtitle: "Club recommendations, adjustments"
                        )
                    }
                } header: {
                    Text("Golf Preferences")
                }
                
                // App Settings Section
                Section {
                    NavigationLink(destination: NotificationPreferencesView()) {
                        SettingsRow(
                            icon: "bell.fill",
                            iconColor: .red,
                            title: "Notifications",
                            subtitle: "Reminders, alerts, social"
                        )
                    }
                    
                    NavigationLink(destination: SoundHapticsSettingsView()) {
                        SettingsRow(
                            icon: "speaker.wave.2.fill",
                            iconColor: .orange,
                            title: "Sound & Haptics",
                            subtitle: soundHapticsSubtitle
                        )
                    }
                    
                    NavigationLink(destination: PrivacySettingsView()) {
                        SettingsRow(
                            icon: "hand.raised.fill",
                            iconColor: .blue,
                            title: "Privacy",
                            subtitle: "Sharing, leaderboards, friends"
                        )
                    }
                } header: {
                    Text("App Settings")
                }
                
                // Data & Storage Section
                Section {
                    NavigationLink(destination: OfflineCacheView()) {
                        SettingsRow(
                            icon: "arrow.down.circle.fill",
                            iconColor: .green,
                            title: "Offline Courses",
                            subtitle: "Downloaded courses, storage"
                        )
                    }
                    
                    NavigationLink(destination: DataManagementView()) {
                        SettingsRow(
                            icon: "externaldrive.fill",
                            iconColor: .gray,
                            title: "Data & Backup",
                            subtitle: "Export, import, backup"
                        )
                    }
                } header: {
                    Text("Data & Storage")
                }
                
                // Connected Services Section
                Section {
                    NavigationLink(destination: HealthKitSettingsView()) {
                        SettingsRow(
                            icon: "heart.fill",
                            iconColor: .pink,
                            title: "Apple Health",
                            subtitle: "Workout tracking, activity"
                        )
                    }
                    
                    NavigationLink(destination: SiriSettingsView()) {
                        SettingsRow(
                            icon: "mic.fill",
                            iconColor: .purple,
                            title: "Siri & Voice",
                            subtitle: "Voice commands, shortcuts"
                        )
                    }
                } header: {
                    Text("Connected Services")
                }
                
                // Help & Support Section
                Section {
                    NavigationLink(destination: IssueReportingView()) {
                        SettingsRow(
                            icon: "exclamationmark.triangle.fill",
                            iconColor: .yellow,
                            title: "Report an Issue",
                            subtitle: "Shot detection, GPS, bugs"
                        )
                    }
                    
                    Button {
                        openSupport()
                    } label: {
                        SettingsRow(
                            icon: "questionmark.circle.fill",
                            iconColor: .blue,
                            title: "Help & Support",
                            subtitle: "FAQs, contact us"
                        )
                    }
                    
                    Button {
                        openPrivacyPolicy()
                    } label: {
                        SettingsRow(
                            icon: "doc.text.fill",
                            iconColor: .gray,
                            title: "Privacy Policy",
                            subtitle: nil
                        )
                    }
                    
                    Button {
                        openTerms()
                    } label: {
                        SettingsRow(
                            icon: "doc.text.fill",
                            iconColor: .gray,
                            title: "Terms of Service",
                            subtitle: nil
                        )
                    }
                } header: {
                    Text("Help & Support")
                }
                
                // App Info
                Section {
                    HStack {
                        Text("Version")
                            .foregroundColor(.white)
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Build")
                            .foregroundColor(.white)
                        Spacer()
                        Text(buildNumber)
                            .foregroundColor(.gray)
                    }
                } header: {
                    Text("About")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color("Background"))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Computed Properties
    
    private var soundHapticsSubtitle: String {
        var parts: [String] = []
        if userProfileManager.appSettings.soundEnabled {
            parts.append("Sound on")
        }
        if userProfileManager.appSettings.hapticFeedbackEnabled {
            parts.append("Haptics on")
        }
        return parts.isEmpty ? "All off" : parts.joined(separator: ", ")
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    // MARK: - Actions
    
    private func openSupport() {
        if let url = URL(string: "https://roundcaddy.app/support") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openPrivacyPolicy() {
        if let url = URL(string: "https://roundcaddy.app/privacy") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openTerms() {
        if let url = URL(string: "https://roundcaddy.app/terms") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Settings Row Component

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(iconColor)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.white)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Sound & Haptics Settings View

struct SoundHapticsSettingsView: View {
    @EnvironmentObject var userProfileManager: UserProfileManager
    
    @State private var soundEnabled: Bool = true
    @State private var hapticFeedbackEnabled: Bool = true
    @State private var voiceAnnouncementsEnabled: Bool = false
    
    var body: some View {
        List {
            Section {
                Toggle(isOn: $soundEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sound Effects")
                            .foregroundColor(.white)
                        Text("Play sounds for actions and alerts")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.green)
                
                Toggle(isOn: $hapticFeedbackEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Haptic Feedback")
                            .foregroundColor(.white)
                        Text("Vibration for interactions")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.green)
            } header: {
                Text("Feedback")
            }
            
            Section {
                Toggle(isOn: $voiceAnnouncementsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Voice Announcements")
                            .foregroundColor(.white)
                        Text("Speak distances and recommendations")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.green)
            } header: {
                Text("Voice")
            } footer: {
                Text("Voice announcements will read out distances, club recommendations, and other helpful information during your round.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("Background"))
        .navigationTitle("Sound & Haptics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSettings()
        }
        .onChange(of: soundEnabled) { _, newValue in
            userProfileManager.updateSettings(soundEnabled: newValue)
        }
        .onChange(of: hapticFeedbackEnabled) { _, newValue in
            userProfileManager.updateSettings(hapticFeedbackEnabled: newValue)
        }
        .onChange(of: voiceAnnouncementsEnabled) { _, newValue in
            userProfileManager.updateSettings(voiceAnnouncementsEnabled: newValue)
        }
    }
    
    private func loadSettings() {
        soundEnabled = userProfileManager.appSettings.soundEnabled
        hapticFeedbackEnabled = userProfileManager.appSettings.hapticFeedbackEnabled
        voiceAnnouncementsEnabled = userProfileManager.appSettings.voiceAnnouncementsEnabled
    }
}

// MARK: - Privacy Settings View

struct PrivacySettingsView: View {
    @EnvironmentObject var userProfileManager: UserProfileManager
    
    @State private var shareRoundsPublicly: Bool = false
    @State private var showOnLeaderboards: Bool = true
    @State private var allowFriendRequests: Bool = true
    
    var body: some View {
        List {
            Section {
                Toggle(isOn: $shareRoundsPublicly) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Public Rounds")
                            .foregroundColor(.white)
                        Text("Allow others to see your round history")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.green)
                
                Toggle(isOn: $showOnLeaderboards) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show on Leaderboards")
                            .foregroundColor(.white)
                        Text("Appear on course and contributor leaderboards")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.green)
            } header: {
                Text("Sharing")
            }
            
            Section {
                Toggle(isOn: $allowFriendRequests) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Friend Requests")
                            .foregroundColor(.white)
                        Text("Allow other users to send you friend requests")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.green)
            } header: {
                Text("Social")
            }
            
            Section {
                Button {
                    // Request data export
                } label: {
                    HStack {
                        Text("Request My Data")
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
            } header: {
                Text("Your Data")
            } footer: {
                Text("Request a copy of all your data stored in RoundCaddy.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("Background"))
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSettings()
        }
        .onChange(of: shareRoundsPublicly) { _, newValue in
            userProfileManager.updateSettings(shareRoundsPublicly: newValue)
        }
        .onChange(of: showOnLeaderboards) { _, newValue in
            userProfileManager.updateSettings(showOnLeaderboards: newValue)
        }
        .onChange(of: allowFriendRequests) { _, newValue in
            userProfileManager.updateSettings(allowFriendRequests: newValue)
        }
    }
    
    private func loadSettings() {
        shareRoundsPublicly = userProfileManager.appSettings.shareRoundsPublicly
        showOnLeaderboards = userProfileManager.appSettings.showOnLeaderboards
        allowFriendRequests = userProfileManager.appSettings.allowFriendRequests
    }
}

// MARK: - Data Management View

struct DataManagementView: View {
    @EnvironmentObject var userProfileManager: UserProfileManager
    @State private var autoBackupEnabled: Bool = true
    @State private var showExportSheet = false
    @State private var showImportSheet = false
    
    var body: some View {
        List {
            Section {
                Toggle(isOn: $autoBackupEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto Backup")
                            .foregroundColor(.white)
                        Text("Automatically backup rounds to cloud")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.green)
            } header: {
                Text("Backup")
            }
            
            Section {
                Button {
                    showExportSheet = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.green)
                        Text("Export Data")
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
                
                Button {
                    showImportSheet = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.green)
                        Text("Import Data")
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
            } header: {
                Text("Import / Export")
            } footer: {
                Text("Export your rounds, stats, and settings to JSON or CSV format.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("Background"))
        .navigationTitle("Data & Backup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            autoBackupEnabled = userProfileManager.appSettings.autoBackupEnabled
        }
        .onChange(of: autoBackupEnabled) { _, newValue in
            userProfileManager.updateSettings(autoBackupEnabled: newValue)
        }
        .sheet(isPresented: $showImportSheet) {
            DataImportView()
        }
    }
}

// NOTE: SiriSettingsView is defined in SiriIntentsManager.swift

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AuthManager())
        .environmentObject(UserProfileManager.shared)
        .preferredColorScheme(.dark)
}
