import SwiftUI
import MapKit
import CoreLocation

/// Map-first course discovery view - shows full-screen map centered on user location
/// with nearby courses as markers
struct CoursesMapView: View {
    @EnvironmentObject var gpsManager: GPSManager
    @EnvironmentObject var roundManager: RoundManager
    @EnvironmentObject var authManager: AuthManager
    
    // Data state
    @State private var courses: [Course] = []
    @State private var isLoading = true
    @State private var isSyncing = false
    
    // Map state
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var mapStyleSelection: CourseMapStyle = .satellite
    @State private var selectedCourse: Course?
    @State private var showCourseDetail = false
    
    // UI state
    @State private var showSearchPanel = false
    @State private var showListView = false
    @State private var searchText = ""
    @State private var showSettings = false
    @State private var nearbyRadius: Double = 50 // miles
    
    private let bundleLoader = CourseBundleLoader.shared
    
    // Nearby courses based on user location
    private var nearbyCourses: [Course] {
        guard let userLocation = gpsManager.currentLocation else {
            return Array(courses.prefix(100)) // Show some courses if no location
        }
        
        let userCL = CLLocation(latitude: userLocation.coordinate.latitude, 
                                longitude: userLocation.coordinate.longitude)
        
        return courses
            .filter { course in
                guard let lat = course.latitude, let lon = course.longitude else { return false }
                let courseCL = CLLocation(latitude: lat, longitude: lon)
                let distanceMeters = userCL.distance(from: courseCL)
                let distanceMiles = distanceMeters / 1609.34
                return distanceMiles <= nearbyRadius
            }
            .sorted { course1, course2 in
                guard let lat1 = course1.latitude, let lon1 = course1.longitude,
                      let lat2 = course2.latitude, let lon2 = course2.longitude else { return false }
                let dist1 = userCL.distance(from: CLLocation(latitude: lat1, longitude: lon1))
                let dist2 = userCL.distance(from: CLLocation(latitude: lat2, longitude: lon2))
                return dist1 < dist2
            }
    }
    
