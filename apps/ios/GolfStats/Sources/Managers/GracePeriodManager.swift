import Foundation
import Combine

/// Manages the tiered access model with grace period, free tier, trial, and Pro
/// Handles feature gating, access level determination, and prompts
@MainActor
class GracePeriodManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = GracePeriodManager()
    
    // MARK: - Published State
    
    @Published private(set) var currentAccessLevel: AccessLevel = .free
    @Published private(set) var gracePeriodDaysRemaining: Int = 0
    @Published private(set) var trialDaysRemaining: Int = 0
    @Published private(set) var isGracePeriodExpired: Bool = false
    @Published private(set) var isTrialActive: Bool = false
    @Published private(set) var hasUsedTrial: Bool = false
    
    // MARK: - Storage Keys
    
    private let installDateKey = "app_install_date"
    private let trialStartDateKey = "trial_start_date"
    private let hasUsedTrialKey = "has_used_trial"
    private let proSubscriptionActiveKey = "pro_subscription_active"
    
    // MARK: - Developer/Test Accounts (permanent pro access)
    
    private let developerEmails: Set<String> = [
        "terry@vrim.ie",
        "test@roundcaddy.com"
    ]
    
    /// Current logged-in user email (set by AuthManager)
    var currentUserEmail: String? {
        didSet {
            updateAccessLevel()
        }
    }
    
    /// Check if current user is a developer/tester with permanent pro access
    private var isDeveloperAccount: Bool {
        guard let email = currentUserEmail?.lowercased() else { return false }
        return developerEmails.contains(email)
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let calendar = Calendar.current
    
    // MARK: - Initialization
    
    private init() {
        setupInstallDate()
        updateAccessLevel()
        
        // Refresh access level periodically
        Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateAccessLevel()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Setup
    
    private func setupInstallDate() {
        // Record install date if not already set
        if UserDefaults.standard.object(forKey: installDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: installDateKey)
        }
        
        hasUsedTrial = UserDefaults.standard.bool(forKey: hasUsedTrialKey)
    }
    
    // MARK: - Access Level Determination
    
    func updateAccessLevel() {
        // Check if developer/test account (always Pro)
        if isDeveloperAccount {
            currentAccessLevel = .pro
            gracePeriodDaysRemaining = 0
            trialDaysRemaining = 0
            isGracePeriodExpired = false
            isTrialActive = false
            return
        }
        
        // Check if Pro subscription is active
        if isProSubscriptionActive {
            currentAccessLevel = .pro
            gracePeriodDaysRemaining = 0
            trialDaysRemaining = 0
            isGracePeriodExpired = false
            isTrialActive = false
            return
        }
        
        // Check if trial is active
        if let trialStart = trialStartDate {
            let daysSinceTrialStart = daysSince(trialStart)
            if daysSinceTrialStart < GracePeriodConfig.trialDurationDays {
                currentAccessLevel = .trial
                trialDaysRemaining = GracePeriodConfig.trialDurationDays - daysSinceTrialStart
                isTrialActive = true
                gracePeriodDaysRemaining = 0
                isGracePeriodExpired = true
                return
            } else {
                // Trial has expired
                isTrialActive = false
                trialDaysRemaining = 0
            }
        }
        
        // Check grace period
        let daysSinceInstall = daysSinceInstallation
        
        if daysSinceInstall < GracePeriodConfig.durationDays {
            currentAccessLevel = .gracePeriod
            gracePeriodDaysRemaining = GracePeriodConfig.durationDays - daysSinceInstall
            isGracePeriodExpired = false
        } else {
            currentAccessLevel = .free
            gracePeriodDaysRemaining = 0
            isGracePeriodExpired = true
        }
    }
    
    // MARK: - Feature Access
    
    /// Check if a specific feature is available at current access level
    func hasAccess(to feature: AppFeature) -> Bool {
        switch currentAccessLevel {
        case .pro, .trial:
            return true // All features available
            
        case .gracePeriod:
            return GracePeriodConfig.gracePeriodFeatures.contains(feature) ||
                   GracePeriodConfig.freeFeatures.contains(feature)
            
        case .free:
            return GracePeriodConfig.freeFeatures.contains(feature)
        }
    }
    
    /// Check if a round mode is available
    func hasAccess(to mode: RoundMode) -> Bool {
        return currentAccessLevel >= mode.minimumAccessLevel
    }
    
    /// Get reason why feature is locked
    func lockReason(for feature: AppFeature) -> LockReason? {
        guard !hasAccess(to: feature) else { return nil }
        
        if feature.requiresPro {
            return .requiresPro
        }
        
        if isGracePeriodExpired && !hasUsedTrial {
            return .gracePeriodExpired
        }
        
        if hasUsedTrial {
            return .trialExpired
        }
        
        return .requiresPro
    }
    
    // MARK: - Trial Management
    
    /// Start the free trial
    func startTrial() -> Bool {
        guard !hasUsedTrial else {
            print("⚠️ Trial already used")
            return false
        }
        
        UserDefaults.standard.set(Date(), forKey: trialStartDateKey)
        UserDefaults.standard.set(true, forKey: hasUsedTrialKey)
        hasUsedTrial = true
        
        updateAccessLevel()
        
        print("✅ Free trial started")
        return true
    }
    
    /// Check if user can start a trial
    var canStartTrial: Bool {
        return !hasUsedTrial && !isProSubscriptionActive
    }
    
    // MARK: - Subscription
    
    /// Update when subscription status changes
    func setProSubscriptionActive(_ active: Bool) {
        UserDefaults.standard.set(active, forKey: proSubscriptionActiveKey)
        updateAccessLevel()
    }
    
    private var isProSubscriptionActive: Bool {
        return UserDefaults.standard.bool(forKey: proSubscriptionActiveKey)
    }
    
    // MARK: - Date Calculations
    
    private var installDate: Date {
        return UserDefaults.standard.object(forKey: installDateKey) as? Date ?? Date()
    }
    
    private var trialStartDate: Date? {
        return UserDefaults.standard.object(forKey: trialStartDateKey) as? Date
    }
    
    private var daysSinceInstallation: Int {
        return daysSince(installDate)
    }
    
    private func daysSince(_ date: Date) -> Int {
        let components = calendar.dateComponents([.day], from: date, to: Date())
        return components.day ?? 0
    }
    
    // MARK: - UI Helpers
    
    /// Get appropriate prompt for locked feature
    func promptType(for feature: AppFeature) -> FeaturePromptType {
        guard !hasAccess(to: feature) else { return .none }
        
        if !isGracePeriodExpired {
            // Still in grace period but feature is Pro-only
            return .proPreview
        }
        
        if canStartTrial {
            return .startTrial
        }
        
        return .upgrade
    }
    
    /// Get status text for display
    var statusText: String {
        switch currentAccessLevel {
        case .pro:
            return "Pro Member"
        case .trial:
            return "Trial: \(trialDaysRemaining) days left"
        case .gracePeriod:
            return "\(gracePeriodDaysRemaining) days to explore"
        case .free:
            return "Free Plan"
        }
    }
    
    /// Get upgrade call-to-action based on current state
    var upgradeCallToAction: String {
        if canStartTrial {
            return "Start Free Trial"
        }
        return "Upgrade to Pro"
    }
}

