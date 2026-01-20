-- Storage Bucket Verification Script
-- Run this in Supabase SQL Editor to verify storage setup

-- 1. Check if bucket exists
SELECT 
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types,
    created_at
FROM storage.buckets 
WHERE name ILIKE '%course-photos%';

-- 2. Check storage policies
SELECT 
    policyname,
    cmd,
    roles,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND (
      policyname LIKE '%course-photos%' 
      OR qual::text LIKE '%course-photos%'
      OR with_check::text LIKE '%course-photos%'
  )
ORDER BY policyname, cmd;

-- 3. Verify RLS is enabled
SELECT 
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'storage' 
  AND tablename = 'objects';

-- 4. Expected policies summary
-- Should have 3 policies:
-- 1. "Allow authenticated uploads" - INSERT - authenticated
-- 2. "Allow public read access" - SELECT - public
-- 3. "Allow users to delete own uploads" - DELETE - authenticated

-- 5. Check for any duplicate policies
SELECT 
    policyname,
    COUNT(*) as count,
    array_agg(DISTINCT cmd) as commands
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND policyname LIKE '%course-photos%'
GROUP BY policyname
HAVING COUNT(*) > 1;

-- If bucket doesn't exist, create it:
/*
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'course-photos',
    'course-photos',
    true,
    5242880, -- 5 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE
SET 
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
*/
