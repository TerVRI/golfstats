import SwiftUI
import MapKit
import CoreLocation

/// Full-screen in-round experience with satellite map, smart overlays, and pull-up drawers
/// Designed for maximum visibility while playing, with easy access to all features
struct FullScreenRoundView: View {
    @EnvironmentObject var gpsManager: GPSManager
    @EnvironmentObject var roundManager: RoundManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var watchSyncManager: WatchSyncManager
    
    // Map state
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var mapStyle: MapDisplayStyle = .satellite
    @State private var showLayers = LayerVisibility()
    @State private var isUserInteracting = false
    @State private var followUserLocation = true
    
    // Drawer state
    @State private var drawerState: DrawerState = .collapsed
    @State private var drawerOffset: CGFloat = 0
    @State private var activeDrawerTab: DrawerTab = .scorecard
    
    // UI state
    @State private var showEndRoundAlert = false
    @State private var showClubPicker = false
    @State private var selectedClub: ClubType = .sevenIron
    @State private var showSettings = false
    @State private var showLayerPicker = false
    @State private var showARView = false
    @State private var showAICaddie = false
    @State private var showCourseNotes = false
    @State private var isSaving = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full-screen map
                fullScreenMap
                    .ignoresSafeArea()
                
                // Floating overlays
                VStack(spacing: 0) {
                    // Top bar (minimal, semi-transparent)
                    topOverlay
                    
                    Spacer()
                    
                    // Distance display (floating)
                    distanceOverlay
                        .padding(.bottom, 16)
                    
                    // Pull-up drawer
                    pullUpDrawer(geometry: geometry)
                }
                
                // Quick action buttons (right side)
                quickActionButtons
                
