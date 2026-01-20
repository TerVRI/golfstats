import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

struct ContributeCourseView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var gpsManager: GPSManager
    @Environment(\.dismiss) var dismiss
    
    @State private var courseName = ""
    @State private var city = ""
    @State private var state = ""
    @State private var country = "USA"
    @State private var address = ""
    @State private var phone = ""
    @State private var website = ""
    @State private var courseRating = ""
    @State private var slopeRating = ""
    @State private var par = "72"
    @State private var holes = "18"
    
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var useCurrentLocation = true
    
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoUrls: [String] = []
    @State private var isUploadingPhotos = false
    
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    @State private var showOSMSearch = false
    @State private var osmCourses: [OSMCourse] = []
    @State private var isSearchingOSM = false
    @State private var osmError: String?
    
    @State private var showHoleDataEntry = false
    @State private var holeDataEntries: [HoleDataEntry] = []
    
    var body: some View {
        NavigationStack {
            Form {
                // OSM Auto-fill Section
                Section {
                    Button {
                        showOSMSearch = true
                    } label: {
                        HStack {
                            Image(systemName: "map.fill")
                            Text("Import from OpenStreetMap")
                        }
                        .foregroundColor(.blue)
                    }
                    
                } header: {
                    Text("Quick Import")
                }
                
                Section("Basic Information") {
                    TextField("Course Name *", text: $courseName)
                    TextField("City", text: $city)
                    TextField("State", text: $state)
                    TextField("Country", text: $country)
                    TextField("Address", text: $address)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Website", text: $website)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
                
                Section("Course Details") {
                    TextField("Course Rating", text: $courseRating)
                        .keyboardType(.decimalPad)
                    TextField("Slope Rating", text: $slopeRating)
                        .keyboardType(.numberPad)
                    TextField("Par", text: $par)
                        .keyboardType(.numberPad)
                    TextField("Number of Holes", text: $holes)
                        .keyboardType(.numberPad)
                }
                
                Section("Location (GPS)") {
                    Toggle("Use Current Location", isOn: $useCurrentLocation)
                    
                    if useCurrentLocation {
                        if let location = gpsManager.currentLocation {
                            Text("Lat: \(location.coordinate.latitude, specifier: "%.6f")")
                            Text("Lon: \(location.coordinate.longitude, specifier: "%.6f")")
                        } else {
                            HStack {
                                ProgressView()
                                Text("Getting location...")
                            }
                        }
                    } else {
                        TextField("Latitude", text: $latitude)
                            .keyboardType(.decimalPad)
                        TextField("Longitude", text: $longitude)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section("Hole Data (Optional)") {
                    Button {
                        showHoleDataEntry = true
                    } label: {
                        HStack {
                            Image(systemName: "list.number")
                            Text("Add Hole-by-Hole Data")
                            Spacer()
                            if !holeDataEntries.isEmpty {
                                Text("\(holeDataEntries.count) holes")
                                    .foregroundColor(.gray)
                            }
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if !holeDataEntries.isEmpty {
                        Text("Hole data includes: par, yardages, green locations, and tee box positions")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Section("Photos (Optional)") {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 10,
                        matching: .images
                    ) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Select Photos")
                        }
                    }
                    .onChange(of: selectedPhotos) { oldValue, newValue in
                        Task {
                            await uploadPhotos()
                        }
                    }
                    
                    if isUploadingPhotos {
                        ProgressView("Uploading photos...")
                    }
                    
                    if !photoUrls.isEmpty {
                        Text("\(photoUrls.count) photo(s) uploaded")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Contribute Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        Task {
                            await submitContribution()
                        }
                    }
                    .disabled(isSubmitting || courseName.isEmpty)
                }
            }
            .task {
                if useCurrentLocation {
                    await requestLocation()
                }
            }
            .sheet(isPresented: $showOSMSearch) {
                OSMSearchSheet(
                    latitude: useCurrentLocation ? gpsManager.currentLocation?.coordinate.latitude : Double(latitude),
                    longitude: useCurrentLocation ? gpsManager.currentLocation?.coordinate.longitude : Double(longitude),
                    courses: $osmCourses,
                    isSearching: $isSearchingOSM,
                    error: $osmError,
                    onSelectCourse: { course in
                        applyOSMCourse(course)
                    }
                )
            }
            .sheet(isPresented: $showHoleDataEntry) {
                HoleDataEntryView(holeDataEntries: $holeDataEntries, gpsManager: gpsManager)
            }
            .alert("Contribution Submitted", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for contributing! Your course submission is pending review.")
            }
        }
    }
    
    private func applyOSMCourse(_ osmCourse: OSMCourse) {
        courseName = osmCourse.name
        city = osmCourse.city ?? ""
        state = osmCourse.state ?? ""
        country = osmCourse.country ?? "USA"
        address = osmCourse.address
        phone = osmCourse.phone ?? ""
        website = osmCourse.website ?? ""
        latitude = String(osmCourse.latitude)
        longitude = String(osmCourse.longitude)
        useCurrentLocation = false
    }
    
    private func requestLocation() async {
        gpsManager.requestAuthorization()
        // Location will update via GPSManager
    }
    
    private func uploadPhotos() async {
        guard !selectedPhotos.isEmpty else { return }
        
        isUploadingPhotos = true
        photoUrls = []
        errorMessage = nil
        
        guard authManager.currentUser != nil else {
            errorMessage = "Please sign in to upload photos"
            isUploadingPhotos = false
            return
        }
        
        var uploadedUrls: [String] = []
        
        for photoItem in selectedPhotos {
            do {
                // Load image from PhotosPickerItem as Data
                guard let imageData = try await photoItem.loadTransferable(type: Data.self) else {
                    errorMessage = "Failed to load photo data"
                    continue
                }
                
                    // Validate file size (5 MB max)
                    let maxSize = 5 * 1024 * 1024 // 5 MB
                    guard imageData.count <= maxSize else {
                        errorMessage = "Photo size must be less than 5 MB"
                        continue
                    }
                    
                    // Generate unique filename
                    let fileExt = photoItem.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                    let timestamp = Int(Date().timeIntervalSince1970 * 1000)
                    let randomString = String.randomString(length: 7)
                    let fileName = "\(timestamp)-\(randomString).\(fileExt)"
                    
                    // Upload to Supabase Storage
                    let publicUrl = try await DataService.shared.uploadPhoto(
                        data: imageData,
                        fileName: fileName,
                        authHeaders: authManager.authHeaders
                    )
                    
                    uploadedUrls.append(publicUrl)
            } catch {
                errorMessage = "Failed to upload photo: \(error.localizedDescription)"
            }
        }
        
        photoUrls = uploadedUrls
        isUploadingPhotos = false
    }
    
    private func submitContribution() async {
        guard let user = authManager.currentUser else {
            errorMessage = "Please sign in to contribute courses"
            return
        }
        
        guard !courseName.isEmpty else {
            errorMessage = "Course name is required"
            return
        }
        
        let lat: Double
        let lon: Double
        
        if useCurrentLocation, let location = gpsManager.currentLocation {
            lat = location.coordinate.latitude
            lon = location.coordinate.longitude
        } else {
            guard let latValue = Double(latitude), let lonValue = Double(longitude) else {
                errorMessage = "Valid GPS coordinates are required"
                return
            }
            lat = latValue
            lon = lonValue
        }
        
        isSubmitting = true
        errorMessage = nil
        
        do {
            // Convert hole data entries to JSON format
            let holeDataJson: [[String: Any]]? = holeDataEntries.isEmpty ? nil : holeDataEntries.map { entry in
                var holeData: [String: Any] = [
                    "hole_number": entry.holeNumber,
                    "par": entry.par,
                    "yardages": ["total": entry.yardage]
                ]
                
                // Add green center if available
                if let centerLat = Double(entry.greenCenterLat), let centerLon = Double(entry.greenCenterLon) {
                    holeData["green_center"] = ["lat": centerLat, "lon": centerLon]
                }
                
                // Add green front if available
                if let frontLat = Double(entry.greenFrontLat), let frontLon = Double(entry.greenFrontLon) {
                    holeData["green_front"] = ["lat": frontLat, "lon": frontLon]
                }
                
                // Add green back if available
                if let backLat = Double(entry.greenBackLat), let backLon = Double(entry.greenBackLon) {
                    holeData["green_back"] = ["lat": backLat, "lon": backLon]
                }
                
                // Add tee box if available
                if let teeLat = Double(entry.teeBoxLat), let teeLon = Double(entry.teeBoxLon) {
                    holeData["tee_box"] = ["lat": teeLat, "lon": teeLon]
                }
                
                return holeData
            }
            
            try await DataService.shared.contributeCourse(
                userId: user.id,
                authHeaders: authManager.authHeaders,
                name: courseName,
                city: city.isEmpty ? nil : city,
                state: state.isEmpty ? nil : state,
                country: country.isEmpty ? "USA" : country,
                address: address.isEmpty ? nil : address,
                phone: phone.isEmpty ? nil : phone,
                website: website.isEmpty ? nil : website,
                courseRating: Double(courseRating),
                slopeRating: Int(slopeRating),
                par: Int(par),
                holes: Int(holes) ?? 18,
                latitude: lat,
                longitude: lon,
                photoUrls: photoUrls,
                holeData: holeDataJson
            )
            
            showSuccess = true
        } catch {
            errorMessage = "Failed to submit contribution: \(error.localizedDescription)"
        }
        
        isSubmitting = false
    }
}

// MARK: - Hole Data Entry

struct HoleDataEntry: Identifiable {
    let id = UUID()
    var holeNumber: Int
    var par: Int = 4
    var yardage: Int = 0
    var greenCenterLat: String = ""
    var greenCenterLon: String = ""
    var greenFrontLat: String = ""
    var greenFrontLon: String = ""
    var greenBackLat: String = ""
    var greenBackLon: String = ""
    var teeBoxLat: String = ""
    var teeBoxLon: String = ""
}

struct HoleDataEntryView: View {
    @Binding var holeDataEntries: [HoleDataEntry]
    @Environment(\.dismiss) var dismiss
    let gpsManager: GPSManager
    
    @State private var numberOfHoles = 18
    @State private var selectedHole: Int = 1
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Number of Holes", selection: $numberOfHoles) {
                        Text("9").tag(9)
                        Text("18").tag(18)
                    }
                    .onChange(of: numberOfHoles) { _, newValue in
                        initializeHoles(count: newValue)
                    }
                } header: {
                    Text("Course Layout")
                }
                
                Section {
                    Picker("Select Hole", selection: $selectedHole) {
                        ForEach(1...numberOfHoles, id: \.self) { hole in
                            Text("Hole \(hole)").tag(hole)
                        }
                    }
                } header: {
                    Text("Edit Hole")
                }
                
                if let holeData = holeDataEntries.first(where: { $0.holeNumber == selectedHole }) {
                    Section("Hole \(selectedHole) Details") {
                        Picker("Par", selection: Binding(
                            get: { 
                                holeDataEntries.first(where: { $0.holeNumber == selectedHole })?.par ?? 4
                            },
                            set: { newValue in
                                updateHole(selectedHole) { $0.par = newValue }
                            }
                        )) {
                            Text("3").tag(3)
                            Text("4").tag(4)
                            Text("5").tag(5)
                        }
                        
                        TextField("Yardage", value: Binding(
                            get: { 
                                holeDataEntries.first(where: { $0.holeNumber == selectedHole })?.yardage ?? 0
                            },
                            set: { newValue in
                                updateHole(selectedHole) { $0.yardage = newValue }
                            }
                        ), format: .number)
                        .keyboardType(.numberPad)
                    }
                    
                    Section("Green Locations (GPS)") {
                        HStack {
                            Text("Center")
                            Spacer()
                            Button("Use Current") {
                                if let location = gpsManager.currentLocation {
                                    updateHole(selectedHole) {
                                        $0.greenCenterLat = String(location.coordinate.latitude)
                                        $0.greenCenterLon = String(location.coordinate.longitude)
                                    }
                                }
                            }
                            .font(.caption)
                        }
                        TextField("Latitude", text: Binding(
                            get: { holeData.greenCenterLat },
                            set: { newValue in
                                updateHole(selectedHole) { $0.greenCenterLat = newValue }
                            }
                        ))
                        .keyboardType(.decimalPad)
                        TextField("Longitude", text: Binding(
                            get: { holeData.greenCenterLon },
                            set: { newValue in
                                updateHole(selectedHole) { $0.greenCenterLon = newValue }
                            }
                        ))
                        .keyboardType(.decimalPad)
                        
                        HStack {
                            Text("Front")
                            Spacer()
                            Button("Use Current") {
                                if let location = gpsManager.currentLocation {
                                    updateHole(selectedHole) {
                                        $0.greenFrontLat = String(location.coordinate.latitude)
                                        $0.greenFrontLon = String(location.coordinate.longitude)
                                    }
                                }
                            }
                            .font(.caption)
                        }
                        TextField("Latitude", text: Binding(
                            get: { holeData.greenFrontLat },
                            set: { newValue in
                                updateHole(selectedHole) { $0.greenFrontLat = newValue }
                            }
                        ))
                        .keyboardType(.decimalPad)
                        TextField("Longitude", text: Binding(
                            get: { holeData.greenFrontLon },
                            set: { newValue in
                                updateHole(selectedHole) { $0.greenFrontLon = newValue }
                            }
                        ))
                        .keyboardType(.decimalPad)
                        
                        HStack {
                            Text("Back")
                            Spacer()
                            Button("Use Current") {
                                if let location = gpsManager.currentLocation {
                                    updateHole(selectedHole) {
                                        $0.greenBackLat = String(location.coordinate.latitude)
                                        $0.greenBackLon = String(location.coordinate.longitude)
                                    }
                                }
                            }
                            .font(.caption)
                        }
                        TextField("Latitude", text: Binding(
                            get: { holeData.greenBackLat },
                            set: { newValue in
                                updateHole(selectedHole) { $0.greenBackLat = newValue }
                            }
                        ))
                        .keyboardType(.decimalPad)
                        TextField("Longitude", text: Binding(
                            get: { holeData.greenBackLon },
                            set: { newValue in
                                updateHole(selectedHole) { $0.greenBackLon = newValue }
                            }
                        ))
                        .keyboardType(.decimalPad)
                    }
                    
                    Section("Tee Box Location (GPS)") {
                        Button("Use Current Location") {
                            if let location = gpsManager.currentLocation {
                                updateHole(selectedHole) {
                                    $0.teeBoxLat = String(location.coordinate.latitude)
                                    $0.teeBoxLon = String(location.coordinate.longitude)
                                }
                            }
                        }
                        TextField("Latitude", text: Binding(
                            get: { holeData.teeBoxLat },
                            set: { newValue in
                                updateHole(selectedHole) { $0.teeBoxLat = newValue }
                            }
                        ))
                        .keyboardType(.decimalPad)
                        TextField("Longitude", text: Binding(
                            get: { holeData.teeBoxLon },
                            set: { newValue in
                                updateHole(selectedHole) { $0.teeBoxLon = newValue }
                            }
                        ))
                        .keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle("Hole Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if holeDataEntries.isEmpty {
                    initializeHoles(count: numberOfHoles)
                }
            }
        }
    }
    
    private func initializeHoles(count: Int) {
        holeDataEntries = (1...count).map { hole in
            HoleDataEntry(holeNumber: hole)
        }
    }
    
    private func updateHole(_ holeNumber: Int, _ update: (inout HoleDataEntry) -> Void) {
        if let index = holeDataEntries.firstIndex(where: { $0.holeNumber == holeNumber }) {
            var hole = holeDataEntries[index]
            update(&hole)
            holeDataEntries[index] = hole
        }
    }
}

extension String {
    static func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
}

#Preview {
    ContributeCourseView()
        .environmentObject(AuthManager())
        .environmentObject(GPSManager())
        .preferredColorScheme(.dark)
}
