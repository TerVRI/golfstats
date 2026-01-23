# Arccos Features Analysis & Implementation Checklist

This document catalogs all features observed from Arccos screenshots and website research, organized by implementation priority for RoundCaddy.

---

## Onboarding Flow Features

### Profile Setup Wizard (6 steps in Arccos)
- [ ] Birthday collection (age-based insights)
- [ ] Gender selection (male/female baseline comparison)
- [ ] Handicap/average score slider (Tour Pro to Beginner)
- [ ] Play frequency (rounds per year: Rarely to Constantly)
- [ ] Driver distance estimate (slider)
- [ ] Handedness (right/left handed)
- [ ] Projected handicap improvement display ("We can get you to 11 HI")
- [ ] Video explainer with instructor

### Sensor Pairing (if applicable)
- [ ] "Already ordered sensors?" prompt
- [ ] "Play without sensors" option
- [ ] Club selection grid (Woods, Hybrids, Irons, Wedges, Putter)

---

## In-Round Experience

### Course/Round Setup
- [ ] Course search with location
- [ ] "AI Strategy is here!" banner/promo
- [ ] Home course setting
- [ ] Shot detection mode selection:
  - [ ] Phone
  - [ ] Pair Arccos Link
  - [ ] Watch
  - [ ] No Shot Detection
- [ ] Accessories section (Smart Laser)
- [ ] Tee selection (Blue/Yellow/Red with colors)
- [ ] Starting hole (1, 10, Other)
- [ ] Tee time picker with date
- [ ] Weather display on setup (temp, high/low, precip, wind)
- [ ] "View your strategy" button

### Full-Screen Map View
- [ ] Satellite imagery (Apple Maps)
- [ ] Hole navigation pills (1, 2, 3, 4... scrollable)
- [ ] Par/yardage/handicap display per hole
- [ ] Settings gear icon
- [ ] Report issue icon (!)
- [ ] Wind speed & direction badge (e.g., "5 MPH" with arrow)

### Distance Display
- [ ] GPS distance to target
- [ ] "Plays Like" adjusted distance (e.g., "170y | 173y PLAYS")
- [ ] Club recommendation pill (e.g., "4i 170")
- [ ] Position indicator (LEFT, CENTER, RIGHT)
- [ ] Distance to layup positions

### Environmental Adjustments Detail Panel
- [ ] Wind: speed + yardage effect
- [ ] Slope: elevation + yardage effect
- [ ] Temperature: degrees + yardage effect
- [ ] Humidity: percentage + yardage effect
- [ ] Altitude: feet + yardage effect
- [ ] Club options row (7w, 8w, 4i, 9w, 5i)
- [ ] "Get distance to pin" button

### AI Strategy / Smart Play
- [ ] TEE STRATEGY label
- [ ] "SMART PLAY" with checkmark to set
- [ ] Strategy notation (e.g., "3h > Lw > flag")
- [ ] xScore (expected strokes: 4.17)
- [ ] Probability breakdown:
  - [ ] Birdie %
  - [ ] Par %
  - [ ] Bogey %
- [ ] ALTERNATE strategy cards (swipeable)
- [ ] CUSTOM strategy option
- [ ] Shot line visualization on map
- [ ] Shot dispersion ellipse overlay

### Approach Strategy
- [ ] Approach strategy panel (similar to tee)
- [ ] "DRAG PIN" to set hole location
- [ ] Pin position distances (front, middle, back)
- [ ] Bunker/hazard distances shown
- [ ] "GO FOR IT" alternative strategy

### Loading States
- [ ] "Mitigating Short-Side Risk..." AI processing indicator
- [ ] Diamond/gem animation during calculation

### Pin Placement
- [ ] "SET PIN" button with flag icon
- [ ] Draggable pin on green
- [ ] Green distances (front/back/sides) in yards
- [ ] Zoom control on green view

---

## Smart Club Distances

### Club Distance List
- [ ] Club Distances dropdown
- [ ] "Using last 100 shots" filter
- [ ] Filter icon
- [ ] Wrench icon (manage clubs)
- [ ] "Your Smart Distances (yds)" header
- [ ] Paginated dots (multiple views)
- [ ] All clubs listed (Dr, 3w, 7w, 8w, 9w, 12w, 13w, 14w, 3h, 4i-Gw)
- [ ] Distance bar visualization per club
- [ ] Distance value in yards

### Individual Club Detail
- [ ] Club name with type (e.g., "Anser (12w)")
- [ ] STATS / USAGE / MANAGE CLUB tabs
- [ ] "Not enough rounds" empty state
- [ ] Usage frequency tracking
- [ ] Average distance
- [ ] Dispersion pattern

---

## Player Profile / Analytics

### Dashboard Header
- [ ] Player name
- [ ] Handicap index (N/A if not enough data)
- [ ] Shots count
- [ ] Rounds count
- [ ] Settings gear icon
- [ ] "Compared to X H.I. using 5 Round Avg" selector

### Analytics Tabs
- [ ] OVERALL
- [ ] DRIVING
- [ ] APPROACH
- [ ] SHORT GAME
- [ ] PUTTING
- [ ] PERSONAL (additional tab)

### Trend Analysis
- [ ] Trend line chart (multi-line for comparison)
- [ ] "Latest" marker on current position
- [ ] "Your Trend Analysis will become available once you play your first round of at least 6 holes!" message

### Scoring Analysis
- [ ] Horizontal scoring slider visualization
- [ ] Scoring categories/buckets

