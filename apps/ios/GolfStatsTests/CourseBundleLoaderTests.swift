import XCTest

@MainActor
final class CourseBundleLoaderTests: XCTestCase {
    var bundleLoader: CourseBundleLoader!
    
    override func setUp() {
        super.setUp()
        bundleLoader = CourseBundleLoader.shared
    }
    
    func testLoadBundledCourses() async {
        let courses = await bundleLoader.loadBundledCourses()
        
        // Should load courses from bundle
        XCTAssertGreaterThan(courses.count, 0, "Should load courses from bundle")
        print("✅ Loaded \(courses.count) courses from bundle in test")
        
        // Check first course has required fields
        if let firstCourse = courses.first {
            XCTAssertFalse(firstCourse.name.isEmpty, "Course should have a name")
            XCTAssertNotNil(firstCourse.id, "Course should have an ID")
        }
    }
    
    func testCountryFiltering() async {
        let courses = await bundleLoader.loadBundledCourses()
        
        // Test filtering for United States
        let usCourses = courses.filter { course in
            guard let country = course.country else { return false }
            return country.localizedCaseInsensitiveCompare("US") == .orderedSame ||
                   country.localizedCaseInsensitiveCompare("USA") == .orderedSame ||
                   country.localizedCaseInsensitiveCompare("United States") == .orderedSame
        }
        
        print("✅ Found \(usCourses.count) US courses")
        XCTAssertGreaterThan(usCourses.count, 0, "Should find US courses")
    }
    
    func testBundleFileExists() {
        guard let url = Bundle.main.url(forResource: "courses-bundle", withExtension: "json") else {
            XCTFail("courses-bundle.json not found in app bundle")
            return
        }
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Bundle file should exist")
        
        // Check file size
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let fileSize = attributes[.size] as? Int64 {
            let sizeInMB = Double(fileSize) / (1024 * 1024)
            print("✅ Bundle file size: \(String(format: "%.2f", sizeInMB)) MB")
            XCTAssertGreaterThan(fileSize, 0, "Bundle file should not be empty")
        }
    }
}
