-- ============================================
-- COURSE CONTRIBUTIONS & VALIDATION SYSTEM
-- ============================================

-- ============================================
-- 1. COURSE CONTRIBUTIONS TABLE
-- Tracks user-submitted course data
-- ============================================
CREATE TABLE IF NOT EXISTS public.course_contributions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE,
    -- If course_id is NULL, this is a new course submission
    -- If course_id exists, this is an update/confirmation to existing course
    contributor_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    
    -- Course basic info
    name TEXT NOT NULL,
    city TEXT,
    state TEXT,
    country TEXT DEFAULT 'USA',
    address TEXT,
    phone TEXT,
    website TEXT,
    
    -- Course ratings
    course_rating DECIMAL(4,1),
    slope_rating INTEGER,
    par INTEGER,
    holes INTEGER DEFAULT 18,
    
    -- GPS and location data
    latitude DECIMAL(10, 7),
    longitude DECIMAL(10, 7),
    geojson_data JSONB,
    
    -- Detailed hole data with GPS coordinates
    hole_data JSONB,
    -- hole_data structure matches courses.hole_data:
    -- [
    --   {
    --     "hole_number": 1,
    --     "par": 4,
    --     "yardages": { "black": 420, "blue": 400, "white": 380, "gold": 350, "red": 300 },
    --     "handicap_index": 5,
    --     "tee_locations": [
    --       { "tee": "blue", "lat": 40.7128, "lon": -74.0060 }
    --     ],
    --     "green_center": { "lat": 40.7130, "lon": -74.0055 },
    --     "green_front": { "lat": 40.7129, "lon": -74.0056 },
    --     "green_back": { "lat": 40.7131, "lon": -74.0054 },
    --     "hazards": [
    --       { "type": "bunker", "lat": 40.7129, "lon": -74.0057 },
    --       { "type": "water", "polygon": [[lat, lon], ...] }
    --     ]
    --   }
    -- ]
    
    -- Status and validation
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'merged')),
    -- pending: waiting for admin review or confirmations
    -- approved: approved by admin or enough confirmations
    -- rejected: rejected (duplicate, invalid, etc.)
    -- merged: merged into existing course
    
    rejection_reason TEXT,
    admin_notes TEXT,
    
    -- Metadata
    source TEXT DEFAULT 'user' CHECK (source IN ('user', 'osm', 'csv', 'admin')),
    -- user: user-submitted
    -- osm: from OpenStreetMap
    -- csv: from CSV import
    -- admin: admin-created
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ,
    reviewed_by UUID REFERENCES public.profiles(id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_course_contributions_course_id ON public.course_contributions(course_id);
CREATE INDEX IF NOT EXISTS idx_course_contributions_contributor ON public.course_contributions(contributor_id);
CREATE INDEX IF NOT EXISTS idx_course_contributions_status ON public.course_contributions(status);
CREATE INDEX IF NOT EXISTS idx_course_contributions_location ON public.course_contributions(latitude, longitude) WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- RLS for course contributions
ALTER TABLE public.course_contributions ENABLE ROW LEVEL SECURITY;

-- Anyone can view contributions (for transparency)
CREATE POLICY "Anyone can view course contributions" ON public.course_contributions
    FOR SELECT USING (TRUE);

-- Users can insert their own contributions
CREATE POLICY "Users can insert own contributions" ON public.course_contributions
    FOR INSERT WITH CHECK (auth.uid() = contributor_id);

-- Users can update their own pending contributions
CREATE POLICY "Users can update own pending contributions" ON public.course_contributions
    FOR UPDATE USING (
        auth.uid() = contributor_id 
        AND status = 'pending'
    );

-- Users can delete their own pending contributions
CREATE POLICY "Users can delete own pending contributions" ON public.course_contributions
    FOR DELETE USING (
        auth.uid() = contributor_id 
        AND status = 'pending'
    );

-- ============================================
-- 2. COURSE CONFIRMATIONS TABLE
-- Tracks when users confirm/validate course data
-- ============================================
CREATE TABLE IF NOT EXISTS public.course_confirmations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE NOT NULL,
    contribution_id UUID REFERENCES public.course_contributions(id) ON DELETE SET NULL,
    -- If contribution_id is set, user is confirming a specific contribution
    -- If NULL, user is confirming the current course data
    
    confirmer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    
    -- What the user is confirming
    confirmed_fields JSONB NOT NULL DEFAULT '{}',
    -- {
    --   "dimensions": true,  -- course length, hole yardages match
    --   "tee_locations": true,  -- tee box GPS coordinates match
    --   "green_locations": true,  -- green GPS coordinates match
    --   "pars": true,  -- hole pars match
    --   "hazards": true,  -- hazard locations match
    --   "address": true,  -- address/location matches
    --   "ratings": true  -- course rating/slope match
    -- }
    
    -- User's notes/comments
    notes TEXT,
    
    -- Confidence level (1-5, how confident is the user)
    confidence INTEGER CHECK (confidence >= 1 AND confidence <= 5) DEFAULT 3,
    
    -- If user found discrepancies
    has_discrepancies BOOLEAN DEFAULT FALSE,
    discrepancy_details TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Prevent duplicate confirmations from same user for same course/contribution
    UNIQUE(course_id, confirmer_id, contribution_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_course_confirmations_course_id ON public.course_confirmations(course_id);
CREATE INDEX IF NOT EXISTS idx_course_confirmations_contribution_id ON public.course_confirmations(contribution_id);
CREATE INDEX IF NOT EXISTS idx_course_confirmations_confirmer ON public.course_confirmations(confirmer_id);

-- RLS for course confirmations
ALTER TABLE public.course_confirmations ENABLE ROW LEVEL SECURITY;

-- Anyone can view confirmations
CREATE POLICY "Anyone can view course confirmations" ON public.course_confirmations
    FOR SELECT USING (TRUE);

-- Users can insert their own confirmations
CREATE POLICY "Users can insert own confirmations" ON public.course_confirmations
    FOR INSERT WITH CHECK (auth.uid() = confirmer_id);

-- Users can update their own confirmations
CREATE POLICY "Users can update own confirmations" ON public.course_confirmations
    FOR UPDATE USING (auth.uid() = confirmer_id);

-- Users can delete their own confirmations
CREATE POLICY "Users can delete own confirmations" ON public.course_confirmations
    FOR DELETE USING (auth.uid() = confirmer_id);

-- ============================================
-- 3. UPDATE COURSES TABLE
-- Add fields for tracking confirmations
-- ============================================
ALTER TABLE public.courses
ADD COLUMN IF NOT EXISTS confirmation_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS required_confirmations INTEGER DEFAULT 2,
ADD COLUMN IF NOT EXISTS last_confirmed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS contribution_count INTEGER DEFAULT 0;

-- ============================================
-- 4. FUNCTION TO UPDATE CONFIRMATION COUNT
-- ============================================
CREATE OR REPLACE FUNCTION update_course_confirmation_count()
RETURNS TRIGGER AS $$
BEGIN
    -- Update confirmation count for the course
    UPDATE public.courses
    SET 
        confirmation_count = (
            SELECT COUNT(DISTINCT confirmer_id)
            FROM public.course_confirmations
            WHERE course_id = COALESCE(NEW.course_id, OLD.course_id)
            AND has_discrepancies = FALSE
        ),
        last_confirmed_at = (
            SELECT MAX(created_at)
            FROM public.course_confirmations
            WHERE course_id = COALESCE(NEW.course_id, OLD.course_id)
        ),
        is_verified = (
            SELECT COUNT(DISTINCT confirmer_id) >= required_confirmations
            FROM public.course_confirmations
            WHERE course_id = COALESCE(NEW.course_id, OLD.course_id)
            AND has_discrepancies = FALSE
        )
    WHERE id = COALESCE(NEW.course_id, OLD.course_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update confirmation count
CREATE TRIGGER update_course_confirmation_on_confirm
    AFTER INSERT OR UPDATE OR DELETE ON public.course_confirmations
    FOR EACH ROW EXECUTE FUNCTION update_course_confirmation_count();

-- ============================================
-- 5. FUNCTION TO UPDATE CONTRIBUTION COUNT
-- ============================================
CREATE OR REPLACE FUNCTION update_course_contribution_count()
RETURNS TRIGGER AS $$
BEGIN
    -- Update contribution count for the course
    IF NEW.course_id IS NOT NULL THEN
        UPDATE public.courses
        SET contribution_count = (
            SELECT COUNT(*)
            FROM public.course_contributions
            WHERE course_id = NEW.course_id
            AND status IN ('approved', 'merged')
        )
        WHERE id = NEW.course_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update contribution count
CREATE TRIGGER update_course_contribution_count_trigger
    AFTER INSERT OR UPDATE ON public.course_contributions
    FOR EACH ROW EXECUTE FUNCTION update_course_contribution_count();

-- ============================================
-- 6. FUNCTION TO GET CONTRIBUTOR STATS
-- ============================================
CREATE OR REPLACE FUNCTION get_course_contributor_stats(p_user_id UUID)
RETURNS TABLE (
    total_contributions INTEGER,
    approved_contributions INTEGER,
    verified_courses INTEGER,
    pending_contributions INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_contributions,
        COUNT(*) FILTER (WHERE status = 'approved' OR status = 'merged')::INTEGER as approved_contributions,
        (
            SELECT COUNT(DISTINCT c.id)::INTEGER
            FROM public.courses c
            WHERE c.contributed_by = p_user_id
            AND c.is_verified = TRUE
        ) as verified_courses,
        COUNT(*) FILTER (WHERE status = 'pending')::INTEGER as pending_contributions
    FROM public.course_contributions
    WHERE contributor_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 7. UPDATE TRIGGERS
-- ============================================
CREATE TRIGGER update_course_contributions_updated_at
    BEFORE UPDATE ON public.course_contributions
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_course_confirmations_updated_at
    BEFORE UPDATE ON public.course_confirmations
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
