# Storage Setup - Quick Verification

## ✅ Your Setup Looks Good!

From your Supabase dashboard, I can see:

### Bucket Configuration
- ✅ Bucket name: `COURSE-PHOTOS` (works with code's `course-photos` - case insensitive)
- ✅ Public bucket: Enabled
- ✅ Policies configured

### Policies Status
1. ✅ **Allow authenticated uploads** - INSERT ✓
2. ✅ **Allow public read access** - SELECT ✓
3. ✅ **Allow users to delete own uploads** - DELETE ✓
4. ⚠️ **Duplicate policy** - Has SELECT (should be removed)

### ⚠️ One Small Fix Needed

You have a duplicate policy that should be removed:
- The 4th policy "Allow users to delete own uploads" with SELECT command
- This is a duplicate - you already have the correct DELETE policy

**To fix:**
1. Click the ellipsis (⋯) on the duplicate policy
2. Select "Delete policy"
3. Keep only the DELETE policy for "Allow users to delete own uploads"

---

## 📁 No Sample File Needed!

**Supabase Storage automatically creates folders when you upload files.**

The photo upload component will:
- Create `contributions/` folder automatically on first upload
- Upload files to: `contributions/{timestamp}-{random}.{ext}`
- No manual setup required!

---

## 🧪 Ready to Test!

Your setup is complete! You can now:

1. **Test via web app:**
   - Go to `/courses/contribute`
   - Upload a photo in the "Course Photos" section
   - It should work immediately!

2. **Verify in Supabase:**
   - Go to Storage → Files
   - Select `COURSE-PHOTOS` bucket
   - You should see the `contributions/` folder appear after first upload

---

## ✅ Final Checklist

- [x] Bucket created (`COURSE-PHOTOS`)
- [x] Bucket is public
- [x] INSERT policy (authenticated uploads)
- [x] SELECT policy (public read)
- [x] DELETE policy (users delete own)
- [ ] Remove duplicate policy (optional cleanup)
- [ ] Test upload via web app

**You're all set!** Just remove that duplicate policy and you're ready to go! 🎉
