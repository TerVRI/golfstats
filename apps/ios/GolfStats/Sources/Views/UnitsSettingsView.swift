import SwiftUI

/// Settings view for units and measurements
struct UnitsSettingsView: View {
    @EnvironmentObject var userProfileManager: UserProfileManager
    
    @State private var distanceUnit: DistanceUnit = .yards
    @State private var temperatureUnit: TemperatureUnit = .fahrenheit
    @State private var speedUnit: SpeedUnit = .mph
    
    var body: some View {
        List {
            // Distance
            Section {
                ForEach(DistanceUnit.allCases, id: \.self) { unit in
                    Button {
                        distanceUnit = unit
                        userProfileManager.updateProfile(distanceUnit: unit)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(unit.displayName)
                                    .foregroundColor(.white)
                                Text("e.g., 150\(unit.abbreviation) to the green")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            if distanceUnit == unit {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            } header: {
                Text("Distance")
            } footer: {
                Text("Distances to greens, hazards, and targets will be shown in your preferred unit.")
            }
            
            // Temperature
            Section {
                ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                    Button {
                        temperatureUnit = unit
                        userProfileManager.updateProfile(temperatureUnit: unit)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(unit.displayName)
                                    .foregroundColor(.white)
                                Text(sampleTemperature(for: unit))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            if temperatureUnit == unit {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            } header: {
                Text("Temperature")
            } footer: {
                Text("Weather conditions and temperature adjustments will use this unit.")
            }
            
            // Wind Speed
            Section {
                ForEach(SpeedUnit.allCases, id: \.self) { unit in
                    Button {
                        speedUnit = unit
                        userProfileManager.updateProfile(speedUnit: unit)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(unit.displayName)
                                    .foregroundColor(.white)
                                Text(sampleSpeed(for: unit))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            if speedUnit == unit {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            } header: {
                Text("Wind Speed")
            }
            
            // Preview
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Example Display")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Distance to Green")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(distanceUnit.format(156))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Temperature")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(temperatureUnit.format(72))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Wind")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(speedUnit.format(12))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color("BackgroundSecondary"))
                    .cornerRadius(12)
                }
            } header: {
                Text("Preview")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("Background"))
        .navigationTitle("Units")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        distanceUnit = userProfileManager.userProfile?.distanceUnit ?? .yards
        temperatureUnit = userProfileManager.userProfile?.temperatureUnit ?? .fahrenheit
        speedUnit = userProfileManager.userProfile?.speedUnit ?? .mph
    }
    
    private func sampleTemperature(for unit: TemperatureUnit) -> String {
        switch unit {
        case .fahrenheit: return "e.g., 72°F (room temperature)"
        case .celsius: return "e.g., 22°C (room temperature)"
        }
    }
    
    private func sampleSpeed(for unit: SpeedUnit) -> String {
        switch unit {
        case .mph: return "e.g., 10 mph wind"
        case .kph: return "e.g., 16 kph wind"
        case .mps: return "e.g., 4.5 mps wind"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        UnitsSettingsView()
            .environmentObject(UserProfileManager.shared)
    }
    .preferredColorScheme(.dark)
}
