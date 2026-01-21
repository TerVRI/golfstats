import SwiftUI

/// Settings view for configuring swing detection and preferences
struct SettingsView: View {
    @EnvironmentObject var motionManager: MotionManager
    @AppStorage("watchWrist") private var watchWrist = "Left"
    @AppStorage("dominantHand") private var dominantHand = "Right"
    @AppStorage("sensitivity") private var sensitivity = 1.0
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("autoPuttingMode") private var autoPuttingMode = true
    @AppStorage("practiceMode") private var practiceMode = false
    @AppStorage("targetTempo") private var targetTempo = 3.0
    
    var isLeadWrist: Bool {
        // Lead wrist for right-handed = left wrist
        (dominantHand == "Right" && watchWrist == "Left") ||
        (dominantHand == "Left" && watchWrist == "Right")
    }
    
    var body: some View {
        List {
            // Hand/Wrist Configuration
            Section {
                Picker("Watch Wrist", selection: $watchWrist) {
                    Text("Left").tag("Left")
                    Text("Right").tag("Right")
                }
                
                Picker("Dominant Hand", selection: $dominantHand) {
                    Text("Right-Handed").tag("Right")
                    Text("Left-Handed").tag("Left")
                }
                
                // Lead wrist indicator
                HStack {
                    Image(systemName: isLeadWrist ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(isLeadWrist ? .green : .orange)
                    
                    VStack(alignment: .leading) {
                        Text(isLeadWrist ? "Lead Wrist ✓" : "Trail Wrist")
                            .font(.caption)
                        Text(isLeadWrist ? "Optimal for detection" : "Detection may be less accurate")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Wrist Setup")
            }
            
            // Detection Settings
            Section {
                // Sensitivity slider
                VStack(alignment: .leading) {
                    HStack {
                        Text("Sensitivity")
                        Spacer()
                        Text(sensitivityLabel)
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                    
                    Slider(value: $sensitivity, in: 0.5...1.5, step: 0.1)
                        .tint(.green)
                }
                
                Toggle("Haptic Feedback", isOn: $hapticEnabled)
                    .font(.caption)
                
                Toggle("Auto Putting Mode", isOn: $autoPuttingMode)
                    .font(.caption)
                
            } header: {
                Text("Detection")
            }
            
            // Practice Mode
            Section {
                Toggle(isOn: $practiceMode) {
                    VStack(alignment: .leading) {
                        Text("Practice Mode")
                            .font(.caption)
                        Text("Detailed metrics, no shot counting")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                if practiceMode {
                    // Target tempo setting
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Target Tempo")
                            Spacer()
                            Text("\(String(format: "%.1f", targetTempo)):1")
                                .foregroundColor(.green)
                        }
                        .font(.caption)
                        
                        Slider(value: $targetTempo, in: 2.0...4.0, step: 0.1)
                            .tint(.green)
                        
                        Text("Pro average: 3.0:1")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Training")
            }
            
            // About
            Section {
                HStack {
                    Text("Version")
                        .font(.caption)
                    Spacer()
                    Text("1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                NavigationLink(destination: AboutSwingDetectionView()) {
                    Text("About Swing Detection")
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Settings")
    }
    
    var sensitivityLabel: String {
        if sensitivity < 0.8 { return "Low" }
        if sensitivity > 1.2 { return "High" }
        return "Normal"
    }
}

// MARK: - About Swing Detection View

struct AboutSwingDetectionView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("How It Works")
                    .font(.headline)
                
                Text("RoundCaddy uses your Apple Watch's sensors to automatically detect golf swings:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                FeatureRow(
                    icon: "gyroscope",
                    title: "Gyroscope",
                    description: "Detects rotation during swing"
                )
                
                FeatureRow(
                    icon: "gauge.with.dots.needle.bottom.50percent",
                    title: "Accelerometer",
                    description: "Measures G-forces & impact"
                )
                
                FeatureRow(
                    icon: "location.fill",
                    title: "GPS",
                    description: "Filters practice swings"
                )
                
                Divider()
                
                Text("Tips for Best Results")
                    .font(.headline)
                
                BulletPoint("Wear watch on lead wrist")
                BulletPoint("Keep band snug (not loose)")
                BulletPoint("Full swings work best")
                BulletPoint("Putts detected near green")
            }
            .padding()
        }
        .navigationTitle("About")
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 20)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct BulletPoint: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .foregroundColor(.green)
            Text(text)
                .font(.caption)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(MotionManager())
    }
}
