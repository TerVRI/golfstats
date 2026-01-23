import Foundation
import ARKit
import AVFoundation

/// Detects device capabilities for LiDAR, body tracking, and camera features
/// Used to determine which Range Mode features are available
final class LiDARCapabilities {
    
    // MARK: - Singleton
    
    static let shared = LiDARCapabilities()
    
    // MARK: - Cached Capabilities
    
    /// Device has LiDAR scanner (iPhone 12 Pro+, iPad Pro 2020+)
    let hasLiDAR: Bool
    
    /// Device supports ARKit body tracking (A12 chip+)
    let supportsBodyTracking: Bool
    
    /// Device supports 3D body pose in Vision (iOS 17+)
    let supports3DBodyPose: Bool
    
    /// Device supports scene reconstruction/mesh (LiDAR required)
    let supportsSceneReconstruction: Bool
    
    /// Device supports people occlusion
    let supportsPeopleOcclusion: Bool
    
    /// Device supports high frame rate capture (120fps)
    let supportsHighFrameRate: Bool
    
    /// Device supports 4K video capture in AR
    let supports4KVideo: Bool
    
    /// Maximum supported camera frame rate
    let maxFrameRate: Int
    
    /// Best available tracking mode for this device
    let recommendedTrackingMode: TrackingMode
    
    // MARK: - Initialization
    
    private init() {
        // Check LiDAR availability
        hasLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        
        // Check body tracking support (requires A12 or later)
        supportsBodyTracking = ARBodyTrackingConfiguration.isSupported
        
        // Check 3D body pose (iOS 17+)
        if #available(iOS 17.0, *) {
            supports3DBodyPose = true
        } else {
            supports3DBodyPose = false
        }
        
        // Scene reconstruction requires LiDAR
        supportsSceneReconstruction = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        
        // People occlusion
        supportsPeopleOcclusion = ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth)
        
        // Check camera capabilities
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )
        
        if let camera = discoverySession.devices.first {
            // Check for 120fps support
            let supports120fps = camera.formats.contains { format in
                format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 120 }
            }
            supportsHighFrameRate = supports120fps
            
            // Find max frame rate
            let maxRate = camera.formats.flatMap { $0.videoSupportedFrameRateRanges }
                .map { Int($0.maxFrameRate) }
                .max() ?? 30
            maxFrameRate = maxRate
            
            // Check 4K support (iPhone 12+ generally)
            // 4K AR capture requires specific device capabilities
            supports4KVideo = maxRate >= 60 && hasLiDAR
        } else {
            supportsHighFrameRate = false
            maxFrameRate = 30
            supports4KVideo = false
        }
        
        // Determine best tracking mode
        recommendedTrackingMode = Self.determineTrackingMode(
            hasLiDAR: hasLiDAR,
            supportsBodyTracking: supportsBodyTracking,
            supports3DBodyPose: supports3DBodyPose
        )
        
        logCapabilities()
    }
    
    // MARK: - Tracking Mode Determination
    
    private static func determineTrackingMode(
        hasLiDAR: Bool,
        supportsBodyTracking: Bool,
        supports3DBodyPose: Bool
    ) -> TrackingMode {
        if hasLiDAR && supportsBodyTracking {
            return .arKitBodyTracking3D  // Best: 91 joints in 3D with depth
        } else if supportsBodyTracking {
            return .arKitBodyTracking2D  // Good: 91 joints but less accurate depth
        } else if supports3DBodyPose {
            return .vision3DPose         // Decent: 17 joints with some 3D
        } else {
            return .vision2DPose         // Basic: 17-19 joints in 2D
        }
    }
    
    // MARK: - Feature Availability Checks
    
    /// Check if a specific feature is available on this device
    func isFeatureAvailable(_ feature: RangeModeFeature) -> Bool {
        switch feature {
        case .basicSwingAnalysis:
            return true // Always available with camera
            
        case .avatar3D:
            return supportsBodyTracking
            
        case .swingPlane3D:
            return hasLiDAR || supportsBodyTracking
            
        case .ghostOverlay:
            return supportsBodyTracking
            
        case .proComparison:
            return supportsBodyTracking
            
        case .pointCloud:
            return hasLiDAR
            
        case .realMeasurements:
            return hasLiDAR // Accurate measurements need depth
            
        case .clubTracking:
            return hasLiDAR // Future feature
            
        case .highFrameRateCapture:
            return supportsHighFrameRate
            
        case .video4K:
            return supports4KVideo
        }
    }
    
    /// Get all available features for this device
    func availableFeatures() -> [RangeModeFeature] {
        return RangeModeFeature.allCases.filter { isFeatureAvailable($0) }
    }
    
    /// Get features that require upgrade (Pro device)
    func unavailableFeatures() -> [RangeModeFeature] {
        return RangeModeFeature.allCases.filter { !isFeatureAvailable($0) }
    }
    
    // MARK: - Configuration Builders
    
    /// Create optimal ARBodyTrackingConfiguration for this device
    func createBodyTrackingConfiguration() -> ARBodyTrackingConfiguration? {
        guard supportsBodyTracking else { return nil }
        
        let config = ARBodyTrackingConfiguration()
        config.automaticSkeletonScaleEstimationEnabled = true
        config.isAutoFocusEnabled = true
        
        // Note: ARBodyTrackingConfiguration doesn't support sceneReconstruction
        // LiDAR mesh is available through ARWorldTrackingConfiguration
        
        if supportsPeopleOcclusion {
            config.frameSemantics.insert(.personSegmentationWithDepth)
        }
        
        return config
    }
    
    /// Create optimal camera configuration for pose detection
    func createCameraConfiguration() -> (format: AVCaptureDevice.Format, frameRate: Int)? {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front // Front camera for swing analysis
        )
        
        guard let camera = discoverySession.devices.first else { return nil }
        
        // Prefer 60fps for smooth tracking, fallback to 30fps
        let targetFrameRate = supportsHighFrameRate ? 60 : 30
        
        // Find best format
        let sortedFormats = camera.formats.sorted { f1, f2 in
            let dim1 = CMVideoFormatDescriptionGetDimensions(f1.formatDescription)
            let dim2 = CMVideoFormatDescriptionGetDimensions(f2.formatDescription)
            return dim1.width * dim1.height > dim2.width * dim2.height
        }
        
        for format in sortedFormats {
            let supportsTargetRate = format.videoSupportedFrameRateRanges.contains {
                $0.maxFrameRate >= Double(targetFrameRate)
            }
            
            if supportsTargetRate {
                return (format, targetFrameRate)
            }
        }
        
        // Fallback to first available
        if let firstFormat = sortedFormats.first {
            let maxRate = Int(firstFormat.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 30)
            return (firstFormat, min(maxRate, 30))
        }
        
        return nil
    }
    
    // MARK: - Debug Logging
    
    private func logCapabilities() {
        print("📱 Device Capabilities:")
        print("  - LiDAR: \(hasLiDAR)")
        print("  - Body Tracking: \(supportsBodyTracking)")
        print("  - 3D Body Pose: \(supports3DBodyPose)")
        print("  - Scene Reconstruction: \(supportsSceneReconstruction)")
        print("  - People Occlusion: \(supportsPeopleOcclusion)")
        print("  - High Frame Rate: \(supportsHighFrameRate) (max: \(maxFrameRate)fps)")
        print("  - 4K Video: \(supports4KVideo)")
        print("  - Recommended Mode: \(recommendedTrackingMode.rawValue)")
    }
    
    /// Get a user-friendly description of device capabilities
    func capabilityDescription() -> String {
        switch recommendedTrackingMode {
        case .arKitBodyTracking3D:
            return "Full 3D tracking with LiDAR depth sensing"
        case .arKitBodyTracking2D:
            return "3D body tracking (91 joints)"
        case .vision3DPose:
            return "3D pose estimation (17 joints)"
        case .vision2DPose:
            return "2D pose estimation"
        }
    }
}

