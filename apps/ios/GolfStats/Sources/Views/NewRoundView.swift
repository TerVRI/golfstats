import SwiftUI

struct NewRoundView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var roundManager: RoundManager
    @Environment(\.dismiss) var dismiss
    
    @State private var courseName = ""
    @State private var courseRating = ""
    @State private var slopeRating = ""
    @State private var totalScore = ""
    @State private var totalPutts = ""
    @State private var fairwaysHit = ""
    @State private var fairwaysTotal = "14"
    @State private var gir = ""
    @State private var penalties = "0"
    @State private var isSaving = false
    @State private var error: String?
    
    @State private var courses: [Course] = []
    @State private var selectedCourse: Course?
    @State private var showCoursePicker = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Course Section
                Section("Course") {
                    Button {
                        showCoursePicker = true
                    } label: {
                        HStack {
                            Text(selectedCourse?.name ?? "Select Course")
                                .foregroundColor(selectedCourse == nil ? .gray : .white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if selectedCourse == nil {
                        TextField("Or enter course name", text: $courseName)
                    }
                    
                    HStack {
                        TextField("Rating", text: $courseRating)
                            .keyboardType(.decimalPad)
                        TextField("Slope", text: $slopeRating)
                            .keyboardType(.numberPad)
                    }
                }
                
                // Score Section
                Section("Score") {
                    TextField("Total Score", text: $totalScore)
                        .keyboardType(.numberPad)
                        .font(.title)
                    
                    TextField("Total Putts", text: $totalPutts)
                        .keyboardType(.numberPad)
                }
                
                // Stats Section
                Section("Stats") {
                    HStack {
                        TextField("Fairways Hit", text: $fairwaysHit)
                            .keyboardType(.numberPad)
                        Text("/")
                            .foregroundColor(.gray)
                        TextField("Total", text: $fairwaysTotal)
                            .keyboardType(.numberPad)
                    }
                    
                    TextField("Greens in Regulation", text: $gir)
                        .keyboardType(.numberPad)
                    
                    TextField("Penalties", text: $penalties)
                        .keyboardType(.numberPad)
                }
                
                // Error
                if let error = error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color("Background"))
            .navigationTitle("New Round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveRound() }
                    }
                    .disabled(isSaving || totalScore.isEmpty)
                }
            }
            .sheet(isPresented: $showCoursePicker) {
                CoursePickerView(selectedCourse: $selectedCourse) {
                    if let course = selectedCourse {
                        courseName = course.name
                        if let rating = course.courseRating {
                            courseRating = String(format: "%.1f", rating)
                        }
                        if let slope = course.slopeRating {
                            slopeRating = "\(slope)"
                        }
                    }
                }
            }
        }
        .task {
            await loadCourses()
        }
    }
    
    private func loadCourses() async {
        do {
            courses = try await DataService.shared.fetchCourses(limit: 100)
        } catch {
            print("Error loading courses: \(error)")
        }
    }
    
    private func saveRound() async {
        guard let user = authManager.currentUser,
              let score = Int(totalScore) else {
            error = "Please enter a valid score"
            return
        }
        
        isSaving = true
        error = nil
        
        let finalCourseName = selectedCourse?.name ?? courseName
        guard !finalCourseName.isEmpty else {
            error = "Please select or enter a course name"
            isSaving = false
            return
        }
        
        do {
            let roundData: [String: Any] = [
                "user_id": user.id,
                "course_name": finalCourseName,
                "played_at": ISO8601DateFormatter().string(from: Date()).prefix(10).description,
                "total_score": score,
                "total_putts": Int(totalPutts) as Any,
                "fairways_hit": Int(fairwaysHit) as Any,
                "fairways_total": Int(fairwaysTotal) ?? 14,
                "gir": Int(gir) as Any,
                "penalties": Int(penalties) ?? 0,
                "course_rating": Double(courseRating) as Any,
                "slope_rating": Int(slopeRating) as Any,
                "scoring_format": "stroke"
            ]
            
            var request = URLRequest(url: URL(string: "https://kanvhqwrfkzqktuvpxnp.supabase.co/rest/v1/rounds")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            for (key, value) in authManager.authHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
            
            request.httpBody = try JSONSerialization.data(withJSONObject: roundData)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
                throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to save round"])
            }
            
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        
        isSaving = false
    }
}

struct CoursePickerView: View {
    @Binding var selectedCourse: Course?
    let onSelect: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var courses: [Course] = []
    @State private var searchText = ""
    @State private var isLoading = true
    
    var filteredCourses: [Course] {
        if searchText.isEmpty {
            return courses
        }
        return courses.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    List(filteredCourses) { course in
                        Button {
                            selectedCourse = course
                            onSelect()
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(course.name)
                                        .foregroundColor(.white)
                                    if !course.location.isEmpty {
                                        Text(course.location)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Spacer()
                                
                                if selectedCourse?.id == course.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search courses")
                }
            }
            .navigationTitle("Select Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task {
            await loadCourses()
        }
    }
    
    private func loadCourses() async {
        do {
            courses = try await DataService.shared.fetchCourses(limit: 100)
        } catch {
            print("Error loading courses: \(error)")
        }
        isLoading = false
    }
}

#Preview {
    NewRoundView()
        .environmentObject(AuthManager())
        .environmentObject(RoundManager())
        .preferredColorScheme(.dark)
}
