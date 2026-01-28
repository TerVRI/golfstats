import Foundation
import ARKit
import RealityKit
import Combine
import UIKit

/// ARKit-based 3D body tracking using LiDAR sensor
/// Provides full skeletal mesh tracking with depth information
@available(iOS 14.0, *)
class ARBodyTracker: NSObject, ObservableObject, BodyPoseProvider {
    
    // MARK: - Published State
    
    @Published private(set) var isDetecting = false
    @Published var currentPose: PoseFrame?
    @Published var alignmentStatus: AlignmentStatus = .searching
    @Published var alignmentMessage: String = "Point camera at person"
    
    // 3D-specific state
    @Published var bodyAnchor: ARBodyAnchor?
    @Published var hasBodyMesh = false
    
    // MARK: - BodyPoseProvider Conformance
    
    var currentPosePublisher: AnyPublisher<PoseFrame?, Never> {
        $currentPose.eraseToAnyPublisher()
    }
    
    var alignmentStatusPublisher: AnyPublisher<AlignmentStatus, Never> {
        $alignmentStatus.eraseToAnyPublisher()
    }
    
    var alignmentMessagePublisher: AnyPublisher<String, Never> {
        $alignmentMessage.eraseToAnyPublisher()
    }
    
    var supports3D: Bool { true }
    var requiresSpecialHardware: Bool { true }
    
    static func isAvailable() -> Bool {
        return ARBodyTrackingConfiguration.isSupported
    }
    
    // MARK: - ARKit Components
    
    private(set) var arView: ARView?
    private var bodyEntity: BodyTrackedEntity?
    private var skeletonEntity: Entity?
    
    // MARK: - Configuration
    
    /// Whether to show the full body mesh or just skeleton
    var showBodyMesh = false {
        didSet {
            updateBodyVisualization()
        }
    }
    
    /// Whether to show skeleton overlay on the AR view
    var showSkeleton = true {
        didSet {
            updateBodyVisualization()
        }
    }
    
    // MARK: - Private Properties
    
    private var frameIndex = 0
    private var cancellables = Set<AnyCancellable>()
    
    /// One-Euro Filter smoother for reducing joint jitter
    private let poseSmoother = PoseSmoother(minCutoff: 1.5, beta: 0.5, dCutoff: 1.0)
    
    // Joint mapping from ARKit 3D body joint names to our pose frame names
    // ARKit body tracking uses string-based joint names
    private let jointMapping: [String: String] = [
        "head_joint": "head",
        "left_shoulder_1_joint": "leftShoulder",
        "right_shoulder_1_joint": "rightShoulder",
        "left_forearm_joint": "leftElbow",
        "right_forearm_joint": "rightElbow",
        "left_hand_joint": "leftWrist",
        "right_hand_joint": "rightWrist",
        "left_upLeg_joint": "leftHip",
        "right_upLeg_joint": "rightHip",
        "left_leg_joint": "leftKnee",
        "right_leg_joint": "rightKnee",
        "left_foot_joint": "leftAnkle",
        "right_foot_joint": "rightAnkle"
    ]
    
    // MARK: - Initialization
    
    override init() {
        super.init()
    }
    
    /// Create and configure the AR view
    func createARView(frame: CGRect) -> ARView {
        let view = ARView(frame: frame)
        view.automaticallyConfigureSession = false
        
        // Configure for body tracking
        view.environment.background = .cameraFeed()
        
        self.arView = view
        return view
    }
    
    // MARK: - BodyPoseProvider Methods
    
