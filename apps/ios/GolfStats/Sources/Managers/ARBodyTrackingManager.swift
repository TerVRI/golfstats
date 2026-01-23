import Foundation
import ARKit
import RealityKit
import Combine
import simd

/// Manages ARKit body tracking for 3D swing analysis
/// Provides 91-joint skeleton tracking with optional LiDAR depth enhancement
class ARBodyTrackingManager: NSObject, ObservableObject {
    
    // MARK: - Static Properties
    
    /// Check if AR body tracking is supported on this device
    static var isSupported: Bool {
        return ARBodyTrackingConfiguration.isSupported
    }
    
    // MARK: - Published State
    
    @Published var isTracking = false
    @Published var isPersonDetected = false
    @Published var currentSkeleton: Skeleton3D?
    @Published var trackingQuality: TrackingQuality = .notAvailable
    
    // Avatar state
    @Published var avatarEntity: Entity?
    @Published var isAvatarVisible = false
    
    // Measurements
    @Published var currentMeasurements: BodyMeasurements?
    
    // Swing plane
    @Published var swingPlaneNormal: SIMD3<Float>?
    @Published var swingPlanePoints: [SIMD3<Float>] = []
    
    // MARK: - Configuration
    
    let capabilities = LiDARCapabilities.shared
    var settings = LiDAR3DSettings()
    
    // MARK: - Private Properties
    
    private var arSession: ARSession?
    private var arView: ARView?
    private var bodyAnchor: ARBodyAnchor?
    private var bodyAnchorEntity: AnchorEntity?
    
    // Skeleton history for swing analysis
    private var skeletonHistory: [Skeleton3D] = []
    private let maxHistorySize = 300 // ~10 seconds at 30fps
    
    // Swing plane calculation
    private var handPathPoints: [SIMD3<Float>] = []
    
