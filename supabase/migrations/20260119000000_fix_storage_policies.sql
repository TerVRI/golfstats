-- Fix Storage Policies for course-photos bucket
-- This migration removes duplicate policies and ensures correct setup

-- First, let's see what policies exist (for reference)
-- Run this separately to see current policies:
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
-- FROM pg_policies 
-- WHERE tablename = 'objects' AND schemaname = 'storage'
-- AND policyname LIKE '%course-photos%' OR qual::text LIKE '%course-photos%';

-- Remove duplicate policy if it exists
-- This removes any policy named "Allow users to delete own uploads" that has SELECT command
-- (The correct one should have DELETE command)
DO $$
DECLARE
    policy_to_drop RECORD;
BEGIN
    -- Find policies on storage.objects that match the duplicate pattern
    FOR policy_to_drop IN
        SELECT policyname, schemaname, tablename
        FROM pg_policies
        WHERE schemaname = 'storage'
          AND tablename = 'objects'
          AND policyname LIKE '%delete own uploads%'
          AND cmd = 'SELECT'  -- This is the duplicate - should be DELETE
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', policy_to_drop.policyname);
        RAISE NOTICE 'Dropped duplicate policy: %', policy_to_drop.policyname;
    END LOOP;
END $$;

-- Ensure RLS is enabled on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Verify bucket exists (create if it doesn't - though it should already exist)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'course-photos',
    'course-photos',
    true,
    5242880, -- 5 MB in bytes
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE
SET 
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

-- Ensure correct policies exist (drop and recreate to ensure they're correct)
-- This ensures we have exactly the right policies

-- Drop existing policies for course-photos (we'll recreate them)
DROP POLICY IF EXISTS "Allow authenticated uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read access" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to delete own uploads" ON storage.objects;

-- Policy 1: Allow authenticated users to upload
CREATE POLICY "Allow authenticated uploads"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'course-photos'::text);

-- Policy 2: Allow public read access
CREATE POLICY "Allow public read access"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'course-photos'::text);

-- Policy 3: Allow users to delete their own uploads
CREATE POLICY "Allow users to delete own uploads"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'course-photos'::text 
    AND auth.uid()::text = (storage.objects.owner_id)::text
);

-- Verify the setup
DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND (
          policyname LIKE '%course-photos%' 
          OR qual::text LIKE '%course-photos%'
          OR with_check::text LIKE '%course-photos%'
      );
    
    RAISE NOTICE 'Total policies for course-photos bucket: %', policy_count;
    
    IF policy_count != 3 THEN
        RAISE WARNING 'Expected 3 policies, found %. Please verify manually.', policy_count;
    ELSE
        RAISE NOTICE '✅ Storage policies correctly configured!';
    END IF;
END $$;
