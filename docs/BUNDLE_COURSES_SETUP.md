# Course Bundle Setup Guide

This guide explains how to bundle course data in the iOS app for offline-first functionality.

## Overview

The app now includes a bundled JSON file with all basic course data (~9MB) that:
- Loads instantly on app launch
- Works completely offline
- Syncs updates in the background based on `updated_at` timestamps

## Setup Steps

### 1. Export Course Data

Run the export script to generate the bundle file:

```bash
cd /path/to/golfstats
npx tsx scripts/export-courses-for-bundle.ts
```

This will:
- Fetch all courses from Supabase (basic fields only, no `hole_data`)
- Create `apps/ios/GolfStats/Resources/courses-bundle.json`
- Show the file size (~9MB for 22,837 courses)

### 2. Add to Xcode Project

The JSON file should be automatically included if it's in the `GolfStats/Resources` folder. Verify:

1. Open Xcode project
2. Check that `courses-bundle.json` appears in the Resources folder
3. Ensure it's included in the app target (check Target Membership)

### 3. Build and Test

The app will:
- Load courses from bundle on first launch (instant, offline)
- Check for updates in background (every 24 hours)
- Merge updated courses with bundled data
- Cache merged results locally

## How It Works

### Initial Load
1. App launches → Loads `courses-bundle.json` from bundle (instant)
2. Checks local cache for previously merged data
3. Displays courses immediately (no network required)

### Background Sync
1. Checks if 24+ hours since last sync
2. Fetches only courses with `updated_at > last_sync_date`
3. Merges updates with bundled courses
4. Caches merged result
5. Updates UI if not filtering/searching

### Update Process
- Only downloads courses that changed since last sync
- Typical sync: 0-50 courses (very small, ~50-200KB)
- Full sync only on first run or after 30+ days

## Updating the Bundle

When you add new courses or make significant updates:

1. **Run export script** to regenerate bundle:
   ```bash
   npx tsx scripts/export-courses-for-bundle.ts
   ```

2. **Commit the new JSON file** to git

3. **Users will get updates**:
   - New app version includes new bundle
   - Background sync handles incremental updates

## File Structure

```
apps/ios/GolfStats/Resources/
  └── courses-bundle.json
      ├── metadata
      │   ├── export_date
      │   ├── total_courses
      │   └── version
      └── courses[]
          ├── id
          ├── name
          ├── city, state, country
          ├── coordinates
          ├── ratings
          └── ... (no hole_data)
```

## Size Estimates

- **Basic course data**: ~400 bytes per course
- **22,837 courses**: ~9 MB uncompressed
- **With compression**: ~3-4 MB (iOS handles this automatically)
- **Sync updates**: ~50-200 KB per sync (only changed courses)

## Benefits

✅ **Instant app launch** - No waiting for network  
✅ **Works offline** - Full course search/browse without internet  
✅ **Efficient updates** - Only downloads what changed  
✅ **Small syncs** - Background updates are tiny  
✅ **Better UX** - Courses appear immediately  

## Troubleshooting

### Bundle not found
- Check file is in `GolfStats/Resources/` folder
- Verify it's included in Xcode target
- Check file name is exactly `courses-bundle.json`

### Sync not working
- Check network connection
- Verify `updated_at` column exists in courses table
- Check console logs for sync errors

### Large bundle size
- Ensure `hole_data` is excluded from export
- Check for unnecessary fields in export query
- Consider splitting by region if needed
