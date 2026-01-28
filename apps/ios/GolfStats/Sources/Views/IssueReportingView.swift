import SwiftUI

/// View for reporting issues with the app
struct IssueReportingView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var userProfileManager: UserProfileManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedIssues: Set<IssueType> = []
    @State private var additionalDetails: String = ""
    @State private var includeRoundData: Bool = true
    @State private var includeDiagnostics: Bool = true
    
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var errorMessage: String?
    
    // Optional context
    var roundId: String?
    var courseId: String?
    var holeNumber: Int?
    
    var body: some View {
        NavigationStack {
            List {
                // Issue Selection
                Section {
                    ForEach(IssueType.allCases, id: \.self) { issueType in
                        Button {
                            toggleIssue(issueType)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(issueType.displayName)
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                                
                                if selectedIssues.contains(issueType) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Select issues you've encountered")
                } footer: {
                    Text("Select all that apply. This helps us understand and fix the problem faster.")
                }
                
                // Additional Details
                Section {
                    ZStack(alignment: .topLeading) {
                        if additionalDetails.isEmpty {
                            Text("Describe the issue in more detail...")
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        
                        TextEditor(text: $additionalDetails)
                            .foregroundColor(.white)
                            .frame(minHeight: 100)
                            .scrollContentBackground(.hidden)
                    }
                } header: {
                    Text("Additional Details (Optional)")
                } footer: {
                    Text("Include any specific details like what you were doing when the issue occurred.")
                }
                
                // Data to Include
                Section {
                    Toggle(isOn: $includeRoundData) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Include Recent Round Data")
                                .foregroundColor(.white)
                            Text("Helps us understand context of the issue")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .tint(.green)
                    
                    Toggle(isOn: $includeDiagnostics) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Include Diagnostic Info")
                                .foregroundColor(.white)
                            Text("Device model, OS version, app version")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .tint(.green)
                } header: {
                    Text("Information to Include")
                }
                
                // Context Info (if provided)
                if roundId != nil || courseId != nil || holeNumber != nil {
                    Section {
                        if let roundId = roundId {
                            HStack {
                                Text("Round ID")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(String(roundId.prefix(8)) + "...")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                        }
                        
                        if let courseId = courseId {
                            HStack {
                                Text("Course ID")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(String(courseId.prefix(8)) + "...")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                        }
                        
                        if let holeNumber = holeNumber {
                            HStack {
                                Text("Hole Number")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(holeNumber)")
                                    .foregroundColor(.white)
                            }
                        }
                    } header: {
                        Text("Context")
                    }
                }
                
                // Submit Button
                Section {
                    Button {
                        submitReport()
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Submit Report")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(selectedIssues.isEmpty ? Color.gray : Color.green)
                        .cornerRadius(12)
                    }
                    .disabled(selectedIssues.isEmpty || isSubmitting)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color("Background"))
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Report Submitted", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for your feedback! Our team will review your report and work on a fix.")
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func toggleIssue(_ issue: IssueType) {
        if selectedIssues.contains(issue) {
            selectedIssues.remove(issue)
        } else {
            selectedIssues.insert(issue)
        }
    }
    
    private func submitReport() {
        guard let userId = authManager.currentUser?.id else {
            errorMessage = "Please sign in to submit a report"
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                // Build details with diagnostics if enabled
                var details = additionalDetails
                
                if includeDiagnostics {
                    details += "\n\n--- Diagnostics ---"
                    details += "\nDevice: \(UIDevice.current.model)"
                    details += "\nOS: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
                    details += "\nApp Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")"
                    details += "\nBuild: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")"
                }
                
                try await userProfileManager.submitIssueReport(
                    roundId: includeRoundData ? roundId : nil,
                    courseId: courseId,
                    holeNumber: holeNumber,
                    issueTypes: Array(selectedIssues),
                    additionalDetails: details.isEmpty ? nil : details,
                    userId: userId,
                    authHeaders: authManager.authHeaders
                )
                
                await MainActor.run {
                    isSubmitting = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Failed to submit report: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Quick Report Button (for use during rounds)

struct QuickIssueReportButton: View {
    @State private var showReportSheet = false
    
    var roundId: String?
    var courseId: String?
    var holeNumber: Int?
    
    var body: some View {
        Button {
            showReportSheet = true
        } label: {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.yellow)
        }
        .sheet(isPresented: $showReportSheet) {
            IssueReportingView(
                roundId: roundId,
                courseId: courseId,
                holeNumber: holeNumber
            )
        }
    }
}

// MARK: - Preview

#Preview {
    IssueReportingView()
        .environmentObject(AuthManager())
        .environmentObject(UserProfileManager.shared)
}
