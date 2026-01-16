#!/bin/bash

# RoundCaddy App Icon Generator
# Generates all required icon sizes for iOS and watchOS from a 1024x1024 source image
# Usage: ./generate-app-icons.sh <source-1024x1024.png>

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-1024x1024-icon.png>"
    echo ""
    echo "This script generates all required app icons for iOS and watchOS"
    echo "from a single 1024x1024 source image."
    echo ""
    echo "Example:"
    echo "  $0 ~/Downloads/roundcaddy-icon.png"
    exit 1
fi

SOURCE_ICON="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ ! -f "$SOURCE_ICON" ]; then
    echo "Error: Source icon not found: $SOURCE_ICON"
    exit 1
fi

# Verify source dimensions
DIMENSIONS=$(sips -g pixelWidth -g pixelHeight "$SOURCE_ICON" | tail -2 | awk '{print $2}')
WIDTH=$(echo "$DIMENSIONS" | head -1)
HEIGHT=$(echo "$DIMENSIONS" | tail -1)

if [ "$WIDTH" != "1024" ] || [ "$HEIGHT" != "1024" ]; then
    echo "Warning: Source image is ${WIDTH}x${HEIGHT}, not 1024x1024"
    echo "Icons may not look optimal. Continue? (y/n)"
    read -r response
    if [ "$response" != "y" ]; then
        exit 1
    fi
fi

# iOS App Icon directory
IOS_ICON_DIR="$PROJECT_DIR/GolfStats/Resources/Assets.xcassets/AppIcon.appiconset"

# watchOS App Icon directory
WATCH_ICON_DIR="$PROJECT_DIR/../watch/GolfStatsWatch WatchKit Extension/Resources/Assets.xcassets/AppIcon.appiconset"

echo "🎨 Generating iOS app icons..."

# iOS icons (just need 1024x1024 for modern iOS)
mkdir -p "$IOS_ICON_DIR"
cp "$SOURCE_ICON" "$IOS_ICON_DIR/AppIcon-1024.png"

# Update iOS Contents.json
cat > "$IOS_ICON_DIR/Contents.json" << 'EOF'
{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo "✅ iOS app icon generated"

echo "⌚ Generating watchOS app icons..."

mkdir -p "$WATCH_ICON_DIR"

# watchOS icon sizes (size@scale)
declare -a WATCH_ICONS=(
    "48:24@2x:notificationCenter:38mm"
    "55:27.5@2x:notificationCenter:42mm"
    "58:29@2x:companionSettings:"
    "87:29@3x:companionSettings:"
    "80:40@2x:appLauncher:38mm"
    "88:44@2x:appLauncher:40mm"
    "92:46@2x:appLauncher:41mm"
    "100:50@2x:appLauncher:44mm"
    "102:51@2x:appLauncher:45mm"
    "108:54@2x:appLauncher:49mm"
    "172:86@2x:quickLook:38mm"
    "196:98@2x:quickLook:42mm"
    "216:108@2x:quickLook:44mm"
    "234:117@2x:quickLook:45mm"
    "258:129@2x:quickLook:49mm"
    "1024:1024@1x:marketing:"
)

# Generate each watch icon size
for ICON_DEF in "${WATCH_ICONS[@]}"; do
    IFS=':' read -r PIXELS SIZE ROLE SUBTYPE <<< "$ICON_DEF"
    FILENAME="AppIcon-${PIXELS}.png"
    
    echo "  Creating $FILENAME ($PIXELS x $PIXELS)..."
    sips -z "$PIXELS" "$PIXELS" "$SOURCE_ICON" --out "$WATCH_ICON_DIR/$FILENAME" > /dev/null 2>&1
done

# Update watchOS Contents.json
cat > "$WATCH_ICON_DIR/Contents.json" << 'EOF'
{
  "images" : [
    {
      "filename" : "AppIcon-48.png",
      "idiom" : "watch",
      "scale" : "2x",
      "role" : "notificationCenter",
      "size" : "24x24",
      "subtype" : "38mm"
    },
    {
      "filename" : "AppIcon-55.png",
      "idiom" : "watch",
      "scale" : "2x",
      "role" : "notificationCenter",
      "size" : "27.5x27.5",
      "subtype" : "42mm"
    },
    {
      "filename" : "AppIcon-58.png",
      "idiom" : "watch",
      "scale" : "2x",
      "role" : "companionSettings",
      "size" : "29x29"
    },
    {
      "filename" : "AppIcon-87.png",
      "idiom" : "watch",
      "scale" : "3x",
      "role" : "companionSettings",
      "size" : "29x29"
    },
    {
      "filename" : "AppIcon-80.png",
      "idiom" : "watch",
      "scale" : "2x",
      "role" : "appLauncher",
      "size" : "40x40",
      "subtype" : "38mm"
    },
    {
      "filename" : "AppIcon-88.png",
      "idiom" : "watch",
      "scale" : "2x",
      "role" : "appLauncher",
      "size" : "44x44",
      "subtype" : "40mm"
    },
    {
      "filename" : "AppIcon-92.png",
      "idiom" : "watch",
      "scale" : "2x",
      "role" : "appLauncher",
      "size" : "46x46",
      "subtype" : "41mm"
    },
    {
      "filename" : "AppIcon-100.png",
      "idiom" : "watch",
      "scale" : "2x",
      "role" : "appLauncher",
      "size" : "50x50",
      "subtype" : "44mm"
    },
    {
      "filename" : "AppIcon-102.png",
      "idiom" : "watch",
      "scale" : "2x",
      "role" : "appLauncher",
      "size" : "51x51",
      "subtype" : "45mm"
    },
    {
      "filename" : "AppIcon-108.png",
      "idiom" : "watch",
      "scale" : "2x",
      "role" : "appLauncher",
      "size" : "54x54",
      "subtype" : "49mm"
    },
    {
      "filename" : "AppIcon-172.png",
      "idiom" : "watch",
      "scale" : "2x",
      "role" : "quickLook",
      "size" : "86x86",
      "subtype" : "38mm"
    },
    {
      "filename" : "AppIcon-196.png",
      "idiom" : "watch",
      "scale" : "2x",
      "role" : "quickLook",
      "size" : "98x98",
      "subtype" : "42mm"
    },
    {
      "filename" : "AppIcon-216.png",
      "idiom" : "watch",
      "scale" : "2x",
      "role" : "quickLook",
      "size" : "108x108",
      "subtype" : "44mm"
    },
    {
      "filename" : "AppIcon-234.png",
      "idiom" : "watch",
      "scale" : "2x",
      "role" : "quickLook",
      "size" : "117x117",
      "subtype" : "45mm"
    },
    {
      "filename" : "AppIcon-258.png",
      "idiom" : "watch",
      "scale" : "2x",
      "role" : "quickLook",
      "size" : "129x129",
      "subtype" : "49mm"
    },
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "watch-marketing",
      "scale" : "1x",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo "✅ watchOS app icons generated"
echo ""
echo "🎉 All icons generated successfully!"
echo ""
echo "Icon locations:"
echo "  iOS:     $IOS_ICON_DIR"
echo "  watchOS: $WATCH_ICON_DIR"
echo ""
echo "Next steps:"
echo "  1. Open RoundCaddy.xcodeproj in Xcode"
echo "  2. Verify icons appear in Assets.xcassets"
echo "  3. Build and archive for TestFlight"
