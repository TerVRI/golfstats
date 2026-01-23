import AppIntents
import SwiftUI
import CoreLocation

// MARK: - Distance Intent

/// Siri intent: "Hey Siri, distance to green"
@available(watchOS 10.0, *)
struct WatchGetDistanceIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Distance to Green"
    static var description = IntentDescription("Get the distance to the green on the current hole")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let gpsManager = GPSManager.shared
        let roundManager = RoundManager.shared
        
        guard roundManager.isRoundActive else {
            return .result(dialog: "No round is currently active. Start a round first.")
        }
        
        let center = gpsManager.distanceToGreenCenter
        guard center > 0 else {
            return .result(dialog: "Unable to get distance. Make sure GPS is enabled.")
        }
        
        let front = gpsManager.distanceToGreenFront
        let back = gpsManager.distanceToGreenBack
        
        let dialog: String
        if front > 0 && back > 0 {
            dialog = "\(center) yards to center. \(front) front, \(back) back."
        } else {
            dialog = "\(center) yards to the center of the green."
        }
        
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

// MARK: - Score Intent

/// Siri intent: "Hey Siri, what's my score"
@available(watchOS 10.0, *)
struct WatchGetScoreIntent: AppIntent {
    static var title: LocalizedStringResource = "Get My Score"
    static var description = IntentDescription("Get your current score in the round")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let roundManager = RoundManager.shared
        
        guard roundManager.isRoundActive else {
            return .result(dialog: "No round is currently active.")
        }
        
        // Calculate from holeScores
        let scores = roundManager.holeScores.compactMap { $0.score }
        let pars = roundManager.holeScores.map { $0.par }
        
        let totalScore = scores.reduce(0, +)
        let holesPlayed = scores.count
        let totalPar = pars.prefix(holesPlayed).reduce(0, +)
        let relativeToPar = totalScore - totalPar
        
        let scoreText: String
        if relativeToPar == 0 {
            scoreText = "even par"
        } else if relativeToPar > 0 {
            scoreText = "\(relativeToPar) over par"
        } else {
            scoreText = "\(abs(relativeToPar)) under par"
        }
        
        let dialog = "You're \(scoreText) through \(holesPlayed) holes. Total score is \(totalScore)."
        
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

// MARK: - Club Recommendation Intent

/// Siri intent: "Hey Siri, what club should I use"
@available(watchOS 10.0, *)
struct WatchGetClubIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Club Recommendation"
    static var description = IntentDescription("Get AI club recommendation for current distance")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let roundManager = RoundManager.shared
        let gpsManager = GPSManager.shared
        
        guard roundManager.isRoundActive else {
            return .result(dialog: "No round is currently active.")
        }
        
        // Check if we have an AI recommendation
        if let recommendation = roundManager.currentAIRecommendation {
            var dialog = "AI recommends \(recommendation.club)"
            
            if let playsLike = recommendation.playsLikeDistance {
                dialog += ". Plays like \(playsLike.adjustedDistance) yards"
            }
            
            if let alternate = recommendation.alternateClub {
                dialog += ". Or try \(alternate)"
            }
            
            return .result(dialog: IntentDialog(stringLiteral: dialog))
        }
        
        // Fallback to club distance tracker
        let distance = gpsManager.distanceToGreenCenter
        if distance > 0 {
            let clubTracker = ClubDistanceTracker.shared
            let suggestedClub = clubTracker.suggestClub(forDistance: distance)
            return .result(dialog: IntentDialog(stringLiteral: "For \(distance) yards, try your \(suggestedClub)."))
        }
        
        return .result(dialog: "Unable to determine distance for club recommendation.")
    }
}

// MARK: - Hole Info Intent

