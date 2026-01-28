import Foundation
import WatchConnectivity

class WatchSyncManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isWatchConnected = false
    @Published var isWatchAppInstalled = false
    @Published var watchRoundActive = false
    @Published var watchCurrentHole = 1
    @Published var watchTotalScore = 0
    @Published var watchHoleScores: [[String: Any]] = []
    @Published var lastWatchUpdate: Date?
    
    // MARK: - Swing Analytics Data from Watch
    @Published var recentSwings: [SwingRecord] = []
    @Published var clubDistances: [ClubDistanceStats] = []
    @Published var coachingTips: [WatchCoachingTip] = []
    @Published var currentSessionSummary: SwingSessionSummary?
    @Published var liveSwingMetrics: LiveSwingMetrics?
    @Published var watchStrokesGained: WatchStrokesGained?
    
    private var session: WCSession?
    weak var gpsManager: GPSManager?
    private var lastLocationSentAt: Date?
    
    // Persistence keys
    private let clubDistancesKey = "watchClubDistances"
    private let swingHistoryKey = "watchSwingHistory"
    
    override init() {
        super.init()
        
        // Load persisted data
        loadPersistedData()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func attachGPSManager(_ manager: GPSManager) {
        gpsManager = manager
    }
    
    // MARK: - Persistence
    
    private func loadPersistedData() {
        // Load club distances
        if let data = UserDefaults.standard.data(forKey: clubDistancesKey),
           let distances = try? JSONDecoder().decode([ClubDistanceStats].self, from: data) {
            clubDistances = distances
        }
        
        // Load recent swings (last 50)
        if let data = UserDefaults.standard.data(forKey: swingHistoryKey),
           let swings = try? JSONDecoder().decode([SwingRecord].self, from: data) {
            recentSwings = Array(swings.prefix(50))
        }
    }
    
    private func persistClubDistances() {
        if let data = try? JSONEncoder().encode(clubDistances) {
            UserDefaults.standard.set(data, forKey: clubDistancesKey)
        }
    }
    
    private func persistSwingHistory() {
        let toSave = Array(recentSwings.prefix(50))
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: swingHistoryKey)
        }
    }
    
    /// Reset all learned club distances
    func resetClubDistances() {
        clubDistances = []
        UserDefaults.standard.removeObject(forKey: clubDistancesKey)
        
        // Notify watch to also clear its club distance data
        guard let session = session, session.activationState == .activated else { return }
        
        let message: [String: Any] = [
            "action": "resetClubDistances"
        ]
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("Error sending reset to watch: \(error.localizedDescription)")
            }
        } else {
            session.transferUserInfo(message)
        }
    }
    
    // MARK: - Send Data to Watch
    
    func sendCourseToWatch(course: Course) {
        guard let session = session, session.activationState == .activated, session.isReachable else { return }
        
        var message: [String: Any] = [
            "action": "setCourse",
            "courseName": course.name
        ]
        
        if let holeData = course.holeData {
            let pars = holeData.sorted { $0.holeNumber < $1.holeNumber }.map { $0.par }
            message["pars"] = pars
            
            // Send green locations for each hole
            let greenLocations = holeData.compactMap { hole -> [String: Any]? in
                guard let center = hole.greenCenter else { return nil }
                return [
                    "hole": hole.holeNumber,
                    "center": ["lat": center.lat, "lon": center.lon],
                    "front": hole.greenFront.map { ["lat": $0.lat, "lon": $0.lon] } as Any,
                    "back": hole.greenBack.map { ["lat": $0.lat, "lon": $0.lon] } as Any
                ]
            }
            message["greenLocations"] = greenLocations
        }
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("Error sending course to watch: \(error.localizedDescription)")
        }
    }
    
    func sendRoundStart() {
        guard let session = session, session.activationState == .activated, session.isReachable else { return }
        
        let message: [String: Any] = [
            "action": "startRound",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }
    
    func sendRoundEnd() {
        guard let session = session, session.activationState == .activated else { return }
        
        let message: [String: Any] = [
            "action": "endRound",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }
    
    func sendScoreUpdate(hole: Int, score: Int) {
        guard let session = session, session.activationState == .activated, session.isReachable else { return }
        
        let message: [String: Any] = [
            "action": "scoreUpdate",
            "hole": hole,
            "score": score
        ]
        
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }
    
    func sendBagToWatch(clubs: [String]) {
        guard let session = session, session.activationState == .activated else { return }
        
        let message: [String: Any] = [
            "action": "setBag",
            "clubs": clubs
        ]
        
        // Use transferUserInfo for non-urgent data that should persist
        // This ensures the watch receives it even if not currently reachable
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("Error sending bag to watch: \(error.localizedDescription)")
                // Fall back to transferUserInfo
                if session.activationState == .activated {
                session.transferUserInfo(message)
                }
            }
        } else if session.activationState == .activated {
            session.transferUserInfo(message)
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchConnected = activationState == .activated
            self.isWatchAppInstalled = session.isWatchAppInstalled
            if activationState == .activated && session.isReachable {
                self.sendPhoneLocationUpdate(reason: "activation")
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchConnected = false
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate session for new watch
        session.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchConnected = session.isReachable
            if session.isReachable {
                self.sendPhoneLocationUpdate(reason: "reachability")
            }
        }
    }

    private func sendPhoneLocationUpdate(reason: String) {
        guard let session = session,
              session.activationState == .activated,
              session.isReachable,
              let location = gpsManager?.currentLocation else {
            return
        }
        
        if let lastSent = lastLocationSentAt,
           Date().timeIntervalSince(lastSent) < 15 {
            return
        }
        lastLocationSentAt = Date()
        
        let message: [String: Any] = [
            "action": "phoneLocationUpdate",
            "lat": location.coordinate.latitude,
            "lon": location.coordinate.longitude,
            "timestamp": Date().timeIntervalSince1970,
            "reason": reason
        ]
        
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.handleWatchMessage(message)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            self.handleWatchMessage(message)
            replyHandler(["status": "received"])
        }
    }
    
    private func handleWatchMessage(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        
        switch action {
        case "roundStarted":
            NotificationCenter.default.post(name: .watchRoundStarted, object: nil, userInfo: message)
            
        case "roundEnded":
            watchRoundActive = false
            NotificationCenter.default.post(name: .watchRoundEnded, object: nil, userInfo: message)
            
        case "roundDiscarded":
            watchRoundActive = false
            watchHoleScores = []
            watchTotalScore = 0
            watchCurrentHole = 1
            NotificationCenter.default.post(name: .watchRoundDiscarded, object: nil, userInfo: message)
            
        case "roundStateUpdate":
            // Real-time state update from watch
            if let isActive = message["isRoundActive"] as? Bool {
                watchRoundActive = isActive
            }
            if let hole = message["currentHole"] as? Int {
                watchCurrentHole = hole
            }
            if let score = message["totalScore"] as? Int {
                watchTotalScore = score
            }
            if let scores = message["scores"] as? [[String: Any]] {
                watchHoleScores = scores
            }
            lastWatchUpdate = Date()
            NotificationCenter.default.post(name: .watchRoundStateUpdate, object: nil, userInfo: message)
            
        case "scoreUpdate":
            NotificationCenter.default.post(name: .watchScoreUpdate, object: nil, userInfo: message)
            
        case "shotAdded":
            NotificationCenter.default.post(name: .watchShotAdded, object: nil, userInfo: message)
            
        // MARK: - Swing Analytics Messages
            
        case "swingDetected":
            handleSwingDetected(message)
            
        case "liveSwingMetrics":
            handleLiveSwingMetrics(message)
            
        case "clubDistanceUpdate":
            handleClubDistanceUpdate(message)
            
        case "coachingTip":
            handleCoachingTip(message)
            
        case "sessionSummary":
            handleSessionSummary(message)
            
        case "strokesGainedUpdate":
            handleStrokesGainedUpdate(message)
            
        default:
            break
        }
    }
    
    // MARK: - Swing Analytics Handlers
    
    private func handleSwingDetected(_ message: [String: Any]) {
        let swing = SwingRecord(
            id: message["id"] as? String ?? UUID().uuidString,
            timestamp: Date(timeIntervalSince1970: message["timestamp"] as? Double ?? Date().timeIntervalSince1970),
            club: message["club"] as? String,
            distance: message["distance"] as? Int,
            tempo: message["tempo"] as? Double,
            peakHandSpeed: message["peakHandSpeed"] as? Double,
            impactQuality: message["impactQuality"] as? Double,
            swingPath: (message["swingPath"] as? String).flatMap { SwingPath(rawValue: $0) },
            peakGForce: message["peakGForce"] as? Double,
            peakRotationRate: message["peakRotationRate"] as? Double
        )
        
        DispatchQueue.main.async {
            self.recentSwings.insert(swing, at: 0)
            if self.recentSwings.count > 100 {
                self.recentSwings = Array(self.recentSwings.prefix(100))
            }
            self.persistSwingHistory()
            NotificationCenter.default.post(name: .watchSwingDetected, object: nil, userInfo: ["swing": swing])
        }
    }
    
    private func handleLiveSwingMetrics(_ message: [String: Any]) {
        let metrics = LiveSwingMetrics(
            tempo: message["tempo"] as? Double,
            backswingTime: message["backswingTime"] as? Double,
            downswingTime: message["downswingTime"] as? Double,
            peakHandSpeed: message["peakHandSpeed"] as? Double,
            impactQuality: message["impactQuality"] as? Double,
            swingPath: (message["swingPath"] as? String).flatMap { SwingPath(rawValue: $0) },
            isSwingInProgress: message["isSwingInProgress"] as? Bool ?? false
        )
        
        DispatchQueue.main.async {
            self.liveSwingMetrics = metrics
            NotificationCenter.default.post(name: .watchLiveSwingMetrics, object: nil, userInfo: ["metrics": metrics])
        }
    }
    
    private func handleClubDistanceUpdate(_ message: [String: Any]) {
        guard let club = message["club"] as? String else { return }
        
        let stats = ClubDistanceStats(
            club: club,
            averageDistance: message["averageDistance"] as? Int ?? 0,
            minDistance: message["minDistance"] as? Int ?? 0,
            maxDistance: message["maxDistance"] as? Int ?? 0,
            shotCount: message["shotCount"] as? Int ?? 0,
            consistencyScore: message["consistencyScore"] as? Double ?? 0,
            lastUpdated: Date()
        )
        
        DispatchQueue.main.async {
            if let index = self.clubDistances.firstIndex(where: { $0.club == club }) {
                self.clubDistances[index] = stats
            } else {
                self.clubDistances.append(stats)
            }
            // Sort by typical club order
            self.clubDistances.sort { self.clubSortOrder($0.club) < self.clubSortOrder($1.club) }
            self.persistClubDistances()
            NotificationCenter.default.post(name: .watchClubDistanceUpdate, object: nil, userInfo: ["stats": stats])
        }
    }
    
    private func handleCoachingTip(_ message: [String: Any]) {
        guard let title = message["title"] as? String,
              let tipMessage = message["message"] as? String else { return }
        
        let categoryString = message["category"] as? String ?? "general"
        let category = WatchCoachingTip.TipCategory(rawValue: categoryString) ?? .general
        
        let tip = WatchCoachingTip(
            id: message["id"] as? String ?? UUID().uuidString,
            category: category,
            title: title,
            message: tipMessage,
            priority: message["priority"] as? Int ?? 2,
            timestamp: Date()
        )
        
        DispatchQueue.main.async {
            // Keep only recent tips (last 20)
            self.coachingTips.insert(tip, at: 0)
            if self.coachingTips.count > 20 {
                self.coachingTips = Array(self.coachingTips.prefix(20))
            }
            NotificationCenter.default.post(name: .watchCoachingTip, object: nil, userInfo: ["tip": tip])
        }
    }
    
    private func handleSessionSummary(_ message: [String: Any]) {
        let tips: [WatchCoachingTip] = (message["tips"] as? [[String: Any]] ?? []).compactMap { tipDict in
            guard let title = tipDict["title"] as? String,
                  let tipMessage = tipDict["message"] as? String else { return nil }
            let categoryString = tipDict["category"] as? String ?? "general"
            return WatchCoachingTip(
                category: WatchCoachingTip.TipCategory(rawValue: categoryString) ?? .general,
                title: title,
                message: tipMessage,
                priority: tipDict["priority"] as? Int ?? 2
            )
        }
        
        let summary = SwingSessionSummary(
            id: message["id"] as? String ?? UUID().uuidString,
            roundId: message["roundId"] as? String,
            date: Date(timeIntervalSince1970: message["timestamp"] as? Double ?? Date().timeIntervalSince1970),
            totalSwings: message["totalSwings"] as? Int ?? 0,
            totalPutts: message["totalPutts"] as? Int ?? 0,
            averageTempo: message["averageTempo"] as? Double,
            averageHandSpeed: message["averageHandSpeed"] as? Double,
            bestImpactQuality: message["bestImpactQuality"] as? Double,
            clubsUsed: message["clubsUsed"] as? [String] ?? [],
            tips: tips
        )
        
        DispatchQueue.main.async {
            self.currentSessionSummary = summary
            NotificationCenter.default.post(name: .watchSessionSummary, object: nil, userInfo: ["summary": summary])
        }
    }
    
    private func handleStrokesGainedUpdate(_ message: [String: Any]) {
        let sg = WatchStrokesGained(
            offTee: message["offTee"] as? Double ?? 0,
            approach: message["approach"] as? Double ?? 0,
            aroundGreen: message["aroundGreen"] as? Double ?? 0,
            putting: message["putting"] as? Double ?? 0
        )
        
        DispatchQueue.main.async {
            self.watchStrokesGained = sg
            NotificationCenter.default.post(name: .watchStrokesGainedUpdate, object: nil, userInfo: ["strokesGained": sg])
        }
    }
    
    private func clubSortOrder(_ club: String) -> Int {
        let order = ["Driver", "3W", "5W", "7W", "2H", "3H", "4H", "5H",
                     "2i", "3i", "4i", "5i", "6i", "7i", "8i", "9i",
                     "PW", "GW", "52°", "54°", "SW", "56°", "58°", "LW", "60°", "Putter"]
        return order.firstIndex(of: club) ?? 99
    }
    
    // MARK: - Send Round State to Watch
    
    func sendRoundStateToWatch(isActive: Bool, currentHole: Int, courseName: String, holeScores: [HoleScore]) {
        guard let session = session, session.activationState == .activated, session.isReachable else { return }
        
        // Build scores array, only including non-nil values (WCSession doesn't support NSNull)
        let scoresData = holeScores.map { hole -> [String: Any] in
            var dict: [String: Any] = [
                "holeNumber": hole.holeNumber,
                "par": hole.par
            ]
            if let score = hole.score { dict["score"] = score }
            if let putts = hole.putts { dict["putts"] = putts }
            if let fairwayHit = hole.fairwayHit { dict["fairwayHit"] = fairwayHit }
            if let gir = hole.gir { dict["gir"] = gir }
            return dict
        }
        
        let message: [String: Any] = [
            "action": "roundStateUpdate",
            "isRoundActive": isActive,
            "currentHole": currentHole,
            "courseName": courseName,
            "scores": scoresData,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("Error sending round state to watch: \(error.localizedDescription)")
        }
    }
    
    func sendEndRoundToWatch() {
        guard let session = session, session.activationState == .activated else { return }
        
        let message: [String: Any] = [
            "action": "endRound",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(message)
        }
        
        watchRoundActive = false
    }
    
    func sendStartRoundToWatch(courseName: String, pars: [Int]) {
        guard let session = session, session.activationState == .activated else { return }
        
        let message: [String: Any] = [
            "action": "startRound",
            "courseName": courseName,
            "pars": pars,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(message)
        }
    }
}

