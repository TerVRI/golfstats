import Foundation
import UniformTypeIdentifiers
import SwiftUI

/// Manages importing round data from external sources (Garmin, Arccos, CSV, etc.)
class DataImportManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = DataImportManager()
    
    // MARK: - Published State
    
    @Published var isImporting = false
    @Published var importProgress: Double = 0
    @Published var lastImportResult: ImportResult?
    
    // MARK: - Supported Formats
    
    static let supportedTypes: [UTType] = [
        .json,
        .commaSeparatedText,
        UTType(filenameExtension: "fit") ?? .data,
        UTType(filenameExtension: "tcx") ?? .data
    ]
    
    // MARK: - Import Methods
    
    /// Import from a file URL
    func importFile(at url: URL) async throws -> ImportResult {
        isImporting = true
        importProgress = 0
        
        defer {
            isImporting = false
        }
        
        // Determine file type
        let fileExtension = url.pathExtension.lowercased()
        
        let result: ImportResult
        
        switch fileExtension {
        case "json":
            result = try await importJSON(from: url)
        case "csv":
            result = try await importCSV(from: url)
        case "fit":
            result = try await importFIT(from: url)
        case "tcx":
            result = try await importTCX(from: url)
        default:
            throw ImportError.unsupportedFormat
        }
        
        lastImportResult = result
        return result
    }
    
    /// Import from data directly
    func importData(_ data: Data, format: ImportFormat) async throws -> ImportResult {
        isImporting = true
        importProgress = 0
        
        defer {
            isImporting = false
        }
        
        let result: ImportResult
        
        switch format {
        case .garminJSON:
            result = try await parseGarminJSON(data)
        case .arccosExport:
            result = try await parseArccosExport(data)
        case .golfPadCSV:
            result = try await parseGolfPadCSV(data)
        case .genericCSV:
            result = try await parseGenericCSV(data)
        case .shotScopeJSON:
            result = try await parseShotScopeJSON(data)
        }
        
        lastImportResult = result
        return result
    }
    
    // MARK: - JSON Import
    
    private func importJSON(from url: URL) async throws -> ImportResult {
        let data = try Data(contentsOf: url)
        
        // Try to detect the format
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if json["activityType"] != nil || json["activityName"] != nil {
                return try await parseGarminJSON(data)
            } else if json["rounds"] != nil || json["smartCaddie"] != nil {
                return try await parseArccosExport(data)
            } else if json["shots"] != nil && json["course"] != nil {
                return try await parseShotScopeJSON(data)
            }
        }
        
        // Try generic round format
        return try await parseGenericJSON(data)
    }
    
    private func importCSV(from url: URL) async throws -> ImportResult {
        let data = try Data(contentsOf: url)
        return try await parseGenericCSV(data)
    }
    
    private func importFIT(from url: URL) async throws -> ImportResult {
        // FIT files are binary - would need FIT SDK for full support
        // For now, return a placeholder
        throw ImportError.fitParsingNotSupported
    }
    
    private func importTCX(from url: URL) async throws -> ImportResult {
        // TCX is XML-based
        let data = try Data(contentsOf: url)
        return try await parseTCX(data)
    }
    
    // MARK: - Format Parsers
    
    /// Parse Garmin Connect JSON export
    private func parseGarminJSON(_ data: Data) async throws -> ImportResult {
        importProgress = 0.1
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let garminData = try decoder.decode(GarminExport.self, from: data)
        
        importProgress = 0.5
        
        var importedRounds: [ImportedRound] = []
        
        for activity in garminData.activities where activity.activityType == "golf" {
            let round = ImportedRound(
                id: UUID(),
                source: .garmin,
                date: activity.startTime,
                courseName: activity.courseName ?? "Unknown Course",
                score: activity.totalScore ?? 0,
                holesPlayed: activity.holesPlayed ?? 18,
                holeScores: parseGarminHoleScores(activity.holes),
                shots: [],
                stats: ImportedStats(
                    fairwaysHit: activity.fairwaysHit,
                    fairwaysTotal: activity.fairwaysTotal,
                    greensInReg: activity.greensInReg,
                    greensTotal: activity.greensTotal,
                    totalPutts: activity.totalPutts,
                    penalties: activity.penalties
                ),
                rawData: nil
            )
            importedRounds.append(round)
        }
        
        importProgress = 1.0
        
        return ImportResult(
            success: true,
            source: .garmin,
            roundsImported: importedRounds.count,
            rounds: importedRounds,
            errors: []
        )
    }
    
    private func parseGarminHoleScores(_ holes: [GarminHole]?) -> [ImportedHoleScore] {
        guard let holes = holes else { return [] }
        
        return holes.map { hole in
            ImportedHoleScore(
                holeNumber: hole.holeNumber,
                par: hole.par,
                strokes: hole.strokes,
                putts: hole.putts,
                fairwayHit: hole.fairwayHit,
                greenInReg: hole.greenInReg,
                penalties: hole.penalties
            )
        }
    }
    
    /// Parse Arccos Golf export
    private func parseArccosExport(_ data: Data) async throws -> ImportResult {
        importProgress = 0.1
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let arccosData = try decoder.decode(ArccosExport.self, from: data)
        
        importProgress = 0.5
        
        var importedRounds: [ImportedRound] = []
        
        for round in arccosData.rounds {
            let importedRound = ImportedRound(
                id: UUID(),
                source: .arccos,
                date: round.date,
                courseName: round.courseName,
                score: round.totalScore,
                holesPlayed: round.holesPlayed,
                holeScores: round.holes.map { hole in
                    ImportedHoleScore(
                        holeNumber: hole.holeNumber,
                        par: hole.par,
                        strokes: hole.strokes,
                        putts: hole.putts,
                        fairwayHit: hole.fairwayHit,
                        greenInReg: hole.gir,
                        penalties: hole.penalties
                    )
                },
                shots: round.shots?.map { shot in
                    ImportedShot(
                        club: shot.club,
                        distance: shot.distance,
                        latitude: shot.lat,
                        longitude: shot.lon,
                        timestamp: shot.timestamp
                    )
                } ?? [],
                stats: ImportedStats(
                    strokesGained: round.strokesGained,
                    sgDriving: round.sgDriving,
                    sgApproach: round.sgApproach,
                    sgShortGame: round.sgShortGame,
                    sgPutting: round.sgPutting
                ),
                rawData: nil
            )
            importedRounds.append(importedRound)
        }
        
        importProgress = 1.0
        
        return ImportResult(
            success: true,
            source: .arccos,
            roundsImported: importedRounds.count,
            rounds: importedRounds,
            errors: []
        )
    }
    
    /// Parse Golf Pad CSV export
    private func parseGolfPadCSV(_ data: Data) async throws -> ImportResult {
        return try await parseGenericCSV(data, source: .golfPad)
    }
    
    /// Parse generic CSV (most flexible)
    private func parseGenericCSV(_ data: Data, source: ImportSource = .csv) async throws -> ImportResult {
        importProgress = 0.1
        
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidEncoding
        }
        
        let lines = csvString.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        guard lines.count > 1 else {
            throw ImportError.emptyFile
        }
        
        // Parse header
        let header = parseCSVLine(lines[0])
        let columnMap = createColumnMap(from: header)
        
        importProgress = 0.3
        
        var importedRounds: [ImportedRound] = []
        var currentRound: ImportedRound?
        var holeScores: [ImportedHoleScore] = []
        let errors: [String] = []
        
        for (index, line) in lines.dropFirst().enumerated() {
            let values = parseCSVLine(line)
            
            importProgress = 0.3 + 0.6 * Double(index) / Double(lines.count - 1)
            
            // Check if this is a new round
            if let dateCol = columnMap["date"],
               dateCol < values.count,
               let date = parseDate(values[dateCol]) {
                
                // Save previous round
                if var round = currentRound {
                    round.holeScores = holeScores
                    round.score = holeScores.reduce(0) { $0 + $1.strokes }
                    importedRounds.append(round)
                }
                
                // Start new round
                let courseName = columnMap["course"].flatMap { $0 < values.count ? values[$0] : nil } ?? "Unknown Course"
                
                currentRound = ImportedRound(
                    id: UUID(),
                    source: source,
                    date: date,
                    courseName: courseName,
                    score: 0,
                    holesPlayed: 18,
                    holeScores: [],
                    shots: [],
                    stats: nil,
                    rawData: nil
                )
                holeScores = []
            }
            
            // Parse hole data
            if let holeCol = columnMap["hole"],
               holeCol < values.count,
               let holeNumber = Int(values[holeCol]) {
                
                let par = columnMap["par"].flatMap { $0 < values.count ? Int(values[$0]) : nil } ?? 4
                let strokes = columnMap["strokes"].flatMap { $0 < values.count ? Int(values[$0]) : nil } ?? 0
                let putts = columnMap["putts"].flatMap { $0 < values.count ? Int(values[$0]) : nil }
                
                let fairwayHit: Bool? = columnMap["fairway"].flatMap { col -> Bool? in
                    guard col < values.count else { return nil }
                    let val = values[col].lowercased()
                    return val == "1" || val == "yes" || val == "true" || val == "hit"
                }
                
                let gir: Bool? = columnMap["gir"].flatMap { col -> Bool? in
                    guard col < values.count else { return nil }
                    let val = values[col].lowercased()
                    return val == "1" || val == "yes" || val == "true"
                }
                
                holeScores.append(ImportedHoleScore(
                    holeNumber: holeNumber,
                    par: par,
                    strokes: strokes,
                    putts: putts,
                    fairwayHit: fairwayHit,
                    greenInReg: gir,
                    penalties: nil
                ))
            }
        }
        
        // Save last round
        if var round = currentRound {
            round.holeScores = holeScores
            round.score = holeScores.reduce(0) { $0 + $1.strokes }
            importedRounds.append(round)
        }
        
        importProgress = 1.0
        
        return ImportResult(
            success: importedRounds.count > 0,
            source: source,
            roundsImported: importedRounds.count,
            rounds: importedRounds,
            errors: errors
        )
    }
    
    /// Parse Shot Scope JSON
    private func parseShotScopeJSON(_ data: Data) async throws -> ImportResult {
        importProgress = 0.1
        
        let decoder = JSONDecoder()
        let shotScopeData = try decoder.decode(ShotScopeExport.self, from: data)
        
        importProgress = 0.5
        
        let round = ImportedRound(
            id: UUID(),
            source: .shotScope,
            date: shotScopeData.date,
            courseName: shotScopeData.course.name,
            score: shotScopeData.totalScore,
            holesPlayed: shotScopeData.holes.count,
            holeScores: shotScopeData.holes.map { hole in
                ImportedHoleScore(
                    holeNumber: hole.number,
                    par: hole.par,
                    strokes: hole.strokes,
                    putts: hole.putts,
                    fairwayHit: hole.fairwayHit,
                    greenInReg: hole.greenInReg,
                    penalties: nil
                )
            },
            shots: shotScopeData.shots.map { shot in
                ImportedShot(
                    club: shot.club,
                    distance: shot.distance,
                    latitude: shot.lat,
                    longitude: shot.lng,
                    timestamp: nil
                )
            },
            stats: nil,
            rawData: nil
        )
        
        importProgress = 1.0
        
        return ImportResult(
            success: true,
            source: .shotScope,
            roundsImported: 1,
            rounds: [round],
            errors: []
        )
    }
    
    /// Parse generic JSON
    private func parseGenericJSON(_ data: Data) async throws -> ImportResult {
        // Attempt to parse as a simple round format
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let rounds = try decoder.decode([GenericRound].self, from: data)
            
            let importedRounds = rounds.map { round in
                ImportedRound(
                    id: UUID(),
                    source: .other,
                    date: round.date,
                    courseName: round.courseName,
                    score: round.score,
                    holesPlayed: round.holesPlayed ?? 18,
                    holeScores: round.holes?.map { hole in
                        ImportedHoleScore(
                            holeNumber: hole.holeNumber,
                            par: hole.par,
                            strokes: hole.strokes,
                            putts: hole.putts,
                            fairwayHit: hole.fairwayHit,
                            greenInReg: hole.greenInReg,
                            penalties: nil
                        )
                    } ?? [],
                    shots: [],
                    stats: nil,
                    rawData: nil
                )
            }
            
            return ImportResult(
                success: true,
                source: .other,
                roundsImported: importedRounds.count,
                rounds: importedRounds,
                errors: []
            )
        } catch {
            throw ImportError.parseError(error.localizedDescription)
        }
    }
    
    /// Parse TCX (Training Center XML)
    private func parseTCX(_ data: Data) async throws -> ImportResult {
        // TCX is primarily for fitness activities, limited golf support
        // This is a basic implementation
        throw ImportError.tcxGolfNotSupported
    }
    
    // MARK: - CSV Helpers
    
    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current.trimmingCharacters(in: .whitespaces))
        
        return result
    }
    
    private func createColumnMap(from header: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        
        for (index, col) in header.enumerated() {
            let normalized = col.lowercased()
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: " ", with: "_")
            
            // Map common column names
            if normalized.contains("date") || normalized.contains("played") {
                map["date"] = index
            } else if normalized.contains("course") || normalized.contains("name") {
                map["course"] = index
            } else if normalized == "hole" || normalized == "hole_number" || normalized == "hole#" {
                map["hole"] = index
            } else if normalized == "par" {
                map["par"] = index
            } else if normalized.contains("score") || normalized.contains("strokes") || normalized == "gross" {
                map["strokes"] = index
            } else if normalized.contains("putt") {
                map["putts"] = index
            } else if normalized.contains("fairway") || normalized == "fir" {
                map["fairway"] = index
            } else if normalized.contains("green") || normalized == "gir" {
                map["gir"] = index
            }
        }
        
        return map
    }
    
    private func parseDate(_ string: String) -> Date? {
        let formatters: [DateFormatter] = [
            { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f }(),
            { let f = DateFormatter(); f.dateFormat = "MM/dd/yyyy"; return f }(),
            { let f = DateFormatter(); f.dateFormat = "dd/MM/yyyy"; return f }(),
            { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"; return f }(),
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        
        return nil
    }
}

// MARK: - Data Models

struct ImportResult {
    let success: Bool
    let source: ImportSource
    let roundsImported: Int
    let rounds: [ImportedRound]
    let errors: [String]
}

struct ImportedRound: Identifiable {
    let id: UUID
    let source: ImportSource
    let date: Date
    let courseName: String
    var score: Int
    let holesPlayed: Int
    var holeScores: [ImportedHoleScore]
    let shots: [ImportedShot]
    let stats: ImportedStats?
    let rawData: Data?
}

struct ImportedHoleScore {
    let holeNumber: Int
    let par: Int
    let strokes: Int
    let putts: Int?
    let fairwayHit: Bool?
    let greenInReg: Bool?
    let penalties: Int?
}

struct ImportedShot {
    let club: String?
    let distance: Double?
    let latitude: Double?
    let longitude: Double?
    let timestamp: Date?
}

struct ImportedStats {
    var fairwaysHit: Int?
    var fairwaysTotal: Int?
    var greensInReg: Int?
    var greensTotal: Int?
    var totalPutts: Int?
    var penalties: Int?
    var strokesGained: Double?
    var sgDriving: Double?
    var sgApproach: Double?
    var sgShortGame: Double?
    var sgPutting: Double?
    
    init(
        fairwaysHit: Int? = nil,
        fairwaysTotal: Int? = nil,
        greensInReg: Int? = nil,
        greensTotal: Int? = nil,
        totalPutts: Int? = nil,
        penalties: Int? = nil,
        strokesGained: Double? = nil,
        sgDriving: Double? = nil,
        sgApproach: Double? = nil,
        sgShortGame: Double? = nil,
        sgPutting: Double? = nil
    ) {
        self.fairwaysHit = fairwaysHit
        self.fairwaysTotal = fairwaysTotal
        self.greensInReg = greensInReg
        self.greensTotal = greensTotal
        self.totalPutts = totalPutts
        self.penalties = penalties
        self.strokesGained = strokesGained
        self.sgDriving = sgDriving
        self.sgApproach = sgApproach
        self.sgShortGame = sgShortGame
        self.sgPutting = sgPutting
    }
}

enum ImportSource: String {
    case garmin = "Garmin"
    case arccos = "Arccos"
    case shotScope = "Shot Scope"
    case golfPad = "Golf Pad"
    case csv = "CSV"
    case other = "Other"
}

enum ImportFormat {
    case garminJSON
    case arccosExport
    case golfPadCSV
    case genericCSV
    case shotScopeJSON
}

enum ImportError: LocalizedError {
    case unsupportedFormat
    case invalidEncoding
    case emptyFile
    case parseError(String)
    case fitParsingNotSupported
    case tcxGolfNotSupported
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported file format"
        case .invalidEncoding:
            return "Could not read file - invalid encoding"
        case .emptyFile:
            return "File is empty or has no data"
        case .parseError(let message):
            return "Parse error: \(message)"
        case .fitParsingNotSupported:
            return "FIT file parsing not yet supported"
        case .tcxGolfNotSupported:
            return "TCX files don't have good golf support"
        }
    }
}

