import SwiftUI
import MapKit

struct CourseVisualizerView: View {
    let holeData: [HoleData]
    let initialHole: Int
    let showSatellite: Bool
    let fallbackCoordinate: CLLocationCoordinate2D?  // Course's main lat/lon as fallback
    let courseName: String?
    
    @State private var selectedHole: Int
    @State private var cameraPosition: MapCameraPosition
    @State private var showLayers = LayerVisibility()
    
    init(holeData: [HoleData], initialHole: Int = 1, showSatellite: Bool = false, fallbackCoordinate: CLLocationCoordinate2D? = nil, courseName: String? = nil) {
        self.holeData = holeData
        self.initialHole = initialHole
        self.showSatellite = showSatellite
        self.fallbackCoordinate = fallbackCoordinate
        self.courseName = courseName
        _selectedHole = State(initialValue: initialHole)
        
        // Calculate initial camera position - try hole data first, then fallback to course coordinates
        let initialPosition = Self.findBestInitialPosition(holeData: holeData, preferredHole: initialHole, fallback: fallbackCoordinate)
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: initialPosition.center,
            span: MKCoordinateSpan(latitudeDelta: initialPosition.span, longitudeDelta: initialPosition.span)
        )))
    }
    
    /// Find the best initial camera position from available hole data or fallback
    private static func findBestInitialPosition(holeData: [HoleData], preferredHole: Int, fallback: CLLocationCoordinate2D?) -> (center: CLLocationCoordinate2D, span: Double) {
        // Try the preferred hole first
        if let hole = holeData.first(where: { $0.holeNumber == preferredHole }),
           let coords = extractCoordinates(from: hole) {
            return (coords, 0.003)
        }
        
        // Try any hole with a green center
        for hole in holeData.sorted(by: { $0.holeNumber < $1.holeNumber }) {
            if let greenCenter = hole.greenCenter {
                return (CLLocationCoordinate2D(latitude: greenCenter.lat, longitude: greenCenter.lon), 0.003)
            }
        }
        
        // Try any hole with tee locations
        for hole in holeData.sorted(by: { $0.holeNumber < $1.holeNumber }) {
            if let tee = hole.teeLocations?.first {
                return (tee.coordinate, 0.003)
            }
        }
        
        // Try any hole with a green polygon
        for hole in holeData.sorted(by: { $0.holeNumber < $1.holeNumber }) {
            if let green = hole.green, let first = green.first {
                return (CLLocationCoordinate2D(latitude: first.lat, longitude: first.lon), 0.003)
            }
        }
        
        // Try any hole with a fairway polygon
        for hole in holeData.sorted(by: { $0.holeNumber < $1.holeNumber }) {
            if let fairway = hole.fairway, let first = fairway.first {
                return (CLLocationCoordinate2D(latitude: first.lat, longitude: first.lon), 0.003)
            }
        }
        
        // Use fallback course coordinates if available (zoom out more to show whole course)
        if let fallback = fallback {
            return (fallback, 0.008)  // Wider span to show more of the course area
        }
        
        // No valid coordinates found
        return (CLLocationCoordinate2D(latitude: 0, longitude: 0), 0.003)
    }
    
    /// Extract coordinates from a hole (green center preferred, then tees, then polygon)
    private static func extractCoordinates(from hole: HoleData) -> CLLocationCoordinate2D? {
        if let greenCenter = hole.greenCenter {
            return CLLocationCoordinate2D(latitude: greenCenter.lat, longitude: greenCenter.lon)
        }
        if let tee = hole.teeLocations?.first {
            return tee.coordinate
        }
        if let green = hole.green, let first = green.first {
            return CLLocationCoordinate2D(latitude: first.lat, longitude: first.lon)
        }
        if let fairway = hole.fairway, let first = fairway.first {
            return CLLocationCoordinate2D(latitude: first.lat, longitude: first.lon)
        }
        return nil
    }
    
    /// Check if hole data has any valid coordinates for polygon overlays
    var hasValidCoordinates: Bool {
        for hole in holeData {
            if hole.greenCenter != nil { return true }
            if hole.teeLocations?.isEmpty == false { return true }
            if hole.green?.isEmpty == false { return true }
            if hole.fairway?.isEmpty == false { return true }
            if hole.bunkers?.isEmpty == false { return true }
            if hole.waterHazards?.isEmpty == false { return true }
        }
        return false
    }
    
    /// Check if we have any location to show (either hole data or fallback)
    var hasAnyLocation: Bool {
        hasValidCoordinates || fallbackCoordinate != nil
    }
    
    /// Map content builder - separate to avoid conditional issues in MapContentBuilder
    @MapContentBuilder
    var mapContent: some MapContent {
        if hasValidCoordinates {
            // Show hole overlays and annotations
            overlayContent
            
            ForEach(annotations) { item in
                Annotation("", coordinate: item.coordinate) {
                    item.annotationView()
                }
            }
        } else if let fallback = fallbackCoordinate {
            // Show course center marker only
            Annotation(courseName ?? "Course", coordinate: fallback) {
                VStack(spacing: 4) {
                    Image(systemName: "flag.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    Text(courseName ?? "Course")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                }
            }
        } else {
            // Fallback: invisible marker at 0,0 - this should never happen but prevents crash
            // (hasAnyLocation check should prevent us from getting here)
            MapCircle(center: CLLocationCoordinate2D(latitude: 0, longitude: 0), radius: 0)
                .foregroundStyle(.clear)
        }
    }
    
    var currentHole: HoleData? {
        holeData.first(where: { $0.holeNumber == selectedHole })
    }
    
    /// Course-wide bunkers from hole 0 (shown on every hole)
    var courseWideBunkers: [Bunker] {
        holeData.first(where: { $0.holeNumber == 0 })?.bunkers ?? []
    }
    
    /// Course-wide water hazards from hole 0 (shown on every hole)
    var courseWideWater: [WaterHazard] {
        holeData.first(where: { $0.holeNumber == 0 })?.waterHazards ?? []
    }
    
    /// All greens from all holes (for showing course-wide view)
    var allGreens: [(holeNumber: Int, polygon: [Coordinate], center: Coordinate?)] {
        holeData
            .filter { $0.holeNumber > 0 && $0.green != nil }
            .compactMap { hole in
                guard let green = hole.green else { return nil }
                return (holeNumber: hole.holeNumber, polygon: green, center: hole.greenCenter)
            }
    }
    
    /// All fairways from all holes (for showing course-wide view)
    var allFairways: [(holeNumber: Int, polygon: [Coordinate])] {
        holeData
            .filter { $0.holeNumber > 0 && $0.fairway != nil }
            .compactMap { hole in
                guard let fairway = hole.fairway else { return nil }
                return (holeNumber: hole.holeNumber, polygon: fairway)
            }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Hole Selector and Layer Toggles - only show when we have hole data
            if hasValidCoordinates && !holeData.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Picker("Hole", selection: $selectedHole) {
                            // Filter out hole 0 (course-wide hazards container)
                            ForEach(holeData.filter { $0.holeNumber > 0 }, id: \.holeNumber) { hole in
                                Text("Hole \(hole.holeNumber) - Par \(hole.par)")
                                    .tag(hole.holeNumber)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.white)
                        .onChange(of: selectedHole) { oldValue, newHole in
                            updateRegionForHole(newHole)
                        }
                        
                        Spacer()
                        
                        // Layer Toggles
                        HStack(spacing: 6) {
                            // "This Hole Only" toggle - filters greens/fairways to current hole
                            LayerToggleButton(
                                icon: "1.circle.fill",
                                isOn: $showLayers.thisHoleOnly,
                                color: .orange
                            )
                            
                            LayerToggleButton(
                                icon: "flag.fill",
                                isOn: $showLayers.green,
                                color: .green
                            )
                            LayerToggleButton(
                                icon: "square.fill",
                                isOn: $showLayers.bunkers,
                                color: .yellow
                            )
                            LayerToggleButton(
                                icon: "drop.fill",
                                isOn: $showLayers.water,
                                color: .blue
                            )
                        }
                    }
                }
                .padding()
                .background(Color("BackgroundSecondary"))
            }
            
            // Map view - always show if we have any location (hole data or course coordinates)
            if hasAnyLocation {
                ZStack(alignment: .top) {
                    Map(position: $cameraPosition) {
                        // Use computed map content to avoid conditional issues
                        mapContent
                    }
                    .mapStyle(showSatellite ? .imagery : .standard)
                    .frame(height: 400)
                    .cornerRadius(0)
                    .overlay(
                        Rectangle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    
                    // Banner when showing fallback location without hole overlays
                    if !hasValidCoordinates && fallbackCoordinate != nil {
                        Text("Satellite view - hole overlays not yet available")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                            .padding(.top, 8)
                    }
                }
            } else {
                // No location at all - show informative message
                VStack(spacing: 16) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("Location Not Available")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("This course is missing location coordinates.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(height: 400)
                .frame(maxWidth: .infinity)
                .background(Color("BackgroundSecondary"))
            }
            
            // Hole Info
            if let hole = currentHole {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Hole \(hole.holeNumber)")
                            .font(.headline)
                        Spacer()
                        Text("Par \(hole.par)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .foregroundColor(.white)
                    
                    if let yardages = hole.yardages, !yardages.isEmpty {
                        HStack(spacing: 12) {
                            ForEach(yardages.keys.sorted(), id: \.self) { tee in
                                if let dist = yardages[tee] {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(teeColorToColor(tee))
                                            .frame(width: 8, height: 8)
                                        Text("\(dist)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    }
                    
                    if let yardageMarkers = hole.yardageMarkers, !yardageMarkers.isEmpty {
                        Text("Markers: \(yardageMarkers.map { "\($0.distance)" }.joined(separator: ", ")) yards")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color("BackgroundSecondary"))
            }
        }
        .background(Color("Background"))
    }
    
    private var annotations: [MapAnnotationItem] {
        guard let hole = currentHole else { return [] }
        var items: [MapAnnotationItem] = []
        
        // Tee locations
        if let tees = hole.teeLocations {
            for tee in tees {
                items.append(MapAnnotationItem(
                    coordinate: tee.coordinate,
                    annotationView: { AnyView(TeeMarker(teeColor: tee.tee)) }
                ))
            }
        }
        
        // Green center
        if let greenCenter = hole.greenCenter {
            items.append(MapAnnotationItem(
                coordinate: greenCenter.clLocation,
                annotationView: { AnyView(GreenMarker()) }
            ))
        }
        
        // Yardage markers
        if showLayers.yardageMarkers, let markers = hole.yardageMarkers {
            for marker in markers {
                items.append(MapAnnotationItem(
                    coordinate: marker.coordinate,
                    annotationView: { AnyView(YardageMarkerView(distance: marker.distance)) }
                ))
            }
        }
        
        return items
    }
    
    @MapContentBuilder
    private var overlayContent: some MapContent {
        if let hole = currentHole {
            // Fairway polygons - show all or just current hole
            if showLayers.fairway {
                if showLayers.thisHoleOnly {
                    // Only current hole's fairway
                    if let fairway = hole.fairway, fairway.count >= 3 {
                        let coordinates = fairway.map { $0.clLocation }
                        MapPolygon(coordinates: coordinates + [coordinates[0]])
                            .foregroundStyle(.green.opacity(0.3))
                            .stroke(.green, lineWidth: 2)
                    }
                } else {
                    // ALL fairways from all holes
                    ForEach(Array(allFairways.enumerated()), id: \.offset) { index, fairwayData in
                        if fairwayData.polygon.count >= 3 {
                            let coordinates = fairwayData.polygon.map { $0.clLocation }
                            let isCurrentHole = fairwayData.holeNumber == selectedHole
                            MapPolygon(coordinates: coordinates + [coordinates[0]])
                                .foregroundStyle(.green.opacity(isCurrentHole ? 0.4 : 0.2))
                                .stroke(.green, lineWidth: isCurrentHole ? 2 : 1)
                        }
                    }
                }
            }
            
            // Green polygons - show all or just current hole
            if showLayers.green {
                if showLayers.thisHoleOnly {
                    // Only current hole's green
                    if let green = hole.green, green.count >= 3 {
                        let coordinates = green.map { $0.clLocation }
                        MapPolygon(coordinates: coordinates + [coordinates[0]])
                            .foregroundStyle(.green.opacity(0.5))
                            .stroke(.green, lineWidth: 2)
                    }
                } else {
                    // ALL greens from all holes
                    ForEach(Array(allGreens.enumerated()), id: \.offset) { index, greenData in
                        if greenData.polygon.count >= 3 {
                            let coordinates = greenData.polygon.map { $0.clLocation }
                            let isCurrentHole = greenData.holeNumber == selectedHole
                            MapPolygon(coordinates: coordinates + [coordinates[0]])
                                .foregroundStyle(.green.opacity(isCurrentHole ? 0.6 : 0.3))
                                .stroke(isCurrentHole ? .white : .green, lineWidth: isCurrentHole ? 3 : 1)
                        }
                    }
                }
            }
            
            // Rough polygon
            if showLayers.rough, let rough = hole.rough, rough.count >= 3 {
                let coordinates = rough.map { $0.clLocation }
                MapPolygon(coordinates: coordinates + [coordinates[0]])
                    .foregroundStyle(Color(red: 0.52, green: 0.80, blue: 0.09).opacity(0.2))
                    .stroke(Color(red: 0.52, green: 0.80, blue: 0.09), lineWidth: 1)
            }
            
            // Bunkers - show current hole's bunkers + course-wide bunkers (hole 0)
            if showLayers.bunkers {
                let allBunkers = (hole.bunkers ?? []) + courseWideBunkers
                ForEach(Array(allBunkers.enumerated()), id: \.offset) { index, bunker in
                    if bunker.polygon.count >= 3 {
                        let coordinates = bunker.polygon.map { $0.clLocation }
                        MapPolygon(coordinates: coordinates + [coordinates[0]])
                            .foregroundStyle(.yellow.opacity(0.4))
                            .stroke(.yellow, lineWidth: 2)
                    }
                }
            }
            
            // Water hazards - show current hole's water + course-wide water (hole 0)
            if showLayers.water {
                let allWater = (hole.waterHazards ?? []) + courseWideWater
                ForEach(Array(allWater.enumerated()), id: \.offset) { index, hazard in
                    if hazard.polygon.count >= 3 {
                        let coordinates = hazard.polygon.map { $0.clLocation }
                        MapPolygon(coordinates: coordinates + [coordinates[0]])
                            .foregroundStyle(.blue.opacity(0.5))
                            .stroke(.blue, lineWidth: 2)
                    }
                }
            }
            
            // Trees
            if showLayers.trees, let trees = hole.trees {
                ForEach(Array(trees.enumerated()), id: \.offset) { index, tree in
                    if tree.polygon.count >= 3 {
                        let coordinates = tree.polygon.map { $0.clLocation }
                        MapPolygon(coordinates: coordinates + [coordinates[0]])
                            .foregroundStyle(Color(red: 0.09, green: 0.64, blue: 0.29).opacity(0.3))
                            .stroke(Color(red: 0.09, green: 0.64, blue: 0.29), lineWidth: 1)
                    }
                }
            }
        }
    }
    
    private func updateRegionForHole(_ holeNumber: Int) {
        guard let hole = holeData.first(where: { $0.holeNumber == holeNumber }) else { return }
        
        // Try to get coordinates from the hole in order of preference
        if let greenCenter = hole.greenCenter {
            cameraPosition = .region(MKCoordinateRegion(
                center: greenCenter.clLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
            ))
        } else if let firstTee = hole.teeLocations?.first {
            cameraPosition = .region(MKCoordinateRegion(
                center: firstTee.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
            ))
        } else if let green = hole.green, let first = green.first {
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: first.lat, longitude: first.lon),
                span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
            ))
        } else if let fairway = hole.fairway, let first = fairway.first {
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: first.lat, longitude: first.lon),
                span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
            ))
        }
        // If no coordinates found for this hole, keep the current camera position
    }

    private func teeColorToColor(_ tee: String) -> Color {
        switch tee.lowercased() {
        case "black": return .black
        case "blue": return .blue
        case "white": return .white
        case "gold": return .yellow
        case "red": return .red
        default: return .blue
        }
    }
}