### Driving Tab
- [ ] Strokes Gained value (e.g., "-2.6")
- [ ] Trend direction arrow
- [ ] Trend line chart
- [ ] "Distance vs. Accuracy" scatter plot
- [ ] "Distance Off the Tee" with crown icon
- [ ] Distance value (e.g., "263")
- [ ] Comparison slider (you vs benchmark)

### Overall SG Breakdown
- [ ] Total SG per round (e.g., "-1.3")
- [ ] Improvement indicator (e.g., "+1.1")
- [ ] "SG / Round" label
- [ ] Driving SG (with color: red for negative)
- [ ] Approach SG (with color: green for positive)
- [ ] Short SG
- [ ] Putting SG
- [ ] "Show Handicap Breakdown" toggle

---

## Post-Round Experience

### Round Review
- [ ] Course name, date, tee, score badge
- [ ] GOOD SHOTS / EDIT/POST NOTES tabs
- [ ] Hole-by-hole scorecard grid
- [ ] Shot details expandable per hole
- [ ] Fairway indicators
- [ ] GIR indicators
- [ ] Putts count

### Shot Editing
- [ ] "Drag the headers up & down to change which shots are assigned to which holes"
- [ ] Hole list with "Not Played" status
- [ ] Shot detail (club, distance, result)
- [ ] Birdie/Par/Bogey labels

### USGA Posting
- [ ] "Post To USGA?" prompt
- [ ] "Yes, Prepare Round for USGA" button
- [ ] "No Thanks" option
- [ ] "Don't ask me again" checkbox

### Top Shots / PGA TOUR Quality
- [ ] "Top Shots celebrates some of your best moments from each round"
- [ ] "PGA TOUR Quality" badge for exceptional approach shots
- [ ] Proximity to hole comparison vs PGA TOUR average
- [ ] Shareable achievement cards

---

## Settings & Account

### USGA Verification
- [ ] USGA logo
- [ ] "USGA Handicap ID" field
- [ ] "USGA Email Address" field
- [ ] "Don't have a Handicap Index? Get one" link
- [ ] Submit button

### Device Connections
- [ ] Smart Laser Diagnostics
  - [ ] Connected Device Name
  - [ ] MAC Address
  - [ ] Firmware Version
  - [ ] Clear/Disconnect option

### Report Issue System
- [ ] Issue selection checklist:
  - [ ] Club recommendations are wrong
  - [ ] Smart targets are wrong (typically underlying course mapping issue)
  - [ ] Dispersion ellipse sizes feel too big
  - [ ] Dispersion ellipse sizes feel too small
  - [ ] Score percentages are wrong
  - [ ] Course mapping issue
  - [ ] Battery drain
  - [ ] Missing some putts
  - [ ] Missing too many shots
  - [ ] No shots detected
  - [ ] Had to delete too many shots
  - [ ] Shots on the wrong hole
- [ ] "Tell us more (optional)" text field
- [ ] Submit issue button

---

## Subscription/Paywall

### 18Birdies Integration (Arccos uses 18Birdies for subscription)
- [ ] "Play Golf with Confidence!" headline
- [ ] Review count + star rating (220K+ Reviews, 4.9/5)
- [ ] Feature checklist:
  - [ ] Distance to every hole location & hazard
  - [ ] Swing tips + course strategy suggestions
  - [ ] Make better club selections & hit more greens
  - [ ] Adjustments for slope, wind & temperature
  - [ ] Secured with Apple, cancel anytime, risk-free
- [ ] Pricing tiers:
  - [ ] 7 Days Free → €99.99/Year ("Best Value")
  - [ ] 7 Days Free → €22.99/Month
  - [ ] €8.99/Week
- [ ] "Continue" button
- [ ] Legal text (cancel anytime, auto-renew, etc.)
- [ ] App Store purchase confirmation sheet

---

## UI Patterns to Replicate

### Color Scheme
- [ ] Dark mode primary (dark gray/black backgrounds)
- [ ] Green accent for positive/CTA buttons
- [ ] Red for negative values (losing strokes)
- [ ] Yellow for bunkers
- [ ] Blue for water/distances
- [ ] White/gray text hierarchy

### Typography
- [ ] Large bold numbers for distances
- [ ] Condensed caps for labels (TEE STRATEGY, SMART PLAY)
- [ ] Italic for headlines ("How can Arccos help?")

### Interaction Patterns
- [ ] Swipeable cards for strategies
- [ ] Pull-up drawers for details
- [ ] Floating badges that don't obstruct map
- [ ] Tap-to-set pin location
- [ ] Long-press for context menus

---

## Data We Need to Collect

To implement these features, track:
- [ ] Every shot: club, start location, end location, timestamp
- [ ] Environmental conditions at shot time
- [ ] Pin positions per hole
- [ ] Lie type (fairway, rough, bunker, etc.)
- [ ] Shot result (GIR, miss left/right/short/long)
- [ ] Putt distances and makes/misses

---

## Implementation Order

### Phase 1 (Core Experience)
1. Full-screen map with satellite toggle
2. Basic distance display (GPS + Plays Like)
3. Hole navigation pills
4. Simple club recommendation

### Phase 2 (Smart Features)
5. Environmental adjustments panel
6. AI Strategy with probability %
7. Shot dispersion ellipse
8. Pin placement tool

### Phase 3 (Analytics)
9. Multi-tab player analytics
10. Strokes Gained breakdown
11. Trend charts
12. Club distance tracking

### Phase 4 (Polish)
13. Post-round review with editing
14. USGA integration
15. Report issue system
16. Achievement celebrations
