-- Simple verification queries
-- Run each query separately in Supabase SQL Editor

-- 1. Check new tables exist (should return 11 rows)
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN (
  'contributor_reputation',
  'course_versions',
  'course_duplicates',
  'notifications',
  'course_discussions',
  'discussion_replies',
  'contributor_thanks',
  'contribution_challenges',
  'user_challenge_progress',
  'point_transactions',
  'duplicate_votes'
)
ORDER BY table_name;

-- 2. Check course_contributions new columns (should return 4 rows)
SELECT column_name 
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'course_contributions'
AND column_name IN ('photos', 'is_draft', 'completeness_score', 'missing_fields');

-- 3. Check courses new columns (should return 4 rows)
SELECT column_name 
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'courses'
AND column_name IN ('completeness_score', 'missing_critical_fields', 'current_version', 'last_updated_by');

-- 4. Check profiles new columns (should return 4 rows)
SELECT column_name 
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'profiles'
AND column_name IN ('contribution_points', 'contribution_streak_days', 'last_contribution_date', 'longest_streak_days');
