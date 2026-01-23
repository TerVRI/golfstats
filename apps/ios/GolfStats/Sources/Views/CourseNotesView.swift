import SwiftUI

/// Course notes system with personal and community notes for each hole
struct CourseNotesView: View {
    let course: Course
    @StateObject private var viewModel: CourseNotesViewModel
    @State private var selectedHole: Int = 1
    @State private var showAddNote = false
    
    init(course: Course) {
        self.course = course
        _viewModel = StateObject(wrappedValue: CourseNotesViewModel(courseId: course.id))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Hole picker
            holePicker
            
            // Notes content
            ScrollView {
                VStack(spacing: 16) {
                    // My notes section
                    myNotesSection
                    
                    // Community notes section
                    communityNotesSection
                }
                .padding()
            }
        }
        .navigationTitle("Course Notes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showAddNote = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddNote) {
            AddNoteSheet(
                courseId: course.id,
                holeNumber: selectedHole,
                viewModel: viewModel
            )
        }
        .task {
            await viewModel.loadNotes()
        }
    }
    
    // MARK: - Hole Picker
    
    private var holePicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // All holes option
                    holeButton(number: 0, label: "All")
                    
                    ForEach(1...18, id: \.self) { hole in
                        holeButton(number: hole, label: "\(hole)")
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: selectedHole) { _, newHole in
                withAnimation {
                    proxy.scrollTo(newHole, anchor: .center)
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }
    
    private func holeButton(number: Int, label: String) -> some View {
        Button(action: { selectedHole = number }) {
            Text(label)
                .font(.subheadline)
                .fontWeight(selectedHole == number ? .bold : .regular)
                .foregroundStyle(selectedHole == number ? .white : .primary)
                .frame(width: number == 0 ? 50 : 36, height: 36)
                .background(selectedHole == number ? Color.green : Color(.tertiarySystemBackground))
                .clipShape(Circle())
        }
        .id(number)
    }
    
    // MARK: - My Notes Section
    
    private var myNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundStyle(.blue)
                Text("My Notes")
                    .font(.headline)
                
                Spacer()
                
                Text("\(viewModel.myNotes(for: selectedHole).count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            let notes = viewModel.myNotes(for: selectedHole)
            
            if notes.isEmpty {
                EmptyNotesView(
                    message: "No personal notes yet",
                    action: { showAddNote = true }
                )
            } else {
                ForEach(notes) { note in
                    PersonalNoteCard(note: note, viewModel: viewModel)
                }
            }
        }
    }
    
    // MARK: - Community Notes Section
    
    private var communityNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundStyle(.purple)
                Text("Community Notes")
                    .font(.headline)
                
                Spacer()
                
                Text("\(viewModel.communityNotes(for: selectedHole).count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            let notes = viewModel.communityNotes(for: selectedHole)
            
            if notes.isEmpty {
                EmptyNotesView(
                    message: "No community notes yet",
                    subtitle: "Be the first to share a tip!"
                )
            } else {
                ForEach(notes) { note in
                    CommunityNoteCard(note: note, viewModel: viewModel)
                }
            }
        }
    }
}

// MARK: - View Model

class CourseNotesViewModel: ObservableObject {
    let courseId: String
    
    @Published var personalNotes: [CourseNote] = []
    @Published var communityNotes: [CourseNote] = []
    @Published var isLoading = false
    
    init(courseId: String) {
        self.courseId = courseId
    }
    
    func myNotes(for hole: Int) -> [CourseNote] {
        if hole == 0 {
            return personalNotes
        }
        return personalNotes.filter { $0.holeNumber == hole }
    }
    
    func communityNotes(for hole: Int) -> [CourseNote] {
        if hole == 0 {
            return communityNotes.sorted { $0.votes > $1.votes }
        }
        return communityNotes.filter { $0.holeNumber == hole }.sorted { $0.votes > $1.votes }
    }
    
    // MARK: - Data Loading
    
    func loadNotes() async {
        isLoading = true
        
        // Load personal notes from local storage
        loadPersonalNotes()
        
        // Load community notes from server
        await loadCommunityNotes()
        
        isLoading = false
    }
    
    private func loadPersonalNotes() {
        let key = "personal_notes_\(courseId)"
        if let data = UserDefaults.standard.data(forKey: key),
           let notes = try? JSONDecoder().decode([CourseNote].self, from: data) {
            DispatchQueue.main.async {
                self.personalNotes = notes
            }
        }
    }
    
    private func loadCommunityNotes() async {
        // Would fetch from API
        // For now, use sample data
        await MainActor.run {
            self.communityNotes = CourseNote.sampleCommunityNotes
        }
    }
    
    // MARK: - Note Management
    
