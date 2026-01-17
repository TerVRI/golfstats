# Next Steps After Migration

## ✅ Migration Complete!

All 11 new tables have been created successfully. Here's what to do next:

---

## 1. Create Storage Bucket for Photos 📸

### In Supabase Dashboard:

1. Go to **Storage** in the left sidebar
2. Click **New bucket**
3. Configure:
   - **Name:** `course-photos`
   - **Public bucket:** ✅ Check this (or configure RLS policies)
   - Click **Create bucket**

### Set Up RLS Policies (if bucket is not public):

```sql
-- Allow authenticated users to upload
CREATE POLICY "Users can upload course photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'course-photos');

-- Allow anyone to view photos
CREATE POLICY "Anyone can view course photos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'course-photos');

-- Allow users to delete their own uploads
CREATE POLICY "Users can delete own photos"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'course-photos' AND auth.uid()::text = (storage.foldername(name))[1]);
```

---

## 2. Install Dependencies 📦

Make sure you have the new packages installed:

```bash
cd apps/web
npm install
```

This will install:
- `leaflet` - Map library
- `react-leaflet` - React components for maps
- `@types/leaflet` - TypeScript types

---

## 3. Test the Features 🧪

### Quick Test Checklist:

- [ ] **Map Editor** - Try the course contribution page with map
- [ ] **Photo Upload** - Test uploading a photo
- [ ] **OSM Auto-fill** - Test importing from OpenStreetMap
- [ ] **Data Validation** - Submit a course and see validation warnings
- [ ] **Notifications** - Check if notification system works
- [ ] **Discussions** - Try creating a discussion on a course

---

## 4. Integrate Components into Your App 🔌

### Add to Course Contribution Page

Update `apps/web/src/app/(app)/courses/contribute/page.tsx`:

1. Import the new components:
```tsx
import { CourseMapEditor } from "@/components/course-map-editor";
import { PhotoUpload } from "@/components/photo-upload";
import { OSMAutofill } from "@/components/osm-autofill";
import { DataCompletenessIndicator } from "@/components/data-completeness-indicator";
import { validateCourseData } from "@/lib/course-validation";
```

2. Add state for photos and map markers
3. Add the components to your form
4. Add validation before submission

See `docs/COURSE_FEATURES_INTEGRATION.md` for detailed integration steps.

---

## 5. Add Notification Bell to Layout 🔔

Update your main layout/navbar:

```tsx
import { NotificationBell } from "@/components/notifications";

// In your navbar component
<NotificationBell />
```

---

## 6. Create Notifications Page 📄

Create `apps/web/src/app/(app)/notifications/page.tsx`:

```tsx
import { NotificationsCenter } from "@/components/notifications";

export default function NotificationsPage() {
  return <NotificationsCenter />;
}
```

---

## 7. Add Discussions to Course Detail Page 💬

Update `apps/web/src/app/(app)/courses/[id]/page.tsx`:

```tsx
import { CourseDiscussions } from "@/components/course-discussions";

// Add to your course detail page
<CourseDiscussions courseId={course.id} />
```

---

## 8. Test End-to-End Flow 🎯

1. **Contribute a Course:**
   - Go to `/courses/contribute`
   - Use OSM auto-fill to import basic info
   - Use map editor to place markers
   - Upload photos
   - Submit

2. **Confirm a Course:**
   - Go to a course detail page
   - Click "Confirm Course Data"
   - Fill out confirmation form
   - Submit

3. **Check Notifications:**
   - Should see notification when course is confirmed
   - Check notification center

4. **Start Discussion:**
   - Go to course detail page
   - Ask a question in discussions
   - Reply to discussions

---

## 9. Optional: Set Up Auto-Notifications 🔔

To automatically send notifications when events happen, you can:

### Option A: Use Database Triggers (Already Set Up)

The migration includes functions that can trigger notifications. You may want to add Edge Functions or use Supabase Realtime to send notifications.

### Option B: Add Notification Triggers

Add triggers to automatically create notifications:

```sql
-- Example: Notify when course is verified
CREATE OR REPLACE FUNCTION notify_course_verified()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_verified = TRUE AND OLD.is_verified = FALSE THEN
    INSERT INTO notifications (user_id, type, title, message, course_id)
    SELECT 
      contributed_by,
      'course_verified',
      'Course Verified!',
      'Your contributed course "' || NEW.name || '" has been verified!',
      NEW.id
    FROM courses
    WHERE id = NEW.id AND contributed_by IS NOT NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER course_verified_notification
  AFTER UPDATE ON courses
  FOR EACH ROW
  WHEN (NEW.is_verified IS DISTINCT FROM OLD.is_verified)
  EXECUTE FUNCTION notify_course_verified();
```

---

## 10. Monitor & Debug 🐛

### Check Logs:
- Supabase Dashboard → Logs
- Check for any errors in function execution

### Test Database Functions:
```sql
-- Test completeness calculation
SELECT calculate_contribution_completeness('some-contribution-id');

-- Test reputation update
SELECT update_contributor_reputation('some-user-id');
```

---

## 🎉 You're Ready!

All the infrastructure is in place. Now you can:

1. ✅ Start using the map-based course editor
2. ✅ Upload photos with contributions
3. ✅ Use OSM auto-fill
4. ✅ Get smart suggestions
5. ✅ Track contributor reputation
6. ✅ Enable community discussions
7. ✅ Send notifications

**Need help?** Check `docs/COURSE_FEATURES_INTEGRATION.md` for detailed integration examples.
