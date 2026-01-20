# How to See GolfStatsTests Target in Xcode

## ✅ Target Exists

The `GolfStatsTests` target **IS** in the project. Verified via command line:

```bash
xcodebuild -list -project RoundCaddy.xcodeproj
```

Shows:
```
Targets:
    GolfStats
    GolfStatsTests    ← This exists!
    GolfStatsWatch
```

## 🔍 Where to Find It in Xcode

### Method 1: Project Settings (Most Common)

1. **Open Xcode** with `RoundCaddy.xcodeproj`
2. **Click the blue project icon** at the very top of the Project Navigator (left sidebar)
   - It should say "RoundCaddy" or show a folder icon
3. In the **main editor area**, you'll see tabs: **General**, **Signing & Capabilities**, etc.
4. Look for the **TARGETS** section in the left column
5. You should see:
   - **GolfStats** (with app icon)
   - **GolfStatsTests** (with test icon) ← This is it!
   - **GolfStatsWatch** (with watch icon)

### Method 2: Scheme Editor

1. Click the **scheme selector** in the top toolbar (next to play/stop buttons)
2. Select **"Edit Scheme..."**
3. Click **"Test"** in the left sidebar
4. Under **"Testables"**, you should see **GolfStatsTests**

### Method 3: Build Settings

1. Click the blue project icon
2. Select **GolfStatsTests** from the TARGETS list
3. Click **"Build Settings"** tab
4. You should see build settings for GolfStatsTests

## 🚨 If You Still Don't See It

### Step 1: Close Xcode Completely
```bash
# Quit Xcode completely (Cmd+Q)
```

### Step 2: Regenerate Project
```bash
cd apps/ios
xcodegen generate
```

### Step 3: Reopen Xcode
```bash
open RoundCaddy.xcodeproj
```

### Step 4: Clean Build Folder
In Xcode:
- **Product** → **Clean Build Folder** (Shift+Cmd+K)

### Step 5: Verify Target Membership

1. Select any test file (e.g., `GolfStatsTests.swift`)
2. In the **File Inspector** (right sidebar), check **Target Membership**
3. **GolfStatsTests** should be checked

## 📸 Visual Guide

When you click the blue project icon, you should see:

```
┌─────────────────────────────────────┐
│ RoundCaddy                          │
├─────────────────────────────────────┤
│                                     │
│ TARGETS                             │
│ ┌─────────────────────────────────┐ │
│ │ 🎯 GolfStats                    │ │
│ │    (Application)                │ │
│ ├─────────────────────────────────┤ │
│ │ 🧪 GolfStatsTests  ← HERE!      │ │
│ │    (Unit Test Bundle)           │ │
│ ├─────────────────────────────────┤ │
│ │ ⌚ GolfStatsWatch               │ │
│ │    (Watch App)                  │ │
│ └─────────────────────────────────┘ │
│                                     │
│ PROJECT                              │
│ ┌─────────────────────────────────┐ │
│ │ RoundCaddy                      │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

## ✅ Quick Verification Command

Run this to confirm the target exists:

```bash
cd apps/ios
xcodebuild -list -project RoundCaddy.xcodeproj | grep -A 10 "Targets:"
```

You should see `GolfStatsTests` in the list.
