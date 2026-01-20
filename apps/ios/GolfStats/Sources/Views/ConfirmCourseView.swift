import SwiftUI
import CoreLocation

struct ConfirmCourseView: View {
    let course: Course
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var gpsManager: GPSManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedHole: Int = 1
    @State private var holeConfirmations: [Int: HoleConfirmation] = [:]
    @State private var confidenceLevel: Double = 3.0
    @State private var discrepancyNotes = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    var numberOfHoles: Int {
        course.holeData?.count ?? 18
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text(course.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Confirm Course Data - Hole by Hole")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Walk the course and mark each location with GPS. This helps verify course data accuracy.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    // Hole Selector
                    Section {
                        Picker("Select Hole", selection: $selectedHole) {
                            ForEach(1...numberOfHoles, id: \.self) { hole in
                                Text("Hole \(hole)").tag(hole)
                            }
                        }
                        .pickerStyle(.menu)
                    } header: {
                        Text("Current Hole")
                    }
                    .padding(.horizontal)
                    
                    // Current Hole Confirmation
                    if let holeData = course.holeData?.first(where: { $0.holeNumber == selectedHole }) {
                        HoleConfirmationSection(
                            holeNumber: selectedHole,
                            holeData: holeData,
                            confirmation: Binding(
                                get: { holeConfirmations[selectedHole] ?? HoleConfirmation(holeNumber: selectedHole) },
                                set: { holeConfirmations[selectedHole] = $0 }
                            ),
                            gpsManager: gpsManager
                        )
                        .padding(.horizontal)
                    }
                    
                    // Overall Confidence
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Overall Confidence Level")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack {
                            Text("1")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Slider(value: $confidenceLevel, in: 1...5, step: 1)
                            Text("5")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Text("\(Int(confidenceLevel)) - \(confidenceDescription)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color("BackgroundSecondary"))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Overall Notes (Optional)")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        TextField("Any discrepancies or additional notes...", text: $discrepancyNotes, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color("BackgroundTertiary"))
                            .cornerRadius(8)
                            .lineLimit(3...6)
                    }
                    .padding()
                    .background(Color("BackgroundSecondary"))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Progress Summary
                    let confirmedCount = holeConfirmations.values.filter { $0.isComplete }.count
                    VStack(spacing: 8) {
                        Text("Progress: \(confirmedCount) of \(numberOfHoles) holes confirmed")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        ProgressView(value: Double(confirmedCount), total: Double(numberOfHoles))
                            .tint(.green)
                    }
                    .padding()
                    .background(Color("BackgroundSecondary"))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Error Message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    // Submit Button
                    Button {
                        Task {
                            await submitConfirmation()
                        }
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text(isSubmitting ? "Submitting..." : "Submit Confirmation")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    .disabled(isSubmitting)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding(.vertical)
            }
            .background(Color("Background"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Confirmation Submitted", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for confirming this course data!")
            }
            .onAppear {
                gpsManager.startTracking()
            }
            .onDisappear {
                gpsManager.stopTracking()
            }
        }
    }
    
    private var confidenceDescription: String {
        switch Int(confidenceLevel) {
        case 1: return "Not confident"
        case 2: return "Somewhat confident"
        case 3: return "Confident"
        case 4: return "Very confident"
        case 5: return "Extremely confident"
        default: return ""
        }
    }
    
    private func submitConfirmation() async {
        guard let user = authManager.currentUser else {
            errorMessage = "Please sign in to confirm courses"
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        do {
            // Convert hole confirmations to the format expected by API
            let dimensionsMatch = holeConfirmations.values.allSatisfy { $0.dimensionsMatch }
            let teeLocationsMatch = holeConfirmations.values.allSatisfy { $0.teeLocationsMatch }
            let greenLocationsMatch = holeConfirmations.values.allSatisfy { $0.greenLocationsMatch }
            let hazardLocationsMatch = holeConfirmations.values.allSatisfy { $0.hazardLocationsMatch }
            
            // Convert hole confirmations to JSON
            let holeConfirmationsJSON = holeConfirmations.mapValues { $0.toJSON() }
            
            try await DataService.shared.confirmCourse(
                courseId: course.id,
                userId: user.id,
                authHeaders: authManager.authHeaders,
                dimensionsMatch: dimensionsMatch,
                teeLocationsMatch: teeLocationsMatch,
                greenLocationsMatch: greenLocationsMatch,
                hazardLocationsMatch: hazardLocationsMatch,
                confidenceLevel: Int(confidenceLevel),
                discrepancyNotes: discrepancyNotes.isEmpty ? nil : discrepancyNotes,
                holeConfirmations: holeConfirmationsJSON
            )
            
            showSuccess = true
        } catch {
            errorMessage = "Failed to submit confirmation: \(error.localizedDescription)"
        }
        
        isSubmitting = false
    }
}

