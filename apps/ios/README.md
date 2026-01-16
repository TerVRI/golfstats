# GolfStats iOS App

A native SwiftUI iOS app for GolfStats with full GPS tracking, Apple Watch sync, and Supabase backend integration.

## Features

- **Sign in with Apple** - Secure authentication via Supabase
- **Dashboard** - Quick stats, recent rounds, handicap display
- **Live Round Mode** - GPS tracking, score entry, shot tracking
- **Course Discovery** - Search 29+ famous courses with weather
- **Apple Watch Sync** - Real-time data sync via WatchConnectivity
- **Weather Integration** - Current conditions from Open-Meteo API

## Project Structure

```
apps/ios/GolfStats/
├── Sources/
│   ├── GolfStatsApp.swift          # App entry point
│   ├── Models/
│   │   └── Models.swift            # Data models (Round, Course, Shot, etc.)
│   ├── Managers/
│   │   ├── AuthManager.swift       # Supabase auth & Sign in with Apple
│   │   ├── GPSManager.swift        # CoreLocation GPS tracking
│   │   ├── RoundManager.swift      # Active round state management
│   │   ├── WatchSyncManager.swift  # WatchConnectivity sync
│   │   └── DataService.swift       # Supabase REST API client
│   └── Views/
│       ├── LoginView.swift         # Sign in with Apple
│       ├── MainTabView.swift       # Tab navigation
│       ├── DashboardView.swift     # Home dashboard
│       ├── LiveRoundView.swift     # GPS tracking during round
│       ├── RoundsListView.swift    # Round history
│       ├── CoursesView.swift       # Course discovery
│       ├── ProfileView.swift       # User profile & settings
│       └── NewRoundView.swift      # Quick round entry
└── Resources/
    └── Assets.xcassets             # App icons, colors
```

## Setup Instructions

### Prerequisites

- Xcode 15.0+
- iOS 17.0+ target
- Apple Developer account
- Supabase project (already configured)

### Creating the Xcode Project

1. **Open Xcode** → File → New → Project

2. **Choose Template**:
   - Platform: iOS
   - Application: App
   - Click Next

3. **Project Options**:
   - Product Name: `GolfStats`
   - Team: Your Apple Developer team
   - Organization Identifier: `com.golfstats`
   - Interface: SwiftUI
   - Language: Swift
   - Storage: None
   - ✓ Include Tests (optional)
   - Click Next

4. **Save Location**: Save to `apps/ios/`

5. **Copy Source Files**:
   - Delete the generated `ContentView.swift`
   - Copy all files from `Sources/` into the Xcode project
   - Ensure files are added to the target

### Required Capabilities

In Xcode, select your target → Signing & Capabilities:

1. **Sign in with Apple**
   - Click "+ Capability"
   - Add "Sign in with Apple"

2. **Background Modes**
   - Click "+ Capability"
   - Add "Background Modes"
   - Check: "Location updates"

3. **Push Notifications** (optional, for future)

### Info.plist Permissions

Add these keys to your Info.plist:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>GolfStats needs your location to calculate distances to greens and track shots.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>GolfStats needs background location to track your round continuously.</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>GolfStats uses background location for continuous GPS tracking during rounds.</string>
```

### Asset Catalog Colors

Create these colors in Assets.xcassets:

- **Background**: `#0f172a` (dark blue)
- **BackgroundSecondary**: `#1e293b`
- **BackgroundTertiary**: `#334155`

### Build & Run

1. Select your iPhone or Simulator as destination
2. Build and Run (⌘R)
3. Sign in with your Apple ID

## Architecture

### State Management

Uses `@StateObject` and `@EnvironmentObject` for:
- `AuthManager` - Authentication state
- `GPSManager` - Location tracking
- `RoundManager` - Active round data
- `WatchSyncManager` - Watch communication

### Networking

- Direct REST API calls to Supabase
- No external dependencies (pure URLSession)
- Async/await throughout

### GPS Tracking

- `CLLocationManager` with best accuracy
- Background location updates enabled
- 1-meter distance filter for real-time updates

## Apple Watch Integration

The iOS app communicates with the Watch app via `WatchConnectivity`:

### Messages Sent to Watch
- `setCourse` - Course name and par values
- `startRound` / `endRound` - Round lifecycle
- `scoreUpdate` - Score changes per hole

### Messages Received from Watch
- `roundStarted` / `roundEnded` - Watch-initiated rounds
- `scoreUpdate` - Score entered on watch
- `shotAdded` - Shots marked on watch

## API Endpoints Used

```
Supabase REST API:
- POST /auth/v1/token - Authentication
- GET  /auth/v1/user - Current user
- GET  /rest/v1/rounds - Fetch rounds
- POST /rest/v1/rounds - Save round
- GET  /rest/v1/courses - Fetch courses

Open-Meteo:
- GET  /v1/forecast - Weather data
```

## Future Improvements

- [ ] Offline support with local caching
- [ ] Hole-by-hole score entry UI
- [ ] Course flyover maps
- [ ] Shot dispersion visualization
- [ ] HealthKit integration
- [ ] Siri shortcuts
