import SwiftUI

struct EditRoundView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    let round: Round

    @State private var courseName: String
    @State private var courseRating: String
    @State private var slopeRating: String
    @State private var totalScore: String
    @State private var totalPutts: String
    @State private var fairwaysHit: String
    @State private var fairwaysTotal: String
    @State private var gir: String
    @State private var penalties: String
    @State private var isSaving = false
    @State private var error: String?

    @State private var courses: [Course] = []
    @State private var selectedCourse: Course?
    @State private var showCoursePicker = false

    init(round: Round) {
        self.round = round
        _courseName = State(initialValue: round.courseName)
        _courseRating = State(initialValue: round.courseRating.map { String(format: "%.1f", $0) } ?? "")
        _slopeRating = State(initialValue: round.slopeRating.map { "\($0)" } ?? "")
        _totalScore = State(initialValue: "\(round.totalScore)")
        _totalPutts = State(initialValue: round.totalPutts.map { "\($0)" } ?? "")
        _fairwaysHit = State(initialValue: round.fairwaysHit.map { "\($0)" } ?? "")
        _fairwaysTotal = State(initialValue: round.fairwaysTotal.map { "\($0)" } ?? "14")
        _gir = State(initialValue: round.gir.map { "\($0)" } ?? "")
        _penalties = State(initialValue: round.penalties.map { "\($0)" } ?? "0")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Course") {
                    Button {
                        showCoursePicker = true
                    } label: {
                        HStack {
                            Text(selectedCourse?.name ?? courseName)
                                .foregroundColor((selectedCourse == nil && courseName.isEmpty) ? .gray : .white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }

                    if selectedCourse == nil {
                        TextField("Course name", text: $courseName)
                    }

                    HStack {
                        TextField("Rating", text: $courseRating)
                            .keyboardType(.decimalPad)
                        TextField("Slope", text: $slopeRating)
                            .keyboardType(.numberPad)
                    }
                }

                Section {
                    TextField("Total Score", text: $totalScore)
                        .keyboardType(.numberPad)
                        .font(.title)
                    TextField("Total Putts", text: $totalPutts)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Score")
                }

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

                if let error = error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color("Background"))
            .navigationTitle("Edit Round")
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
        guard authManager.currentUser != nil,
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

        let payload: [String: Any] = [
            "course_name": finalCourseName,
            "total_score": score,
            "total_putts": Int(totalPutts) as Any,
            "fairways_hit": Int(fairwaysHit) as Any,
            "fairways_total": Int(fairwaysTotal) ?? 14,
            "gir": Int(gir) as Any,
            "penalties": Int(penalties) ?? 0,
            "course_rating": Double(courseRating) as Any,
            "slope_rating": Int(slopeRating) as Any
        ]

        do {
            try await DataService.shared.updateRound(
                id: round.id,
                authHeaders: authManager.authHeaders,
                payload: payload
            )
            NotificationCenter.default.post(name: .roundsUpdated, object: nil)
            dismiss()
        } catch {
            self.error = "Failed to update round"
        }

        isSaving = false
    }
}