/// Siri intent: "Hey Siri, hole info"
@available(watchOS 10.0, *)
struct WatchGetHoleInfoIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Hole Info"
    static var description = IntentDescription("Get information about the current hole")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let roundManager = RoundManager.shared
        
        guard roundManager.isRoundActive else {
            return .result(dialog: "No round is currently active.")
        }
        
        let hole = roundManager.currentHole
        let holeScore = roundManager.holeScores.first { $0.holeNumber == hole }
        let par = holeScore?.par ?? 4
        let currentScore = holeScore?.score
        
        var dialog = "Hole \(hole), par \(par)."
        
        if let score = currentScore, score > 0 {
            let relativeToPar = score - par
            let scoreDesc: String
            switch relativeToPar {
            case ...(-2): scoreDesc = "eagle or better"
            case -1: scoreDesc = "birdie"
            case 0: scoreDesc = "par"
            case 1: scoreDesc = "bogey"
            case 2: scoreDesc = "double bogey"
            default: scoreDesc = "\(relativeToPar) over par"
            }
            dialog += " You scored \(score), \(scoreDesc)."
        }
        
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

// MARK: - Mark Shot Intent

/// Siri intent: "Hey Siri, mark my shot"
@available(watchOS 10.0, *)
struct WatchMarkShotIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Shot"
    static var description = IntentDescription("Mark your current position as a shot")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let roundManager = RoundManager.shared
        let gpsManager = GPSManager.shared
        
        guard roundManager.isRoundActive else {
            return .result(dialog: "No round is currently active.")
        }
        
        guard let location = gpsManager.currentLocation else {
            return .result(dialog: "Unable to get your location. Make sure GPS is enabled.")
        }
        
        // Add shot at current location
        let shotsOnHole = roundManager.shots.filter { $0.holeNumber == roundManager.currentHole }
        let shotNumber = shotsOnHole.count + 1
        
        let shot = Shot(
            id: UUID(),
            holeNumber: roundManager.currentHole,
            shotNumber: shotNumber,
            club: nil,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            locationIsEstimated: false,
            timestamp: Date()
        )
        roundManager.shots.append(shot)
        
        // Provide haptic feedback
        HapticManager.shared.play(.shotConfirmed)
        
        let dialog = "Shot \(shotNumber) marked on hole \(roundManager.currentHole)."
        
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}

// MARK: - App Shortcuts Provider

@available(watchOS 10.0, *)
struct RoundCaddyWatchShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WatchGetDistanceIntent(),
            phrases: [
                "Distance to green with \(.applicationName)",
                "How far to the green \(.applicationName)",
                "What's my distance \(.applicationName)",
                "\(.applicationName) distance"
            ],
            shortTitle: "Distance",
            systemImageName: "flag.fill"
        )
        
        AppShortcut(
            intent: WatchGetScoreIntent(),
            phrases: [
                "What's my score with \(.applicationName)",
                "My golf score \(.applicationName)",
                "\(.applicationName) score",
                "How am I playing \(.applicationName)"
            ],
            shortTitle: "Score",
            systemImageName: "number.circle"
        )
        
        AppShortcut(
            intent: WatchGetClubIntent(),
            phrases: [
                "What club should I use \(.applicationName)",
                "Club recommendation \(.applicationName)",
                "\(.applicationName) what club",
                "Suggest a club \(.applicationName)"
            ],
            shortTitle: "Club",
            systemImageName: "figure.golf"
        )
        
        AppShortcut(
            intent: WatchGetHoleInfoIntent(),
            phrases: [
                "Hole info with \(.applicationName)",
                "\(.applicationName) hole info",
                "What hole am I on \(.applicationName)"
            ],
            shortTitle: "Hole Info",
            systemImageName: "info.circle"
        )
        
        AppShortcut(
            intent: WatchMarkShotIntent(),
            phrases: [
                "Mark my shot with \(.applicationName)",
                "\(.applicationName) mark shot",
                "Record shot \(.applicationName)"
            ],
            shortTitle: "Mark Shot",
            systemImageName: "mappin.and.ellipse"
        )
    }
}

// MARK: - Siri Settings View

struct SiriSettingsView: View {
    var body: some View {
        List {
            Section {
                Text("Say \"Hey Siri\" followed by:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Available Commands") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\"Distance to green\"")
                        .font(.caption)
                    Text("Get yardages to the green")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\"What's my score\"")
                        .font(.caption)
                    Text("Hear your current score")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\"What club\"")
                        .font(.caption)
                    Text("Get club recommendation")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\"Mark my shot\"")
                        .font(.caption)
                    Text("Record shot location")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section {
                Text("Tip: Add shortcuts to your Watch face for quick access")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Siri")
    }
}
