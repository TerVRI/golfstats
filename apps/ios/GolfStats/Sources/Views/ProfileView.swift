import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var watchSyncManager: WatchSyncManager
    @EnvironmentObject var userProfileManager: UserProfileManager
    @Environment(\.openURL) private var openURL
    @StateObject private var golfBag = GolfBag.shared
    @State private var stats: UserStats = .empty
    @State private var isLoading = true
    @State private var showSignOutAlert = false
    @State private var showBagEditor = false
    @State private var showPaywall = false
    @State private var showDeleteAlert = false
    @State private var showSettings = false
    @State private var showOnboarding = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header with Edit Button
                    VStack(spacing: 16) {
                        ZStack(alignment: .bottomTrailing) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                Text(authManager.currentUser?.initials ?? "G")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            
                            NavigationLink(destination: EditProfileView()) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                    .background(Circle().fill(Color("Background")))
                            }
                        }
                        
                        VStack(spacing: 4) {
                            Text(authManager.currentUser?.displayName ?? "Golfer")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            if let email = authManager.currentUser?.email {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            // Show profile info summary
                            if let profile = userProfileManager.userProfile {
                                HStack(spacing: 12) {
                                    if let handicap = profile.handicapIndex {
                                        ProfileInfoBadge(icon: "number", text: String(format: "%.1f", handicap))
                                    }
                                    
                                    ProfileInfoBadge(icon: "hand.raised", text: profile.handedness.shortName)
                                    
                                    if let targetHcp = profile.targetHandicap {
                                        ProfileInfoBadge(icon: "target", text: "→ \(Int(targetHcp))")
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                    .padding()

                    if !authManager.hasProAccess {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Image(systemName: "star.fill")
                                Text("Start Pro Free Trial")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Settings Button
                    Button {
                        showSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("Settings")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color("BackgroundSecondary"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Notifications Button
                    NavigationLink(destination: NotificationsView()) {
                        HStack {
                            Image(systemName: "bell.fill")
                            Text("Notifications")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color("BackgroundSecondary"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Handicap Card
                    if let handicap = stats.handicapIndex {
                        VStack(spacing: 8) {
                            Text("Handicap Index")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text(String(format: "%.1f", handicap))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("BackgroundSecondary"))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Stats Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ProfileStatCard(title: "Rounds Played", value: "\(stats.roundsPlayed)", icon: "flag.fill")
                        ProfileStatCard(title: "Average Score", value: stats.roundsPlayed > 0 ? String(format: "%.0f", stats.averageScore) : "-", icon: "number")
                        ProfileStatCard(title: "Best Score", value: stats.bestScore > 0 ? "\(stats.bestScore)" : "-", icon: "trophy.fill")
                        ProfileStatCard(title: "Avg SG", value: stats.roundsPlayed > 0 ? String(format: "%+.1f", stats.averageSG) : "-", icon: "chart.line.uptrend.xyaxis")
                    }
                    .padding(.horizontal)
                    
                    // My Bag Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("My Bag")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button {
                                showBagEditor = true
                            } label: {
                                Text("Edit")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Text("\(golfBag.clubs.count) clubs")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        // Club grid
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
                            ForEach(golfBag.clubs) { club in
                                Text(club.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.green.opacity(0.3))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color("BackgroundSecondary"))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Watch Status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Connected Devices")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack {
                            Image(systemName: authManager.hasProAccess ? "applewatch" : "lock.fill")
                                .font(.title2)
                                .foregroundColor(authManager.hasProAccess ? (watchSyncManager.isWatchConnected ? .green : .gray) : .gray)
                            
                            VStack(alignment: .leading) {
                                Text("Apple Watch")
                                    .foregroundColor(.white)
                                if authManager.hasProAccess {
                                    Text(watchSyncManager.isWatchConnected ? "Connected" : "Not Connected")
                                        .font(.caption)
                                        .foregroundColor(watchSyncManager.isWatchConnected ? .green : .gray)
                                } else {
                                    Text("Pro required")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            if authManager.hasProAccess, watchSyncManager.isWatchConnected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(Color("BackgroundSecondary"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Sign Out
                    Button {
                        showSignOutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("BackgroundSecondary"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // Delete Account
                    Button {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Account")
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("BackgroundSecondary"))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // App Info
                    VStack(spacing: 4) {
                        Text("RoundCaddy")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("Version 1.0.0")
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .padding()
                }
                .padding(.vertical)
            }
            .background(Color("Background"))
            .navigationTitle("Profile")
        }
        .alert("Sign Out?", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task {
                    await authManager.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Account", role: .destructive) {
                if let url = AccountConfig.deleteAccountURL {
                    openURL(url)
                }
                Task {
                    await authManager.signOut()
                }
            }
        } message: {
            Text("This will take you to the account deletion page to permanently delete your account.")
        }
        .sheet(isPresented: $showBagEditor) {
            BagEditorView(golfBag: golfBag, watchSyncManager: watchSyncManager)
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            UserProfileOnboardingView()
        }
        .task {
            await loadStats()
        }
        .onAppear {
            // Sync bag to watch when profile loads
            watchSyncManager.sendBagToWatch(clubs: golfBag.clubNames)
            
            // Check if onboarding is needed
            if userProfileManager.needsOnboarding {
                showOnboarding = true
            }
        }
        .onChange(of: userProfileManager.needsOnboarding) { _, needsOnboarding in
            if needsOnboarding {
                showOnboarding = true
            }
        }
    }
    
    private func loadStats() async {
        guard let user = authManager.currentUser else { return }
        isLoading = true
        
        do {
            stats = try await DataService.shared.fetchStats(
                userId: user.id,
                authHeaders: authManager.authHeaders
            )
        } catch {
            print("Error loading stats: \(error)")
        }
        
        isLoading = false
    }
}

struct ProfileStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
    }
}

// MARK: - Bag Editor View

struct BagEditorView: View {
    @ObservedObject var golfBag: GolfBag
    @ObservedObject var watchSyncManager: WatchSyncManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(ClubCategory.allCases, id: \.self) { category in
                    Section(header: Text(category.rawValue)) {
                        let clubsInCategory = ClubType.allCases.filter { $0.category == category }
                        ForEach(clubsInCategory) { club in
                            HStack {
                                Text(club.rawValue)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if golfBag.isInBag(club) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleClub(club)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color("Background"))
            .navigationTitle("Edit My Bag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Sync to watch when done editing
                        watchSyncManager.sendBagToWatch(clubs: golfBag.clubNames)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func toggleClub(_ club: ClubType) {
        if golfBag.isInBag(club) {
            golfBag.removeClub(club)
        } else {
            golfBag.addClub(club)
        }
    }
}

// MARK: - Profile Info Badge

struct ProfileInfoBadge: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.green)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.2))
        .cornerRadius(8)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
        .environmentObject(WatchSyncManager())
        .environmentObject(UserProfileManager.shared)
        .preferredColorScheme(.dark)
}
