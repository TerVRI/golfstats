# SQL Setup Order for OSM Import

## Required SQL Files (In Order)

Run these SQL files in Supabase SQL Editor **before** running the import script:

### 1. Add OSM Tracking Columns
**File:** `add-osm-columns.sql`

**What it does:**
- Adds `osm_id` and `osm_type` columns to `course_contributions`
- Creates indexes for fast lookups
- Prevents duplicate imports

**Run this first!** Without this, the import will fail.

### 2. Create RoundCaddy User
**File:** `create-system-user.sql`

**What it does:**
- Creates a special "RoundCaddy" user for OSM imports
- All imported courses will be credited to this user
- Email: `roundcaddy@roundcaddy.com`

**Note:** The profiles table uses `name` (not `full_name`), so this is already fixed.

### 3. Performance Indexes (Optional but Recommended)
**File:** `apply-performance-indexes.sql`

**What it does:**
- Creates indexes for fast country-based queries
- Creates location indexes
- Creates PostGIS spatial indexes

**Run this for better performance**, but not required for import.

## Quick Setup Checklist

1. ✅ **Run `add-osm-columns.sql`** in Supabase SQL Editor
2. ✅ **Run `create-system-user.sql`** in Supabase SQL Editor  
3. ✅ (Optional) **Run `apply-performance-indexes.sql`** for better performance
4. ✅ **Run the import script:** `npx tsx scripts/import-osm-courses.ts`

## Verification

After running the SQL files, verify:

```sql
-- Check OSM columns exist
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'course_contributions' 
  AND column_name IN ('osm_id', 'osm_type');

-- Check RoundCaddy user exists
SELECT id, email, name 
FROM public.profiles 
WHERE email = 'roundcaddy@roundcaddy.com';

-- Check indexes exist (optional)
SELECT indexname 
FROM pg_indexes 
WHERE tablename = 'course_contributions' 
  AND indexname LIKE 'idx_%';
```

## Common Issues

### Error: "column full_name does not exist"
- **Fixed!** The SQL now uses `name` instead of `full_name`

### Error: "osm_id column not found"
- Run `add-osm-columns.sql` first

### Error: "contributor_id foreign key violation"
- Run `create-system-user.sql` to create RoundCaddy user

## All Set!

Once you've run the SQL files above, you're ready to import:

```bash
npx tsx scripts/import-osm-courses.ts
```
