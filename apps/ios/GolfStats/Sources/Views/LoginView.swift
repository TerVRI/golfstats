import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isSigningIn = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color("Background"), Color("BackgroundSecondary")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Logo
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.green, .teal],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "flag.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                    }
                    
                    Text("GolfStats")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Strokes Gained Analytics")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // Features
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Track your strokes gained")
                    FeatureRow(icon: "location.fill", text: "GPS distances to greens")
                    FeatureRow(icon: "applewatch", text: "Apple Watch companion")
                    FeatureRow(icon: "cloud.sun.fill", text: "Weather-adjusted distances")
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Sign in with Apple
                SignInWithAppleButton(
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            isSigningIn = true
                            Task {
                                await authManager.signInWithApple(authorization: authorization)
                                isSigningIn = false
                            }
                        case .failure(let error):
                            print("Sign in with Apple failed: \(error.localizedDescription)")
                        }
                    }
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 55)
                .cornerRadius(12)
                .padding(.horizontal, 32)
                .disabled(isSigningIn)
                .opacity(isSigningIn ? 0.7 : 1)
                
                if isSigningIn {
                    ProgressView()
                        .tint(.white)
                }
                
                if let error = authManager.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                // Terms
                Text("By signing in, you agree to our Terms of Service and Privacy Policy")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.green)
                .frame(width: 30)
            
            Text(text)
                .foregroundColor(.white)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
