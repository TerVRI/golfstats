import SwiftUI

@main
struct RoundCaddyWatchApp: App {
    @StateObject private var gpsManager = GPSManager()
    @StateObject private var roundManager = RoundManager()
    @StateObject private var motionManager = MotionManager()
    @StateObject private var workoutManager = WorkoutManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gpsManager)
                .environmentObject(roundManager)
                .environmentObject(motionManager)
                .environmentObject(workoutManager)
        }
    }
}
