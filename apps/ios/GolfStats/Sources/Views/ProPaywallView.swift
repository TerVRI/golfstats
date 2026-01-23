import SwiftUI
import StoreKit

struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    featuresSection
                    plansSection
                    footerSection
                }
                .padding()
            }
            .background(Color("Background"))
            .navigationTitle("RoundCaddy Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if subscriptionManager.products.isEmpty {
                    await subscriptionManager.refreshProducts()
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Start your 14-day free trial")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("Unlock Watch GPS, swing analytics, and unlimited rounds.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FeatureRow(icon: "applewatch", text: "Apple Watch live round + swing tracking")
            FeatureRow(icon: "waveform.path.ecg", text: "Swing analytics and coaching")
            FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Advanced insights and trends")
            FeatureRow(icon: "infinity", text: "Unlimited rounds history")
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
    }

    private var plansSection: some View {
        VStack(spacing: 12) {
            if subscriptionManager.isLoading {
                ProgressView()
                    .tint(.green)
            } else if subscriptionManager.products.isEmpty {
                Text("Subscription options unavailable.")
                    .font(.footnote)
                    .foregroundColor(.gray)
            } else {
                ForEach(subscriptionManager.products.sorted(by: { $0.displayPrice < $1.displayPrice }), id: \.id) { product in
                    Button {
                        Task { await subscriptionManager.purchase(product) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.displayName)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(product.displayPrice)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let error = subscriptionManager.error {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var footerSection: some View {
        VStack(spacing: 8) {
            Button("Restore Purchases") {
                Task { await subscriptionManager.restorePurchases() }
            }
            .font(.footnote)
            .foregroundColor(.green)

            Button("Manage Subscription") {
                subscriptionManager.manageSubscriptions()
            }
            .font(.footnote)
            .foregroundColor(.green)

            Text("Auto-renewing subscription. Cancel anytime in Settings.")
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }
}
