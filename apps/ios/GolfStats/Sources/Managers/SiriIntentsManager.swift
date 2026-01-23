import Foundation
import Intents
import AppIntents
import CoreLocation

// MARK: - App Intents (iOS 16+)

/// Get distance to the green - main Siri intent
@available(iOS 16.0, *)
struct GetDistanceIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Distance to Green"
    static var description = IntentDescription("Get the distance to the front, center, or back of the green")
    
    @Parameter(title: "Target", default: .center)
    var target: DistanceTarget
    
    static var parameterSummary: some ParameterSummary {
        Summary("Get distance to \(\.$target) of the green")
    }
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let manager = SiriIntentsManager.shared
        
        guard manager.isRoundActive else {
            return .result(
                dialog: "You don't have an active round. Open RoundCaddy to start a round.",
                view: SiriDistanceSnippetView(distance: nil, target: target, message: "No active round")
            )
        }
        
        let distance = manager.getDistance(to: target)
        
        guard let distance = distance else {
            return .result(
                dialog: "I couldn't get the GPS distance. Make sure location services are enabled.",
                view: SiriDistanceSnippetView(distance: nil, target: target, message: "GPS unavailable")
            )
        }
        
        let response = "\(distance) yards to the \(target.displayName)"
        
        return .result(
            dialog: IntentDialog(stringLiteral: response),
            view: SiriDistanceSnippetView(distance: distance, target: target, message: nil)
        )
    }
}

/// Get current score
@available(iOS 16.0, *)
struct GetScoreIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Golf Score"
    static var description = IntentDescription("Get your current score in the active round")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = SiriIntentsManager.shared
        
        guard manager.isRoundActive else {
            return .result(dialog: "You don't have an active round.")
        }
        
        let score = manager.currentScore
        let throughHoles = manager.completedHoles
        let vspar = manager.scoreVsPar
        
        var response = "You're at \(score)"
        if vspar > 0 {
            response += ", \(vspar) over par"
        } else if vspar < 0 {
            response += ", \(abs(vspar)) under par"
        } else {
            response += ", even par"
        }
        response += " through \(throughHoles) holes."
        
        return .result(dialog: IntentDialog(stringLiteral: response))
    }
}

/// Get current hole info
@available(iOS 16.0, *)
struct GetHoleInfoIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Hole Info"
    static var description = IntentDescription("Get information about the current hole")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = SiriIntentsManager.shared
        
        guard manager.isRoundActive else {
            return .result(dialog: "You don't have an active round.")
        }
        
        let hole = manager.currentHole
        let par = manager.currentHolePar
        let yardage = manager.currentHoleYardage
        
        var response = "Hole \(hole), par \(par)"
        if let yardage = yardage {
            response += ", \(yardage) yards"
        }
        
        return .result(dialog: IntentDialog(stringLiteral: response))
    }
}

/// Get club recommendation
@available(iOS 16.0, *)
struct GetClubRecommendationIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Club Recommendation"
    static var description = IntentDescription("Get a club recommendation for the current distance")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = SiriIntentsManager.shared
        
        guard manager.isRoundActive else {
            return .result(dialog: "You don't have an active round.")
        }
        
        guard let distance = manager.getDistance(to: .center) else {
            return .result(dialog: "I couldn't get your distance to the green.")
        }
        
        let club = manager.recommendClub(for: distance)
        let response = "\(distance) yards to the center. I recommend your \(club)."
        
        return .result(dialog: IntentDialog(stringLiteral: response))
    }
}

/// Mark a shot with Siri
@available(iOS 16.0, *)
struct MarkShotIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Golf Shot"
    static var description = IntentDescription("Mark your current position as a shot")
    
    @Parameter(title: "Club")
    var club: ClubParameter?
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = SiriIntentsManager.shared
        
        guard manager.isRoundActive else {
            return .result(dialog: "You don't have an active round.")
        }
        
        manager.markShot(club: club?.clubType)
        
        if let club = club {
            return .result(dialog: "Shot marked with your \(club.displayName).")
        } else {
            return .result(dialog: "Shot marked.")
        }
    }
}

