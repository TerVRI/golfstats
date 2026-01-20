# Adding GolfStatsTests Target to Xcode

## ✅ Target Already Created

The `GolfStatsTests` target has been added to `project.yml` and the project has been regenerated. The target exists in **RoundCaddy.xcodeproj**.

## 🔍 How to See the Target in Xcode

### Step 1: Open the Correct Project

**IMPORTANT**: You need to open **`RoundCaddy.xcodeproj`**, not `GolfStats.xcodeproj`

```bash
cd apps/ios
open RoundCaddy.xcodeproj
```

### Step 2: View Targets in Xcode

Once Xcode is open, you can see targets in several ways:

#### Option A: Project Navigator
1. In the left sidebar (Project Navigator), click on the **blue project icon** at the top (RoundCaddy)
2. In the main editor, you'll see **TARGETS** section
3. You should see:
   - GolfStats
   - **GolfStatsTests** ← This is your test target
   - GolfStatsWatch

#### Option B: Scheme Selector
1. Look at the top toolbar
2. Click on the scheme selector (next to the play/stop buttons)
3. You should see "GolfStats" scheme
4. When you select it, you can see test targets associated with it

#### Option C: Product Menu
1. Go to **Product** → **Scheme** → **Edit Scheme...**
2. Click on **Test** in the left sidebar
3. Under **Testables**, you should see **GolfStatsTests**

### Step 3: Verify Test Files Are Included

1. In Project Navigator, expand the project
2. Look for **GolfStatsTests** folder/group
3. You should see:
   - `GolfStatsTests.swift`
   - `UI/` folder with:
     - `GPSLocationDisplayTests.swift`
     - `CourseConfirmationTests.swift`
     - `DiscussionsTests.swift`
     - `NewRoundButtonTests.swift`

## 🚨 Troubleshooting

### If You Don't See the Target

1. **Close Xcode completely**
2. **Regenerate the project**:
   ```bash
   cd apps/ios
   xcodegen generate
   ```
3. **Reopen Xcode**:
   ```bash
   open RoundCaddy.xcodeproj
   ```

### If Test Files Are Missing

1. In Xcode, right-click on the project
2. Select **Add Files to "RoundCaddy"...**
3. Navigate to `apps/ios/GolfStatsTests`
4. Select all test files
5. Make sure **"Copy items if needed"** is UNCHECKED
6. Make sure **"Add to targets: GolfStatsTests"** is CHECKED
7. Click **Add**

### If Target Exists But Tests Don't Run

1. Select the **GolfStats** scheme (top toolbar)
2. Press **Cmd+U** to run tests
3. Or go to **Product** → **Test**

## ✅ Verification

To verify everything is set up correctly:

```bash
cd apps/ios
xcodebuild -list -project RoundCaddy.xcodeproj
```

You should see:
```
Targets:
    GolfStats
    GolfStatsTests    ← Should be here
    GolfStatsWatch
```

## 📝 Quick Reference

- **Project File**: `RoundCaddy.xcodeproj` (NOT `GolfStats.xcodeproj`)
- **Test Target**: `GolfStatsTests`
- **Test Files Location**: `apps/ios/GolfStatsTests/`
- **Run Tests**: Press `Cmd+U` in Xcode or select scheme → Test
