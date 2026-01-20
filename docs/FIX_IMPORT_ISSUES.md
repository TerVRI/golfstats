# Fixing OSM Import Issues

## Issues Fixed

1. **SQL Error**: `function array_length(jsonb, integer) does not exist`
   - Fixed in `fix-array-length-error.sql`
   - The migration was using `array_length()` on a JSONB object, which doesn't work
   - Now uses proper JSONB checks

2. **Regional Import Strategy**
   - Script now imports regions incrementally (as they complete)
   - Skips regions that are already imported
   - Supports test mode to import 1 course per region first

## Steps to Fix and Import

### Step 1: Fix the Database Function

Run this SQL in Supabase SQL Editor:
```sql
-- Run: fix-array-length-error.sql
```

This fixes the `calculate_completeness_score` function that was causing import errors.

### Step 2: Test with One Course Per Region

Run the import script in test mode:
```bash
npx tsx scripts/import-osm-courses.ts --test
```

This will:
- Import 1 course from each region
- Verify the import works correctly
- Skip regions that are already imported

### Step 3: Full Import

Once test mode works, run the full import:
```bash
npx tsx scripts/import-osm-courses.ts
```

This will:
- Query all regions from OSM
- Import each region as it completes (incremental)
- Skip regions that are already imported
- Retry failed regions on next run

## How It Works Now

1. **Incremental Import**: Each region is imported immediately after querying, not waiting for all regions
2. **Skip Already Imported**: Checks if courses exist in a region's bounding box before querying
3. **Error Recovery**: If a region fails, you can re-run the script and it will only retry failed regions
4. **Test Mode**: Use `--test` flag to import just 1 course per region for verification

## Notes

- The script automatically loads `.env.local` if it exists
- Uses the RoundCaddy user for all OSM imports
- Duplicate courses (by `osm_id`) are automatically skipped
- Failed regions are logged and can be retried
