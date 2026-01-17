import SwiftUI

struct ConfirmCourseView: View {
    let course: Course
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var dimensionsMatch = true
    @State private var teeLocationsMatch = true
    @State private var greenLocationsMatch = true
    @State private var hazardLocationsMatch = true
    @State private var confidenceLevel: Double = 3.0
    @State private var discrepancyNotes = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
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
                        
                        Text("Confirm Course Data")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Please verify the following information matches what you see at the course:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    // Checklist
                    VStack(spacing: 16) {
                        ChecklistItem(
                            title: "Dimensions & Yardages",
                            isChecked: $dimensionsMatch
                        )
                        
                        ChecklistItem(
                            title: "Tee Box Locations",
                            isChecked: $teeLocationsMatch
                        )
                        
                        ChecklistItem(
                            title: "Green Locations",
                            isChecked: $greenLocationsMatch
                        )
                        
                        ChecklistItem(
                            title: "Hazard Locations",
                            isChecked: $hazardLocationsMatch
                        )
                    }
                    .padding(.horizontal)
                    
                    // Confidence Level
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confidence Level")
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
                    
                    // Discrepancy Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (Optional)")
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
                            Text(isSubmitting ? "Submitting..." : "Confirm Course Data")
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
            try await DataService.shared.confirmCourse(
                courseId: course.id,
                userId: user.id,
                authHeaders: authManager.authHeaders,
                dimensionsMatch: dimensionsMatch,
                teeLocationsMatch: teeLocationsMatch,
                greenLocationsMatch: greenLocationsMatch,
                hazardLocationsMatch: hazardLocationsMatch,
                confidenceLevel: Int(confidenceLevel),
                discrepancyNotes: discrepancyNotes.isEmpty ? nil : discrepancyNotes
            )
            
            showSuccess = true
        } catch {
            errorMessage = "Failed to submit confirmation: \(error.localizedDescription)"
        }
        
        isSubmitting = false
    }
}

struct ChecklistItem: View {
    let title: String
    @Binding var isChecked: Bool
    
    var body: some View {
        HStack {
            Button {
                isChecked.toggle()
            } label: {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isChecked ? .green : .gray)
                    .font(.title3)
            }
            
            Text(title)
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding()
        .background(Color("BackgroundSecondary"))
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
            courseRating: 75.5,
            slopeRating: 145,
            par: 72,
            latitude: 36.5725,
            longitude: -121.9486,
            avgRating: 4.8,
            reviewCount: 150,
            holeData: nil
        )
    )
    .environmentObject(AuthManager())
    .preferredColorScheme(.dark)
}