    func startDetecting() {
        print("🎥 ARBodyTracker.startDetecting() called")
        
        guard !isDetecting else {
            print("🎥 ARBodyTracker: Already detecting, skipping")
            return
        }
        
        guard ARBodyTracker.isAvailable() else {
            alignmentStatus = .searching
            alignmentMessage = "Body tracking not supported on this device"
            print("⚠️ ARBodyTrackingConfiguration not supported on this device")
            return
        }
        
        guard let arView = arView else {
            print("⚠️ ARBodyTracker: ARView is nil. Call createARView() first.")
            return
        }
        
        print("🎥 ARBodyTracker: Configuring ARBodyTrackingConfiguration...")
        
        // Configure body tracking
        let configuration = ARBodyTrackingConfiguration()
        configuration.automaticSkeletonScaleEstimationEnabled = true
        configuration.frameSemantics.insert(.bodyDetection)
        
        // Enable scene depth if available (LiDAR)
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            // LiDAR is available - we get better depth
            print("🎯 LiDAR sensor detected - enhanced depth tracking enabled")
        }
        
        // Set delegate
        arView.session.delegate = self
        print("🎥 ARBodyTracker: Session delegate set, running configuration...")
        
        // Start session
        arView.session.run(configuration)
        
        isDetecting = true
        frameIndex = 0
        