                // Hole navigator (left side)
                holeNavigatorOverlay
            }
        }
        .onAppear {
            setupView()
        }
        .onDisappear {
            cleanupView()
        }
        .onChange(of: roundManager.currentHole) { _, _ in
            updateForCurrentHole()
        }
        .onChange(of: gpsManager.currentLocation) { _, newLocation in
            if followUserLocation, let location = newLocation {
                updateCameraToFollow(location)
            }
        }
        .alert("End Round?", isPresented: $showEndRoundAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Save & End", role: .destructive) {
                Task { await saveAndEndRound() }
            }
            Button("Discard", role: .destructive) {
                roundManager.endRound()
            }
        }
        .sheet(isPresented: $showClubPicker) {
            ClubPickerSheet(selectedClub: $selectedClub) {
                markShot()
            }
        }
        .sheet(isPresented: $showSettings) {
            MapSettingsSheet(mapStyle: $mapStyle, showLayers: $showLayers)
        }
        .fullScreenCover(isPresented: $showARView) {
            ARCourseView()
        }
        .sheet(isPresented: $showAICaddie) {
            NavigationStack {
                AICaddieView()
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCourseNotes) {
            NavigationStack {
                if let course = roundManager.selectedCourse {
                    CourseNotesView(course: course)
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
    
    // MARK: - Full Screen Map
    
    private var fullScreenMap: some View {
        Map(position: $cameraPosition, interactionModes: .all) {
            // User location
            UserAnnotation()
            
            // Course overlays
            if let hole = currentHoleData {
                courseOverlays(for: hole)
            }
            
            // Annotations
            ForEach(mapAnnotations) { item in
                Annotation("", coordinate: item.coordinate) {
                    item.view
                }
            }
            
            // Shot markers
            ForEach(roundManager.currentHoleShots, id: \.id) { shot in
                if let lat = shot.latitude, let lon = shot.longitude {
                    Annotation("", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                        ShotMarker(shot: shot)
                    }
                }
            }
        }
        .mapStyle(mapStyle.mapKitStyle)
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .continuous) { context in
            isUserInteracting = true
            // Disable auto-follow when user interacts
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                isUserInteracting = false
            }
        }
    }
    
    @MapContentBuilder
    private func courseOverlays(for hole: HoleData) -> some MapContent {
        let reference = hole.greenCenter?.clLocation ?? hole.teeLocations?.first?.coordinate
        
        // Fairway
        if showLayers.fairway, let fairway = hole.fairway, fairway.count >= 3 {
            let coords = normalizedPolygon(fairway, reference: reference)
            MapPolygon(coordinates: coords + [coords[0]])
                .foregroundStyle(.green.opacity(mapStyle == .satellite ? 0.2 : 0.3))
                .stroke(.green.opacity(0.8), lineWidth: 2)
        }
        
        // Green
        if showLayers.green, let green = hole.green, green.count >= 3 {
            let coords = normalizedPolygon(green, reference: reference)
            MapPolygon(coordinates: coords + [coords[0]])
                .foregroundStyle(.green.opacity(mapStyle == .satellite ? 0.3 : 0.5))
                .stroke(.green, lineWidth: 3)
        }
        
        // Bunkers
        if showLayers.bunkers, let bunkers = hole.bunkers {
            ForEach(Array(bunkers.enumerated()), id: \.offset) { _, bunker in
                if bunker.polygon.count >= 3 {
                    let coords = normalizedPolygon(bunker.polygon, reference: reference)
                    MapPolygon(coordinates: coords + [coords[0]])
                        .foregroundStyle(.yellow.opacity(mapStyle == .satellite ? 0.3 : 0.4))
                        .stroke(.yellow.opacity(0.9), lineWidth: 2)
                }
            }
        }
        
        // Water
        if showLayers.water, let water = hole.waterHazards {
            ForEach(Array(water.enumerated()), id: \.offset) { _, hazard in
                if hazard.polygon.count >= 3 {
                    let coords = normalizedPolygon(hazard.polygon, reference: reference)
                    MapPolygon(coordinates: coords + [coords[0]])
                        .foregroundStyle(.blue.opacity(mapStyle == .satellite ? 0.3 : 0.5))
                        .stroke(.blue, lineWidth: 2)
                }
            }
        }
        
        // Distance lines (from user to green)
        if let userLocation = gpsManager.currentLocation?.coordinate,
           let greenCenter = hole.greenCenter?.clLocation {
            MapPolyline(coordinates: [userLocation, greenCenter])
                .stroke(.white.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [10, 5]))
        }
    }
    
    // MARK: - Top Overlay
    
    private var topOverlay: some View {
        HStack {
            // End round button
            Button(action: { showEndRoundAlert = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                    Text("End")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.red.opacity(0.8))
                .clipShape(Capsule())
            }
            
            Spacer()
            
            // Course name and score
            VStack(spacing: 2) {
                Text(roundManager.selectedCourse?.name ?? "Round")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                HStack(spacing: 8) {
                    Text("Score: \(roundManager.totalScore)")
                        .font(.caption)
                    
                    if roundManager.totalScore != 0 {
                        let vspar = roundManager.totalScore - roundManager.totalPar
                        Text(vspar >= 0 ? "+\(vspar)" : "\(vspar)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(vspar <= 0 ? .green : .red)
                    }
                }
                .foregroundStyle(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Watch connection status
            HStack(spacing: 4) {
                if authManager.hasProAccess && watchSyncManager.isWatchConnected {
                    Image(systemName: "applewatch")
                        .foregroundStyle(.green)
                }
                
                // Settings button
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.7), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Distance Overlay
    
    @State private var showPlaysLikeDetails = false
    
    private var distanceOverlay: some View {
        VStack(spacing: 8) {
            // Main center distance with "Plays Like"
            VStack(spacing: 4) {
                if let distance = gpsManager.distanceToCenter {
                    // GPS and Plays Like distances
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        // GPS distance
                        Text("\(distance)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Text("|")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.3))
                        
                        // Plays Like distance (adjusted)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(playsLikeDistance(gpsDistance: distance))")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                            Text("PLAYS")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.green.opacity(0.8))
                        }
                    }
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                    
                    // Labels
                    HStack(spacing: 40) {
                        Text("GPS")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.6))
                        
                        Text("")
                        
                        Text("")
                    }
                    
                    // Environmental adjustments (expandable)
                    if authManager.hasProAccess {
                        Button(action: { showPlaysLikeDetails.toggle() }) {
                            HStack(spacing: 12) {
                                AdjustmentPill(icon: "wind", label: windAdjustmentText, color: windAdjustment < 0 ? .green : windAdjustment > 0 ? .red : .gray)
                                AdjustmentPill(icon: "arrow.up.right", label: slopeAdjustmentText, color: slopeAdjustment > 0 ? .red : slopeAdjustment < 0 ? .green : .gray)
                                AdjustmentPill(icon: "thermometer.medium", label: tempAdjustmentText, color: tempAdjustment > 0 ? .red : tempAdjustment < 0 ? .green : .gray)
                                
                                Image(systemName: showPlaysLikeDetails ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        }
                        
                        // Detailed breakdown
                        if showPlaysLikeDetails {
                            PlaysLikeDetailView(
                                gpsDistance: distance,
                                windAdjustment: windAdjustment,
                                slopeAdjustment: slopeAdjustment,
                                tempAdjustment: tempAdjustment,
                                humidityAdjustment: humidityAdjustment,
                                altitudeAdjustment: altitudeAdjustment
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                } else {
                    Text("---")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Text("WAITING FOR GPS")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showPlaysLikeDetails)
            
            // Front/Back distances
            HStack(spacing: 40) {
                distanceChip(label: "FRONT", distance: gpsManager.distanceToFront)
                distanceChip(label: "BACK", distance: gpsManager.distanceToBack)
            }
            
            // Last shot distance
            if let lastShot = gpsManager.lastShotDistance {
                HStack(spacing: 6) {
                    Image(systemName: "figure.golf")
                        .foregroundStyle(.orange)
                    Text("Last shot: \(lastShot) yds")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - Plays Like Calculations
    
    /// Calculate adjusted "plays like" distance based on environmental factors
    private func playsLikeDistance(gpsDistance: Int) -> Int {
        let adjustments = windAdjustment + slopeAdjustment + tempAdjustment + humidityAdjustment + altitudeAdjustment
        return gpsDistance + adjustments
    }
    
    /// Wind adjustment based on direction and speed
    private var windAdjustment: Int {
        // For demo purposes, using simulated values
        // In production, this would come from weather API via WeatherManager
        guard let windSpeed = simulatedWindSpeed,
              let windDirection = simulatedWindDirection else { return 0 }
        
        // Calculate headwind/tailwind component
        // Positive = headwind (plays longer), Negative = tailwind (plays shorter)
        let bearingToHole = Double(gpsManager.bearingToTarget ?? 0)
        let windAngle = abs(windDirection - bearingToHole)
        let headwindComponent = cos(windAngle * .pi / 180)
        
        // Rule of thumb: ~1 yard per mph of headwind/tailwind
        return Int((Double(windSpeed) * headwindComponent).rounded())
    }
    
    /// Slope/elevation adjustment
    private var slopeAdjustment: Int {
        // Positive elevation = plays longer, negative = plays shorter
        // Rule of thumb: ~1 yard per 3 feet of elevation change
        // Note: Elevation data not currently available in HoleData
        // This would require elevation API integration or course-specific data
        return 0
    }
    
    /// Temperature adjustment
    private var tempAdjustment: Int {
        // Ball travels farther in warm air, shorter in cold
        // Rule of thumb: ~2 yards per 10°F difference from 70°F
        guard let temp = simulatedTemperature else { return 0 }
        let diff = temp - 70
        return Int((diff / 10.0 * 2).rounded())
    }
    
    /// Humidity adjustment
    private var humidityAdjustment: Int {
        // Higher humidity = slightly less air resistance = slightly farther
        // Effect is minimal: ~1 yard per 25% humidity above 50%
        guard let humidity = simulatedHumidity else { return 0 }
        let diff = humidity - 50
        return -Int((diff / 25.0).rounded()) // Negative because higher humidity = plays shorter
    }
    
    /// Altitude adjustment
    private var altitudeAdjustment: Int {
        // Ball travels farther at altitude due to thinner air
        // Rule of thumb: ~2% farther per 1000 feet above sea level
        guard let altitude = gpsManager.currentLocation?.altitude,
              let distance = gpsManager.distanceToCenter else { return 0 }
        let altitudeFeet = altitude * 3.28084 // Convert meters to feet
        let percentIncrease = (altitudeFeet / 1000.0) * 0.02
        return -Int((Double(distance) * percentIncrease).rounded()) // Negative because ball travels farther
    }
    
    // Text formatters for adjustments
    private var windAdjustmentText: String {
        let adj = windAdjustment
        if adj == 0 { return "0y" }
        return adj > 0 ? "+\(adj)y" : "\(adj)y"
    }
    
    private var slopeAdjustmentText: String {
        let adj = slopeAdjustment
        if adj == 0 { return "0y" }
        return adj > 0 ? "+\(adj)y" : "\(adj)y"
    }
    
    private var tempAdjustmentText: String {
        let adj = tempAdjustment
        if adj == 0 { return "0y" }
        return adj > 0 ? "+\(adj)y" : "\(adj)y"
    }
    
    // Simulated environmental values (would come from weather API in production)
    private var simulatedWindSpeed: Int? { 8 }  // mph
    private var simulatedWindDirection: Double? { 180 } // degrees
    private var simulatedTemperature: Double? { 65 }  // Fahrenheit
    private var simulatedHumidity: Double? { 55 }  // percent
    
    private func distanceChip(label: String, distance: Int?) -> some View {
        VStack(spacing: 2) {
            Text(distance.map { "\($0)" } ?? "--")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(width: 80)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Hole Navigator Overlay
    
    private var holeNavigatorOverlay: some View {
        VStack {
            Spacer()
            
            HStack {
                // Hole navigation
                VStack(spacing: 8) {
                    Button(action: { roundManager.previousHole() }) {
                        Image(systemName: "chevron.up")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(roundManager.currentHole > 1 ? .white : .gray)
                            .frame(width: 44, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(roundManager.currentHole == 1)
                    
                    VStack(spacing: 2) {
                        Text("\(roundManager.currentHole)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        if let par = currentHoleData?.par {
                            Text("Par \(par)")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .frame(width: 60, height: 60)
                    .background(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Button(action: { roundManager.nextHole() }) {
                        Image(systemName: "chevron.down")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(roundManager.currentHole < 18 ? .white : .gray)
                            .frame(width: 44, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(roundManager.currentHole == 18)
                }
                .padding(.leading, 16)
                .padding(.bottom, drawerState == .collapsed ? 100 : 300)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Quick Action Buttons
    
    private var quickActionButtons: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                VStack(spacing: 12) {
                    // Mark shot button
                    Button(action: { showClubPicker = true }) {
                        VStack(spacing: 4) {
                            Image(systemName: "scope")
                                .font(.title2)
                            Text("Shot")
                                .font(.caption2)
                        }
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(.orange)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                    }
                    
                    // Recenter button
                    Button(action: { recenterMap() }) {
                        Image(systemName: followUserLocation ? "location.fill" : "location")
                            .font(.title3)
                            .foregroundStyle(followUserLocation ? .blue : .white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    // Map style toggle
                    Button(action: { cycleMapStyle() }) {
                        Image(systemName: mapStyle.icon)
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    // Layer picker
                    Button(action: { showLayerPicker.toggle() }) {
                        Image(systemName: "square.3.layers.3d")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .popover(isPresented: $showLayerPicker) {
                        LayerPickerPopover(showLayers: $showLayers)
                            .presentationCompactAdaptation(.popover)
                    }
                    
                    // AR View button (if device supports AR)
                    if ARBodyTrackingManager.isSupported {
                        Button(action: { showARView = true }) {
                            Image(systemName: "arkit")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    
                    // AI Caddie button
                    Button(action: { showAICaddie = true }) {
                        Image(systemName: "brain")
                            .font(.title3)
                            .foregroundStyle(.purple)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    // Course Notes button
                    Button(action: { showCourseNotes = true }) {
                        Image(systemName: "note.text")
                            .font(.title3)
                            .foregroundStyle(.yellow)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.trailing, 16)
                .padding(.bottom, drawerState == .collapsed ? 100 : 300)
            }
        }
    }
    
    // MARK: - Pull-Up Drawer
    
    private func pullUpDrawer(geometry: GeometryProxy) -> some View {
        let collapsedHeight: CGFloat = 80
        let expandedHeight: CGFloat = geometry.size.height * 0.5
        let fullHeight: CGFloat = geometry.size.height * 0.85
        
        let currentHeight: CGFloat = {
            switch drawerState {
            case .collapsed: return collapsedHeight
            case .partial: return expandedHeight
            case .expanded: return fullHeight
            }
        }()
        
        return VStack(spacing: 0) {
            // Handle
            VStack(spacing: 8) {
                Capsule()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 40, height: 4)
                    .padding(.top, 8)
                
                // Tab selector
                HStack(spacing: 0) {
                    ForEach(DrawerTab.allCases, id: \.self) { tab in
                        Button(action: { activeDrawerTab = tab }) {
                            VStack(spacing: 4) {
                                Image(systemName: tab.icon)
                                    .font(.title3)
                                Text(tab.title)
                                    .font(.caption2)
                            }
                            .foregroundStyle(activeDrawerTab == tab ? .green : .white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .background(Color("BackgroundSecondary"))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        drawerOffset = value.translation.height
                    }
                    .onEnded { value in
                        handleDrawerDrag(value: value)
                    }
            )
            
            // Content
            TabView(selection: $activeDrawerTab) {
                DrawerScorecardContent()
                    .tag(DrawerTab.scorecard)
                
                DrawerStatsContent()
                    .tag(DrawerTab.stats)
                
                DrawerShotsContent(showClubPicker: $showClubPicker, selectedClub: $selectedClub)
                    .tag(DrawerTab.shots)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(Color("Background"))
        }
        .frame(height: max(50, currentHeight + drawerOffset))
        .background(Color("Background"))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
        .animation(.spring(response: 0.3), value: drawerState)
    }
    
    private func handleDrawerDrag(value: DragGesture.Value) {
        let threshold: CGFloat = 50
        
        withAnimation(.spring(response: 0.3)) {
            if value.translation.height < -threshold {
                // Swiped up
                switch drawerState {
                case .collapsed: drawerState = .partial
                case .partial: drawerState = .expanded
                case .expanded: break
                }
            } else if value.translation.height > threshold {
                // Swiped down
                switch drawerState {
                case .collapsed: break
                case .partial: drawerState = .collapsed
                case .expanded: drawerState = .partial
                }
            }
            drawerOffset = 0
        }
    }
    
    // MARK: - Helpers
    
    private var currentHoleData: HoleData? {
        roundManager.selectedCourse?.holeData?.first { $0.holeNumber == roundManager.currentHole }
    }
    
    private var mapAnnotations: [MapAnnotationData] {
        guard let hole = currentHoleData else { return [] }
        var annotations: [MapAnnotationData] = []
        
        // Green markers
        if let front = hole.greenFront?.clLocation {
            annotations.append(MapAnnotationData(
                coordinate: front,
                view: AnyView(GreenEdgeMarker(label: "F"))
            ))
        }
        if let center = hole.greenCenter?.clLocation {
            annotations.append(MapAnnotationData(
                coordinate: center,
                view: AnyView(FlagMarker())
            ))
        }
        if let back = hole.greenBack?.clLocation {
            annotations.append(MapAnnotationData(
                coordinate: back,
                view: AnyView(GreenEdgeMarker(label: "B"))
            ))
        }
        
        // Yardage markers
        if showLayers.yardageMarkers, let markers = hole.yardageMarkers {
            for marker in markers {
                annotations.append(MapAnnotationData(
                    coordinate: marker.coordinate,
                    view: AnyView(YardageMarkerView(distance: marker.distance))
                ))
            }
        }
        
        return annotations
    }
    
    private func setupView() {
        gpsManager.startTracking()
        updateForCurrentHole()
        
        if authManager.hasProAccess {
            setupWatchSync()
        }
    }
    
    private func cleanupView() {
        gpsManager.stopTracking()
        roundManager.onStateChanged = nil
    }
    
    private func updateForCurrentHole() {
        // Update green locations for GPS
        guard let hole = currentHoleData else {
            gpsManager.clearGreenLocations()
            return
        }
        
        let front = hole.greenFront.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        let center = hole.greenCenter.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        let back = hole.greenBack.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        gpsManager.setGreenLocations(front: front, center: center, back: back)
        
        // Update camera to show hole
        if let greenCenter = hole.greenCenter?.clLocation {
            withAnimation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: greenCenter,
                    span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
                ))
            }
        }
    }
    
    private func updateCameraToFollow(_ location: CLLocation) {
        guard !isUserInteracting else { return }
        
        // Smooth camera follow
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
            ))
        }
    }
    
    private func recenterMap() {
        followUserLocation = true
        if let location = gpsManager.currentLocation {
            updateCameraToFollow(location)
        }
    }
    
    private func cycleMapStyle() {
        mapStyle = mapStyle.next
    }
    
    private func markShot() {
        gpsManager.markShot()
        roundManager.addShot(
            club: selectedClub,
            location: gpsManager.currentLocation?.coordinate
        )
    }
    
    private func setupWatchSync() {
        roundManager.onStateChanged = { [self] in
            watchSyncManager.sendRoundStateToWatch(
                isActive: roundManager.isRoundActive,
                currentHole: roundManager.currentHole,
                courseName: roundManager.selectedCourse?.name ?? "Unknown",
                holeScores: roundManager.holeScores
            )
        }
        
        if let course = roundManager.selectedCourse {
            watchSyncManager.sendCourseToWatch(course: course)
        }
    }
    
    private func saveAndEndRound() async {
        guard let user = authManager.currentUser else { return }
        isSaving = true
        
        do {
            try await roundManager.saveRound(userId: user.id, authHeaders: authManager.authHeaders)
            if authManager.hasProAccess {
                watchSyncManager.sendEndRoundToWatch()
            }
        } catch {
            print("Error saving round: \(error)")
        }
        
        isSaving = false
    }
    
    // Polygon normalization (same as CourseVisualizerView)
    private func normalizedPolygon(_ polygon: [Coordinate], reference: CLLocationCoordinate2D?) -> [CLLocationCoordinate2D] {
        let original = polygon.map { $0.clLocation }
        guard let reference else { return original }
        
        let swapped = polygon.map { CLLocationCoordinate2D(latitude: $0.lon, longitude: $0.lat) }
        let swappedValid = swapped.allSatisfy { abs($0.latitude) <= 90 && abs($0.longitude) <= 180 }
        
        let refLoc = CLLocation(latitude: reference.latitude, longitude: reference.longitude)
        let originalDist = original.reduce(0.0) { $0 + CLLocation(latitude: $1.latitude, longitude: $1.longitude).distance(from: refLoc) }
        let swappedDist = swappedValid ? swapped.reduce(0.0) { $0 + CLLocation(latitude: $1.latitude, longitude: $1.longitude).distance(from: refLoc) } : originalDist
        
        return swappedValid && swappedDist < originalDist ? swapped : original
    }
}

// MARK: - Supporting Types

enum MapDisplayStyle: CaseIterable {
    case satellite
    case hybrid
    case standard
    
    var mapKitStyle: MapStyle {
        switch self {
        case .satellite: return .imagery
        case .hybrid: return .hybrid
        case .standard: return .standard
        }
    }
    
    var icon: String {
        switch self {
        case .satellite: return "globe.americas.fill"
        case .hybrid: return "map.fill"
        case .standard: return "map"
        }
    }
    
    var next: MapDisplayStyle {
        let all = MapDisplayStyle.allCases
        let idx = all.firstIndex(of: self)!
        return all[(idx + 1) % all.count]
    }
}

enum DrawerState {
    case collapsed
    case partial
    case expanded
}

enum DrawerTab: CaseIterable {
    case scorecard
    case stats
    case shots
    
    var title: String {
        switch self {
        case .scorecard: return "Score"
        case .stats: return "Stats"
        case .shots: return "Shots"
        }
    }
    
    var icon: String {
        switch self {
        case .scorecard: return "list.number"
        case .stats: return "chart.bar.fill"
        case .shots: return "scope"
        }
    }
}

struct MapAnnotationData: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let view: AnyView
}

// MARK: - Drawer Content Views

struct DrawerScorecardContent: View {
    @EnvironmentObject var roundManager: RoundManager
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Front 9
                ScorecardSection(title: "Front 9", holes: 1...9)
                
                // Back 9
                ScorecardSection(title: "Back 9", holes: 10...18)
            }
            .padding()
        }
    }
}

struct ScorecardSection: View {
    @EnvironmentObject var roundManager: RoundManager
    let title: String
    let holes: ClosedRange<Int>
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Hole numbers
            HStack(spacing: 4) {
                Text("")
                    .frame(width: 40)
                ForEach(Array(holes), id: \.self) { hole in
                    Text("\(hole)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
                Text("Tot")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 36)
            }
            
            // Par row
            HStack(spacing: 4) {
                Text("Par")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                    .frame(width: 40, alignment: .leading)
                
                ForEach(Array(holes), id: \.self) { hole in
                    let par = roundManager.holeScores.first { $0.holeNumber == hole }?.par ?? 4
                    Text("\(par)")
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .frame(maxWidth: .infinity)
                }
                
                let totalPar = holes.reduce(0) { result, hole in result + (roundManager.holeScores.first { $0.holeNumber == hole }?.par ?? 4) }
                Text("\(totalPar)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.gray)
                    .frame(width: 36)
            }
            
            // Score row
            HStack(spacing: 4) {
                Text("Score")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .frame(width: 40, alignment: .leading)
                
                ForEach(holes, id: \.self) { hole in
                    let holeScore = roundManager.holeScores.first { $0.holeNumber == hole }
                    let score = holeScore?.score ?? 0
                    let par = holeScore?.par ?? 4
                    
                    Text(score > 0 ? "\(score)" : "-")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(scoreColor(score: score, par: par))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(roundManager.currentHole == hole ? Color.green.opacity(0.3) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                
                let totalScore = holes.reduce(0) { result, hole in result + (roundManager.holeScores.first { $0.holeNumber == hole }?.score ?? 0) }
                Text(totalScore > 0 ? "\(totalScore)" : "-")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 36)
            }
        }
        .padding(.bottom, 16)
    }
    
    private func scoreColor(score: Int, par: Int) -> Color {
        guard score > 0 else { return .white }
        let diff = score - par
        switch diff {
        case ..<(-1): return .yellow  // Eagle or better
        case -1: return .red          // Birdie
        case 0: return .white         // Par
        case 1: return .blue          // Bogey
        default: return .purple       // Double+
        }
    }
}

struct DrawerStatsContent: View {
    @EnvironmentObject var roundManager: RoundManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Quick stats
                HStack(spacing: 20) {
                    StatCard(title: "FIR", value: fairwaysHit, color: .green)
                    StatCard(title: "GIR", value: greensInReg, color: .green)
                    StatCard(title: "Putts", value: "\(totalPutts)", color: .blue)
                }
                
                // Score distribution
                VStack(alignment: .leading, spacing: 8) {
                    Text("Score Distribution")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 12) {
                        ScoreDistributionItem(label: "Eagles", count: eagles, color: .yellow)
                        ScoreDistributionItem(label: "Birdies", count: birdies, color: .red)
                        ScoreDistributionItem(label: "Pars", count: pars, color: .white)
                        ScoreDistributionItem(label: "Bogeys", count: bogeys, color: .blue)
                        ScoreDistributionItem(label: "Others", count: others, color: .purple)
                    }
                }
                .padding()
                .background(Color("BackgroundSecondary"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }
    
    // Computed stats
    private var completedHoles: [HoleScore] {
        roundManager.holeScores.filter { ($0.score ?? 0) > 0 }
    }
    
    private var fairwaysHit: String {
        let eligible = completedHoles.filter { $0.par > 3 }
        let hit = eligible.filter { $0.fairwayHit == true }.count
        return "\(hit)/\(eligible.count)"
    }
    
    private var greensInReg: String {
        let hit = completedHoles.filter { $0.gir == true }.count
        return "\(hit)/\(completedHoles.count)"
    }
    
    private var totalPutts: Int {
        completedHoles.reduce(0) { $0 + ($1.putts ?? 0) }
    }
    
    private var eagles: Int { completedHoles.filter { ($0.score ?? 0) <= $0.par - 2 && ($0.score ?? 0) > 0 }.count }
    private var birdies: Int { completedHoles.filter { $0.score == $0.par - 1 }.count }
    private var pars: Int { completedHoles.filter { $0.score == $0.par }.count }
    private var bogeys: Int { completedHoles.filter { $0.score == $0.par + 1 }.count }
    private var others: Int { completedHoles.filter { ($0.score ?? 0) > $0.par + 1 }.count }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color("BackgroundSecondary"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ScoreDistributionItem: View {
    let label: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.gray)
        }
    }
}

struct DrawerShotsContent: View {
    @EnvironmentObject var roundManager: RoundManager
    @EnvironmentObject var gpsManager: GPSManager
    @Binding var showClubPicker: Bool
    @Binding var selectedClub: ClubType
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Mark shot button
                Button(action: { showClubPicker = true }) {
                    HStack {
                        Image(systemName: "scope")
                        Text("Mark Shot")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Current hole shots
                if !roundManager.currentHoleShots.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hole \(roundManager.currentHole) Shots")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        ForEach(roundManager.currentHoleShots, id: \.id) { shot in
                            ShotRow(shot: shot)
                        }
                    }
                    .padding()
                    .background(Color("BackgroundSecondary"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Text("No shots recorded for this hole")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .padding()
                }
            }
            .padding()
        }
    }
}

struct ShotRow: View {
    let shot: Shot
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
            
            Text(shot.club ?? "Unknown")
                .font(.subheadline)
                .foregroundStyle(.white)
            
            Spacer()
            
            if let distance = shot.distanceToPin {
                Text("\(distance) yds")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Map Markers

struct FlagMarker: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "flag.fill")
                .font(.title3)
                .foregroundStyle(.red)
            
            Rectangle()
                .fill(.gray)
                .frame(width: 2, height: 12)
        }
    }
}

struct GreenEdgeMarker: View {
    let label: String
    
    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(4)
            .background(.green.opacity(0.8))
            .clipShape(Circle())
    }
}

struct ShotMarker: View {
    let shot: Shot
    
    var body: some View {
        Circle()
            .fill(Color.orange)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
    }
}

// MARK: - Settings Sheet

struct MapSettingsSheet: View {
    @Binding var mapStyle: MapDisplayStyle
    @Binding var showLayers: LayerVisibility
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Map Style") {
                    Picker("Style", selection: $mapStyle) {
                        Text("Satellite").tag(MapDisplayStyle.satellite)
                        Text("Hybrid").tag(MapDisplayStyle.hybrid)
                        Text("Standard").tag(MapDisplayStyle.standard)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Layers") {
                    Toggle("Fairway", isOn: $showLayers.fairway)
                    Toggle("Green", isOn: $showLayers.green)
                    Toggle("Bunkers", isOn: $showLayers.bunkers)
                    Toggle("Water", isOn: $showLayers.water)
                    Toggle("Trees", isOn: $showLayers.trees)
                    Toggle("Yardage Markers", isOn: $showLayers.yardageMarkers)
                }
            }
            .navigationTitle("Map Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct LayerPickerPopover: View {
    @Binding var showLayers: LayerVisibility
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Layers")
                .font(.headline)
            
            Toggle("Fairway", isOn: $showLayers.fairway)
            Toggle("Green", isOn: $showLayers.green)
            Toggle("Bunkers", isOn: $showLayers.bunkers)
            Toggle("Water", isOn: $showLayers.water)
            Toggle("Yardage Markers", isOn: $showLayers.yardageMarkers)
        }
        .padding()
        .frame(width: 200)
    }
}

// MARK: - Plays Like Components

struct AdjustmentPill: View {
    let icon: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundStyle(color)
    }
}

struct PlaysLikeDetailView: View {
    let gpsDistance: Int
    let windAdjustment: Int
    let slopeAdjustment: Int
    let tempAdjustment: Int
    let humidityAdjustment: Int
    let altitudeAdjustment: Int
    
    var totalAdjustment: Int {
        windAdjustment + slopeAdjustment + tempAdjustment + humidityAdjustment + altitudeAdjustment
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("\(gpsDistance)y")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))
                Text("GPS")
                    .font(.caption)
                    .foregroundStyle(.gray)
                
                Spacer()
                
                Text("\(gpsDistance + totalAdjustment)y")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("PLAYS")
                    .font(.caption)
                    .foregroundStyle(.green.opacity(0.7))
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Adjustment rows
            AdjustmentRow(icon: "wind", label: "Wind", value: windAdjustment, detail: "8 mph")
            AdjustmentRow(icon: "arrow.up.right", label: "Slope", value: slopeAdjustment, detail: "+6 ft")
            AdjustmentRow(icon: "thermometer.medium", label: "Temp", value: tempAdjustment, detail: "65°F")
            AdjustmentRow(icon: "humidity", label: "Humidity", value: humidityAdjustment, detail: "55%")
            AdjustmentRow(icon: "mountain.2", label: "Altitude", value: altitudeAdjustment, detail: "0 ft")
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Total
            HStack {
                Text("Total Adjustment")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
                Text(totalAdjustment >= 0 ? "+\(totalAdjustment)y" : "\(totalAdjustment)y")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(totalAdjustment > 0 ? .red : totalAdjustment < 0 ? .green : .white)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: 280)
    }
}

struct AdjustmentRow: View {
    let icon: String
    let label: String
    let value: Int
    let detail: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.gray)
                .frame(width: 20)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            
            Text(detail)
                .font(.caption)
                .foregroundStyle(.gray)
            
            Spacer()
            
            Text(formatAdjustment(value))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(adjustmentColor(value))
        }
    }
    
    private func formatAdjustment(_ value: Int) -> String {
        if value == 0 { return "0y" }
        return value > 0 ? "+\(value)y" : "\(value)y"
    }
    
    private func adjustmentColor(_ value: Int) -> Color {
        if value > 0 { return .red }
        if value < 0 { return .green }
        return .gray
    }
}
