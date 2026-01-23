# RoundCaddy Android

Native Android app for RoundCaddy built with Kotlin and Jetpack Compose.

## Prerequisites
- Android Studio (latest stable)
- Android SDK Platform (API 34 or newer)
- Android SDK Build-Tools (latest)
- Android Emulator (optional)

## Local setup
1. Open `apps/android` in Android Studio.
2. Configure SDK path if prompted.
3. Ensure `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `MAPS_API_KEY` are set in the repo root `.env.local`.
4. (Optional) Create a `local.properties` file in `apps/android` to override:

```
sdk.dir=/Users/<your-user>/Library/Android/sdk
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
MAPS_API_KEY=YOUR_GOOGLE_MAPS_KEY
```

5. Sync Gradle.
6. Run the `app` configuration on a device or emulator.

## Notes
- Supabase credentials are loaded from root `.env.local`, with `local.properties` taking precedence.
- Do not commit secrets.
- If Android Studio prompts for updates, accept recommended SDK and Gradle updates.
