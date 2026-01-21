# Production Migration Steps

This document outlines the SQL migrations that need to be applied to your production Supabase database.

## Prerequisites

1. Access to your Supabase project dashboard
2. Navigate to **SQL Editor** in your Supabase dashboard

## Migration Order

Apply these migrations in order. Each migration is idempotent (safe to run multiple times).

### 1. Storage Bucket Setup (if not already done)

Run `verify_storage_setup.sql` first to check current status:

```sql
-- Check if course-photos bucket exists
SELECT * FROM storage.buckets WHERE id = 'course-photos';
```

If missing, create it:

```sql
-- Create the bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('course-photos', 'course-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Allow public read access
CREATE POLICY "Anyone can view course photos"
ON storage.objects FOR SELECT
USING (bucket_id = 'course-photos');

-- Allow authenticated users to upload
CREATE POLICY "Authenticated users can upload course photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'course-photos');
```

### 2. Incomplete Courses System

**File:** `supabase/migrations/20260121000000_incomplete_courses.sql`

This adds the incomplete courses tracking system:
- Incomplete course metadata fields
- Data completeness tracking

### 3. Badges System

**File:** `supabase/migrations/20260121000001_badges_system.sql`

This adds the gamification system:
- `user_badges` table
- `badge_definitions` reference data
- Badge calculation functions
- Auto-award triggers

### 4. Nearby Courses PostGIS Function

**File:** `supabase/migrations/20260122000000_nearby_courses_function.sql`

This adds the optimized nearby courses search:
- `get_nearby_courses()` function using PostGIS
- Efficient distance-based course queries

## Quick Apply All

Copy and paste all migrations into the SQL Editor, or run them one by one:

```bash
# From project root, concatenate all pending migrations
cat supabase/migrations/20260121000000_incomplete_courses.sql \
    supabase/migrations/20260121000001_badges_system.sql \
    supabase/migrations/20260122000000_nearby_courses_function.sql
```

## Verification

After applying migrations, verify they worked:

```sql
-- Check badges table exists
SELECT COUNT(*) FROM badge_definitions;

-- Check nearby courses function exists
SELECT proname FROM pg_proc WHERE proname = 'get_nearby_courses';

-- Test nearby courses (example: San Francisco area)
SELECT * FROM get_nearby_courses(37.7749, -122.4194, 25, 5);
```

## Rollback (if needed)

To rollback, you can drop the created objects:

```sql
-- Rollback badges (careful - this deletes user badges!)
-- DROP TABLE IF EXISTS user_badges CASCADE;
-- DROP TABLE IF EXISTS badge_definitions CASCADE;
-- DROP FUNCTION IF EXISTS calculate_user_badges CASCADE;
-- DROP FUNCTION IF EXISTS award_badge CASCADE;
-- DROP FUNCTION IF EXISTS check_and_award_completion_badges CASCADE;

-- Rollback nearby courses function
-- DROP FUNCTION IF EXISTS get_nearby_courses CASCADE;
```

## Environment Variables

Make sure these are set in your deployment:

```env
NEXT_PUBLIC_SUPABASE_URL=your-project-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key (for server-side)
```

## Post-Migration Testing

1. **Web App:**
   - Go to `/courses/incomplete` - should show incomplete courses
   - Go to `/profile/badges` - should show badge progress
   - Try contributing a course - should create contribution

2. **iOS App:**
   - Open Courses tab - should load courses
   - Try "Nearby Courses" - should use PostGIS query
   - Try contributing a course - should work

3. **Watch App:**
   - Start a round - motion detection should work
   - Swing should be detected with haptic feedback

## Troubleshooting

### PostGIS not enabled
```sql
-- Enable PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;
```

### Function permission errors
```sql
-- Grant permissions
GRANT EXECUTE ON FUNCTION get_nearby_courses TO anon, authenticated;
```

### Storage bucket 403 errors
Check the storage policies are correctly applied:
```sql
SELECT * FROM storage.policies WHERE bucket_id = 'course-photos';
```
