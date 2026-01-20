# OpenStreetMap Courses Visualization

## Overview

A beautiful, interactive visualization of all OpenStreetMap golf courses imported into the database. This feature provides a global view of golf courses with advanced filtering, clustering, and statistics.

## Features

### 🎨 Visual Features

- **Interactive Global Map**: View all 40,000+ OSM courses on a world map
- **Smart Clustering**: Automatically clusters markers when zoomed out for performance
- **Color-Coded Status**: 
  - 🟢 Green = Approved courses
  - 🟡 Yellow = Pending courses
  - ⚪ Gray = Other status
- **Heatmap Overlay**: Optional heatmap showing course density
- **Fullscreen Mode**: Immersive fullscreen viewing experience

### 📊 Statistics Dashboard

Real-time statistics cards showing:
- **Total Courses**: All OSM courses in database
- **Countries**: Number of countries represented
- **Visible**: Currently filtered/visible courses
- **Pending**: Courses awaiting approval

### 🔍 Search & Filter

- **Search Bar**: Search by course name, city, or country
- **Country Filter**: Dropdown to filter by country
- **Top Countries**: Quick-click buttons for top 12 countries
- **Real-time Updates**: Filters update map instantly

### 🎯 Interactive Features

- **Click Markers**: View course details in popups
- **Auto-fit Bounds**: Map automatically adjusts to show filtered courses
- **Zoom Controls**: Standard map zoom and pan
- **Responsive Design**: Works on all screen sizes

## Usage

### Accessing the Visualization

1. Navigate to `/courses/osm-visualization`
2. Or click "OSM Map" button on the courses page

### Using Filters

1. **Search**: Type in the search bar to filter by name/location
2. **Country**: Select a country from the dropdown
3. **Top Countries**: Click a country card to filter
4. **Toggle Clusters**: Enable/disable marker clustering
5. **Toggle Heatmap**: Show/hide density heatmap

### Viewing Course Details

- Click any marker on the map
- Popup shows:
  - Course name
  - Location (city, state, country)
  - Status badge
  - OSM source indicator

## Technical Details

### Components

- **`OSMCoursesVisualization`**: Main visualization component
- **`ClusterLayer`**: Handles marker clustering using Leaflet MarkerCluster
- **`OSMVisualizationPage`**: Page wrapper with header and info

### Dependencies

- `leaflet`: Map rendering
- `react-leaflet`: React bindings for Leaflet
- `leaflet.markercluster`: Marker clustering plugin
- `@supabase/supabase-js`: Database queries

### Performance

- **Clustering**: Automatically clusters markers when zoomed out
- **Chunked Loading**: Loads markers in chunks for better performance
- **Lazy Rendering**: Only renders visible markers
- **Optimized Queries**: Efficient database queries with proper indexing

### Data Source

- Fetches from `course_contributions` table
- Filters by `source = 'osm'`
- Only includes courses with valid coordinates
- Real-time data from database

## Customization

### Clustering Options

Clusters are color-coded by size:
- **Small** (1-50 courses): Green, 30px
- **Medium** (51-100 courses): Yellow, 40px
- **Large** (100+ courses): Red, 50px

### Marker Icons

Custom golf course icons with:
- Status-based colors
- Golf flag emoji
- White border for visibility
- Shadow for depth

### Map Styles

- Default: OpenStreetMap tiles
- Can be extended with satellite view
- Responsive to theme (dark/light)

## Future Enhancements

Potential improvements:
- [ ] Satellite view toggle
- [ ] Export filtered courses to CSV
- [ ] Share map view URL
- [ ] Animation when filtering
- [ ] Course density charts
- [ ] Time-based filtering (by import date)
- [ ] Status-based filtering
- [ ] Region-based filtering (continents)

## Screenshots

The visualization includes:
- Gradient stat cards
- Interactive map with clustering
- Search and filter controls
- Top countries quick-select
- Fullscreen mode

## Notes

- **Performance**: With 40,000+ courses, clustering is essential
- **Data Quality**: Some courses may have missing country tags
- **Updates**: Data updates when new OSM courses are imported
- **Mobile**: Fully responsive, works on mobile devices

## Related

- See `docs/OSM_IMPORT_GUIDE.md` for importing courses
- See `docs/OSM_COURSE_STATISTICS.md` for statistics
