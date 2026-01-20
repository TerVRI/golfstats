# How to Run the OSM Import Script

## Location

Run the script from the **project root directory**:

```bash
cd /Users/tmad/Documents/Coding/Cursor\ Projects/golfstats
```

## Getting Your Supabase Credentials

### Option 1: From Supabase Dashboard

1. Go to your Supabase project dashboard: https://app.supabase.com
2. Click on your project
3. Go to **Settings** → **API**
4. Copy:
   - **Project URL** → This is your `SUPABASE_URL`
   - **service_role key** (not the anon key!) → This is your `SUPABASE_SERVICE_KEY`

⚠️ **Important**: Use the `service_role` key, not the `anon` key. The service role key has admin privileges needed to insert data.

### Option 2: From Environment File

If you have a `.env` file in the project root or `apps/web/.env.local`, you can check there:

```bash
# Look for these variables
SUPABASE_URL=...
SUPABASE_SERVICE_KEY=...
```

## Running the Script

### Method 1: Inline Environment Variables (Recommended)

From the project root directory:

```bash
SUPABASE_URL="https://your-project.supabase.co" \
SUPABASE_SERVICE_KEY="your-service-role-key-here" \
npx tsx scripts/import-osm-courses.ts
```

### Method 2: Export Variables First

```bash
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_SERVICE_KEY="your-service-role-key-here"
npx tsx scripts/import-osm-courses.ts
```

### Method 3: Create a .env File (Optional)

Create a `.env` file in the project root:

```bash
# .env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key-here
```

Then run:
```bash
source .env
npx tsx scripts/import-osm-courses.ts
```

## Full Example

```bash
# Navigate to project root
cd /Users/tmad/Documents/Coding/Cursor\ Projects/golfstats

# Run the import (replace with your actual values)
SUPABASE_URL="https://abcdefghijklmnop.supabase.co" \
SUPABASE_SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
npx tsx scripts/import-osm-courses.ts
```

## What to Expect

The script will:
1. ✅ Query OpenStreetMap for all golf courses (~40,000 courses)
2. ✅ Convert them to your database format
3. ✅ Import them in batches of 100
4. ✅ Skip courses that already exist
5. ✅ Show progress and summary

**Time**: This will take 30-60 minutes for ~40,000 courses.

**Output**: You'll see progress messages like:
```
Querying OpenStreetMap for all golf courses...
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

## Troubleshooting

### Error: "SUPABASE_URL and SUPABASE_SERVICE_KEY must be set"
- Make sure you're setting the environment variables correctly
- Check that there are no extra spaces or quotes issues

### Error: "Permission denied" or "RLS policy violation"
- Make sure you're using the **service_role** key, not the anon key
- The service_role key bypasses RLS policies

### Error: "Connection timeout"
- The OSM query can take 5-10 minutes
- This is normal - just wait for it to complete

### Error: "Too many requests"
- The script includes rate limiting (500ms between batches)
- If you still get this, you can increase the delay in the script

## After Import

Once the import completes:

1. **Check the database:**
   ```sql
   SELECT COUNT(*) FROM course_contributions WHERE source = 'osm';
   ```

2. **View the visualization:**
   - Go to `/courses/osm-visualization` in your app
   - Or click "OSM Map" on the courses page

3. **Approve courses (optional):**
   ```sql
   UPDATE course_contributions 
   SET status = 'approved' 
   WHERE source = 'osm' 
   AND latitude IS NOT NULL 
   AND longitude IS NOT NULL;
   ```

## Notes

- The script automatically skips duplicates (based on `osm_id`)
- All courses are imported with `status = 'pending'`
- You can re-run the script - it will only import new courses
- The script filters out courses without valid coordinates