    // Callbacks
    var onSkeletonUpdate: ((Skeleton3D) -> Void)?
    var onSwingDetected: ((SwingData3D) -> Void)?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
    }
    
    // MARK: - Setup
    
    /// Setup AR view for body tracking
    func setupARView(_ view: ARView) {
        self.arView = view
        arSession = view.session
        arSession?.delegate = self
        
        print("🎯 ARBodyTrackingManager configured with ARView")
    }
    
    /// Start body tracking session
    func startTracking() {
        guard capabilities.supportsBodyTracking else {
            print("⚠️ Body tracking not supported on this device")
            trackingQuality = .notAvailable
            return
        }
        
        guard let config = capabilities.createBodyTrackingConfiguration() else {
            print("⚠️ Could not create body tracking configuration")
            return
        }
        
        arSession?.run(config, options: [.resetTracking, .removeExistingAnchors])
        isTracking = true
        
        print("🎯 ARKit body tracking started (LiDAR: \(capabilities.hasLiDAR))")
    }
    
    /// Stop body tracking session
    func stopTracking() {
        arSession?.pause()
        isTracking = false
        isPersonDetected = false
        bodyAnchor = nil
        
        print("🎯 ARKit body tracking stopped")
    }
    
    // MARK: - Avatar Management
    
    /// Load and attach 3D avatar to body anchor
    func loadAvatar(style: AvatarStyle) {
        guard let arView = arView else { return }
        
        // Remove existing avatar
        removeAvatar()
        
        do {
            let avatarURL: URL
            
            switch style {
            case .robot:
                // Use Apple's robot character from bundle or load from URL
                avatarURL = Bundle.main.url(forResource: "robot", withExtension: "usdz")
                    ?? Bundle.main.url(forResource: "biped_robot", withExtension: "usdz")!
                
            case .golfer:
                // Custom golfer character (would need to be added)
                avatarURL = Bundle.main.url(forResource: "golfer", withExtension: "usdz")
                    ?? Bundle.main.url(forResource: "robot", withExtension: "usdz")!
                
            case .skeleton:
                // Create skeleton from joints
                createSkeletonEntity()
                return
                
            case .points:
                // Create point cloud entity
                createPointCloudEntity()
                return
            }
            
            // Load body-tracked entity
            let character = try Entity.loadBodyTracked(contentsOf: avatarURL)
            
            // Create body anchor
            let bodyAnchor = AnchorEntity(.body)
            bodyAnchor.addChild(character)
            
            arView.scene.addAnchor(bodyAnchor)
            
            self.bodyAnchorEntity = bodyAnchor
            self.avatarEntity = character
            self.isAvatarVisible = true
            
            print("🤖 Avatar loaded: \(style.rawValue)")
            
        } catch {
            print("⚠️ Failed to load avatar: \(error.localizedDescription)")
            // Fallback to skeleton visualization
            createSkeletonEntity()
        }
    }
    
    /// Remove current avatar
    func removeAvatar() {
        bodyAnchorEntity?.removeFromParent()
        bodyAnchorEntity = nil
        avatarEntity = nil
        isAvatarVisible = false
    }
    
    /// Create skeleton entity from joints
    private func createSkeletonEntity() {
        guard let arView = arView else { return }
        
        let skeletonAnchor = AnchorEntity(.body)
        
        // Create sphere for each joint
        for jointName in ARSkeletonDefinition.defaultBody3D.jointNames {
            let sphere = MeshResource.generateSphere(radius: 0.02)
            let material = SimpleMaterial(color: .green, isMetallic: false)
            let jointEntity = ModelEntity(mesh: sphere, materials: [material])
            jointEntity.name = jointName
            skeletonAnchor.addChild(jointEntity)
        }
        
        arView.scene.addAnchor(skeletonAnchor)
        bodyAnchorEntity = skeletonAnchor
        isAvatarVisible = true
        
        print("💀 Skeleton entity created")
    }
    
    /// Create point cloud entity (for LiDAR devices)
    private func createPointCloudEntity() {
        guard capabilities.hasLiDAR else {
            print("⚠️ Point cloud requires LiDAR")
            createSkeletonEntity()
            return
        }
        
        // Point cloud is handled differently - drawn from depth data
        // For now, use skeleton
        createSkeletonEntity()
    }
    
    // MARK: - Skeleton Processing
    
    /// Extract skeleton data from ARBodyAnchor
    private func processBodyAnchor(_ anchor: ARBodyAnchor) {
        let skeleton = extractSkeleton3D(from: anchor)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.currentSkeleton = skeleton
            self.isPersonDetected = true
            self.updateTrackingQuality(from: anchor)
            
            // Add to history
            self.skeletonHistory.append(skeleton)
            if self.skeletonHistory.count > self.maxHistorySize {
                self.skeletonHistory.removeFirst()
            }
            
            // Update measurements
            if self.settings.showRealMeasurements {
                self.updateMeasurements(skeleton: skeleton)
            }
            
            // Update swing plane
            if self.settings.showSwingPlane {
                self.updateSwingPlane(skeleton: skeleton)
            }
            
            // Notify callback
            self.onSkeletonUpdate?(skeleton)
        }
    }
    
    /// Extract Skeleton3D from ARBodyAnchor
    private func extractSkeleton3D(from anchor: ARBodyAnchor) -> Skeleton3D {
        let arSkeleton = anchor.skeleton
        
        var joints: [String: Joint3D] = [:]
        
        for (index, jointName) in arSkeleton.definition.jointNames.enumerated() {
            let modelTransform = arSkeleton.jointModelTransforms[index]
            let localTransform = arSkeleton.jointLocalTransforms[index]
            
            // Extract position (in meters)
            let position = SIMD3<Float>(
                modelTransform.columns.3.x,
                modelTransform.columns.3.y,
                modelTransform.columns.3.z
            )
            
            // Extract rotation
            let rotationMatrix = simd_float3x3(
                SIMD3<Float>(modelTransform.columns.0.x, modelTransform.columns.0.y, modelTransform.columns.0.z),
                SIMD3<Float>(modelTransform.columns.1.x, modelTransform.columns.1.y, modelTransform.columns.1.z),
                SIMD3<Float>(modelTransform.columns.2.x, modelTransform.columns.2.y, modelTransform.columns.2.z)
            )
            
            joints[jointName] = Joint3D(
                name: jointName,
                position: position,
                rotation: rotationMatrix,
                localTransform: localTransform,
                worldTransform: modelTransform,
                isTracked: true // ARKit doesn't provide per-joint confidence
            )
        }
        
        return Skeleton3D(
            timestamp: Date(),
            joints: joints,
            rootTransform: anchor.transform,
            estimatedHeight: Float(anchor.estimatedScaleFactor)
        )
    }
    
    /// Update tracking quality indicator
    private func updateTrackingQuality(from anchor: ARBodyAnchor) {
        // ARKit doesn't provide explicit quality, estimate from scale factor
        let scale = anchor.estimatedScaleFactor
        
        if scale > 0.8 && scale < 1.2 {
            trackingQuality = .good
        } else if scale > 0.6 && scale < 1.4 {
            trackingQuality = .limited
        } else {
            trackingQuality = .poor
        }
    }
    
    // MARK: - Measurements
    
    /// Calculate real-world body measurements from skeleton
    private func updateMeasurements(skeleton: Skeleton3D) {
        guard let leftHip = skeleton.joints["left_upLeg_joint"],
              let rightHip = skeleton.joints["right_upLeg_joint"],
              let leftShoulder = skeleton.joints["left_shoulder_1_joint"],
              let rightShoulder = skeleton.joints["right_shoulder_1_joint"],
              let leftHand = skeleton.joints["left_hand_joint"],
              let rightHand = skeleton.joints["right_hand_joint"],
              let head = skeleton.joints["head_joint"] else {
            return
        }
        
        // Calculate distances in meters, convert to cm
        let stanceWidth = distance(leftHip.position, rightHip.position) * 100
        let shoulderWidth = distance(leftShoulder.position, rightShoulder.position) * 100
        let armSpan = distance(leftHand.position, rightHand.position) * 100
        
        // Estimate height from head to average foot position
        var height: Float = 0
        if let leftFoot = skeleton.joints["left_foot_joint"],
           let rightFoot = skeleton.joints["right_foot_joint"] {
            let avgFootY = (leftFoot.position.y + rightFoot.position.y) / 2
            height = (head.position.y - avgFootY) * 100
        }
        
        currentMeasurements = BodyMeasurements(
            stanceWidthCm: stanceWidth,
            shoulderWidthCm: shoulderWidth,
            armSpanCm: armSpan,
            heightCm: height
        )
    }
    
    // MARK: - Swing Plane
    
    /// Update swing plane from hand path
    private func updateSwingPlane(skeleton: Skeleton3D) {
        // Track dominant hand (right hand for right-handed golfer)
        guard let rightHand = skeleton.joints["right_hand_joint"] else { return }
        
        handPathPoints.append(rightHand.position)
        
        // Keep last 60 points (~2 seconds)
        if handPathPoints.count > 60 {
            handPathPoints.removeFirst()
        }
        
        // Calculate swing plane from hand path
        if handPathPoints.count >= 10 {
            let plane = calculateSwingPlane(points: handPathPoints)
            swingPlaneNormal = plane.normal
            swingPlanePoints = Array(handPathPoints.suffix(30))
        }
    }
    
    /// Calculate swing plane from set of 3D points using least squares
    private func calculateSwingPlane(points: [SIMD3<Float>]) -> (normal: SIMD3<Float>, d: Float) {
        // Centroid
        let n = Float(points.count)
        let centroid = points.reduce(SIMD3<Float>.zero, +) / n
        
        // Covariance matrix
        var covariance = simd_float3x3(0)
        for point in points {
            let diff = point - centroid
            covariance.columns.0 += diff.x * diff
            covariance.columns.1 += diff.y * diff
            covariance.columns.2 += diff.z * diff
        }
        
        // Simple approximation: use smallest eigenvector as normal
        // For a proper implementation, use SVD or eigendecomposition
        // This is a simplified version
        let normal = normalize(SIMD3<Float>(
            covariance.columns.1.z - covariance.columns.2.y,
            covariance.columns.2.x - covariance.columns.0.z,
            covariance.columns.0.y - covariance.columns.1.x
        ))
        
        let d = -dot(normal, centroid)
        
        return (normal, d)
    }
    
    // MARK: - Ghost Overlay (Swing Comparison)
    
    /// Record current swing for later comparison
    func recordSwing() -> RecordedSwing3D? {
        guard skeletonHistory.count >= 30 else {
            print("⚠️ Not enough data to record swing")
            return nil
        }
        
        let recording = RecordedSwing3D(
            id: UUID(),
            timestamp: Date(),
            skeletons: skeletonHistory,
            duration: Double(skeletonHistory.count) / 30.0
        )
        
        print("📹 Swing recorded: \(skeletonHistory.count) frames")
        return recording
    }
    
    /// Clear skeleton history
    func clearHistory() {
        skeletonHistory.removeAll()
        handPathPoints.removeAll()
    }
    
    // MARK: - Utility
    
    private func distance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        return simd_length(a - b)
    }
}