        print("🎥 AR body tracking started successfully")
    }
    
    func stopDetecting() {
        guard isDetecting else { return }
        
        arView?.session.pause()
        
        // Clean up entities
        bodyEntity?.removeFromParent()
        skeletonEntity?.removeFromParent()
        bodyEntity = nil
        skeletonEntity = nil
        
        isDetecting = false
        bodyAnchor = nil
        hasBodyMesh = false
        alignmentStatus = .searching
        alignmentMessage = "Point camera at person"
        poseSmoother.reset() // Reset filter state for next session
        
        print("🎥 AR body tracking stopped")
    }
    
    // MARK: - Body Visualization
    
    private func updateBodyVisualization() {
        guard let anchor = bodyAnchor else { return }
        
        if showBodyMesh {
            loadBodyMesh(for: anchor)
        } else {
            bodyEntity?.removeFromParent()
            bodyEntity = nil
        }
        
        if showSkeleton {
            updateSkeletonVisualization(for: anchor)
        } else {
            skeletonEntity?.removeFromParent()
            skeletonEntity = nil
        }
    }
    
    private func loadBodyMesh(for anchor: ARBodyAnchor) {
        guard let arView = arView else { return }
        
        // Only create once
        if bodyEntity == nil {
            // Create body tracked entity with robot character
            // In production, you might want a custom mesh or transparent overlay
            if let robot = try? Entity.loadBodyTracked(named: "robot") {
                bodyEntity = robot
                
                // Make semi-transparent
                robot.scale = [1.0, 1.0, 1.0]
                
                // Create anchor entity for the body
                let anchorEntity = AnchorEntity(.body)
                anchorEntity.addChild(robot)
                arView.scene.addAnchor(anchorEntity)
            } else {
                // Fallback: create simple skeleton visualization
                print("⚠️ Could not load body mesh, using skeleton only")
            }
        }
    }
    
    private func updateSkeletonVisualization(for anchor: ARBodyAnchor) {
        // Skeleton is drawn in the overlay view, not in AR scene
        // This method could be used for AR-native skeleton rendering if desired
    }
    
    // MARK: - Pose Extraction
    
    private func extractPoseFrame(from bodyAnchor: ARBodyAnchor, in frame: ARFrame) -> PoseFrame {
        frameIndex += 1
        
        var builder = PoseFrameBuilder(
            timestamp: Date(),
            frameIndex: frameIndex,
            confidence: bodyAnchor.isTracked ? 0.9 : 0.3
        )
        
        let skeleton = bodyAnchor.skeleton
        let viewportSize = arView?.bounds.size ?? CGSize(width: 1, height: 1)
        
        // Debug: Log skeleton info
        print("🦴 Skeleton has \(skeleton.jointModelTransforms.count) joint transforms, viewport: \(viewportSize)")
        
        // Debug: Print all available joint names
        if frameIndex <= 2 {
            print("🦴 Available joints in skeleton definition:")
            for i in 0..<skeleton.definition.jointCount {
                let name = skeleton.definition.jointNames[i]
                print("   - \(i): \(name)")
            }
        }
        
        // Extract 2D projected positions for each joint using string-based joint names
        var projectedCount = 0
        var failedJoints: [String] = []
        
        func projectJoint(_ jointName: String) -> CGPoint? {
            // Get joint index from skeleton definition
            let jointIndex = skeleton.definition.index(for: ARSkeleton.JointName(rawValue: jointName))
            if jointIndex == NSNotFound {
                failedJoints.append("\(jointName): index not found")
                return nil
            }
            
            let transform = skeleton.jointModelTransforms[jointIndex]
            
            // Get joint position in world space
            let jointWorldPosition = bodyAnchor.transform * transform
            let position = SIMD3<Float>(
                jointWorldPosition.columns.3.x,
                jointWorldPosition.columns.3.y,
                jointWorldPosition.columns.3.z
            )
            
            // Project to screen coordinates
            guard let arView = arView else {
                failedJoints.append("\(jointName): arView is nil")
                return nil
            }
            
            let screenPoint = arView.project(position)
            
            guard let point = screenPoint else {
                failedJoints.append("\(jointName): project returned nil (pos: \(position))")
                return nil
            }
            
            // Check if point is within viewport (0-1 normalized range with some margin)
            let normalizedX = point.x / viewportSize.width
            let normalizedY = point.y / viewportSize.height
            
            // Allow points slightly outside viewport
            guard normalizedX > -0.5 && normalizedX < 1.5 &&
                  normalizedY > -0.5 && normalizedY < 1.5 else {
                failedJoints.append("\(jointName): out of bounds (\(normalizedX), \(normalizedY))")
                return nil
            }
            
            projectedCount += 1
            return CGPoint(x: normalizedX, y: normalizedY)
        }
        
        // Map ARKit joints to pose frame using string-based joint names
        builder.nose = projectJoint("head_joint")
        builder.leftShoulder = projectJoint("left_shoulder_1_joint")
        builder.rightShoulder = projectJoint("right_shoulder_1_joint")
        builder.leftElbow = projectJoint("left_forearm_joint")
        builder.rightElbow = projectJoint("right_forearm_joint")
        builder.leftWrist = projectJoint("left_hand_joint")
        builder.rightWrist = projectJoint("right_hand_joint")
        builder.leftHip = projectJoint("left_upLeg_joint")
        builder.rightHip = projectJoint("right_upLeg_joint")
        builder.leftKnee = projectJoint("left_leg_joint")
        builder.rightKnee = projectJoint("right_leg_joint")
        builder.leftAnkle = projectJoint("left_foot_joint")
        builder.rightAnkle = projectJoint("right_foot_joint")
        
        // Debug: Log projected joint count and failures
        print("🦴 Projected \(projectedCount)/13 joints to screen")
        if !failedJoints.isEmpty && frameIndex <= 5 {
            print("🦴 Failed joints:")
            for failure in failedJoints {
                print("   - \(failure)")
            }
        }
        
        // Extract 3D joint positions
        var joints3D: [PoseJoint3D] = []
        for (arJointName, poseName) in jointMapping {
            let jointIndex = skeleton.definition.index(for: ARSkeleton.JointName(rawValue: arJointName))
            guard jointIndex != NSNotFound else { continue }
            
            let transform = skeleton.jointModelTransforms[jointIndex]
            let worldTransform = bodyAnchor.transform * transform
            let position = SIMD3<Float>(
                worldTransform.columns.3.x,
                worldTransform.columns.3.y,
                worldTransform.columns.3.z
            )
            
            let screenPos = arView?.project(position) ?? .zero
            let normalizedScreen = CGPoint(
                x: screenPos.x / viewportSize.width,
                y: screenPos.y / viewportSize.height
            )
            
            joints3D.append(PoseJoint3D(
                name: poseName,
                position: position,
                screenPosition: normalizedScreen,
                confidence: bodyAnchor.isTracked ? 0.95 : 0.5
            ))
        }
        builder.joints3D = joints3D
        
        // Calculate derived angles (same as 2D version)
        builder.spineAngle = calculateSpineAngle(builder: builder)
        builder.hipRotation = calculateHipRotation(builder: builder)
        builder.shoulderRotation = calculateShoulderRotation(builder: builder)
        
        return builder.build()
    }
    
    // MARK: - Angle Calculations (3D-aware)
    
    private func calculateSpineAngle(builder: PoseFrameBuilder) -> Double? {
        guard let leftShoulder = builder.leftShoulder,
              let rightShoulder = builder.rightShoulder,
              let leftHip = builder.leftHip,
              let rightHip = builder.rightHip else { return nil }
        
        let shoulderMid = CGPoint(
            x: (leftShoulder.x + rightShoulder.x) / 2,
            y: (leftShoulder.y + rightShoulder.y) / 2
        )
        let hipMid = CGPoint(
            x: (leftHip.x + rightHip.x) / 2,
            y: (leftHip.y + rightHip.y) / 2
        )
        
        let deltaX = shoulderMid.x - hipMid.x
        let deltaY = shoulderMid.y - hipMid.y
        
        let angleRadians = atan2(deltaX, -deltaY)
        return angleRadians * 180.0 / Double.pi
    }
    
    private func calculateHipRotation(builder: PoseFrameBuilder) -> Double? {
        // For 3D mode, we can calculate true rotation from 3D positions
        if let joints3D = builder.joints3D,
           let leftHip = joints3D.first(where: { $0.name == "leftHip" }),
           let rightHip = joints3D.first(where: { $0.name == "rightHip" }) {
            
            // Calculate angle from the hip line to the camera's forward vector
            let hipVector = SIMD3<Float>(
                rightHip.position.x - leftHip.position.x,
                0, // Ignore vertical
                rightHip.position.z - leftHip.position.z
            )
            
            // Camera faces -Z in ARKit
            let forwardVector = SIMD3<Float>(0, 0, -1)
            
            // Calculate angle between hip line and camera forward
            let dot = simd_dot(simd_normalize(hipVector), forwardVector)
            let angleRadians = acos(abs(dot))
            
            return Double(angleRadians) * 180.0 / Double.pi
        }
        
        // Fallback to 2D calculation
        guard let leftHip = builder.leftHip, let rightHip = builder.rightHip else { return nil }
        
        let hipWidth = abs(rightHip.x - leftHip.x)
        let maxWidth: CGFloat = 0.25
        let compressionRatio = min(hipWidth / maxWidth, 1.0)
        
        let angleRadians = acos(compressionRatio)
        return Double(angleRadians) * 180.0 / Double.pi
    }
    
    private func calculateShoulderRotation(builder: PoseFrameBuilder) -> Double? {
        // For 3D mode, calculate true rotation
        if let joints3D = builder.joints3D,
           let leftShoulder = joints3D.first(where: { $0.name == "leftShoulder" }),
           let rightShoulder = joints3D.first(where: { $0.name == "rightShoulder" }) {
            
            let shoulderVector = SIMD3<Float>(
                rightShoulder.position.x - leftShoulder.position.x,
                0,
                rightShoulder.position.z - leftShoulder.position.z
            )
            
            let forwardVector = SIMD3<Float>(0, 0, -1)
            let dot = simd_dot(simd_normalize(shoulderVector), forwardVector)
            let angleRadians = acos(abs(dot))
            
            return Double(angleRadians) * 180.0 / Double.pi
        }
        
        // Fallback to 2D
        guard let leftShoulder = builder.leftShoulder, let rightShoulder = builder.rightShoulder else { return nil }
        
        let shoulderWidth = abs(rightShoulder.x - leftShoulder.x)
        let maxWidth: CGFloat = 0.35
        let compressionRatio = min(shoulderWidth / maxWidth, 1.0)
        
        let angleRadians = acos(compressionRatio)
        return Double(angleRadians) * 180.0 / Double.pi
    }
    
    // MARK: - Alignment Status
    
    private func updateAlignmentStatus(pose: PoseFrame, isTracked: Bool) {
        guard isTracked else {
            alignmentStatus = .searching
            alignmentMessage = "Looking for person..."
            return
        }
        
        let hasUpperBody = pose.leftShoulder != nil && pose.rightShoulder != nil
        let hasLowerBody = pose.leftHip != nil && pose.rightHip != nil
        
        guard hasUpperBody && hasLowerBody else {
            alignmentStatus = .tooFar
            alignmentMessage = "Step closer or adjust camera"
            return
        }
        
        // Check centering
        if let leftShoulder = pose.leftShoulder, let rightShoulder = pose.rightShoulder {
            let centerX = (leftShoulder.x + rightShoulder.x) / 2
            if centerX < 0.2 {
                alignmentStatus = .tooLeft
                alignmentMessage = "Move right in frame"
                return
            } else if centerX > 0.8 {
                alignmentStatus = .tooRight
                alignmentMessage = "Move left in frame"
                return
            }
        }
        
        // Good!
        alignmentStatus = .good
        alignmentMessage = "Ready - 3D tracking active"
        hasBodyMesh = true
    }
}

