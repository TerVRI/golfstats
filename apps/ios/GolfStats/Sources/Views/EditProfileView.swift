import SwiftUI

/// View for editing user profile settings
struct EditProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var userProfileManager: UserProfileManager
    @Environment(\.dismiss) var dismiss
    
    // Local state for editing
    @State private var birthday: Date = Date()
    @State private var gender: Gender = .preferNotToSay
    @State private var handedness: Handedness = .right
    @State private var handicapIndex: Double = 15
    @State private var hasHandicap: Bool = false
    @State private var targetHandicap: Double = 10
    @State private var hasTargetHandicap: Bool = false
    @State private var skillLevel: SkillLevel = .intermediate
    @State private var driverDistance: Int = 220
    @State private var playingFrequency: PlayingFrequency = .regular
    @State private var preferredTees: TeeColor = .white
    
    @State private var hasChanges = false
    @State private var showDiscardAlert = false
    
    var body: some View {
        List {
            // Personal Information
            Section {
                DatePicker(
                    "Birthday",
                    selection: $birthday,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .foregroundColor(.white)
                
                Picker("Gender", selection: $gender) {
                    ForEach(Gender.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .foregroundColor(.white)
            } header: {
                Text("Personal Information")
            }
            
            // Golf Profile
            Section {
                Toggle(isOn: $hasHandicap) {
                    Text("I have a handicap")
                        .foregroundColor(.white)
                }
                .tint(.green)
                
                if hasHandicap {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Handicap Index")
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "%.1f", handicapIndex))
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        }
                        
                        Slider(value: $handicapIndex, in: -5...54, step: 0.1)
                            .tint(.green)
                    }
                } else {
                    Picker("Skill Level", selection: $skillLevel) {
                        ForEach(SkillLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .foregroundColor(.white)
                }
                
                Picker("Handedness", selection: $handedness) {
                    ForEach(Handedness.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .foregroundColor(.white)
            } header: {
                Text("Golf Profile")
            }
            
            // Playing Style
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Driver Distance")
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(driverDistance) yards")
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(driverDistance) },
                        set: { driverDistance = Int($0) }
                    ), in: 100...350, step: 5)
                        .tint(.green)
                }
                
                Picker("Playing Frequency", selection: $playingFrequency) {
                    ForEach(PlayingFrequency.allCases, id: \.self) { freq in
                        Text(freq.displayName).tag(freq)
                    }
                }
                .foregroundColor(.white)
                
                Picker("Preferred Tees", selection: $preferredTees) {
                    ForEach(TeeColor.allCases, id: \.self) { tee in
                        Text(tee.displayName).tag(tee)
                    }
                }
                .foregroundColor(.white)
            } header: {
                Text("Playing Style")
            }
            
            // Goal
            Section {
                Toggle(isOn: $hasTargetHandicap) {
                    Text("I have a target handicap")
                        .foregroundColor(.white)
                }
                .tint(.green)
                
                if hasTargetHandicap {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Target Handicap")
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "%.0f", targetHandicap))
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        }
                        
                        Slider(value: $targetHandicap, in: -5...54, step: 1)
                            .tint(.green)
                        
                        if hasHandicap && targetHandicap < handicapIndex {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.green)
                                Text("\(Int(handicapIndex - targetHandicap)) strokes to improve")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            } header: {
                Text("Goal")
            } footer: {
                Text("Setting a target helps you track progress and stay motivated.")
            }
            
            // Re-run Onboarding
            Section {
                Button {
                    // Re-run onboarding
                    userProfileManager.needsOnboarding = true
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                        Text("Re-run Setup Wizard")
                            .foregroundColor(.blue)
                    }
                }
            } footer: {
                Text("Run through the initial setup process again to update all your profile information.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("Background"))
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveChanges()
                }
                .fontWeight(.semibold)
                .foregroundColor(.green)
                .disabled(!hasChanges)
            }
        }
        .onAppear {
            loadProfile()
        }
        .onChange(of: birthday) { _, _ in hasChanges = true }
        .onChange(of: gender) { _, _ in hasChanges = true }
        .onChange(of: handedness) { _, _ in hasChanges = true }
        .onChange(of: handicapIndex) { _, _ in hasChanges = true }
        .onChange(of: hasHandicap) { _, _ in hasChanges = true }
        .onChange(of: targetHandicap) { _, _ in hasChanges = true }
        .onChange(of: hasTargetHandicap) { _, _ in hasChanges = true }
        .onChange(of: skillLevel) { _, _ in hasChanges = true }
        .onChange(of: driverDistance) { _, _ in hasChanges = true }
        .onChange(of: playingFrequency) { _, _ in hasChanges = true }
        .onChange(of: preferredTees) { _, _ in hasChanges = true }
        .alert("Discard Changes?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
    }
    
    private func loadProfile() {
        guard let profile = userProfileManager.userProfile else { return }
        
        birthday = profile.birthday ?? Date()
        gender = profile.gender ?? .preferNotToSay
        handedness = profile.handedness
        handicapIndex = profile.handicapIndex ?? 15
        hasHandicap = profile.handicapIndex != nil
        targetHandicap = profile.targetHandicap ?? 10
        hasTargetHandicap = profile.targetHandicap != nil
        skillLevel = profile.skillLevel
        driverDistance = profile.driverDistance
        playingFrequency = profile.playingFrequency
        preferredTees = profile.preferredTees
        
        hasChanges = false
    }
    
    private func saveChanges() {
        userProfileManager.updateProfile(
            birthday: birthday,
            gender: gender,
            handedness: handedness,
            handicapIndex: hasHandicap ? handicapIndex : nil,
            targetHandicap: hasTargetHandicap ? targetHandicap : nil,
            skillLevel: hasHandicap ? SkillLevel.from(handicap: handicapIndex) : skillLevel,
            driverDistance: driverDistance,
            playingFrequency: playingFrequency,
            preferredTees: preferredTees
        )
        
        // Sync to server
        Task {
            await userProfileManager.syncProfileToServer()
        }
        
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EditProfileView()
            .environmentObject(AuthManager())
            .environmentObject(UserProfileManager.shared)
    }
    .preferredColorScheme(.dark)
}
