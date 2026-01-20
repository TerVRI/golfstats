# Current TODO Status - January 2025

## ✅ Completed Tasks

### 1. Storage Bucket Setup ✅
- Created verification SQL script: `verify_storage_setup.sql`
- Storage bucket configuration documented
- Migration file exists: `supabase/migrations/20260119000000_fix_storage_policies.sql`
- **Action Required**: Run the verification script in Supabase SQL Editor to confirm bucket and policies are set up correctly

### 2. Web Tests - In Progress 🔄
- **Status**: 90 tests passing, 17 tests failing
- **Fixed**: Updated `rounds/new/page.test.tsx` to match actual component structure
  - Changed from placeholder-based queries to label-based queries
  - Updated to handle `CourseSearch` component properly
  - Fixed async timing issues
- **Remaining Issues**:
  - `rounds/new/page.test.tsx`: Some tests still need adjustment for actual component behavior
  - `courses/confirm/[id]/page.test.tsx`: Component not rendering in tests (likely async/loading state issue)
- **Next Steps**: 
  - Fix remaining test failures
  - Ensure all mocks properly handle async operations

### 3. iOS Project Regeneration - In Progress 🔄
- **Status**: `xcodegen` is installed and ready
- **Action**: Regenerate project with: `cd apps/ios && xcodegen generate`
- **After Regeneration**:
  - Verify `GolfStatsTests` target exists
  - Check all test files are included
  - Run tests: `Cmd+U` in Xcode

## 📋 Remaining Tasks

### 4. iOS Tests ⏳
- [ ] Regenerate Xcode project (in progress)
- [ ] Verify test target compiles
- [ ] Fix any import/access issues
- [ ] Run tests in Xcode: `Cmd+U`
- [ ] Fix any failing tests

### 5. End-to-End Verification ⏳
- [ ] Test course contribution on web
- [ ] Test course contribution on iOS
- [ ] Test photo uploads
- [ ] Test course confirmations
- [ ] Test leaderboard
- [ ] Verify data appears in Supabase

## 📝 Files Created/Modified

### New Files
- `verify_storage_setup.sql` - SQL script to verify storage bucket setup

### Modified Files
- `apps/web/src/app/(app)/rounds/new/page.test.tsx` - Fixed test queries to match component structure
- `apps/web/src/app/(app)/courses/confirm/[id]/page.test.tsx` - Added auth mock (partial fix)

## 🎯 Quick Actions

### To Verify Storage Setup:
```sql
-- Run in Supabase SQL Editor
\i verify_storage_setup.sql
```

### To Regenerate iOS Project:
```bash
cd apps/ios
xcodegen generate
```

### To Run Web Tests:
```bash
cd apps/web
npm run test:run
```

### To Run iOS Tests:
1. Open `apps/ios/RoundCaddy.xcodeproj` in Xcode
2. Select `GolfStatsTests` scheme
3. Press `Cmd+U`

## 📊 Test Status Summary

- **Web Tests**: 90/107 passing (84%)
- **iOS Tests**: Not yet run (project needs regeneration)
- **Storage**: Needs verification
- **E2E Tests**: Not started

## 🚀 Next Priority Actions

1. **High Priority**:
   - Fix remaining web test failures
   - Regenerate iOS project and run tests
   - Verify storage bucket setup

2. **Medium Priority**:
   - Complete end-to-end testing
   - Fix any iOS test failures

3. **Low Priority**:
   - Add missing edge case tests
   - Improve test coverage
