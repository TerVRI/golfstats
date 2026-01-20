# Environment Setup for OSM Import

## What You Have

Your `.env.local` file contains:
- ✅ `NEXT_PUBLIC_SUPABASE_URL` - Your Supabase project URL
- ✅ `NEXT_PUBLIC_SUPABASE_ANON_KEY` - Your anon/public key
- ✅ Database credentials

## What's Missing

The import script needs:
- ✅ `SUPABASE_URL` (can use `NEXT_PUBLIC_SUPABASE_URL` - script now supports this)
- ❌ `SUPABASE_SERVICE_KEY` - **You need to get this!**

## Getting the Service Role Key

The **service_role key** is different from the anon key. It has admin privileges needed to insert data.

### Steps:

1. Go to your Supabase Dashboard: https://app.supabase.com
2. Select your project
3. Go to **Settings** → **API**
4. Scroll down to find **service_role key** (it's in a different section than the anon key)
5. Click **Reveal** to show it
6. Copy the entire key (it's a long JWT token)

⚠️ **Security Note**: The service_role key has full admin access. Never commit it to git or expose it publicly!

## Option 1: Add to .env.local (Recommended)

Add this line to your `.env.local` file:

```bash
# Add this line to .env.local
SUPABASE_SERVICE_KEY=your-service-role-key-here
```

Then run:
```bash
npx tsx scripts/import-osm-courses.ts
```

The script will automatically read from `.env.local` if you have `NEXT_PUBLIC_SUPABASE_URL` set.

## Option 2: Use the Helper Script

I've created a helper script that loads `.env.local` automatically:

```bash
./scripts/load-env.sh
```

But you still need to add `SUPABASE_SERVICE_KEY` to `.env.local` first.

## Option 3: Inline (One-time)

If you don't want to save the service key to a file:

```bash
SUPABASE_SERVICE_KEY="your-service-role-key" \
npx tsx scripts/import-osm-courses.ts
```

## Updated Script

The import script now:
- ✅ Automatically uses `NEXT_PUBLIC_SUPABASE_URL` if `SUPABASE_URL` isn't set
- ✅ Warns you if you're using the anon key instead of service_role key
- ✅ Works with `.env.local` files

## Quick Start

1. **Get your service_role key** from Supabase Dashboard
2. **Add to `.env.local`**:
   ```bash
   SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```
3. **Run the import**:
   ```bash
   npx tsx scripts/import-osm-courses.ts
   ```

That's it! The script will automatically use your `.env.local` values.