    var body: some View {
        ZStack {
            // Full-screen map
            fullScreenMap
                .ignoresSafeArea()
            
            // Floating UI overlays
            VStack(spacing: 0) {
                // Top bar with search and controls
                topOverlay
                
                Spacer()
                
                // Selected course preview card (if course selected)
                if let course = selectedCourse {
                    coursePreviewCard(course)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Bottom quick actions
                if selectedCourse == nil {
                    bottomQuickActions
                }
            }
            
            // Map controls (right side)
            mapControls
        }
        .task {
            // Start location updates first
            gpsManager.startTracking()
            
            // Load courses
            await loadCourses()
            
            // Center on user location once we have it
            centerOnUserLocation()
        }
        .onAppear {
            // Ensure location updates are running
            gpsManager.startTracking()
        }
        .onChange(of: gpsManager.currentLocation) { _, newLocation in
            // Only auto-center if we haven't manually moved the map
            if cameraPosition == .automatic, let location = newLocation {
                withAnimation(.easeInOut(duration: 0.5)) {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
                    ))
                }
            }
        }
        .onChange(of: courses.count) { _, _ in
            // Trigger UI refresh when courses are loaded
            // This ensures "courses nearby" count updates
        }
        .sheet(isPresented: $showListView) {
            CoursesListSheet(
                courses: courses,
                searchText: $searchText,
                onSelectCourse: { course in
                    selectCourse(course)
                    showListView = false
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCourseDetail) {
            if let course = selectedCourse {
                NavigationStack {
                    CourseDetailView(course: course)
                }
                .presentationDetents([.large])
            }
        }
        .sheet(isPresented: $showSettings) {
            MapSettingsSheetForCourses(
                mapStyle: $mapStyleSelection,
                nearbyRadius: $nearbyRadius
            )
            .presentationDetents([.medium])
        }
    }
    
    // MARK: - Full Screen Map
    
    private var fullScreenMap: some View {
        Map(position: $cameraPosition, interactionModes: .all) {
            // User location
            UserAnnotation()
            
            // Course markers
            ForEach(nearbyCourses) { course in
                if let lat = course.latitude, let lon = course.longitude {
                    Annotation(course.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), anchor: .bottom) {
                        CourseMapMarker(
                            course: course,
                            isSelected: selectedCourse?.id == course.id,
                            hasHoleData: course.holeData?.isEmpty == false
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                selectedCourse = course
                            }
                        }
                    }
                }
            }
        }
        .mapStyle(mapStyleSelection.mapKitStyle)
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onTapGesture {
            // Deselect course when tapping on map
            if selectedCourse != nil {
                withAnimation(.spring(response: 0.3)) {
                    selectedCourse = nil
                }
            }
        }
    }
    
    // MARK: - Top Overlay
    
    private var topOverlay: some View {
        HStack(spacing: 12) {
            // Search button
            Button {
                showListView = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("Search courses...")
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
            .foregroundColor(.white)
            
            // Settings button
            Button {
                showSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Course Preview Card
    
    private func coursePreviewCard(_ course: Course) -> some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                // Drag handle
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 40, height: 5)
                
                Spacer()
                
                // Close button (X)
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedCourse = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        if let city = course.city {
                            Text(city)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        // Distance from user
                        if let distance = distanceFromUser(to: course) {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                Text(String(format: "%.1f mi", distance))
                                    .font(.caption)
                            }
                            .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                    
                    // Course stats
                    VStack(alignment: .trailing, spacing: 4) {
                        if let par = course.par {
                            HStack(spacing: 4) {
                                Text("Par")
                                    .foregroundColor(.gray)
                                Text("\(par)")
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                        }
                        
                        if let rating = course.courseRating {
                            HStack(spacing: 4) {
                                Text("Rating")
                                    .foregroundColor(.gray)
                                Text(String(format: "%.1f", rating))
                                    .fontWeight(.semibold)
                            }
                            .font(.caption)
                        }
                        
                        // Has hole data indicator
                        if course.holeData?.isEmpty == false {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("GPS Ready")
                                    .foregroundColor(.green)
                            }
                            .font(.caption)
                        }
                    }
                    .foregroundColor(.white)
                }
                
                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        roundManager.startRound(course: course)
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Round")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .cornerRadius(10)
                    }
                    
                    Button {
                        showCourseDetail = true
                    } label: {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("Details")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color("BackgroundTertiary"))
                        .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    // MARK: - Bottom Quick Actions
    
    private var bottomQuickActions: some View {
        HStack(spacing: 16) {
            // Nearby courses count
            VStack(alignment: .leading, spacing: 2) {
                Text("\(nearbyCourses.count)")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("courses nearby")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            
            Spacer()
            
            // View list button
            Button {
                showListView = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                    Text("List")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 16)
    }
    
    // MARK: - Map Controls (Right Side)
    
    private var mapControls: some View {
        VStack(spacing: 12) {
            Spacer()
            
            // Re-center on user location
            Button {
                centerOnUserLocation()
            } label: {
                Image(systemName: "location.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            // Map style toggle
            Button {
                withAnimation {
                    mapStyleSelection = mapStyleSelection == .satellite ? .standard : .satellite
                }
            } label: {
                Image(systemName: mapStyleSelection == .satellite ? "globe.americas.fill" : "map")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            // Zoom to fit all courses
            Button {
                zoomToFitNearbyCourses()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.trailing, 16)
        // Move controls higher when course preview card is shown to avoid overlap
        .padding(.bottom, selectedCourse != nil ? 280 : 120)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .animation(.spring(response: 0.3), value: selectedCourse != nil)
    }
    
    // MARK: - Helper Functions
    
    private func centerOnUserLocation() {
        // Request location update if we don't have one
        if gpsManager.currentLocation == nil {
            gpsManager.startTracking()
            // Set a timer to try again once location is available
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let location = gpsManager.currentLocation {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
                        ))
                    }
                }
            }
            return
        }
        
        if let location = gpsManager.currentLocation {
            withAnimation(.easeInOut(duration: 0.5)) {
                cameraPosition = .region(MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
                ))
            }
        }
    }
    
    private func selectCourse(_ course: Course) {
        // Always update selection with animation
        withAnimation(.spring(response: 0.3)) {
            selectedCourse = course
        }
        
        // Always zoom to course location - use a slight delay to ensure animation happens
        if let lat = course.latitude, let lon = course.longitude {
            // First set to a slightly different position to force update
            let targetRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
            
            withAnimation(.easeInOut(duration: 0.5)) {
                cameraPosition = .region(targetRegion)
            }
        }
    }
    
    private func zoomToFitNearbyCourses() {
        let coursesWithLocation = nearbyCourses.filter { $0.latitude != nil && $0.longitude != nil }
        guard !coursesWithLocation.isEmpty else { return }
        
        var minLat = coursesWithLocation.first!.latitude!
        var maxLat = minLat
        var minLon = coursesWithLocation.first!.longitude!
        var maxLon = minLon
        
        for course in coursesWithLocation {
            if let lat = course.latitude, let lon = course.longitude {
                minLat = min(minLat, lat)
                maxLat = max(maxLat, lat)
                minLon = min(minLon, lon)
                maxLon = max(maxLon, lon)
            }
        }
        
        // Include user location
        if let userLoc = gpsManager.currentLocation {
            minLat = min(minLat, userLoc.coordinate.latitude)
            maxLat = max(maxLat, userLoc.coordinate.latitude)
            minLon = min(minLon, userLoc.coordinate.longitude)
            maxLon = max(maxLon, userLoc.coordinate.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3,
            longitudeDelta: (maxLon - minLon) * 1.3
        )
        
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
    
    private func distanceFromUser(to course: Course) -> Double? {
        guard let userLocation = gpsManager.currentLocation,
              let lat = course.latitude,
              let lon = course.longitude else { return nil }
        
        let userCL = CLLocation(latitude: userLocation.coordinate.latitude, 
                                longitude: userLocation.coordinate.longitude)
        let courseCL = CLLocation(latitude: lat, longitude: lon)
        let distanceMeters = userCL.distance(from: courseCL)
        return distanceMeters / 1609.34 // Convert to miles
    }
    
    @MainActor
    private func loadCourses() async {
        isLoading = true
        
        // Load from bundle
        let bundledCourses = await bundleLoader.loadBundledCourses()
        
        if bundledCourses.isEmpty {
            if let cached = await bundleLoader.loadCachedCourses(), !cached.isEmpty {
                courses = cached
            }
        } else {
            courses = bundledCourses
        }
        
        isLoading = false
        
        // Sync updates in background if needed
        let needsSync = await bundleLoader.shouldSync()
        if needsSync {
            isSyncing = true
            // Background sync would happen here if we had auth headers
            // For now just use cached data
            if let updated = await bundleLoader.loadCachedCourses() {
                courses = updated
            }
            isSyncing = false
        }
    }
}

// MARK: - Course Map Marker

struct CourseMapMarker: View {
    let course: Course
    let isSelected: Bool
    let hasHoleData: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                // Outer glow for selected
                if isSelected {
                    Circle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 50, height: 50)
                }
                
                // Main marker
                Circle()
                    .fill(hasHoleData ? Color.green : Color.orange)
                    .frame(width: isSelected ? 36 : 28, height: isSelected ? 36 : 28)
                    .overlay(
                        Image(systemName: "flag.fill")
                            .font(.system(size: isSelected ? 16 : 12))
                            .foregroundColor(.white)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
            }
            
            // Course name label (only when selected)
            if isSelected {
                Text(course.name)
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
                    .lineLimit(1)
            }
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Courses List Sheet

struct CoursesListSheet: View {
    let courses: [Course]
    @Binding var searchText: String
    let onSelectCourse: (Course) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var filteredCourses: [Course] {
        if searchText.isEmpty {
            return courses
        }
        return courses.filter { 
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.city?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCourses.prefix(200)) { course in
                    Button {
                        onSelectCourse(course)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(course.name)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                if let city = course.city {
                                    Text(city)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            if course.holeData?.isEmpty == false {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .listRowBackground(Color("BackgroundSecondary"))
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search by name or city")
            .navigationTitle("Find Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .background(Color("Background"))
    }
}

// MARK: - Course Map Style Enum

enum CourseMapStyle: String, CaseIterable, Hashable {
    case satellite
    case standard
    case hybrid
    
    var mapKitStyle: MapStyle {
        switch self {
        case .satellite: return .imagery
        case .standard: return .standard
        case .hybrid: return .hybrid
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Map Settings Sheet for Courses

struct MapSettingsSheetForCourses: View {
    @Binding var mapStyle: CourseMapStyle
    @Binding var nearbyRadius: Double
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Map Style") {
                    Picker("Style", selection: $mapStyle) {
                        Text("Satellite").tag(CourseMapStyle.satellite)
                        Text("Standard").tag(CourseMapStyle.standard)
                        Text("Hybrid").tag(CourseMapStyle.hybrid)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Search Radius") {
                    Picker("Nearby Radius", selection: $nearbyRadius) {
                        Text("10 miles").tag(10.0)
                        Text("25 miles").tag(25.0)
                        Text("50 miles").tag(50.0)
                        Text("100 miles").tag(100.0)
                        Text("250 miles").tag(250.0)
                    }
                }
            }
            .navigationTitle("Map Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CoursesMapView()
        .environmentObject(GPSManager())
        .environmentObject(RoundManager())
        .environmentObject(AuthManager())
        .preferredColorScheme(.dark)
}
