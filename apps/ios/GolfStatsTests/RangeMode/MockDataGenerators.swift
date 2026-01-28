import Foundation
import simd
@testable import GolfStats

/// Generates mock data for testing Range Mode components
enum MockDataGenerators {
    
    // MARK: - Pose Generation
    
    /// Generate a sequence of poses simulating a golf swing
    static func generateSwingSequence(
        duration: TimeInterval = 1.2,
        fps: Int = 30,
        swingType: MockSwingType = .normal
    ) -> [PoseFrame] {
        var poses: [PoseFrame] = []
        let frameCount = Int(duration * Double(fps))
        let startTime = Date()
        
        for i in 0..<frameCount {
            let progress = Double(i) / Double(frameCount)
            let timestamp = startTime.addingTimeInterval(Double(i) / Double(fps))
            let pose = generatePoseAtProgress(progress, frameIndex: i, timestamp: timestamp, swingType: swingType)
            poses.append(pose)
        }
        
        return poses
    }
    
    /// Generate pose at specific swing progress (0 = setup, 0.5 = top, 1.0 = finish)
    static func generatePoseAtProgress(
        _ progress: Double,
        frameIndex: Int = 0,
        timestamp: Date = Date(),
        swingType: MockSwingType = .normal
    ) -> PoseFrame {
        var pose = PoseFrame(
            timestamp: timestamp,
            frameIndex: frameIndex,
            confidence: 0.95
        )
        
        // Base position (golfer at address)
        let baseX: CGFloat = 0.5
        let baseY: CGFloat = 0.5
        
        // Calculate phase-specific body positions
        let (shoulderRotation, hipRotation, spineAngle) = calculateBodyAngles(progress: progress, swingType: swingType)
        
        // Apply rotations to generate joint positions
        let shoulderWidth: CGFloat = 0.3 * CGFloat(cos(shoulderRotation * .pi / 180))
        let hipWidth: CGFloat = 0.2 * CGFloat(cos(hipRotation * .pi / 180))
        
        // Head/Nose - slight lateral movement allowed
        let headSway = progress < 0.5 ? progress * 0.02 : (1 - progress) * 0.02
        pose.nose = CGPoint(x: baseX + CGFloat(headSway), y: 0.15)
        
        // Shoulders
        pose.leftShoulder = CGPoint(x: baseX - shoulderWidth/2, y: 0.3)
        pose.rightShoulder = CGPoint(x: baseX + shoulderWidth/2, y: 0.3)
        
        // Elbows - arms move during swing
        let elbowOffset = calculateElbowPosition(progress: progress)
        pose.leftElbow = CGPoint(x: baseX - 0.15 + elbowOffset.x, y: 0.45 + elbowOffset.y)
        pose.rightElbow = CGPoint(x: baseX + 0.15 - elbowOffset.x, y: 0.45 + elbowOffset.y)
        
        // Wrists - hands come together at address and impact
        let wristOffset = calculateWristPosition(progress: progress)
        pose.leftWrist = CGPoint(x: baseX - 0.05 + wristOffset.x, y: 0.55 + wristOffset.y)
        pose.rightWrist = CGPoint(x: baseX + 0.05 + wristOffset.x, y: 0.55 + wristOffset.y)
        
        // Hips
        pose.leftHip = CGPoint(x: baseX - hipWidth/2, y: 0.55)
        pose.rightHip = CGPoint(x: baseX + hipWidth/2, y: 0.55)
        
        // Knees
        pose.leftKnee = CGPoint(x: baseX - 0.1, y: 0.72)
        pose.rightKnee = CGPoint(x: baseX + 0.1, y: 0.72)
        
        // Ankles
        pose.leftAnkle = CGPoint(x: baseX - 0.12, y: 0.9)
        pose.rightAnkle = CGPoint(x: baseX + 0.12, y: 0.9)
        
        // Set calculated angles
        pose.shoulderRotation = shoulderRotation
        pose.hipRotation = hipRotation
        pose.spineAngle = spineAngle
        
        return pose
    }
    
