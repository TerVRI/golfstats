import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedProduct: Product?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Features list
                    featuresSection
                    
                    // Subscription options
                    subscriptionOptions
                    
                    // Subscribe button
                    subscribeButton
                    
                    // Restore and terms
                    footerSection
                }
                .padding()
            }
            .background(Color("BackgroundPrimary"))
            .navigationTitle("Upgrade to Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Select annual by default (best value)
            if selectedProduct == nil {
                selectedProduct = subscriptionManager.products.first { $0.id.contains("annual") }
                    ?? subscriptionManager.products.first
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.linearGradient(
                    colors: [.green, .mint],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            Text("Unlock Your Full Potential")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Get tour-level analytics and unlimited round tracking")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Strokes Gained Analytics", description: "See exactly where you're gaining and losing strokes")
            
            FeatureRow(icon: "infinity", title: "Unlimited Rounds", description: "Track as many rounds as you want")
            
            FeatureRow(icon: "applewatch", title: "Apple Watch App", description: "Quick score entry and distances on your wrist")
            
            FeatureRow(icon: "figure.golf", title: "Swing Analysis", description: "AI-powered tips to improve your game")
            
            FeatureRow(icon: "map.fill", title: "Course Visualization", description: "Detailed hole maps with hazards and greens")
            
            FeatureRow(icon: "person.2.fill", title: "Compare with Friends", description: "See how you stack up against others")
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(16)
    }
    
    private var subscriptionOptions: some View {
        VStack(spacing: 12) {
            if subscriptionManager.isLoading {
                ProgressView()
                    .padding()
            } else if subscriptionManager.products.isEmpty {
                Text("Unable to load subscription options")
                    .foregroundColor(.secondary)
            } else {
                ForEach(subscriptionManager.products.sorted { $0.price > $1.price }, id: \.id) { product in
                    SubscriptionOptionCard(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        isAnnual: product.id.contains("annual")
                    ) {
                        selectedProduct = product
                    }
                }
            }
        }
    }
    
    private var subscribeButton: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    if let product = selectedProduct {
                        await subscriptionManager.purchase(product)
                        if subscriptionManager.hasProAccess {
                            dismiss()
                        }
                    }
                }
            } label: {
                HStack {
                    if subscriptionManager.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Start Free Trial")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(selectedProduct == nil || subscriptionManager.isLoading)
            
            if let error = subscriptionManager.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            Text("14-day free trial, then auto-renews")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var footerSection: some View {
        VStack(spacing: 16) {
            Button("Restore Purchases") {
                Task {
                    await subscriptionManager.restorePurchases()
                    if subscriptionManager.hasProAccess {
                        dismiss()
                    }
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless it is cancelled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions by going to your account settings in the App Store after purchase.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 16) {
                    Link("Terms of Service", destination: URL(string: "https://roundcaddy.com/terms")!)
                    Link("Privacy Policy", destination: URL(string: "https://roundcaddy.com/privacy")!)
                }
                .font(.caption2)
            }
        }
        .padding(.top)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.green)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SubscriptionOptionCard: View {
    let product: Product
    let isSelected: Bool
    let isAnnual: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(isAnnual ? "Annual" : "Monthly")
                            .font(.headline)
                        
                        if isAnnual {
                            Text("Best Value")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(isAnnual ? "Save 40% vs monthly" : "Cancel anytime")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text(isAnnual ? "/year" : "/month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .green : .secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.green : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.green.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView()
        .environmentObject(SubscriptionManager())
}
