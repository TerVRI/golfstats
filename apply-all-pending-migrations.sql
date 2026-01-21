-- ===========================================
-- COMBINED PENDING MIGRATIONS FOR ROUNDCADDY
-- ===========================================
-- Run this in Supabase SQL Editor
-- Date: 2026-01-20
-- 
-- Migrations included:
-- 1. Incomplete Courses (20260121000000)
-- 2. Badges System (20260121000001)
-- 3. Nearby Courses PostGIS Function (20260122000000)
-- ===========================================

-- ============================================
-- MIGRATION 1: INCOMPLETE COURSES
-- ============================================

-- Update the status CHECK constraint to include new status values
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

-- Add comments
COMMENT ON COLUMN public.course_contributions.completion_priority IS 
'Priority score for incomplete courses: 10=name+address, 7=name only, 5=address only, 3=other data';

COMMENT ON COLUMN public.course_contributions.missing_fields IS 
'Array of missing field names (e.g., ["latitude", "longitude", "phone"])';

COMMENT ON COLUMN public.course_contributions.geocoded IS 
'Whether coordinates were obtained via geocoding';

COMMENT ON COLUMN public.course_contributions.completed_by IS 
'User who completed this incomplete course';

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_course_contributions_incomplete 
ON public.course_contributions(status, completion_priority DESC) 
WHERE status IN ('incomplete', 'needs_location', 'needs_verification');

CREATE INDEX IF NOT EXISTS idx_course_contributions_completed_by 
ON public.course_contributions(completed_by, completed_at DESC) 
WHERE completed_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_course_contributions_geocoded 
ON public.course_contributions(geocoded, geocoded_at DESC) 
WHERE geocoded = TRUE;

-- ============================================
-- MIGRATION 2: BADGES SYSTEM
-- ============================================