    private static func calculateBodyAngles(progress: Double, swingType: MockSwingType) -> (shoulder: Double, hip: Double, spine: Double) {
        let params = swingType.parameters
        
        let shoulderRotation: Double
        let hipRotation: Double
        let spineAngle: Double
        
        if progress < 0.1 {
            // Setup
            shoulderRotation = 0
            hipRotation = 0
            spineAngle = params.setupSpineAngle
        } else if progress < 0.45 {
            // Backswing (0.1 -> 0.45)
            let backswingProgress = (progress - 0.1) / 0.35
            shoulderRotation = backswingProgress * params.maxShoulderTurn
            hipRotation = backswingProgress * params.maxHipTurn
            spineAngle = params.setupSpineAngle + (backswingProgress * params.spineAngleChange)
        } else if progress < 0.55 {
            // Top of swing (0.45 -> 0.55)
            shoulderRotation = params.maxShoulderTurn
            hipRotation = params.maxHipTurn
            spineAngle = params.setupSpineAngle + params.spineAngleChange
        } else if progress < 0.75 {
            // Downswing (0.55 -> 0.75)
            let downswingProgress = (progress - 0.55) / 0.2
            shoulderRotation = params.maxShoulderTurn * (1 - downswingProgress * 1.2) // Overshoots slightly
            hipRotation = params.maxHipTurn * (1 - downswingProgress * 1.5) // Hips lead
            spineAngle = params.setupSpineAngle + params.spineAngleChange * (1 - downswingProgress)
        } else {
            // Follow through (0.75 -> 1.0)
            let followProgress = (progress - 0.75) / 0.25
            shoulderRotation = -params.maxShoulderTurn * 0.3 * followProgress // Rotates through
            hipRotation = -params.maxHipTurn * 0.5 * followProgress
            spineAngle = params.setupSpineAngle
        }
        
        return (shoulderRotation, hipRotation, spineAngle)
    }
    
    private static func calculateElbowPosition(progress: Double) -> CGPoint {
        // Elbows move during backswing and follow through
        if progress < 0.45 {
            // Backswing - elbows rise
            let backswingProgress = progress / 0.45
            return CGPoint(x: -backswingProgress * 0.1, y: -backswingProgress * 0.15)
        } else if progress < 0.75 {
            // Downswing - elbows drop
            let downswingProgress = (progress - 0.45) / 0.3
            return CGPoint(x: -0.1 + downswingProgress * 0.1, y: -0.15 + downswingProgress * 0.15)
        } else {
            // Follow through
            let followProgress = (progress - 0.75) / 0.25
            return CGPoint(x: followProgress * 0.05, y: -followProgress * 0.1)
        }
    }
    
    private static func calculateWristPosition(progress: Double) -> CGPoint {
        // Wrists/hands follow club through swing
        if progress < 0.45 {
            // Backswing
            let backswingProgress = progress / 0.45
            return CGPoint(x: -backswingProgress * 0.2, y: -backswingProgress * 0.25)
        } else if progress < 0.75 {
            // Downswing
            let downswingProgress = (progress - 0.45) / 0.3
            return CGPoint(x: -0.2 + downswingProgress * 0.25, y: -0.25 + downswingProgress * 0.3)
        } else {
            // Follow through
            let followProgress = (progress - 0.75) / 0.25
            return CGPoint(x: 0.05 + followProgress * 0.15, y: 0.05 - followProgress * 0.2)
        }
    }
    
    // MARK: - Motion Sample Generation
    
