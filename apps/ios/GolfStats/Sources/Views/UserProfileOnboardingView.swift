import SwiftUI

/// Multi-step onboarding flow to collect user profile information
struct UserProfileOnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var userProfileManager: UserProfileManager
    @Environment(\.dismiss) var dismiss
    
    @State private var currentStep = 0
    
    // Profile data being collected
    @State private var birthday: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var gender: Gender = .preferNotToSay
    @State private var handedness: Handedness = .right
    @State private var handicapValue: Double = 15
    @State private var hasHandicap: Bool = true
    @State private var skillLevel: SkillLevel = .intermediate
    @State private var driverDistance: Int = 220
    @State private var playingFrequency: Double = 50
    @State private var targetHandicap: Double = 10
    @State private var hasTargetHandicap: Bool = true
    
    let totalSteps = 6
    
    var body: some View {
        ZStack {
            Color("Background")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress Bar
                OnboardingProgressBar(currentStep: currentStep, totalSteps: totalSteps)
                    .padding(.horizontal)
                    .padding(.top)
                
                // Content
                TabView(selection: $currentStep) {
                    BirthdayStep(birthday: $birthday)
                        .tag(0)
                    
                    GenderStep(gender: $gender)
                        .tag(1)
                    
                    HandicapStep(
                        handicapValue: $handicapValue,
                        hasHandicap: $hasHandicap,
                        skillLevel: $skillLevel
                    )
                        .tag(2)
                    
                    PlayingFrequencyStep(playingFrequency: $playingFrequency)
                        .tag(3)
                    
                    DriverDistanceStep(driverDistance: $driverDistance, handedness: $handedness)
                        .tag(4)
                    
                    GoalStep(
                        targetHandicap: $targetHandicap,
                        hasTargetHandicap: $hasTargetHandicap,
                        currentHandicap: handicapValue
                    )
                        .tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                
                // Navigation Buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button {
                            withAnimation {
                                currentStep -= 1
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color("BackgroundSecondary"))
                                .clipShape(Circle())
                        }
                    }
                    
                    Button {
                        if currentStep < totalSteps - 1 {
                            withAnimation {
                                currentStep += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        HStack {
                            Text(currentStep < totalSteps - 1 ? "Next" : "Get Started")
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func completeOnboarding() {
        // Build profile from collected data
        userProfileManager.updateProfile(
            birthday: birthday,
            gender: gender,
            handedness: handedness,
            handicapIndex: hasHandicap ? handicapValue : nil,
            targetHandicap: hasTargetHandicap ? targetHandicap : nil,
            skillLevel: hasHandicap ? SkillLevel.from(handicap: handicapValue) : skillLevel,
            driverDistance: driverDistance,
            playingFrequency: PlayingFrequency.from(sliderValue: playingFrequency)
        )
        
        userProfileManager.completeOnboarding()
        dismiss()
    }
}

// MARK: - Progress Bar

struct OnboardingProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Rectangle()
                        .fill(step <= currentStep ? Color.green : Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                }
            }
            
            Text("PERSONALIZE: \(currentStep + 1) of \(totalSteps)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Step Views

struct BirthdayStep: View {
    @Binding var birthday: Date
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "gift.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            VStack(spacing: 12) {
                Text("When is your birthday?")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("You need to be at least 13 years old to use our platform. Your age will also tell us what aspects of your game to target for improvement.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            DatePicker(
                "Birthday",
                selection: $birthday,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .colorScheme(.dark)
            
            Spacer()
        }
        .padding()
    }
}

struct GenderStep: View {
    @Binding var gender: Gender
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "person.2.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            VStack(spacing: 12) {
                Text("Who do you want to compare your game against?")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("We make sure our algorithms accommodate both male and female golfers. We'll only use this information to analyze your data properly.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                ForEach([Gender.male, Gender.female], id: \.self) { option in
                    Button {
                        gender = option
                    } label: {
                        Text(option == .male ? "Male Golfers" : "Female Golfers")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(gender == option ? Color.green : Color("BackgroundSecondary"))
                            .cornerRadius(12)
                    }
                }
                
                Button {
                    gender = .preferNotToSay
                } label: {
                    Text("Prefer not to say")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

struct HandicapStep: View {
    @Binding var handicapValue: Double
    @Binding var hasHandicap: Bool
    @Binding var skillLevel: SkillLevel
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "number")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            VStack(spacing: 12) {
                Text("What's your approx. handicap?")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Let us know how you're currently playing so we can help set attainable targets for you.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if hasHandicap {
                VStack(spacing: 8) {
                    Text("\(Int(handicapValue))")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    
                    Text("Avg. Score of \(72 + Int(handicapValue))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Slider(value: $handicapValue, in: -5...54, step: 1)
                        .tint(.green)
                        .padding(.horizontal, 32)
                    
                    HStack {
                        Text("Tour Pro")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("Beginner")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 32)
                }
            } else {
                VStack(spacing: 16) {
                    Text("Select your skill level")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ForEach(SkillLevel.allCases, id: \.self) { level in
                        Button {
                            skillLevel = level
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(level.displayName)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(level.description)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                if skillLevel == level {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(skillLevel == level ? Color.green.opacity(0.2) : Color("BackgroundSecondary"))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Button {
                hasHandicap.toggle()
            } label: {
                Text(hasHandicap ? "I don't know my handicap" : "I know my handicap")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct PlayingFrequencyStep: View {
    @Binding var playingFrequency: Double
    
    private var roundsPerYear: Int {
        PlayingFrequency.from(sliderValue: playingFrequency).roundsPerYear
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "calendar")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            VStack(spacing: 12) {
                Text("How many times a year do you play?")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("We will make sure your target is reasonable based on how frequently you play.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 8) {
                Text("\(roundsPerYear)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                
                Text("rounds per year")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Slider(value: $playingFrequency, in: 0...100)
                    .tint(.green)
                    .padding(.horizontal, 32)
                
                HStack {
                    Text("Rarely")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Constantly")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct DriverDistanceStep: View {
    @Binding var driverDistance: Int
    @Binding var handedness: Handedness
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "figure.golf")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            VStack(spacing: 12) {
                Text("How far do you hit the ball with your driver?")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Sharing your driver distance will greatly improve club recommendations.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 8) {
                Text("\(driverDistance)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                
                Text("yards")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Slider(value: Binding(
                    get: { Double(driverDistance) },
                    set: { driverDistance = Int($0) }
                ), in: 100...350, step: 5)
                    .tint(.green)
                    .padding(.horizontal, 32)
                
                HStack {
                    Text("100 yards")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("350 yards")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 32)
            }
            
            VStack(spacing: 12) {
                Text("How do you swing the club?")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 12) {
                    ForEach(Handedness.allCases, id: \.self) { option in
                        Button {
                            handedness = option
                        } label: {
                            Text(option.displayName)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(handedness == option ? Color.green : Color("BackgroundSecondary"))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                
                Text("Our shot-detection technology uses motion sensors, so we need to know this to ensure we capture your shots!")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct GoalStep: View {
    @Binding var targetHandicap: Double
    @Binding var hasTargetHandicap: Bool
    let currentHandicap: Double
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "target")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            VStack(spacing: 12) {
                Text("What's your goal handicap?")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Set a target and we'll help you track your progress toward achieving it.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if hasTargetHandicap {
                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(targetHandicap))")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                        
                        if targetHandicap < currentHandicap {
                            Text("↓\(Int(currentHandicap - targetHandicap))")
                                .font(.title2)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Text("target handicap")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Slider(value: $targetHandicap, in: -5...max(currentHandicap, 30), step: 1)
                        .tint(.green)
                        .padding(.horizontal, 32)
                    
                    HStack {
                        Text("Scratch")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("Current")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 32)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("No problem!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("You can always set a target later from your profile settings.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
            
            Button {
                hasTargetHandicap.toggle()
                if hasTargetHandicap {
                    targetHandicap = max(0, currentHandicap - 5)
                }
            } label: {
                Text(hasTargetHandicap ? "I don't have a goal right now" : "I have a goal handicap")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    UserProfileOnboardingView()
        .environmentObject(AuthManager())
        .environmentObject(UserProfileManager.shared)
}
