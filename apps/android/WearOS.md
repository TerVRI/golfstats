# Wear OS Parity Plan

This Android app focuses on phone parity first. Wear OS will mirror the Apple Watch feature set:

## Target features
- Quick score entry and hole navigation
- Distance display (front/middle/back) with GPS updates
- Shot confirmation prompts synced from phone
- Strokes gained snapshot and round status

## Phase plan
1. **Phone parity first**: ensure live round tracking and data sync are stable.
2. **Wear OS companion**: add a lightweight Wear OS module under `apps/android/wear`.
3. **Sync layer**: use Data Layer API for round state, shots, and score updates.
4. **Offline support**: queue updates when watch is disconnected.

## Notes
- If Wear OS is not installed, all features are available in the phone app.
- GPS on watch will be optional; the phone is the default location source.