    /// Generate Watch motion data for a swing
    static func generateSwingMotion(
        peakGForce: Double = 10.0,
        duration: TimeInterval = 1.2,
        sampleRate: Int = 100
    ) -> [MotionSample] {
        var samples: [MotionSample] = []
        let sampleCount = Int(duration * Double(sampleRate))
        let startTime = Date()
        
        for i in 0..<sampleCount {
            let t = Double(i) / Double(sampleRate)
            let progress = t / duration
            
            // Acceleration curve: builds through downswing, peaks at impact
            let accel: Double
            if progress < 0.45 {
                // Backswing - moderate acceleration
                accel = 2.0 + progress * 3.0
            } else if progress < 0.7 {
                // Downswing - rapid buildup
                let downswingProgress = (progress - 0.45) / 0.25
                accel = 5.0 + downswingProgress * (peakGForce - 5.0)
            } else if progress < 0.72 {
                // Impact - peak
                accel = peakGForce
            } else {
                // Follow through - deceleration
                let followProgress = (progress - 0.72) / 0.28
                accel = peakGForce * (1 - followProgress * 0.7)
            }
            
            // Rotation rate follows similar pattern
            let rotation = accel * 1.2
            
            samples.append(MotionSample(
                timestamp: startTime.addingTimeInterval(t),
                index: i,
                acceleration: (x: accel * 0.7, y: accel * 0.5, z: accel * 0.3),
                rotation: (x: rotation * 0.3, y: rotation * 0.8, z: rotation * 0.2)
            ))
        }
        
        return samples
    }
    
    // MARK: - Combined Swing Generation
    
    /// Generate a complete swing with both camera and Watch data
    static func generateCombinedSwingCapture(
        swingType: MockSwingType = .normal,
        includeWatch: Bool = true
    ) -> CombinedSwingCapture {
        let timestamp = Date()
        var capture = CombinedSwingCapture(timestamp: timestamp)
        
        // Generate camera data
        let poses = generateSwingSequence(swingType: swingType)
        let phases = generatePhaseMarkers(from: poses)
        
        capture.cameraCapture = CameraSwingCapture(
            startTime: poses.first?.timestamp ?? timestamp,
            endTime: poses.last?.timestamp ?? timestamp,
            poseFrames: poses,
            phases: phases,
            bodyMetrics: generateBodyMetrics(from: poses)
        )
        
        // Generate Watch data
        if includeWatch {
            let motionSamples = generateSwingMotion(peakGForce: swingType.parameters.peakGForce)
            
            capture.watchMotionData = WatchMotionCapture(
                startTime: motionSamples.first?.timestamp ?? timestamp,
                endTime: motionSamples.last?.timestamp ?? timestamp,
                samples: motionSamples,
                metrics: generateWatchMetrics(from: motionSamples, swingType: swingType)
            )
        }
        
        // Calculate combined metrics
        capture.combinedMetrics = generateCombinedMetrics(
            camera: capture.cameraCapture,
            watch: capture.watchMotionData
        )
        
        return capture
    }
    
    private static func generatePhaseMarkers(from poses: [PoseFrame]) -> [SwingPhaseMarker] {
        var markers: [SwingPhaseMarker] = []
        let phases: [(CameraSwingPhase, Double)] = [
            (.setup, 0.0),
            (.takeaway, 0.1),
            (.backswing, 0.2),
            (.topOfSwing, 0.45),
            (.downswing, 0.55),
            (.impact, 0.72),
            (.followThrough, 0.8),
            (.finish, 0.95)
        ]
        
        for (phase, progress) in phases {
            let frameIndex = Int(progress * Double(poses.count - 1))
            if frameIndex < poses.count {
                markers.append(SwingPhaseMarker(
                    phase: phase,
                    timestamp: poses[frameIndex].timestamp,
                    frameIndex: frameIndex,
                    confidence: 0.9
                ))
            }
        }
        
        return markers
    }
    
