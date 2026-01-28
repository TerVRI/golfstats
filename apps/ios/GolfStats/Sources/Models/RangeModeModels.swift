import Foundation
import CoreMotion
import simd

// MARK: - Body Tracking Mode

/// Tracking mode selection
enum BodyTrackingMode: String, CaseIterable, Codable {
    case vision2D = "2D (Standard)"
    case arkit3D = "3D (LiDAR)"
    
    var description: String {
        switch self {
        case .vision2D:
            return "Standard camera-based tracking. Works on all devices."
        case .arkit3D:
            return "LiDAR-enhanced 3D tracking with full body mesh. Requires iPhone 12 Pro or later."
        }
    }
    
    var iconName: String {
        switch self {
        case .vision2D:
            return "person.crop.rectangle"
        case .arkit3D:
            return "cube.transparent"
        }
    }
}

// MARK: - Range Session

/// Represents a complete practice session at the driving range
struct RangeSession: Identifiable, Codable {
    let id: UUID
    var startTime: Date
    var endTime: Date?
    var swings: [CombinedSwingCapture]
    var selectedClub: String?
    var notes: String?
    var trackingMode: BodyTrackingMode?
    
    // Computed properties
    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }
    
    var swingCount: Int { swings.count }
    
    var averageTempo: Double? {
        let tempos = swings.compactMap { $0.combinedMetrics?.tempoRatio }
        guard !tempos.isEmpty else { return nil }
        return tempos.reduce(0, +) / Double(tempos.count)
    }
    
    var averageClubSpeed: Double? {
        let speeds = swings.compactMap { $0.combinedMetrics?.estimatedClubSpeed }
        guard !speeds.isEmpty else { return nil }
        return speeds.reduce(0, +) / Double(speeds.count)
    }
    
    var consistencyScore: Double? {
        guard swings.count >= 3 else { return nil }
        let tempos = swings.compactMap { $0.combinedMetrics?.tempoRatio }
        guard tempos.count >= 3 else { return nil }
        
        let mean = tempos.reduce(0, +) / Double(tempos.count)
        let variance = tempos.map { pow($0 - mean, 2) }.reduce(0, +) / Double(tempos.count)
        let stdDev = sqrt(variance)
        
        // Lower std dev = higher consistency
        // Map to 0-100 scale (std dev of 0.5 = ~50%, 0 = 100%)
        return max(0, min(100, 100 - (stdDev * 100)))
    }
    
    init(id: UUID = UUID(), startTime: Date = Date()) {
        self.id = id
        self.startTime = startTime
        self.endTime = nil
        self.swings = []
        self.selectedClub = nil
        self.notes = nil
    }
}

// MARK: - Combined Swing Capture

/// A single swing captured with both camera and Watch data
struct CombinedSwingCapture: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    
    // Camera-based data (optional - may be nil if no camera)
    var cameraCapture: CameraSwingCapture?
    
    // Watch motion data (optional - may be nil if no Watch)
    var watchMotionData: WatchMotionCapture?
    
    // Combined/fused metrics
    var combinedMetrics: CombinedSwingMetrics?
    
    // Video reference (if recorded)
    var videoURL: URL?
    
    // User annotations
    var club: String?
    var userRating: Int? // 1-5 stars
    var notes: String?
    
    init(id: UUID = UUID(), timestamp: Date = Date()) {
        self.id = id
        self.timestamp = timestamp
    }
}

// MARK: - Camera Swing Capture

/// Data captured from iPhone camera using Vision framework
struct CameraSwingCapture: Codable {
    let startTime: Date
    var endTime: Date
    
    // Frame-by-frame body pose data
    var poseFrames: [PoseFrame]
    
    // Detected swing phases with timestamps
    var phases: [SwingPhaseMarker]
    
    // Computed body metrics
    var bodyMetrics: BodySwingMetrics?
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var frameCount: Int { poseFrames.count }
    
    var fps: Double {
        guard duration > 0 else { return 0 }
        return Double(frameCount) / duration
    }
}

/// A single frame of body pose data from Vision
struct PoseFrame: Codable {
    let timestamp: Date
    let frameIndex: Int
    
