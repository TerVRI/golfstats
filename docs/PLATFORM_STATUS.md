# Platform Status - Course Contribution Features

This document outlines what course contribution features are implemented across each platform.

## ✅ Web App (`apps/web`) - **COMPLETE**

All course contribution features are fully integrated:

### Implemented Features:
- ✅ **Course Contribution Page** (`/courses/contribute`)
  - OSM auto-fill for importing course data
  - Interactive map editor for GPS coordinates
  - Photo upload (requires storage bucket setup)
  - Real-time validation
  - Data completeness indicator
  - Full form with all course details

- ✅ **Course Confirmation** (`/courses/confirm/[id]`)
  - Review and confirm course data
  - Confidence level selection
  - Discrepancy notes

- ✅ **Leaderboard** (`/courses/leaderboard`)
  - Top contributors by total contributions
  - Top contributors by verified contributions
  - User stats and rankings

- ✅ **Notifications** (`/notifications`)
  - Notification bell in navigation
  - Full notification center
  - Real-time updates
  - Mark as read/delete

- ✅ **Course Discussions** (on course detail pages)
  - Discussion threads per course
  - Reply to discussions
  - Real-time updates

### Database:
- ✅ All migrations applied
- ✅ All tables created
- ✅ Functions and triggers working

### Remaining Setup:
- ⚠️ **Storage Bucket** - Need to create `course-photos` bucket in Supabase (see `SETUP_STORAGE_BUCKET.md`)

---

## 📱 iOS App (`apps/ios`) - **PARTIAL**

### Currently Implemented:
- ✅ **Course Viewing** (`CoursesView.swift`)
  - Browse courses
  - Search courses
  - View course details
  - See weather for courses
  - Start rounds at courses

- ✅ **Course Data Models** (`Models.swift`)
  - `Course` struct with all fields
  - `HoleData` struct
  - GPS coordinate support

- ✅ **Data Service** (`DataService.swift`)
  - `fetchCourses()` - Get all courses
  - `fetchCourse(id:)` - Get single course
  - `fetchNearbyCourses()` - Get courses by location

### Not Yet Implemented:
- ❌ **Course Contribution** - No UI for contributing courses
- ❌ **Course Confirmation** - No UI for confirming courses
- ❌ **Leaderboard** - No view for contributor leaderboard
- ❌ **Notifications** - No notification system
- ❌ **Discussions** - No discussion threads

### What Could Be Added (Recommended):

#### 1. Simplified Course Contribution
**Feasibility:** ⭐⭐⭐⭐ High
- Add "Contribute Course" button to `CoursesView`
- Create `ContributeCourseView.swift`
- Simplified form (name, location, basic info)
- Use device GPS for auto-fill
- Camera integration for photos
- Submit to `course_contributions` table

**Implementation Notes:**
- Use `MapKit` for location selection (native iOS)
- Use `UIImagePickerController` for photos
- Much simpler than web version (no map editor, no OSM search)
- Focus on quick contribution while on the course

#### 2. Course Confirmation
**Feasibility:** ⭐⭐⭐⭐ High
- Add "Confirm Course" button to `CourseDetailView`
- Create `ConfirmCourseView.swift`
- Simple checklist (dimensions match, locations match, etc.)
- Confidence slider
- Submit to `course_confirmations` table

**Implementation Notes:**
- Very simple UI - just checkboxes and slider
- Can be done quickly after playing a round

#### 3. Leaderboard View
**Feasibility:** ⭐⭐⭐⭐⭐ Very High
- Add "Leaderboard" tab or button
- Create `ContributorLeaderboardView.swift`
- Fetch from `contributor_reputation` table
- Display top contributors

**Implementation Notes:**
- Simple list view
- Easy to implement

#### 4. Notifications
**Feasibility:** ⭐⭐⭐ Medium
- Add notification badge to tab bar
- Create `NotificationsView.swift`
- Fetch from `notifications` table
- Push notifications (requires APNs setup)

**Implementation Notes:**
- Requires push notification setup
- Can start with in-app notifications only

#### 5. Discussions
**Feasibility:** ⭐⭐⭐ Medium
- Add discussions section to `CourseDetailView`
- Create `CourseDiscussionsView.swift`
- Simple list of discussions with replies

**Implementation Notes:**
- Moderate complexity
- Can be added later

---

## ⌚ Watch App (`apps/watch`) - **VERY LIMITED**

