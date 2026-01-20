import SwiftUI

/**
 * Toggle view between Map (MapKit) and Schematic (SVG) visualizations
 */
struct CourseVisualizationToggleView: View {
    let holeData: [HoleData]
    
    @State private var visualizationMode: VisualizationMode = .map
    
    enum VisualizationMode {
        case map
        case schematic
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Mode selector
            Picker("View Mode", selection: $visualizationMode) {
                Text("Map").tag(VisualizationMode.map)
                Text("Schematic").tag(VisualizationMode.schematic)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color("BackgroundSecondary"))
            
            // Content
            Group {
                switch visualizationMode {
                case .map:
                    CourseVisualizerView(
                        holeData: holeData,
                        initialHole: 1,
                        showSatellite: false
                    )
                    .frame(minHeight: 450)
                case .schematic:
                    CourseSVGVisualizerView(
                        holeData: holeData,
                        initialHole: 1
                    )
                    .frame(minHeight: 550)
                }
            }
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
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
            bunkers: nil,
            waterHazards: nil,
            trees: nil,
            yardageMarkers: nil
        )
    ]
    
    return CourseVisualizationToggleView(holeData: sampleHoleData)
        .padding()
        .background(Color("Background"))
}
