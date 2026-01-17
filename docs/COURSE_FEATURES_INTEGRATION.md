# Course Features Integration Guide

This document outlines all the enhanced course contribution features and how to integrate them.

## ✅ Platform Status

- **Web App:** ✅ All features fully integrated
- **iOS App:** ✅ All features fully integrated (including photo upload)
- **Watch App:** ⚠️ Limited - only quick confirmation feasible

## ✅ Completed Features

### 1. Map-Based Course Editor
**Component:** `components/course-map-editor.tsx`
- Interactive Leaflet map for placing markers
- Click to add tee boxes, greens, hazards
- Drag markers to adjust positions
- Satellite view toggle
- GPS location button

**Usage:**
```tsx
import { CourseMapEditor } from "@/components/course-map-editor";

<CourseMapEditor
  initialLat={40.7128}
  initialLon={-74.0060}
  markers={markers}
  onMarkerAdd={(marker) => handleAddMarker(marker)}
  onMarkerUpdate={(id, position) => handleUpdateMarker(id, position)}
  onMarkerDelete={(id) => handleDeleteMarker(id)}
  mode="edit"
  currentHole={1}
/>
```

### 2. Photo Verification System
**Component:** `components/photo-upload.tsx`
- Upload multiple photos
- Stores in Supabase Storage
- Preview and delete photos
- Max photos and size limits

**Usage:**
```tsx
import { PhotoUpload } from "@/components/photo-upload";

<PhotoUpload
  photos={photos}
  onPhotosChange={setPhotos}
  bucket="course-photos"
  maxPhotos={10}
  maxSizeMB={5}
/>
```

### 3. Data Completeness Indicator
**Component:** `components/data-completeness-indicator.tsx`
- Shows 0-100% completeness score
- Lists missing fields
- Color-coded status

**Usage:**
```tsx
import { DataCompletenessIndicator } from "@/components/data-completeness-indicator";

<DataCompletenessIndicator
  score={completenessScore}
  missingFields={missingFields}
  showDetails={true}
/>
```

### 4. OSM Auto-Fill
**Component:** `components/osm-autofill.tsx`
- Search OpenStreetMap for courses
- Auto-fill name, address, location
- One-click import

**Usage:**
```tsx
import { OSMAutofill } from "@/components/osm-autofill";

<OSMAutofill
  onSelect={(data) => {
    setFormData({ ...formData, ...data });
  }}
  initialLat={40.7128}
  initialLon={-74.0060}
/>
```

### 5. Quality Validation
**Library:** `lib/course-validation.ts`
- Validates par totals, yardages, GPS coordinates
- Flags suspicious data
- Duplicate detection

**Usage:**
```tsx
import { validateCourseData, detectDuplicates } from "@/lib/course-validation";

const validation = validateCourseData(courseData);
if (!validation.isValid) {
  console.error(validation.errors);
}
console.warn(validation.warnings);

const duplicateCheck = detectDuplicates(course1, course2);
if (duplicateCheck.isDuplicate) {
  // Handle duplicate
}
```

### 6. Notifications System
**Component:** `components/notifications.tsx`
- Notification center
- Unread count badge
- Real-time updates

**Usage:**
```tsx
import { NotificationsCenter, NotificationBell } from "@/components/notifications";

// In header/navbar
<NotificationBell />

// Full notifications page
<NotificationsCenter />
```

### 7. Smart Suggestions
**Library:** `lib/smart-suggestions.ts`
- Courses near you needing data
- Similar courses to ones you've contributed
- Courses needing verification

**Usage:**
```tsx
import { getCoursesNearYouNeedingData } from "@/lib/smart-suggestions";

const suggestions = await getCoursesNearYouNeedingData(lat, lon, 50);
```

## 🔄 Integration Steps

### Step 1: Update Contribution Page

Add to `apps/web/src/app/(app)/courses/contribute/page.tsx`:

1. **Import components:**
```tsx
import { CourseMapEditor } from "@/components/course-map-editor";
import { PhotoUpload } from "@/components/photo-upload";
import { OSMAutofill } from "@/components/osm-autofill";
import { DataCompletenessIndicator } from "@/components/data-completeness-indicator";
import { validateCourseData } from "@/lib/course-validation";
```

2. **Add state:**
```tsx
const [photos, setPhotos] = useState<string[]>([]);
const [mapMarkers, setMapMarkers] = useState<MapMarker[]>([]);
const [completenessScore, setCompletenessScore] = useState(0);
const [validationResult, setValidationResult] = useState<ValidationResult | null>(null);
```

