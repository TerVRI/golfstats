# GolfStats Mobile App & GPS Plan

## Overview

Expand GolfStats with:
1. **iOS App** (React Native / Expo)
2. **Apple Watch App** (Native Swift/SwiftUI companion)
3. **GPS Course Mapping**
4. **Course Database** (downloadable, user-contributed)
5. **Weather Integration**
6. **Course Reviews**

---

## 1. Technology Stack Decision

### iOS App
| Option | Pros | Cons |
|--------|------|------|
| **React Native + Expo** ✅ | Share code with web, faster dev | Watch app requires native bridge |
| Swift/SwiftUI | Best performance, full Watch support | Separate codebase |
| Flutter | Cross-platform, good performance | Different language (Dart) |

**Recommendation:** React Native + Expo for main app, with native Swift module for Apple Watch.

### Apple Watch App
- **Must be native Swift/SwiftUI** - React Native doesn't support WatchOS directly
- Will communicate with iOS app via WatchConnectivity framework
- Features: GPS distance, score entry, hole navigation

---

## 2. Golf Course Data Strategy

### The Problem
- Commercial providers (GolfLogix, Hole19, SwingU) charge $50k-500k/year for their databases
- No comprehensive free golf course GPS database exists publicly
- OpenStreetMap has course boundaries but NOT hole-by-hole data

### Our Solution: Hybrid Approach

#### A) Seed Data (Free Sources)
| Source | What It Has | How to Get |
|--------|-------------|------------|
| OpenStreetMap | Course boundaries, some tees/greens | Overpass API query |
| USGA Course Database | Names, ratings, slopes (US) | Manual entry from GHIN |
| R&A/EGA Databases | International course info | Public course finders |
| Google Places API | Course locations, names | Free tier (limited) |

#### B) User-Contributed Mapping
- Users map their home courses
- Reward system: Free premium features for mapping
- Crowdsourced verification
- Export/import course files (JSON format)

#### C) Course File Format
```json
{
  "course": {
    "id": "uuid",
    "name": "Pebble Beach Golf Links",
    "location": { "lat": 36.5725, "lng": -121.9486 },
    "rating": 75.5,
    "slope": 145,
    "holes": [
      {
        "number": 1,
        "par": 4,
        "distance": { "black": 381, "blue": 356, "white": 331 },
        "tee": { "lat": 36.5730, "lng": -121.9490 },
        "green": {
          "front": { "lat": 36.5735, "lng": -121.9485 },
          "center": { "lat": 36.5736, "lng": -121.9484 },
          "back": { "lat": 36.5737, "lng": -121.9483 }
        },
        "hazards": [
          { "type": "bunker", "lat": 36.5733, "lng": -121.9487 },
          { "type": "water", "polygon": [...] }
        ]
      }
    ]
  }
}
```

#### D) Course Update Strategy
- Version control for course data
- Users can submit corrections
- Admin review queue
- Periodic sync from OpenStreetMap updates

---

## 3. Weather Integration

### Free Weather APIs
| Provider | Free Tier | Best For |
|----------|-----------|----------|
| **OpenWeatherMap** | 1,000 calls/day | Current + forecast |
| **Weather.gov** | Unlimited (US only) | US courses |
| **Open-Meteo** | Unlimited, no key | Global, simple |
| Tomorrow.io | 500 calls/day | Detailed hourly |

**Recommendation:** Open-Meteo (no API key, unlimited) + Weather.gov backup for US.

### Weather Features
- Current conditions at course
- Wind speed/direction (critical for club selection)
- "Plays like" distance adjustment (temp + altitude)
- Rain forecast for round planning

---

## 4. Project Structure

```
golfstats/
├── apps/
│   ├── web/                 # Existing Next.js app
│   ├── mobile/              # React Native + Expo
│   │   ├── app/
│   │   ├── components/
│   │   └── package.json
│   └── watch/               # Native Swift Apple Watch
│       ├── GolfStatsWatch/
│       ├── GolfStatsWatch.xcodeproj
│       └── Shared/
├── packages/
│   ├── shared/              # Shared types, utils
│   ├── supabase/            # Shared Supabase client
│   └── course-data/         # Course file parser
├── supabase/
│   └── migrations/
└── docs/
```

---

## 5. Database Schema Additions

```sql
-- Course GPS data
CREATE TABLE course_gps (
  id UUID PRIMARY KEY,
  course_id UUID REFERENCES courses(id),
  version INTEGER DEFAULT 1,
  data JSONB NOT NULL,  -- Full course mapping
  contributed_by UUID REFERENCES profiles(id),
  verified BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Course reviews
CREATE TABLE course_reviews (
  id UUID PRIMARY KEY,
  course_id UUID REFERENCES courses(id),
  user_id UUID REFERENCES profiles(id),
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  review_text TEXT,
  conditions_rating INTEGER,
  value_rating INTEGER,
  pace_rating INTEGER,
  photos JSONB,
  played_at DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Weather cache
CREATE TABLE weather_cache (
  id UUID PRIMARY KEY,
  location_key TEXT NOT NULL,  -- "lat,lng" rounded
  data JSONB NOT NULL,
  fetched_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL
);
```

---

## 6. Implementation Phases

### Phase 1: Foundation (Week 1-2)
- [ ] Set up monorepo structure with Turborepo
- [ ] Create shared packages (types, supabase client)
- [ ] Set up Expo project for iOS
- [ ] Database migrations for GPS & reviews

### Phase 2: Course Database (Week 2-3)
- [ ] Course GPS schema & API endpoints
- [ ] Course file format parser
- [ ] Seed database with initial courses (manual)
- [ ] Course mapping UI in web app

### Phase 3: iOS App Core (Week 3-5)
- [ ] Authentication (shared with web)
- [ ] Dashboard & round history
- [ ] New round entry with GPS
- [ ] Course selection & download

### Phase 4: GPS Features (Week 5-6)
- [ ] Live GPS tracking during round
- [ ] Distance to green/hazards
- [ ] Shot distance measurement
- [ ] Offline course map support

### Phase 5: Apple Watch (Week 6-8)
- [ ] Native Swift Watch app
- [ ] iOS ↔ Watch communication
- [ ] Simple score entry on Watch
- [ ] GPS distance display

### Phase 6: Weather & Reviews (Week 8-9)
- [ ] Weather API integration
- [ ] "Plays like" distance calculator
- [ ] Course review system
- [ ] Course discovery & search

### Phase 7: Polish & Launch (Week 9-10)
- [ ] App Store submission
- [ ] TestFlight beta
- [ ] Bug fixes & performance
- [ ] Documentation

---

## 7. Initial Course Data Seeding

### Priority Courses to Map First
1. User's home courses (on-demand)
2. Top 100 public courses (US)
3. Most-played courses by region
4. Courses with existing OSM data

### Manual Mapping Process
1. Use Google Earth/Maps to get coordinates
2. Mark tee boxes, greens (F/C/B), hazards
3. Export to JSON format
4. Submit for verification

---

## 8. Technical Requirements

### iOS App
- iOS 15+
- Expo SDK 50+
- React Native 0.73+
- Location permissions (foreground + background optional)

### Apple Watch
- watchOS 9+
- Swift 5.9+
- WatchConnectivity framework

### Backend
- PostGIS extension for Supabase
- Edge Functions for weather API proxy
- Realtime subscriptions for live tracking

---

## 9. Cost Estimates

| Item | Cost |
|------|------|
| Apple Developer Account | $99/year |
| Weather API (Open-Meteo) | Free |
| Supabase (current plan) | Free tier |
| Course Data | Free (user-contributed) |
| **Total** | **~$99/year** |