// MARK: - Supporting Types

struct LayerVisibility {
    var fairway: Bool = true
    var green: Bool = true
    var rough: Bool = true
    var bunkers: Bool = true
    var water: Bool = true
    var trees: Bool = false
    var yardageMarkers: Bool = true
    var thisHoleOnly: Bool = false  // When true, only show current hole's green/fairway
}

struct LayerToggleButton: View {
    let icon: String
    @Binding var isOn: Bool
    let color: Color
    
    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Image(systemName: isOn ? icon : "eye.slash.fill")
                .foregroundColor(isOn ? color : .gray)
                .padding(8)
                .background(isOn ? color.opacity(0.2) : Color.gray.opacity(0.2))
                .cornerRadius(8)
        }
    }
}

// MARK: - Map Annotations

struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let annotationView: () -> AnyView
}


// MARK: - Annotation Views

struct TeeMarker: View {
    let teeColor: String
    
    var body: some View {
        let color = teeColorToColor(teeColor)
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
            Text("T")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private func teeColorToColor(_ tee: String) -> Color {
        switch tee.lowercased() {
        case "black": return .black
        case "blue": return .blue
        case "white": return .white
        case "gold": return .yellow
        case "red": return .red
        default: return .blue
        }
    }
}

struct GreenMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
            Text("G")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

struct YardageMarkerView: View {
    let distance: Int
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1)
                )
        }
    }
}


