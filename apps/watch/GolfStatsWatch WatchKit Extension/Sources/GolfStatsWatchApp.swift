import SwiftUI

@main
struct GolfStatsWatchApp: App {
    @StateObject private var gpsManager = GPSManager()
    @StateObject private var roundManager = RoundManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gpsManager)
                .environmentObject(roundManager)
        }
    }
}
