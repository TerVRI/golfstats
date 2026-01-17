# Migration Instructions

## Running the Enhanced Course Features Migration

You have two options to run the migration:

### Option 1: Using Supabase CLI (Recommended) ⚡

This is the easiest and safest method. The migration will be applied to your remote database.

#### Step 1: Ensure you're in the project directory
```bash
cd "/Users/tmad/Documents/Coding/Cursor Projects/golfstats"
```

#### Step 2: Push the migration to your remote database

**Option A: Include all migrations (recommended if you have unapplied migrations)**
```bash
supabase db push --include-all
```

**Option B: Push only new migrations (if all previous are applied)**
```bash
supabase db push
```

This will:
- Apply all pending migrations (including `20260118000000_enhanced_course_features.sql`)
- Show you what will be applied before executing
- Apply changes to your remote Supabase project

**Note:** If you see a message about migrations that need to be inserted, use `--include-all` flag.

**Preview what will be applied:**
```bash
supabase db push --dry-run --include-all
```

#### Alternative: Apply specific migration
If you want to apply just this migration:
```bash
supabase migration up
```

---

### Option 2: Manual via Supabase Dashboard (Backup Method) 📝

If you prefer to run it manually or the CLI doesn't work:

#### Step 1: Open Supabase Dashboard
1. Go to [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. Select your **golfstats** project
3. Click on **SQL Editor** in the left sidebar

#### Step 2: Copy the migration SQL
1. Open the file: `supabase/migrations/20260118000000_enhanced_course_features.sql`
2. Copy the entire contents

#### Step 3: Run in SQL Editor
1. In the SQL Editor, paste the entire migration SQL
2. Click **Run** (or press Cmd+Enter / Ctrl+Enter)
3. Wait for it to complete (may take 30-60 seconds)

#### Step 4: Verify
Check that the migration ran successfully by running:
```sql
-- Check if new tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN (
  'contributor_reputation',
  'course_versions',
  'course_duplicates',
  'notifications',
  'course_discussions'
);

-- Should return 5 rows
```

---

### Option 3: Using Supabase CLI with specific project

If you need to specify the project explicitly:

```bash
# Link to your project (if not already linked)
supabase link --project-ref kanvhqwrfkzqktuvpxnp

# Push migrations
supabase db push
```

---

## What This Migration Does

This migration adds:

1. **Photo support** - Columns for storing photos with contributions
2. **Draft system** - Save and resume contributions later
3. **Reputation system** - Track contributor quality and trust
4. **Versioning** - Track course changes over time
5. **Duplicate detection** - Tables for detecting and merging duplicates
6. **Notifications** - System for user notifications
7. **Community features** - Discussions, replies, thank you system
8. **Gamification** - Challenges, streaks, points system
9. **Data completeness** - Scoring and tracking missing fields
10. **Auto-update functions** - Triggers and functions for automatic updates

## After Migration

### 1. Create Storage Bucket for Photos

In Supabase Dashboard:
1. Go to **Storage**
2. Click **New bucket**
3. Name: `course-photos`
4. Set to **Public** (or configure RLS policies)
5. Click **Create bucket**

### 2. Verify Migration Success

Run this query in SQL Editor:
```sql
-- Check all new tables
SELECT 
  schemaname,
  tablename
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN (
  'contributor_reputation',
  'course_versions',
  'course_duplicates',
  'duplicate_votes',
  'notifications',
  'course_discussions',
  'discussion_replies',
  'contributor_thanks',
  'contribution_challenges',
  'user_challenge_progress',
  'point_transactions'
)
ORDER BY tablename;
```

Should return 11 rows.

### 3. Test Functions

```sql
-- Test completeness calculation (will work once you have contributions)
SELECT calculate_contribution_completeness('some-uuid-here');

-- Test reputation update (will work once you have contributions)
SELECT update_contributor_reputation('some-user-uuid-here');
```

## Troubleshooting

### If migration fails:

1. **Check for existing columns/tables:**
   - The migration uses `IF NOT EXISTS` and `ADD COLUMN IF NOT EXISTS`
   - It should be safe to run multiple times
   - If you get errors, check what already exists

2. **Common issues:**
   - **Permission errors**: Make sure you're using the correct database user
   - **Syntax errors**: Check the SQL file for any issues
   - **Timeout**: Large migrations may timeout - run in smaller chunks if needed

3. **Rollback (if needed):**
   - Supabase doesn't have automatic rollback
   - You'll need to manually drop tables/columns if needed
   - Always backup before running migrations!

## Next Steps

After migration:
1. ✅ Create storage bucket for photos
2. ✅ Test the new features
3. ✅ Update your app to use the new components
4. ✅ Set up notification triggers (if using Edge Functions)

---

**Need help?** Check the integration guide: `docs/COURSE_FEATURES_INTEGRATION.md`