struct HoleConfirmation {
    var holeNumber: Int
    var dimensionsMatch: Bool = false
    var teeLocationsMatch: Bool = false
    var greenLocationsMatch: Bool = false
    var hazardLocationsMatch: Bool = false
    
    // GPS marked locations
    var markedTeeBox: CLLocationCoordinate2D?
    var markedGreenCenter: CLLocationCoordinate2D?
    var markedGreenFront: CLLocationCoordinate2D?
    var markedGreenBack: CLLocationCoordinate2D?
    var markedHazards: [CLLocationCoordinate2D] = []
    
    var notes: String = ""
    
    var isComplete: Bool {
        dimensionsMatch && teeLocationsMatch && greenLocationsMatch && hazardLocationsMatch
    }
    
    func toJSON() -> [String: Any] {
        var json: [String: Any] = [
            "hole_number": holeNumber,
            "dimensions_match": dimensionsMatch,
            "tee_locations_match": teeLocationsMatch,
            "green_locations_match": greenLocationsMatch,
            "hazard_locations_match": hazardLocationsMatch,
            "notes": notes
        ]
        
        if let teeBox = markedTeeBox {
            json["marked_tee_box"] = ["lat": teeBox.latitude, "lon": teeBox.longitude]
        }
        if let center = markedGreenCenter {
            json["marked_green_center"] = ["lat": center.latitude, "lon": center.longitude]
        }
        if let front = markedGreenFront {
            json["marked_green_front"] = ["lat": front.latitude, "lon": front.longitude]
        }
        if let back = markedGreenBack {
            json["marked_green_back"] = ["lat": back.latitude, "lon": back.longitude]
        }
        if !markedHazards.isEmpty {
            json["marked_hazards"] = markedHazards.map { ["lat": $0.latitude, "lon": $0.longitude] }
        }
        
        return json
    }
}

struct HoleConfirmationSection: View {
    let holeNumber: Int
    let holeData: HoleData
    @Binding var confirmation: HoleConfirmation
    let gpsManager: GPSManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hole \(holeNumber) - Par \(holeData.par)")
                .font(.headline)
                .foregroundColor(.white)
            
            // Dimensions & Yardages
            ConfirmationItem(
                title: "Dimensions & Yardages",
                isChecked: $confirmation.dimensionsMatch,
                description: "Par: \(holeData.par), Yardage: \(holeData.yardages?["total"] ?? 0)"
            )
            
            // Tee Box Location
            ConfirmationItemWithGPS(
                title: "Tee Box Location",
                isChecked: $confirmation.teeLocationsMatch,
                markedLocation: $confirmation.markedTeeBox,
                gpsManager: gpsManager,
                description: "Mark the tee box location with GPS"
            )
            
