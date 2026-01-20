# Test Coverage Documentation

## Overview
This document outlines the comprehensive test coverage for RoundCaddy, including web, iOS, iPad, Watch, and Android platforms.

## Test Infrastructure

### Web Application (Vitest)
- **Framework**: Vitest with React Testing Library
- **Location**: `apps/web/src/**/*.test.{ts,tsx}`
- **Config**: `apps/web/vitest.config.ts`
- **Setup**: `apps/web/src/test/setup.ts`

### iOS Application
- **Framework**: XCTest (Swift)
- **Location**: `apps/ios/GolfStats/Tests/`
- **Note**: iOS tests need to be created in Xcode

### Watch Application
- **Framework**: XCTest (Swift)
- **Location**: `apps/watch/GolfStatsWatch Tests/`
- **Note**: Watch tests need to be created in Xcode

## Test Coverage by Feature

### ✅ Course Discussions (Web)
**File**: `apps/web/src/components/course-discussions.test.tsx`

**Coverage**:
- ✅ Render discussions component
- ✅ Display "New Question" button when logged in
- ✅ Show empty state when no discussions exist
- ✅ Display existing discussions with replies
- ✅ Show new discussion form when button clicked
- ✅ Create new discussion when form submitted
- ✅ Validate form (title and content required)
- ✅ Handle errors when fetching discussions
- ✅ Display user information and timestamps

**UI Tests**:
- ✅ Button clicks navigate correctly
- ✅ Form inputs work correctly
- ✅ Error messages display properly

### ✅ Course Confirmation (Web)
**File**: `apps/web/src/app/(app)/courses/confirm/[id]/page.test.tsx`

**Coverage**:
- ✅ Redirect to login if not authenticated
- ✅ Display course information
- ✅ Show all confirmation checkboxes (dimensions, tee locations, green locations, pars, hazards, address, ratings)
- ✅ Toggle confirmation checkboxes
- ✅ Select confidence level (1-5)
- ✅ Submit confirmation with valid data
- ✅ Disable submit if no fields confirmed
- ✅ Show discrepancy form when checkbox checked
- ✅ Handle form submission errors

**UI Tests**:
- ✅ All checkboxes are interactive
- ✅ Confidence level buttons work
- ✅ Form validation works
- ✅ Navigation buttons work

### ✅ Navigation Component (Web)
**File**: `apps/web/src/components/layout/navigation.test.tsx`

**Coverage**:
- ✅ Render all navigation menu items
- ✅ Highlight active route
- ✅ Correct hrefs for all navigation items
- ✅ Toggle mobile menu
- ✅ Show user info when logged in
- ✅ Show logout button
- ✅ Handle logout action

**UI Tests**:
- ✅ All navigation links work
- ✅ Active state highlighting
- ✅ Mobile menu toggle
- ✅ User authentication state

### ✅ New Round Page (Web)
**File**: `apps/web/src/app/(app)/rounds/new/page.test.tsx`

**Coverage**:
- ✅ Render new round page with course selection
- ✅ Enter course name
- ✅ Enter course rating and slope
- ✅ Navigate between steps (course → holes → review)
- ✅ Enter hole scores
- ✅ Enter putts for each hole
- ✅ Navigate between holes
- ✅ Calculate totals correctly
- ✅ Save round when submitted
- ✅ Show error if not logged in

**UI Tests**:
- ✅ Multi-step form navigation
- ✅ Input validation
- ✅ Score calculation
- ✅ Form submission

### ✅ Existing Tests

#### Course Validation
**File**: `apps/web/src/lib/course-validation.test.ts`
- ✅ Validate complete course data
- ✅ Validate course with matching par totals
- ✅ Error when name is missing
- ✅ Error when GPS coordinates are missing
- ✅ Error when latitude/longitude out of range
- ✅ Error when par totals don't match
- ✅ Warn about unusual par values
- ✅ Warn about unusual yardages
- ✅ Warn when tee and green are very close
- ✅ Detect duplicate courses