// MARK: - Supporting Types

/// Available tracking modes in order of capability
enum TrackingMode: String, CaseIterable {
    case arKitBodyTracking3D = "ARKit 3D (LiDAR)"
    case arKitBodyTracking2D = "ARKit 3D"
    case vision3DPose = "Vision 3D"
    case vision2DPose = "Vision 2D"
    
    var jointCount: Int {
        switch self {
        case .arKitBodyTracking3D, .arKitBodyTracking2D:
            return 91
        case .vision3DPose:
            return 17
        case .vision2DPose:
            return 19
        }
    }
    
    var supportsDepth: Bool {
        switch self {
        case .arKitBodyTracking3D:
            return true
        case .arKitBodyTracking2D, .vision3DPose:
            return false // Estimated depth only
        case .vision2DPose:
            return false
        }
    }
}

/// Features available in Range Mode
enum RangeModeFeature: String, CaseIterable {
    case basicSwingAnalysis = "Basic Swing Analysis"
    case avatar3D = "3D Avatar Mirror"
    case swingPlane3D = "3D Swing Plane"
    case ghostOverlay = "Ghost Overlay"
    case proComparison = "Pro Comparison"
    case pointCloud = "Point Cloud"
    case realMeasurements = "Real Measurements"
    case clubTracking = "Club Tracking"
    case highFrameRateCapture = "120fps Capture"
    case video4K = "4K Video"
    
    var description: String {
        switch self {
        case .basicSwingAnalysis:
            return "Analyze your swing with body pose detection"
        case .avatar3D:
            return "See a 3D character mirror your movements"
        case .swingPlane3D:
            return "Visualize your swing plane in AR"
        case .ghostOverlay:
            return "Compare swings with overlay"
        case .proComparison:
            return "Compare with professional golfers"
        case .pointCloud:
            return "Matrix-style body visualization"
        case .realMeasurements:
            return "Accurate measurements in cm/inches"
        case .clubTracking:
            return "Track club head through swing"
        case .highFrameRateCapture:
            return "Capture at 120 frames per second"
        case .video4K:
            return "Record in 4K resolution"
        }
    }
    
    var requiresLiDAR: Bool {
        switch self {
        case .pointCloud, .realMeasurements, .clubTracking:
            return true
        default:
            return false
        }
    }
    
    var requiresProDevice: Bool {
        return requiresLiDAR
    }
}
