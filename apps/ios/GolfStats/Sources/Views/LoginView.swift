import SwiftUI
import AuthenticationServices

enum AuthMode {
    case signIn
    case signUp
}

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var authMode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var fullName = ""
    @State private var showEmailForm = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color("Background"), Color("BackgroundSecondary")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: 40)
                    
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
                    if !showEmailForm {
                        VStack(alignment: .leading, spacing: 16) {
                            FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Track your strokes gained")
                            FeatureRow(icon: "location.fill", text: "GPS distances to greens")
                            FeatureRow(icon: "applewatch", text: "Apple Watch companion")
                            FeatureRow(icon: "cloud.sun.fill", text: "Weather-adjusted distances")
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                    }
                    
                    Spacer()
                        .frame(height: showEmailForm ? 0 : 20)
                    
                    // Auth Options
                    VStack(spacing: 16) {
                        if showEmailForm {
                            // Email Form
                            emailFormSection
                        } else {
                            // Social Sign-In Buttons
                            socialSignInSection
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Loading indicator
                    if authManager.isSigningIn {
                        ProgressView()
                            .tint(.white)
                            .padding()
                    }
                    
                    // Error/Success message
                    if let error = authManager.error {
                        Text(error)
                            .font(.subheadline)
                            .fontWeight(error.contains("✅") ? .medium : .regular)
                            .foregroundColor(error.contains("✅") || error.contains("Check your email") ? .green : .red)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 8)
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
        .onOpenURL { url in
            // Handle Google OAuth callback
            if url.scheme == "golfstats" && url.host == "auth" {
                Task {
                    await authManager.handleOAuthCallback(url: url)
                }
            }
        }
    }
    
    // MARK: - Social Sign-In Section
    
    private var socialSignInSection: some View {
        VStack(spacing: 12) {
            // Sign in with Apple
            SignInWithAppleButton(
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        Task {
                            await authManager.signInWithApple(authorization: authorization)
                        }
                    case .failure(let error):
                        print("Sign in with Apple failed: \(error.localizedDescription)")
                    }
                }
            )
            .signInWithAppleButtonStyle(.white)
            .frame(height: 55)
            .cornerRadius(12)
            .disabled(authManager.isSigningIn)
            
            // Sign in with Google
            Button(action: {
                if let url = authManager.getGoogleSignInURL() {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "g.circle.fill")
                        .font(.title2)
                    Text("Sign in with Google")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 55)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(12)
            }
            .disabled(authManager.isSigningIn)
            
            // Divider
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                Text("or")
                    .font(.caption)
                    .foregroundColor(.gray)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.vertical, 8)
            
            // Continue with Email
            Button(action: {
                withAnimation {
                    showEmailForm = true
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.title3)
                    Text("Continue with Email")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 55)
                .background(Color("BackgroundTertiary"))
                .foregroundColor(.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .disabled(authManager.isSigningIn)
        }
    }
    
    // MARK: - Email Form Section
    
    private var emailFormSection: some View {
        VStack(spacing: 16) {
            // Auth mode toggle
            Picker("", selection: $authMode) {
                Text("Sign In").tag(AuthMode.signIn)
                Text("Sign Up").tag(AuthMode.signUp)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 8)
            
            // Full name (sign up only)
            if authMode == .signUp {
                TextField("Full Name", text: $fullName)
                    .textFieldStyle(AuthTextFieldStyle())
                    .textContentType(.name)
                    .autocapitalization(.words)
            }
            
            // Email
            TextField("Email", text: $email)
                .textFieldStyle(AuthTextFieldStyle())
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            // Password
            SecureField("Password", text: $password)
                .textFieldStyle(AuthTextFieldStyle())
                .textContentType(authMode == .signUp ? .newPassword : .password)
            
            // Submit button
            Button(action: {
                Task {
                    if authMode == .signIn {
                        await authManager.signInWithEmail(email: email, password: password)
                    } else {
                        await authManager.signUpWithEmail(email: email, password: password, fullName: fullName)
                    }
                }
            }) {
                Text(authMode == .signIn ? "Sign In" : "Create Account")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(
                        LinearGradient(
                            colors: [.green, .teal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(authManager.isSigningIn || email.isEmpty || password.isEmpty || (authMode == .signUp && fullName.isEmpty))
            .opacity(email.isEmpty || password.isEmpty || (authMode == .signUp && fullName.isEmpty) ? 0.6 : 1)
            
            // Back button
            Button(action: {
                withAnimation {
                    showEmailForm = false
                    email = ""
                    password = ""
                    fullName = ""
                }
            }) {
                Text("← Back to all sign-in options")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Supporting Views

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

struct AuthTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color("BackgroundTertiary"))
            .foregroundColor(.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