// MARK: - ARSessionDelegate

extension ARBodyTrackingManager: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let bodyAnchor = anchor as? ARBodyAnchor {
                self.bodyAnchor = bodyAnchor
                processBodyAnchor(bodyAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let bodyAnchor = anchor as? ARBodyAnchor {
                self.bodyAnchor = bodyAnchor
                processBodyAnchor(bodyAnchor)
                
                // Update avatar position if needed
                if let entity = bodyAnchorEntity {
                    entity.transform = Transform(matrix: bodyAnchor.transform)
                }
            }
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if anchor is ARBodyAnchor {
                DispatchQueue.main.async { [weak self] in
                    self?.isPersonDetected = false
                    self?.currentSkeleton = nil
                }
            }
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .notAvailable:
            trackingQuality = .notAvailable
        case .limited(let reason):
            trackingQuality = .limited
            print("⚠️ Tracking limited: \(reason)")
        case .normal:
            trackingQuality = .good
        }
    }
}

// MARK: - Supporting Types

/// 3D skeleton with all joints
struct Skeleton3D {
    let timestamp: Date
    let joints: [String: Joint3D]
    let rootTransform: simd_float4x4
    let estimatedHeight: Float
    
    /// Get position of a named joint
    func position(of jointName: String) -> SIMD3<Float>? {
        return joints[jointName]?.position
    }
    
