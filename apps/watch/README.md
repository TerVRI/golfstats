# RoundCaddy Apple Watch App

A native SwiftUI Apple Watch app for RoundCaddy that provides:
- **GPS Distance Tracking**: Front/Center/Back yardages to the green
- **Scorecard Entry**: Quick score entry with stepper controls
- **Shot Tracking**: Mark shots with GPS coordinates and club selection
- **iPhone Sync**: Real-time synchronization with the iOS app via WatchConnectivity

## Setup Instructions

### Prerequisites
- Xcode 15.0+ installed on your Mac
- Apple Developer account with watchOS capabilities
- iPhone running the RoundCaddy iOS app (for full functionality)

### Opening the Project

1. **Create Xcode Project**:
   - Open Xcode
   - File → New → Project
   - Choose "watchOS" tab → "App"
   - Product Name: "RoundCaddyWatch"
   - Team: Select your Apple Developer account
   - Bundle Identifier: `com.roundcaddy.watch`
   - Interface: SwiftUI
   - Language: Swift
   - Include: Watch Companion App (optional, for iOS companion)

2. **Copy Source Files**:
   - Replace the generated source files with the Swift files in this directory
   - Structure:
     ```
     RoundCaddyWatch WatchKit Extension/
     └── Sources/
         ├── RoundCaddyWatchApp.swift
         ├── ContentView.swift
         ├── GPSManager.swift
         ├── RoundManager.swift
         └── Views/
             ├── DistanceView.swift
             ├── ScorecardView.swift
             └── ShotTrackerView.swift
     ```

3. **Configure Capabilities**:
   - Select target → "Signing & Capabilities"
   - Add "Location Updates" (for GPS)
   - Add "HealthKit" (optional, for activity tracking)
   - Enable "WatchConnectivity" (for iPhone sync)

4. **Info.plist Permissions**:
   Add these keys to your Info.plist:
   ```xml
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>RoundCaddy needs location to calculate distances to greens and track shots.</string>
   <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
   <string>RoundCaddy needs background location to track your round continuously.</string>
   ```

### Building & Running

1. Select your Apple Watch or Simulator as the destination
2. Build and Run (⌘R)
3. For physical device:
   - Enable Developer Mode on your Apple Watch
   - Pair with your Mac via iPhone

### Features

#### Distance View
- Shows front/center/back yardages to the green
- GPS-powered real-time updates
- Last shot distance after marking

#### Scorecard View
- Quick +/- score entry
- Fairway hit toggle
- GIR toggle
- Putts counter
- Running total display

#### Shot Tracker View
- Club selection picker
- "Mark Shot" button captures GPS
- Shot history for current hole
- Calculated distance from previous shot

### iPhone Communication

The watch app communicates with the iPhone app via WatchConnectivity:

**Watch → iPhone**:
- Round start/end events
- Score updates per hole
- Shot GPS data

**iPhone → Watch**:
- Course name and details
- Hole par values
- Green GPS coordinates

### Limitations

- Requires iPhone to be nearby for internet features
- GPS accuracy varies (typically 5-10 yards)
- Course GPS data must be loaded from iPhone app
- Battery usage increases with continuous GPS

## Development Notes

- SwiftUI for all views (watchOS 9+)
- Combine for reactive state management
- CoreLocation for GPS
- WatchConnectivity for iPhone sync
- No external dependencies required

## TestFlight Deployment

The watchOS app is embedded within the iOS app and deployed together.

### Bundle IDs
- iOS App: `com.roundcaddy.ios`
- Watch App: `com.roundcaddy.ios.watchkitapp`

### Deployment Steps

1. Both apps are built together when archiving the iOS app
2. Open `apps/ios/RoundCaddy.xcodeproj`
3. Archive with scheme "GolfStats" (includes watch target)
4. Upload to App Store Connect
5. Watch app appears in TestFlight alongside iOS app

### Testing on Physical Watch

1. Install TestFlight on your iPhone
2. Install the iOS beta app
3. Open Watch app on iPhone
4. Find RoundCaddy → Install on Watch

See `apps/ios/TESTFLIGHT_GUIDE.md` for complete instructions.