// MARK: - Parameter Types

@available(iOS 16.0, *)
enum DistanceTarget: String, AppEnum {
    case front = "front"
    case center = "center"
    case back = "back"
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Distance Target")
    
    static var caseDisplayRepresentations: [DistanceTarget: DisplayRepresentation] = [
        .front: "Front",
        .center: "Center",
        .back: "Back"
    ]
    
    var displayName: String {
        switch self {
        case .front: return "front"
        case .center: return "center"
        case .back: return "back"
        }
    }
}

@available(iOS 16.0, *)
struct ClubParameter: AppEntity {
    let id: String
    let displayName: String
    let clubType: ClubType
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Golf Club")
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: displayName))
    }
    
    static var defaultQuery = ClubQuery()
}

@available(iOS 16.0, *)
struct ClubQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ClubParameter] {
        return identifiers.compactMap { id in
            ClubType.allCases.first { $0.rawValue == id }.map {
                ClubParameter(id: $0.rawValue, displayName: $0.rawValue, clubType: $0)
            }
        }
    }
    
    func suggestedEntities() async throws -> [ClubParameter] {
        return ClubType.allCases.map {
            ClubParameter(id: $0.rawValue, displayName: $0.rawValue, clubType: $0)
        }
    }
}

// MARK: - App Shortcuts Provider

@available(iOS 16.0, *)
struct RoundCaddyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetDistanceIntent(),
            phrases: [
                "Get distance in \(.applicationName)",
                "How far to the green in \(.applicationName)",
                "Distance to center in \(.applicationName)",
                "What's my distance in \(.applicationName)",
                "How far is the green \(.applicationName)"
            ],
            shortTitle: "Distance to Green",
            systemImageName: "location.fill"
        )
        
        AppShortcut(
            intent: GetScoreIntent(),
            phrases: [
                "What's my score in \(.applicationName)",
                "Get my golf score from \(.applicationName)",
                "How am I playing in \(.applicationName)"
            ],
            shortTitle: "Golf Score",
            systemImageName: "list.number"
        )
        
        AppShortcut(
            intent: GetHoleInfoIntent(),
            phrases: [
                "Current hole info in \(.applicationName)",
                "What hole am I on in \(.applicationName)",
                "Tell me about this hole \(.applicationName)"
            ],
            shortTitle: "Hole Info",
            systemImageName: "flag.fill"
        )
        
        AppShortcut(
            intent: GetClubRecommendationIntent(),
            phrases: [
                "What club should I use in \(.applicationName)",
                "Club recommendation from \(.applicationName)",
                "Recommend a club \(.applicationName)"
            ],
            shortTitle: "Club Recommendation",
            systemImageName: "figure.golf"
        )
        
        AppShortcut(
            intent: MarkShotIntent(),
            phrases: [
                "Mark shot in \(.applicationName)",
                "Record my shot in \(.applicationName)",
                "I just hit in \(.applicationName)"
            ],
            shortTitle: "Mark Shot",
            systemImageName: "scope"
        )
    }
}

// MARK: - Siri Snippet View

import SwiftUI

@available(iOS 16.0, *)
struct SiriDistanceSnippetView: View {
    let distance: Int?
    let target: DistanceTarget
    let message: String?
    
