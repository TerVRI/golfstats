# OpenStreetMap Golf Course Import Guide

## Overview

This guide explains how to import all OpenStreetMap golf courses into your database to provide a comprehensive starting dataset for users.

## Statistics

Based on research, OpenStreetMap contains approximately **38,000-38,800 golf courses** worldwide. The distribution by country is roughly:

### Top Countries (Estimated)

| Country | Estimated Courses |
|---------|-------------------|
| United States | ~16,700 |
| Japan | ~3,100 |
| Canada | ~2,600-2,700 |
| England | ~2,200-2,300 |
| Australia | ~1,600 |
| Germany | ~1,050 |
| France | ~800 |
| South Korea | ~780-800 |
| Sweden | ~650 |
| Spain | ~400-500 |
| Italy | ~300-400 |
| Netherlands | ~200-300 |
| And many more... | |

**Note:** These are estimates based on global golf course data. The actual OSM coverage may vary by country.

## Getting Statistics

To get the exact count of golf courses in OSM by country:

```bash
npx tsx scripts/get-osm-golf-statistics.ts
```

This script will:
1. Query OpenStreetMap for all golf courses globally
2. Group them by country
3. Display statistics
4. Save results to `osm-golf-statistics.json`

**Warning:** This query can take 5-10 minutes as it fetches all courses globally.

## Importing Courses

### Prerequisites

1. **Environment Variables:**
   ```bash
   export SUPABASE_URL="https://your-project.supabase.co"
   export SUPABASE_SERVICE_KEY="your-service-role-key"
   export SYSTEM_CONTRIBUTOR_ID="uuid-of-system-user"  # Optional
   ```

2. **System User:**
   - Create a system user account in your database
   - Use this user's ID as `SYSTEM_CONTRIBUTOR_ID`
   - Or the script will use a placeholder UUID

3. **Database Schema:**
   - Ensure `course_contributions` table exists
   - Ensure it has `osm_id` and `osm_type` columns (or add them)

### Running the Import

```bash
npx tsx scripts/import-osm-courses.ts
```

### What the Script Does

1. **Fetches All Courses:**
   - Queries OpenStreetMap Overpass API
   - Gets all features tagged `leisure=golf_course`
   - Includes ways, relations, and nodes
   - Extracts geometry data

2. **Converts to Database Format:**
   - Maps OSM tags to your schema
   - Extracts name, address, location, contact info
   - Converts geometry to GeoJSON
   - Sets source as "osm"

3. **Imports to Database:**
   - Inserts in batches of 100
   - Skips courses that already exist (by `osm_id`)
   - Sets status as "pending" (requires confirmation)
   - Handles rate limiting

### Import Options

The script supports:
- **Skip Existing:** Automatically skips courses already in database
- **Batch Processing:** Processes in batches to avoid overwhelming API/DB
- **Error Handling:** Continues on errors, reports summary

### After Import

1. **Review Imported Courses:**
   ```sql
   SELECT COUNT(*) FROM course_contributions WHERE source = 'osm';
   SELECT country, COUNT(*) 
   FROM course_contributions 
   WHERE source = 'osm' 
   GROUP BY country 
   ORDER BY COUNT(*) DESC;
   ```

2. **Verify Data:**
   - Check for duplicates
   - Verify coordinates are valid
   - Review course names

3. **Approve Courses:**
   - Courses are imported with `status = 'pending'`
   - You can bulk approve verified courses:
   ```sql
   UPDATE course_contributions 
   SET status = 'approved' 
   WHERE source = 'osm' 
   AND latitude IS NOT NULL 
   AND longitude IS NOT NULL;
   ```

4. **Merge into Main Courses Table:**
   - Use your existing approval workflow
   - Or create a migration to auto-approve OSM courses

## Database Schema Updates

If your `course_contributions` table doesn't have `osm_id` and `osm_type` columns, add them:

```sql
ALTER TABLE public.course_contributions
ADD COLUMN IF NOT EXISTS osm_id TEXT,
ADD COLUMN IF NOT EXISTS osm_type TEXT;

CREATE INDEX IF NOT EXISTS idx_course_contributions_osm_id 
ON public.course_contributions(osm_id) 
WHERE osm_id IS NOT NULL;
```

## Rate Limiting

The Overpass API has rate limits:
- **Recommended:** 1 request per second
- **Timeout:** 3 minutes for global queries
- **Best Practice:** Use batching and delays

The import script includes:
- 500ms delay between batches
- Batch size of 100 courses
- Error handling for timeouts

## Data Quality

### What OSM Provides

✅ **Good Coverage:**
- Course names
- Locations (lat/lon)
- Basic address info
- Some contact details
- Geometry (for ways/relations)

❌ **Missing:**
- Hole-level data
- Course ratings
- Par information
- Detailed GPS coordinates
- Photos

### Post-Import Enhancement

After importing, you can:
1. **Enrich with User Contributions:**
   - Users can add hole data
   - Add photos
   - Confirm/update information

2. **Auto-approve High-Quality:**
   - Courses with complete addresses
   - Courses with geometry
   - Courses in well-mapped regions

3. **Flag for Review:**
   - Courses without names
   - Courses with invalid coordinates
   - Duplicate entries

## Monitoring

Track import progress:

```sql
-- Total imported
SELECT COUNT(*) FROM course_contributions WHERE source = 'osm';

-- By country
SELECT country, COUNT(*) 
FROM course_contributions 
WHERE source = 'osm' 
GROUP BY country 
ORDER BY COUNT(*) DESC 
LIMIT 20;

-- By status
SELECT status, COUNT(*) 
FROM course_contributions 
WHERE source = 'osm' 
GROUP BY status;

-- With geometry
SELECT COUNT(*) 
FROM course_contributions 
WHERE source = 'osm' 
AND geojson_data IS NOT NULL;
```

## Troubleshooting

### Timeout Errors

If the global query times out:
1. Import by country/region instead
2. Use smaller bounding boxes
3. Increase timeout in script

### Duplicate Courses

Check for duplicates:
```sql
SELECT osm_id, COUNT(*) 
FROM course_contributions 
WHERE osm_id IS NOT NULL 
GROUP BY osm_id 
HAVING COUNT(*) > 1;
```

### Missing Data

Many OSM courses may be missing:
- Names (use "Unnamed Golf Course")
- Addresses
- Contact information

This is normal - users can fill in gaps.

## Next Steps

1. **Run Statistics Script:**
   ```bash
   npx tsx scripts/get-osm-golf-statistics.ts
   ```

2. **Review Results:**
   - Check `osm-golf-statistics.json`
   - Verify country breakdown

3. **Run Import:**
   ```bash
   SUPABASE_URL=... SUPABASE_SERVICE_KEY=... npx tsx scripts/import-osm-courses.ts
   ```

4. **Review and Approve:**
   - Check imported courses
   - Approve high-quality entries
   - Flag issues for review

5. **Monitor Usage:**
   - Track which courses users interact with
   - Prioritize enhancements for popular courses

## Notes

- **Import Time:** Full global import can take 30-60 minutes
- **Database Size:** ~38,000 courses = ~50-100MB of data
- **Maintenance:** Re-run periodically to catch new OSM additions
- **Attribution:** Remember to credit OpenStreetMap contributors

## License

OpenStreetMap data is licensed under ODbL. Ensure your use complies with the license terms.
