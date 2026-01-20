# Incomplete Courses - Next Steps

## ✅ Database Migration Applied

The database schema has been successfully updated with:
- New status types: `incomplete`, `needs_location`, `needs_verification`
- New fields: `completion_priority`, `missing_fields`, `geocoded`, `completed_by`, etc.
- Indexes for efficient queries

## Testing the System

### 1. Test the UI

1. **Navigate to Incomplete Courses Page**
   - Go to `/courses/incomplete` in your web app
   - You should see the list page (empty if no incomplete courses yet)

2. **Test Course Completion Flow**
   - If you have incomplete courses, click "Complete Course"
   - Test the map interface
   - Test geocoding functionality
   - Submit a completion

### 2. Create Test Incomplete Course

You can manually create a test incomplete course in Supabase:

```sql
-- Insert a test incomplete course
INSERT INTO public.course_contributions (
  contributor_id,
  name,
  city,
  country,
  address,
  status,
  completion_priority,
  missing_fields,
  source
) VALUES (
  (SELECT id FROM public.profiles LIMIT 1), -- Use any user ID
  'Test Golf Course',
  'Test City',
  'US',
  '123 Test Street',
  'incomplete',
  10,
  ARRAY['latitude', 'longitude'],
  'osm'
);
```

### 3. Import Incomplete Courses (Optional)

When ready, you can run the import script to find and import incomplete courses from OSM:

```bash
npx tsx scripts/import-incomplete-courses.ts
```

**Note:** This script currently queries sample regions. Most OSM courses have coordinates, so you may not find many incomplete courses.

## What Works Now

✅ **Browse Incomplete Courses**
- List page at `/courses/incomplete`
- Search and filter functionality
- Priority badges

✅ **Complete Courses**
- Interactive map for setting location
- Geocoding integration
- Form for additional data
- Submit to mark as "needs_verification"

✅ **Database Support**
- All new fields and statuses
- Indexes for performance
- Foreign key relationships

## What's Next (Optional Enhancements)

### Badges System
- Create `user_badges` table
- Badge calculation logic
- Badge display in profile

### Leaderboards
- Create leaderboard page
- Query top completers
- Monthly vs all-time views

### Competitions
- Competition data model
- Competition pages
- Progress tracking

## Troubleshooting

### No Incomplete Courses Showing
- This is normal if you haven't imported any yet
- Create a test course using the SQL above
- Or wait until you import incomplete courses from OSM

### Geocoding Not Working
- Check browser console for errors
- Nominatim (OpenStreetMap) has rate limits
- For production, consider using Google Geocoding API

### Map Not Loading
- Ensure Leaflet is installed: `npm install leaflet @types/leaflet`
- Check browser console for errors
- Map loads client-side only (no SSR)

## Production Considerations

1. **Geocoding Service**
   - Current: OpenStreetMap Nominatim (free, rate-limited)
   - Production: Consider Google Geocoding API or similar
   - Update `geocodeAddress()` in `lib/incomplete-courses.ts`

2. **Rate Limiting**
   - Add rate limiting for geocoding requests
   - Cache geocoding results
   - Consider server-side geocoding

3. **Verification Process**
   - Incomplete courses go to "needs_verification" status
   - Need approval workflow (admin or community)
   - Consider auto-approval for high-quality completions

4. **Gamification**
   - Badges system (next phase)
   - Leaderboards (next phase)
   - Competitions (next phase)

## Success! 🎉

Your incomplete courses system is now ready to use. Users can:
- Browse incomplete courses
- Complete them with location data
- Earn credit when approved

The foundation is in place for the full gamification system!
