import SwiftUI

/// Shows live distance from the last shot location as the player walks to their ball
struct LiveShotDistanceView: View {
    @EnvironmentObject var gpsManager: GPSManager
    @EnvironmentObject var roundManager: RoundManager
    @EnvironmentObject var workoutManager: WorkoutManager
    
    /// Most recent shot for the current hole
    private var lastShot: Shot? {
        roundManager.shots
            .filter { $0.holeNumber == roundManager.currentHole }
            .last
    }
    
    /// Whether we have a shot to measure from
    private var hasLastShot: Bool {
        lastShot != nil && gpsManager.lastShotDistance != nil
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if hasLastShot, let distance = gpsManager.lastShotDistance {
                // Shot distance display
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "figure.golf")
                            .foregroundColor(.orange)
                        Text("Last Shot")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Big distance number
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(distance)")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                        
                        Text("yds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Club used
                    if let shot = lastShot, let club = shot.club {
                        Text(club)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                // Workout stats
                if workoutManager.isWorkoutActive {
                    HStack(spacing: 16) {
                        // Elapsed time
                        VStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text(workoutManager.formattedElapsedTime)
                                .font(.caption)
                                .monospacedDigit()
                        }
                        
                        // Heart rate
                        if workoutManager.heartRate > 0 {
                            VStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                Text("\(workoutManager.formattedHeartRate)")
                                    .font(.caption)
                                    .monospacedDigit()
                            }
                        }
                        
                        // Calories
                        VStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("\(workoutManager.formattedCalories)")
                                .font(.caption)
                                .monospacedDigit()
                        }
                    }
                }
                
            } else {
                // No shot recorded yet
                VStack(spacing: 12) {
                    Image(systemName: "location.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("No shot recorded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Mark a shot to track distance")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .padding()
    }
}

// MARK: - Compact Shot Distance Badge

/// A compact badge showing last shot distance, for use in other views
struct ShotDistanceBadge: View {
    @EnvironmentObject var gpsManager: GPSManager
    
    var body: some View {
        if let distance = gpsManager.lastShotDistance {
            HStack(spacing: 4) {
                Image(systemName: "arrow.left.and.right")
                    .font(.caption2)
                Text("\(distance) yds")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.15))
            .cornerRadius(12)
        }
    }
}

// MARK: - Preview

#Preview {
    LiveShotDistanceView()
        .environmentObject(GPSManager())
        .environmentObject(RoundManager())
        .environmentObject(WorkoutManager())
}