// MARK: - Supporting Types

enum LockReason {
    case requiresPro
    case gracePeriodExpired
    case trialExpired
    
    var title: String {
        switch self {
        case .requiresPro:
            return "Pro Feature"
        case .gracePeriodExpired:
            return "Exploration Period Ended"
        case .trialExpired:
            return "Trial Expired"
        }
    }
    
    var message: String {
        switch self {
        case .requiresPro:
            return "This feature is available with Pro subscription."
        case .gracePeriodExpired:
            return "Your 2-week exploration period has ended. Start a free trial or upgrade to continue using this feature."
        case .trialExpired:
            return "Your free trial has ended. Upgrade to Pro to continue using all features."
        }
    }
}

enum FeaturePromptType {
    case none           // Feature is accessible
    case proPreview     // Show what Pro offers
    case startTrial     // Prompt to start trial
    case upgrade        // Prompt to upgrade
}

// MARK: - SwiftUI Integration

import SwiftUI

/// View modifier for feature gating
struct FeatureGatedModifier: ViewModifier {
    let feature: AppFeature
    @ObservedObject var gracePeriodManager = GracePeriodManager.shared
    @State private var showPaywall = false
    
    let content: () -> AnyView
    let lockedContent: () -> AnyView
    
    func body(content: Content) -> some View {
        Group {
            if gracePeriodManager.hasAccess(to: feature) {
                content
            } else {
                lockedContent()
                    .onTapGesture {
                        showPaywall = true
                    }
            }
        }
        .sheet(isPresented: $showPaywall) {
            FeatureLockedSheet(feature: feature)
        }
    }
}

/// Sheet shown when accessing locked feature
struct FeatureLockedSheet: View {
    let feature: AppFeature
    @ObservedObject var gracePeriodManager = GracePeriodManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "lock.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)
                
                // Title
                Text(lockReason?.title ?? "Pro Feature")
                    .font(.title)
                    .fontWeight(.bold)
                
                // Message
                Text(lockReason?.message ?? "")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Feature name
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text(feature.displayName)
                        .fontWeight(.semibold)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    if gracePeriodManager.canStartTrial {
                        Button(action: startTrial) {
                            Text("Start 7-Day Free Trial")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.green)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    
                    Button(action: { /* Navigate to paywall */ }) {
                        Text("View Pro Plans")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button("Maybe Later") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    private var lockReason: LockReason? {
        gracePeriodManager.lockReason(for: feature)
    }
    
    private func startTrial() {
        if gracePeriodManager.startTrial() {
            dismiss()
        }
    }
}

/// Locked feature overlay view
struct LockedFeatureOverlay: View {
    let feature: AppFeature
    @ObservedObject var gracePeriodManager = GracePeriodManager.shared
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
            
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                
                Text(feature.displayName)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(gracePeriodManager.upgradeCallToAction)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.green)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Gate a view behind a feature check
    func featureGated(
        _ feature: AppFeature,
        locked: @escaping () -> some View = { EmptyView() }
    ) -> some View {
        modifier(FeatureGatedModifier(
            feature: feature,
            content: { AnyView(self) },
            lockedContent: { AnyView(locked()) }
        ))
    }
}
