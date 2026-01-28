import SwiftUI
import MapKit

struct CoursesView: View {
    @EnvironmentObject var gpsManager: GPSManager
    @State private var courses: [Course] = []
    @State private var isLoading = true
    @State private var isSyncing = false
    @State private var lastSyncDate: Date? = nil
    @State private var searchText = ""
    @State private var showNearby = false
    @State private var selectedCountry: String? = nil
    @State private var showCountryPicker = false
    @State private var showLocationAlert = false
    @State private var showNearbyRadiusPicker = false
    @AppStorage("nearbyRadiusMiles") private var nearbyRadiusMiles = 50.0
    
    private let bundleLoader = CourseBundleLoader.shared
    
    // Map country names to ISO codes (database uses codes like "US", "GB", "IE")
    private func getCountryCode(for countryName: String) -> [String] {
        let mapping: [String: [String]] = [
            "United States": ["US", "USA", "United States"],
            "United Kingdom": ["GB", "UK", "United Kingdom", "Great Britain", "England", "Scotland", "Wales", "Northern Ireland"],
            "Ireland": ["IE", "Ireland", "Republic of Ireland", "Eire"],
            "Canada": ["CA", "Canada"],
            "Australia": ["AU", "Australia"],
            "Germany": ["DE", "Germany"],
            "France": ["FR", "France"],
            "Italy": ["IT", "Italy"],
            "Spain": ["ES", "Spain"],
            "Netherlands": ["NL", "Netherlands"],
            "Sweden": ["SE", "Sweden"],
            "Norway": ["NO", "Norway"],
            "Denmark": ["DK", "Denmark"],
            "Finland": ["FI", "Finland"],
            "Japan": ["JP", "Japan"],
            "South Korea": ["KR", "South Korea", "Korea"],
            "China": ["CN", "China"],
            "New Zealand": ["NZ", "New Zealand"],
            "Mexico": ["MX", "Mexico"],
            "Brazil": ["BR", "Brazil"],
            "Argentina": ["AR", "Argentina"],
            "South Africa": ["ZA", "South Africa"],
            "India": ["IN", "India"],
            "Thailand": ["TH", "Thailand"],
            "Singapore": ["SG", "Singapore"],
            "Malaysia": ["MY", "Malaysia"],
            "Indonesia": ["ID", "Indonesia"],
            "Philippines": ["PH", "Philippines"],
            "Portugal": ["PT", "Portugal"],
            "Greece": ["GR", "Greece"],
            "Turkey": ["TR", "Turkey"],
            "Poland": ["PL", "Poland"],
            "Czech Republic": ["CZ", "Czech Republic"],
            "Switzerland": ["CH", "Switzerland"],
            "Austria": ["AT", "Austria"],
            "Belgium": ["BE", "Belgium"],
        ]
        
        return mapping[countryName] ?? [countryName]
    }
    
