import Foundation
import Vision
import AVFoundation
import CoreImage
import Combine

/// Detects human body poses from camera frames using Apple Vision framework
class PoseDetector: ObservableObject {
    
    // MARK: - Published State
    
    @Published var isDetecting = false
    @Published var currentPose: PoseFrame?
    @Published var detectionConfidence: Float = 0
    @Published var isPersonDetected = false
    @Published var isPersonInFrame = false
    @Published var personBoundingBox: CGRect = .zero
    
    // Alignment guidance
    @Published var alignmentStatus: AlignmentStatus = .searching
    @Published var alignmentMessage: String = "Position yourself in frame"
    
    // MARK: - Configuration
    
    /// Minimum confidence threshold for pose detection
    var minimumConfidence: Float = 0.5
    
    /// Whether to use 3D pose detection (iOS 17+)
    var use3DPose: Bool = false
    
    /// Frame rate for processing (reduce to save battery)
    var targetFrameRate: Int = 30
    
    // MARK: - Private Properties
    
    private var frameIndex = 0
    private var lastProcessedTime: Date?
    private let minimumFrameInterval: TimeInterval
    
    // Vision requests
    private lazy var bodyPoseRequest: VNDetectHumanBodyPoseRequest = {
        let request = VNDetectHumanBodyPoseRequest()
        return request
    }()
    
    // Callbacks
    var onPoseDetected: ((PoseFrame) -> Void)?
    var onPersonLost: (() -> Void)?
    var onAlignmentChanged: ((AlignmentStatus) -> Void)?
    
    // MARK: - Initialization
    
    init(targetFrameRate: Int = 30) {
        self.targetFrameRate = targetFrameRate
        self.minimumFrameInterval = 1.0 / Double(targetFrameRate)
    }
    
    // MARK: - Public Methods
    
    /// Start pose detection
    func startDetecting() {
        isDetecting = true
        frameIndex = 0
        lastProcessedTime = nil
        print("🎥 Pose detection started at \(targetFrameRate) fps")
    }
    
    /// Stop pose detection
    func stopDetecting() {
        isDetecting = false
        isPersonDetected = false
        alignmentStatus = .searching
        print("🎥 Pose detection stopped")
    }
    
    /// Process a camera frame for body pose
    func processFrame(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation = .up) {
        guard isDetecting else { return }
        
        // Throttle to target frame rate
        let now = Date()
        if let lastTime = lastProcessedTime,
           now.timeIntervalSince(lastTime) < minimumFrameInterval {
            return
        }
        lastProcessedTime = now
        
        // Create request handler
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        
        do {
            try handler.perform([bodyPoseRequest])
            
            // Process results
            if let observation = bodyPoseRequest.results?.first {
                processBodyPoseObservation(observation, timestamp: now)
            } else {
                handleNoDetection()
            }
        } catch {
            print("⚠️ Pose detection error: \(error.localizedDescription)")
        }
    }
    
