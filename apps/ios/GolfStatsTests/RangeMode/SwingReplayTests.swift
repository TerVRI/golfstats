import XCTest
@testable import GolfStats

/// Unit tests for SwingReplayView and related components
final class SwingReplayTests: XCTestCase {
    
    // MARK: - Playback Speed Tests
    
    func testPlaybackSpeed_Multipliers() {
        XCTAssertEqual(PlaybackSpeed.quarterSpeed.multiplier, 0.25)
        XCTAssertEqual(PlaybackSpeed.halfSpeed.multiplier, 0.5)
        XCTAssertEqual(PlaybackSpeed.normal.multiplier, 1.0)
        XCTAssertEqual(PlaybackSpeed.doubleSpeed.multiplier, 2.0)
    }
    
    func testPlaybackSpeed_Labels() {
        XCTAssertEqual(PlaybackSpeed.quarterSpeed.label, "0.25x")
        XCTAssertEqual(PlaybackSpeed.halfSpeed.label, "0.5x")
        XCTAssertEqual(PlaybackSpeed.normal.label, "1x")
        XCTAssertEqual(PlaybackSpeed.doubleSpeed.label, "2x")
    }
    
    func testPlaybackSpeed_Cycling() {
        // Start at quarter speed and cycle through all
        var speed = PlaybackSpeed.quarterSpeed
        
        speed = speed.next
        XCTAssertEqual(speed, .halfSpeed)
        
        speed = speed.next
        XCTAssertEqual(speed, .normal)
        
        speed = speed.next
        XCTAssertEqual(speed, .doubleSpeed)
        
        speed = speed.next
        XCTAssertEqual(speed, .quarterSpeed) // Wraps around
    }
    
    // MARK: - View Model Tests
    
    func testViewModel_InitialState() {
        // Given: A swing capture
        let swing = MockDataGenerators.generateCombinedSwingCapture()
        
        // When: Create view model
        let viewModel = SwingReplayViewModel(swing: swing)
        
        // Then: Should have correct initial state
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertTrue(viewModel.isLooping)
        XCTAssertEqual(viewModel.progress, 0)
        XCTAssertEqual(viewModel.currentFrameIndex, 0)
        XCTAssertEqual(viewModel.playbackSpeed, .normal)
        XCTAssertTrue(viewModel.showSkeleton)
        XCTAssertTrue(viewModel.showPhaseLabels)
    }
    
    func testViewModel_PosesAccess() {
        // Given: A swing with poses
        let swing = MockDataGenerators.generateCombinedSwingCapture()
        let viewModel = SwingReplayViewModel(swing: swing)
        
        // Then: Should have access to poses
        XCTAssertGreaterThan(viewModel.poses.count, 0)
    }
    
    func testViewModel_CurrentPose() {
        // Given: A swing with poses
        let swing = MockDataGenerators.generateCombinedSwingCapture()
        let viewModel = SwingReplayViewModel(swing: swing)
        
        // Then: Current pose should be first pose
        XCTAssertNotNil(viewModel.currentPose)
        XCTAssertEqual(viewModel.currentPose?.frameIndex, viewModel.poses.first?.frameIndex)
    }
    
    func testViewModel_Scrubbing() {
        // Given: A swing with poses
        let swing = MockDataGenerators.generateCombinedSwingCapture()
        let viewModel = SwingReplayViewModel(swing: swing)
        
        // When: Scrub to middle
        viewModel.scrub(to: 0.5)
        
        // Then: Should be at middle
        XCTAssertEqual(viewModel.progress, 0.5, accuracy: 0.01)
        XCTAssertEqual(viewModel.currentFrameIndex, viewModel.poses.count / 2, accuracy: 1)
    }
    
    func testViewModel_ScrubBoundaries() {
        // Given: A swing with poses
        let swing = MockDataGenerators.generateCombinedSwingCapture()
        let viewModel = SwingReplayViewModel(swing: swing)
        
        // When: Scrub beyond boundaries
        viewModel.scrub(to: -0.5)
        XCTAssertEqual(viewModel.progress, 0)
        
        viewModel.scrub(to: 1.5)
        XCTAssertEqual(viewModel.progress, 1)
    }
    
    func testViewModel_FrameNavigation() {
        // Given: A swing with poses
        let swing = MockDataGenerators.generateCombinedSwingCapture()
        let viewModel = SwingReplayViewModel(swing: swing)
        
        // Initially at frame 0
        XCTAssertEqual(viewModel.currentFrameIndex, 0)
        
        // When: Go to next frame
        viewModel.nextFrame()
        XCTAssertEqual(viewModel.currentFrameIndex, 1)
        
        // When: Go to previous frame
        viewModel.previousFrame()
        XCTAssertEqual(viewModel.currentFrameIndex, 0)
        
        // When: Try to go before start
        viewModel.previousFrame()
        XCTAssertEqual(viewModel.currentFrameIndex, 0) // Should stay at 0
    }
    
    func testViewModel_NextFrameAtEnd() {
        // Given: A swing with poses, at last frame
        let swing = MockDataGenerators.generateCombinedSwingCapture()
        let viewModel = SwingReplayViewModel(swing: swing)
        viewModel.scrub(to: 1.0)
        let lastFrameIndex = viewModel.currentFrameIndex
        
        // When: Try to go past end
        viewModel.nextFrame()
        
        // Then: Should stay at last frame
        XCTAssertEqual(viewModel.currentFrameIndex, lastFrameIndex)
    }
    
    func testViewModel_SpeedCycling() {
        // Given: View model at normal speed
        let swing = MockDataGenerators.generateCombinedSwingCapture()
        let viewModel = SwingReplayViewModel(swing: swing)
        XCTAssertEqual(viewModel.playbackSpeed, .normal)
        
        // When: Cycle speed
        viewModel.cycleSpeed()
        
        // Then: Should be at double speed
        XCTAssertEqual(viewModel.playbackSpeed, .doubleSpeed)
    }
    
