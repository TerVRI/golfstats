# Incomplete Courses & Gamification Proposal

## Overview

While most missing OSM courses likely have coordinates (they just weren't imported due to timeouts or bounding box limitations), we should design a system to:

1. **Import courses with partial data** (name + address but no coordinates)
2. **Allow users to complete them** (add coordinates, verify details)
3. **Gamify the completion process** (badges, leaderboards, competitions)

## Analysis Summary

Based on our investigation:
- **Missing 17,087 courses** are likely courses WITH coordinates that:
  - Were in regions that timed out
  - Fall outside our defined bounding boxes
  - Need to be re-imported with better regional coverage

- **Courses WITHOUT coordinates** are rare in OSM, but when found, they typically have:
  - Course names
  - Addresses (city, country, street)
  - Contact information (website, phone)
  - Can be geocoded or manually located by users

## Proposed Solution

### 1. Database Schema Changes

Add new status types and fields to `course_contributions`:

```sql
-- Add new status for incomplete courses
ALTER TYPE contribution_status ADD VALUE IF NOT EXISTS 'incomplete';
ALTER TYPE contribution_status ADD VALUE IF NOT EXISTS 'needs_location';
ALTER TYPE contribution_status ADD VALUE IF NOT EXISTS 'needs_verification';

-- Add fields for incomplete course tracking
ALTER TABLE course_contributions
ADD COLUMN IF NOT EXISTS completion_priority INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS missing_fields TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS geocoded BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS geocoded_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS completed_by UUID REFERENCES profiles(id),
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP WITH TIME ZONE;

-- Index for finding incomplete courses
CREATE INDEX IF NOT EXISTS idx_course_contributions_incomplete 
ON course_contributions(status, completion_priority DESC) 
WHERE status IN ('incomplete', 'needs_location', 'needs_verification');
```

### 2. Import Strategy for Incomplete Courses

**Criteria for importing as incomplete:**
- ✅ Has name OR address
- ❌ Missing coordinates (or coordinates are invalid)
- ✅ Has at least one other field (phone, website, city, etc.)

**Priority scoring:**
- Name + Address: Priority 10 (highest - can be geocoded)
- Name only: Priority 7 (users can search)
- Address only: Priority 5 (can be geocoded)
- Other data only: Priority 3 (lowest)

### 3. User Completion Flow

**Step 1: Find Incomplete Courses**
- Browse "Incomplete Courses" section
- Filter by country, missing field type
- Search by name or address

**Step 2: Complete Course**
- **Option A: Geocoding** (if address exists)
  - Click "Geocode Address" button
  - System uses geocoding API to get coordinates
  - User verifies location on map
  - User can adjust if needed

- **Option B: Manual Location** (if no address)
  - User searches for course by name
  - User places marker on map
  - User adds any missing details

**Step 3: Verification**
- Course status changes to "pending"
- Goes through normal approval process
- Completer gets credit when approved

### 4. Gamification System

#### Badges

**Course Completion Badges:**
- 🏆 **Course Completer** - Complete 1 incomplete course
- 🏆 **Location Master** - Add coordinates to 5 courses
- 🏆 **Map Builder** - Complete 10 incomplete courses
- 🏆 **Geocoding Expert** - Geocode 20 courses with addresses
- 🏆 **Country Completer** - Complete all incomplete courses in your country
- 🏆 **Global Mapper** - Complete courses in 5 different countries

**Quality Badges:**
- ⭐ **Detail Master** - Complete courses with all fields (name, address, phone, website)
- ⭐ **Verification Pro** - 10 of your completed courses get approved
- ⭐ **Community Helper** - Help complete 50 courses total

#### Leaderboards

**Monthly Leaderboards:**
- 🥇 Top Course Completers (by count)
- 🥇 Most Verified Completions (by approval rate)
- 🥇 Most Countries Covered
- 🥇 Highest Quality Score (completeness + verification)

**All-Time Leaderboards:**
- 🏅 Hall of Fame - Top 100 all-time completers
- 🏅 Country Champions - Top completer per country
- 🏅 Quality Masters - Highest verification rate (min 20 completions)

#### Competitions

**Monthly Challenges:**
- 🎯 **"Complete the Map"** - Complete all incomplete courses in your country
- 🎯 **"Global Explorer"** - Complete courses in 10 different countries
- 🎯 **"Speed Mapper"** - Complete 20 courses in one week
- 🎯 **"Quality Quest"** - Complete 10 courses with 100% data completeness

**Special Events:**
- 🌍 **"World Golf Day"** - Global competition to complete courses worldwide
- 🎉 **"New Year Mapping"** - Start of year challenge
- 🏌️ **"Golf Month"** - Month-long completion challenge

#### Rewards System

**Points System:**
- Complete 1 course: +10 points
- Complete with geocoding: +15 points
- Complete with all fields: +20 points
- Get verified: +25 points
- Complete in new country: +30 points

**Unlockables:**
- Special profile badges
- Custom map markers
- Early access to features
- Recognition in app

### 5. Implementation Plan

#### Phase 1: Database & Schema
- [ ] Add new status types
- [ ] Add completion tracking fields
- [ ] Create indexes
- [ ] Migration script

#### Phase 2: Import Script
- [ ] Create script to find incomplete courses
- [ ] Import with `status='incomplete'`
- [ ] Set `completion_priority` based on available data
- [ ] Populate `missing_fields` array

#### Phase 3: UI Components
- [ ] Incomplete courses list page
- [ ] Course completion form
- [ ] Geocoding integration
- [ ] Map interface for manual location

#### Phase 4: Gamification
- [ ] Badge system
- [ ] Leaderboard pages
- [ ] Competition system
- [ ] Points/rewards tracking

#### Phase 5: User Flow
- [ ] Complete course workflow
- [ ] Verification process
- [ ] Credit assignment
- [ ] Notification system

### 6. Example User Journey

**Sarah discovers an incomplete course:**

1. **Discovery**: Sarah browses "Incomplete Courses" and finds "Riverside Golf Club" in her city
   - Status: `incomplete`
   - Has: Name, city, website
   - Missing: Coordinates, full address

2. **Completion**: Sarah clicks "Complete This Course"
   - She searches for the course online
   - Finds the address: "123 Golf Road, Riverside, CA"
   - Clicks "Geocode Address"
   - System finds coordinates: 34.0522, -118.2437
   - Sarah verifies location on map (looks correct!)
   - Adds phone number from website
   - Submits for verification

3. **Rewards**: 
   - Sarah earns: +15 points (geocoded completion)
   - Badge progress: "Location Master" (1/5)
   - Course status: `pending` (awaiting approval)

4. **Verification**:
   - Course gets approved by community
   - Sarah earns: +25 points (verification bonus)
   - Badge unlocked: "Location Master" ✅
   - Course status: `approved`
   - Sarah's profile shows: "Completed 1 course"

### 7. Benefits

**For Users:**
- 🎮 Engaging gameplay loop
- 🏆 Recognition and achievements
- 🌍 Help build the global golf course database
- 💪 Sense of contribution and community

**For Platform:**
- 📈 More complete course database
- 👥 Increased user engagement
- 🔄 User-generated content
- 🌟 Community building

**For Golf Community:**
- 🗺️ More accurate course locations
- 📍 Better course discovery
- ✅ Verified course information
- 🌐 Global coverage improvement

### 8. Technical Considerations

**Geocoding Services:**
- Use Google Geocoding API (or similar)
- Cache results to avoid duplicate API calls
- Handle rate limiting
- Fallback to manual location if geocoding fails

**Performance:**
- Index incomplete courses for fast queries
- Paginate incomplete courses list
- Cache leaderboard data
- Background job for badge calculations

**Data Quality:**
- Validate coordinates before submission
- Check for duplicates (same location, different name)
- Require minimum data quality for completion
- Review process for completed courses

## Next Steps

1. **Create migration** for database schema changes
2. **Build import script** to find and import incomplete courses
3. **Design UI mockups** for incomplete courses interface
4. **Implement completion flow** with geocoding
5. **Build gamification system** (badges, leaderboards)
6. **Test with real users** and iterate

## Conclusion

Even if most missing courses have coordinates, building this system provides:
- ✅ Framework for handling truly incomplete courses
- ✅ Engaging gamification to increase user participation
- ✅ Community-driven course completion
- ✅ Better data quality through user verification

This creates a win-win: users get engaging gameplay, and the platform gets a more complete, verified database.
