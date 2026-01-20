# Demo Course Data Sources

## Summary

We've researched free sources for golf course hole-by-hole data and successfully added demo data to **Pebble Beach Golf Links** to showcase the visualization system.

## Free Data Sources Found

### 1. **OpenStreetMap (OSM)** ⭐ Best Option
- **What's Available**: Golf course boundaries, tees, greens, fairways, bunkers, water hazards
- **How to Access**: Overpass API queries, OSM exports
- **Quality**: Varies by course - some are well-mapped, others have minimal data
- **License**: ODbL (Open Database License) - requires attribution
- **Script Created**: `scripts/fetch-osm-hole-data.ts` - queries OSM for detailed hole data

### 2. **GolfAPI.io**
- **What's Available**: 42,000+ courses, scorecards, tee boxes, pars, yardages
- **Cost**: Free tier available, paid for full access
- **Limitation**: May not include polygon/geometry data for fairways/greens

### 3. **GolfCourseAPI**
- **What's Available**: 30,000+ courses globally
- **Cost**: Free tier for testing
- **Limitation**: Check if GPS/polygon data included in free tier

### 4. **tracks.golf**
- **What's Available**: Global directory powered by OSM
- **Use Case**: Good for discovering which courses are mapped in OSM
- **Website**: https://tracks.golf

### 5. **State/Local GIS Portals**
- **What's Available**: Some states/cities provide golf course shapefiles
- **Example**: Utah GIS has golf course polygons
- **Limitation**: Usually just course boundaries, not hole-by-hole detail

## What We've Implemented

### ✅ Demo Data Script
**File**: `scripts/add-demo-hole-data.ts`

This script generates realistic hole data for demonstration purposes. It includes:
- 18 holes with tee locations
- Green polygons and centers
- Fairway polygons (for par 4s and 5s)
- Bunker locations
- Water hazards
- Yardage information

**Usage**:
```bash
npx tsx scripts/add-demo-hole-data.ts
```

**Successfully Added**: Pebble Beach Golf Links now has full hole data!

### ✅ OSM Data Fetcher
**File**: `scripts/fetch-osm-hole-data.ts`

This script queries OpenStreetMap for actual golf course features:
- Tee boxes (`golf=tee`)
- Greens (`golf=green`)
- Fairways (`golf=fairway`)
- Bunkers (`golf=bunker`)
- Water hazards (`natural=water`)

**Usage**:
```bash
npx tsx scripts/fetch-osm-hole-data.ts
```

## Current Demo Course Status

### Pebble Beach Golf Links ✅
- **Status**: Has full demo hole data
- **Holes**: 18
- **Features**:
  - ✅ Tee locations (multiple tees per hole)
  - ✅ Green polygons and centers
  - ✅ Fairway polygons (14 holes)
  - ✅ Bunkers (8 total)
  - ✅ Water hazards (4 total)
  - ✅ Yardage information

**You can now view this course in the SVG visualizer!**

## Next Steps

### Option 1: Add More Demo Courses
Run the demo script for other famous courses:
- St Andrews (Old Course)
- TPC Sawgrass
- Augusta National (may need manual data entry)

### Option 2: Fetch Real OSM Data
Use `fetch-osm-hole-data.ts` to query OSM for courses that are well-mapped:
- Some courses in OSM have detailed hole-by-hole data
- Quality varies - may need manual refinement

### Option 3: Manual Data Entry
For courses like Augusta National:
- Use official scorecards for yardages/pars
- Trace fairways/greens from satellite imagery
- Add through the contribution system

### Option 4: API Integration
Consider integrating with:
- GolfAPI.io for scorecard data
- Combine with OSM geometry data
- Best of both worlds

## Data Quality Notes

### What OSM Typically Has:
- ✅ Course boundaries
- ✅ Basic location data
- ⚠️ Hole-by-hole detail (varies widely)
- ⚠️ Polygon data (some courses well-mapped, others not)

### What We Need for Full Visualization:
- Tee box locations (GPS coordinates)
- Green centers (GPS coordinates)
- Fairway polygons (arrays of GPS coordinates)
- Green polygons
- Bunker polygons
- Water hazard polygons
- Yardage markers

### Realistic Expectations:
- **Well-mapped courses in OSM**: May have 60-80% of needed data
- **Average courses**: May have 20-40% of needed data
- **Most courses**: Will need user contributions to complete

## Recommendations

1. **Start with Demo Data**: ✅ Done - Pebble Beach has demo data
2. **Query OSM for Popular Courses**: Try St Andrews, TPC Sawgrass
3. **Encourage User Contributions**: Best long-term solution
4. **Consider API Partnerships**: For scorecard data (pars, yardages)

## Files Created

1. `scripts/add-demo-hole-data.ts` - Generates demo hole data
2. `scripts/fetch-osm-hole-data.ts` - Queries OSM for real data
3. `docs/DEMO_COURSE_DATA_SOURCES.md` - This document

## Testing the Visualization

1. Navigate to a course detail page (e.g., Pebble Beach)
2. Switch to "Schematic View"
3. You should see:
   - All 18 holes with polygons
   - Tee boxes, greens, fairways
   - Bunkers and water hazards
   - Distance calculations

The visualization system is now ready to showcase with real course data!
