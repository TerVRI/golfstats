# TestFlight Setup Guide for RoundCaddy

This guide walks you through publishing RoundCaddy iOS and Apple Watch apps to TestFlight.

## Prerequisites

- ✅ Apple Developer Program membership ($99/year)
- ✅ Xcode 15.0+ installed
- ✅ Valid Apple ID with developer account access
- ✅ Physical iPhone for testing (recommended)
- ✅ Physical Apple Watch for testing (recommended)

## Step 1: Apple Developer Portal Setup

### 1.1 Create App IDs

Go to [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list)

**Create iOS App ID:**
1. Click **+** to add new identifier
2. Select **App IDs** → Continue
3. Select **App** → Continue
4. Description: `RoundCaddy iOS`
5. Bundle ID: **Explicit** → `com.roundcaddy.ios`
6. Capabilities:
   - ✅ Sign In with Apple
   - ✅ App Groups (for watch communication)
7. Click **Register**

**Create watchOS App ID:**
1. Click **+** to add new identifier
2. Select **App IDs** → Continue
3. Select **App** → Continue
4. Description: `RoundCaddy Watch`
5. Bundle ID: **Explicit** → `com.roundcaddy.ios.watchkitapp`
6. Capabilities:
   - ✅ App Groups
7. Click **Register**

### 1.2 Create App Group

1. Go to **Identifiers** → Select type **App Groups**
2. Click **+** to add new
3. Description: `RoundCaddy Group`
4. Identifier: `group.com.roundcaddy`
5. Click **Register**

### 1.3 Update App IDs with App Group

1. Edit both App IDs
2. Enable **App Groups** capability
3. Select `group.com.roundcaddy`
4. Save

## Step 2: App Store Connect Setup

### 2.1 Create Your App

