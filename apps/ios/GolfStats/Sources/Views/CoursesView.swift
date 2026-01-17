import SwiftUI

struct CoursesView: View {
    @EnvironmentObject var gpsManager: GPSManager
    @State private var courses: [Course] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var showNearby = false
    
    var filteredCourses: [Course] {
        if searchText.isEmpty {
            return courses
        }
        return courses.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if courses.isEmpty {
                    EmptyStateCard(
                        icon: "map",
                        title: "No courses found",
                        subtitle: "Search for a course or check back later"
                    )
                    .padding()
                } else {
                    List {
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
                    NavigationLink(destination: ContributeCourseView()) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNearby.toggle()
                        Task { await loadCourses() }
                    } label: {
                        Image(systemName: showNearby ? "location.fill" : "location")
                            .foregroundColor(showNearby ? .green : .gray)
                    }
                }
            }
        }
        .task {
            await loadCourses()
        }
        .refreshable {
            await loadCourses()
        }
    }
    
    private func loadCourses() async {
        isLoading = true
        
        do {
            if showNearby, let location = gpsManager.currentLocation {
                courses = try await DataService.shared.fetchNearbyCourses(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            } else {
                courses = try await DataService.shared.fetchCourses(
                    search: searchText.isEmpty ? nil : searchText
                )
            }
        } catch {
            print("Error loading courses: \(error)")
        }
        
        isLoading = false
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
                if !course.location.isEmpty {
                    Label(course.location, systemImage: "mappin")
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
}

struct CourseDetailView: View {
    let course: Course
    @EnvironmentObject var roundManager: RoundManager
    @State private var weather: Weather?
    @State private var isLoadingWeather = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text(course.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if !course.location.isEmpty {
                        Label(course.location, systemImage: "mappin")
                            .font(.subheadline)
                            .foregroundColor(.gray)
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
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color("Background"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadWeather()
        }
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
