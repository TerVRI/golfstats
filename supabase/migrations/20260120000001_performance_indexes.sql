-- ============================================
-- PERFORMANCE INDEXES FOR COURSE QUERIES
-- ============================================
-- These indexes optimize location-based and country-based queries

-- Index for country filtering (most common query)
CREATE INDEX IF NOT EXISTS idx_courses_country 
ON public.courses(country) 
WHERE country IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_course_contributions_country 
ON public.course_contributions(country) 
WHERE country IS NOT NULL;

-- Index for location-based queries
CREATE INDEX IF NOT EXISTS idx_courses_location 
ON public.courses(latitude, longitude) 
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_course_contributions_location 
ON public.course_contributions(latitude, longitude) 
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- Index for source filtering (OSM courses)
CREATE INDEX IF NOT EXISTS idx_course_contributions_source 
ON public.course_contributions(source) 
WHERE source = 'osm';

-- Composite index for common query pattern: country + source
CREATE INDEX IF NOT EXISTS idx_course_contributions_country_source 
ON public.course_contributions(country, source) 
WHERE country IS NOT NULL AND source = 'osm';

-- Index for status filtering
CREATE INDEX IF NOT EXISTS idx_course_contributions_status 
ON public.course_contributions(status);

-- Index for review_count ordering (already exists but ensuring it's there)
CREATE INDEX IF NOT EXISTS idx_courses_review_count 
ON public.courses(review_count DESC) 
WHERE review_count > 0;

-- PostGIS index for spatial queries (if using PostGIS)
-- This enables efficient distance-based queries
CREATE INDEX IF NOT EXISTS idx_courses_location_postgis 
ON public.courses 
USING GIST (
  ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
) 
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_course_contributions_location_postgis 
ON public.course_contributions 
USING GIST (
  ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
) 
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- Analyze tables to update statistics
ANALYZE public.courses;
ANALYZE public.course_contributions;