-- 2.1 USER BADGES TABLE
CREATE TABLE IF NOT EXISTS public.user_badges (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    badge_type TEXT NOT NULL,
    badge_name TEXT NOT NULL,
    badge_description TEXT,
    badge_icon TEXT,
    earned_at TIMESTAMPTZ DEFAULT NOW(),
    progress INTEGER DEFAULT 100,
    metadata JSONB DEFAULT '{}',
    UNIQUE(user_id, badge_type),
    CONSTRAINT user_badges_badge_type_check CHECK (badge_type IN (
        'course_completer', 'location_master', 'map_builder', 'geocoding_expert',
        'country_completer', 'global_mapper', 'detail_master', 'verification_pro',
        'community_helper', 'first_contribution', 'contributor', 'active_contributor',
        'top_contributor', 'verifier', 'trusted_verifier', 'expert_verifier'
    ))
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_badges_user_id ON public.user_badges(user_id);
CREATE INDEX IF NOT EXISTS idx_user_badges_badge_type ON public.user_badges(badge_type);
CREATE INDEX IF NOT EXISTS idx_user_badges_earned_at ON public.user_badges(earned_at DESC);

-- RLS
ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view badges" ON public.user_badges;
CREATE POLICY "Anyone can view badges" ON public.user_badges
    FOR SELECT USING (TRUE);

-- 2.2 BADGE DEFINITIONS TABLE
CREATE TABLE IF NOT EXISTS public.badge_definitions (
    badge_type TEXT PRIMARY KEY,
    badge_name TEXT NOT NULL,
    badge_description TEXT NOT NULL,
    badge_icon TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('completion', 'quality', 'contribution', 'verification')),
    requirement_type TEXT NOT NULL CHECK (requirement_type IN ('count', 'threshold', 'custom')),
    requirement_value INTEGER,
    requirement_description TEXT,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert badge definitions
INSERT INTO public.badge_definitions (badge_type, badge_name, badge_description, badge_icon, category, requirement_type, requirement_value, requirement_description, display_order) VALUES
('course_completer', 'Course Completer', 'Complete 1 incomplete course', '🏆', 'completion', 'count', 1, 'Complete 1 incomplete course', 1),
('location_master', 'Location Master', 'Add coordinates to 5 courses', '📍', 'completion', 'count', 5, 'Add coordinates to 5 incomplete courses', 2),
('map_builder', 'Map Builder', 'Complete 10 incomplete courses', '🗺️', 'completion', 'count', 10, 'Complete 10 incomplete courses', 3),
('geocoding_expert', 'Geocoding Expert', 'Geocode 20 courses with addresses', '🌐', 'completion', 'count', 20, 'Use geocoding to add coordinates to 20 courses', 4),
('country_completer', 'Country Completer', 'Complete all incomplete courses in your country', '🏁', 'completion', 'custom', NULL, 'Complete all incomplete courses in your country', 5),
('global_mapper', 'Global Mapper', 'Complete courses in 5 different countries', '🌍', 'completion', 'count', 5, 'Complete courses in 5 different countries', 6),
('detail_master', 'Detail Master', 'Complete courses with all fields', '⭐', 'quality', 'count', 5, 'Complete 5 courses with all fields filled', 10),
('verification_pro', 'Verification Pro', '10 of your completed courses get approved', '✅', 'quality', 'count', 10, 'Have 10 of your completed courses approved', 11),
('community_helper', 'Community Helper', 'Help complete 50 courses total', '🤝', 'quality', 'count', 50, 'Complete 50 courses total', 12),
('first_contribution', 'First Contribution', 'Make your first course contribution', '🎯', 'contribution', 'count', 1, 'Make your first course contribution', 20),
('contributor', 'Contributor', 'Make 5 course contributions', '📝', 'contribution', 'count', 5, 'Make 5 course contributions', 21),
('active_contributor', 'Active Contributor', 'Make 20 course contributions', '🔥', 'contribution', 'count', 20, 'Make 20 course contributions', 22),
('top_contributor', 'Top Contributor', 'Make 100 course contributions', '👑', 'contribution', 'count', 100, 'Make 100 course contributions', 23),
('verifier', 'Verifier', 'Verify 5 courses', '🔍', 'verification', 'count', 5, 'Verify 5 courses', 30),
('trusted_verifier', 'Trusted Verifier', 'Verify 20 courses', '🛡️', 'verification', 'count', 20, 'Verify 20 courses', 31),
('expert_verifier', 'Expert Verifier', 'Verify 50 courses', '🎓', 'verification', 'count', 50, 'Verify 50 courses', 32)
ON CONFLICT (badge_type) DO NOTHING;

-- RLS for badge definitions
ALTER TABLE public.badge_definitions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view badge definitions" ON public.badge_definitions;
CREATE POLICY "Anyone can view badge definitions" ON public.badge_definitions
    FOR SELECT USING (TRUE);

-- 2.3 BADGE CALCULATION FUNCTION
CREATE OR REPLACE FUNCTION calculate_user_badges(p_user_id UUID)
RETURNS TABLE(badge_type TEXT, badge_name TEXT, earned BOOLEAN, progress INTEGER) AS $$
DECLARE
    v_completions_count INTEGER;
    v_verified_count INTEGER;
    v_geocoded_count INTEGER;
    v_countries_count INTEGER;
    v_contributions_count INTEGER;
    v_verifications_count INTEGER;
    v_full_completions_count INTEGER;
BEGIN
    SELECT 
        COUNT(*) FILTER (WHERE completed_by = p_user_id),
        COUNT(*) FILTER (WHERE completed_by = p_user_id AND status = 'approved'),
        COUNT(*) FILTER (WHERE completed_by = p_user_id AND geocoded = TRUE),
        COUNT(DISTINCT country) FILTER (WHERE completed_by = p_user_id),
        COUNT(*) FILTER (WHERE completed_by = p_user_id AND 
            missing_fields = '{}' OR array_length(missing_fields, 1) IS NULL)
    INTO 
        v_completions_count,
        v_verified_count,
        v_geocoded_count,
        v_countries_count,
        v_full_completions_count
    FROM public.course_contributions
    WHERE completed_by = p_user_id;

    SELECT COUNT(*) INTO v_contributions_count
    FROM public.course_contributions WHERE contributor_id = p_user_id;

    SELECT COUNT(*) INTO v_verifications_count
    FROM public.course_confirmations WHERE confirmer_id = p_user_id;

    RETURN QUERY
    SELECT 
        bd.badge_type,
        bd.badge_name,
        CASE 
            WHEN bd.requirement_type = 'count' THEN
                CASE bd.badge_type
                    WHEN 'course_completer' THEN v_completions_count >= 1
                    WHEN 'location_master' THEN v_completions_count >= 5
                    WHEN 'map_builder' THEN v_completions_count >= 10
                    WHEN 'geocoding_expert' THEN v_geocoded_count >= 20
                    WHEN 'global_mapper' THEN v_countries_count >= 5
                    WHEN 'detail_master' THEN v_full_completions_count >= 5
                    WHEN 'verification_pro' THEN v_verified_count >= 10
                    WHEN 'community_helper' THEN v_completions_count >= 50
                    WHEN 'first_contribution' THEN v_contributions_count >= 1
                    WHEN 'contributor' THEN v_contributions_count >= 5
                    WHEN 'active_contributor' THEN v_contributions_count >= 20
                    WHEN 'top_contributor' THEN v_contributions_count >= 100
                    WHEN 'verifier' THEN v_verifications_count >= 5
                    WHEN 'trusted_verifier' THEN v_verifications_count >= 20
                    WHEN 'expert_verifier' THEN v_verifications_count >= 50
                    ELSE FALSE
                END
            ELSE FALSE
        END as earned,
        CASE 
            WHEN bd.requirement_type = 'count' AND bd.requirement_value > 0 THEN
                LEAST(100, ROUND(
                    CASE bd.badge_type
                        WHEN 'course_completer' THEN (v_completions_count::DECIMAL / 1) * 100
                        WHEN 'location_master' THEN (v_completions_count::DECIMAL / 5) * 100
                        WHEN 'map_builder' THEN (v_completions_count::DECIMAL / 10) * 100
                        WHEN 'geocoding_expert' THEN (v_geocoded_count::DECIMAL / 20) * 100
                        WHEN 'global_mapper' THEN (v_countries_count::DECIMAL / 5) * 100
                        WHEN 'detail_master' THEN (v_full_completions_count::DECIMAL / 5) * 100
                        WHEN 'verification_pro' THEN (v_verified_count::DECIMAL / 10) * 100
                        WHEN 'community_helper' THEN (v_completions_count::DECIMAL / 50) * 100
                        WHEN 'first_contribution' THEN (v_contributions_count::DECIMAL / 1) * 100
                        WHEN 'contributor' THEN (v_contributions_count::DECIMAL / 5) * 100
                        WHEN 'active_contributor' THEN (v_contributions_count::DECIMAL / 20) * 100
                        WHEN 'top_contributor' THEN (v_contributions_count::DECIMAL / 100) * 100
                        WHEN 'verifier' THEN (v_verifications_count::DECIMAL / 5) * 100
                        WHEN 'trusted_verifier' THEN (v_verifications_count::DECIMAL / 20) * 100
                        WHEN 'expert_verifier' THEN (v_verifications_count::DECIMAL / 50) * 100
                        ELSE 0
                    END
                )::INTEGER)
            ELSE 0
        END as progress
    FROM public.badge_definitions bd
    ORDER BY bd.display_order;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2.4 AWARD BADGE FUNCTION
CREATE OR REPLACE FUNCTION award_badge(
    p_user_id UUID,
    p_badge_type TEXT,
    p_progress INTEGER DEFAULT 100
)
RETURNS UUID AS $$
DECLARE
    v_badge_id UUID;
    v_badge_def RECORD;
BEGIN
    SELECT * INTO v_badge_def FROM public.badge_definitions WHERE badge_type = p_badge_type;
    IF NOT FOUND THEN RAISE EXCEPTION 'Badge type % does not exist', p_badge_type; END IF;

    INSERT INTO public.user_badges (user_id, badge_type, badge_name, badge_description, badge_icon, progress)
    VALUES (p_user_id, p_badge_type, v_badge_def.badge_name, v_badge_def.badge_description, v_badge_def.badge_icon, p_progress)
    ON CONFLICT (user_id, badge_type) 
    DO UPDATE SET 
        progress = GREATEST(user_badges.progress, p_progress),
        earned_at = CASE WHEN p_progress >= 100 AND user_badges.progress < 100 THEN NOW() ELSE user_badges.earned_at END
    RETURNING id INTO v_badge_id;

    RETURN v_badge_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2.5 AUTO-AWARD TRIGGER
CREATE OR REPLACE FUNCTION check_and_award_completion_badges()
RETURNS TRIGGER AS $$
DECLARE
    v_completions_count INTEGER;
    v_geocoded_count INTEGER;
    v_verified_count INTEGER;
BEGIN
    IF NEW.completed_by IS NULL THEN RETURN NEW; END IF;

    SELECT COUNT(*) INTO v_completions_count FROM public.course_contributions WHERE completed_by = NEW.completed_by;
    SELECT COUNT(*) INTO v_geocoded_count FROM public.course_contributions WHERE completed_by = NEW.completed_by AND geocoded = TRUE;
    SELECT COUNT(*) INTO v_verified_count FROM public.course_contributions WHERE completed_by = NEW.completed_by AND status = 'approved';

    IF v_completions_count >= 1 THEN PERFORM award_badge(NEW.completed_by, 'course_completer', 100); END IF;
    IF v_completions_count >= 5 THEN PERFORM award_badge(NEW.completed_by, 'location_master', 100); END IF;
    IF v_completions_count >= 10 THEN PERFORM award_badge(NEW.completed_by, 'map_builder', 100); END IF;
    IF v_geocoded_count >= 20 THEN PERFORM award_badge(NEW.completed_by, 'geocoding_expert', 100); END IF;
    IF v_verified_count >= 10 THEN PERFORM award_badge(NEW.completed_by, 'verification_pro', 100); END IF;
    IF v_completions_count >= 50 THEN PERFORM award_badge(NEW.completed_by, 'community_helper', 100); END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_award_completion_badges ON public.course_contributions;
CREATE TRIGGER trigger_award_completion_badges
AFTER INSERT OR UPDATE ON public.course_contributions
FOR EACH ROW WHEN (NEW.completed_by IS NOT NULL)
EXECUTE FUNCTION check_and_award_completion_badges();

-- ============================================
-- MIGRATION 3: NEARBY COURSES POSTGIS FUNCTION
-- ============================================

-- Ensure PostGIS is enabled
CREATE EXTENSION IF NOT EXISTS postgis;

-- Create the nearby courses function
CREATE OR REPLACE FUNCTION get_nearby_courses(
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_radius_miles DOUBLE PRECISION DEFAULT 50,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    city TEXT,
    state TEXT,
    country TEXT,
    course_rating DECIMAL(4,1),
    slope_rating INTEGER,
    par INTEGER,
    holes INTEGER,
    latitude DECIMAL(10,7),
    longitude DECIMAL(10,7),
    address TEXT,
    phone TEXT,
    website TEXT,
    hole_data JSONB,
    avg_rating DECIMAL(3,2),
    review_count INTEGER,
    distance_miles DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.name,
        c.city,
        c.state,
        c.country,
        c.course_rating,
        c.slope_rating,
        c.par,
        c.holes,
        c.latitude,
        c.longitude,
        c.address,
        c.phone,
        c.website,
        c.hole_data,
        c.avg_rating,
        c.review_count,
        (ST_DistanceSphere(
            ST_SetSRID(ST_MakePoint(c.longitude::float, c.latitude::float), 4326),
            ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)
        ) / 1609.34)::DOUBLE PRECISION AS distance_miles
    FROM public.courses c
    WHERE 
        c.latitude IS NOT NULL 
        AND c.longitude IS NOT NULL
        AND c.latitude BETWEEN (p_latitude - (p_radius_miles / 69.0)) AND (p_latitude + (p_radius_miles / 69.0))
        AND c.longitude BETWEEN (p_longitude - (p_radius_miles / (69.0 * COS(RADIANS(p_latitude))))) 
                            AND (p_longitude + (p_radius_miles / (69.0 * COS(RADIANS(p_latitude)))))
    ORDER BY distance_miles ASC
    LIMIT p_limit;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_nearby_courses TO anon, authenticated;

COMMENT ON FUNCTION get_nearby_courses IS 'Returns courses within specified radius of a location, sorted by distance';

-- ============================================
-- VERIFICATION QUERIES
-- ============================================
-- Run these after the migration to verify success:

-- SELECT 'badge_definitions' as table_name, COUNT(*) as count FROM badge_definitions;
-- SELECT 'user_badges' as table_name, COUNT(*) as count FROM user_badges;
-- SELECT proname FROM pg_proc WHERE proname = 'get_nearby_courses';
-- SELECT proname FROM pg_proc WHERE proname = 'calculate_user_badges';
-- SELECT proname FROM pg_proc WHERE proname = 'award_badge';

-- Test nearby courses (San Francisco):
-- SELECT name, distance_miles FROM get_nearby_courses(37.7749, -122.4194, 25, 5);

-- ============================================
-- MIGRATION COMPLETE!
-- ============================================
