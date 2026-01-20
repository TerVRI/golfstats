# Course Visualization Guide

## Overview

The course visualization system allows you to display and interact with detailed GPS-based course layouts, including fairways, greens, bunkers, rough, water hazards, and more.

## Data Structure

### Enhanced `hole_data` JSONB Structure

The `hole_data` field in the `courses` table supports a comprehensive structure for visualizing course features:

```typescript
interface HoleVisualizationData {
  hole_number: number;
  par: number;
  
  // Point Locations
  tee_locations?: Array<{
    tee: string;        // "black", "blue", "white", "gold", "red"
    lat: number;
    lon: number;
  }>;
  
  green_center?: { lat: number; lon: number };
  green_front?: { lat: number; lon: number };
  green_back?: { lat: number; lon: number };
  
  // Polygon Areas (arrays of [lat, lon] coordinates)
  fairway?: Array<[number, number]>;      // Fairway boundary
  green?: Array<[number, number]>;        // Green boundary
  rough?: Array<[number, number]>;        // Rough areas
  
  // Complex Features
  bunkers?: Array<{
    type: "bunker" | "sand_trap";
    polygon: Array<[number, number]>;     // Bunker boundary
    center?: { lat: number; lon: number };
  }>;
  
  water_hazards?: Array<{
    polygon: Array<[number, number]>;     // Water boundary
    center?: { lat: number; lon: number };
  }>;
  
  trees?: Array<{
    polygon: Array<[number, number]>;     // Tree area boundary
    center?: { lat: number; lon: number };
  }>;
  
  // Yardage Markers
  yardage_markers?: Array<{
    distance: number;  // yards
    lat: number;
    lon: number;
  }>;
}
```

### Example JSON

```json
{
  "hole_number": 1,
  "par": 4,
  "tee_locations": [
    { "tee": "blue", "lat": 40.7128, "lon": -74.0060 },
    { "tee": "white", "lat": 40.7129, "lon": -74.0061 }
  ],
  "green_center": { "lat": 40.7130, "lon": -74.0055 },
  "green_front": { "lat": 40.7129, "lon": -74.0056 },
  "green_back": { "lat": 40.7131, "lon": -74.0054 },
  "fairway": [
    [40.7128, -74.0060],
    [40.7130, -74.0058],
    [40.7132, -74.0056],
    [40.7130, -74.0054],
    [40.7128, -74.0056]
  ],
  "green": [
    [40.7129, -74.0056],
    [40.7131, -74.0055],
    [40.7131, -74.0054],
    [40.7129, -74.0055]
  ],
  "bunkers": [
    {
      "type": "bunker",
      "polygon": [
        [40.7129, -74.0057],
        [40.7130, -74.0057],
        [40.7130, -74.0056],
        [40.7129, -74.0056]
      ]
    }
  ],
  "water_hazards": [
    {
      "polygon": [
        [40.7130, -74.0058],
        [40.7132, -74.0058],
        [40.7132, -74.0057],
        [40.7130, -74.0057]
      ]
    }
  ],
  "yardage_markers": [
    { "distance": 150, "lat": 40.7129, "lon": -74.0057 },
    { "distance": 100, "lat": 40.7130, "lon": -74.0056 }
  ]
}
```

## Web Component

### CourseVisualizer Component

**Location:** `apps/web/src/components/course-visualizer.tsx`

**Features:**
- Interactive Leaflet map
- Polygon rendering for fairways, greens, rough, bunkers, water
- Layer toggles for showing/hiding features
- Hole selector
- Satellite view toggle
- Yardage markers
- Tee-to-green line

**Usage:**

```tsx
import { CourseVisualizer } from "@/components/course-visualizer";

<CourseVisualizer
  holeData={course.hole_data}
  initialHole={1}
  center={[40.7128, -74.0060]}
  zoom={15}
  showSatellite={false}
  mode="view"
  onHoleChange={(holeNumber) => console.log("Hole changed:", holeNumber)}
  showLayers={{
    fairway: true,
    green: true,
    rough: true,
    bunkers: true,
    water: true,
    trees: false,
    yardageMarkers: true,
  }}
/>
```