// MARK: - External Format Structures

struct GarminExport: Codable {
    let activities: [GarminActivity]
}

struct GarminActivity: Codable {
    let activityType: String
    let startTime: Date
    let courseName: String?
    let totalScore: Int?
    let holesPlayed: Int?
    let fairwaysHit: Int?
    let fairwaysTotal: Int?
    let greensInReg: Int?
    let greensTotal: Int?
    let totalPutts: Int?
    let penalties: Int?
    let holes: [GarminHole]?
}

struct GarminHole: Codable {
    let holeNumber: Int
    let par: Int
    let strokes: Int
    let putts: Int?
    let fairwayHit: Bool?
    let greenInReg: Bool?
    let penalties: Int?
}

struct ArccosExport: Codable {
    let rounds: [ArccosRound]
}

struct ArccosRound: Codable {
    let date: Date
    let courseName: String
    let totalScore: Int
    let holesPlayed: Int
    let holes: [ArccosHole]
    let shots: [ArccosShot]?
    let strokesGained: Double?
    let sgDriving: Double?
    let sgApproach: Double?
    let sgShortGame: Double?
    let sgPutting: Double?
}

struct ArccosHole: Codable {
    let holeNumber: Int
    let par: Int
    let strokes: Int
    let putts: Int?
    let fairwayHit: Bool?
    let gir: Bool?
    let penalties: Int?
}