// Notification names for watch events
extension Foundation.Notification.Name {
    static let watchRoundStarted = Foundation.Notification.Name("watchRoundStarted")
    static let watchRoundEnded = Foundation.Notification.Name("watchRoundEnded")
    static let watchRoundDiscarded = Foundation.Notification.Name("watchRoundDiscarded")
    static let watchRoundStateUpdate = Foundation.Notification.Name("watchRoundStateUpdate")
    static let watchScoreUpdate = Foundation.Notification.Name("watchScoreUpdate")
    static let watchShotAdded = Foundation.Notification.Name("watchShotAdded")
    static let roundsUpdated = Foundation.Notification.Name("roundsUpdated")
    
    // Swing Analytics Notifications
    static let watchSwingDetected = Foundation.Notification.Name("watchSwingDetected")
    static let watchLiveSwingMetrics = Foundation.Notification.Name("watchLiveSwingMetrics")
    static let watchClubDistanceUpdate = Foundation.Notification.Name("watchClubDistanceUpdate")
    static let watchCoachingTip = Foundation.Notification.Name("watchCoachingTip")
    static let watchSessionSummary = Foundation.Notification.Name("watchSessionSummary")
    static let watchStrokesGainedUpdate = Foundation.Notification.Name("watchStrokesGainedUpdate")
}