    /// Calculate angle between three joints
    func angle(from a: String, through b: String, to c: String) -> Float? {
        guard let posA = position(of: a),
              let posB = position(of: b),
              let posC = position(of: c) else {
            return nil
        }
        
        let v1 = normalize(posA - posB)
        let v2 = normalize(posC - posB)
        
        return acos(dot(v1, v2)) * 180 / .pi
    }
}

/// Single joint in 3D space
struct Joint3D {
    let name: String
    let position: SIMD3<Float>       // In meters
    let rotation: simd_float3x3
    let localTransform: simd_float4x4
    let worldTransform: simd_float4x4
    let isTracked: Bool
}

/// Body measurements derived from skeleton
struct BodyMeasurements {
    let stanceWidthCm: Float
    let shoulderWidthCm: Float
    let armSpanCm: Float
    let heightCm: Float
}

/// Recorded swing for ghost overlay
struct RecordedSwing3D: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let skeletons: [Skeleton3D]
    let duration: TimeInterval
    
    // Codable conformance requires custom implementation for SIMD types
    enum CodingKeys: String, CodingKey {
        case id, timestamp, duration
    }
    
    init(id: UUID, timestamp: Date, skeletons: [Skeleton3D], duration: TimeInterval) {
        self.id = id
        self.timestamp = timestamp
        self.skeletons = skeletons
        self.duration = duration
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        skeletons = [] // Would need custom serialization for SIMD types
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(duration, forKey: .duration)
        // Skeleton serialization would need custom handling
    }
}

/// 3D swing data
struct SwingData3D {
    let startTime: Date
    let endTime: Date
    let skeletons: [Skeleton3D]
    let swingPlane: (normal: SIMD3<Float>, points: [SIMD3<Float>])?
    let handPath: [SIMD3<Float>]
}

/// Tracking quality level
enum TrackingQuality {
    case notAvailable
    case poor
    case limited
    case good
    
    var description: String {
        switch self {
        case .notAvailable: return "Not Available"
        case .poor: return "Poor"
        case .limited: return "Limited"
        case .good: return "Good"
        }
    }
    
    var color: String {
        switch self {
        case .notAvailable: return "gray"
        case .poor: return "red"
        case .limited: return "yellow"
        case .good: return "green"
        }
    }
}

/// Avatar styles
enum AvatarStyle: String, CaseIterable {
    case robot = "Robot"
    case golfer = "Golfer"
    case skeleton = "Skeleton"
    case points = "Points"
}

/// Settings for LiDAR 3D features
struct LiDAR3DSettings: Codable {
    var showAvatar = true
    var avatarStyle: AvatarStyle = .skeleton
    var showSwingPlane = true
    var showRealMeasurements = true
    var showGhostOverlay = false
    var ghostOpacity: Float = 0.5
    var swingPlaneColor: String = "green"
    
    enum CodingKeys: String, CodingKey {
        case showAvatar, showSwingPlane, showRealMeasurements
        case showGhostOverlay, ghostOpacity, swingPlaneColor
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showAvatar = try container.decodeIfPresent(Bool.self, forKey: .showAvatar) ?? true
        showSwingPlane = try container.decodeIfPresent(Bool.self, forKey: .showSwingPlane) ?? true
        showRealMeasurements = try container.decodeIfPresent(Bool.self, forKey: .showRealMeasurements) ?? true
        showGhostOverlay = try container.decodeIfPresent(Bool.self, forKey: .showGhostOverlay) ?? false
        ghostOpacity = try container.decodeIfPresent(Float.self, forKey: .ghostOpacity) ?? 0.5
        swingPlaneColor = try container.decodeIfPresent(String.self, forKey: .swingPlaneColor) ?? "green"
        avatarStyle = .skeleton
    }
}

// Make Skeleton3D Codable (simplified - would need full implementation for production)
extension Skeleton3D: Codable {
    enum CodingKeys: String, CodingKey {
        case timestamp, estimatedHeight
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        estimatedHeight = try container.decode(Float.self, forKey: .estimatedHeight)
        joints = [:]
        rootTransform = matrix_identity_float4x4
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(estimatedHeight, forKey: .estimatedHeight)
    }
}
