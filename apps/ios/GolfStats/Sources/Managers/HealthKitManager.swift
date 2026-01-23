import Foundation
import HealthKit
import CoreLocation

/// Manages Apple HealthKit integration for logging golf rounds as workouts
class HealthKitManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = HealthKitManager()
    
    // MARK: - Published State
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var isLoggingEnabled = true
    
    // MARK: - HealthKit Store
    
    private let healthStore = HKHealthStore()
    private var currentWorkout: HKWorkoutBuilder?
    private var workoutSession: HKWorkoutSession?
    
    // MARK: - Types to Write
    
    private var typesToWrite: Set<HKSampleType> {
        return [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!
        ]
    }
    
    // MARK: - Types to Read
    
    private var typesToRead: Set<HKObjectType> {
        return [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!
        ]
    }
    
    // MARK: - Initialization
    
    private init() {
        checkAuthorizationStatus()
        loadPreferences()
    }
    
    // MARK: - Authorization
    
    /// Check if HealthKit is available on this device
    var isHealthKitAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    /// Request authorization to access HealthKit data
    func requestAuthorization() async throws {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }
        
        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
        
        await MainActor.run {
            checkAuthorizationStatus()
        }
    }
    
    /// Check current authorization status
    private func checkAuthorizationStatus() {
        guard isHealthKitAvailable else {
            authorizationStatus = .notDetermined
            isAuthorized = false
            return
        }
        
        let status = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        authorizationStatus = status
        isAuthorized = status == .sharingAuthorized
    }
    
    // MARK: - Workout Logging
    
    /// Start tracking a golf round as a workout
    func startGolfWorkout(courseName: String) async throws -> HKWorkoutBuilder {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .golf
        configuration.locationType = .outdoor
        
        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: .local()
        )
        
        try await builder.beginCollection(at: Date())
        
        currentWorkout = builder
        
        print("🏌️ Started golf workout: \(courseName)")
        return builder
    }
    
    /// End the current golf workout and save it
    func endGolfWorkout(
        courseName: String,
        duration: TimeInterval,
        caloriesBurned: Double? = nil,
        distanceWalked: Double? = nil,
        steps: Int? = nil
    ) async throws -> HKWorkout? {
        guard let builder = currentWorkout else {
            throw HealthKitError.noActiveWorkout
        }
        
        // Add metadata
        let _ = [
            HKMetadataKeyWorkoutBrandName: "RoundCaddy",
            "CourseName": courseName
        ] as [String: Any]
        
        // Add samples
        var samples: [HKSample] = []
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-duration)
        
        // Calories burned (estimate: ~300-400 calories per hour for walking golf)
        let calories = caloriesBurned ?? estimateCalories(duration: duration)
        let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let caloriesQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
        let caloriesSample = HKQuantitySample(
            type: caloriesType,
            quantity: caloriesQuantity,
            start: startDate,
            end: endDate
        )
        samples.append(caloriesSample)
        
        // Distance walked (estimate: ~5-7 km for 18 holes)
        let distance = distanceWalked ?? estimateDistance(duration: duration)
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: distance)
        let distanceSample = HKQuantitySample(
            type: distanceType,
            quantity: distanceQuantity,
            start: startDate,
            end: endDate
        )
        samples.append(distanceSample)
        
        // Steps (estimate: ~10,000 steps for 18 holes)
        let stepCount = steps ?? estimateSteps(duration: duration)
        let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let stepsQuantity = HKQuantity(unit: .count(), doubleValue: Double(stepCount))
        let stepsSample = HKQuantitySample(
            type: stepsType,
            quantity: stepsQuantity,
            start: startDate,
            end: endDate
        )
        samples.append(stepsSample)
        
        // Add samples to builder
        if !samples.isEmpty {
            try await builder.addSamples(samples)
        }
        
        // End collection
        try await builder.endCollection(at: endDate)
        
        // Finish and save workout
        let workout = try await builder.finishWorkout()
        
        currentWorkout = nil
        
        print("✅ Saved golf workout: \(courseName), duration: \(Int(duration/60)) minutes")
        
        return workout
    }
    
    /// Cancel the current workout without saving
    func cancelWorkout() async {
        guard let builder = currentWorkout else { return }
        
        builder.discardWorkout()
        currentWorkout = nil
        
        print("⚠️ Golf workout cancelled")
    }
    
    // MARK: - Quick Save (for completed rounds)
    
    /// Save a completed round as a workout (after the fact)
    func saveCompletedRound(
        courseName: String,
        startDate: Date,
        endDate: Date,
        holesPlayed: Int = 18,
        caloriesBurned: Double? = nil,
        distanceWalked: Double? = nil
    ) async throws -> HKWorkout {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }
        
        let duration = endDate.timeIntervalSince(startDate)
        let calories = caloriesBurned ?? estimateCalories(duration: duration, holes: holesPlayed)
        let distance = distanceWalked ?? estimateDistance(duration: duration, holes: holesPlayed)
        
        // Create workout using HKWorkoutBuilder (iOS 17+ recommended approach)
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .golf
        configuration.locationType = .outdoor
        
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        
        try await builder.beginCollection(at: startDate)
        
        // Add samples
        var samples: [HKSample] = []
        
        let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let caloriesQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
        let caloriesSample = HKQuantitySample(type: caloriesType, quantity: caloriesQuantity, start: startDate, end: endDate)
        samples.append(caloriesSample)
        
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: distance)
        let distanceSample = HKQuantitySample(type: distanceType, quantity: distanceQuantity, start: startDate, end: endDate)
        samples.append(distanceSample)
        
        try await builder.addSamples(samples)
        try await builder.endCollection(at: endDate)
        
        // Add metadata
        try await builder.addMetadata([
            HKMetadataKeyWorkoutBrandName: "RoundCaddy",
            "CourseName": courseName,
            "HolesPlayed": holesPlayed
        ])
        
        // Finish and save
        guard let workout = try await builder.finishWorkout() else {
            throw HealthKitError.workoutSaveFailed
        }
        
        print("✅ Saved completed round as workout: \(courseName)")
        
        return workout
    }
    
    // MARK: - Estimations
    
    /// Estimate calories burned during golf
    private func estimateCalories(duration: TimeInterval, holes: Int = 18) -> Double {
        // Walking golf: ~300-400 kcal/hour
        // Riding golf: ~200-250 kcal/hour
        // We'll use walking estimate
        let hours = duration / 3600
        let baseRate: Double = 350 // kcal per hour
        return hours * baseRate
    }
    
    /// Estimate distance walked during golf
    private func estimateDistance(duration: TimeInterval, holes: Int = 18) -> Double {
        // Average 18-hole course: 5.5-6.5 km
        // Adjust based on holes played
        let fullCourseDistance: Double = 6000 // meters
        let holesRatio = Double(holes) / 18.0
        return fullCourseDistance * holesRatio
    }
    
    /// Estimate steps during golf
    private func estimateSteps(duration: TimeInterval, holes: Int = 18) -> Int {
        // Average: ~10,000 steps for 18 holes
        let fullSteps = 10000
        let holesRatio = Double(holes) / 18.0
        return Int(Double(fullSteps) * holesRatio)
    }
    
    // MARK: - Reading Data
    
    /// Get recent golf workouts
    func getRecentGolfWorkouts(limit: Int = 10) async throws -> [HKWorkout] {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }
        
        let workoutType = HKObjectType.workoutType()
        let golfPredicate = HKQuery.predicateForWorkouts(with: .golf)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: golfPredicate,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let workouts = samples as? [HKWorkout] ?? []
                continuation.resume(returning: workouts)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Get total golf stats for a time period
    func getGolfStats(from startDate: Date, to endDate: Date) async throws -> GolfHealthStats {
        let workouts = try await getRecentGolfWorkouts(limit: 100)
        
        let filteredWorkouts = workouts.filter {
            $0.startDate >= startDate && $0.endDate <= endDate
        }
        
        let totalDuration = filteredWorkouts.reduce(0) { $0 + $1.duration }
        let totalCalories = filteredWorkouts.reduce(0.0) {
            $0 + ($1.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0)
        }
        let totalDistance = filteredWorkouts.reduce(0.0) {
            $0 + ($1.totalDistance?.doubleValue(for: .meter()) ?? 0)
        }
        
        return GolfHealthStats(
            roundCount: filteredWorkouts.count,
            totalDuration: totalDuration,
            totalCalories: totalCalories,
            totalDistance: totalDistance / 1000, // Convert to km
            averageDuration: filteredWorkouts.isEmpty ? 0 : totalDuration / Double(filteredWorkouts.count)
        )
    }
    
    // MARK: - Preferences
    
    private func loadPreferences() {
        isLoggingEnabled = UserDefaults.standard.bool(forKey: "healthkit_logging_enabled")
    }
    
    func setLoggingEnabled(_ enabled: Bool) {
        isLoggingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "healthkit_logging_enabled")
    }
}