    func addNote(_ note: CourseNote) {
        var newNote = note
        newNote.id = UUID().uuidString
        newNote.createdAt = Date()
        
        if note.isPersonal {
            personalNotes.append(newNote)
            savePersonalNotes()
        } else {
            // Would upload to server
            communityNotes.append(newNote)
        }
    }
    
    func updateNote(_ note: CourseNote) {
        if note.isPersonal {
            if let index = personalNotes.firstIndex(where: { $0.id == note.id }) {
                personalNotes[index] = note
                savePersonalNotes()
            }
        }
    }
    
    func deleteNote(_ note: CourseNote) {
        if note.isPersonal {
            personalNotes.removeAll { $0.id == note.id }
            savePersonalNotes()
        }
    }
    
    private func savePersonalNotes() {
        let key = "personal_notes_\(courseId)"
        if let data = try? JSONEncoder().encode(personalNotes) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    // MARK: - Voting
    
    func upvote(_ note: CourseNote) {
        guard let index = communityNotes.firstIndex(where: { $0.id == note.id }) else { return }
        
        if communityNotes[index].userVote == .up {
            communityNotes[index].votes -= 1
            communityNotes[index].userVote = .none
        } else {
            if communityNotes[index].userVote == .down {
                communityNotes[index].votes += 1
            }
            communityNotes[index].votes += 1
            communityNotes[index].userVote = .up
        }
        
        // Would sync with server
    }
    
    func downvote(_ note: CourseNote) {
        guard let index = communityNotes.firstIndex(where: { $0.id == note.id }) else { return }
        
        if communityNotes[index].userVote == .down {
            communityNotes[index].votes += 1
            communityNotes[index].userVote = .none
        } else {
            if communityNotes[index].userVote == .up {
                communityNotes[index].votes -= 1
            }
            communityNotes[index].votes -= 1
            communityNotes[index].userVote = .down
        }
        
        // Would sync with server
    }
    
    func reportNote(_ note: CourseNote) {
        // Would send report to server
        print("Reported note: \(note.id)")
    }
}

// MARK: - Data Models

struct CourseNote: Identifiable, Codable {
    var id: String
    let courseId: String
    let holeNumber: Int
    var content: String
    var category: NoteCategory
    var isPersonal: Bool
    var votes: Int
    var userVote: VoteType
    var authorName: String?
    var createdAt: Date
    var updatedAt: Date?
    
    init(
        id: String = UUID().uuidString,
        courseId: String,
        holeNumber: Int,
        content: String,
        category: NoteCategory = .general,
        isPersonal: Bool = true,
        votes: Int = 0,
        authorName: String? = nil
    ) {
        self.id = id
        self.courseId = courseId
        self.holeNumber = holeNumber
        self.content = content
        self.category = category
        self.isPersonal = isPersonal
        self.votes = votes
        self.userVote = .none
        self.authorName = authorName
        self.createdAt = Date()
    }
    
    static let sampleCommunityNotes: [CourseNote] = [
        CourseNote(
            courseId: "sample",
            holeNumber: 1,
            content: "The green breaks more than it looks - always play for more break on putts",
            category: .putting,
            isPersonal: false,
            votes: 15,
            authorName: "GolfPro123"
        ),
        CourseNote(
            courseId: "sample",
            holeNumber: 1,
            content: "Layup to 100 yards is safer than going for the green in two",
            category: .strategy,
            isPersonal: false,
            votes: 8,
            authorName: "LocalPlayer"
        ),
        CourseNote(
            courseId: "sample",
            holeNumber: 3,
            content: "Wind is always stronger than it appears on this hole",
            category: .conditions,
            isPersonal: false,
            votes: 12,
            authorName: "WindWatcher"
        )
    ]
}

enum NoteCategory: String, Codable, CaseIterable {
    case general = "General"
    case teeShot = "Tee Shot"
    case approach = "Approach"
    case putting = "Putting"
    case hazards = "Hazards"
    case strategy = "Strategy"
    case conditions = "Conditions"
    
    var icon: String {
        switch self {
        case .general: return "note.text"
        case .teeShot: return "figure.golf"
        case .approach: return "scope"
        case .putting: return "flag.fill"
        case .hazards: return "exclamationmark.triangle"
        case .strategy: return "lightbulb"
        case .conditions: return "wind"
        }
    }
    
    var color: Color {
        switch self {
        case .general: return .gray
        case .teeShot: return .blue
        case .approach: return .green
        case .putting: return .red
        case .hazards: return .orange
        case .strategy: return .purple
        case .conditions: return .cyan
        }
    }
}

enum VoteType: String, Codable {
    case none, up, down
}

// MARK: - Supporting Views

struct PersonalNoteCard: View {
    let note: CourseNote
    @ObservedObject var viewModel: CourseNotesViewModel
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Label(note.category.rawValue, systemImage: note.category.icon)
                    .font(.caption)
                    .foregroundStyle(note.category.color)
                
                Spacer()
                
