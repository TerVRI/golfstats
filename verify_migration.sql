-- Verification query for migration
-- Run this in Supabase SQL Editor to verify all tables were created

-- Query 1: Check if all new tables exist
SELECT 
  table_name,
  CASE 
    WHEN table_name IN (
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
    ) THEN 'Created'
    ELSE 'Missing'
  END as status
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

-- Query 2: Check that course_contributions table has new columns
SELECT 
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'course_contributions'
AND column_name IN ('photos', 'is_draft', 'completeness_score', 'missing_fields')
ORDER BY column_name;

-- Query 3: Check that courses table has new columns
SELECT 
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'courses'
AND column_name IN ('completeness_score', 'missing_critical_fields', 'current_version', 'last_updated_by')
ORDER BY column_name;

-- Query 4: Check that profiles table has new columns for gamification
SELECT 
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'profiles'
AND column_name IN ('contribution_points', 'contribution_streak_days', 'last_contribution_date', 'longest_streak_days')
ORDER BY column_name;