    private static func generateBodyMetrics(from poses: [PoseFrame]) -> BodySwingMetrics {
        var metrics = BodySwingMetrics()
        
        // Setup metrics
        if let setupPose = poses.first {
            metrics.setupSpineAngle = setupPose.spineAngle
        }
        
        // Find max rotations
        metrics.maxShoulderTurn = poses.compactMap { $0.shoulderRotation }.max()
        metrics.maxHipTurn = poses.compactMap { $0.hipRotation }.max()
        
        // X-Factor
        if let maxShoulder = metrics.maxShoulderTurn, let maxHip = metrics.maxHipTurn {
            metrics.shoulderHipSeparation = maxShoulder - maxHip
        }
        
        // Spine angle maintenance
        let spineAngles = poses.compactMap { $0.spineAngle }
        if let setup = metrics.setupSpineAngle, !spineAngles.isEmpty {
            let maxDeviation = spineAngles.map { abs($0 - setup) }.max() ?? 0
            metrics.spineAngleMaintained = maxDeviation < 10
        }
        
        // Head movement
        let nosePositions = poses.compactMap { $0.nose }
        if nosePositions.count > 2 {
            let xRange = (nosePositions.map { $0.x }.max() ?? 0) - (nosePositions.map { $0.x }.min() ?? 0)
            let yRange = (nosePositions.map { $0.y }.max() ?? 0) - (nosePositions.map { $0.y }.min() ?? 0)
            metrics.headMovement = sqrt(xRange * xRange + yRange * yRange)
        }
        
        return metrics
    }
    
    private static func generateWatchMetrics(from samples: [MotionSample], swingType: MockSwingType) -> WatchSwingMetrics {
        let params = swingType.parameters
        
        return WatchSwingMetrics(
            backswingDuration: params.backswingDuration,
            downswingDuration: params.downswingDuration,
            totalSwingDuration: params.backswingDuration + params.downswingDuration,
            tempoRatio: params.backswingDuration / params.downswingDuration,
            peakWristAcceleration: params.peakGForce,
            estimatedClubSpeed: params.peakGForce * 8, // Rough conversion
            peakRotationRate: params.peakGForce * 1.2,
            impactTimestamp: samples.first?.timestamp.addingTimeInterval(params.backswingDuration + params.downswingDuration * 0.95),
            impactQuality: swingType == .normal ? 0.85 : 0.6,
            impactDeceleration: params.peakGForce * 0.6,
            lagRetained: swingType != .casting,
            smoothnessScore: swingType == .normal ? 0.85 : 0.5,
            consistencyWithPrevious: nil
        )
    }
    
    private static func generateCombinedMetrics(
        camera: CameraSwingCapture?,
        watch: WatchMotionCapture?
    ) -> CombinedSwingMetrics {
        var metrics = CombinedSwingMetrics()
        
        metrics.hasCameraData = camera != nil
        metrics.hasWatchData = watch != nil
        
        if let watchMetrics = watch?.metrics {
            metrics.tempoRatio = watchMetrics.tempoRatio
            metrics.backswingDuration = watchMetrics.backswingDuration
            metrics.downswingDuration = watchMetrics.downswingDuration
            metrics.estimatedClubSpeed = watchMetrics.estimatedClubSpeed
            metrics.impactQuality = watchMetrics.impactQuality
        }
        
        if let bodyMetrics = camera?.bodyMetrics {
            metrics.hipTurnDegrees = bodyMetrics.maxHipTurn
            metrics.shoulderTurnDegrees = bodyMetrics.maxShoulderTurn
            metrics.xFactor = bodyMetrics.shoulderHipSeparation
            metrics.spineAngleMaintained = bodyMetrics.spineAngleMaintained
            if let head = bodyMetrics.headMovement {
                metrics.headMovementInches = head * 72 * 0.7
            }
        }
        
        return metrics
    }
    
    // MARK: - Session Generation
    
