import Foundation
import AuthenticationServices
import CryptoKit

enum AuthProvider: String {
    case apple
    case google
    case email
}

@MainActor
class AuthManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = true
    @Published var error: String?
    @Published var isSigningIn = false
    
    var isAuthenticated: Bool {
        currentUser != nil
    }
    
    private let supabaseUrl = "https://kanvhqwrfkzqktuvpxnp.supabase.co"
    private let supabaseKey = "sb_publishable_JftEdMATFsi78Ba8rIFObg_tpOeIS2J"
    
    private var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "access_token") }
        set { UserDefaults.standard.set(newValue, forKey: "access_token") }
    }
    
    private var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "refresh_token") }
        set { UserDefaults.standard.set(newValue, forKey: "refresh_token") }
    }
    
    init() {
        // SCREENSHOT_MODE: Set to true only when capturing App Store screenshots
        #if DEBUG
        // To enable screenshot mode, change the return value below to `true`
        func isScreenshotModeEnabled() -> Bool { false }
        
        if isScreenshotModeEnabled() {
            self.currentUser = User(
                id: "demo-user-id",
                email: "demo@roundcaddy.com",
                fullName: "Mike Johnson",
                avatarUrl: nil
            )
            self.isLoading = false
            return
        }
        #endif
        
        Task {
            await checkSession()
        }
    }
    
    // MARK: - Session Management
    
    func checkSession() async {
        isLoading = true
        
        guard let token = accessToken else {
            isLoading = false
            return
        }
        
        // Verify token with Supabase
        do {
            let user = try await fetchUser(token: token)
            self.currentUser = user
        } catch {
            // Token expired, try refresh
            if let refresh = refreshToken {
                do {
                    try await refreshSession(refreshToken: refresh)
                } catch {
                    await signOut()
                }
            } else {
                await signOut()
            }
        }
        
        isLoading = false
    }
    
    private func fetchUser(token: String) async throws -> User {
        var request = URLRequest(url: URL(string: "\(supabaseUrl)/auth/v1/user")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.invalidSession
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        return User(
            id: json?["id"] as? String ?? "",
            email: json?["email"] as? String,
            fullName: (json?["user_metadata"] as? [String: Any])?["full_name"] as? String,
            avatarUrl: (json?["user_metadata"] as? [String: Any])?["avatar_url"] as? String
        )
    }
    
    private func refreshSession(refreshToken: String) async throws {
        var request = URLRequest(url: URL(string: "\(supabaseUrl)/auth/v1/token?grant_type=refresh_token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(["refresh_token": refreshToken])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.refreshFailed
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        self.accessToken = json?["access_token"] as? String
        self.refreshToken = json?["refresh_token"] as? String
        
        if let token = self.accessToken {
            self.currentUser = try await fetchUser(token: token)
        }
    }
    
    // MARK: - Sign In with Email
    
    func signInWithEmail(email: String, password: String) async {
        isSigningIn = true
        error = nil
        
        do {
            var request = URLRequest(url: URL(string: "\(supabaseUrl)/auth/v1/token?grant_type=password")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            
            let body: [String: Any] = [
                "email": email,
                "password": password
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let errorMessage = errorJson?["error_description"] as? String ?? errorJson?["msg"] as? String ?? "Sign in failed"
                throw AuthError.customError(errorMessage)
            }
            
            try await handleAuthResponse(data: data)
        } catch let authError as AuthError {
            self.error = authError.message
        } catch {
            self.error = "Sign in failed: \(error.localizedDescription)"
        }
        
        isSigningIn = false
    }
    
    // MARK: - Sign Up with Email
    
    func signUpWithEmail(email: String, password: String, fullName: String) async {
        isSigningIn = true
        error = nil
        
        do {
            var request = URLRequest(url: URL(string: "\(supabaseUrl)/auth/v1/signup")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            
            let body: [String: Any] = [
                "email": email,
                "password": password,
                "data": ["full_name": fullName]
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let errorMessage = errorJson?["error_description"] as? String ?? errorJson?["msg"] as? String ?? "Sign up failed"
                throw AuthError.customError(errorMessage)
            }
            
            // Check if email confirmation is required
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let accessToken = json?["access_token"] as? String, !accessToken.isEmpty {
                try await handleAuthResponse(data: data)
            } else if json?["id"] != nil {
                // User created but email confirmation required
                throw AuthError.emailConfirmationRequired
            } else {
                throw AuthError.signInFailed
            }
        } catch let authError as AuthError {
            // For email confirmation, this is actually a success
            self.error = authError.message
        } catch {
            self.error = "Sign up failed: \(error.localizedDescription)"
        }
        
        isSigningIn = false
    }
    
    // MARK: - Sign In with Apple
    
    func signInWithApple(authorization: ASAuthorization) async {
        isSigningIn = true
        error = nil
        
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            self.error = "Failed to get Apple ID credential"
            isSigningIn = false
            return
        }
        
        do {
            var request = URLRequest(url: URL(string: "\(supabaseUrl)/auth/v1/token?grant_type=id_token")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            
            let body: [String: Any] = [
                "provider": "apple",
                "id_token": tokenString
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let errorMessage = errorJson?["error_description"] as? String ?? errorJson?["msg"] as? String ?? "Apple sign in failed"
                throw AuthError.customError(errorMessage)
            }
            
            try await handleAuthResponse(data: data)
        } catch let authError as AuthError {
            self.error = authError.message
        } catch {
            self.error = "Sign in failed: \(error.localizedDescription)"
        }
        
        isSigningIn = false
    }
    
    // MARK: - Sign In with Google (OAuth)
    
    func getGoogleSignInURL() -> URL? {
        var components = URLComponents(string: "\(supabaseUrl)/auth/v1/authorize")
        // Use the custom URL scheme for redirect
        let redirectURL = "roundcaddy://auth/callback"
        components?.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(name: "redirect_to", value: redirectURL)
        ]
        let url = components?.url
        print("Google OAuth URL: \(url?.absoluteString ?? "nil")")
        return url
    }
    
    func handleOAuthCallback(url: URL) async {
        isSigningIn = true
        error = nil
        
        print("OAuth callback received: \(url.absoluteString)")
        
        // Add timeout protection
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            if isSigningIn {
                await MainActor.run {
                    self.error = "Request timed out. Please try again."
                    self.isSigningIn = false
                }
            }
        }
        
        defer {
            timeoutTask.cancel()
        }
        
        // Parse the callback URL for tokens
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            self.error = "Invalid callback URL"
            isSigningIn = false
            return
        }
        
        // Try fragment first (Supabase typically uses #access_token=...)
        var params: [String: String] = [:]
        
        if let fragment = components.fragment {
            // Parse fragment (access_token=...&refresh_token=...&...)
        for param in fragment.split(separator: "&") {
            let pair = param.split(separator: "=", maxSplits: 1)
            if pair.count == 2 {
                    let key = String(pair[0])
                    let value = String(pair[1]).removingPercentEncoding ?? String(pair[1])
                    params[key] = value
                }
            }
        }
        
        // If no fragment, try query parameters
        if params.isEmpty, let queryItems = components.queryItems {
            for item in queryItems {
                if let value = item.value {
                    params[item.name] = value.removingPercentEncoding ?? value
                }
            }
        }
        
        print("Parsed OAuth params: \(params.keys.joined(separator: ", "))")
        
        if let accessToken = params["access_token"],
           let refreshToken = params["refresh_token"] {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            
            do {
                self.currentUser = try await fetchUser(token: accessToken)
                print("OAuth login successful")
            } catch {
                print("Failed to fetch user: \(error.localizedDescription)")
                self.error = "Failed to fetch user profile"
            }
        } else if let errorDescription = params["error_description"] {
            let decoded = errorDescription.removingPercentEncoding ?? errorDescription
            print("OAuth error: \(decoded)")
            self.error = decoded
        } else if let errorCode = params["error"] {
            let decoded = errorCode.removingPercentEncoding ?? errorCode
            print("OAuth error code: \(decoded)")
            self.error = "Authentication failed: \(decoded)"
        } else {
            print("OAuth callback missing tokens. Available params: \(params.keys.joined(separator: ", "))")
            self.error = "Authentication failed: No tokens received"
        }
        
        isSigningIn = false
    }
    
    // MARK: - Auth Response Handler
    
    private func handleAuthResponse(data: Data) async throws {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        self.accessToken = json?["access_token"] as? String
        self.refreshToken = json?["refresh_token"] as? String
        
        if let token = self.accessToken {
            self.currentUser = try await fetchUser(token: token)
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async {
        accessToken = nil
        refreshToken = nil
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: "access_token")
        UserDefaults.standard.removeObject(forKey: "refresh_token")
    }
    
    // MARK: - Demo Mode
    
    /// Set up demo mode for App Store screenshots
    func setupDemoUser(_ user: User) {
        self.currentUser = user
        self.isLoading = false
    }
    
    // MARK: - API Helpers
    
    func authenticatedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        return request
    }
    
    var authHeaders: [String: String] {
        var headers = ["apikey": supabaseKey]
        if let token = accessToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }
}

enum AuthError: Error {
    case invalidSession
    case refreshFailed
    case signInFailed
    case customError(String)
    case emailConfirmationRequired
    
    var message: String {
        switch self {
        case .invalidSession:
            return "Session expired. Please sign in again."
        case .refreshFailed:
            return "Failed to refresh session. Please sign in again."
        case .signInFailed:
            return "Sign in failed. Please try again."
        case .customError(let msg):
            return msg
        case .emailConfirmationRequired:
            return "✅ Check your email to confirm your account, then sign in."
        }
    }
    
    var isSuccess: Bool {
        switch self {
        case .emailConfirmationRequired:
            return true
        default:
            return false
        }
    }
}