// MARK: - ARSessionDelegate

@available(iOS 14.0, *)
extension ARBodyTracker: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Body tracking is handled through anchors
        // This is called every frame - the camera feed is working
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("⚠️ AR session was interrupted")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        print("🎥 AR session interruption ended, resuming...")
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let body = anchor as? ARBodyAnchor {
                print("🦴 ARBodyAnchor ADDED - isTracked: \(body.isTracked)")
                bodyAnchor = body
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    let rawPose = self.extractPoseFrame(from: body, in: session.currentFrame!)
                    print("🦴 Extracted pose - joints: \(rawPose.allJoints.count), confidence: \(rawPose.confidence)")
                    // Apply One-Euro Filter smoothing
                    let pose = self.poseSmoother.smooth(rawPose)
                    self.currentPose = pose
                    self.updateAlignmentStatus(pose: pose, isTracked: body.isTracked)
                    self.updateBodyVisualization()
                }
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let body = anchor as? ARBodyAnchor {
                bodyAnchor = body
                
                guard let frame = session.currentFrame else { continue }
                
                // Log every 30 frames (~1 second) to avoid spam
                if frameIndex % 30 == 0 {
                    print("🦴 ARBodyAnchor UPDATE #\(frameIndex) - isTracked: \(body.isTracked)")
                }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    let rawPose = self.extractPoseFrame(from: body, in: frame)
                    // Apply One-Euro Filter smoothing
                    let pose = self.poseSmoother.smooth(rawPose)
                    self.currentPose = pose
                    self.updateAlignmentStatus(pose: pose, isTracked: body.isTracked)
                    
                    // Log joint count periodically
                    if self.frameIndex % 30 == 0 {
                        print("🦴 Pose joints: \(pose.allJoints.count)")
                    }
                }
            }
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if anchor is ARBodyAnchor {
                bodyAnchor = nil
                hasBodyMesh = false
                poseSmoother.reset() // Reset smoother when body is lost
                
                DispatchQueue.main.async { [weak self] in
                    self?.alignmentStatus = .searching
                    self?.alignmentMessage = "Person lost - point camera at golfer"
                }
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("⚠️ AR session error: \(error.localizedDescription)")
        
        DispatchQueue.main.async { [weak self] in
            self?.alignmentStatus = .searching
            self?.alignmentMessage = "AR error: \(error.localizedDescription)"
        }
    }
}