    // Key body landmarks (normalized 0-1 coordinates)
    var nose: CGPoint?
    var leftShoulder: CGPoint?
    var rightShoulder: CGPoint?
    var leftElbow: CGPoint?
    var rightElbow: CGPoint?
    var leftWrist: CGPoint?
    var rightWrist: CGPoint?
    var leftHip: CGPoint?
    var rightHip: CGPoint?
    var leftKnee: CGPoint?
    var rightKnee: CGPoint?
    var leftAnkle: CGPoint?
    var rightAnkle: CGPoint?
    
    // Derived angles
    var spineAngle: Double?         // Angle of spine from vertical
    var hipRotation: Double?        // Rotation of hips from square
    var shoulderRotation: Double?   // Rotation of shoulders from square
    var leftArmAngle: Double?       // Angle at left elbow
    var rightArmAngle: Double?      // Angle at right elbow
    
    // Detection confidence (0-1)
    var confidence: Float
    
    // 3D joint positions (only populated in ARKit mode)
    // Note: Not included in Codable since SIMD3<Float> doesn't auto-conform
    var joints3D: [PoseJoint3D]?
    
    // Custom Codable to exclude joints3D
    enum CodingKeys: String, CodingKey {
        case timestamp, frameIndex
        case nose, leftShoulder, rightShoulder, leftElbow, rightElbow
        case leftWrist, rightWrist, leftHip, rightHip
        case leftKnee, rightKnee, leftAnkle, rightAnkle
        case spineAngle, hipRotation, shoulderRotation
        case leftArmAngle, rightArmAngle, confidence
    }
}

/// 3D joint position for PoseFrame (for ARKit mode)
/// Note: Separate from Joint3D in ARBodyTrackingManager which has more properties
struct PoseJoint3D {
    let name: String
    let position: SIMD3<Float>      // 3D world position
    let screenPosition: CGPoint     // Projected 2D screen position
    let confidence: Float
}

/// Marks a detected swing phase with its timestamp
struct SwingPhaseMarker: Codable {
    let phase: CameraSwingPhase
    let timestamp: Date
    let frameIndex: Int
    let confidence: Float
}

/// Swing phases as detected by camera
enum CameraSwingPhase: String, Codable, CaseIterable {
    case setup = "Setup"
    case takeaway = "Takeaway"
    case backswing = "Backswing"
    case topOfSwing = "Top"
    case downswing = "Downswing"
    case impact = "Impact"
    case followThrough = "Follow Through"
    case finish = "Finish"
}

/// Body-based swing metrics computed from camera pose data
struct BodySwingMetrics: Codable {
    // Setup position
    var setupSpineAngle: Double?          // Degrees from vertical at address
    var setupHipWidth: Double?            // Normalized hip width
    var setupShoulderWidth: Double?       // Normalized shoulder width
    
    // Backswing
    var maxHipTurn: Double?               // Peak hip rotation (degrees)
    var maxShoulderTurn: Double?          // Peak shoulder rotation (degrees)
    var shoulderHipSeparation: Double?    // X-factor (shoulder turn - hip turn)
    var topOfSwingSpineAngle: Double?     // Spine angle at top
    
    // Downswing & Impact
    var spineAngleMaintained: Bool?       // Did spine angle stay consistent?
    var hipSlide: Double?                 // Lateral hip movement toward target
    var headMovement: Double?             // Total head movement (should be minimal)
    
    // Follow Through
    var finishBalance: Double?            // 0-1 score for balanced finish
    var fullRotation: Bool?               // Did player complete rotation?
    
    // Overall
    var swingPlaneConsistency: Double?    // How consistent was the swing plane
}

// MARK: - Watch Motion Capture

/// Motion data captured from Apple Watch during swing
struct WatchMotionCapture: Codable {
    let startTime: Date
    let endTime: Date
    
    // High-frequency motion samples (100Hz)
    var samples: [MotionSample]
    
    // Derived metrics
    var metrics: WatchSwingMetrics?
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var sampleCount: Int { samples.count }
    
