import SwiftUI

// MARK: - Demo/Screenshot Mode Configuration
// Set to true when capturing App Store screenshots
#if DEBUG
let isDemoMode = false  // Set to true to enable demo mode for screenshots
#else
let isDemoMode = false
#endif

@main
struct RoundCaddyApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var gpsManager = GPSManager()
    @StateObject private var roundManager = RoundManager()
    @StateObject private var watchSyncManager = WatchSyncManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(gpsManager)
                .environmentObject(roundManager)
                .environmentObject(watchSyncManager)
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        Group {
            if authManager.isLoading {
                LoadingView()
            } else if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut, value: authManager.isAuthenticated)
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color("Background").ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                Text("RoundCaddy")
                    .font(.title)
                    .fontWeight(.bold)
                ProgressView()
                    .tint(.green)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
        .environmentObject(GPSManager())
        .environmentObject(RoundManager())
        .environmentObject(WatchSyncManager())
}
