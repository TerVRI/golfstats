import SwiftUI

/**
 * SVG-based schematic course visualizer for iOS/iPad
 * Similar to the web version, but using SwiftUI Canvas
 */
struct CourseSVGVisualizerView: View {
    let holeData: [HoleData]
    let initialHole: Int
    
    @State private var selectedHole: Int
    @State private var showLayers = LayerVisibility()
    @State private var viewMode: VisualizationMode = .hole
    @State private var zoom: CGFloat = 1.0
    
    enum VisualizationMode {
        case hole
        case overview
    }
    
    init(holeData: [HoleData], initialHole: Int = 1) {
        self.holeData = holeData
        self.initialHole = initialHole
        _selectedHole = State(initialValue: initialHole)
    }
    
    var currentHole: HoleData? {
        holeData.first(where: { $0.holeNumber == selectedHole })
    }
    
    var displayHoles: [HoleData] {
        viewMode == .overview ? holeData : (currentHole.map { [$0] } ?? [])
    }
    
    /// Check if hole data has any valid coordinates for visualization
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Controls - only show when we have valid coordinate data
            if hasValidCoordinates && !holeData.isEmpty {
                VStack(spacing: 12) {
                    // Mode toggle and hole selector
                    HStack {
                        if viewMode == .hole {
                            Picker("Hole", selection: $selectedHole) {
                                ForEach(holeData, id: \.holeNumber) { hole in
                                    Text("Hole \(hole.holeNumber) - Par \(hole.par)")
                                        .tag(hole.holeNumber)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        Spacer()
                        
                        // View mode toggle
                        Picker("View", selection: $viewMode) {
                            Text("Hole").tag(VisualizationMode.hole)
                            Text("Overview").tag(VisualizationMode.overview)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                    
                    // Layer toggles
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            LayerToggleButtonWithLabel(
                                icon: "eye.fill",
                                label: "Fairway",
                                isOn: $showLayers.fairway,
                                color: .green
                            )
                            LayerToggleButtonWithLabel(
                                icon: "flag.fill",
                                label: "Green",
                                isOn: $showLayers.green,
                                color: .green
                            )
                            LayerToggleButtonWithLabel(
                                icon: "square.fill",
                                label: "Bunkers",
                                isOn: $showLayers.bunkers,
                                color: .yellow
                            )
                            LayerToggleButtonWithLabel(
                                icon: "drop.fill",
                                label: "Water",
                                isOn: $showLayers.water,
                                color: .blue
                            )
                            LayerToggleButtonWithLabel(
                                icon: "location.fill",
                                label: "Tees",
                                isOn: Binding(
                                    get: { true },
                                    set: { _ in }
                                ),
                                color: .blue
                            )
                            LayerToggleButtonWithLabel(
                                icon: "mappin.circle.fill",
                                label: "Pin",
                                isOn: Binding(
                                    get: { true },
                                    set: { _ in }
                                ),
                                color: .red
                            )
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                .background(Color("BackgroundSecondary"))
            }
            
            // SVG Canvas or "No Coordinates" message
            if hasValidCoordinates {
                ZStack {
                    GeometryReader { geometry in
                        Canvas { context, size in
                            let bounds = calculateBounds()
                            let scale = min(size.width / max(bounds.width, 0.001), size.height / max(bounds.height, 0.001)) * 0.9
                            let offsetX = (size.width - bounds.width * scale) / 2
                            let offsetY = (size.height - bounds.height * scale) / 2
                            
                            // Background
                            context.fill(
                                Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 0),
                                with: .color(Color(red: 0.94, green: 0.98, blue: 0.96))
                            )
                            
                            // Draw each hole
                            for hole in displayHoles {
                                drawHole(hole, in: context, size: size, bounds: bounds, scale: scale, offsetX: offsetX, offsetY: offsetY)
                            }
                        }
                        .background(Color(red: 0.94, green: 0.98, blue: 0.96))
                    }
                    
                    // Hole number labels for overview mode (overlay)
                    if viewMode == .overview {
                        GeometryReader { geometry in
                            let bounds = calculateBounds()
                            let scale = min(geometry.size.width / max(bounds.width, 0.001), geometry.size.height / max(bounds.height, 0.001)) * 0.9
                            let offsetX = (geometry.size.width - bounds.width * scale) / 2
                            let offsetY = (geometry.size.height - bounds.height * scale) / 2
                            
                            ForEach(displayHoles, id: \.holeNumber) { hole in
                                if let greenCenter = hole.greenCenter {
                                    let point = gpsToPoint(
                                        lat: greenCenter.lat,
                                        lon: greenCenter.lon,
                                        bounds: bounds,
                                        size: geometry.size,
                                        scale: scale,
                                        offsetX: offsetX,
                                        offsetY: offsetY
                                    )
                                    
                                    Text("\(hole.holeNumber)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(4)
                                        .background(Color.white.opacity(0.8))
                                        .cornerRadius(4)
                                        .position(x: point.x, y: point.y - 30)
                                }
                            }
                        }
                    }
                }
                .frame(height: viewMode == .overview ? 600 : 400)
            } else {
                // No valid coordinates - show informative message
                VStack(spacing: 16) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("Schematic Data Incomplete")
                        .font(.headline)
                        .foregroundColor(.black)
                    
                    Text("This course has hole information but is missing geographic coordinates needed for the schematic view.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text("Hole data: \(holeData.filter { $0.holeNumber > 0 }.count) holes (par values available)")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(height: viewMode == .overview ? 600 : 400)
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.94, green: 0.98, blue: 0.96))
            }
            
            // Hole info
            if viewMode == .hole, let hole = currentHole {
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
                    
                    if let tees = hole.teeLocations, !tees.isEmpty {
                        Text("Available tees: \(tees.map { $0.tee.capitalized }.joined(separator: ", "))")
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
        .cornerRadius(12)
    }
    
    private func calculateBounds() -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double, width: Double, height: Double) {
        var minLat = Double.infinity
        var maxLat = -Double.infinity
        var minLon = Double.infinity
        var maxLon = -Double.infinity
        
        for hole in displayHoles {
            // Tees
            hole.teeLocations?.forEach { tee in
                minLat = min(minLat, tee.lat)
                maxLat = max(maxLat, tee.lat)
                minLon = min(minLon, tee.lon)
                maxLon = max(maxLon, tee.lon)
            }
            
            // Green center
            if let green = hole.greenCenter {
                minLat = min(minLat, green.lat)
                maxLat = max(maxLat, green.lat)
                minLon = min(minLon, green.lon)
                maxLon = max(maxLon, green.lon)
            }
            
            // Polygons
            hole.fairway?.forEach { coord in
                minLat = min(minLat, coord.lat)
                maxLat = max(maxLat, coord.lat)
                minLon = min(minLon, coord.lon)
                maxLon = max(maxLon, coord.lon)
            }
            
            hole.green?.forEach { coord in
                minLat = min(minLat, coord.lat)
                maxLat = max(maxLat, coord.lat)
                minLon = min(minLon, coord.lon)
                maxLon = max(maxLon, coord.lon)
            }
            
            hole.bunkers?.forEach { bunker in
                bunker.polygon.forEach { coord in
                    minLat = min(minLat, coord.lat)
                    maxLat = max(maxLat, coord.lat)
                    minLon = min(minLon, coord.lon)
                    maxLon = max(maxLon, coord.lon)
                }
            }
            
            hole.waterHazards?.forEach { water in
                water.polygon.forEach { coord in
                    minLat = min(minLat, coord.lat)
                    maxLat = max(maxLat, coord.lat)
                    minLon = min(minLon, coord.lon)
                    maxLon = max(maxLon, coord.lon)
                }
            }
        }
        
        // If no coordinates found, return safe defaults
        if minLat == Double.infinity || maxLat == -Double.infinity ||
           minLon == Double.infinity || maxLon == -Double.infinity {
            // Return small default bounds (won't actually be rendered since hasValidCoordinates will be false)
            return (minLat: 0, maxLat: 1, minLon: 0, maxLon: 1, width: 1, height: 1)
        }
        
        // Add padding
        let latPadding = (maxLat - minLat) * 0.05
        let lonPadding = (maxLon - minLon) * 0.05
        
        return (
            minLat: minLat - latPadding,
            maxLat: maxLat + latPadding,
            minLon: minLon - lonPadding,
            maxLon: maxLon + lonPadding,
            width: (maxLon - minLon) + (lonPadding * 2),
            height: (maxLat - minLat) + (latPadding * 2)
        )
    }
    
    private func gpsToPoint(lat: Double, lon: Double, bounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double, width: Double, height: Double), size: CGSize, scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> CGPoint {
        let normalizedLat = (lat - bounds.minLat) / bounds.height
        let normalizedLon = (lon - bounds.minLon) / bounds.width
        
        let x = offsetX + CGFloat(normalizedLon) * CGFloat(bounds.width) * scale
        let y = offsetY + CGFloat(1 - normalizedLat) * CGFloat(bounds.height) * scale // Flip Y
        
        return CGPoint(x: x, y: y)
    }
    
    private func drawHole(_ hole: HoleData, in context: GraphicsContext, size: CGSize, bounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double, width: Double, height: Double), scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        // Z-Order: Fairway -> Water -> Bunkers -> Green -> Tees -> Pin
        
        // Fairway
        if showLayers.fairway, let fairway = hole.fairway, fairway.count >= 3 {
            var path = Path()
            let points = fairway.map { gpsToPoint(lat: $0.lat, lon: $0.lon, bounds: bounds, size: size, scale: scale, offsetX: offsetX, offsetY: offsetY) }
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
            
            context.fill(path, with: .color(.green.opacity(0.4)))
            context.stroke(path, with: .color(.green), lineWidth: 1.5)
        }
        
        // Water hazards
        if showLayers.water, let water = hole.waterHazards {
            for hazard in water {
                if hazard.polygon.count >= 3 {
                    var path = Path()
                    let points = hazard.polygon.map { gpsToPoint(lat: $0.lat, lon: $0.lon, bounds: bounds, size: size, scale: scale, offsetX: offsetX, offsetY: offsetY) }
                    path.move(to: points[0])
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                    path.closeSubpath()
                    
                    context.fill(path, with: .color(.blue.opacity(0.6)))
                    context.stroke(path, with: .color(.blue), lineWidth: 1.5)
                }
            }
        }
        
        // Bunkers
        if showLayers.bunkers, let bunkers = hole.bunkers {
            for bunker in bunkers {
                if bunker.polygon.count >= 3 {
                    var path = Path()
                    let points = bunker.polygon.map { gpsToPoint(lat: $0.lat, lon: $0.lon, bounds: bounds, size: size, scale: scale, offsetX: offsetX, offsetY: offsetY) }
                    path.move(to: points[0])
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                    path.closeSubpath()
                    
                    context.fill(path, with: .color(.yellow.opacity(0.8)))
                    context.stroke(path, with: .color(.yellow.opacity(0.9)), lineWidth: 1.5)
                }
            }
        }
        
        // Green
        if showLayers.green, let green = hole.green, green.count >= 3 {
            var path = Path()
            let points = green.map { gpsToPoint(lat: $0.lat, lon: $0.lon, bounds: bounds, size: size, scale: scale, offsetX: offsetX, offsetY: offsetY) }
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
            
            context.fill(path, with: .color(Color(red: 0.06, green: 0.73, blue: 0.51).opacity(0.8)))
            context.stroke(path, with: .color(Color(red: 0.02, green: 0.59, blue: 0.41)), lineWidth: 2)
        }
        
        // Tee locations
        if let tees = hole.teeLocations {
            for tee in tees {
                let point = gpsToPoint(lat: tee.lat, lon: tee.lon, bounds: bounds, size: size, scale: scale, offsetX: offsetX, offsetY: offsetY)
                let color = teeColorToColor(tee.tee)
                
                let rect = CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14)
                context.fill(Path(ellipseIn: rect), with: .color(color))
                context.stroke(Path(ellipseIn: rect), with: .color(.white), lineWidth: 1.5)
                
                // Draw "T" in Canvas (using resolved view if possible, but simplest is to draw text)
                // GraphicsContext.draw text is preferred here
                let text = context.resolve(Text("T").font(.system(size: 8, weight: .bold)).foregroundColor(.white))
                context.draw(text, at: point)
            }
        }
        
        // Green center / Pin
        if let greenCenter = hole.greenCenter {
            let point = gpsToPoint(lat: greenCenter.lat, lon: greenCenter.lon, bounds: bounds, size: size, scale: scale, offsetX: offsetX, offsetY: offsetY)
            
            // Pin circle
            let pinRect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
            context.fill(Path(ellipseIn: pinRect), with: .color(.red))
            context.stroke(Path(ellipseIn: pinRect), with: .color(.white), lineWidth: 1.5)
            
            // Pin flag line
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: point.x, y: point.y - 5))
                    path.addLine(to: CGPoint(x: point.x, y: point.y - 15))
                    path.addLine(to: CGPoint(x: point.x + 8, y: point.y - 12))
                    path.addLine(to: CGPoint(x: point.x, y: point.y - 9))
                },
                with: .color(.red),
                lineWidth: 1.5
            )
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

struct LayerToggleButtonWithLabel: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool
    let color: Color
    
    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isOn ? icon : "eye.slash.fill")
                    .foregroundColor(isOn ? color : .gray)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(isOn ? color : .gray)
            }
            .padding(8)
            .background(isOn ? color.opacity(0.2) : Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
    }
}

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
            yardageMarkers: nil
        )
    ]
    
    return CourseSVGVisualizerView(holeData: sampleHoleData, initialHole: 1)
        .padding()
        .background(Color("Background"))
}
