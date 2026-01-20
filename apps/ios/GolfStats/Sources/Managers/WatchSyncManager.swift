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
    
    private var session: WCSession?
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
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
        }
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
            
        default:
            break
        }
    }
    
    // MARK: - Send Round State to Watch
    
    func sendRoundStateToWatch(isActive: Bool, currentHole: Int, courseName: String, holeScores: [HoleScore]) {
        guard let session = session, session.activationState == .activated, session.isReachable else { return }
        
        let message: [String: Any] = [
            "action": "roundStateUpdate",
            "isRoundActive": isActive,
            "currentHole": currentHole,
            "courseName": courseName,
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
}
