import Foundation
import WatchConnectivity
import Combine

struct HoleScore: Identifiable, Codable {
    var id: Int { holeNumber }
    var holeNumber: Int
    var par: Int
    var score: Int?
    var putts: Int?
    var fairwayHit: Bool?
    var gir: Bool?
}

struct Shot: Identifiable, Codable {
    let id: UUID
    let holeNumber: Int
    let shotNumber: Int
    let club: String?
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}

class RoundManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isRoundActive = false
    @Published var currentHole = 1
    @Published var holeScores: [HoleScore] = []
    @Published var shots: [Shot] = []
    @Published var totalScore: Int = 0
    @Published var courseName: String = "Unknown Course"
    
    private var wcSession: WCSession?
    
    override init() {
        super.init()
        setupWatchConnectivity()
        initializeHoles()
    }
    
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            wcSession = WCSession.default
            wcSession?.delegate = self
            wcSession?.activate()
        }
    }
    
    private func initializeHoles() {
        holeScores = (1...18).map { hole in
            HoleScore(
                holeNumber: hole,
                par: 4, // Default, should come from course data
                score: nil,
                putts: nil,
                fairwayHit: nil,
                gir: nil
            )
        }
    }
    
    func startRound() {
        isRoundActive = true
        currentHole = 1
        initializeHoles()
        shots = []
        totalScore = 0
        
        // Notify iPhone app
        sendMessageToPhone(["action": "roundStarted", "timestamp": Date().timeIntervalSince1970])
    }
    
    func endRound() {
        isRoundActive = false
        
        // Send final round data to iPhone
        let roundData: [String: Any] = [
            "action": "roundEnded",
            "scores": holeScores.compactMap { hole -> [String: Any]? in
                guard let score = hole.score else { return nil }
                return [
                    "holeNumber": hole.holeNumber,
                    "par": hole.par,
                    "score": score,
                    "putts": hole.putts ?? 0,
                    "fairwayHit": hole.fairwayHit ?? false,
                    "gir": hole.gir ?? false
                ]
            },
            "totalScore": totalScore,
            "timestamp": Date().timeIntervalSince1970
        ]
        sendMessageToPhone(roundData)
    }
    
    func updateScore(for hole: Int, score: Int) {
        guard let index = holeScores.firstIndex(where: { $0.holeNumber == hole }) else { return }
        holeScores[index].score = score
        calculateTotalScore()
        
        // Sync with iPhone
        sendMessageToPhone([
            "action": "scoreUpdate",
            "hole": hole,
            "score": score
        ])
    }
    
    func updatePutts(for hole: Int, putts: Int) {
        guard let index = holeScores.firstIndex(where: { $0.holeNumber == hole }) else { return }
        holeScores[index].putts = putts
    }
    
    func updateFairway(for hole: Int, hit: Bool) {
        guard let index = holeScores.firstIndex(where: { $0.holeNumber == hole }) else { return }
        holeScores[index].fairwayHit = hit
    }
    
    func updateGIR(for hole: Int, hit: Bool) {
        guard let index = holeScores.firstIndex(where: { $0.holeNumber == hole }) else { return }
        holeScores[index].gir = hit
    }
    
    func addShot(holeNumber: Int, club: String?, latitude: Double, longitude: Double) {
        let shotNumber = shots.filter { $0.holeNumber == holeNumber }.count + 1
        let shot = Shot(
            id: UUID(),
            holeNumber: holeNumber,
            shotNumber: shotNumber,
            club: club,
            latitude: latitude,
            longitude: longitude,
            timestamp: Date()
        )
        shots.append(shot)
        
        // Sync with iPhone
        sendMessageToPhone([
            "action": "shotAdded",
            "hole": holeNumber,
            "shot": shotNumber,
            "club": club ?? "",
            "lat": latitude,
            "lon": longitude
        ])
    }
    
    func nextHole() {
        if currentHole < 18 {
            currentHole += 1
        }
    }
    
    func previousHole() {
        if currentHole > 1 {
            currentHole -= 1
        }
    }
    
    private func calculateTotalScore() {
        totalScore = holeScores.compactMap { $0.score }.reduce(0, +)
    }
    
    private func sendMessageToPhone(_ message: [String: Any]) {
        guard let session = wcSession, session.isReachable else { return }
        session.sendMessage(message, replyHandler: nil) { error in
            print("Error sending message: \(error.localizedDescription)")
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation error: \(error.localizedDescription)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let action = message["action"] as? String {
                switch action {
                case "setCourse":
                    if let name = message["courseName"] as? String {
                        self.courseName = name
                    }
                case "setHolePars":
                    if let pars = message["pars"] as? [Int] {
                        for (index, par) in pars.enumerated() where index < self.holeScores.count {
                            self.holeScores[index].par = par
                        }
                    }
                default:
                    break
                }
            }
        }
    }
}