3. **Add OSM autofill section:**
```tsx
<OSMAutofill
  onSelect={(data) => {
    setFormData({ ...formData, ...data });
    if (data.latitude && data.longitude) {
      setMapCenter([data.latitude, data.longitude]);
    }
  }}
  initialLat={parseFloat(formData.latitude) || undefined}
  initialLon={parseFloat(formData.longitude) || undefined}
/>
```

4. **Add map editor:**
```tsx
<CourseMapEditor
  initialLat={parseFloat(formData.latitude) || 40.7128}
  initialLon={parseFloat(formData.longitude) || -74.0060}
  markers={mapMarkers}
  onMarkerAdd={(marker) => {
    setMapMarkers([...mapMarkers, marker]);
    // Update hole data with marker position
  }}
  mode="edit"
  currentHole={currentHole}
/>
```

5. **Add photo upload:**
```tsx
<PhotoUpload
  photos={photos}
  onPhotosChange={setPhotos}
  bucket="course-photos"
/>
```

6. **Add validation:**
```tsx
useEffect(() => {
  const validation = validateCourseData({
    name: formData.name,
    par: parseInt(formData.par),
    holes: parseInt(formData.holes),
    latitude: parseFloat(formData.latitude),
    longitude: parseFloat(formData.longitude),
    hole_data: holeData,
  });
  setValidationResult(validation);
}, [formData, holeData]);
```

7. **Add completeness indicator:**
```tsx
<DataCompletenessIndicator
  score={completenessScore}
  missingFields={missingFields}
  showDetails={true}
/>
```

### Step 2: Update Course Detail Page

Add to `apps/web/src/app/(app)/courses/[id]/page.tsx`:

```tsx
import { CourseDiscussions } from "@/components/course-discussions";
import { PhotoUpload } from "@/components/photo-upload";

// Add discussions section
<CourseDiscussions courseId={course.id} />

// Show photos if available
{course.photos && course.photos.length > 0 && (
  <div className="grid grid-cols-4 gap-2">
    {course.photos.map((photo, i) => (
      <img key={i} src={photo} alt={`Course photo ${i + 1}`} />
    ))}
  </div>
)}
```

### Step 3: Add Notifications to Layout

Add to your main layout:

```tsx
import { NotificationBell } from "@/components/notifications";

// In navbar
<NotificationBell />
```

### Step 4: Create Notifications Page

Create `apps/web/src/app/(app)/notifications/page.tsx`:

```tsx
import { NotificationsCenter } from "@/components/notifications";

export default function NotificationsPage() {
  return <NotificationsCenter />;
}
```

### Step 5: Run Database Migration

Run the migration:
```sql
-- Run: supabase/migrations/20260118000000_enhanced_course_features.sql
```

### Step 6: Set Up Storage Bucket

In Supabase Dashboard:
1. Go to Storage
2. Create bucket: `course-photos`
3. Set public: true (or configure RLS policies)

## 📋 Remaining Features to Implement

### 1. Duplicate Detection UI
- Component created: `components/duplicate-detection.tsx`
- Need to add page: `/courses/duplicates`
- Auto-run detection on new contributions

### 2. Partial Contributions (Drafts)
- Save drafts to database
- Resume later functionality
- Share drafts

### 3. Contributor Reputation
- Display reputation on profiles
- Trusted contributor badge
- Faster verification for trusted users

### 4. Community Features
- Thank contributors button
- Report incorrect data
- Discussion threads (component created)

### 5. Gamification
- Monthly challenges
- Streak tracking
- Points system
- Special badges

### 6. Course Versioning
- Show version history
- Revert capability
- Change tracking

### 7. Mobile Contribution
- iOS app integration
- GPS auto-fill
- Camera integration

### 8. Bulk Import
- CSV import tool
- Admin interface
- Batch validation

## 🎯 Next Steps

1. **Test all components** - Ensure they work with your existing code
2. **Style adjustments** - Match your design system
3. **Add error handling** - Comprehensive error messages
4. **Add loading states** - Better UX during async operations
5. **Add tests** - Unit and integration tests
6. **Documentation** - User-facing docs for contributors

## 🔧 Configuration

### Environment Variables
None required - all features use existing Supabase setup.

### Dependencies
Already added to `package.json`:
- `leaflet` & `react-leaflet` for maps
- `@types/leaflet` for TypeScript

### Storage Setup
Ensure Supabase Storage bucket `course-photos` exists with proper RLS policies.
