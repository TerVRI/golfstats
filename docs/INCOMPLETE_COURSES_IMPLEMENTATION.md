# Incomplete Courses Implementation Guide

## Quick Start

### 1. Apply Database Migration

```bash
# Apply the migration via Supabase SQL Editor or CLI
supabase migration up
```

Or manually run:
```sql
-- See: supabase/migrations/20260121000000_incomplete_courses.sql
```

### 2. Import Incomplete Courses (Optional)

```bash
npx tsx scripts/import-incomplete-courses.ts
```

**Note:** This is currently a sample script. Most missing courses likely have coordinates and just need to be re-imported with better regional coverage.

### 3. Build UI Components

See implementation plan in `INCOMPLETE_COURSES_PROPOSAL.md`

## Key Concepts

### Status Types

- **`incomplete`**: Course has name + address, can be geocoded (priority 7-10)
- **`needs_location`**: Course has minimal data, needs manual location (priority 3-6)
- **`needs_verification`**: Course was completed by user, awaiting approval

### Completion Priority

- **10**: Name + Address (highest - can be geocoded automatically)
- **7**: Name only (users can search)
- **5**: Address only (can be geocoded)
- **3**: Other data only (lowest priority)

### Missing Fields

Tracked in `missing_fields` array:
- `latitude`, `longitude` - Missing coordinates
- `name` - Missing course name
- `address` - Missing address
- `contact_info` - Missing phone/website/email

## API Endpoints Needed

### Get Incomplete Courses

```typescript
GET /api/courses/incomplete
Query params:
  - country?: string
  - priority?: number (min)
  - missing_field?: string
  - limit?: number
  - offset?: number
```

### Complete Course

```typescript
POST /api/courses/:id/complete
Body: {
  latitude: number;
  longitude: number;
  geocoded?: boolean;
  additional_data?: {
    phone?: string;
    website?: string;
    // ... other fields
  }
}
```

### Get User Completions

```typescript
GET /api/users/:id/completions
Query params:
  - status?: string
  - limit?: number
```

## Gamification Data

### Badges Table (to be created)

```sql
CREATE TABLE user_badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  badge_type TEXT NOT NULL,
  earned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, badge_type)
);
```

### Leaderboard Query

```sql
SELECT 
  p.id,
  p.name,
  COUNT(cc.id) as completions_count,
  COUNT(cc.id) FILTER (WHERE cc.status = 'approved') as verified_count
FROM profiles p
JOIN course_contributions cc ON cc.completed_by = p.id
WHERE cc.status IN ('approved', 'pending')
GROUP BY p.id, p.name
ORDER BY verified_count DESC, completions_count DESC
LIMIT 100;
```

## Next Steps

1. ✅ Database migration created
2. ⏳ Import script created (sample)
3. ⏳ API endpoints to be implemented
4. ⏳ UI components to be built
5. ⏳ Gamification system to be implemented

See `INCOMPLETE_COURSES_PROPOSAL.md` for full details.
