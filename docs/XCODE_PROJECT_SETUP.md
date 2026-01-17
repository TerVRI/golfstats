# Xcode Project Setup - Adding New Files

## Issue: ContributorLeaderboardView Not Found

The `ContributorLeaderboardView.swift` file exists in the filesystem but Xcode can't find it because it's not added to the Xcode project.

## Solution: Add File to Xcode Project

### Method 1: Add Files Dialog (Recommended)

1. Open Xcode
2. In Project Navigator, right-click on `GolfStats/Sources/Views` folder
3. Select **"Add Files to 'RoundCaddy'..."** (Note: It says "RoundCaddy" because that's the project name, but you'll select the GolfStats target)
4. Navigate to: `apps/ios/GolfStats/Sources/Views/ContributorLeaderboardView.swift`
5. **CRITICAL - In the dialog that appears, check these options:**
   - ✅ "Copy items if needed" (usually unchecked if file is already in project folder)
   - ✅ "Create groups" (not "Create folder references")
   - ✅ **"Add to targets: GolfStats"** ✅ (MOST IMPORTANT! This is in the "Add to targets" section at the bottom)
   - ❌ Make sure "GolfStatsWatch" is **NOT** checked (unless you want it there too)
6. Click **"Add"**

**Note:** Even though the menu says "Add Files to 'RoundCaddy'...", the important part is selecting the **"GolfStats"** target in the dialog that appears!

### Method 2: Drag and Drop

1. Open Finder and navigate to: `apps/ios/GolfStats/Sources/Views/`
2. Drag `ContributorLeaderboardView.swift` into Xcode's Project Navigator
3. Drop it on the `Views` folder under `GolfStats/Sources/Views`
4. In the dialog that appears:
   - ✅ "Copy items if needed" (usually unchecked)
   - ✅ "Create groups"
   - ✅ **"Add to targets: GolfStats"** ✅
5. Click "Finish"

### Method 3: Verify Target Membership

If file is already in project but still not found:

1. Select `ContributorLeaderboardView.swift` in Project Navigator
2. Open File Inspector (right panel, first tab)
3. Under "Target Membership", ensure **"GolfStats"** is checked ✅
4. Clean build folder (⇧⌘K)
5. Rebuild (⌘B)

## After Adding File

1. **Clean Build Folder:** Product → Clean Build Folder (⇧⌘K)
2. **Rebuild:** Product → Build (⌘B)
3. **Uncomment in MainTabView:** Remove the `//` comments around `ContributorLeaderboardView()` in `MainTabView.swift`

## Verify It Works

After adding the file, you should be able to:
- See `ContributorLeaderboardView` in autocomplete
- Build without errors
- See the Leaderboard tab in the app

## Temporary Workaround

I've temporarily commented out the Leaderboard tab in `MainTabView.swift` so the app can build. Once you add the file to Xcode, uncomment those lines.

## Files That Need to Be Added

Make sure these files are in your Xcode project:
- ✅ `ContributorLeaderboardView.swift` - **Needs to be added**
- ✅ `ConfirmCourseView.swift` - Should already be there
- ✅ `ContributeCourseView.swift` - Should already be there

**Important:** When adding files, the dialog will say "Add Files to 'RoundCaddy'..." (the project name), but you must check **"GolfStats"** in the "Add to targets" section at the bottom of the dialog!

## Visual Guide

When you click "Add Files to 'RoundCaddy'...", you'll see a dialog with:
- File options at the top (Copy items, Create groups, etc.)
- **"Add to targets" section at the bottom** - This is where you check ✅ **"GolfStats"**

The project name is "RoundCaddy" but the iOS app target is "GolfStats" - make sure you select the target, not just the project!
