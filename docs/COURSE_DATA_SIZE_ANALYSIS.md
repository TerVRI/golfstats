# Course Data Download Size Analysis

## Current Database Status
- **Total Courses**: ~22,837 (from OSM import)
- **Courses with hole_data**: Unknown (varies by course)
- **Courses with polygon data**: Unknown (most OSM courses have basic data only)

## Data Size Estimates

### Per Course Breakdown

#### Basic Course Fields (without hole_data)
- `id`: UUID (36 bytes)
- `name`: TEXT (~30-50 chars = 30-50 bytes)
- `city`, `state`, `country`: TEXT (~15-30 chars each = 45-90 bytes)
- `address`: TEXT (~50-100 chars = 50-100 bytes)
- `phone`, `website`: TEXT (~20-50 chars each = 40-100 bytes)
- `course_rating`, `slope_rating`, `par`: Numbers (~10 bytes)
- `latitude`, `longitude`: DECIMAL (~20 bytes)
- `avg_rating`, `review_count`: Numbers (~10 bytes)
- **Subtotal**: ~250-400 bytes per course

#### hole_data JSONB (Variable Size)
The `hole_data` field is the largest variable:

**Minimal hole_data** (just par/yardages, no polygons):
- 18 holes × ~50 bytes = ~900 bytes
- **Total with basic**: ~1.2-1.3 KB per course

**Moderate hole_data** (with tee/green locations, some polygons):
- 18 holes × ~200 bytes = ~3.6 KB
- **Total with basic**: ~4 KB per course

**Full hole_data** (complete polygon data for all features):
- Fairway polygons: ~5-10 KB per hole
- Green polygons: ~1-2 KB per hole
- Bunkers, water, trees: ~2-5 KB per hole
- 18 holes × ~10 KB = ~180 KB per course
- **Total with basic**: ~180-200 KB per course

### Total Size Estimates

#### Scenario 1: Basic Data Only (No hole_data)
- 22,837 courses × 0.4 KB = **~9 MB**

#### Scenario 2: Minimal hole_data (Most OSM courses)
- 22,837 courses × 1.3 KB = **~30 MB**

#### Scenario 3: Moderate hole_data (Some detailed courses)
- 22,837 courses × 4 KB = **~91 MB**

#### Scenario 4: Full hole_data (All courses with complete polygons)
- 22,837 courses × 200 KB = **~4.5 GB** ⚠️

#### Scenario 5: Realistic Mix (Most OSM courses are basic)
- 20,000 courses × 1.3 KB (basic) = 26 MB
- 2,500 courses × 4 KB (moderate) = 10 MB
- 337 courses × 200 KB (full) = 67 MB
- **Total**: **~103 MB** (compressed: ~20-30 MB)

## Recommendations

### ✅ Recommended Approach: Selective Download

1. **Initial Load**: Download only basic course info (name, location, ratings)
   - Size: ~9 MB
   - Fast initial load, good for search/browsing

2. **On-Demand**: Download `hole_data` only when viewing a course
   - Size: 1-200 KB per course
   - Users only download what they need

3. **Caching**: Cache viewed courses locally
   - Store recently viewed courses with full data
   - Limit cache to ~50-100 courses (~5-20 MB)

### Implementation Strategy

```swift
// Lightweight course list (no hole_data)
func fetchCourses(search: String?, country: String?, limit: Int) async throws -> [Course] {
    // Exclude hole_data from initial query
    // SELECT id, name, city, state, country, latitude, longitude, 
    //        course_rating, slope_rating, par, avg_rating, review_count
    // FROM courses
}

// Full course details (with hole_data)
func fetchCourseDetails(id: String) async throws -> Course {
    // Include hole_data for specific course
    // SELECT * FROM courses WHERE id = $1
}
```

### Compression Benefits

- **JSON compression**: Can reduce size by 60-80%
- **Gzip on API**: Supabase likely compresses responses
- **Estimated compressed size**: 20-40 MB for all basic data

## Conclusion

**Downloading all course data with full hole_data**: ~4.5 GB (not recommended)

**Downloading all basic course data**: ~9-30 MB (feasible, but still large for mobile)

**Recommended**: Download basic data on-demand (paginated) + fetch hole_data per course
- Initial app load: ~1-2 MB (first 100-200 courses)
- Per course detail: 1-200 KB
- Total user data usage: Minimal, only what they view
