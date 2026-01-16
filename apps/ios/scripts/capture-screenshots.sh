#!/bin/bash

# App Store Screenshot Capture Script for RoundCaddy
# This script builds the app in demo mode and captures screenshots for all required devices

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SCREENSHOT_DIR="$PROJECT_DIR/screenshots"

echo "📸 RoundCaddy Screenshot Capture"
echo "================================"
echo ""

cd "$PROJECT_DIR"

# Create screenshot directories
mkdir -p "$SCREENSHOT_DIR"/{iphone-6.7,iphone-6.5,ipad-12.9,watch-45mm,watch-49mm}

# Device configurations
# Format: "SimulatorName:OutputFolder:Width:Height"
IPHONE_DEVICES=(
    "iPhone 17 Pro Max:iphone-6.7:1290:2796"
    "iPhone 15 Pro Max:iphone-6.7:1290:2796"
    "iPhone 11 Pro Max:iphone-6.5:1242:2688"
)

IPAD_DEVICES=(
    "iPad Pro 13-inch (M4):ipad-12.9:2048:2732"
    "iPad Pro (12.9-inch) (6th generation):ipad-12.9:2048:2732"
)

WATCH_DEVICES=(
    "Apple Watch Series 11 (46mm):watch-45mm:396:484"
    "Apple Watch Ultra 3 (49mm):watch-49mm:410:502"
)

# Function to find an available device
find_available_device() {
    local device_list=("$@")
    for device_spec in "${device_list[@]}"; do
        IFS=':' read -r device_name folder width height <<< "$device_spec"
        device_udid=$(xcrun simctl list devices available | grep "$device_name" | head -1 | grep -oE '\([A-F0-9-]+\)' | tr -d '()')
        if [ -n "$device_udid" ]; then
            echo "$device_udid:$folder:$width:$height:$device_name"
            return 0
        fi
    done
    return 1
}

# Function to boot simulator if needed
boot_simulator() {
    local udid=$1
    local state=$(xcrun simctl list devices | grep "$udid" | grep -oE '\(Booted\)' || true)
    if [ -z "$state" ]; then
        echo "  Booting simulator..."
        xcrun simctl boot "$udid" 2>/dev/null || true
        sleep 5
    fi
}

# Function to capture screenshot
capture_screenshot() {
    local udid=$1
    local name=$2
    local output_path=$3
    
    xcrun simctl io "$udid" screenshot "$output_path" --type png 2>/dev/null
    echo "  ✅ Captured: $name"
}

# Function to wait for app to launch
wait_for_app() {
    sleep 3
}

echo "📱 Building iOS app in demo mode..."
xcodebuild build \
    -project RoundCaddy.xcodeproj \
    -scheme GolfStats \
    -configuration Debug \
    -destination "generic/platform=iOS Simulator" \
    -quiet \
    2>&1 | grep -E "(error:|warning:|\*\*)" || true

echo ""
echo "🔍 Finding available simulators..."

# Find available iPhone
IPHONE_INFO=$(find_available_device "${IPHONE_DEVICES[@]}" || echo "")
if [ -z "$IPHONE_INFO" ]; then
    echo "❌ No iPhone simulator found"
    exit 1
fi
IFS=':' read -r IPHONE_UDID IPHONE_FOLDER IPHONE_WIDTH IPHONE_HEIGHT IPHONE_NAME <<< "$IPHONE_INFO"
echo "  iPhone: $IPHONE_NAME ($IPHONE_UDID)"

# Find available iPad
IPAD_INFO=$(find_available_device "${IPAD_DEVICES[@]}" || echo "")
if [ -n "$IPAD_INFO" ]; then
    IFS=':' read -r IPAD_UDID IPAD_FOLDER IPAD_WIDTH IPAD_HEIGHT IPAD_NAME <<< "$IPAD_INFO"
    echo "  iPad: $IPAD_NAME ($IPAD_UDID)"
fi

# Find available Watch
WATCH_INFO=$(find_available_device "${WATCH_DEVICES[@]}" || echo "")
if [ -n "$WATCH_INFO" ]; then
    IFS=':' read -r WATCH_UDID WATCH_FOLDER WATCH_WIDTH WATCH_HEIGHT WATCH_NAME <<< "$WATCH_INFO"
    echo "  Watch: $WATCH_NAME ($WATCH_UDID)"