            // Green Locations
            VStack(alignment: .leading, spacing: 12) {
                Text("Green Locations")
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                ConfirmationItemWithGPS(
                    title: "Green Center",
                    isChecked: Binding(
                        get: { confirmation.greenLocationsMatch },
                        set: { confirmation.greenLocationsMatch = $0 }
                    ),
                    markedLocation: $confirmation.markedGreenCenter,
                    gpsManager: gpsManager,
                    description: nil
                )
                
                ConfirmationItemWithGPS(
                    title: "Green Front",
                    isChecked: Binding(
                        get: { confirmation.greenLocationsMatch },
                        set: { confirmation.greenLocationsMatch = $0 }
                    ),
                    markedLocation: $confirmation.markedGreenFront,
                    gpsManager: gpsManager,
                    description: nil
                )
                
                ConfirmationItemWithGPS(
                    title: "Green Back",
                    isChecked: Binding(
                        get: { confirmation.greenLocationsMatch },
                        set: { confirmation.greenLocationsMatch = $0 }
                    ),
                    markedLocation: $confirmation.markedGreenBack,
                    gpsManager: gpsManager,
                    description: nil
                )
            }
            .padding()
            .background(Color("BackgroundTertiary"))
            .cornerRadius(12)
            
            // Hazard Locations
            ConfirmationItem(
                title: "Hazard Locations",
                isChecked: $confirmation.hazardLocationsMatch,
                description: "Mark hazards if present"
            )
            
            // Notes for this hole
            TextField("Notes for this hole...", text: $confirmation.notes, axis: .vertical)
                .textFieldStyle(.plain)
                .padding()
                .background(Color("BackgroundTertiary"))
                .cornerRadius(8)
                .lineLimit(2...4)
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
    }
}

struct ConfirmationItem: View {
    let title: String
    @Binding var isChecked: Bool
    let description: String?
    
    var body: some View {
        HStack {
            Button {
                isChecked.toggle()
            } label: {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isChecked ? .green : .gray)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .foregroundColor(.white)
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color("BackgroundTertiary"))
        .cornerRadius(12)
    }
}

struct ConfirmationItemWithGPS: View {
    let title: String
    @Binding var isChecked: Bool
    @Binding var markedLocation: CLLocationCoordinate2D?
    let gpsManager: GPSManager
    let description: String?
    
    var body: some View {
        HStack {
            Button {
                isChecked.toggle()
            } label: {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isChecked ? .green : .gray)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundColor(.white)
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                if let location = markedLocation {
                    Text("Lat: \(location.latitude, specifier: "%.6f"), Lon: \(location.longitude, specifier: "%.6f")")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            Button {
                if let currentLocation = gpsManager.currentLocation {
                    markedLocation = currentLocation.coordinate
                    isChecked = true
                }
            } label: {
                Image(systemName: "location.fill")
                    .foregroundColor(.green)
            }
            .disabled(gpsManager.currentLocation == nil)
        }
        .padding()
        .background(Color("BackgroundTertiary"))
        .cornerRadius(12)
    }
}

#Preview {
    ConfirmCourseView(
        course: Course(
            id: "1",
            name: "Pebble Beach",
            city: "Pebble Beach",
            state: "CA",
            country: "USA",
            address: nil,
            phone: nil,
            website: nil,
            courseRating: 75.5,
            slopeRating: 145,
            par: 72,
            holes: 18,
            latitude: 36.5725,
            longitude: -121.9486,
            avgRating: 4.8,
            reviewCount: 150,
            holeData: [
                HoleData(
                    holeNumber: 1,
                    par: 4,
                    yardages: ["total": 380],
                    greenCenter: Coordinate(lat: 36.5725, lon: -121.9486),
                    greenFront: nil,
                    greenBack: nil,
                    teeLocations: nil,
                    fairway: nil,
                    green: nil,
                    rough: nil,
                    bunkers: nil,
                    waterHazards: nil,
                    trees: nil,
                    yardageMarkers: nil
                )
            ],
            updatedAt: nil,
            createdAt: nil
        )
    )
    .environmentObject(AuthManager())
    .environmentObject(GPSManager())
    .preferredColorScheme(.dark)
}
