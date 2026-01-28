import Foundation
import StoreKit

/// Subscription status details
struct SubscriptionStatus {
    let hasPro: Bool
    let source: SubscriptionSource?
    let plan: SubscriptionPlan?
    let expiresAt: Date?
    let isTrial: Bool
    
    static let free = SubscriptionStatus(hasPro: false, source: nil, plan: nil, expiresAt: nil, isTrial: false)
}

enum SubscriptionSource: String, Codable {
    case apple
    case stripe
    case promo
}

enum SubscriptionPlan: String, Codable {
    case monthly
    case annual
}

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var hasProAccess = false
    @Published var subscriptionStatus: SubscriptionStatus = .free
    @Published var isLoading = false
    @Published var error: String?
    
    // Track where subscription came from
    @Published var hasAppleSubscription = false
    @Published var hasWebSubscription = false

    private var updatesTask: Task<Void, Never>?
    
    private let supabaseUrl = "https://kanvhqwrfkzqktuvpxnp.supabase.co"
    private let supabaseKey = "sb_publishable_JftEdMATFsi78Ba8rIFObg_tpOeIS2J"

    init() {
        updatesTask = Task {
            await listenForTransactions()
        }
        Task {
            await refreshProducts()
            await refreshAllEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func refreshProducts() async {
        isLoading = true
        error = nil
        do {
            products = try await Product.products(for: SubscriptionConfig.productIds)
        } catch {
            self.error = "Unable to load subscription options."
        }
        isLoading = false
    }

    /// Refresh entitlements from BOTH Apple IAP and web subscriptions
    func refreshAllEntitlements() async {
        async let appleCheck = checkAppleEntitlements()
        async let webCheck = checkWebSubscription()
        
        let (hasApple, hasWeb) = await (appleCheck, webCheck)
        
        hasAppleSubscription = hasApple
        hasWebSubscription = hasWeb
        hasProAccess = hasApple || hasWeb
        
        print("📱 Subscription status: Apple=\(hasApple), Web=\(hasWeb), Pro=\(hasProAccess)")
    }
    
    /// Check Apple IAP entitlements
    private func checkAppleEntitlements() async -> Bool {
        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = checkVerified(entitlement) else { continue }
            if SubscriptionConfig.productIds.contains(transaction.productID) {
                // Sync to Supabase for cross-platform tracking
                await syncApplePurchaseToSupabase(transaction: transaction)
                return true
            }
        }
        return false
    }
    
    /// Check web subscription from Supabase
    private func checkWebSubscription() async -> Bool {
        // Get current user ID from auth
        guard let userId = await getCurrentUserId() else {
            return false
        }
        
        do {
            var urlComponents = URLComponents(string: "\(supabaseUrl)/rest/v1/rpc/has_pro_access")!
            
            var request = URLRequest(url: urlComponents.url!)
            request.httpMethod = "POST"
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["p_user_id": userId])
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }
            
            // The function returns a boolean
            if let result = try? JSONDecoder().decode(Bool.self, from: data) {
                return result
            }
            
            return false
        } catch {
            print("⚠️ Error checking web subscription: \(error)")
            return false
        }
    }
    
    /// Get current user ID from Supabase auth
    private func getCurrentUserId() async -> String? {
        // Check if we have a stored access token
        guard let token = UserDefaults.standard.string(forKey: "access_token") else {
            return nil
        }
        
        do {
            var request = URLRequest(url: URL(string: "\(supabaseUrl)/auth/v1/user")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let userId = json["id"] as? String {
                return userId
            }
            
            return nil
        } catch {
            return nil
        }
    }
    
    /// Sync Apple purchase to Supabase for tracking
    private func syncApplePurchaseToSupabase(transaction: Transaction) async {
        guard let userId = await getCurrentUserId() else { return }
        
        let plan: String = transaction.productID.contains("annual") ? "annual" : "monthly"
        
        let body: [String: Any] = [
            "user_id": userId,
            "source": "apple",
            "plan": plan,
            "status": "active",
            "apple_transaction_id": String(transaction.id),
            "apple_original_transaction_id": String(transaction.originalID),
            "current_period_end": ISO8601DateFormatter().string(from: transaction.expirationDate ?? Date().addingTimeInterval(30*24*60*60))
        ]
        
        do {
            var request = URLRequest(url: URL(string: "\(supabaseUrl)/rest/v1/subscriptions")!)
            request.httpMethod = "POST"
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📱 Synced Apple purchase to Supabase: \(httpResponse.statusCode)")
            }
        } catch {
            print("⚠️ Failed to sync Apple purchase: \(error)")
        }
    }

    func purchase(_ product: Product) async {
        isLoading = true
        error = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if let transaction = checkVerified(verification) {
                    await transaction.finish()
                }
                await refreshAllEntitlements()
            case .userCancelled:
                break
            case .pending:
                error = "Purchase pending. Please complete it in the App Store."
            @unknown default:
                error = "Purchase failed. Please try again."
            }
        } catch {
            self.error = "Purchase failed. Please try again."
        }

        isLoading = false
    }

    func restorePurchases() async {
        isLoading = true
        error = nil
        await refreshAllEntitlements()
        isLoading = false
    }

    func manageSubscriptions() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            guard let transaction = checkVerified(update) else { continue }
            if SubscriptionConfig.productIds.contains(transaction.productID) {
                await refreshAllEntitlements()
            }
            await transaction.finish()
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) -> T? {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            return nil
        }
    }
}
