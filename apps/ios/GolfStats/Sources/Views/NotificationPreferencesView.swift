import SwiftUI
import UserNotifications

/// Settings view for notification preferences
struct NotificationPreferencesView: View {
    @EnvironmentObject var userProfileManager: UserProfileManager
    
    @State private var roundReminderEnabled: Bool = true
    @State private var weatherAlertEnabled: Bool = true
    @State private var teeTimeReminderEnabled: Bool = true
    @State private var achievementNotificationsEnabled: Bool = true
    @State private var socialNotificationsEnabled: Bool = true
    @State private var marketingNotificationsEnabled: Bool = false
    
    @State private var systemNotificationsEnabled: Bool = false
    @State private var showingSystemSettings = false
    
    var body: some View {
        List {
            // System Status
            if !systemNotificationsEnabled {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notifications Disabled")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Enable notifications in system settings to receive alerts.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Button {
                        openSystemSettings()
                    } label: {
                        HStack {
                            Text("Open Settings")
                                .foregroundColor(.green)
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            // Round Notifications
            Section {
                Toggle(isOn: $roundReminderEnabled) {
                    NotificationToggleLabel(
                        title: "Round Reminders",
                        description: "Reminders when you start or finish a round",
                        icon: "flag.fill",
                        iconColor: .green
                    )
                }
                .tint(.green)
                .disabled(!systemNotificationsEnabled)
                
                Toggle(isOn: $weatherAlertEnabled) {
                    NotificationToggleLabel(
                        title: "Weather Alerts",
                        description: "Notifications about weather changes during your round",
                        icon: "cloud.sun.fill",
                        iconColor: .orange
                    )
                }
                .tint(.green)
                .disabled(!systemNotificationsEnabled)
                
                Toggle(isOn: $teeTimeReminderEnabled) {
                    NotificationToggleLabel(
                        title: "Tee Time Reminders",
                        description: "Reminder 1 hour before your scheduled tee time",
                        icon: "clock.fill",
                        iconColor: .blue
                    )
                }
                .tint(.green)
                .disabled(!systemNotificationsEnabled)
            } header: {
                Text("Round Notifications")
            }
            
            // Progress & Social
            Section {
                Toggle(isOn: $achievementNotificationsEnabled) {
                    NotificationToggleLabel(
                        title: "Achievements",
                        description: "Celebrate milestones and personal bests",
                        icon: "trophy.fill",
                        iconColor: .yellow
                    )
                }
                .tint(.green)
                .disabled(!systemNotificationsEnabled)
                
                Toggle(isOn: $socialNotificationsEnabled) {
                    NotificationToggleLabel(
                        title: "Social Updates",
                        description: "Friend requests, comments, and community activity",
                        icon: "person.2.fill",
                        iconColor: .purple
                    )
                }
                .tint(.green)
                .disabled(!systemNotificationsEnabled)
            } header: {
                Text("Progress & Social")
            }
            
            // Marketing
            Section {
                Toggle(isOn: $marketingNotificationsEnabled) {
                    NotificationToggleLabel(
                        title: "Tips & Promotions",
                        description: "Golf tips, feature updates, and special offers",
                        icon: "megaphone.fill",
                        iconColor: .red
                    )
                }
                .tint(.green)
                .disabled(!systemNotificationsEnabled)
            } header: {
                Text("Marketing")
            } footer: {
                Text("We respect your inbox. Marketing notifications are optional and you can unsubscribe at any time.")
            }
            
            // Quick Actions
            Section {
                Button {
                    enableAll()
                } label: {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.green)
                        Text("Enable All")
                            .foregroundColor(.white)
                    }
                }
                .disabled(!systemNotificationsEnabled)
                
                Button {
                    disableAll()
                } label: {
                    HStack {
                        Image(systemName: "bell.slash.fill")
                            .foregroundColor(.red)
                        Text("Disable All")
                            .foregroundColor(.white)
                    }
                }
                .disabled(!systemNotificationsEnabled)
            } header: {
                Text("Quick Actions")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("Background"))
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSettings()
            checkSystemNotificationStatus()
        }
        .onChange(of: roundReminderEnabled) { _, newValue in
            userProfileManager.updateSettings(roundReminderEnabled: newValue)
        }
        .onChange(of: weatherAlertEnabled) { _, newValue in
            userProfileManager.updateSettings(weatherAlertEnabled: newValue)
        }
        .onChange(of: teeTimeReminderEnabled) { _, newValue in
            userProfileManager.updateSettings(teeTimeReminderEnabled: newValue)
        }
        .onChange(of: achievementNotificationsEnabled) { _, newValue in
            userProfileManager.updateSettings(achievementNotificationsEnabled: newValue)
        }
        .onChange(of: socialNotificationsEnabled) { _, newValue in
            userProfileManager.updateSettings(socialNotificationsEnabled: newValue)
        }
        .onChange(of: marketingNotificationsEnabled) { _, newValue in
            userProfileManager.updateSettings(marketingNotificationsEnabled: newValue)
        }
    }
    
    private func loadSettings() {
        let settings = userProfileManager.appSettings
        roundReminderEnabled = settings.roundReminderEnabled
        weatherAlertEnabled = settings.weatherAlertEnabled
        teeTimeReminderEnabled = settings.teeTimeReminderEnabled
        achievementNotificationsEnabled = settings.achievementNotificationsEnabled
        socialNotificationsEnabled = settings.socialNotificationsEnabled
        marketingNotificationsEnabled = settings.marketingNotificationsEnabled
    }
    
    private func checkSystemNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                systemNotificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func enableAll() {
        roundReminderEnabled = true
        weatherAlertEnabled = true
        teeTimeReminderEnabled = true
        achievementNotificationsEnabled = true
        socialNotificationsEnabled = true
        // Don't enable marketing by default
    }
    
    private func disableAll() {
        roundReminderEnabled = false
        weatherAlertEnabled = false
        teeTimeReminderEnabled = false
        achievementNotificationsEnabled = false
        socialNotificationsEnabled = false
        marketingNotificationsEnabled = false
    }
}

// MARK: - Notification Toggle Label

struct NotificationToggleLabel: View {
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(iconColor)
                .cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NotificationPreferencesView()
            .environmentObject(UserProfileManager.shared)
    }
    .preferredColorScheme(.dark)
}
