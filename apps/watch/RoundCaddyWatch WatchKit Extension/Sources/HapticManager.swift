import WatchKit
import Foundation

/// Manages contextual haptic feedback for golf events on Apple Watch
class HapticManager {
    
    // MARK: - Singleton
    
    static let shared = HapticManager()
    
    // MARK: - Settings
    
    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "hapticsEnabled")
    }
    
    private init() {
        // Default to enabled
        if UserDefaults.standard.object(forKey: "hapticsEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "hapticsEnabled")
        }
    }
    
    // MARK: - Haptic Types
    
    enum GolfEvent {
        case swingDetected
        case shotConfirmed
        case birdie
        case eagle
        case par
        case bogey
        case doubleBogeyOrWorse
        case roundStarted
        case roundSaved
        case roundDiscarded
        case approachingGreen
        case puttMade
        case holeComplete
        case notification
        case warning
        case error
    }
    
    // MARK: - Play Haptics
    
    func play(_ event: GolfEvent) {
        guard isEnabled else { return }
        
        let device = WKInterfaceDevice.current()
        
        switch event {
        case .swingDetected:
            // Subtle click for swing detection
            device.play(.click)
            
        case .shotConfirmed:
            // Success haptic for confirmed shot
            device.play(.success)
            
        case .birdie:
            // Exciting haptic sequence for birdie
            playSequence([.success, .directionUp])
            
        case .eagle:
            // Extra exciting for eagle/better
            playSequence([.success, .directionUp, .success])
            
        case .par:
            // Gentle success for par
            device.play(.success)
            
        case .bogey:
            // Subtle notification for bogey
            device.play(.notification)
            
        case .doubleBogeyOrWorse:
            // Failure haptic for double+
            device.play(.failure)
            
        case .roundStarted:
            // Start haptic
            device.play(.start)
            
        case .roundSaved:
            // Success for saved round
            playSequence([.success, .stop])
            
        case .roundDiscarded:
            // Stop haptic
            device.play(.stop)
            
        case .approachingGreen:
            // Notification that you're close
            device.play(.notification)
            
        case .puttMade:
            // Direction down (ball going in)
            device.play(.directionDown)
            
        case .holeComplete:
            // Click to mark hole complete
            device.play(.click)
            
        case .notification:
            device.play(.notification)
            
        case .warning:
            device.play(.retry)
            
        case .error:
            device.play(.failure)
        }
    }
    
    /// Play haptic for score relative to par
    func playScoreHaptic(score: Int, par: Int) {
        let relativeToPar = score - par
        
        switch relativeToPar {
        case ...(-2):
            play(.eagle)
        case -1:
            play(.birdie)
        case 0:
            play(.par)
        case 1:
            play(.bogey)
        default:
            play(.doubleBogeyOrWorse)
        }
    }
    
    /// Play haptic when approaching the green
    func playDistanceHaptic(distanceToGreen: Int) {
        if distanceToGreen <= 30 && distanceToGreen > 0 {
            play(.approachingGreen)
        }
    }
    
    // MARK: - Haptic Sequences
    
    private func playSequence(_ haptics: [WKHapticType]) {
        let device = WKInterfaceDevice.current()
        
        for (index, haptic) in haptics.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                device.play(haptic)
            }
        }
    }
    
    // MARK: - Settings
    
    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "hapticsEnabled")
    }
    
    func toggle() -> Bool {
        let newValue = !isEnabled
        setEnabled(newValue)
        
        // Provide feedback for the toggle
        if newValue {
            WKInterfaceDevice.current().play(.success)
        }
        
        return newValue
    }
}

// MARK: - Integration with RoundManager

extension RoundManager {
    /// Call when a score is entered
    func triggerScoreHaptic(hole: Int) {
        guard hole >= 1 && hole <= 18 else { return }
        guard let holeScore = holeScores.first(where: { $0.holeNumber == hole }),
              let score = holeScore.score else { return }
        let par = holeScore.par
        
        if score > 0 && par > 0 {
            HapticManager.shared.playScoreHaptic(score: score, par: par)
        }
    }
}

// MARK: - Integration with GPSManager

extension GPSManager {
    /// Call when distance updates to check for approaching green
    func checkDistanceHaptic() {
        let distance = distanceToGreenCenter
        if distance > 0 && distance <= 30 {
            // Only trigger once per hole
            let key = "hapticTriggered_hole_\(RoundManager.shared.currentHole)"
            if !UserDefaults.standard.bool(forKey: key) {
                HapticManager.shared.play(.approachingGreen)
                UserDefaults.standard.set(true, forKey: key)
            }
        }
    }
    
    /// Reset haptic triggers for new hole
    func resetHapticTriggers(for hole: Int) {
        UserDefaults.standard.set(false, forKey: "hapticTriggered_hole_\(hole)")
    }
}

// MARK: - Haptic Settings View

import SwiftUI

struct HapticSettingsView: View {
    @State private var hapticsEnabled: Bool = UserDefaults.standard.bool(forKey: "hapticsEnabled")
    
    var body: some View {
        List {
            Section {
                Toggle("Enable Haptics", isOn: $hapticsEnabled)
                    .onChange(of: hapticsEnabled) { _, newValue in
                        HapticManager.shared.setEnabled(newValue)
                    }
            } footer: {
                Text("Feel vibrations for scores, swing detection, and approaching the green.")
            }
            
            if hapticsEnabled {
                Section("Preview") {
                    Button("Birdie") {
                        HapticManager.shared.play(.birdie)
                    }
                    
                    Button("Par") {
                        HapticManager.shared.play(.par)
                    }
                    
                    Button("Bogey") {
                        HapticManager.shared.play(.bogey)
                    }
                    
                    Button("Swing Detected") {
                        HapticManager.shared.play(.swingDetected)
                    }
                }
            }
        }
        .navigationTitle("Haptics")
    }
}
