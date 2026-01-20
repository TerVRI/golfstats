# Complete Setup Steps for OSM Import

## Step 1: Apply Performance Indexes ✅

**Why first?** The indexes will make the import faster and queries efficient from the start.

1. Go to https://app.supabase.com
2. Select your project
3. SQL Editor → New Query
4. Copy contents of `apply-performance-indexes.sql`
5. Paste and Run

**Time**: ~30 seconds

## Step 2: Run OSM Import Script ✅

**After indexes are created**, import all courses:

```bash
cd /Users/tmad/Documents/Coding/Cursor\ Projects/golfstats
npx tsx scripts/import-osm-courses.ts
```

**What it does:**
- Queries OpenStreetMap for all golf courses (~40,000)
- Converts to your database format
- Imports in batches of 100
- Skips duplicates automatically
- Shows progress

**Time**: 30-60 minutes (for ~40,000 courses)

**What you'll see:**
```
✅ Loaded environment variables from .env.local
Querying OpenStreetMap for all golf courses...
This may take several minutes...
Found 40491 golf courses in OpenStreetMap
Converting to database format...
Importing 40491 courses into database...
Processing batch 1/405...
  Imported 100 courses
...
Import Summary
Total courses: 40491
Imported: 40491
Skipped (already exist): 0
Errors: 0
```

## Step 3: Verify Import ✅

Check in Supabase SQL Editor:

```sql
-- Count total OSM courses
SELECT COUNT(*) FROM course_contributions WHERE source = 'osm';

-- Count by country
SELECT country, COUNT(*) 
FROM course_contributions 
WHERE source = 'osm' 
GROUP BY country 
ORDER BY COUNT(*) DESC 
LIMIT 20;

-- Count by status
SELECT status, COUNT(*) 
FROM course_contributions 
WHERE source = 'osm' 
GROUP BY status;
```

## Step 4: (Optional) Approve Courses ✅

All courses are imported with `status = 'pending'`. You can bulk approve:

```sql
-- Approve all OSM courses with valid coordinates
UPDATE course_contributions 
SET status = 'approved' 
WHERE source = 'osm' 
AND latitude IS NOT NULL 
AND longitude IS NOT NULL;
```

Or approve by country:
```sql
-- Approve courses from specific countries
UPDATE course_contributions 
SET status = 'approved' 
WHERE source = 'osm' 
AND country IN ('United States', 'Canada', 'United Kingdom')
AND latitude IS NOT NULL;
```

## Step 5: Test the Apps ✅

1. **Web App**: 
   - Go to `/courses` - should show courses from your country
   - Go to `/courses/osm-visualization` - should show the map

2. **iOS App**:
   - Open Courses view
   - Should show courses from your country by default
   - Fast load times!

## Troubleshooting

### Import fails with timeout
- The OSM query can take 5-10 minutes
- This is normal - just wait
- If it times out, the script will retry

### Import is slow
- Make sure indexes were created first
- The import uses batches, so it's normal to take 30-60 minutes

### No courses showing in app
- Check that courses were imported: `SELECT COUNT(*) FROM course_contributions WHERE source = 'osm';`
- Check that country detection is working
- Try the "Show all countries" toggle

### Duplicate courses
- The script automatically skips duplicates based on `osm_id`
- If you see duplicates, check: `SELECT osm_id, COUNT(*) FROM course_contributions WHERE osm_id IS NOT NULL GROUP BY osm_id HAVING COUNT(*) > 1;`

## Summary

1. ✅ Apply indexes (30 seconds)
2. ✅ Run import script (30-60 minutes)
3. ✅ Verify import (1 minute)
4. ✅ (Optional) Approve courses (1 minute)
5. ✅ Test apps (2 minutes)

**Total time**: ~35-65 minutes

After this, you'll have 40,000+ courses ready to use with fast, location-based filtering! 🚀
