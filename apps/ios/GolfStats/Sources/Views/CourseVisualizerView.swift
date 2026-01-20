import SwiftUI
import MapKit

struct CourseVisualizerView: View {
    let holeData: [HoleData]
    let initialHole: Int
    let showSatellite: Bool
    
    @State private var selectedHole: Int
    @State private var cameraPosition: MapCameraPosition
    @State private var showLayers = LayerVisibility()
    
    init(holeData: [HoleData], initialHole: Int = 1, showSatellite: Bool = false) {
        self.holeData = holeData
        self.initialHole = initialHole
        self.showSatellite = showSatellite
        _selectedHole = State(initialValue: initialHole)
        
        // Calculate initial camera position from first hole
        if let firstHole = holeData.first(where: { $0.holeNumber == initialHole }) {
            if let greenCenter = firstHole.greenCenter {
                _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: greenCenter.lat, longitude: greenCenter.lon),
                    span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
                )))
            } else if let firstTee = firstHole.teeLocations?.first {
                _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                    center: firstTee.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
                )))
            } else {
                _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
                    span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
                )))
            }
        } else {
            _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
                span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
            )))
        }
    }
    
    var currentHole: HoleData? {
        holeData.first(where: { $0.holeNumber == selectedHole })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Hole Selector and Layer Toggles
            VStack(spacing: 8) {
                HStack {
                    Picker("Hole", selection: $selectedHole) {
                        ForEach(holeData, id: \.holeNumber) { hole in
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
                    HStack(spacing: 8) {
                        LayerToggleButton(
                            icon: "eye.fill",
                            isOn: $showLayers.fairway,
                            color: .green
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
                    }
                }
            }
            .padding()
            .background(Color("BackgroundSecondary"))
            
            // Map
            Map(position: $cameraPosition) {
                // Overlays (polygons)
                overlayContent
                
                // Annotations (markers)
                ForEach(annotations) { item in
                    Annotation("", coordinate: item.coordinate) {
                        item.annotationView()
                    }
                }
            }
            .mapStyle(showSatellite ? .imagery : .standard)
            .frame(height: 400)
            .cornerRadius(0)
            .overlay(
                Rectangle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            
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
            // Fairway polygon
            if showLayers.fairway, let fairway = hole.fairway, fairway.count >= 3 {
                let coordinates = fairway.map { $0.clLocation } + [fairway[0].clLocation]
                MapPolygon(coordinates: coordinates)
                    .foregroundStyle(.green.opacity(0.3))
                    .stroke(.green, lineWidth: 2)
            }
            
            // Green polygon
            if showLayers.green, let green = hole.green, green.count >= 3 {
                let coordinates = green.map { $0.clLocation } + [green[0].clLocation]
                MapPolygon(coordinates: coordinates)
                    .foregroundStyle(.green.opacity(0.5))
                    .stroke(.green, lineWidth: 2)
            }
            
            // Rough polygon
            if showLayers.rough, let rough = hole.rough, rough.count >= 3 {
                let coordinates = rough.map { $0.clLocation } + [rough[0].clLocation]
                MapPolygon(coordinates: coordinates)
                    .foregroundStyle(Color(red: 0.52, green: 0.80, blue: 0.09).opacity(0.2))
                    .stroke(Color(red: 0.52, green: 0.80, blue: 0.09), lineWidth: 1)
            }
            
            // Bunkers
            if showLayers.bunkers, let bunkers = hole.bunkers {
                ForEach(Array(bunkers.enumerated()), id: \.offset) { index, bunker in
                    if bunker.polygon.count >= 3 {
                        let coordinates = bunker.polygon.map { $0.clLocation } + [bunker.polygon[0].clLocation]
                        MapPolygon(coordinates: coordinates)
                            .foregroundStyle(.yellow.opacity(0.4))
                            .stroke(.yellow, lineWidth: 2)
                    }
                }
            }
            
            // Water hazards
            if showLayers.water, let water = hole.waterHazards {
                ForEach(Array(water.enumerated()), id: \.offset) { index, hazard in
                    if hazard.polygon.count >= 3 {
                        let coordinates = hazard.polygon.map { $0.clLocation } + [hazard.polygon[0].clLocation]
                        MapPolygon(coordinates: coordinates)
                            .foregroundStyle(.blue.opacity(0.5))
                            .stroke(.blue, lineWidth: 2)
                    }
                }
            }
            
            // Trees
            if showLayers.trees, let trees = hole.trees {
                ForEach(Array(trees.enumerated()), id: \.offset) { index, tree in
                    if tree.polygon.count >= 3 {
                        let coordinates = tree.polygon.map { $0.clLocation } + [tree.polygon[0].clLocation]
                        MapPolygon(coordinates: coordinates)
                            .foregroundStyle(Color(red: 0.09, green: 0.64, blue: 0.29).opacity(0.3))
                            .stroke(Color(red: 0.09, green: 0.64, blue: 0.29), lineWidth: 1)
                    }
                }
            }
        }
    }
    
    private func updateRegionForHole(_ holeNumber: Int) {
        guard let hole = holeData.first(where: { $0.holeNumber == holeNumber }) else { return }
        
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

// MARK: - Supporting Types

struct LayerVisibility {
    var fairway: Bool = true
    var green: Bool = true
    var rough: Bool = true
    var bunkers: Bool = true
    var water: Bool = true
    var trees: Bool = false
    var yardageMarkers: Bool = true
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