    /// Process a CMSampleBuffer from camera
    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        processFrame(pixelBuffer)
    }
    
    /// Check if current pose is suitable for swing analysis
    func isPoseReadyForSwing() -> Bool {
        guard let pose = currentPose, pose.confidence > minimumConfidence else { return false }
        
        // Check essential joints are visible
        let hasEssentials = pose.leftShoulder != nil &&
                           pose.rightShoulder != nil &&
                           pose.leftHip != nil &&
                           pose.rightHip != nil
        
        return hasEssentials && alignmentStatus == .good
    }
    
    // MARK: - Private Methods
    
    private func processBodyPoseObservation(_ observation: VNHumanBodyPoseObservation, timestamp: Date) {
        frameIndex += 1
        
        // Extract body points
        let pose = extractPoseFrame(from: observation, timestamp: timestamp)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.currentPose = pose
            self.detectionConfidence = pose.confidence
            self.isPersonDetected = pose.confidence > self.minimumConfidence
            self.isPersonInFrame = true
            
            // Update alignment status
            self.updateAlignmentStatus(pose: pose)
            
            // Notify callback
            self.onPoseDetected?(pose)
        }
    }
    
    private func extractPoseFrame(from observation: VNHumanBodyPoseObservation, timestamp: Date) -> PoseFrame {
        var pose = PoseFrame(
            timestamp: timestamp,
            frameIndex: frameIndex,
            confidence: observation.confidence
        )
        
        // Extract recognized points
        // Note: Vision uses normalized coordinates (0-1) with origin at bottom-left
        
        // Head
        pose.nose = point(from: observation, joint: .nose)
        
        // Upper body
        pose.leftShoulder = point(from: observation, joint: .leftShoulder)
        pose.rightShoulder = point(from: observation, joint: .rightShoulder)
        pose.leftElbow = point(from: observation, joint: .leftElbow)
        pose.rightElbow = point(from: observation, joint: .rightElbow)
        pose.leftWrist = point(from: observation, joint: .leftWrist)
        pose.rightWrist = point(from: observation, joint: .rightWrist)
        
        // Lower body
        pose.leftHip = point(from: observation, joint: .leftHip)
        pose.rightHip = point(from: observation, joint: .rightHip)
        pose.leftKnee = point(from: observation, joint: .leftKnee)
        pose.rightKnee = point(from: observation, joint: .rightKnee)
        pose.leftAnkle = point(from: observation, joint: .leftAnkle)
        pose.rightAnkle = point(from: observation, joint: .rightAnkle)
        
        // Calculate derived angles
        pose.spineAngle = calculateSpineAngle(pose: pose)
        pose.hipRotation = calculateHipRotation(pose: pose)
        pose.shoulderRotation = calculateShoulderRotation(pose: pose)
        pose.leftArmAngle = calculateArmAngle(shoulder: pose.leftShoulder, elbow: pose.leftElbow, wrist: pose.leftWrist)
        pose.rightArmAngle = calculateArmAngle(shoulder: pose.rightShoulder, elbow: pose.rightElbow, wrist: pose.rightWrist)
        
        return pose
    }
    
    private func point(from observation: VNHumanBodyPoseObservation, joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
        guard let point = try? observation.recognizedPoint(joint),
              point.confidence > minimumConfidence else {
            return nil
        }
        // Convert from Vision coordinates (bottom-left origin) to standard (top-left origin)
        return CGPoint(x: point.location.x, y: 1 - point.location.y)
    }
    
    private func handleNoDetection() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.isPersonDetected {
                // Person was detected but now lost
                self.onPersonLost?()
            }
            
            self.isPersonDetected = false
            self.isPersonInFrame = false
            self.detectionConfidence = 0
            self.alignmentStatus = .searching
            self.alignmentMessage = "Position yourself in frame"
        }
    }
    
    // MARK: - Angle Calculations
    
    /// Calculate spine angle from vertical (degrees)
    private func calculateSpineAngle(pose: PoseFrame) -> Double? {
        guard let leftShoulder = pose.leftShoulder,
              let rightShoulder = pose.rightShoulder,
              let leftHip = pose.leftHip,
              let rightHip = pose.rightHip else { return nil }
        
        // Calculate midpoints
        let shoulderMid = CGPoint(
            x: (leftShoulder.x + rightShoulder.x) / 2,
            y: (leftShoulder.y + rightShoulder.y) / 2
        )
        let hipMid = CGPoint(
            x: (leftHip.x + rightHip.x) / 2,
            y: (leftHip.y + rightHip.y) / 2
        )
        
        // Calculate angle from vertical
        let deltaX = shoulderMid.x - hipMid.x
        let deltaY = shoulderMid.y - hipMid.y
        
        let angleRadians = atan2(deltaX, -deltaY) // negative y because screen coords
        return angleRadians * 180.0 / Double.pi
    }
    
    /// Calculate hip rotation (degrees from square to camera)
    private func calculateHipRotation(pose: PoseFrame) -> Double? {
        guard let leftHip = pose.leftHip, let rightHip = pose.rightHip else { return nil }
        
        // Use the width between hips as indicator of rotation
        // When square to camera, width is maximum
        // When rotated, width appears smaller
        let hipWidth = abs(rightHip.x - leftHip.x)
        
        // Typical hip width when square is ~0.15-0.25 in normalized coords
        // Estimate rotation from width compression
        let maxWidth: CGFloat = 0.25
        let compressionRatio = min(hipWidth / maxWidth, 1.0)
        
        // Convert to approximate angle (0 = square, 90 = profile)
        let angleRadians = acos(compressionRatio)
        return Double(angleRadians) * 180.0 / Double.pi
    }
    
    /// Calculate shoulder rotation (degrees from square to camera)
    private func calculateShoulderRotation(pose: PoseFrame) -> Double? {
        guard let leftShoulder = pose.leftShoulder, let rightShoulder = pose.rightShoulder else { return nil }
        
        let shoulderWidth = abs(rightShoulder.x - leftShoulder.x)
        let maxWidth: CGFloat = 0.35
        let compressionRatio = min(shoulderWidth / maxWidth, 1.0)
        
        let angleRadians = acos(compressionRatio)
        return Double(angleRadians) * 180.0 / Double.pi
    }
    
    /// Calculate angle at elbow joint (degrees)
    private func calculateArmAngle(shoulder: CGPoint?, elbow: CGPoint?, wrist: CGPoint?) -> Double? {
        guard let shoulder = shoulder, let elbow = elbow, let wrist = wrist else { return nil }
        
        // Vectors from elbow to shoulder and elbow to wrist
        let v1 = CGPoint(x: shoulder.x - elbow.x, y: shoulder.y - elbow.y)
        let v2 = CGPoint(x: wrist.x - elbow.x, y: wrist.y - elbow.y)
        
        // Dot product
        let dot = v1.x * v2.x + v1.y * v2.y
        
        // Magnitudes
        let mag1 = sqrt(v1.x * v1.x + v1.y * v1.y)
        let mag2 = sqrt(v2.x * v2.x + v2.y * v2.y)
        
        guard mag1 > 0 && mag2 > 0 else { return nil }
        
        // Angle
        let cosAngle = dot / (mag1 * mag2)
        let clampedCos = max(-1.0, min(1.0, cosAngle)) // Clamp for numerical stability
        let angleRadians = acos(clampedCos)
        
        return angleRadians * 180.0 / Double.pi
    }
    
    // MARK: - Alignment Status
    
    private func updateAlignmentStatus(pose: PoseFrame) {
        // Check if essential points are detected
        let hasUpperBody = pose.leftShoulder != nil && pose.rightShoulder != nil
        let hasLowerBody = pose.leftHip != nil && pose.rightHip != nil
        let _ = (pose.leftElbow != nil || pose.rightElbow != nil) &&
                (pose.leftWrist != nil || pose.rightWrist != nil) // hasArms - checked later
        
        // Check if person is properly positioned
        guard hasUpperBody && hasLowerBody else {
            alignmentStatus = .tooFar
            alignmentMessage = "Step closer or adjust camera angle"
            onAlignmentChanged?(alignmentStatus)
            return
        }
        
        // Check if person is centered
        if let leftShoulder = pose.leftShoulder, let rightShoulder = pose.rightShoulder {
            let centerX = (leftShoulder.x + rightShoulder.x) / 2
            if centerX < 0.25 {
                alignmentStatus = .tooLeft
                alignmentMessage = "Move right in frame"
                onAlignmentChanged?(alignmentStatus)
                return
            } else if centerX > 0.75 {
                alignmentStatus = .tooRight
                alignmentMessage = "Move left in frame"
                onAlignmentChanged?(alignmentStatus)
                return
            }
        }
        
        // Check if full body is visible
        if pose.leftAnkle == nil && pose.rightAnkle == nil {
            alignmentStatus = .tooClose
            alignmentMessage = "Step back to show full body"
            onAlignmentChanged?(alignmentStatus)
            return
        }
        
        // Check confidence
        if pose.confidence < 0.7 {
            alignmentStatus = .lowConfidence
            alignmentMessage = "Improve lighting or reduce movement"
            onAlignmentChanged?(alignmentStatus)
            return
        }
        
        // All good!
        alignmentStatus = .good
        alignmentMessage = "Ready to analyze swings"
        onAlignmentChanged?(alignmentStatus)
    }
}

