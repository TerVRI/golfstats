# Storage Bucket Verification

## ✅ Current Setup Status

Based on your Supabase dashboard screenshot:

### Bucket Configuration
- **Bucket Name:** `COURSE-PHOTOS` (uppercase in Supabase)
- **Code Reference:** `course-photos` (lowercase in code)
- **Status:** ✅ Case-insensitive, will work fine
- **Public:** ✅ Yes (correct)

### Policies Configured
1. ✅ **Allow authenticated uploads** - INSERT - public
2. ✅ **Allow public read access** - SELECT - public  
3. ✅ **Allow users to delete own uploads** - DELETE - public
4. ⚠️ **Allow users to delete own uploads** - SELECT - public (duplicate/incorrect)

### Issue Found
There's a duplicate policy with incorrect command:
- Policy #4 has `SELECT` command but should be `DELETE` (or should be removed if it's a duplicate)

**Recommendation:** Delete the duplicate policy #4 (the one with SELECT command).

---

## 📁 Folder Structure

The photo upload component will automatically create folders as needed:
- **Default folder:** `contributions/`
- **File path format:** `contributions/{timestamp}-{random}.{ext}`
- **Example:** `contributions/1704067200000-abc123.jpg`

**No manual folder creation needed** - Supabase Storage creates folders automatically when files are uploaded.

---

## 🧪 Testing the Setup

### Option 1: Test via Web App (Recommended)
1. Navigate to `/courses/contribute` in your web app
2. Fill in the course form
3. Scroll to "Course Photos" section
4. Click "Upload Photos"
5. Select an image file
6. Verify upload succeeds and photo appears

### Option 2: Test via Supabase Dashboard
1. Go to Storage → Files
2. Select `COURSE-PHOTOS` bucket
3. Click "Upload file"
4. Upload a test image
5. Verify it appears in the bucket

### Option 3: Test via SQL/API
You can verify the bucket exists:
```sql
SELECT * FROM storage.buckets WHERE name = 'course-photos';
```

---

## ✅ Verification Checklist

- [x] Bucket exists (`COURSE-PHOTOS`)
- [x] Bucket is public
- [x] INSERT policy for authenticated users
- [x] SELECT policy for public read
- [x] DELETE policy for users to delete own uploads
- [ ] Remove duplicate policy (if exists)
- [ ] Test upload via web app
- [ ] Verify photos appear in bucket
- [ ] Verify public URLs work

---

## 🔧 Fixing the Duplicate Policy

If you see a duplicate policy:

1. Go to Storage → Policies
2. Find the duplicate policy (the one with SELECT command)
3. Click the ellipsis (⋯) menu
4. Select "Delete policy"
5. Confirm deletion

**Correct Policy Setup:**
- ✅ INSERT policy: Allow authenticated users to upload
- ✅ SELECT policy: Allow public read access
- ✅ DELETE policy: Allow users to delete own uploads

---

## 📝 Sample File Structure

After uploading photos, your bucket will look like:

```
COURSE-PHOTOS/
└── contributions/
    ├── 1704067200000-abc123.jpg
    ├── 1704067300000-def456.png
    └── 1704067400000-ghi789.webp
```

**No need to create this structure manually** - it's created automatically on first upload.

---

## 🚀 Next Steps

1. **Remove duplicate policy** (if present)
2. **Test photo upload** via the web app
3. **Verify photos appear** in Supabase Storage
4. **Check public URLs** work correctly

Once you've tested an upload, everything should be working! 🎉