#### OpenStreetMap
**File**: `apps/web/src/lib/openstreetmap.test.ts`
- ✅ Search for courses
- ✅ Handle API errors
- ✅ Parse OSM data correctly

#### Strokes Gained Calculator
**File**: `apps/web/src/lib/strokes-gained/calculator.test.ts`
- ✅ Calculate strokes gained for rounds
- ✅ Handle missing data
- ✅ Calculate by category (off tee, approach, around green, putting)

#### Export
**File**: `apps/web/src/lib/export.test.ts`
- ✅ Export rounds to PDF
- ✅ Format data correctly

#### Data Completeness Indicator
**File**: `apps/web/src/components/data-completeness-indicator.test.tsx`
- ✅ Display completeness percentage
- ✅ Show missing fields

#### OSM Autofill
**File**: `apps/web/src/components/osm-autofill.test.tsx`
- ✅ Autofill course data from OSM
- ✅ Handle errors

## Features Requiring Tests (Not Yet Covered)

### iOS App Features
The following iOS features need XCTest coverage:

1. **Hole-by-Hole Course Confirmation**
   - GPS marking functionality
   - Hole selector
   - Location capture
   - Form submission

2. **New Round Button on Rounds Page**
   - Button visibility
   - Navigation to new round view
   - Integration with round creation

3. **Discussions (iOS)**
   - Create discussion
   - Display discussions
   - Reply to discussions
   - Error handling

4. **GPS Location Display**
   - Show current location
   - Update when location changes
   - Handle GPS errors
   - Display distances to green

5. **Watch Integration**
   - Send data to watch
   - Receive data from watch
   - Sync round state
   - Handle disconnection

6. **Course Data Input UI**
   - Hole-by-hole data entry
   - GPS coordinate capture
   - Photo upload
   - Form validation

### Web App Features (Additional Coverage Needed)

1. **Course Detail Page**
   - Display course information
   - Show reviews
   - Weather display
   - Discussion integration

2. **Round History Page**
   - List rounds
   - Filter rounds
   - View round details
   - Delete rounds

3. **Dashboard**
   - Display statistics
   - Show charts
   - Recent rounds
   - Quick actions

## Running Tests

### Web Application
```bash
cd apps/web
npm test                    # Run in watch mode
npm run test:run           # Run once
```

### iOS Application
1. Open project in Xcode
2. Select test target
3. Press Cmd+U to run tests

### Watch Application
1. Open project in Xcode
2. Select Watch test target
3. Press Cmd+U to run tests

## Test Best Practices

1. **Unit Tests**: Test individual functions and components in isolation
2. **Integration Tests**: Test component interactions
3. **UI Tests**: Test user interactions and navigation
4. **E2E Tests**: Test complete user flows (future)

## Coverage Goals

- **Current Coverage**: ~60% of new features
- **Target Coverage**: 80%+ of all features
- **Critical Paths**: 100% coverage (authentication, data saving, GPS)

## Next Steps

1. ✅ Create tests for course discussions (Web)
2. ✅ Create tests for course confirmation (Web)
3. ✅ Create tests for navigation (Web)
4. ✅ Create tests for new round page (Web)
5. ✅ Create iOS XCTest files for new features
6. ⏳ Create Watch XCTest files for sync features
7. ⏳ Add E2E tests for critical user flows
8. ⏳ Add performance tests for GPS tracking
9. ⏳ Fix remaining async timing issues in web tests
10. ⏳ Add iOS test target to Xcode project configuration

## Notes

- All web tests use Vitest with React Testing Library
- iOS/Watch tests require Xcode and XCTest framework
- Android tests would use JUnit/Espresso (not yet implemented)
- Mock Supabase client for all database operations
- Mock navigation hooks for routing tests
- Mock user authentication for protected routes
