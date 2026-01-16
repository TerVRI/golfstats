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
    @Published var clubBag: [String] = RoundManager.defaultClubs
    @Published var roundStartTime: Date?
    @Published var lastSyncedToPhone: Date?
    
    private var wcSession: WCSession?
    private let clubBagKey = "syncedClubBag"
    private let roundStateKey = "cachedRoundState"
    
    static let defaultClubs = ["Driver", "3W", "5W", "4i", "5i", "6i", "7i", "8i", "9i", "PW", "SW", "Putter"]
    
    override init() {
        super.init()
        loadSavedBag()
        initializeHoles()
        restoreCachedRound()
        setupWatchConnectivity()
    }
    
    private func loadSavedBag() {
        if let savedClubs = UserDefaults.standard.stringArray(forKey: clubBagKey) {
            clubBag = savedClubs
        }
    }
    
    private func saveBag() {
        UserDefaults.standard.set(clubBag, forKey: clubBagKey)
    }
    
    // MARK: - Round State Persistence
    
    private func cacheRoundState() {
        guard isRoundActive else {
            // Clear cache if round is not active
            UserDefaults.standard.removeObject(forKey: roundStateKey)
            return
        }
        
        let state: [String: Any] = [
            "isRoundActive": isRoundActive,
            "currentHole": currentHole,
            "courseName": courseName,
            "totalScore": totalScore,
            "roundStartTime": roundStartTime?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
            "holeScores": holeScores.map { hole -> [String: Any] in
                var dict: [String: Any] = [
                    "holeNumber": hole.holeNumber,
                    "par": hole.par
                ]
                if let score = hole.score { dict["score"] = score }
                if let putts = hole.putts { dict["putts"] = putts }
                if let fw = hole.fairwayHit { dict["fairwayHit"] = fw }
                if let gir = hole.gir { dict["gir"] = gir }
                return dict
            },
            "shots": shots.map { shot -> [String: Any] in
                [
                    "id": shot.id.uuidString,
                    "holeNumber": shot.holeNumber,
                    "shotNumber": shot.shotNumber,
                    "club": shot.club ?? "",
                    "latitude": shot.latitude,
                    "longitude": shot.longitude,
                    "timestamp": shot.timestamp.timeIntervalSince1970
                ]
            },
            "cachedAt": Date().timeIntervalSince1970
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: state) {
            UserDefaults.standard.set(data, forKey: roundStateKey)
        }
    }
    
    private func restoreCachedRound() {
        guard let data = UserDefaults.standard.data(forKey: roundStateKey),
              let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let wasActive = state["isRoundActive"] as? Bool,
              wasActive else {
            return
        }
        
        // Restore round state
        isRoundActive = true
        
        if let hole = state["currentHole"] as? Int {
            currentHole = hole
        }
        if let name = state["courseName"] as? String {
            courseName = name
        }
        if let startTime = state["roundStartTime"] as? TimeInterval {
            roundStartTime = Date(timeIntervalSince1970: startTime)
        }
        
        // Restore hole scores
        if let scoresData = state["holeScores"] as? [[String: Any]] {
            for scoreData in scoresData {
                if let holeNumber = scoreData["holeNumber"] as? Int,
                   let index = holeScores.firstIndex(where: { $0.holeNumber == holeNumber }) {
                    if let par = scoreData["par"] as? Int {
                        holeScores[index].par = par
                    }
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
        
        // Restore shots
        if let shotsData = state["shots"] as? [[String: Any]] {
            shots = shotsData.compactMap { shotData -> Shot? in
                guard let idString = shotData["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let holeNumber = shotData["holeNumber"] as? Int,
                      let shotNumber = shotData["shotNumber"] as? Int,
                      let lat = shotData["latitude"] as? Double,
                      let lon = shotData["longitude"] as? Double,
                      let timestamp = shotData["timestamp"] as? TimeInterval else {
                    return nil
                }
                return Shot(
                    id: id,
                    holeNumber: holeNumber,
                    shotNumber: shotNumber,
                    club: shotData["club"] as? String,
                    latitude: lat,
                    longitude: lon,
                    timestamp: Date(timeIntervalSince1970: timestamp)
                )
            }
        }
        
        calculateTotalScore()
        
        print("Restored cached round: \(courseName), Hole \(currentHole), Score \(totalScore)")
    }
    
    func clearCachedRound() {
        UserDefaults.standard.removeObject(forKey: roundStateKey)
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
        roundStartTime = Date()
        
        // Cache locally and notify iPhone
        cacheRoundState()
        sendRoundStateToPhone()
    }
    
    func endRound() {
        // Calculate stats before clearing
        let playedHoles = holeScores.filter { $0.score != nil }
        let totalPar = playedHoles.reduce(0) { $0 + $1.par }
        let totalFairways = holeScores.filter { $0.fairwayHit == true }.count
        let totalGIR = holeScores.filter { $0.gir == true }.count
        let totalPutts = holeScores.compactMap { $0.putts }.reduce(0, +)
        
        // Send final round data to iPhone
        let roundData: [String: Any] = [
            "action": "roundEnded",
            "courseName": courseName,
            "roundStartTime": roundStartTime?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
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
            "totalPar": totalPar,
            "holesPlayed": playedHoles.count,
            "fairwaysHit": totalFairways,
            "gir": totalGIR,
            "totalPutts": totalPutts,
            "shots": shots.map { shot in
                [
                    "holeNumber": shot.holeNumber,
                    "shotNumber": shot.shotNumber,
                    "club": shot.club ?? "",
                    "latitude": shot.latitude,
                    "longitude": shot.longitude
                ]
            },
            "timestamp": Date().timeIntervalSince1970
        ]
        sendMessageToPhone(roundData)
        
        // Clear local state and cache after sending
        isRoundActive = false
        roundStartTime = nil
        clearCachedRound()
    }
    
    func discardRound() {
        isRoundActive = false
        currentHole = 1
        initializeHoles()
        shots = []
        totalScore = 0
        roundStartTime = nil
        
        // Clear cached data
        clearCachedRound()
        
        // Notify iPhone that round was discarded
        sendMessageToPhone([
            "action": "roundDiscarded",
            "timestamp": Date().timeIntervalSince1970
        ])
    }
    
    func updateScore(for hole: Int, score: Int) {
        guard let index = holeScores.firstIndex(where: { $0.holeNumber == hole }) else { return }
        holeScores[index].score = score
        calculateTotalScore()
        
        // Send real-time update to iPhone
        sendRoundStateToPhone()
    }
    
    func updatePutts(for hole: Int, putts: Int) {
        guard let index = holeScores.firstIndex(where: { $0.holeNumber == hole }) else { return }
        holeScores[index].putts = putts
        
        // Send real-time update to iPhone
        sendRoundStateToPhone()
    }
    
    func updateFairway(for hole: Int, hit: Bool) {
        guard let index = holeScores.firstIndex(where: { $0.holeNumber == hole }) else { return }
        holeScores[index].fairwayHit = hit
        
        // Send real-time update to iPhone
        sendRoundStateToPhone()
    }
    
    func updateGIR(for hole: Int, hit: Bool) {
        guard let index = holeScores.firstIndex(where: { $0.holeNumber == hole }) else { return }
        holeScores[index].gir = hit
        
        // Send real-time update to iPhone
        sendRoundStateToPhone()
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
        
        // Cache and sync full state (includes shots)
        sendRoundStateToPhone()
        
        // Also send specific shot event for immediate notification
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
            sendRoundStateToPhone()
        }
    }
    
    func previousHole() {
        if currentHole > 1 {
            currentHole -= 1
            sendRoundStateToPhone()
        }
    }
    
    // MARK: - Real-time Sync
    
    private func sendRoundStateToPhone() {
        // Always cache locally first
        cacheRoundState()
        
        let stateData: [String: Any] = [
            "action": "roundStateUpdate",
            "isRoundActive": isRoundActive,
            "currentHole": currentHole,
            "courseName": courseName,
            "totalScore": totalScore,
            "roundStartTime": roundStartTime?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
            "scores": holeScores.map { hole -> [String: Any] in
                [
                    "holeNumber": hole.holeNumber,
                    "par": hole.par,
                    "score": hole.score as Any,
                    "putts": hole.putts as Any,
                    "fairwayHit": hole.fairwayHit as Any,
                    "gir": hole.gir as Any
                ]
            },
            "shots": shots.map { shot in
                [
                    "holeNumber": shot.holeNumber,
                    "shotNumber": shot.shotNumber,
                    "club": shot.club ?? "",
                    "latitude": shot.latitude,
                    "longitude": shot.longitude
                ]
            },
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if sendMessageToPhone(stateData) {
            lastSyncedToPhone = Date()
        }
    }
    
    /// Force resync - call when connection is restored
    func resyncToPhone() {
        guard isRoundActive else { return }
        sendRoundStateToPhone()
    }
    
    private func calculateTotalScore() {
        totalScore = holeScores.compactMap { $0.score }.reduce(0, +)
    }
    
    @discardableResult
    private func sendMessageToPhone(_ message: [String: Any]) -> Bool {
        guard let session = wcSession, session.isReachable else {
            // If not reachable, try to use transferUserInfo for important data
            if let action = message["action"] as? String, 
               action == "roundEnded" || action == "roundStateUpdate" {
                wcSession?.transferUserInfo(message)
            }
            return false
        }
        session.sendMessage(message, replyHandler: nil) { error in
            print("Error sending message: \(error.localizedDescription)")
        }
        return true
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation error: \(error.localizedDescription)")
        } else if activationState == .activated {
            // Connection restored - resync if we have an active round
            DispatchQueue.main.async {
                self.resyncToPhone()
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            // Connection restored - resync cached round data
            DispatchQueue.main.async {
                print("Watch connectivity restored - resyncing round data")
                self.resyncToPhone()
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.handleMessage(message)
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        DispatchQueue.main.async {
            self.handleMessage(userInfo)
        }
    }
    
    private func handleMessage(_ message: [String: Any]) {
        if let action = message["action"] as? String {
            switch action {
            case "setCourse":
                if let name = message["courseName"] as? String {
                    self.courseName = name
                }
                if let pars = message["pars"] as? [Int] {
                    for (index, par) in pars.enumerated() where index < self.holeScores.count {
                        self.holeScores[index].par = par
                    }
                }
            case "setHolePars":
                if let pars = message["pars"] as? [Int] {
                    for (index, par) in pars.enumerated() where index < self.holeScores.count {
                        self.holeScores[index].par = par
                    }
                }
            case "setBag":
                if let clubs = message["clubs"] as? [String], !clubs.isEmpty {
                    self.clubBag = clubs
                    self.saveBag()
                }
            case "startRound":
                // iPhone started a round - sync to watch
                if !self.isRoundActive {
                    self.startRound()
                }
                if let name = message["courseName"] as? String {
                    self.courseName = name
                }
            case "endRound":
                // iPhone ended the round - sync to watch
                self.isRoundActive = false
                self.currentHole = 1
                self.initializeHoles()
                self.shots = []
                self.totalScore = 0
            case "roundStateUpdate":
                // iPhone sent a state update - apply it
                self.applyStateFromPhone(message)
            default:
                break
            }
        }
    }
    
    private func applyStateFromPhone(_ state: [String: Any]) {
        if let isActive = state["isRoundActive"] as? Bool {
            self.isRoundActive = isActive
        }
        if let hole = state["currentHole"] as? Int {
            self.currentHole = hole
        }
        if let name = state["courseName"] as? String {
            self.courseName = name
        }
        if let scores = state["scores"] as? [[String: Any]] {
            for scoreData in scores {
                if let holeNumber = scoreData["holeNumber"] as? Int,
                   let index = self.holeScores.firstIndex(where: { $0.holeNumber == holeNumber }) {
                    if let par = scoreData["par"] as? Int {
                        self.holeScores[index].par = par
                    }
                    if let score = scoreData["score"] as? Int {
                        self.holeScores[index].score = score
                    }
                    if let putts = scoreData["putts"] as? Int {
                        self.holeScores[index].putts = putts
                    }
                    if let fw = scoreData["fairwayHit"] as? Bool {
                        self.holeScores[index].fairwayHit = fw
                    }
                    if let gir = scoreData["gir"] as? Bool {
                        self.holeScores[index].gir = gir
                    }
                }
            }
            self.calculateTotalScore()
        }
    }
}
