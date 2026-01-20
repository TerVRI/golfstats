import SwiftUI

struct OSMSearchSheet: View {
    let latitude: Double?
    let longitude: Double?
    @Binding var courses: [OSMCourse]
    @Binding var isSearching: Bool
    @Binding var error: String?
    @Environment(\.dismiss) var dismiss
    var onSelectCourse: ((OSMCourse) -> Void)?
    
    @State private var manualLatitude: String = ""
    @State private var manualLongitude: String = ""
    @State private var useManualLocation = false
    
    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    ProgressView("Searching OpenStreetMap...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if latitude == nil && longitude == nil && !useManualLocation {
                    // Show manual location entry form
                    Form {
                        Section {
                            Toggle("Enter Location Manually", isOn: $useManualLocation)
                        } header: {
                            Text("Location Required")
                        } footer: {
                            Text("OSM search requires coordinates. Enable location services or enter coordinates manually.")
                        }
                        
                        if useManualLocation {
                            Section("Coordinates") {
                                TextField("Latitude", text: $manualLatitude)
                                    .keyboardType(.decimalPad)
                                TextField("Longitude", text: $manualLongitude)
                                    .keyboardType(.decimalPad)
                                
                                Button("Search with These Coordinates") {
                                    Task {
                                        await searchWithManualLocation()
                                    }
                                }
                                .disabled(manualLatitude.isEmpty || manualLongitude.isEmpty)
                            }
                        }
                    }
                } else if let errorMessage = error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("Search Failed")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Try Again") {
                            Task {
                                await searchOSM()
                            }
                        }
                        .padding(.top)
                    }
                    .padding()
                } else if courses.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "map")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No courses found")
                            .font(.headline)
                        Text("No golf courses found in OpenStreetMap near this location.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(courses) { course in
                            Button {
                                onSelectCourse?(course)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(course.name)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    if let city = course.city, let state = course.state {
                                        Text("\(city), \(state)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    if !course.address.isEmpty {
                                        Text(course.address)
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color("Background"))
            .navigationTitle("Import from OSM")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                // Only auto-search if we have coordinates
                if latitude != nil && longitude != nil {
                    await searchOSM()
                }
            }
        }
    }
    
    private func searchOSM() async {
        guard let lat = latitude, let lon = longitude else {
            // Don't set error here - let the UI show the manual entry form
            return
        }
        
        await performSearch(latitude: lat, longitude: lon)
    }
    
    private func searchWithManualLocation() async {
        guard let lat = Double(manualLatitude), let lon = Double(manualLongitude) else {
            error = "Please enter valid coordinates"
            return
        }
        
        await performSearch(latitude: lat, longitude: lon)
    }
    
    private func performSearch(latitude: Double, longitude: Double) async {
        isSearching = true
        error = nil
        courses = []
        
        do {
            courses = try await DataService.shared.searchOSMCourses(
                latitude: latitude,
                longitude: longitude,
                radius: 5000
            )
        } catch let searchError {
            error = "Failed to search OpenStreetMap: \(searchError.localizedDescription)"
        }
        
        isSearching = false
    }
}

#Preview {
    OSMSearchSheet(
        latitude: 36.5725,
        longitude: -121.9486,
        courses: .constant([]),
        isSearching: .constant(false),
        error: .constant(nil),
        onSelectCourse: nil
    )
    .preferredColorScheme(.dark)
}