    var body: some View {
        VStack(spacing: 12) {
            if let distance = distance {
                Text("\(distance)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                
                Text("yards to \(target.displayName)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else if let message = message {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Siri Intents Manager

/// Central manager for Siri integration - bridges between intents and app state
class SiriIntentsManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SiriIntentsManager()
    
    // MARK: - State Access
    
    /// Whether there's an active round
    var isRoundActive: Bool {
        // Access RoundManager state
        return _isRoundActive
    }
    
    /// Current total score
    var currentScore: Int {
        return _currentScore
    }
    
    /// Score vs par
    var scoreVsPar: Int {
        return _scoreVsPar
    }
    
    /// Number of completed holes
    var completedHoles: Int {
        return _completedHoles
    }
    
    /// Current hole number
    var currentHole: Int {
        return _currentHole
    }
    
    /// Current hole par
    var currentHolePar: Int {
        return _currentHolePar
    }
    
    /// Current hole yardage
    var currentHoleYardage: Int? {
        return _currentHoleYardage
    }
    
    // MARK: - Private State (updated by app)
    
    private var _isRoundActive = false
    private var _currentScore = 0
    private var _scoreVsPar = 0
    private var _completedHoles = 0
    private var _currentHole = 1
    private var _currentHolePar = 4
    private var _currentHoleYardage: Int?
    
    private var _distanceToFront: Int?
    private var _distanceToCenter: Int?
    private var _distanceToBack: Int?
    
    private var _clubDistances: [ClubType: Int] = [:]
    
    // MARK: - Initialization
    
    private init() {
        setupDefaultClubDistances()
    }
    
    // MARK: - State Updates (called by app)
    
    /// Update round state (called by RoundManager)
    func updateRoundState(
        isActive: Bool,
        score: Int,
        vsPar: Int,
        completedHoles: Int,
        currentHole: Int,
        currentHolePar: Int,
        currentHoleYardage: Int?
    ) {
        _isRoundActive = isActive
        _currentScore = score
        _scoreVsPar = vsPar
        _completedHoles = completedHoles
        _currentHole = currentHole
        _currentHolePar = currentHolePar
        _currentHoleYardage = currentHoleYardage
    }
    
    /// Update GPS distances (called by GPSManager)
    func updateDistances(front: Int?, center: Int?, back: Int?) {
        _distanceToFront = front
        _distanceToCenter = center
        _distanceToBack = back
    }
    
    /// Update club distances from user's bag
    func updateClubDistances(_ distances: [ClubType: Int]) {
        _clubDistances = distances
    }
    
    // MARK: - Intent Actions
    
    /// Get distance to target
    @available(iOS 16.0, *)
    func getDistance(to target: DistanceTarget) -> Int? {
        switch target {
        case .front: return _distanceToFront
        case .center: return _distanceToCenter
        case .back: return _distanceToBack
        }
    }
    
    /// Get club recommendation for distance
    func recommendClub(for distance: Int) -> String {
        // Find the club that matches best
        var bestClub: ClubType = .sevenIron
        var bestDiff = Int.max
        
        for (club, clubDistance) in _clubDistances {
            let diff = abs(clubDistance - distance)
            if diff < bestDiff {
                bestDiff = diff
                bestClub = club
            }
        }
        
        return bestClub.rawValue
    }
    
    /// Mark a shot
    func markShot(club: ClubType?) {
        // Post notification to be handled by the app
        NotificationCenter.default.post(
            name: Foundation.Notification.Name.siriMarkShot,
            object: nil,
            userInfo: ["club": club as Any]
        )
    }
    
    // MARK: - Setup
    
    private func setupDefaultClubDistances() {
        // Default distances (will be updated from user's actual data)
        _clubDistances = [
            .driver: 250,
            .threeWood: 230,
            .fiveWood: 210,
            .hybrid3: 195,
            .hybrid4: 185,
            .hybrid5: 180,
            .fourIron: 185,
            .fiveIron: 175,
            .sixIron: 165,
            .sevenIron: 155,
            .eightIron: 145,
            .nineIron: 135,
            .pitchingWedge: 125,
            .gapWedge: 110,
            .sandWedge: 95,
            .lobWedge: 75,
            .putter: 0
        ]
    }
    
    // MARK: - Siri Donation
    
    /// Donate relevant shortcuts based on current context
    @available(iOS 16.0, *)
    func donateRelevantShortcuts() {
        // Donate distance intent when in active round
        if isRoundActive {
            let intent = GetDistanceIntent()
            intent.target = .center
            // System handles donation automatically with App Intents
        }
    }
}

// MARK: - Notification Names

extension Foundation.Notification.Name {
    static let siriMarkShot = Foundation.Notification.Name("siriMarkShot")
}

// MARK: - ClubType Extension (if not already defined elsewhere)

// This assumes ClubType is defined elsewhere - this is just for compilation
// If ClubType doesn't exist, uncomment and modify:
/*
enum ClubType: String, CaseIterable, Codable {
    case driver = "Driver"
    case threeWood = "3 Wood"
    case fiveWood = "5 Wood"
    case hybrid = "Hybrid"
    case fourIron = "4 Iron"
    case fiveIron = "5 Iron"
    case sixIron = "6 Iron"
    case sevenIron = "7 Iron"
    case eightIron = "8 Iron"
    case nineIron = "9 Iron"
    case pitchingWedge = "PW"
    case gapWedge = "GW"
    case sandWedge = "SW"
    case lobWedge = "LW"
    case putter = "Putter"
}
*/

// MARK: - Settings View

import SwiftUI

struct SiriSettingsView: View {
    @State private var voiceDistancesEnabled = false
    @State private var showShortcutsHelp = false
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "mic.fill")
                            .font(.title)
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Siri & Shortcuts")
                                .font(.headline)
                            Text("Use voice commands during your round")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Section("Available Commands") {
                VoiceCommandRow(
                    phrase: "Hey Siri, get distance in RoundCaddy",
                    description: "Get distance to the green"
                )
                
                VoiceCommandRow(
                    phrase: "Hey Siri, what's my score in RoundCaddy",
                    description: "Get your current score"
                )
                
                VoiceCommandRow(
                    phrase: "Hey Siri, what club should I use",
                    description: "Get a club recommendation"
                )
                
                VoiceCommandRow(
                    phrase: "Hey Siri, mark shot in RoundCaddy",
                    description: "Record your shot position"
                )
            }
            
            Section {
                Toggle("Announce distances automatically", isOn: $voiceDistancesEnabled)
                
                if voiceDistancesEnabled {
                    Text("RoundCaddy will announce distances when you approach your ball")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section {
                Button(action: { showShortcutsHelp = true }) {
                    HStack {
                        Text("Add to Shortcuts App")
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                    }
                }
                
                Link(destination: URL(string: "x-apple.shortcuts://")!) {
                    HStack {
                        Text("Open Shortcuts App")
                        Spacer()
                        Image(systemName: "arrow.up.forward.square")
                    }
                }
            }
            
            Section {
                Text("Tip: You can customize these phrases in the Shortcuts app or use them directly with Siri during your round.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Siri & Voice")
        .sheet(isPresented: $showShortcutsHelp) {
            ShortcutsHelpView()
        }
    }
}

struct VoiceCommandRow: View {
    let phrase: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(phrase)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct ShortcutsHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 50))
                            .foregroundStyle(.blue)
                        
                        Text("Custom Shortcuts")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    
                    // Steps
                    VStack(alignment: .leading, spacing: 16) {
                        StepRow(number: 1, text: "Open the Shortcuts app on your iPhone")
                        StepRow(number: 2, text: "Tap the + button to create a new shortcut")
                        StepRow(number: 3, text: "Search for \"RoundCaddy\" in the actions")
                        StepRow(number: 4, text: "Add actions like \"Get Distance\" or \"Get Score\"")
                        StepRow(number: 5, text: "Tap the name at the top to set a custom phrase")
                    }
                    .padding()
                    
                    // Example
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Example Shortcuts")
                            .font(.headline)
                        
                        Text("• \"What's my yardage\" → Get Distance (Center)")
                        Text("• \"How's my round going\" → Get Score")
                        Text("• \"Caddie\" → Get Club Recommendation")
                    }
                    .font(.subheadline)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Shortcuts Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct StepRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
        }
    }
}