// MARK: - Supporting Types

enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized
    case noActiveWorkout
    case saveFailed
    case workoutSaveFailed
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .notAuthorized:
            return "HealthKit access not authorized. Please enable in Settings."
        case .noActiveWorkout:
            return "No active workout to end"
        case .saveFailed:
            return "Failed to save workout to HealthKit"
        case .workoutSaveFailed:
            return "Failed to finish and save workout"
        }
    }
}

struct GolfHealthStats {
    let roundCount: Int
    let totalDuration: TimeInterval
    let totalCalories: Double
    let totalDistance: Double // in km
    let averageDuration: TimeInterval
    
    var formattedTotalDuration: String {
        let hours = Int(totalDuration / 3600)
        let minutes = Int((totalDuration.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }
    
    var formattedAverageDuration: String {
        let hours = Int(averageDuration / 3600)
        let minutes = Int((averageDuration.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

/// View for HealthKit settings and stats
struct HealthKitSettingsView: View {
    @ObservedObject var healthKitManager = HealthKitManager.shared
    @State private var recentStats: GolfHealthStats?
    @State private var isLoading = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    
                    VStack(alignment: .leading) {
                        Text("Apple Health")
                            .font(.headline)
                        Text(healthKitManager.isAuthorized ? "Connected" : "Not Connected")
                            .font(.caption)
                            .foregroundStyle(healthKitManager.isAuthorized ? .green : .secondary)
                    }
                    
                    Spacer()
                    
                    if !healthKitManager.isAuthorized {
                        Button("Connect") {
                            Task {
                                try? await healthKitManager.requestAuthorization()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            if healthKitManager.isAuthorized {
                Section("Settings") {
                    Toggle("Log rounds as workouts", isOn: Binding(
                        get: { healthKitManager.isLoggingEnabled },
                        set: { healthKitManager.setLoggingEnabled($0) }
                    ))
                }
                
                Section("Golf Activity (Last 30 Days)") {
                    if isLoading {
                        ProgressView()
                    } else if let stats = recentStats {
                        LabeledContent("Rounds Played", value: "\(stats.roundCount)")
                        LabeledContent("Total Time", value: stats.formattedTotalDuration)
                        LabeledContent("Calories Burned", value: "\(Int(stats.totalCalories)) kcal")
                        LabeledContent("Distance Walked", value: String(format: "%.1f km", stats.totalDistance))
                        LabeledContent("Avg Round Duration", value: stats.formattedAverageDuration)
                    } else {
                        Text("No data available")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section {
                Text("When enabled, your golf rounds will be saved to Apple Health as workouts, including estimated calories burned and distance walked.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Apple Health")
        .onAppear {
            loadStats()
        }
    }
    
    private func loadStats() {
        guard healthKitManager.isAuthorized else { return }
        
        isLoading = true
        
        Task {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate)!
            
            do {
                let stats = try await healthKitManager.getGolfStats(from: startDate, to: endDate)
                await MainActor.run {
                    recentStats = stats
                    isLoading = false
                }
            } catch {
                print("Failed to load stats: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

/// Compact health stats card for dashboard
struct HealthStatsCard: View {
    @ObservedObject var healthKitManager = HealthKitManager.shared
    @State private var stats: GolfHealthStats?
    
    var body: some View {
        if healthKitManager.isAuthorized, let stats = stats {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text("This Month's Activity")
                        .font(.headline)
                }
                
                HStack(spacing: 20) {
                    StatItem(value: "\(stats.roundCount)", label: "Rounds")
                    StatItem(value: "\(Int(stats.totalCalories))", label: "Calories")
                    StatItem(value: String(format: "%.0f", stats.totalDistance), label: "km Walked")
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onAppear {
                loadStats()
            }
        }
    }
    
    private func loadStats() {
        Task {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate)!
            stats = try? await healthKitManager.getGolfStats(from: startDate, to: endDate)
        }
    }
}

private struct StatItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
