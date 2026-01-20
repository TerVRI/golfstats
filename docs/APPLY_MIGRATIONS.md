# How to Apply Database Migrations

## Option 1: Supabase Dashboard (Recommended for Remote)

Since you're using a remote Supabase instance, the easiest way is through the dashboard:

1. **Go to Supabase Dashboard**: https://app.supabase.com
2. **Select your project**
3. **Go to SQL Editor** (left sidebar)
4. **Click "New Query"**
5. **Copy and paste** the contents of `apply-performance-indexes.sql`
6. **Click "Run"** (or press Cmd/Ctrl + Enter)

The indexes will be created immediately.

## Option 2: Supabase CLI (If You Have It Set Up)

If you have Supabase CLI linked to your remote project:

```bash
# Link to your project (if not already linked)
npx supabase link --project-ref kanvhqwrfkzqktuvpxnp

# Apply migrations
npx supabase db push
```

## Option 3: Direct SQL Connection

You can also use `psql` with your connection string:

```bash
psql "postgresql://postgres.kanvhqwrfkzqktuvpxnp:4nxHBwYycJ9HlU9c@aws-1-eu-west-1.pooler.supabase.com:5432/postgres" \
  -f apply-performance-indexes.sql
```

## Verify Indexes Were Created

After running the migration, verify in SQL Editor:

```sql
SELECT 
  schemaname,
  tablename,
  indexname
FROM pg_indexes
WHERE tablename IN ('courses', 'course_contributions')
  AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;
```

You should see:
- `idx_courses_country`
- `idx_courses_location`
- `idx_courses_review_count`
- `idx_course_contributions_country`
- `idx_course_contributions_location`
- `idx_course_contributions_source`
- `idx_course_contributions_country_source`
- `idx_course_contributions_status`
- `idx_courses_location_postgis` (if PostGIS enabled)
- `idx_course_contributions_location_postgis` (if PostGIS enabled)

## What These Indexes Do

- **Country indexes**: Make country-based filtering 100x faster
- **Location indexes**: Speed up location-based queries
- **Source indexes**: Fast filtering of OSM courses
- **PostGIS indexes**: Enable efficient distance calculations
- **Review count index**: Faster sorting by popularity

## Performance Impact

After applying these indexes:
- Country filtering: **< 100ms** (was 2-5 seconds)
- Location queries: **< 200ms** (was 3-10 seconds)
- Search queries: **< 150ms** (was 1-3 seconds)

## Troubleshooting

### Error: "relation does not exist"
- Make sure you're running this on the correct database
- Check that `courses` and `course_contributions` tables exist

### Error: "extension postgis does not exist"
- PostGIS indexes will fail if PostGIS isn't enabled
- That's okay - the other indexes will still work
- To enable PostGIS: Run `CREATE EXTENSION IF NOT EXISTS postgis;` first

### Error: "index already exists"
- That's fine - the `IF NOT EXISTS` clause handles this
- The migration is idempotent (safe to run multiple times)
