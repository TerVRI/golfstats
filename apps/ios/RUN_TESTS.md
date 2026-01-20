# Running iOS Tests in Xcode

## Quick Start

1. **Select the GolfStats scheme** (top toolbar, next to play button)
2. **Press `Cmd+U`** to run all tests
3. **Or** go to **Product** → **Test**

## Step-by-Step

### 1. Select the Correct Scheme
- Look at the top toolbar in Xcode
- Click the scheme selector (shows "GolfStats" or device name)
- Make sure **"GolfStats"** is selected (not GolfStatsWatch)

### 2. Run Tests
- **Keyboard shortcut**: Press `Cmd+U`
- **Or menu**: **Product** → **Test**
- **Or button**: Click the play button, then select "Test" from dropdown

### 3. View Results
- Test results appear in the **Test Navigator** (left sidebar, test icon)
- Or in the **Report Navigator** (left sidebar, document icon)
- Green checkmarks = passing tests
- Red X = failing tests

## What to Expect

### First Run
- Tests may fail initially due to:
  - Missing imports
  - Access level issues (models need to be `public` or `internal`)
  - Missing test data/mocks

### Common Issues & Fixes

#### Issue: "Cannot find 'GPSManager' in scope"
**Fix**: Make sure classes are accessible:
```swift
// In your source files, ensure classes are not private
class GPSManager: NSObject { ... }  // ✅ Good
private class GPSManager { ... }    // ❌ Won't work
```

#### Issue: "Use of unresolved identifier"
**Fix**: Check that you're importing the module:
```swift
@testable import GolfStats  // Make sure this is at the top
```

#### Issue: Tests compile but fail
**Fix**: Check the test output for specific error messages

## Running Specific Tests

### Run One Test
1. Open the test file
2. Click the diamond icon (◊) next to the test function
3. Or right-click the test name → **Run "testName"**

### Run All Tests in a File
1. Click the diamond icon next to the class name
2. Or right-click the class → **Run Tests**

## Test Results

### Success ✅
```
Test Suite 'GolfStatsTests' passed.
     Executed 15 tests, with 0 failures
```

### Failure ❌
```
Test Case '-[GolfStatsTests testGPSManagerInitialization]' failed.
```

Click on failed tests to see error details.

## Next Steps After Running

1. **Fix any compilation errors** - Update access levels, imports, etc.
2. **Fix failing tests** - Update test logic to match your actual code
3. **Add more tests** - Cover edge cases and additional features

## Command Line Alternative

You can also run tests from terminal:

```bash
cd apps/ios
./scripts/run-tests.sh
```

Or directly:
```bash
xcodebuild test \
  -project RoundCaddy.xcodeproj \
  -scheme GolfStats \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```
