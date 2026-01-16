import Foundation
import WatchConnectivity

class WatchSyncManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isWatchConnected = false
    @Published var isWatchAppInstalled = false
    
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
        guard let session = session, session.isReachable else { return }
        
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
        guard let session = session, session.isReachable else { return }
        
        let message: [String: Any] = [
            "action": "startRound",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }
    
    func sendRoundEnd() {
        guard let session = session, session.isReachable else { return }
        
        let message: [String: Any] = [
            "action": "endRound",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }
    
    func sendScoreUpdate(hole: Int, score: Int) {
        guard let session = session, session.isReachable else { return }
        
        let message: [String: Any] = [
            "action": "scoreUpdate",
            "hole": hole,
            "score": score
        ]
        
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
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
            NotificationCenter.default.post(name: .watchRoundEnded, object: nil, userInfo: message)
            
        case "scoreUpdate":
            NotificationCenter.default.post(name: .watchScoreUpdate, object: nil, userInfo: message)
            
        case "shotAdded":
            NotificationCenter.default.post(name: .watchShotAdded, object: nil, userInfo: message)
            
        default:
            break
        }
    }
}

// Notification names for watch events
extension Notification.Name {
    static let watchRoundStarted = Notification.Name("watchRoundStarted")
    static let watchRoundEnded = Notification.Name("watchRoundEnded")
    static let watchScoreUpdate = Notification.Name("watchScoreUpdate")
    static let watchShotAdded = Notification.Name("watchShotAdded")
}
