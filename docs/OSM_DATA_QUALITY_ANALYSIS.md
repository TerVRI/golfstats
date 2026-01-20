# OSM Data Quality Analysis

## The Problem: Why "Unknown" Locations?

### What OSM Actually Contains

OpenStreetMap (OSM) is a **crowd-sourced map database**. For golf courses, it typically contains:

✅ **What OSM HAS:**
- Course name
- Basic location (coordinates - sometimes)
- Address components (city, state, country - **often incomplete**)
- Contact info (phone, website - if added by contributors)
- Course outline polygon (geometry)

❌ **What OSM DOES NOT HAVE:**
- Hole-by-hole data (par, yardages, tees)
- Pin placements
- Green locations
- Fairway boundaries
- Bunker locations
- Detailed course features

### Why We Have "Unknown" Locations

Looking at our import code (`scripts/import-osm-courses.ts`):

```typescript
country: tags["addr:country"] || tags["addr:country_code"] || "Unknown",
```

**The issue:** Many OSM entries don't have `addr:country` or `addr:country_code` tags because:
1. OSM contributors don't always add complete address data
2. Some courses are tagged with just coordinates and name
3. Address tags are optional in OSM

**Result:** ~94.5% of our imported courses have `country: "Unknown"` because OSM doesn't provide it.

### Coordinate Issues

Some courses have coordinates, some don't:
- **Ways/Relations:** Have `center` coordinates (calculated from geometry)
- **Nodes:** Have direct `lat/lon`
- **Some entries:** Have neither (rare, but happens)

Our code handles this:
```typescript
const lat = osmCourse.lat || osmCourse.center?.lat;
const lon = osmCourse.lon || osmCourse.center?.lon;
```

But if both are missing, we store `null` → "Location Unknown"

## Data Quality Issues

### 1. Bad Course Names
- **Numbers only:** "1", "13", "15" (likely incomplete OSM entries)
- **Quotes:** '"Ground Golf"' (OSM tag formatting)
- **Too short:** "GC" (abbreviations without full name)

**Source:** OSM contributors sometimes add minimal data

### 2. Missing Location Data
- **No country:** 94.5% of courses
- **No city:** 69% of courses  
- **No coordinates:** Some courses (rare)

**Source:** Incomplete OSM tagging

### 3. No Golf-Specific Data
- **No hole data:** OSM doesn't store this
- **No PARs:** Not in OSM schema
- **No yardages:** Not in OSM schema
- **No tee locations:** Not in OSM schema

**Source:** OSM is a map, not a golf course database

## What We're Storing

From `convertOSMCourseToContribution()`:

```typescript
{
  name: tags.name || "Unnamed Golf Course",
  city: tags["addr:city"] || null,
  state: tags["addr:state"] || null,
  country: tags["addr:country"] || tags["addr:country_code"] || "Unknown",
  address: [house number + street] || null,
  phone: tags.phone || null,
  website: tags.website || null,
  latitude: lat || null,
  longitude: lon || null,
  hole_data: [],  // ← EMPTY! OSM doesn't have this
  geojson_data: polygon || null,  // Course outline
  source: "osm"
}
```

## Solutions

### 1. Immediate Fixes (App-Level)
✅ **DONE:** Filter out bad course names in the app
✅ **DONE:** Better location formatting (hide "Unknown")
✅ **DONE:** Maps integration for courses with coordinates

### 2. Data Quality Improvements

#### A. Reverse Geocoding
For courses with coordinates but missing country/city:
- Use coordinates → reverse geocode → get country/city
- Update database with geocoded data

#### B. Forward Geocoding  
For courses with address but no coordinates:
- Use address → geocode → get coordinates
- Update database with coordinates

#### C. Data Cleaning
- Mark courses with bad names as "incomplete"
- Filter them from exports
- Allow users to complete them

### 3. Long-Term Strategy

**OSM is just a starting point.** We need:
1. **User contributions** to add hole data, pars, yardages
2. **Geocoding** to fill missing location data
3. **Data validation** to ensure quality
4. **Gamification** (badges, leaderboards) to encourage contributions

## Sample OSM Course

Run `npx tsx scripts/query-osm-sample-course.ts` to see what a real OSM course contains.

Expected output:
- Basic tags (name, leisure=golf_course)
- Address tags (often incomplete)
- Contact tags (if available)
- **NO golf-specific data** (holes, pars, tees, yardages)

## Conclusion

**OSM provides:**
- Basic course locations and names
- Incomplete address data (hence "Unknown" countries)
- Course outline polygons

**OSM does NOT provide:**
- Detailed golf course data (holes, pars, yardages, tees)
- Complete location data (many missing countries/cities)

**Our role:**
- Use OSM as a starting point
- Fill in missing data through:
  - Geocoding (for locations)
  - User contributions (for golf-specific data)
  - Data validation (for quality)