    /// Generate a complete range session with multiple swings
    static func generateRangeSession(
        swingCount: Int = 10,
        includeVariation: Bool = true,
        trackingMode: BodyTrackingMode = .vision2D
    ) -> RangeSession {
        var session = RangeSession()
        session.startTime = Date().addingTimeInterval(-600) // 10 minutes ago
        session.endTime = Date()
        session.selectedClub = "7 Iron"
        session.trackingMode = trackingMode
        
        for i in 0..<swingCount {
            let swingType: MockSwingType
            if includeVariation {
                // Mix of swing types
                switch i % 5 {
                case 0: swingType = .normal
                case 1: swingType = .fastTempo
                case 2: swingType = .slowTempo
                case 3: swingType = .overTheTop
                default: swingType = .normal
                }
            } else {
                swingType = .normal
            }
            
            var swing = generateCombinedSwingCapture(swingType: swingType)
            swing.club = "7 Iron"
            session.swings.append(swing)
        }
        
        return session
    }
    
    // MARK: - 3D Joint Generation
    
    /// Generate 3D joints for a pose at given swing progress
    static func generate3DJoints(
        progress: Double,
        swingType: MockSwingType = .normal
    ) -> [Joint3D] {
        let (shoulderRotation, hipRotation, _) = calculateBodyAngles(progress: progress, swingType: swingType)
        
        // Convert degrees to radians
        let shoulderRad = Float(shoulderRotation * .pi / 180)
        let hipRad = Float(hipRotation * .pi / 180)
        
        var joints: [Joint3D] = []
        
        // Base height (meters)
        let headHeight: Float = 1.7
        let shoulderHeight: Float = 1.4
        let hipHeight: Float = 0.95
        let kneeHeight: Float = 0.5
        let ankleHeight: Float = 0.05
        
        // Base widths (meters)
        let shoulderWidth: Float = 0.4
        let hipWidth: Float = 0.24
        let stanceWidth: Float = 0.24
        
        // Head
        joints.append(createJoint3D(
            name: "head",
            x: 0,
            y: headHeight,
            z: 0
        ))
        
        // Shoulders (rotated)
        joints.append(createJoint3D(
            name: "leftShoulder",
            x: -shoulderWidth/2 * cos(shoulderRad),
            y: shoulderHeight,
            z: -shoulderWidth/2 * sin(shoulderRad)
        ))
        joints.append(createJoint3D(
            name: "rightShoulder",
            x: shoulderWidth/2 * cos(shoulderRad),
            y: shoulderHeight,
            z: shoulderWidth/2 * sin(shoulderRad)
        ))
        
        // Elbows
        let elbowOffset = calculateElbowPosition(progress: progress)
        joints.append(createJoint3D(
            name: "leftElbow",
            x: -0.25 + Float(elbowOffset.x),
            y: 1.2 + Float(elbowOffset.y),
            z: -0.1
        ))
        joints.append(createJoint3D(
            name: "rightElbow",
            x: 0.25 - Float(elbowOffset.x),
            y: 1.2 + Float(elbowOffset.y),
            z: -0.1
        ))
        
        // Wrists
        let wristOffset = calculateWristPosition(progress: progress)
        joints.append(createJoint3D(
            name: "leftWrist",
            x: -0.1 + Float(wristOffset.x),
            y: 1.0 + Float(wristOffset.y),
            z: -0.2
        ))
        joints.append(createJoint3D(
            name: "rightWrist",
            x: 0.1 + Float(wristOffset.x),
            y: 1.0 + Float(wristOffset.y),
            z: -0.2
        ))
        
        // Hips (rotated)
        joints.append(createJoint3D(
            name: "leftHip",
            x: -hipWidth/2 * cos(hipRad),
            y: hipHeight,
            z: -hipWidth/2 * sin(hipRad)
        ))
        joints.append(createJoint3D(
            name: "rightHip",
            x: hipWidth/2 * cos(hipRad),
            y: hipHeight,
            z: hipWidth/2 * sin(hipRad)
        ))
        
        // Knees
        joints.append(createJoint3D(
            name: "leftKnee",
            x: -stanceWidth/2,
            y: kneeHeight,
            z: 0
        ))
        joints.append(createJoint3D(
            name: "rightKnee",
            x: stanceWidth/2,
            y: kneeHeight,
            z: 0
        ))
        
        // Ankles
        joints.append(createJoint3D(
            name: "leftAnkle",
            x: -stanceWidth/2,
            y: ankleHeight,
            z: 0
        ))
        joints.append(createJoint3D(
            name: "rightAnkle",
            x: stanceWidth/2,
            y: ankleHeight,
            z: 0
        ))
        
        return joints
    }
    