// MARK: - Preview

#Preview {
    let sampleHoleData = [
        HoleData(
            holeNumber: 1,
            par: 4,
            yardages: ["blue": 400],
            greenCenter: Coordinate(lat: 40.7130, lon: -74.0055),
            greenFront: nil,
            greenBack: nil,
            teeLocations: [
                TeeLocation(tee: "blue", lat: 40.7128, lon: -74.0060)
            ],
            fairway: [
                Coordinate(lat: 40.7128, lon: -74.0060),
                Coordinate(lat: 40.7130, lon: -74.0058),
                Coordinate(lat: 40.7132, lon: -74.0056),
                Coordinate(lat: 40.7130, lon: -74.0054)
            ],
            green: [
                Coordinate(lat: 40.7129, lon: -74.0056),
                Coordinate(lat: 40.7131, lon: -74.0055),
                Coordinate(lat: 40.7131, lon: -74.0054),
                Coordinate(lat: 40.7129, lon: -74.0055)
            ],
            rough: nil,
            bunkers: [
                Bunker(
                    type: "bunker",
                    polygon: [
                        Coordinate(lat: 40.7129, lon: -74.0057),
                        Coordinate(lat: 40.7130, lon: -74.0057),
                        Coordinate(lat: 40.7130, lon: -74.0056),
                        Coordinate(lat: 40.7129, lon: -74.0056)
                    ],
                    center: nil
                )
            ],
            waterHazards: nil,
            trees: nil,
            yardageMarkers: [
                YardageMarker(distance: 150, lat: 40.7129, lon: -74.0057)
            ]
        )
    ]
    
    return CourseVisualizerView(holeData: sampleHoleData, initialHole: 1)
        .padding()
        .background(Color("Background"))
}
