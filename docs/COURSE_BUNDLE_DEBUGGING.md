# Course Bundle Debugging Guide

## Issue: Courses Not Showing

If courses aren't appearing in the app, check the following:

### 1. Verify Bundle File Exists
```bash
ls -la apps/ios/GolfStats/Resources/courses-bundle.json
```
Should show a ~13MB file.

### 2. Check Xcode Target Membership
1. Open Xcode
2. Select `courses-bundle.json` in the project navigator
3. Check "Target Membership" in the File Inspector
4. Ensure "GolfStats" target is checked

### 3. Check Console Logs
When the app launches, you should see:
```
📦 Found bundle file at: /path/to/courses-bundle.json
📦 Bundle file size: 13324072 bytes
✅ Successfully decoded bundle
✅ Loaded 23032 courses from bundle
```

If you see:
- `⚠️ courses-bundle.json not found in app bundle` → File not included in target
- `❌ Error loading bundled courses` → Check the specific error message

### 4. Verify Course Model Matches JSON
The Course model must include all fields from the JSON:
- id, name, city, state, country
- address, phone, website (optional)
- course_rating, slope_rating, par, holes (optional)
- latitude, longitude (optional)
- avg_rating, review_count (optional)
- updated_at, created_at (optional)
- hole_data (optional)

### 5. Test Bundle Loading
Run the test:
```bash
# In Xcode: Cmd+U to run all tests
# Or check CourseBundleLoaderTests.swift
```

### 6. Common Issues

**Issue: "No courses found" but bundle loaded**
- Check country filter - many courses have `country: "Unknown"`
- Try selecting "All Countries" or searching by name

**Issue: Bundle file not found**
- Ensure file is in `GolfStats/Resources/` folder
- Check Xcode target membership
- Clean build folder (Cmd+Shift+K) and rebuild

**Issue: Decoding errors**
- Check console for specific field errors
- Verify Course model matches JSON structure
- Ensure all optional fields are marked as `?`

### 7. Debug Commands

Check bundle contents:
```bash
# Count courses
cat apps/ios/GolfStats/Resources/courses-bundle.json | jq '.courses | length'

# Check metadata
cat apps/ios/GolfStats/Resources/courses-bundle.json | jq '.metadata'

# Sample course
cat apps/ios/GolfStats/Resources/courses-bundle.json | jq '.courses[0]'
```

### 8. Force Reload
1. Delete app from device/simulator
2. Clean build folder (Cmd+Shift+K)
3. Rebuild and reinstall
4. Check console logs on launch
