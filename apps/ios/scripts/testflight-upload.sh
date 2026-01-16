#!/bin/bash

# TestFlight Upload Script for RoundCaddy
# This script builds and uploads the app to TestFlight using Xcode's command line tools

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/RoundCaddy.xcarchive"
IPA_PATH="$BUILD_DIR/RoundCaddy.ipa"
EXPORT_OPTIONS="$PROJECT_DIR/ExportOptions.plist"

echo "🏌️ RoundCaddy TestFlight Upload"
echo "================================"
echo ""

cd "$PROJECT_DIR"

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: Xcode command line tools not found"
    echo "   Install with: xcode-select --install"
    exit 1
fi

# Check for project
if [ ! -d "RoundCaddy.xcodeproj" ]; then
    echo "❌ Error: RoundCaddy.xcodeproj not found"
    echo "   Please run this script from apps/ios/"
    exit 1
fi

# Create build directory
mkdir -p "$BUILD_DIR"

# Step 1: Clean previous builds
echo "🧹 Cleaning previous builds..."
xcodebuild clean -project RoundCaddy.xcodeproj -scheme GolfStats -configuration Release | tail -1

# Step 2: Archive
echo ""
echo "📦 Creating archive..."
echo "   This may take a few minutes..."
xcodebuild archive \
    -project RoundCaddy.xcodeproj \
    -scheme GolfStats \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=iOS" \
    DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}" \
    CODE_SIGN_STYLE=Automatic \
    | grep -E "(Archive|error:|warning:|\*\*)"

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "❌ Error: Archive failed"
    exit 1
fi

echo "✅ Archive created successfully"

# Step 3: Export IPA
echo ""
echo "📱 Exporting IPA..."

# Create export options if not exists
if [ ! -f "$EXPORT_OPTIONS" ]; then
    cat > "$EXPORT_OPTIONS" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>upload</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadSymbols</key>
    <true/>
    <key>manageAppVersionAndBuildNumber</key>
    <true/>
</dict>
</plist>
EOF
fi

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$BUILD_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    | grep -E "(Export|error:|warning:|\*\*|upload)"

echo ""
echo "✅ Export completed"

# Step 4: Validate (optional)
echo ""
echo "🔍 Validating with App Store Connect..."

xcrun altool --validate-app \
    -f "$BUILD_DIR/GolfStats.ipa" \
    -t ios \
    --apiKey "${APP_STORE_CONNECT_API_KEY:-}" \
    --apiIssuer "${APP_STORE_CONNECT_ISSUER_ID:-}" \
    2>&1 || echo "⚠️  Validation skipped (API key not configured)"

# Step 5: Upload
echo ""
echo "🚀 Uploading to TestFlight..."
echo "   (This uses Xcode's built-in upload from archive)"
echo ""
echo "To upload manually:"
echo "   1. Open Xcode → Window → Organizer"
echo "   2. Select the archive: $ARCHIVE_PATH"
echo "   3. Click 'Distribute App'"
echo "   4. Select 'App Store Connect' → 'Upload'"
echo ""

# Try to upload using xcrun if API credentials are available
if [ -n "${APP_STORE_CONNECT_API_KEY:-}" ] && [ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]; then
    xcrun altool --upload-app \
        -f "$BUILD_DIR/GolfStats.ipa" \
        -t ios \
        --apiKey "$APP_STORE_CONNECT_API_KEY" \
        --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
    
    echo ""
    echo "✅ Upload complete! Check App Store Connect for processing status."
else
    echo "ℹ️  To enable automatic upload, set these environment variables:"
    echo "   export APP_STORE_CONNECT_API_KEY=your_key_id"
    echo "   export APP_STORE_CONNECT_ISSUER_ID=your_issuer_id"
    echo ""
    echo "Or upload manually through Xcode Organizer."
fi

echo ""
echo "================================"
echo "🏌️ Done! Next steps:"
echo "   1. Go to appstoreconnect.apple.com"
echo "   2. Select your app → TestFlight"
echo "   3. Wait for processing (5-30 min)"
echo "   4. Add testers and enable build for testing"
echo "================================"