    var filteredCourses: [Course] {
        var filtered = courses
        
        // Filter out courses with bad names (numbers, quotes, too short, empty)
        filtered = filtered.filter { course in
            let name = course.name.trimmingCharacters(in: .whitespaces)
            
            // Filter out empty names
            if name.isEmpty {
                return false
            }
            
            // Filter out names that are just numbers
            if name.allSatisfy({ $0.isNumber || $0.isWhitespace }) {
                return false
            }
            
            // Filter out names that are too short (less than 3 characters, excluding common abbreviations)
            if name.count < 3 && !["GC", "CC", "GC"].contains(name.uppercased()) {
                return false
            }
            
            // Filter out names that are mostly quotes or special characters
            let alphanumericCount = name.filter { $0.isLetter || $0.isNumber }.count
            if Double(alphanumericCount) / Double(name.count) < 0.5 {
                return false
            }
            
            return true
        }
        
        // Filter by country if selected
        if let country = selectedCountry {
            let countryCodes = getCountryCode(for: country)
            filtered = filtered.filter { course in
                guard let courseCountry = course.country else { 
                    // If no country, only include if "Unknown" is explicitly selected
                    return country == "Unknown" || country.localizedCaseInsensitiveContains("Unknown")
                }
                let normalizedCourse = courseCountry.trimmingCharacters(in: .whitespaces)
                
                // Special handling for "Unknown" country
                if normalizedCourse.localizedCaseInsensitiveCompare("Unknown") == .orderedSame {
                    return country == "Unknown" || country.localizedCaseInsensitiveContains("Unknown")
                }
                
                // Check if course country matches any of the country codes/names
                return countryCodes.contains { code in
                    normalizedCourse.localizedCaseInsensitiveCompare(code) == .orderedSame
                }
            }
        }
        // If no country selected, show ALL courses (including "Unknown")
        
        // Filter by search text if provided
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading courses...")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if courses.isEmpty {
                    VStack(spacing: 16) {
                        EmptyStateCard(
                            icon: "map",
                            title: "No courses loaded",
                            subtitle: "Bundle file may not be included. Check Xcode target membership for courses-bundle.json"
                        )
                        Text("Debug: courses.count = \(courses.count)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                } else if filteredCourses.isEmpty {
                    VStack(spacing: 16) {
                        EmptyStateCard(
                            icon: "map",
                            title: "No courses found",
                            subtitle: selectedCountry != nil 
                                ? "No courses found in \(selectedCountry!). Total courses: \(courses.count). Try selecting a different country or search for a course."
                                : "Search for a course or check back later"
                        )
                        Text("Debug: courses.count = \(courses.count), filteredCourses.count = \(filteredCourses.count)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                } else {
                    List {
                        if showNearby {
                            Text("Showing courses within \(Int(nearbyRadiusMiles)) miles of you")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .listRowBackground(Color("Background"))
                        }
                        ForEach(filteredCourses) { course in
                            NavigationLink(destination: CourseDetailView(course: course)) {
                                CourseRow(course: course)
                            }
                            .listRowBackground(Color("BackgroundSecondary"))
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Search courses")
                }
            }
            .background(Color("Background"))
            .navigationTitle("Courses")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        NavigationLink(destination: ContributeCourseView()) {
                            Label("Contribute Course", systemImage: "plus.circle")
                        }
                        Button {
                            showCountryPicker = true
                        } label: {
                            Label(selectedCountry ?? "All Countries", systemImage: "globe")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            // Force sync by clearing last sync date
                            await bundleLoader.setLastSyncDate(Date.distantPast)
                            await syncUpdatesIfNeeded()
                        }
                    } label: {
                        if isSyncing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if let syncDate = lastSyncDate {
                        Menu {
                            Text("Last synced: \(syncDate, style: .relative)")
                        } label: {
                            Image(systemName: "arrow.clockwise.circle")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Button {
                        if gpsManager.currentLocation == nil {
                            showLocationAlert = true
                        } else {
                            showNearbyRadiusPicker = true
                        }
                    } label: {
                        Image(systemName: showNearby ? "location.fill" : "location")
                            .foregroundColor(showNearby ? .green : .gray)
                    }
                }
            }
            .sheet(isPresented: $showCountryPicker) {
                CountryPickerView(selectedCountry: $selectedCountry) {
                    // When country changes, filtering happens in filteredCourses computed property
                    // No need to reload from server - we filter the bundled courses locally
                    // Only reload if "All Countries" is selected and we want fresh server data
                    if selectedCountry == nil && courses.isEmpty {
                        Task { await loadCourses() }
                    }
                }
            }
        }
        .task {
            await loadCoursesWithBundle()
            // Always try to sync on load to get latest updates (especially hole_data)
            await syncUpdatesIfNeeded()
            // Reload courses after sync to get merged data
            await loadCoursesWithBundle()
        }
        .refreshable {
            // Force sync on pull-to-refresh by clearing last sync date
            await bundleLoader.setLastSyncDate(Date.distantPast)
            await syncUpdatesIfNeeded()
            // Reload from bundle/cache after sync
            await loadCoursesWithBundle()
        }
        .alert("Location Unavailable", isPresented: $showLocationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable location access to show nearby courses within \(Int(nearbyRadiusMiles)) miles.")
        }
        .confirmationDialog("Nearby Search Radius", isPresented: $showNearbyRadiusPicker) {
            Button("10 miles") { enableNearby(radius: 10) }
            Button("25 miles") { enableNearby(radius: 25) }
            Button("50 miles") { enableNearby(radius: 50) }
            Button("100 miles") { enableNearby(radius: 100) }
            if showNearby {
                Button("Show all courses", role: .destructive) {
                    disableNearby()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose how far to search from your current location.")
        }
    }
    
    private func getCountryFromLocale() -> String? {
        if let countryCode = Locale.current.region?.identifier {
            // Map country code to country name (simplified - you might want a full mapping)
            let countryNames: [String: String] = [
                "US": "United States",
                "GB": "United Kingdom",
                "CA": "Canada",
                "AU": "Australia",
                "DE": "Germany",
                "FR": "France",
                "IT": "Italy",
                "ES": "Spain",
                "NL": "Netherlands",
                "SE": "Sweden",
                "NO": "Norway",
                "DK": "Denmark",
                "FI": "Finland",
                "IE": "Ireland",
                "JP": "Japan",
                "KR": "South Korea",
                "CN": "China",
                "NZ": "New Zealand",
                "MX": "Mexico",
                "BR": "Brazil",
                "AR": "Argentina",
                "ZA": "South Africa",
            ]
            return countryNames[countryCode]
        }
        return nil
    }
    
    /// Load courses from bundle first, then sync updates
    @MainActor
    private func loadCoursesWithBundle() async {
        isLoading = true
        print("🔄 Starting to load courses from bundle...")
        
        // Load from bundle immediately (fast, offline-capable)
        let bundledCourses = await bundleLoader.loadBundledCourses()
        
        if bundledCourses.isEmpty {
            print("⚠️ WARNING: Bundle returned 0 courses!")
            print("⚠️ This might mean:")
            print("   1. Bundle file is not included in Xcode target")
            print("   2. Bundle file path is incorrect")
            print("   3. JSON decoding failed")
            // Fall back to cache if bundle is empty
            if let cached = await bundleLoader.loadCachedCourses(), !cached.isEmpty {
                print("💾 Falling back to cached courses: \(cached.count)")
                courses = cached
            }
        } else {
            print("✅ Bundle loaded \(bundledCourses.count) courses")
            courses = bundledCourses
            
            // Check for cached courses (merged with previous updates)
            // Use cache if it exists (it may have updated courses with hole_data)
            if let cached = await bundleLoader.loadCachedCourses(), !cached.isEmpty {
                print("💾 Found cache with \(cached.count) courses (bundle has \(bundledCourses.count))")
                // Always use cache if it exists - it may have updated courses with hole_data
                // The merge function will ensure we have all courses
                courses = cached
            } else {
                print("💾 No cached courses, using bundle directly")
            }
        }
        
        // Log country-specific counts for debugging
        let unknownCount = courses.filter { 
            $0.country == nil || 
            $0.country?.localizedCaseInsensitiveCompare("Unknown") == .orderedSame 
        }.count
        let knownCount = courses.count - unknownCount
        
        print("📊 Total courses loaded: \(courses.count)")
        print("   - With known country: \(knownCount)")
        print("   - With 'Unknown' country: \(unknownCount)")
        
        if let country = selectedCountry {
            print("🌍 Filtering for country: \(country)")
            if country.localizedCaseInsensitiveCompare("Unknown") == .orderedSame {
                print("🌍 Showing only courses with 'Unknown' country")
            } else {
                let countryCodes = getCountryCode(for: country)
                print("🌍 Country codes to match: \(countryCodes.joined(separator: ", "))")
            }
            print("🌍 Found \(filteredCourses.count) courses matching country filter")
        } else {
            print("🌍 No country filter - showing all \(courses.count) courses (including \(unknownCount) with 'Unknown' country)")
        }
        
        print("📊 Final courses array count: \(courses.count)")
        print("📊 filteredCourses count: \(filteredCourses.count)")
        
        isLoading = false
        
        // Don't replace bundled courses with server data - we want to keep all 23k+ courses
        // Sync is triggered from the view lifecycle to avoid overlapping requests
    }
    
    /// Load courses from server (only for nearby search or when explicitly refreshing)
    @MainActor
    private func loadCourses() async {
        // For nearby search, fetch from server
        if showNearby, let location = gpsManager.currentLocation {
            do {
                let serverCourses = try await DataService.shared.fetchNearbyCourses(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    radiusMiles: nearbyRadiusMiles
                )
                courses = serverCourses
                print("📍 Loaded \(serverCourses.count) nearby courses from server")
            } catch {
                print("Error loading nearby courses: \(error)")
                // Keep using bundled/cached data
            }
            return
        }
        
        // For regular search, we use bundled courses and filter locally
        // Don't replace bundled courses with server data - we want all 23k+ courses from bundle
        print("ℹ️ Using bundled courses for search/filter (not fetching from server)")
    }

    @MainActor
    private func enableNearby(radius: Double) {
        nearbyRadiusMiles = radius
        showNearby = true
        Task { await loadCourses() }
    }

    @MainActor
    private func disableNearby() {
        showNearby = false
        Task { await loadCoursesWithBundle() }
    }
    
    /// Sync course updates in the background
    @MainActor
    private func syncUpdatesIfNeeded() async {
        if isSyncing {
            print("⏭️ Sync already in progress, skipping duplicate request")
            return
        }
        // Always try to sync (we'll check date inside, but allow force sync)
        let shouldSync = await bundleLoader.shouldSync()
        if !shouldSync {
            print("⏭️ Sync not needed yet (last sync was recent), but checking for updates anyway...")
        }
        
        isSyncing = true
        
        do {
            // Always check for courses updated since the earliest of bundle date or last sync
            // This ensures we don't skip hole_data updates added after the bundle was built
            let bundleDateFormatter = ISO8601DateFormatter()
            bundleDateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
            let bundleDate = bundleDateFormatter.date(from: "2026-01-18T23:02:35.423Z") ?? Date.distantPast
            let lastSync = await bundleLoader.getLastSyncDate() ?? Date.distantPast
            let syncDate = min(bundleDate, lastSync)
            
            print("🔍 Checking for courses updated since: \(syncDate) (bundle: \(bundleDate), lastSync: \(lastSync))")
            let authHeaders: [String: String] = [:] // Add auth headers if needed
            
            // Fetch only courses updated since last sync (or bundle date)
            let updatedCourses = try await bundleLoader.fetchUpdatedCourses(
                since: syncDate,
                authHeaders: authHeaders
            )
            
            if !updatedCourses.isEmpty {
                print("🔄 Syncing \(updatedCourses.count) updated courses")
                
                // Debug: Check which courses have hole_data
                for course in updatedCourses.prefix(5) {
                    if let holeData = course.holeData, !holeData.isEmpty {
                        print("   ✅ '\(course.name)' has \(holeData.count) holes of data")
                    } else {
                        print("   ❌ '\(course.name)' has no hole_data")
                    }
                }
                
                // Merge with current courses (which may already include cached merged data)
                let current = courses.isEmpty ? await bundleLoader.loadBundledCourses() : courses
                let merged = await bundleLoader.mergeCourses(
                    bundled: current,
                    updated: updatedCourses
                )
                
                // Update cache with merged courses
                await bundleLoader.cacheCourses(merged)
                
                // Only update UI if user isn't actively searching
                if searchText.isEmpty {
                    courses = merged
                    print("✅ Updated courses list with merged data (\(merged.count) total courses)")
                } else {
                    print("ℹ️ Skipped UI update during active search; cache updated")
                }
            } else {
                print("ℹ️ No updated courses found")
            }
            
            // Update last sync date
            await bundleLoader.setLastSyncDate(Date())
            lastSyncDate = Date()
            
        } catch {
            print("⚠️ Error syncing courses: \(error)")
        }
        
        isSyncing = false
    }
}

struct CourseRow: View {
    let course: Course
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(course.name)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if let rating = course.avgRating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", rating))
                            .foregroundColor(.white)
                    }
                    .font(.caption)
                }
            }
            
            HStack {
                // Location with Maps button if coordinates available
                if let lat = course.latitude, let lon = course.longitude {
                    Button {
                        openInMaps(latitude: lat, longitude: lon, name: course.name)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.blue)
                            Text(formatLocation())
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                } else {
                    Label(formatLocation(), systemImage: "mappin")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if let par = course.par {
                    Text("Par \(par)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatLocation() -> String {
        var parts: [String] = []
        
        if let city = course.city, !city.isEmpty {
            parts.append(city)
        }
        if let state = course.state, !state.isEmpty {
            parts.append(state)
        }
        if let country = course.country, !country.isEmpty, country.localizedCaseInsensitiveCompare("Unknown") != .orderedSame {
            parts.append(country)
        }
        
        if parts.isEmpty {
            return "Location Unknown"
        }
        
        // Filter out "Unknown" from the parts
        let filtered = parts.filter { $0.localizedCaseInsensitiveCompare("Unknown") != .orderedSame }
        
        if filtered.isEmpty {
            return "Location Unknown"
        }
        
        return filtered.joined(separator: ", ")
    }
    
    private func openInMaps(latitude: Double, longitude: Double, name: String) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

struct CourseDetailView: View {
    @State var course: Course
    @EnvironmentObject var roundManager: RoundManager
    @State private var weather: Weather?
    @State private var isLoadingWeather = false
    @State private var isFetchingHoleData = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text(course.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    // Location with Maps button
                    HStack(spacing: 8) {
                        if let lat = course.latitude, let lon = course.longitude {
                            Button {
                                openInMaps(latitude: lat, longitude: lon, name: course.name)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(.blue)
                                    Text(formatLocation(course: course))
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                        } else {
                            Label(formatLocation(course: course), systemImage: "mappin")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Rating
                    if let rating = course.avgRating, let count = course.reviewCount {
                        HStack {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: Double(star) <= rating ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                            }
                            Text("(\(count))")
                                .foregroundColor(.gray)
                        }
                        .font(.caption)
                    }
                }
                .padding()
                
                // Course Info
                HStack(spacing: 20) {
                    if let par = course.par {
                        InfoBox(title: "Par", value: "\(par)")
                    }
                    if let rating = course.courseRating {
                        InfoBox(title: "Rating", value: String(format: "%.1f", rating))
                    }
                    if let slope = course.slopeRating {
                        InfoBox(title: "Slope", value: "\(slope)")
                    }
                }
                .padding(.horizontal)
                
                // Weather
                if let weather = weather {
                    WeatherCard(weather: weather)
                        .padding(.horizontal)
                } else if isLoadingWeather {
                    ProgressView()
                        .padding()
                }
                
                // Course Visualization
                VStack(alignment: .leading, spacing: 12) {
                    Text("Course Layout")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    if let holeData = course.holeData, !holeData.isEmpty {
                        // Toggle between Map and Schematic views
                        CourseVisualizationToggleView(
                            holeData: holeData,
                            courseCoordinate: course.coordinate,
                            courseName: course.name
                        )
                        .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    } else if isFetchingHoleData {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Loading hole-by-hole layout...")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(Color("BackgroundSecondary"))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else if let coordinate = course.coordinate {
                        // No hole data but we have course coordinates - show satellite map
                        CourseVisualizationToggleView(
                            holeData: [],
                            courseCoordinate: coordinate,
                            courseName: course.name
                        )
                        .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    } else {
                        // No coordinates available - show unavailable message
                        VStack(spacing: 12) {
                            Image(systemName: "map")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("Location Not Available")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("This course doesn't have location coordinates.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(Color("BackgroundSecondary"))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button {
                        roundManager.startRound(course: course)
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Round at This Course")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    
                    NavigationLink(destination: ConfirmCourseView(course: course)) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Confirm Course Data")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    NavigationLink(destination: CourseDiscussionsView(course: course)) {
                        HStack {
                            Image(systemName: "message")
                            Text("Discussions")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color("Background"))
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadWeather()
            await fetchHoleDataIfNeeded()
        }
    }
    
    private func fetchHoleDataIfNeeded() async {
        // Skip if we already have data
        if let hd = course.holeData, !hd.isEmpty {
            return
        }
        
        isFetchingHoleData = true
        
        do {
            if let fetchedHoleData = try await CourseBundleLoader.shared.fetchHoleData(for: course.id) {
                // Update local state
                let updatedCourse = Course(
                    id: course.id,
                    name: course.name,
                    city: course.city,
                    state: course.state,
                    country: course.country,
                    address: course.address,
                    phone: course.phone,
                    website: course.website,
                    courseRating: course.courseRating,
                    slopeRating: course.slopeRating,
                    par: course.par,
                    holes: course.holes,
                    latitude: course.latitude,
                    longitude: course.longitude,
                    avgRating: course.avgRating,
                    reviewCount: course.reviewCount,
                    holeData: fetchedHoleData,
                    updatedAt: course.updatedAt,
                    createdAt: course.createdAt
                )
                self.course = updatedCourse
                
                // Update cache
                await CourseBundleLoader.shared.updateCourseHoleData(courseId: course.id, holeData: fetchedHoleData)
                print("✅ On-demand hole_data loaded for \(course.name)")
            }
        } catch {
            print("❌ Error fetching on-demand hole_data: \(error)")
        }
        
        isFetchingHoleData = false
    }
    
    private func formatLocation(course: Course) -> String {
        var parts: [String] = []
        
        if let city = course.city, !city.isEmpty {
            parts.append(city)
        }
        if let state = course.state, !state.isEmpty {
            parts.append(state)
        }
        if let country = course.country, !country.isEmpty, country.localizedCaseInsensitiveCompare("Unknown") != .orderedSame {
            parts.append(country)
        }
        
        if parts.isEmpty {
            return "Location Unknown"
        }
        
        // Filter out "Unknown" from the parts
        let filtered = parts.filter { $0.localizedCaseInsensitiveCompare("Unknown") != .orderedSame }
        
        if filtered.isEmpty {
            return "Location Unknown"
        }
        
        return filtered.joined(separator: ", ")
    }
    
    private func openInMaps(latitude: Double, longitude: Double, name: String) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
    
    private func loadWeather() async {
        guard let lat = course.latitude, let lon = course.longitude else { return }
        isLoadingWeather = true
        
        do {
            weather = try await DataService.shared.fetchWeather(latitude: lat, longitude: lon)
        } catch {
            print("Error loading weather: \(error)")
        }
        
        isLoadingWeather = false
    }
}

struct InfoBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
    }
}

struct WeatherCard: View {
    let weather: Weather
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current Weather")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(weather.icon)
                    .font(.title)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("\(weather.temperature)°F")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(weather.conditions)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Label("\(weather.windSpeed) mph \(weather.windDirection)", systemImage: "wind")
                    Label("\(weather.humidity)%", systemImage: "humidity")
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            
            Text(weather.isGoodForGolf ? "☀️ Great day for golf!" : "⚠️ Check conditions")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(weather.isGoodForGolf ? .green : .orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(weather.isGoodForGolf ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                .cornerRadius(8)
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
    }
}

#Preview {
    CoursesView()
        .environmentObject(GPSManager())
        .environmentObject(RoundManager())
        .preferredColorScheme(.dark)
}