    var effectiveSampleRate: Double {
        guard duration > 0 else { return 0 }
        return Double(sampleCount) / duration
    }
}

/// A single motion sample from Watch sensors
struct MotionSample: Codable {
    let timestamp: Date
    let index: Int
    
    // Accelerometer (G-force)
    var accelerationX: Double
    var accelerationY: Double
    var accelerationZ: Double
    
    // Gyroscope (rad/s)
    var rotationX: Double
    var rotationY: Double
    var rotationZ: Double
    
    // Computed magnitudes
    var totalAcceleration: Double {
        sqrt(pow(accelerationX, 2) + pow(accelerationY, 2) + pow(accelerationZ, 2))
    }
    
    var totalRotation: Double {
        sqrt(pow(rotationX, 2) + pow(rotationY, 2) + pow(rotationZ, 2))
    }
    
    init(timestamp: Date, index: Int, acceleration: (x: Double, y: Double, z: Double), rotation: (x: Double, y: Double, z: Double)) {
        self.timestamp = timestamp
        self.index = index
        self.accelerationX = acceleration.x
        self.accelerationY = acceleration.y
        self.accelerationZ = acceleration.z
        self.rotationX = rotation.x
        self.rotationY = rotation.y
        self.rotationZ = rotation.z
    }
}

/// Swing metrics derived from Watch motion data
struct WatchSwingMetrics: Codable {
    // Timing
    var backswingDuration: TimeInterval?
    var downswingDuration: TimeInterval?
    var totalSwingDuration: TimeInterval?
    var tempoRatio: Double?              // backswing / downswing
    
    // Speed
    var peakWristAcceleration: Double?   // Peak G-force
    var estimatedClubSpeed: Double?      // mph, estimated from wrist acceleration
    var peakRotationRate: Double?        // rad/s
    
    // Impact
    var impactTimestamp: Date?
    var impactQuality: Double?           // 0-1 based on acceleration spike sharpness
    var impactDeceleration: Double?      // How quickly acceleration dropped at impact
    
    // Pattern Analysis
    var lagRetained: Bool?               // Did wrist angle hold until late?
    var smoothnessScore: Double?         // 0-1, higher = smoother motion
    var consistencyWithPrevious: Double? // How similar to previous swings
}

// MARK: - Combined Metrics (Sensor Fusion)

/// Metrics computed by combining camera and Watch data
struct CombinedSwingMetrics: Codable {
    // Source indicators
    var hasCameraData: Bool
    var hasWatchData: Bool
    
    // Timing (Watch primary, Camera validation)
    var tempoRatio: Double?
    var backswingDuration: TimeInterval?
    var downswingDuration: TimeInterval?
    
    // Speed (Watch primary)
    var estimatedClubSpeed: Double?      // mph
    var peakWristSpeed: Double?          // mph
    
    // Body Position (Camera primary)
    var hipTurnDegrees: Double?
    var shoulderTurnDegrees: Double?
    var xFactor: Double?                 // shoulder - hip turn
    var spineAngleMaintained: Bool?
    var headMovementInches: Double?
    
    // Impact (Watch primary, Camera validation)
    var impactQuality: Double?           // 0-1
    var impactTimestamp: Date?
    
    // Swing Path (Both sources)
    var swingPath: SwingPathType?
    var swingPlaneAngle: Double?
    
    // Overall Scores
    var overallScore: Double?            // 0-100
    var consistencyScore: Double?        // 0-100
    var tempoScore: Double?              // 0-100 (based on target ratio)
    var balanceScore: Double?            // 0-100
    
    // Improvement suggestions
    var primaryFault: SwingFault?
    var suggestions: [String]
    
    init() {
        self.hasCameraData = false
        self.hasWatchData = false
        self.suggestions = []
    }
}

/// Detected swing path types
enum SwingPathType: String, Codable {
    case insideOut = "Inside-Out"
    case outsideIn = "Outside-In"
    case neutral = "Neutral"
    case unknown = "Unknown"
}

