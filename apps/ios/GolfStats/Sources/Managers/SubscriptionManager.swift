import Foundation
import StoreKit

@MainActor
final class SubscriptionManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var hasProAccess = false
    @Published var isLoading = false
    @Published var error: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task {
            await listenForTransactions()
        }
        Task {
            await refreshProducts()
            await refreshEntitlements()
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

    func refreshEntitlements() async {
        var isPro = false
        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = checkVerified(entitlement) else { continue }
            if SubscriptionConfig.productIds.contains(transaction.productID) {
                isPro = true
                break
            }
        }
        hasProAccess = isPro
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
                await refreshEntitlements()
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
        await refreshEntitlements()
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
                await refreshEntitlements()
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
