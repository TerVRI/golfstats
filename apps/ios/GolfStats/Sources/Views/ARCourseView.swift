import SwiftUI
import ARKit
import RealityKit
import CoreLocation

/// AR Course View that overlays distance information on the real world
/// Shows distances to green, hazards, and targets with AR markers
struct ARCourseView: View {
    @StateObject private var viewModel = ARCourseViewModel()
    @EnvironmentObject var gpsManager: GPSManager
    @EnvironmentObject var roundManager: RoundManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // AR View
            ARCourseContainer(viewModel: viewModel)
                .ignoresSafeArea()
            
            // Overlay UI
            VStack {
                // Top bar
                topBar
                
                Spacer()
                
                // Bottom info panel
                bottomPanel
            }
            
            // Calibration overlay
            if viewModel.needsCalibration {
                calibrationOverlay
            }
            
            // Loading overlay
            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .onAppear {
            viewModel.configure(gpsManager: gpsManager, roundManager: roundManager)
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.stopSession()
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            
            Spacer()
            
            // Hole info
            VStack(spacing: 2) {
                Text("Hole \(roundManager.currentHole)")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                if let par = viewModel.currentHolePar {
                    Text("Par \(par)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            // Settings
            Menu {
                Toggle("Show Hazards", isOn: $viewModel.showHazards)
                Toggle("Show Yardage Markers", isOn: $viewModel.showYardageMarkers)
                Toggle("Show Layup Lines", isOn: $viewModel.showLayupLines)
                
                Divider()
                
                Button("Recalibrate") {
                    viewModel.recalibrate()
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.black.opacity(0.6), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Bottom Panel
    
    private var bottomPanel: some View {
        VStack(spacing: 12) {
            // Main distance display
            HStack(spacing: 24) {
                distanceCard(label: "FRONT", distance: viewModel.distanceToFront, color: .blue)
                distanceCard(label: "CENTER", distance: viewModel.distanceToCenter, color: .green, isMain: true)
                distanceCard(label: "BACK", distance: viewModel.distanceToBack, color: .orange)
            }
            
            // AR accuracy indicator
            HStack {
                Circle()
                    .fill(viewModel.trackingQualityColor)
                    .frame(width: 8, height: 8)
                
                Text(viewModel.trackingStatusText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
                
                if let accuracy = viewModel.gpsAccuracy {
                    Text("GPS: ±\(Int(accuracy))m")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding()
    }
    
    private func distanceCard(label: String, distance: Int?, color: Color, isMain: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.7))
            
            Text(distance.map { "\($0)" } ?? "--")
                .font(isMain ? .system(size: 36, weight: .bold, design: .rounded) : .title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text("yds")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Calibration Overlay
    
    private var calibrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                
                Text("Point at the Green")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Aim your camera toward the center of the green and tap to calibrate")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // Compass indicator
                HStack(spacing: 8) {
                    Image(systemName: "location.north.fill")
                        .foregroundStyle(.red)
                    Text("Bearing to green: \(viewModel.bearingToGreen)°")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Button(action: { viewModel.calibrate() }) {
                    Text("Calibrate")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(.green)
                        .clipShape(Capsule())
                }
                .padding(.top)
            }
        }
        .onTapGesture {
            viewModel.calibrate()
        }
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Loading AR Course View...")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - AR View Container

struct ARCourseContainer: UIViewRepresentable {
    @ObservedObject var viewModel: ARCourseViewModel
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        
        // Configure for world tracking
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravityAndHeading
        config.planeDetection = []
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        
        arView.session.run(config)
        arView.session.delegate = context.coordinator
        
        viewModel.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Updates handled by viewModel
    }
    
    func makeCoordinator() -> ARCourseCoordinator {
        ARCourseCoordinator(viewModel: viewModel)
    }
}

class ARCourseCoordinator: NSObject, ARSessionDelegate {
    let viewModel: ARCourseViewModel
    
    init(viewModel: ARCourseViewModel) {
        self.viewModel = viewModel
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor in
            viewModel.updateFrame(frame)
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        Task { @MainActor in
            viewModel.updateTrackingState(camera.trackingState)
        }
    }
}

// MARK: - View Model

@MainActor
class ARCourseViewModel: ObservableObject {
    // Published state
    @Published var isLoading = true
    @Published var needsCalibration = true
    @Published var trackingState: ARCamera.TrackingState = .notAvailable
    
    // Distances
    @Published var distanceToFront: Int?
    @Published var distanceToCenter: Int?
    @Published var distanceToBack: Int?
    @Published var gpsAccuracy: Double?
    
    // Settings
    @Published var showHazards = true
    @Published var showYardageMarkers = true
    @Published var showLayupLines = false
    
    // AR entities
    var arView: ARView?
    private var greenAnchor: AnchorEntity?
    private var hazardAnchors: [AnchorEntity] = []
    private var markerAnchors: [AnchorEntity] = []
    
    // References
    private weak var gpsManager: GPSManager?
    private weak var roundManager: RoundManager?
    
    // Calibration
    private var isCalibrated = false
    private var calibrationHeading: Double = 0
    
    var currentHolePar: Int? {
        guard let roundManager = roundManager,
              let course = roundManager.selectedCourse,
              let holeData = course.holeData?.first(where: { $0.holeNumber == roundManager.currentHole }) else {
            return nil
        }
        return holeData.par
    }
    
    var bearingToGreen: Int {
        guard let userLocation = gpsManager?.currentLocation,
              let greenCenter = currentGreenCenter else {
            return 0
        }
        
        let bearing = calculateBearing(from: userLocation.coordinate, to: greenCenter)
        return Int(bearing)
    }
    
    var trackingQualityColor: Color {
        switch trackingState {
        case .normal: return .green
        case .limited: return .yellow
        case .notAvailable: return .red
        }
    }
    
    var trackingStatusText: String {
        switch trackingState {
        case .normal: return "AR Tracking Good"
        case .limited(let reason):
            switch reason {
            case .excessiveMotion: return "Move slower"
            case .insufficientFeatures: return "Need more light"
            case .initializing: return "Initializing..."
            case .relocalizing: return "Relocalizing..."
            @unknown default: return "Limited tracking"
            }
        case .notAvailable: return "AR Not Available"
        }
    }
    
    private var currentGreenCenter: CLLocationCoordinate2D? {
        guard let roundManager = roundManager,
              let course = roundManager.selectedCourse,
              let holeData = course.holeData?.first(where: { $0.holeNumber == roundManager.currentHole }),
              let greenCenter = holeData.greenCenter else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: greenCenter.lat, longitude: greenCenter.lon)
    }
    
    // MARK: - Configuration
    
    func configure(gpsManager: GPSManager, roundManager: RoundManager) {
        self.gpsManager = gpsManager
        self.roundManager = roundManager
    }
    
    func startSession() {
        isLoading = true
        
        // Get initial distances
        updateDistances()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.isLoading = false
        }
    }
    
    func stopSession() {
        arView?.session.pause()
        removeAllAnchors()
    }
    
    // MARK: - Calibration
    
    func calibrate() {
        guard let heading = gpsManager?.currentLocation?.course else {
            // Use device heading if available
            calibrationHeading = Double(bearingToGreen)
            finishCalibration()
            return
        }
        
        calibrationHeading = heading
        finishCalibration()
    }
    
    func recalibrate() {
        isCalibrated = false
        needsCalibration = true
        removeAllAnchors()
    }
    
    private func finishCalibration() {
        isCalibrated = true
        needsCalibration = false
        
        // Place AR markers
        placeGreenMarker()
        
        if showHazards {
            placeHazardMarkers()
        }
        
        if showYardageMarkers {
            placeYardageMarkers()
        }
    }
    
    // MARK: - AR Content
    
    private func placeGreenMarker() {
        guard let arView = arView,
              let userLocation = gpsManager?.currentLocation,
              let greenCenter = currentGreenCenter else {
            return
        }
        
        let distance = userLocation.distance(
            from: CLLocation(latitude: greenCenter.latitude, longitude: greenCenter.longitude)
        )
        
        // Convert to AR coordinates
        let bearing = calculateBearing(from: userLocation.coordinate, to: greenCenter)
        let relativeAngle = bearing - calibrationHeading
        
        // Create position in AR space (meters)
        let x = Float(distance * sin(relativeAngle * .pi / 180))
        let z = Float(-distance * cos(relativeAngle * .pi / 180))
        
        // Create anchor
        let anchor = AnchorEntity(world: SIMD3<Float>(x, 0, z))
        
        // Create flag model (use box as cylinder requires iOS 18+)
        let flagPole = MeshResource.generateBox(width: 0.04, height: 2.5, depth: 0.04)
        let poleMaterial = SimpleMaterial(color: .gray, isMetallic: true)
        let poleEntity = ModelEntity(mesh: flagPole, materials: [poleMaterial])
        poleEntity.position.y = 1.25
        
        let flag = MeshResource.generateBox(width: 0.6, height: 0.4, depth: 0.02)
        let flagMaterial = SimpleMaterial(color: .red, isMetallic: false)
        let flagEntity = ModelEntity(mesh: flag, materials: [flagMaterial])
        flagEntity.position = SIMD3<Float>(0.3, 2.3, 0)
        
        anchor.addChild(poleEntity)
        anchor.addChild(flagEntity)
        
        // Add distance label
        let distanceText = generateDistanceLabel(Int(distance))
        distanceText.position = SIMD3<Float>(0, 3, 0)
        anchor.addChild(distanceText)
        
        arView.scene.addAnchor(anchor)
        greenAnchor = anchor
    }
    
    private func placeHazardMarkers() {
        guard let arView = arView,
              let userLocation = gpsManager?.currentLocation,
              let roundManager = roundManager,
              let course = roundManager.selectedCourse,
              let holeData = course.holeData?.first(where: { $0.holeNumber == roundManager.currentHole }) else {
            return
        }
        
        // Water hazards
        if let waterHazards = holeData.waterHazards {
            for hazard in waterHazards {
                if let center = calculatePolygonCenter(hazard.polygon) {
                    let anchor = createHazardAnchor(
                        userLocation: userLocation,
                        hazardCenter: center,
                        type: .water
                    )
                    arView.scene.addAnchor(anchor)
                    hazardAnchors.append(anchor)
                }
            }
        }
        
        // Bunkers
        if let bunkers = holeData.bunkers {
            for bunker in bunkers {
                if let center = calculatePolygonCenter(bunker.polygon) {
                    let anchor = createHazardAnchor(
                        userLocation: userLocation,
                        hazardCenter: center,
                        type: .bunker
                    )
                    arView.scene.addAnchor(anchor)
                    hazardAnchors.append(anchor)
                }
            }
        }
    }
    
    private func createHazardAnchor(userLocation: CLLocation, hazardCenter: CLLocationCoordinate2D, type: HazardType) -> AnchorEntity {
        let distance = userLocation.distance(
            from: CLLocation(latitude: hazardCenter.latitude, longitude: hazardCenter.longitude)
        )
        
        let bearing = calculateBearing(from: userLocation.coordinate, to: hazardCenter)
        let relativeAngle = bearing - calibrationHeading
        
        let x = Float(distance * sin(relativeAngle * .pi / 180))
        let z = Float(-distance * cos(relativeAngle * .pi / 180))
        
        let anchor = AnchorEntity(world: SIMD3<Float>(x, 0, z))
        
        // Create hazard indicator
        let indicatorMesh = MeshResource.generateSphere(radius: 0.5)
        let color: UIColor = type == .water ? .blue : .yellow
        let material = SimpleMaterial(color: color.withAlphaComponent(0.7), isMetallic: false)
        let indicator = ModelEntity(mesh: indicatorMesh, materials: [material])
        indicator.position.y = 0.5
        
        anchor.addChild(indicator)
        
        // Add distance label
        let label = generateDistanceLabel(Int(distance), color: color)
        label.position = SIMD3<Float>(0, 1.5, 0)
        anchor.addChild(label)
        
        return anchor
    }
    
    private func placeYardageMarkers() {
        guard let arView = arView,
              let userLocation = gpsManager?.currentLocation,
              let roundManager = roundManager,
              let course = roundManager.selectedCourse,
              let holeData = course.holeData?.first(where: { $0.holeNumber == roundManager.currentHole }),
              let markers = holeData.yardageMarkers else {
            return
        }
        
        for marker in markers {
            let markerLocation = CLLocation(latitude: marker.coordinate.latitude, longitude: marker.coordinate.longitude)
            let distance = userLocation.distance(from: markerLocation)
            
            let bearing = calculateBearing(from: userLocation.coordinate, to: marker.coordinate)
            let relativeAngle = bearing - calibrationHeading
            
            let x = Float(distance * sin(relativeAngle * .pi / 180))
            let z = Float(-distance * cos(relativeAngle * .pi / 180))
            
            let anchor = AnchorEntity(world: SIMD3<Float>(x, 0, z))
            
            // Create marker (use box as cylinder requires iOS 18+)
            let markerMesh = MeshResource.generateBox(width: 0.2, height: 1.5, depth: 0.2)
            let material = SimpleMaterial(color: .white, isMetallic: false)
            let markerEntity = ModelEntity(mesh: markerMesh, materials: [material])
            markerEntity.position.y = 0.75
            
            anchor.addChild(markerEntity)
            
            // Add distance label
            let label = generateDistanceLabel(marker.distance)
            label.position = SIMD3<Float>(0, 2, 0)
            anchor.addChild(label)
            
            arView.scene.addAnchor(anchor)
            markerAnchors.append(anchor)
        }
    }
    
    private func generateDistanceLabel(_ distance: Int, color: UIColor = .white) -> ModelEntity {
        let mesh = MeshResource.generateText(
            "\(distance)",
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.5, weight: .bold),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        
        let material = SimpleMaterial(color: color, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        
        // Make text face camera (billboard)
        entity.scale = SIMD3<Float>(1, 1, 1)
        
        return entity
    }
    
    private func removeAllAnchors() {
        greenAnchor?.removeFromParent()
        greenAnchor = nil
        
        for anchor in hazardAnchors {
            anchor.removeFromParent()
        }
        hazardAnchors.removeAll()
        
        for anchor in markerAnchors {
            anchor.removeFromParent()
        }
        markerAnchors.removeAll()
    }
    
    // MARK: - Frame Updates
    
    func updateFrame(_ frame: ARFrame) {
        // Update distances periodically
        updateDistances()
        
        // Update GPS accuracy
        gpsAccuracy = gpsManager?.currentLocation?.horizontalAccuracy
    }
    
    func updateTrackingState(_ state: ARCamera.TrackingState) {
        DispatchQueue.main.async {
            self.trackingState = state
        }
    }
    
    private func updateDistances() {
        distanceToFront = gpsManager?.distanceToFront
        distanceToCenter = gpsManager?.distanceToCenter
        distanceToBack = gpsManager?.distanceToBack
    }
    
    // MARK: - Calculations
    
    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        var bearing = atan2(y, x) * 180 / .pi
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)
        
        return bearing
    }
    
    private func calculatePolygonCenter(_ polygon: [Coordinate]) -> CLLocationCoordinate2D? {
        guard !polygon.isEmpty else { return nil }
        
        let totalLat = polygon.reduce(0) { $0 + $1.lat }
        let totalLon = polygon.reduce(0) { $0 + $1.lon }
        
        return CLLocationCoordinate2D(
            latitude: totalLat / Double(polygon.count),
            longitude: totalLon / Double(polygon.count)
        )
    }
}

// MARK: - Supporting Types

enum HazardType {
    case water
    case bunker
}

// MARK: - Preview

#Preview {
    ARCourseView()
        .environmentObject(GPSManager())
        .environmentObject(RoundManager())
}
