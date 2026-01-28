import Foundation
import HealthKit
import Combine

/// Manages HealthKit workout sessions for golf rounds
/// This keeps the app active in background and enables high-frequency sensor access
class WorkoutManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isWorkoutActive = false
    @Published var activeCalories: Double = 0
    @Published var heartRate: Double = 0
    @Published var elapsedTime: TimeInterval = 0
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    
    // Error handling
    @Published var errorMessage: String?
    @Published var showError = false
    
    // MARK: - Private Properties
    
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var startDate: Date?
    
    // Timer for elapsed time
    private var elapsedTimer: Timer?
    
    // MARK: - HealthKit Types
    
    private let workoutType: HKWorkoutActivityType = .golf
    
    private let typesToShare: Set<HKSampleType> = [
        HKQuantityType.workoutType()
    ]
    
    private let typesToRead: Set<HKObjectType> = [
        HKQuantityType.quantityType(forIdentifier: .heartRate)!,
        HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKObjectType.activitySummaryType()
    ]
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        // Check if HealthKit is available
        guard HKHealthStore.isHealthDataAvailable() else {
            print("⚠️ HealthKit not available on this device")
            return
        }
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            return false
        }
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            
            // Update authorization status
            await MainActor.run {
                self.authorizationStatus = healthStore.authorizationStatus(for: HKQuantityType.workoutType())
            }
            
            return true
        } catch {
            await MainActor.run {
                self.errorMessage = "HealthKit access denied. Enable in Settings > Privacy > Health."
                self.showError = true
            }
            print("HealthKit authorization error: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Workout Session Management
    
    /// Start a golf workout session
    func startWorkout() async throws {
        // Request authorization if needed
        if authorizationStatus != .sharingAuthorized {
            _ = await requestAuthorization()
        }
        
        // Create workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutType
        configuration.locationType = .outdoor
        
        do {
            // Create session and builder
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
            
            session?.delegate = self
            builder?.delegate = self
            
            // Set up data source for live metrics
            builder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            
            // Start the session and builder
            let startDate = Date()
            session?.startActivity(with: startDate)
            try await builder?.beginCollection(at: startDate)
            
            await MainActor.run {
                self.startDate = startDate
                self.isWorkoutActive = true
                self.startElapsedTimer()
            }
            
            print("🏌️ Golf workout started")
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to start workout tracking. Your round will continue without HealthKit data."
                self.showError = true
                
                // Auto-dismiss after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                    self?.showError = false
                }
            }
            print("Failed to start workout: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// End the current workout session
    func endWorkout() async throws {
        guard let session = session, let builder = builder else {
            print("No active workout to end")
            return
        }
        
        let endDate = Date()
        
        // End the session
        session.end()
        
        // End data collection
        try await builder.endCollection(at: endDate)
        
        // Finish and save the workout
        do {
            let workout = try await builder.finishWorkout()
            
            await MainActor.run {
                self.isWorkoutActive = false
                self.stopElapsedTimer()
                self.session = nil
                self.builder = nil
            }
            
            print("✅ Golf workout saved: \(workout?.duration ?? 0 / 60) minutes, \(workout?.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0) kcal")
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Workout data couldn't be saved to Health. Your round data is still saved."
                self.showError = true
                
                // Clean up anyway
                self.isWorkoutActive = false
                self.stopElapsedTimer()
                self.session = nil
                self.builder = nil
                
                // Auto-dismiss after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                    self?.showError = false
                }
            }
            print("Failed to save workout: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Discard the current workout without saving
    func discardWorkout() {
        guard let session = session else { return }
        
        session.end()
        builder?.discardWorkout()
        
        isWorkoutActive = false
        stopElapsedTimer()
        self.session = nil
        self.builder = nil
        
        print("🗑️ Golf workout discarded")
    }
    
    // MARK: - Elapsed Time
    
    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startDate else { return }
            self.elapsedTime = Date().timeIntervalSince(start)
        }
    }
    
    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }
    
    // MARK: - Formatted Output
    
    var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var formattedCalories: String {
        return String(format: "%.0f", activeCalories)
    }
    
    var formattedHeartRate: String {
        return String(format: "%.0f", heartRate)
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            switch toState {
            case .running:
                self.isWorkoutActive = true
            case .ended, .stopped:
                self.isWorkoutActive = false
            default:
                break
            }
        }
        
        print("Workout state changed: \(fromState.rawValue) -> \(toState.rawValue)")
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = "Workout tracking interrupted. Your round data is still being saved."
            self?.showError = true
            
            // Auto-dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                self?.showError = false
            }
        }
        print("Workout session failed: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            // Get the most recent statistics
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            DispatchQueue.main.async {
                switch quantityType {
                case HKQuantityType.quantityType(forIdentifier: .heartRate):
                    if let value = statistics?.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
                        self.heartRate = value
                    }
                    
                case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                    if let value = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                        self.activeCalories = value
                    }
                    
                default:
                    break
                }
            }
        }
    }
}

// MARK: - Convenience Extensions

extension WorkoutManager {
    /// Whether HealthKit workouts are supported and authorized
    var canStartWorkout: Bool {
        HKHealthStore.isHealthDataAvailable() && authorizationStatus == .sharingAuthorized
    }
}