Go to [App Store Connect](https://appstoreconnect.apple.com)

1. Click **My Apps** → **+** → **New App**
2. Fill in details:
   - **Platforms**: iOS, watchOS
   - **Name**: `RoundCaddy`
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: Select `com.roundcaddy.ios`
   - **SKU**: `roundcaddy-ios` (unique identifier)
   - **User Access**: Full Access
3. Click **Create**

### 2.2 App Information

Fill out the **App Information** section:

```
Category: Sports
Content Rights: Does not contain third-party content
Age Rating: 4+ (no objectionable content)
```

### 2.3 Pricing and Availability

- **Price**: Free (or set your price)
- **Availability**: Available in all territories (or select specific)

## Step 3: Xcode Project Configuration

### 3.1 Set Your Development Team

1. Open `apps/ios/RoundCaddy.xcodeproj` in Xcode
2. Select project in navigator
3. Select **GolfStats** target
4. Go to **Signing & Capabilities**
5. Set **Team** to your Apple Developer team
6. Ensure **Automatically manage signing** is checked
7. Repeat for **GolfStatsWatch** target

### 3.2 Verify Bundle Identifiers

| Target | Bundle ID |
|--------|-----------|
| GolfStats (iOS) | `com.roundcaddy.ios` |
| GolfStatsWatch | `com.roundcaddy.ios.watchkitapp` |

### 3.3 Update Version Numbers

In `project.yml`:
```yaml
settings:
  base:
    MARKETING_VERSION: "1.0.0"
    CURRENT_PROJECT_VERSION: "1"
```

- `MARKETING_VERSION`: User-visible version (1.0.0)
- `CURRENT_PROJECT_VERSION`: Build number (increment for each upload)

### 3.4 Add App Group Capability

1. Select **GolfStats** target → **Signing & Capabilities**
2. Click **+ Capability**
3. Add **App Groups**
4. Enable `group.com.roundcaddy`
5. Repeat for **GolfStatsWatch** target

## Step 4: App Icons

### 4.1 Required Icon Sizes

**iOS App (1024x1024 source):**
- 1024x1024 @1x (App Store)

**watchOS App:**
See the icon generator script in `scripts/generate-app-icons.sh`

### 4.2 Generate Icons

1. Create a 1024x1024 PNG app icon
2. Run the icon generator:
   ```bash
   cd apps/ios
   ./scripts/generate-app-icons.sh path/to/your-icon-1024.png
   ```

### 4.3 Icon Design Guidelines

- Use a simple, recognizable design
- Works at small sizes (especially for watch)
- No transparency (solid background)
- Golf theme: consider flag, ball, fairway motif

## Step 5: Build and Archive

### 5.1 Select Archive Scheme

1. In Xcode, select **Product** → **Scheme** → **GolfStats**
2. Set destination to **Any iOS Device (arm64)**

### 5.2 Build Archive

1. **Product** → **Archive** (⌘⇧B to build first, then ⌘B to archive)
2. Wait for build to complete
3. Xcode Organizer opens automatically

### 5.3 Validate Archive

1. In Organizer, select your archive
2. Click **Validate App**
3. Select distribution options:
   - ✅ Upload your app's symbols
   - ✅ Manage version and build number
4. Select signing certificate (automatic)
5. Click **Validate**
6. Fix any errors and re-archive if needed

## Step 6: Upload to TestFlight

### 6.1 Upload Archive

1. In Organizer, select validated archive
2. Click **Distribute App**
3. Select **App Store Connect** → **Upload**
4. Options:
   - ✅ Upload your app's symbols
   - ✅ Manage version and build number
5. Click **Upload**
6. Wait for upload to complete (may take 10-30 minutes)

### 6.2 Processing

After upload:
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app → **TestFlight** tab
3. Build shows as "Processing" (5-30 minutes)
4. Once processed, status changes to "Ready to Submit" or shows issues

## Step 7: TestFlight Configuration

### 7.1 Add Test Information

In App Store Connect → TestFlight:

1. Click your build number
2. Fill in **Test Information**:
   - **What to Test**: Describe features to test
   - **Beta App Description**: Brief app description
   - **Feedback Email**: Your email for tester feedback

### 7.2 Export Compliance

Answer the encryption question:
- Select **No** (app doesn't use custom encryption, only HTTPS)
- This was already set in Info.plist: `ITSAppUsesNonExemptEncryption = NO`

### 7.3 Internal Testing (Your Team)

1. Go to **Internal Testing**
2. Add yourself and team members (up to 100)
3. Testers receive TestFlight invitation email
4. No Apple review required

### 7.4 External Testing (Public Beta)

1. Go to **External Testing**
2. Create a **New Group**
3. Add testers by email (up to 10,000)
4. **Submit for Beta App Review** (required for external)
5. Review typically takes 24-48 hours

## Step 8: Testing Checklist

### iOS App Testing

- [ ] Sign In with Apple works
- [ ] Dashboard loads user data
- [ ] Course search returns results
- [ ] GPS tracking activates
- [ ] Shot tracking records coordinates
- [ ] Round saves to Supabase
- [ ] Watch sync (if watch connected)

### watchOS App Testing

- [ ] App launches on watch
- [ ] GPS distance updates
- [ ] Score entry works
- [ ] Shot marking saves GPS
- [ ] Syncs with iPhone app
- [ ] Background location works

### Performance Testing

- [ ] App doesn't crash on launch
- [ ] Memory usage is reasonable
- [ ] Battery drain is acceptable
- [ ] GPS accuracy is sufficient

## Troubleshooting

### Archive Fails

```
"Code signing error"
```
→ Ensure team is set, certificates are valid

```
"Provisioning profile doesn't include capability"
```
→ Regenerate profiles in Developer Portal, or enable capability in App ID

### Upload Fails

```
"Missing compliance information"
```
→ Add `ITSAppUsesNonExemptEncryption` to Info.plist

```
"Invalid bundle identifier"
```
→ Ensure bundle IDs match between Xcode and App Store Connect

### TestFlight Issues

```
"Build is processing"
```
→ Wait 5-30 minutes, refresh page

```
"Missing push notification entitlement"
```
→ Remove push notification capability or add proper configuration

## Next Steps After TestFlight

### Preparing for App Store Release

1. **Screenshots**: 6.5" iPhone, 5.5" iPhone, iPad (if universal)
2. **App Preview Videos**: Optional but recommended
3. **Description**: Compelling App Store description
4. **Keywords**: Up to 100 characters
5. **Support URL**: Link to support page
6. **Privacy Policy URL**: Required for apps with account

### Submit for App Review

1. Complete all metadata
2. Upload screenshots
3. Submit for review
4. Typical review: 24-48 hours

---

## Quick Reference Commands

```bash
# Regenerate Xcode project from project.yml (if using XcodeGen)
cd apps/ios && xcodegen generate

# Open project in Xcode
open apps/ios/RoundCaddy.xcodeproj

# Build from command line
xcodebuild -project RoundCaddy.xcodeproj -scheme GolfStats -configuration Release

# Archive from command line
xcodebuild -project RoundCaddy.xcodeproj -scheme GolfStats -configuration Release archive -archivePath ./build/RoundCaddy.xcarchive
```

## Resources

- [App Store Connect Help](https://developer.apple.com/help/app-store-connect/)
- [TestFlight Documentation](https://developer.apple.com/testflight/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
