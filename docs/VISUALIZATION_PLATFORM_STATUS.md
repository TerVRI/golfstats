# Course Visualization - Platform Status

## ✅ Current Status

### Web (React/Next.js)
- ✅ **Map View**: Leaflet-based map visualization with polygons
- ✅ **Schematic View**: SVG-based schematic visualization (NEW!)
- ✅ **Features**:
  - Hole-by-hole view
  - Overview mode (all holes)
  - Layer toggles (fairway, green, bunkers, water, tees, pins)
  - Export to SVG/PNG
  - Distance calculations
  - Zoom controls

### iOS/iPad (SwiftUI)
- ✅ **Map View**: MapKit-based map visualization with polygons
- ✅ **Schematic View**: SwiftUI Canvas-based SVG visualization (NEW!)
- ✅ **Features**:
  - Hole-by-hole view
  - Overview mode (all holes)
  - Layer toggles
  - Toggle between Map and Schematic views
  - Native iOS/iPad support

## 📊 Demo Courses with Full Data

We've added complete hole data to **3 famous courses**:

1. **Pebble Beach Golf Links** ✅
   - 18 holes
   - Tees, greens, fairways
   - 8 bunkers, 4 water hazards

2. **St Andrews (Old Course)** ✅
   - 18 holes
   - Tees, greens, fairways
   - 4 bunkers

3. **TPC Sawgrass (Stadium)** ✅
   - 18 holes (including famous 17th island green!)
   - Tees, greens, fairways
   - 6 bunkers, 4 water hazards

## 🎯 How to Use

### Web
1. Navigate to any course detail page
2. Click "Schematic View" button
3. Toggle between "Map View" and "Schematic View"
4. Use layer toggles to show/hide features
5. Export as SVG or PNG

### iOS/iPad
1. Open any course detail page
2. Scroll to "Course Layout" section
3. Toggle between "Map View" and "Schematic View"
4. Use layer toggles to customize display
5. Switch between hole view and overview mode

## 🔧 Technical Details

### Web Implementation
- **Component**: `apps/web/src/components/course-svg-visualizer.tsx`
- **Technology**: React + SVG
- **Features**: Export, zoom, distance calculations

### iOS Implementation
- **Components**:
  - `CourseVisualizerView.swift` - MapKit-based map view
  - `CourseSVGVisualizerView.swift` - Canvas-based schematic view (NEW!)
  - `CourseVisualizationToggleView.swift` - Toggle between views (NEW!)
- **Technology**: SwiftUI + Canvas API
- **Features**: Native iOS controls, responsive design

## 📱 Platform Support

| Feature | Web | iOS | iPad |
|---------|-----|-----|------|
| Map View | ✅ | ✅ | ✅ |
| Schematic View | ✅ | ✅ | ✅ |
| Hole-by-Hole | ✅ | ✅ | ✅ |
| Overview Mode | ✅ | ✅ | ✅ |
| Layer Toggles | ✅ | ✅ | ✅ |
| Export (SVG/PNG) | ✅ | ❌ | ❌ |
| Distance Calculations | ✅ | ✅ | ✅ |
| Zoom Controls | ✅ | ✅ | ✅ |

## 🚀 Next Steps

1. **Add More Demo Courses**: Run `scripts/add-demo-hole-data.ts` for more courses
2. **Fetch Real OSM Data**: Use `scripts/fetch-osm-hole-data.ts` to get real course data
3. **User Contributions**: Encourage users to add hole data through the contribution system
4. **iOS Export**: Consider adding export functionality to iOS (share sheet)

## 📝 Notes

- All visualizations work with partial data (points only, or full polygons)
- The system automatically calculates distances from GPS coordinates
- Both map and schematic views use the same data structure (`hole_data` JSONB field)
- SVG visualizations are lightweight and work well on mobile devices
