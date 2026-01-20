-- Migration: Badges System for Gamification
-- Tracks user achievements and badges earned

-- ============================================
-- 1. USER BADGES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.user_badges (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    badge_type TEXT NOT NULL,
    badge_name TEXT NOT NULL,
    badge_description TEXT,
    badge_icon TEXT, -- Icon name or emoji
    earned_at TIMESTAMPTZ DEFAULT NOW(),
    progress INTEGER DEFAULT 100, -- 0-100, for progress tracking
    metadata JSONB DEFAULT '{}', -- Additional badge data
    
    -- Prevent duplicate badges
    UNIQUE(user_id, badge_type),
    
    -- Indexes
    CONSTRAINT user_badges_badge_type_check CHECK (badge_type IN (
        -- Course Completion Badges
        'course_completer',           -- Complete 1 incomplete course
        'location_master',            -- Add coordinates to 5 courses
        'map_builder',                -- Complete 10 incomplete courses
        'geocoding_expert',           -- Geocode 20 courses with addresses
        'country_completer',          -- Complete all incomplete courses in your country
        'global_mapper',              -- Complete courses in 5 different countries
        
        -- Quality Badges
        'detail_master',              -- Complete courses with all fields
        'verification_pro',           -- 10 of your completed courses get approved
        'community_helper',           -- Help complete 50 courses total
        
        -- Contribution Badges
        'first_contribution',         -- First course contribution
        'contributor',                -- 5 contributions
        'active_contributor',         -- 20 contributions
        'top_contributor',            -- 100 contributions
        
        -- Verification Badges
        'verifier',                   -- Verify 5 courses
        'trusted_verifier',           -- Verify 20 courses
        'expert_verifier'             -- Verify 50 courses
    ))
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_badges_user_id ON public.user_badges(user_id);
CREATE INDEX IF NOT EXISTS idx_user_badges_badge_type ON public.user_badges(badge_type);
CREATE INDEX IF NOT EXISTS idx_user_badges_earned_at ON public.user_badges(earned_at DESC);

-- RLS
ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;

-- Anyone can view badges (for leaderboards, profiles)
CREATE POLICY "Anyone can view badges" ON public.user_badges
    FOR SELECT USING (TRUE);

-- Users can view their own badges
CREATE POLICY "Users can view own badges" ON public.user_badges
    FOR SELECT USING (auth.uid() = user_id);

-- ============================================
-- 2. BADGE DEFINITIONS (Reference Data)
-- ============================================
CREATE TABLE IF NOT EXISTS public.badge_definitions (
    badge_type TEXT PRIMARY KEY,
    badge_name TEXT NOT NULL,
    badge_description TEXT NOT NULL,
    badge_icon TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('completion', 'quality', 'contribution', 'verification')),
    requirement_type TEXT NOT NULL CHECK (requirement_type IN ('count', 'threshold', 'custom')),
    requirement_value INTEGER, -- For count/threshold types
    requirement_description TEXT,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert badge definitions
INSERT INTO public.badge_definitions (badge_type, badge_name, badge_description, badge_icon, category, requirement_type, requirement_value, requirement_description, display_order) VALUES
-- Course Completion Badges
('course_completer', 'Course Completer', 'Complete 1 incomplete course', '🏆', 'completion', 'count', 1, 'Complete 1 incomplete course', 1),
('location_master', 'Location Master', 'Add coordinates to 5 courses', '📍', 'completion', 'count', 5, 'Add coordinates to 5 incomplete courses', 2),
('map_builder', 'Map Builder', 'Complete 10 incomplete courses', '🗺️', 'completion', 'count', 10, 'Complete 10 incomplete courses', 3),
('geocoding_expert', 'Geocoding Expert', 'Geocode 20 courses with addresses', '🌐', 'completion', 'count', 20, 'Use geocoding to add coordinates to 20 courses', 4),
('country_completer', 'Country Completer', 'Complete all incomplete courses in your country', '🏁', 'completion', 'custom', NULL, 'Complete all incomplete courses in your country', 5),
('global_mapper', 'Global Mapper', 'Complete courses in 5 different countries', '🌍', 'completion', 'count', 5, 'Complete courses in 5 different countries', 6),

-- Quality Badges
('detail_master', 'Detail Master', 'Complete courses with all fields (name, address, phone, website)', '⭐', 'quality', 'count', 5, 'Complete 5 courses with all fields filled', 10),
('verification_pro', 'Verification Pro', '10 of your completed courses get approved', '✅', 'quality', 'count', 10, 'Have 10 of your completed courses approved', 11),
('community_helper', 'Community Helper', 'Help complete 50 courses total', '🤝', 'quality', 'count', 50, 'Complete 50 courses total', 12),

-- Contribution Badges
('first_contribution', 'First Contribution', 'Make your first course contribution', '🎯', 'contribution', 'count', 1, 'Make your first course contribution', 20),
('contributor', 'Contributor', 'Make 5 course contributions', '📝', 'contribution', 'count', 5, 'Make 5 course contributions', 21),
('active_contributor', 'Active Contributor', 'Make 20 course contributions', '🔥', 'contribution', 'count', 20, 'Make 20 course contributions', 22),
('top_contributor', 'Top Contributor', 'Make 100 course contributions', '👑', 'contribution', 'count', 100, 'Make 100 course contributions', 23),

-- Verification Badges
('verifier', 'Verifier', 'Verify 5 courses', '🔍', 'verification', 'count', 5, 'Verify 5 courses', 30),
('trusted_verifier', 'Trusted Verifier', 'Verify 20 courses', '🛡️', 'verification', 'count', 20, 'Verify 20 courses', 31),
('expert_verifier', 'Expert Verifier', 'Verify 50 courses', '🎓', 'verification', 'count', 50, 'Verify 50 courses', 32)
ON CONFLICT (badge_type) DO NOTHING;

-- RLS for badge definitions (read-only for everyone)
ALTER TABLE public.badge_definitions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view badge definitions" ON public.badge_definitions
    FOR SELECT USING (TRUE);

-- ============================================
-- 3. FUNCTION: Calculate and Award Badges
-- ============================================
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
    -- Get completion statistics
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

    -- Get contribution count
    SELECT COUNT(*)
    INTO v_contributions_count
    FROM public.course_contributions
    WHERE contributor_id = p_user_id;

    -- Get verification count
    SELECT COUNT(*)
    INTO v_verifications_count
    FROM public.course_confirmations
    WHERE confirmer_id = p_user_id;

    -- Return badge calculations
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

-- ============================================
-- 4. FUNCTION: Award Badge
-- ============================================
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
    -- Get badge definition
    SELECT * INTO v_badge_def
    FROM public.badge_definitions
    WHERE badge_type = p_badge_type;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Badge type % does not exist', p_badge_type;
    END IF;

    -- Insert or update badge
    INSERT INTO public.user_badges (
        user_id,
        badge_type,
        badge_name,
        badge_description,
        badge_icon,
        progress
    ) VALUES (
        p_user_id,
        p_badge_type,
        v_badge_def.badge_name,
        v_badge_def.badge_description,
        v_badge_def.badge_icon,
        p_progress
    )
    ON CONFLICT (user_id, badge_type) 
    DO UPDATE SET 
        progress = GREATEST(user_badges.progress, p_progress),
        earned_at = CASE 
            WHEN p_progress >= 100 AND user_badges.progress < 100 
            THEN NOW() 
            ELSE user_badges.earned_at 
        END
    RETURNING id INTO v_badge_id;

    RETURN v_badge_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 5. TRIGGER: Auto-award badges when course is completed
-- ============================================
CREATE OR REPLACE FUNCTION check_and_award_completion_badges()
RETURNS TRIGGER AS $$
DECLARE
    v_completions_count INTEGER;
    v_geocoded_count INTEGER;
    v_verified_count INTEGER;
BEGIN
    -- Only process if this is a completion (completed_by is set)
    IF NEW.completed_by IS NULL THEN
        RETURN NEW;
    END IF;

    -- Count completions
    SELECT COUNT(*)
    INTO v_completions_count
    FROM public.course_contributions
    WHERE completed_by = NEW.completed_by;

    -- Count geocoded completions
    SELECT COUNT(*)
    INTO v_geocoded_count
    FROM public.course_contributions
    WHERE completed_by = NEW.completed_by AND geocoded = TRUE;

    -- Count verified completions
    SELECT COUNT(*)
    INTO v_verified_count
    FROM public.course_contributions
    WHERE completed_by = NEW.completed_by AND status = 'approved';

    -- Award badges based on counts
    IF v_completions_count >= 1 THEN
        PERFORM award_badge(NEW.completed_by, 'course_completer', 100);
    END IF;

    IF v_completions_count >= 5 THEN
        PERFORM award_badge(NEW.completed_by, 'location_master', 100);
    END IF;

    IF v_completions_count >= 10 THEN
        PERFORM award_badge(NEW.completed_by, 'map_builder', 100);
    END IF;

    IF v_geocoded_count >= 20 THEN
        PERFORM award_badge(NEW.completed_by, 'geocoding_expert', 100);
    END IF;

    IF v_verified_count >= 10 THEN
        PERFORM award_badge(NEW.completed_by, 'verification_pro', 100);
    END IF;

    IF v_completions_count >= 50 THEN
        PERFORM award_badge(NEW.completed_by, 'community_helper', 100);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_award_completion_badges
AFTER INSERT OR UPDATE ON public.course_contributions
FOR EACH ROW
WHEN (NEW.completed_by IS NOT NULL)
EXECUTE FUNCTION check_and_award_completion_badges();
