import Foundation
import CoreLocation

@MainActor
class RoundManager: ObservableObject {
    @Published var isRoundActive = false
    @Published var currentRound: Round?
    @Published var currentHole = 1
    @Published var holeScores: [HoleScore] = []
    @Published var shots: [Shot] = []
    @Published var selectedCourse: Course?
    @Published var isLoading = false
    @Published var error: String?
    
    // Watch sync callback - set by the view that has access to WatchSyncManager
    var onStateChanged: (() -> Void)?
    
    // Computed properties
    var totalScore: Int {
        holeScores.compactMap { $0.score }.reduce(0, +)
    }
    
    var totalPutts: Int {
        holeScores.compactMap { $0.putts }.reduce(0, +)
    }
    
    var fairwaysHit: Int {
        holeScores.filter { $0.fairwayHit == true }.count
    }
    
    var greensInRegulation: Int {
        holeScores.filter { $0.gir == true }.count
    }
    
    var currentHoleScore: HoleScore? {
        holeScores.first { $0.holeNumber == currentHole }
    }
    
    private let supabaseUrl = "https://kanvhqwrfkzqktuvpxnp.supabase.co"
    private let supabaseKey = "sb_publishable_JftEdMATFsi78Ba8rIFObg_tpOeIS2J"
    
    // MARK: - Round Lifecycle
    
    func startRound(course: Course? = nil) {
        selectedCourse = course
        isRoundActive = true
        currentHole = 1
        shots = []
        
        // Initialize hole scores with course pars if available
        holeScores = (1...18).map { hole in
            let par = course?.holeData?.first { $0.holeNumber == hole }?.par ?? 4
            return HoleScore(holeNumber: hole, par: par)
        }
    }
    
    func endRound() {
        isRoundActive = false
    }
    
    // MARK: - Hole Navigation
    
    func nextHole() {
        if currentHole < 18 {
            currentHole += 1
            onStateChanged?()
        }
    }
    
    func previousHole() {
        if currentHole > 1 {
            currentHole -= 1
            onStateChanged?()
        }
    }
    
    func goToHole(_ hole: Int) {
        guard hole >= 1 && hole <= 18 else { return }
        currentHole = hole
        onStateChanged?()
    }
    
    // MARK: - Score Entry
    
    func updateScore(_ score: Int) {
        guard let index = holeScores.firstIndex(where: { $0.holeNumber == currentHole }) else { return }
        holeScores[index].score = score
        onStateChanged?()
    }
    
    func updatePutts(_ putts: Int) {
        guard let index = holeScores.firstIndex(where: { $0.holeNumber == currentHole }) else { return }
        holeScores[index].putts = putts
        onStateChanged?()
    }
    
    func toggleFairway() {
        guard let index = holeScores.firstIndex(where: { $0.holeNumber == currentHole }) else { return }
        holeScores[index].fairwayHit = !(holeScores[index].fairwayHit ?? false)
        onStateChanged?()
    }
    
    func toggleGIR() {
        guard let index = holeScores.firstIndex(where: { $0.holeNumber == currentHole }) else { return }
        holeScores[index].gir = !(holeScores[index].gir ?? false)
        onStateChanged?()
    }
    
    func incrementScore() {
        guard let index = holeScores.firstIndex(where: { $0.holeNumber == currentHole }) else { return }
        let current = holeScores[index].score ?? holeScores[index].par
        holeScores[index].score = current + 1
        onStateChanged?()
    }
    
    func decrementScore() {
        guard let index = holeScores.firstIndex(where: { $0.holeNumber == currentHole }) else { return }
        let current = holeScores[index].score ?? holeScores[index].par
        if current > 1 {
            holeScores[index].score = current - 1
            onStateChanged?()
        }
    }
    
    // MARK: - Apply Watch Updates
    
    func applyWatchUpdate(_ message: [String: Any]) {
        if let hole = message["currentHole"] as? Int {
            currentHole = hole
        }
        if let scores = message["scores"] as? [[String: Any]] {
            for scoreData in scores {
                if let holeNumber = scoreData["holeNumber"] as? Int,
                   let index = holeScores.firstIndex(where: { $0.holeNumber == holeNumber }) {
                    if let score = scoreData["score"] as? Int {
                        holeScores[index].score = score
                    }
                    if let putts = scoreData["putts"] as? Int {
                        holeScores[index].putts = putts
                    }
                    if let fw = scoreData["fairwayHit"] as? Bool {
                        holeScores[index].fairwayHit = fw
                    }
                    if let gir = scoreData["gir"] as? Bool {
                        holeScores[index].gir = gir
                    }
                }
            }
        }
    }
    
    // MARK: - Shot Tracking
    
    func addShot(club: ClubType?, location: CLLocationCoordinate2D?) {
        let shotNumber = shots.filter { $0.holeNumber == currentHole }.count + 1
        let shot = Shot(
            id: UUID().uuidString,
            roundId: currentRound?.id ?? "",
            holeNumber: currentHole,
            shotNumber: shotNumber,
            club: club?.rawValue,
            latitude: location?.latitude,
            longitude: location?.longitude,
            distanceToPin: nil,
            lie: nil,
            result: nil,
            timestamp: Date()
        )
        shots.append(shot)
    }
    
    func shotsForCurrentHole() -> [Shot] {
        shots.filter { $0.holeNumber == currentHole }
    }
    
    // MARK: - Save Round
    
    func saveRound(userId: String, authHeaders: [String: String]) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        let roundData: [String: Any] = [
            "user_id": userId,
            "course_name": selectedCourse?.name ?? "Unknown Course",
            "played_at": ISO8601DateFormatter().string(from: Date()).prefix(10).description,
            "total_score": totalScore,
            "total_putts": totalPutts,
            "fairways_hit": fairwaysHit,
            "fairways_total": holeScores.filter { $0.par > 3 }.count,
            "gir": greensInRegulation,
            "penalties": holeScores.compactMap { $0.penalties }.reduce(0, +),
            "course_rating": selectedCourse?.courseRating as Any,
            "slope_rating": selectedCourse?.slopeRating as Any,
            "scoring_format": "stroke"
        ]
        
        var request = URLRequest(url: URL(string: "\(supabaseUrl)/rest/v1/rounds")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: roundData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw RoundError.saveFailed(errorBody)
        }
        
        // Parse the created round
        if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let roundJson = json.first {
            // Round saved successfully
            print("Round saved: \(roundJson["id"] ?? "")")
        }
        
        endRound()
    }
}

enum RoundError: Error, LocalizedError {
    case saveFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let message):
            return "Failed to save round: \(message)"
        }
    }
}
