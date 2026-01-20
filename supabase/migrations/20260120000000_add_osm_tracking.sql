-- ============================================
-- ADD OSM TRACKING COLUMNS TO COURSE_CONTRIBUTIONS
-- ============================================
-- This allows us to track which courses came from OpenStreetMap
-- and prevent duplicate imports

ALTER TABLE public.course_contributions
ADD COLUMN IF NOT EXISTS osm_id TEXT,
ADD COLUMN IF NOT EXISTS osm_type TEXT;

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_course_contributions_osm_id 
ON public.course_contributions(osm_id) 
WHERE osm_id IS NOT NULL;

-- Unique constraint to prevent duplicate OSM imports
CREATE UNIQUE INDEX IF NOT EXISTS idx_course_contributions_osm_unique
ON public.course_contributions(osm_id, osm_type)
WHERE osm_id IS NOT NULL AND osm_type IS NOT NULL;

-- Add photo_urls and photos columns if they don't exist
ALTER TABLE public.course_contributions
ADD COLUMN IF NOT EXISTS photo_urls TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS photos JSONB DEFAULT '[]'::jsonb;
