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
    
    var body: some View {
        NavigationStack {
            Form {
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
            .alert("Contribution Submitted", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for contributing! Your course submission is pending review.")
            }
        }
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
        
        guard let user = authManager.currentUser else {
            errorMessage = "Please sign in to upload photos"
            isUploadingPhotos = false
            return
        }
        
        var uploadedUrls: [String] = []
        
        for photoItem in selectedPhotos {
            do {
                // Load image from PhotosPickerItem
                if let imageData = try await photoItem.loadTransferable(type: Data.self) {
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
                } else if let image = try await photoItem.loadTransferable(type: PlatformImage.self) {
                    // Fallback: Convert UIImage to Data
                    guard let imageData = image.pngData() ?? image.jpegData(compressionQuality: 0.8) else {
                        continue
                    }
                    
                    // Validate file size (5 MB max)
                    let maxSize = 5 * 1024 * 1024 // 5 MB
                    guard imageData.count <= maxSize else {
                        errorMessage = "Photo size must be less than 5 MB"
                        continue
                    }
                    
                    // Generate unique filename
                    let fileExt = "jpg"
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
                }
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
                photoUrls: photoUrls
            )
            
            showSuccess = true
        } catch {
            errorMessage = "Failed to submit contribution: \(error.localizedDescription)"
        }
        
        isSubmitting = false
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
