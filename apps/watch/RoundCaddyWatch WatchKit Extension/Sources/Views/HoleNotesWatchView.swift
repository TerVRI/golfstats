import SwiftUI

/// Displays course notes for the current hole on the Watch
/// Notes are synced from iPhone's personal notes storage
struct HoleNotesWatchView: View {
    @ObservedObject var roundManager = RoundManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                headerView
                
                if roundManager.isRoundActive {
                    let notes = roundManager.currentHoleNotes
                    
                    if notes.isEmpty {
                        emptyNotesView
                    } else {
                        notesListView(notes)
                    }
                } else {
                    noRoundView
                }
            }
            .padding()
        }
        .navigationTitle("Notes")
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Image(systemName: "note.text")
                .foregroundStyle(.yellow)
            
            if roundManager.isRoundActive {
                Text("Hole \(roundManager.currentHole)")
                    .font(.headline)
            } else {
                Text("Course Notes")
                    .font(.headline)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Notes List
    
    private func notesListView(_ notes: [WatchHoleNote]) -> some View {
        VStack(spacing: 8) {
            ForEach(notes) { note in
                noteCard(note)
            }
            
            // Add on iPhone prompt
            addOnIPhoneButton
        }
    }
    
    private func noteCard(_ note: WatchHoleNote) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Category badge
            HStack {
                Image(systemName: note.categoryIcon)
                    .font(.caption2)
                    .foregroundStyle(note.categoryColor)
                
                Text(note.category)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            // Note content
            Text(note.content)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.darkGray).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Empty State
    
    private var emptyNotesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.title)
                .foregroundStyle(.secondary)
            
            Text("No notes for this hole")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            addOnIPhoneButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private var addOnIPhoneButton: some View {
        HStack {
            Image(systemName: "iphone")
                .font(.caption2)
            Text("Add on iPhone")
                .font(.caption2)
        }
        .foregroundStyle(.blue)
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.blue.opacity(0.2))
        .clipShape(Capsule())
    }
    
    // MARK: - No Round State
    
    private var noRoundView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.golf")
                .font(.title)
                .foregroundStyle(.secondary)
            
            Text("Start a round to see hole notes")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Watch Hole Note Model

struct WatchHoleNote: Identifiable, Codable {
    let id: String
    let holeNumber: Int
    let content: String
    let category: String
    let isPersonal: Bool
    
    var categoryIcon: String {
        switch category.lowercased() {
        case "tee shot": return "figure.golf"
        case "approach": return "scope"
        case "putting": return "flag.fill"
        case "hazards": return "exclamationmark.triangle"
        case "strategy": return "lightbulb"
        case "conditions": return "wind"
        default: return "note.text"
        }
    }
    
    var categoryColor: Color {
        switch category.lowercased() {
        case "tee shot": return .blue
        case "approach": return .green
        case "putting": return .red
        case "hazards": return .orange
        case "strategy": return .purple
        case "conditions": return .cyan
        default: return .gray
        }
    }
}

// MARK: - RoundManager Extension for Hole Notes

extension RoundManager {
    /// Notes for the current hole synced from iPhone
    var currentHoleNotes: [WatchHoleNote] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "holeNotes_\(currentHole)"),
                  let notes = try? JSONDecoder().decode([WatchHoleNote].self, from: data) else {
                return []
            }
            return notes
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "holeNotes_\(currentHole)")
            }
            objectWillChange.send()
        }
    }
    
    /// All notes for the course
    var allCourseNotes: [WatchHoleNote] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "allCourseNotes"),
                  let notes = try? JSONDecoder().decode([WatchHoleNote].self, from: data) else {
                return []
            }
            return notes
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "allCourseNotes")
            }
            // Also update hole-specific caches
            for hole in 1...18 {
                let holeNotes = newValue.filter { $0.holeNumber == hole }
                if let data = try? JSONEncoder().encode(holeNotes) {
                    UserDefaults.standard.set(data, forKey: "holeNotes_\(hole)")
                }
            }
        }
    }
    
    /// Handle course notes message from iPhone
    func handleCourseNotes(_ message: [String: Any]) {
        guard let notesData = message["notes"] as? [[String: Any]] else { return }
        
        let notes: [WatchHoleNote] = notesData.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let holeNumber = dict["holeNumber"] as? Int,
                  let content = dict["content"] as? String,
                  let category = dict["category"] as? String else {
                return nil
            }
            return WatchHoleNote(
                id: id,
                holeNumber: holeNumber,
                content: content,
                category: category,
                isPersonal: dict["isPersonal"] as? Bool ?? true
            )
        }
        
        DispatchQueue.main.async {
            self.allCourseNotes = notes
        }
    }
}

#Preview {
    HoleNotesWatchView()
}