struct ArccosShot: Codable {
    let club: String?
    let distance: Double?
    let lat: Double?
    let lon: Double?
    let timestamp: Date?
}

struct ShotScopeExport: Codable {
    let date: Date
    let course: ShotScopeCourse
    let totalScore: Int
    let holes: [ShotScopeHole]
    let shots: [ShotScopeShot]
}

struct ShotScopeCourse: Codable {
    let name: String
}

struct ShotScopeHole: Codable {
    let number: Int
    let par: Int
    let strokes: Int
    let putts: Int?
    let fairwayHit: Bool?
    let greenInReg: Bool?
}

struct ShotScopeShot: Codable {
    let club: String?
    let distance: Double?
    let lat: Double?
    let lng: Double?
}

struct GenericRound: Codable {
    let date: Date
    let courseName: String
    let score: Int
    let holesPlayed: Int?
    let holes: [GenericHole]?
}

struct GenericHole: Codable {
    let holeNumber: Int
    let par: Int
    let strokes: Int
    let putts: Int?
    let fairwayHit: Bool?
    let greenInReg: Bool?
}

// MARK: - SwiftUI Views

import SwiftUI

struct DataImportView: View {
    @ObservedObject var importManager = DataImportManager.shared
    @State private var showFilePicker = false
    @State private var importedRounds: [ImportedRound] = []
    @State private var selectedRounds: Set<UUID> = []
    @State private var showImportConfirmation = false
    