// MARK: - Supporting Types

/// Status of person alignment in camera frame
enum AlignmentStatus: String {
    case searching = "Searching"
    case tooFar = "Too Far"
    case tooClose = "Too Close"
    case tooLeft = "Too Left"
    case tooRight = "Too Right"
    case lowConfidence = "Low Confidence"
    case good = "Good"
    
    var color: String {
        switch self {
        case .good: return "green"
        case .searching, .lowConfidence: return "yellow"
        default: return "orange"
        }
    }
    
    var systemImage: String {
        switch self {
        case .good: return "checkmark.circle.fill"
        case .searching: return "person.crop.circle.badge.questionmark"
        case .tooFar: return "arrow.up.forward"
        case .tooClose: return "arrow.down.backward"
        case .tooLeft: return "arrow.right"
        case .tooRight: return "arrow.left"
        case .lowConfidence: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Pose Frame Extension for Drawing

extension PoseFrame {
    /// Get all detected joint positions as an array for drawing
    var allJoints: [(name: String, point: CGPoint)] {
        var joints: [(String, CGPoint)] = []
        
        if let p = nose { joints.append(("Nose", p)) }
        if let p = leftShoulder { joints.append(("L Shoulder", p)) }
        if let p = rightShoulder { joints.append(("R Shoulder", p)) }
        if let p = leftElbow { joints.append(("L Elbow", p)) }
        if let p = rightElbow { joints.append(("R Elbow", p)) }
        if let p = leftWrist { joints.append(("L Wrist", p)) }
        if let p = rightWrist { joints.append(("R Wrist", p)) }
        if let p = leftHip { joints.append(("L Hip", p)) }
        if let p = rightHip { joints.append(("R Hip", p)) }
        if let p = leftKnee { joints.append(("L Knee", p)) }
        if let p = rightKnee { joints.append(("R Knee", p)) }
        if let p = leftAnkle { joints.append(("L Ankle", p)) }
        if let p = rightAnkle { joints.append(("R Ankle", p)) }
        
        return joints
    }
    
    /// Get bone connections for skeleton drawing
    var boneConnections: [(CGPoint, CGPoint)] {
        var bones: [(CGPoint, CGPoint)] = []
        
        // Spine
        if let ls = leftShoulder, let rs = rightShoulder,
           let lh = leftHip, let rh = rightHip {
            let shoulderMid = CGPoint(x: (ls.x + rs.x) / 2, y: (ls.y + rs.y) / 2)
            let hipMid = CGPoint(x: (lh.x + rh.x) / 2, y: (lh.y + rh.y) / 2)
            bones.append((shoulderMid, hipMid))
        }
        
        // Shoulders
        if let ls = leftShoulder, let rs = rightShoulder {
            bones.append((ls, rs))
        }
        
        // Left arm
        if let s = leftShoulder, let e = leftElbow { bones.append((s, e)) }
        if let e = leftElbow, let w = leftWrist { bones.append((e, w)) }
        
        // Right arm
        if let s = rightShoulder, let e = rightElbow { bones.append((s, e)) }
        if let e = rightElbow, let w = rightWrist { bones.append((e, w)) }
        
        // Hips
        if let lh = leftHip, let rh = rightHip {
            bones.append((lh, rh))
        }
        
        // Left leg
        if let h = leftHip, let k = leftKnee { bones.append((h, k)) }
        if let k = leftKnee, let a = leftAnkle { bones.append((k, a)) }
        
        // Right leg
        if let h = rightHip, let k = rightKnee { bones.append((h, k)) }
        if let k = rightKnee, let a = rightAnkle { bones.append((k, a)) }
        
        return bones
    }
}