### Currently Implemented:
- ✅ **Distance Tracking** - GPS-based yardages to green
- ✅ **Scorecard Entry** - Quick score entry
- ✅ **Shot Tracking** - Mark shots with GPS
- ✅ **Round Management** - Start/end rounds

### Watch Limitations:
- ⚠️ **Small Screen** - Very limited space for complex UI
- ⚠️ **Battery Life** - GPS tracking already uses significant battery
- ⚠️ **Input Method** - Difficult to enter text/data
- ⚠️ **Processing Power** - Limited for complex operations

### What's Feasible for Watch:

#### 1. Quick Course Confirmation ⭐⭐
**Feasibility:** ⭐⭐ Low-Medium
- After finishing a round, show "Confirm Course Data?" button
- Simple yes/no or thumbs up/down
- Very basic confirmation only
- No detailed feedback

**Implementation Notes:**
- Would need to be extremely simple
- Just a quick "This course data looks correct" button
- Submit minimal confirmation data

#### 2. View Course Info ⭐⭐⭐
**Feasibility:** ⭐⭐⭐ Medium
- Already partially implemented (course name, par values)
- Could show more course details during round
- Read-only, no contribution

**Implementation Notes:**
- This is already working via `WatchSyncManager`
- Can enhance to show more course details

#### 3. Photo Capture ⭐
**Feasibility:** ⭐ Very Low
- Watch camera is very limited
- Quality would be poor
- Not recommended

### What's NOT Feasible for Watch:
- ❌ Course contribution (too complex)
- ❌ Detailed confirmation forms
- ❌ Leaderboard viewing
- ❌ Discussions
- ❌ Notifications (can show on iPhone instead)

---

## 📊 Summary Table

| Feature | Web | iOS | Watch | Notes |
|---------|-----|-----|-------|-------|
| **Course Contribution** | ✅ Full | ❌ None | ❌ Not feasible | iOS could add simplified version |
| **Course Confirmation** | ✅ Full | ❌ None | ⭐⭐ Basic only | iOS should add, Watch could do minimal |
| **Leaderboard** | ✅ Full | ❌ None | ❌ Not feasible | iOS should add |
| **Notifications** | ✅ Full | ❌ None | ❌ Not feasible | iOS could add with push notifications |
| **Discussions** | ✅ Full | ❌ None | ❌ Not feasible | iOS could add later |
| **Photo Upload** | ✅ Full | ❌ None | ❌ Not feasible | iOS should add with camera |
| **Map Editor** | ✅ Full | ❌ None | ❌ Not feasible | iOS could use MapKit |
| **OSM Auto-fill** | ✅ Full | ❌ None | ❌ Not feasible | iOS could add |
| **View Courses** | ✅ Full | ✅ Full | ⭐ Partial | Watch shows course name/par |

---

## 🎯 Recommended Next Steps

### Priority 1: iOS App Enhancements
1. **Add Course Confirmation** - Quick win, high value
2. **Add Leaderboard View** - Easy to implement, motivates users
3. **Add Simplified Course Contribution** - Use GPS and camera, submit basic info

### Priority 2: Watch App (Minimal)
1. **Quick Course Confirmation** - Simple yes/no after round
2. **Enhanced Course Info Display** - Show more details during round

### Priority 3: iOS App (Later)
1. **Notifications** - Requires push notification setup
2. **Discussions** - Nice to have, lower priority

---

## 📝 Implementation Notes

### iOS Course Contribution (Simplified)
- Use native `MapKit` for location selection
- Use `UIImagePickerController` for photos
- Auto-fill GPS from device location
- Submit to same `course_contributions` table
- Much simpler than web - focus on quick contribution

### iOS Course Confirmation
- Add button to `CourseDetailView`
- Simple checklist UI
- Submit to `course_confirmations` table
- Can be done quickly after playing

### Watch Quick Confirmation
- After round ends, show confirmation prompt
- Just "Confirm" or "Skip" buttons
- Submit minimal data to `course_confirmations`
- Keep it extremely simple

---

## ✅ Current Status

- **Web App:** 100% complete ✅
- **iOS App:** 20% complete (viewing only) 📱
- **Watch App:** 0% for contributions (not feasible) ⌚

**Overall:** Web app is fully functional. iOS app can view courses but can't contribute. Watch app is focused on round tracking, not course contributions.
