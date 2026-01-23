# Model B Implementation TODOs (iOS IAP + Web Subscription)

This checklist tracks the agreed Model B approach: iOS access via Apple IAP,
web/Android access via website subscription. No web purchase unlocks iOS.

## Product / Entitlements
- Define entitlement rules (iOS IAP unlocks iOS Pro only)
- Separate web subscription entitlements (web/Android only)
- Prevent iOS UI from referencing web purchase

## Free Tier Limits
- Cap free users to 5 stored rounds
- Allow delete to free up slots
- iOS-only live tracking for free tier (no Watch features)

## iOS Purchases
- Implement StoreKit 2 subscriptions (monthly + annual)
- Add 14-day free trial to both plans
- Add paywall UI with auto-renew terms and price
- Add server receipt validation and entitlement sync

## UI / Messaging
- Label Watch, swing analytics, coaching as Pro-only
- Add upgrade prompts where appropriate (no external links)
- Show free tier limitations clearly

## Compliance / Review
- Add in-app account deletion flow
- Fix Sign in with Apple error
- Update App Store privacy labels (no tracking if accurate)
- Add Review Notes: business model + no WeatherKit (if accurate)

## Web Subscription
- Implement Stripe checkout on RoundCaddy.com
- Clarify web subscription applies to web/Android only
- Keep web purchase flow out of iOS app UI