fi

echo ""
echo "📱 Capturing iPhone screenshots..."

# Boot iPhone simulator
boot_simulator "$IPHONE_UDID"

# Install and launch app in demo mode
echo "  Installing app..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "GolfStats.app" -path "*/Debug-iphonesimulator/*" 2>/dev/null | head -1)
if [ -z "$APP_PATH" ]; then
    echo "❌ Could not find built app. Please build from Xcode first."
    exit 1
fi

xcrun simctl install "$IPHONE_UDID" "$APP_PATH"
echo "  Launching app in demo mode..."
xcrun simctl launch "$IPHONE_UDID" com.roundcaddy.ios -demo

wait_for_app

# Capture iPhone screenshots
IPHONE_OUTPUT_DIR="$SCREENSHOT_DIR/$IPHONE_FOLDER"

echo "  Capturing screens..."
sleep 2
capture_screenshot "$IPHONE_UDID" "01-Dashboard" "$IPHONE_OUTPUT_DIR/01-dashboard.png"

# Note: Additional screenshots would require UI automation (XCUITest) to navigate
# For now, we capture the initial screen. See manual instructions below.

echo ""
echo "📱 Capturing iPad screenshots..."

if [ -n "$IPAD_UDID" ]; then
    boot_simulator "$IPAD_UDID"
    
    # Install app on iPad
    xcrun simctl install "$IPAD_UDID" "$APP_PATH"
    xcrun simctl launch "$IPAD_UDID" com.roundcaddy.ios -demo
    
    wait_for_app
    
    IPAD_OUTPUT_DIR="$SCREENSHOT_DIR/$IPAD_FOLDER"
    sleep 2
    capture_screenshot "$IPAD_UDID" "01-Dashboard" "$IPAD_OUTPUT_DIR/01-dashboard.png"
else
    echo "  ⚠️  Skipped (no iPad simulator available)"
fi

echo ""
echo "⌚ Capturing Watch screenshots..."

if [ -n "$WATCH_UDID" ]; then
    boot_simulator "$WATCH_UDID"
    
    # Note: Watch app requires special handling - it's embedded in iOS app
    WATCH_APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "GolfStatsWatch.app" -path "*/Debug-watchsimulator/*" 2>/dev/null | head -1)
    
    if [ -n "$WATCH_APP_PATH" ]; then
        xcrun simctl install "$WATCH_UDID" "$WATCH_APP_PATH"
        xcrun simctl launch "$WATCH_UDID" com.roundcaddy.ios.watchkitapp -demo 2>/dev/null || true
        
        wait_for_app
        
        WATCH_OUTPUT_DIR="$SCREENSHOT_DIR/$WATCH_FOLDER"
        sleep 2
        capture_screenshot "$WATCH_UDID" "01-Distance" "$WATCH_OUTPUT_DIR/01-distance.png"
    else
        echo "  ⚠️  Watch app not found in build"
    fi
else
    echo "  ⚠️  Skipped (no Watch simulator available)"
fi

echo ""
echo "================================"
echo "📸 Screenshot capture complete!"
echo ""
echo "Screenshots saved to: $SCREENSHOT_DIR"
echo ""
echo "📝 IMPORTANT: Manual Steps Required"
echo "================================"
echo ""
echo "The automated capture only gets the initial screen."
echo "For complete App Store screenshots, please:"
echo ""
echo "1. Open Xcode → Product → Run"
echo "2. Edit scheme → Add '-demo' to Arguments Passed On Launch"
echo "3. Run on each simulator device"
echo "4. Manually navigate to capture these screens:"
echo ""
echo "   iPhone Screenshots:"
echo "   - Dashboard (with stats)"
echo "   - Live GPS Round"
echo "   - Scorecard Entry"
echo "   - Statistics/Strokes Gained"
echo "   - Course Search"
echo "   - Profile"
echo ""
echo "   iPad Screenshots (same as iPhone)"
echo ""
echo "   Apple Watch Screenshots:"
echo "   - Distance View"
echo "   - Scorecard"
echo "   - Shot Tracker"
echo ""
echo "To capture manually in Simulator:"
echo "  Press: Cmd+S (or File → Save Screen Shot)"
echo ""
echo "Or use Fastlane Snapshot for full automation:"
echo "  bundle exec fastlane screenshots"
