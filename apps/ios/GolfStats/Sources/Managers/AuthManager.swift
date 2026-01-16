import Foundation
import AuthenticationServices
import CryptoKit

@MainActor
class AuthManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = true
    @Published var error: String?
    
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
    
    // MARK: - Sign In with Apple
    
    func signInWithApple(authorization: ASAuthorization) async {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            self.error = "Failed to get Apple ID credential"
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
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw AuthError.signInFailed
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            self.accessToken = json?["access_token"] as? String
            self.refreshToken = json?["refresh_token"] as? String
            
            if let token = self.accessToken {
                self.currentUser = try await fetchUser(token: token)
            }
        } catch {
            self.error = "Sign in failed: \(error.localizedDescription)"
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
}
