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
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var userProfileManager = UserProfileManager()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(gpsManager)
                .environmentObject(roundManager)
                .environmentObject(watchSyncManager)
                .environmentObject(subscriptionManager)
                .environmentObject(userProfileManager)
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
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        Task {
                            await subscriptionManager.refreshAllEntitlements()
                        }
                    }
                }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var gpsManager: GPSManager
    @EnvironmentObject var watchSyncManager: WatchSyncManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    // TEMP: Set to true to test polygon visualization
    private let testPolygonMode = false
    
    var body: some View {
        Group {
            if testPolygonMode {
                PolygonTestView()
            } else if authManager.isLoading {
                LoadingView()
            } else if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut, value: authManager.isAuthenticated)
        .onAppear {
            watchSyncManager.attachGPSManager(gpsManager)
            // Note: hasProAccess is now computed from GracePeriodManager
            // which handles developer accounts, subscriptions, trials, and grace periods
        }
        .onChange(of: subscriptionManager.hasProAccess) { _, hasProAccess in
            // Update GracePeriodManager with subscription status
            GracePeriodManager.shared.setProSubscriptionActive(hasProAccess)
        }
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

// MARK: - Polygon Test View
struct PolygonTestView: View {
    @State private var holeData: [HoleData]? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var courseName = "Loading..."
    
    // Riverside Golf Club - verified to have full polygon data
    let courseId = "6aafb345-32a0-4cac-9b95-959a5ab2453c"
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading polygon data...")
                            .foregroundColor(.gray)
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                } else if let holeData = holeData {
                    CourseVisualizerView(holeData: holeData, initialHole: 1, showSatellite: true)
                } else {
                    Text("No data available")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle(courseName)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadCourseData()
        }
    }
    
    private func loadCourseData() async {
        do {
            // Fetch hole data from Supabase
            if let data = try await CourseBundleLoader.shared.fetchHoleData(for: courseId) {
                self.holeData = data
                self.courseName = "Riverside Golf Club"
                print("✅ Loaded \(data.count) holes")
                if let h1 = data.first {
                    print("   Hole 1: green=\(h1.green?.count ?? 0) pts, fairway=\(h1.fairway?.count ?? 0) pts, bunkers=\(h1.bunkers?.count ?? 0)")
                }
            } else {
                self.errorMessage = "No hole data found for this course"
            }
        } catch {
            self.errorMessage = "Error: \(error.localizedDescription)"
            print("❌ Error loading hole data: \(error)")
        }
        self.isLoading = false
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
        .environmentObject(GPSManager())
        .environmentObject(RoundManager())
        .environmentObject(WatchSyncManager())
        .environmentObject(SubscriptionManager())
        .environmentObject(UserProfileManager())
}
