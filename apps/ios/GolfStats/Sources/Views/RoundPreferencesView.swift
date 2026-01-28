import SwiftUI

/// Settings view for round preferences and defaults
struct RoundPreferencesView: View {
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var authManager: AuthManager
    
    // Round settings
    @State private var defaultMode: RoundMode = .fullTracking
    @State private var preferredTees: TeeColor = .white
    @State private var enableShotReminders: Bool = true
    @State private var autoAdvanceHole: Bool = false
    @State private var showYardageMarkers: Bool = true
    @State private var showHazardWarnings: Bool = true
    @State private var enableVoiceDistances: Bool = false
    @State private var keepScreenOn: Bool = true
    
    var body: some View {
        List {
            // Default Mode
            Section {
                ForEach(RoundMode.allCases, id: \.self) { mode in
                    Button {
                        if canSelectMode(mode) {
                            defaultMode = mode
                            savePreferences()
                        }
                    } label: {
                        HStack {
                            Image(systemName: mode.icon)
                                .font(.title2)
                                .foregroundColor(mode.requiresPro && !authManager.hasProAccess ? .gray : .green)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(mode.displayName)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    if mode.requiresPro && !authManager.hasProAccess {
                                        Text("PRO")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange)
                                            .cornerRadius(4)
                                    }
                                }
                                
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            if defaultMode == mode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(mode.requiresPro && !authManager.hasProAccess)
                }
            } header: {
                Text("Default Round Mode")
            } footer: {
                Text("This mode will be pre-selected when starting a new round.")
            }
            
            // Tee Preferences
            Section {
                Picker("Preferred Tees", selection: $preferredTees) {
                    ForEach(TeeColor.allCases, id: \.self) { tee in
                        Text(tee.displayName).tag(tee)
                    }
                }
                .foregroundColor(.white)
                .onChange(of: preferredTees) { _, _ in
                    savePreferences()
                    userProfileManager.updateProfile(preferredTees: preferredTees)
                }
            } header: {
                Text("Tees")
            } footer: {
                Text("Your preferred tees will be pre-selected when starting a round.")
            }
            
            // Scoring Assistance
            Section {
                Toggle(isOn: $enableShotReminders) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Shot Reminders")
                            .foregroundColor(.white)
                        Text("Remind to log shots if inactive")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.green)
                .onChange(of: enableShotReminders) { _, _ in savePreferences() }
                
                Toggle(isOn: $autoAdvanceHole) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Advance Hole")
                            .foregroundColor(.white)
                        Text("Automatically move to next hole after saving score")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.green)
                .onChange(of: autoAdvanceHole) { _, _ in
                    savePreferences()
                    userProfileManager.updateSettings(autoAdvanceHole: autoAdvanceHole)
                }
            } header: {
                Text("Scoring Assistance")
            }
            
            // Display Options
            Section {
                Toggle(isOn: $showYardageMarkers) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Yardage Markers")
                            .foregroundColor(.white)
                        Text("Show 100/150/200 yard markers on map")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.green)
                .onChange(of: showYardageMarkers) { _, _ in
                    savePreferences()
                    userProfileManager.updateSettings(showYardageMarkers: showYardageMarkers)
                }
                
                Toggle(isOn: $showHazardWarnings) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hazard Warnings")
                            .foregroundColor(.white)
                        Text("Highlight hazards in carry distance")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.green)
                .onChange(of: showHazardWarnings) { _, _ in
                    savePreferences()
                    userProfileManager.updateSettings(showHazardWarnings: showHazardWarnings)
                }
            } header: {
                Text("Map Display")
            }
            
            // Voice & Screen
            Section {
                Toggle(isOn: $enableVoiceDistances) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Voice Distances")
                            .foregroundColor(.white)
                        Text("Announce distances via Siri")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.green)
                .onChange(of: enableVoiceDistances) { _, _ in savePreferences() }
                
                Toggle(isOn: $keepScreenOn) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keep Screen On")
                            .foregroundColor(.white)
                        Text("Prevent screen from sleeping during round")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .tint(.green)
                .onChange(of: keepScreenOn) { _, _ in
                    savePreferences()
                    userProfileManager.updateSettings(keepScreenOnDuringRound: keepScreenOn)
                }
            } header: {
                Text("Voice & Screen")
            } footer: {
                Text("Keeping the screen on may use more battery during your round.")
            }
            
            // Feature Summary
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Features in \(defaultMode.displayName)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    let features = defaultMode.features
                    RoundFeatureRow(name: "GPS Distances", enabled: features.gpsEnabled)
                    RoundFeatureRow(name: "Shot Tracking", enabled: features.shotTracking)
                    RoundFeatureRow(name: "Club Selection", enabled: features.clubSelection)
                    RoundFeatureRow(name: "Stats Tracking", enabled: features.statsTracking)
                    RoundFeatureRow(name: "Fairway Tracking", enabled: features.fairwayTracking)
                    RoundFeatureRow(name: "GIR Tracking", enabled: features.girTracking)
                    RoundFeatureRow(name: "Apple Watch Sync", enabled: features.watchSync)
                    RoundFeatureRow(name: "Stroke Index Display", enabled: features.strokeIndex)
                    RoundFeatureRow(name: "Handicap Adjustment", enabled: features.handicapAdjustment)
                    RoundFeatureRow(name: "Attestation", enabled: features.attestation)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Mode Features")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("Background"))
        .navigationTitle("Round Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadPreferences()
        }
    }
    
    private func canSelectMode(_ mode: RoundMode) -> Bool {
        if mode.requiresPro && !authManager.hasProAccess {
            return false
        }
        return true
    }
    
    private func loadPreferences() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "round_preferences"),
           let prefs = try? JSONDecoder().decode(RoundPreferences.self, from: data) {
            defaultMode = prefs.defaultMode
            enableShotReminders = prefs.enableShotReminders
            autoAdvanceHole = prefs.autoAdvanceHole
            showYardageMarkers = prefs.showYardageMarkers
            showHazardWarnings = prefs.showHazardWarnings
            enableVoiceDistances = prefs.enableVoiceDistances
            keepScreenOn = prefs.keepScreenOn
        }
        
        // Load tees from profile
        if let profile = userProfileManager.userProfile {
            preferredTees = profile.preferredTees
        }
    }
    
    private func savePreferences() {
        let prefs = RoundPreferences(
            defaultMode: defaultMode,
            preferredTees: preferredTees.rawValue,
            enableShotReminders: enableShotReminders,
            autoAdvanceHole: autoAdvanceHole,
            showYardageMarkers: showYardageMarkers,
            showHazardWarnings: showHazardWarnings,
            enableVoiceDistances: enableVoiceDistances,
            keepScreenOn: keepScreenOn
        )
        
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: "round_preferences")
        }
    }
}

// MARK: - Round Feature Row

struct RoundFeatureRow: View {
    let name: String
    let enabled: Bool
    
    var body: some View {
        HStack {
            Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(enabled ? .green : .gray.opacity(0.5))
            Text(name)
                .font(.subheadline)
                .foregroundColor(enabled ? .white : .gray.opacity(0.5))
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RoundPreferencesView()
            .environmentObject(UserProfileManager.shared)
            .environmentObject(AuthManager())
    }
    .preferredColorScheme(.dark)
}
