# Supabase Storage Bucket Setup Guide

This guide will help you set up the `course-photos` storage bucket in Supabase for the course contribution photo upload feature.

## Steps

### 1. Navigate to Storage in Supabase Dashboard

1. Go to your Supabase project dashboard
2. Click on **Storage** in the left sidebar
3. You should see a list of existing buckets (if any)

### 2. Create New Bucket

1. Click the **"New bucket"** button
2. Configure the bucket:
   - **Name:** `course-photos`
   - **Public bucket:** ✅ **Enable this** (so photos can be accessed via public URLs)
   - **File size limit:** 5 MB (or your preferred limit)
   - **Allowed MIME types:** 
     - `image/jpeg`
     - `image/png`
     - `image/webp`
     - `image/gif`

3. Click **"Create bucket"**

### 3. Set Up Storage Policies

After creating the bucket, you need to set up Row Level Security (RLS) policies to control access.

#### Policy 1: Allow Authenticated Users to Upload

1. Go to **Storage** → **Policies** → Select `course-photos` bucket
2. Click **"New policy"**
3. Choose **"For full customization"**
4. Configure:
   - **Policy name:** `Allow authenticated uploads`
   - **Allowed operation:** `INSERT`
   - **Policy definition:**
   ```sql
   (bucket_id = 'course-photos'::text) AND (auth.role() = 'authenticated'::text)
   ```
5. Click **"Review"** and **"Save policy"**

#### Policy 2: Allow Public Read Access

1. Click **"New policy"** again
2. Choose **"For full customization"**
3. Configure:
   - **Policy name:** `Allow public read access`
   - **Allowed operation:** `SELECT`
   - **Policy definition:**
   ```sql
   (bucket_id = 'course-photos'::text)
   ```
4. Click **"Review"** and **"Save policy"**

#### Policy 3: Allow Users to Delete Their Own Uploads

1. Click **"New policy"** again
2. Choose **"For full customization"**
3. Configure:
   - **Policy name:** `Allow users to delete own uploads`
   - **Allowed operation:** `DELETE`
   - **Policy definition:**
   ```sql
   (bucket_id = 'course-photos'::text) AND (auth.uid()::text = (storage.objects.owner_id)::text)
   ```
4. Click **"Review"** and **"Save policy"**

### 4. Verify Setup

You can verify the setup by:

1. **Check bucket exists:**
   ```sql
   SELECT * FROM storage.buckets WHERE name = 'course-photos';
   ```

2. **Check policies:**
   Storage policies in Supabase are managed through RLS (Row Level Security) on the `storage.objects` table. To check if policies exist, you can:
   - Go to **Storage** → **Policies** in the Supabase Dashboard
   - Or check the policy definitions in the SQL Editor:
   ```sql
   -- Check if bucket exists and is public
   SELECT id, name, public, file_size_limit, allowed_mime_types 
   FROM storage.buckets 
   WHERE name = 'course-photos';
   
   -- Note: Storage policies are RLS policies on storage.objects
   -- They are managed through the Dashboard UI, not a separate policies table
   ```

### 5. Test Photo Upload

Once set up, you can test the photo upload feature:

1. Navigate to `/courses/contribute` in your app
2. Fill in the course form
3. Scroll to the "Course Photos" section
4. Try uploading a photo
5. Verify the photo appears in Supabase Storage → `course-photos` bucket

## Troubleshooting

### Issue: "Bucket not found" error

**Solution:** Make sure the bucket name is exactly `course-photos` (case-sensitive) and matches what's in your `PhotoUpload` component.

### Issue: "Permission denied" when uploading

**Solution:** 
- Check that RLS policies are set up correctly
- Verify the user is authenticated
- Check that the `INSERT` policy allows `authenticated` role

### Issue: Photos not displaying

**Solution:**
- Ensure the bucket is set to **Public**
- Check that the `SELECT` policy allows public read access
- Verify the photo URLs are being generated correctly

### Issue: "File too large" error

**Solution:**
- Check the bucket's file size limit
- Adjust the `maxSizeMB` prop in `PhotoUpload` component if needed
- The default is 5 MB

## Alternative: Using SQL to Create Bucket

If you prefer using SQL, you can run this in the Supabase SQL Editor:

```sql
-- Create the bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'course-photos',
  'course-photos',
  true,
  5242880, -- 5 MB in bytes
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

```

**Note:** Storage policies are managed through the Supabase Dashboard UI. After creating the bucket with SQL, you still need to:

1. Go to **Storage** → **Policies** in the Dashboard
2. Select the `course-photos` bucket
3. Create the policies using the UI (as described in Step 3 above)

Alternatively, if you want to create policies via SQL, you can use:

```sql
-- Enable RLS on storage.objects if not already enabled
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to upload
CREATE POLICY "Allow authenticated uploads"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'course-photos');

-- Allow public read access
CREATE POLICY "Allow public read access"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'course-photos');

-- Allow users to delete their own uploads
CREATE POLICY "Allow users to delete own uploads"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'course-photos' AND auth.uid() = owner_id);
```

**Important:** Make sure RLS is enabled on `storage.objects` before creating policies. You can check with:
```sql
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'storage' AND tablename = 'objects';
```

## Next Steps

After setting up the storage bucket:

1. ✅ Test photo uploads in the contribution form
2. ✅ Verify photos appear in the course detail pages
3. ✅ Test photo deletion
4. ✅ Monitor storage usage in Supabase Dashboard

## Storage Costs

Keep in mind:
- Supabase offers free tier with limited storage
- Monitor your storage usage in the Dashboard
- Consider implementing image compression/optimization for large uploads
- Set up automatic cleanup for old/unused photos if needed