**Props:**
- `holeData`: Array of `HoleVisualizationData`
- `initialHole`: Starting hole number (default: 1)
- `center`: Map center `[lat, lon]` (optional, auto-calculated)
- `zoom`: Initial zoom level (default: 15)
- `showSatellite`: Toggle satellite imagery (default: false)
- `mode`: "view" or "interactive" (default: "view")
- `onHoleChange`: Callback when hole changes
- `showLayers`: Object to control layer visibility

## iOS Component

### CourseVisualizerView (SwiftUI + MapKit)

**Location:** `apps/ios/GolfStats/Sources/Views/CourseVisualizerView.swift`

**Features:**
- Native MapKit integration
- Polygon overlays for course features
- Annotation markers for tees and greens
- Layer controls
- Hole navigation

**Usage:**

```swift
CourseVisualizerView(
    holeData: course.holeData ?? [],
    initialHole: 1,
    showSatellite: false
)
```

## Integration Points

### 1. Course Detail Page

Add visualization to course detail pages:

**Web:**
```tsx
// apps/web/src/app/(app)/courses/[id]/page.tsx
import { CourseVisualizer } from "@/components/course-visualizer";

{course.hole_data && course.hole_data.length > 0 && (
  <Card className="mt-6">
    <CardHeader>
      <CardTitle>Course Layout</CardTitle>
    </CardHeader>
    <CardContent>
      <CourseVisualizer
        holeData={course.hole_data}
        center={course.latitude && course.longitude 
          ? [course.latitude, course.longitude] 
          : undefined}
      />
    </CardContent>
  </Card>
)}
```

**iOS:**
```swift
// In CourseDetailView
if let holeData = course.holeData, !holeData.isEmpty {
    CourseVisualizerView(
        holeData: holeData,
        initialHole: 1
    )
    .frame(height: 400)
    .cornerRadius(12)
}
```

### 2. Course Contribution Flow

Enhance the contribution flow to allow polygon drawing:

- Add polygon drawing tools to `CourseMapEditor`
- Allow users to draw fairways, greens, bunkers, etc.
- Save polygon coordinates to `hole_data`

## Color Scheme

- **Fairway**: Green (#22c55e) - 30% opacity
- **Green**: Green (#10b981) - 50% opacity
- **Rough**: Light Green (#84cc16) - 20% opacity, dashed
- **Bunkers**: Yellow (#fbbf24) - 40% opacity
- **Water**: Blue (#3b82f6) - 50% opacity
- **Trees**: Dark Green (#16a34a) - 30% opacity
- **Tee Boxes**: Color-coded by tee (black, blue, white, gold, red)
- **Green Center**: Green circle marker

## Best Practices

1. **Polygon Points**: Use 4-8 points for fairways, 4-6 for greens
2. **Coordinate Precision**: Use 6-7 decimal places for GPS coordinates
3. **Performance**: Limit polygons to reasonable complexity (max 20 points)
4. **Data Validation**: Ensure polygons are closed (first point = last point)
5. **Progressive Enhancement**: Support courses with partial data (points only, no polygons)

## Future Enhancements

1. **Polygon Drawing Tools**: Interactive editor for drawing course features
2. **Import from OSM**: Auto-import course boundaries from OpenStreetMap
3. **3D Visualization**: Elevation data and 3D rendering
4. **Shot Tracking Overlay**: Show shot locations on course map
5. **Distance Calculation**: Real-time distance to green, hazards
6. **AR Mode**: Augmented reality course view on mobile

## Migration Path

For existing courses with basic GPS data:

1. Keep existing point-based data (tees, greens)
2. Gradually add polygon data through contributions
3. Support both old and new data formats
4. Provide tools to convert points to approximate polygons