    /// Generate a sequence of 3D joint data for a swing
    static func generate3DSwingSequence(
        duration: TimeInterval = 1.2,
        fps: Int = 30,
        swingType: MockSwingType = .normal
    ) -> [[Joint3D]] {
        var sequence: [[Joint3D]] = []
        let frameCount = Int(duration * Double(fps))
        
        for i in 0..<frameCount {
            let progress = Double(i) / Double(frameCount)
            let joints = generate3DJoints(progress: progress, swingType: swingType)
            sequence.append(joints)
        }
        
        return sequence
    }
    
    private static func createJoint3D(name: String, x: Float, y: Float, z: Float) -> Joint3D {
        // Simple orthographic projection for screen position
        let screenX = CGFloat(0.5 + Double(x))
        let screenY = CGFloat(1.0 - Double(y) / 2.0)
        
        return Joint3D(
            name: name,
            position: SIMD3<Float>(x, y, z),
            screenPosition: CGPoint(
                x: max(0, min(1, screenX)),
                y: max(0, min(1, screenY))
            ),
            confidence: 0.95
        )
    }
}

// MARK: - Mock Swing Types

enum MockSwingType: CaseIterable {
    case normal
    case fastTempo
    case slowTempo
    case overTheTop
    case casting
    case lossOfPosture
    
    var parameters: SwingParameters {
        switch self {
        case .normal:
            return SwingParameters(
                maxShoulderTurn: 90,
                maxHipTurn: 45,
                setupSpineAngle: -25,
                spineAngleChange: 5,
                backswingDuration: 0.9,
                downswingDuration: 0.3,
                peakGForce: 10.0
            )
        case .fastTempo:
            return SwingParameters(
                maxShoulderTurn: 85,
                maxHipTurn: 40,
                setupSpineAngle: -25,
                spineAngleChange: 5,
                backswingDuration: 0.6,
                downswingDuration: 0.25,
                peakGForce: 11.0
            )
        case .slowTempo:
            return SwingParameters(
                maxShoulderTurn: 95,
                maxHipTurn: 50,
                setupSpineAngle: -25,
                spineAngleChange: 3,
                backswingDuration: 1.2,
                downswingDuration: 0.35,
                peakGForce: 9.0
            )
        case .overTheTop:
            return SwingParameters(
                maxShoulderTurn: 80,
                maxHipTurn: 35,
                setupSpineAngle: -25,
                spineAngleChange: 10,
                backswingDuration: 0.8,
                downswingDuration: 0.3,
                peakGForce: 9.5
            )
        case .casting:
            return SwingParameters(
                maxShoulderTurn: 85,
                maxHipTurn: 40,
                setupSpineAngle: -25,
                spineAngleChange: 5,
                backswingDuration: 0.7,
                downswingDuration: 0.35,
                peakGForce: 8.0
            )
        case .lossOfPosture:
            return SwingParameters(
                maxShoulderTurn: 90,
                maxHipTurn: 45,
                setupSpineAngle: -25,
                spineAngleChange: 20, // Large change = loss of posture
                backswingDuration: 0.9,
                downswingDuration: 0.3,
                peakGForce: 9.0
            )
        }
    }
}

struct SwingParameters {
    let maxShoulderTurn: Double       // degrees
    let maxHipTurn: Double            // degrees
    let setupSpineAngle: Double       // degrees (negative = forward bend)
    let spineAngleChange: Double      // degrees change during swing
    let backswingDuration: TimeInterval
    let downswingDuration: TimeInterval
    let peakGForce: Double
}
