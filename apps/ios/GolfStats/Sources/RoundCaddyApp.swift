import SwiftUI
import UIKit

// MARK: - Demo/Screenshot Mode Configuration
// Set to true when capturing App Store screenshots
#if DEBUG
let isDemoMode = false  // Set to true to enable demo mode for screenshots
#else
let isDemoMode = false
#endif

@main
struct RoundCaddyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
                .onAppear {
                    // Lock to portrait during loading
                    if authManager.isLoading {
                        AppDelegate.orientationLock = .portrait
                    }
                }
                .onChange(of: authManager.isLoading) { _, isLoading in
                    // Unlock orientation after loading
                    if !isLoading {
                        AppDelegate.orientationLock = .all
                    }
                }
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
        .onOpenURL { url in
            // Handle OAuth callback from Google/other providers
            if url.scheme == "roundcaddy" {
                Task {
                    await authManager.handleOAuthCallback(url: url)
                }
            }
        }
    }
}

// Lock orientation to portrait during loading
extension View {
    func lockOrientation(_ orientation: UIInterfaceOrientationMask) -> some View {
        self.onAppear {
            AppDelegate.orientationLock = orientation
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
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
