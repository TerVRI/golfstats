# RoundCaddy

Tour-level strokes gained analytics for every golfer. Track your rounds, analyze your game, and improve with data.

## Apps

- **Web** (`apps/web`) - Next.js web application with dashboard, round tracking, and analytics
- **iOS** (`apps/ios`) - Native SwiftUI iPhone app with GPS tracking and Sign in with Apple
- **Watch** (`apps/watch`) - Native SwiftUI Apple Watch app with distance tracking and score entry

## Packages

- **@roundcaddy/shared** - Shared types, utilities, and strokes gained calculations

## Getting Started

```bash
# Install dependencies
npm install

# Run web app
npm run dev:web

# Build all
npm run build
```

## Features

- 📊 **Strokes Gained Analytics** - Tour-level statistics for Off the Tee, Approach, Around Green, and Putting
- 📍 **GPS Tracking** - Real-time distance to greens, hazards, and shot tracking
- ⌚ **Apple Watch** - Quick score entry and distance display on your wrist
- 🌤️ **Weather Integration** - Course conditions from Open-Meteo API
- 🏌️ **Course Discovery** - Database of courses with ratings and reviews
- 📱 **Cross-Platform** - Web, iPhone, and Apple Watch support

## Tech Stack

- **Web**: Next.js 16, React 19, Tailwind CSS, Recharts
- **iOS/Watch**: SwiftUI, CoreLocation, WatchConnectivity
- **Backend**: Supabase (PostgreSQL, Auth, Realtime)
- **Monorepo**: Turborepo
