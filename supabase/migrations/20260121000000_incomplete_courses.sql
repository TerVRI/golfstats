-- Migration: Support for incomplete courses and gamification
-- This adds fields and status types for courses that need completion

-- Update the status CHECK constraint to include new status values
-- First, drop the existing constraint
ALTER TABLE public.course_contributions
DROP CONSTRAINT IF EXISTS course_contributions_status_check;

-- Add new constraint with all status values including incomplete statuses
ALTER TABLE public.course_contributions
ADD CONSTRAINT course_contributions_status_check 
CHECK (status IN (
    'pending', 
    'approved', 
    'rejected', 
    'merged',
    'incomplete',
    'needs_location',
    'needs_verification'
));

-- Add fields for incomplete course tracking
ALTER TABLE public.course_contributions
ADD COLUMN IF NOT EXISTS completion_priority INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS missing_fields TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS geocoded BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS geocoded_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS completed_by UUID REFERENCES public.profiles(id),
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP WITH TIME ZONE;

-- Add comment explaining completion_priority
COMMENT ON COLUMN public.course_contributions.completion_priority IS 
'Priority score for incomplete courses: 10=name+address, 7=name only, 5=address only, 3=other data';

COMMENT ON COLUMN public.course_contributions.missing_fields IS 
'Array of missing field names (e.g., ["latitude", "longitude", "phone"])';

COMMENT ON COLUMN public.course_contributions.geocoded IS 
'Whether coordinates were obtained via geocoding';

COMMENT ON COLUMN public.course_contributions.completed_by IS 
'User who completed this incomplete course';

-- Create index for finding incomplete courses efficiently
CREATE INDEX IF NOT EXISTS idx_course_contributions_incomplete 
ON public.course_contributions(status, completion_priority DESC) 
WHERE status IN ('incomplete', 'needs_location', 'needs_verification');

-- Create index for finding courses completed by a user
CREATE INDEX IF NOT EXISTS idx_course_contributions_completed_by 
ON public.course_contributions(completed_by, completed_at DESC) 
WHERE completed_by IS NOT NULL;

-- Create index for geocoded courses
CREATE INDEX IF NOT EXISTS idx_course_contributions_geocoded 
ON public.course_contributions(geocoded, geocoded_at DESC) 
WHERE geocoded = TRUE;