/// Common swing faults that can be detected
enum SwingFault: String, Codable, CaseIterable {
    case overTheTop = "Over the Top"
    case earlyExtension = "Early Extension"
    case lossOfPosture = "Loss of Posture"
    case swayOff = "Sway Off Ball"
    case slideThrough = "Slide Through"
    case casting = "Casting/Early Release"
    case reverseSpineAngle = "Reverse Spine Angle"
    case flatShoulderPlane = "Flat Shoulder Plane"
    case chickenwing = "Chicken Wing"
    case hangingBack = "Hanging Back"
    
    var description: String {
        switch self {
        case .overTheTop: return "Club moves outside the target line in the downswing"
        case .earlyExtension: return "Hips thrust toward the ball in the downswing"
        case .lossOfPosture: return "Spine angle changes significantly during the swing"
        case .swayOff: return "Excessive lateral movement away from target in backswing"
        case .slideThrough: return "Excessive lateral movement toward target in downswing"
        case .casting: return "Early release of wrist angle, losing lag"
        case .reverseSpineAngle: return "Upper body tilts toward target at top of backswing"
        case .flatShoulderPlane: return "Shoulders turn too flat, not enough tilt"
        case .chickenwing: return "Lead elbow bends and moves away from body through impact"
        case .hangingBack: return "Weight stays on trail side through impact"
        }
    }
    
    var tip: String {
        switch self {
        case .overTheTop: return "Feel like your hands drop down to start the downswing"
        case .earlyExtension: return "Keep your belt buckle pointing at the ball longer"
        case .lossOfPosture: return "Maintain your spine angle throughout the swing"
        case .swayOff: return "Keep your head centered over the ball"
        case .slideThrough: return "Rotate your hips rather than sliding them"
        case .casting: return "Feel like you're throwing the club from the inside"
        case .reverseSpineAngle: return "Keep your chest pointing at the ball at the top"
        case .flatShoulderPlane: return "Feel your lead shoulder work down in the backswing"
        case .chickenwing: return "Keep your lead elbow pointing at the target through impact"
        case .hangingBack: return "Feel your weight shift to your lead foot at impact"
        }
    }
}

// MARK: - Range Mode Settings

/// User preferences for Range Mode
struct RangeModeSettings: Codable {
    var recordVideo: Bool = true
    var showLiveMetrics: Bool = true
    var targetTempo: Double = 3.0      // Target backswing:downswing ratio
    var autoDetectSwing: Bool = true
    var hapticFeedback: Bool = true
    var voiceFeedback: Bool = false
    var showSkeletonOverlay: Bool = true
    var metricsToShow: Set<RangeMetricType> = Set(RangeMetricType.allCases)
    
    // Video settings
    var videoQuality: VideoQuality = .high
    var slowMotionCapture: Bool = true  // 120fps if available
    
    // Session settings
    var autoEndAfterMinutes: Int? = nil // Auto-end session after X minutes
    var reminderInterval: Int? = 10     // Reminder every X swings to check form
}

enum RangeMetricType: String, Codable, CaseIterable {
    case tempo = "Tempo"
    case clubSpeed = "Club Speed"
    case hipTurn = "Hip Turn"
    case shoulderTurn = "Shoulder Turn"
    case spineAngle = "Spine Angle"
    case headMovement = "Head Movement"
    case impactQuality = "Impact Quality"
    case swingPath = "Swing Path"
}

enum VideoQuality: String, Codable {
    case low = "720p"
    case medium = "1080p"
    case high = "4K"
}

// MARK: - Watch Communication

/// Message format for Range Mode communication between Watch and iPhone
struct RangeModeMessage: Codable {
    let action: RangeModeAction
    let timestamp: Date
    var payload: [String: AnyCodable]?
    
    enum RangeModeAction: String, Codable {
        case startSession = "startRangeSession"
        case endSession = "endRangeSession"
        case motionSample = "motionSample"        // Single sample
        case motionBatch = "motionBatch"          // Batch of samples
        case swingStart = "swingStart"
        case swingEnd = "swingEnd"
        case swingMetrics = "swingMetrics"        // Computed Watch metrics
        case syncRequest = "syncRequest"
        case syncAcknowledge = "syncAcknowledge"
    }
}

/// Type-erased codable for flexible payload encoding
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