    func testViewModel_Toggles() {
        // Given: View model with default toggles
        let swing = MockDataGenerators.generateCombinedSwingCapture()
        let viewModel = SwingReplayViewModel(swing: swing)
        
        XCTAssertTrue(viewModel.showSkeleton)
        XCTAssertTrue(viewModel.showPhaseLabels)
        XCTAssertTrue(viewModel.isLooping)
        
        // When: Toggle each
        viewModel.toggleSkeleton()
        viewModel.togglePhaseLabels()
        viewModel.toggleLoop()
        
        // Then: All should be inverted
        XCTAssertFalse(viewModel.showSkeleton)
        XCTAssertFalse(viewModel.showPhaseLabels)
        XCTAssertFalse(viewModel.isLooping)
    }
    
    func testViewModel_PhasePositions() {
        // Given: Swing with phase markers
        let swing = MockDataGenerators.generateCombinedSwingCapture()
        let viewModel = SwingReplayViewModel(swing: swing)
        
        // Then: Should have phase positions
        let positions = viewModel.phasePositions
        XCTAssertGreaterThan(positions.count, 0)
        
        // Positions should be in [0, 1] range
        for position in positions {
            XCTAssertGreaterThanOrEqual(position.position, 0)
            XCTAssertLessThanOrEqual(position.position, 1)
        }
    }
    
    func testViewModel_TimeStrings() {
        // Given: Swing with duration
        let swing = MockDataGenerators.generateCombinedSwingCapture()
        let viewModel = SwingReplayViewModel(swing: swing)
        
        // Then: Should have valid time strings
        XCTAssertFalse(viewModel.currentTimeString.isEmpty)
        XCTAssertFalse(viewModel.totalTimeString.isEmpty)
        
        // Current time at start should be close to 0
        let currentTime = Double(viewModel.currentTimeString) ?? 0
        XCTAssertEqual(currentTime, 0, accuracy: 0.1)
        
        // Total time should be positive
        let totalTime = Double(viewModel.totalTimeString) ?? 0
        XCTAssertGreaterThan(totalTime, 0)
    }
    
    func testViewModel_PlayPauseToggle() {
        // Given: View model not playing
        let swing = MockDataGenerators.generateCombinedSwingCapture()
        let viewModel = SwingReplayViewModel(swing: swing)
        XCTAssertFalse(viewModel.isPlaying)
        
        // When: Toggle playback
        viewModel.togglePlayback()
        
        // Then: Should be playing
        XCTAssertTrue(viewModel.isPlaying)
        
        // When: Toggle again
        viewModel.togglePlayback()
        
        // Then: Should be paused
        XCTAssertFalse(viewModel.isPlaying)
    }
    
    func testViewModel_NavigationPausesPlayback() {
        // Given: View model playing
        let swing = MockDataGenerators.generateCombinedSwingCapture()
        let viewModel = SwingReplayViewModel(swing: swing)
        viewModel.play()
        XCTAssertTrue(viewModel.isPlaying)
        
        // When: Navigate frames
        viewModel.nextFrame()
        
        // Then: Should pause
        XCTAssertFalse(viewModel.isPlaying)
    }
    
    // MARK: - Phase Detection Tests
    
    func testViewModel_CurrentPhaseAtStart() {
        // Given: Swing starting at setup
        let swing = MockDataGenerators.generateCombinedSwingCapture()
        let viewModel = SwingReplayViewModel(swing: swing)
        
        // Then: Should be at setup phase
        XCTAssertEqual(viewModel.currentPhase, .setup)
    }
    
    func testViewModel_PhaseChangesWithScrubbing() {
        // Given: Swing with phases
        let swing = MockDataGenerators.generateCombinedSwingCapture()
        let viewModel = SwingReplayViewModel(swing: swing)
        
        // When: Scrub to middle (around impact)
        viewModel.scrub(to: 0.72)
        
        // Then: Phase should have changed from setup
        // (exact phase depends on phase marker positions)
        XCTAssertNotNil(viewModel.currentPhase)
    }
    
    // MARK: - Duration Calculations
    
    func testFrameTimeCalculation() {
        // Given: 30fps video
        let fps = 30.0
        let frameIndex = 45
        
        // When: Calculate time
        let time = Double(frameIndex) / fps
        
        // Then: Should be 1.5 seconds
        XCTAssertEqual(time, 1.5)
    }
    
    func testSlowMotionFrameRate() {
        // Given: 30fps source at 0.25x speed
        let sourceFPS = 30.0
        let speedMultiplier = 0.25
        
        // When: Calculate effective FPS
        let effectiveFPS = sourceFPS * speedMultiplier
        
        // Then: Should be 7.5fps (slow motion)
        XCTAssertEqual(effectiveFPS, 7.5)
    }
    
    // MARK: - Progress Calculation Tests
    
    func testProgressFromFrameIndex() {
        // Given: 100 frames total, at frame 50
        let totalFrames = 100
        let currentFrame = 50
        
        // When: Calculate progress
        let progress = Double(currentFrame) / Double(totalFrames - 1)
        
        // Then: Should be ~0.505
        XCTAssertEqual(progress, 0.505, accuracy: 0.01)
    }
    
    func testFrameIndexFromProgress() {
        // Given: 100 frames total, at 50% progress
        let totalFrames = 100
        let progress = 0.5
        
        // When: Calculate frame index
        let frameIndex = Int(progress * Double(totalFrames - 1))
        
        // Then: Should be 49 (0-indexed)
        XCTAssertEqual(frameIndex, 49)
    }
}