                Text("Hole \(note.holeNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Menu {
                    Button(action: { showEdit = true }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive, action: { showDeleteConfirm = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                }
            }
            
            // Content
            Text(note.content)
                .font(.subheadline)
            
            // Footer
            Text(note.createdAt, style: .date)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showEdit) {
            EditNoteSheet(note: note, viewModel: viewModel)
        }
        .alert("Delete Note?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteNote(note)
            }
        }
    }
}

struct CommunityNoteCard: View {
    let note: CourseNote
    @ObservedObject var viewModel: CourseNotesViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Label(note.category.rawValue, systemImage: note.category.icon)
                    .font(.caption)
                    .foregroundStyle(note.category.color)
                
                Spacer()
                
                Text("Hole \(note.holeNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Content
            Text(note.content)
                .font(.subheadline)
            
            // Footer
            HStack {
                if let author = note.authorName {
                    Text("by \(author)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Voting
                HStack(spacing: 12) {
                    Button(action: { viewModel.upvote(note) }) {
                        HStack(spacing: 4) {
                            Image(systemName: note.userVote == .up ? "arrow.up.circle.fill" : "arrow.up.circle")
                                .foregroundStyle(note.userVote == .up ? .green : .secondary)
                        }
                    }
                    
                    Text("\(note.votes)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(voteColor)
                    
                    Button(action: { viewModel.downvote(note) }) {
                        Image(systemName: note.userVote == .down ? "arrow.down.circle.fill" : "arrow.down.circle")
                            .foregroundStyle(note.userVote == .down ? .red : .secondary)
                    }
                }
                
                // Report
                Menu {
                    Button(action: { viewModel.reportNote(note) }) {
                        Label("Report", systemImage: "flag")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var voteColor: Color {
        if note.votes > 0 { return .green }
        if note.votes < 0 { return .red }
        return .secondary
    }
}

struct EmptyNotesView: View {
    let message: String
    var subtitle: String?
    var action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            if let action = action {
                Button("Add Note", action: action)
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

struct AddNoteSheet: View {
    let courseId: String
    let holeNumber: Int
    @ObservedObject var viewModel: CourseNotesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var content = ""
    @State private var category: NoteCategory = .general
    @State private var shareWithCommunity = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Hole", selection: .constant(holeNumber)) {
                        Text("Hole \(holeNumber)").tag(holeNumber)
                    }
                    
                    Picker("Category", selection: $category) {
                        ForEach(NoteCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                }
                
                Section("Note") {
                    TextEditor(text: $content)
                        .frame(minHeight: 100)
                }
                
                Section {
                    Toggle("Share with Community", isOn: $shareWithCommunity)
                } footer: {
                    Text("Community notes help other golfers. Your username will be shown.")
                }
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveNote()
                        dismiss()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func saveNote() {
        let note = CourseNote(
            courseId: courseId,
            holeNumber: holeNumber,
            content: content.trimmingCharacters(in: .whitespaces),
            category: category,
            isPersonal: !shareWithCommunity,
            authorName: shareWithCommunity ? "You" : nil
        )
        viewModel.addNote(note)
    }
}

struct EditNoteSheet: View {
    let note: CourseNote
    @ObservedObject var viewModel: CourseNotesViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var content: String
    @State private var category: NoteCategory
    
    init(note: CourseNote, viewModel: CourseNotesViewModel) {
        self.note = note
        self.viewModel = viewModel
        _content = State(initialValue: note.content)
        _category = State(initialValue: note.category)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(NoteCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                }
                
                Section("Note") {
                    TextEditor(text: $content)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        var updated = note
        updated.content = content.trimmingCharacters(in: .whitespaces)
        updated.category = category
        updated.updatedAt = Date()
        viewModel.updateNote(updated)
    }
}

// MARK: - Compact Note View (for in-round display)

struct HoleNotesCompact: View {
    let courseId: String
    let holeNumber: Int
    @State private var notes: [CourseNote] = []
    @State private var showAllNotes = false
    
    var body: some View {
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "note.text")
                        .foregroundStyle(.yellow)
                    Text("Notes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if notes.count > 1 {
                        Button("See All") { showAllNotes = true }
                            .font(.caption)
                    }
                }
                
                // Show top note
                if let topNote = notes.first {
                    Text(topNote.content)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onAppear {
                loadNotes()
            }
            .sheet(isPresented: $showAllNotes) {
                // Would show full notes view
                Text("All notes for hole \(holeNumber)")
            }
        }
    }
    
    private func loadNotes() {
        // Load from local + community
        let key = "personal_notes_\(courseId)"
        if let data = UserDefaults.standard.data(forKey: key),
           let allNotes = try? JSONDecoder().decode([CourseNote].self, from: data) {
            notes = allNotes.filter { $0.holeNumber == holeNumber }
        }
    }
}