    var body: some View {
        List {
            Section {
                Button(action: { showFilePicker = true }) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Import from File")
                                .font(.headline)
                            Text("JSON, CSV, or export files")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("Supported Formats") {
                FormatRow(icon: "g.circle.fill", name: "Garmin Connect", description: "JSON export from Garmin")
                FormatRow(icon: "a.circle.fill", name: "Arccos Golf", description: "Full round export with shots")
                FormatRow(icon: "s.circle.fill", name: "Shot Scope", description: "JSON round data")
                FormatRow(icon: "tablecells", name: "CSV File", description: "Spreadsheet format")
            }
            
            if !importedRounds.isEmpty {
                Section("Imported Rounds") {
                    ForEach(importedRounds) { round in
                        ImportedRoundRow(
                            round: round,
                            isSelected: selectedRounds.contains(round.id),
                            onToggle: { toggleSelection(round.id) }
                        )
                    }
                }
                
                Section {
                    Button(action: { showImportConfirmation = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import \(selectedRounds.count) Round(s)")
                        }
                    }
                    .disabled(selectedRounds.isEmpty)
                }
            }
            
            Section {
                Text("Import your golf rounds from other apps. Scores, stats, and shot data will be preserved where available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Import Data")
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: DataImportManager.supportedTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .overlay {
            if importManager.isImporting {
                ImportProgressView(progress: importManager.importProgress)
            }
        }
        .alert("Import Rounds?", isPresented: $showImportConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Import") { finalizeImport() }
        } message: {
            Text("Import \(selectedRounds.count) round(s) to your RoundCaddy account?")
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            Task {
                do {
                    let result = try await importManager.importFile(at: url)
                    await MainActor.run {
                        importedRounds = result.rounds
                        selectedRounds = Set(result.rounds.map { $0.id })
                    }
                } catch {
                    print("Import error: \(error)")
                }
            }
            
        case .failure(let error):
            print("File selection error: \(error)")
        }
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedRounds.contains(id) {
            selectedRounds.remove(id)
        } else {
            selectedRounds.insert(id)
        }
    }
    
    private func finalizeImport() {
        let roundsToImport = importedRounds.filter { selectedRounds.contains($0.id) }
        // TODO: Save rounds to database
        print("Importing \(roundsToImport.count) rounds")
        
        importedRounds.removeAll()
        selectedRounds.removeAll()
    }
}

struct FormatRow: View {
    let icon: String
    let name: String
    let description: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(name)
                    .font(.subheadline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ImportedRoundRow: View {
    let round: ImportedRound
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .green : .secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(round.courseName)
                        .font(.headline)
                    
                    HStack {
                        Text(round.date, style: .date)
                        Text("•")
                        Text("Score: \(round.score)")
                        Text("•")
                        Text(round.source.rawValue)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

struct ImportProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 200)
                
                Text("Importing...")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
