-- ============================================
-- ENHANCED COURSE FEATURES MIGRATION
-- Adds support for photos, drafts, reputation, versioning, etc.
-- ============================================

-- ============================================
-- 1. COURSE CONTRIBUTION PHOTOS
-- ============================================
ALTER TABLE public.course_contributions
ADD COLUMN IF NOT EXISTS photos JSONB DEFAULT '[]',
ADD COLUMN IF NOT EXISTS photo_urls TEXT[] DEFAULT '{}';

-- ============================================
-- 2. DRAFT CONTRIBUTIONS
-- ============================================
ALTER TABLE public.course_contributions
ADD COLUMN IF NOT EXISTS is_draft BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS draft_data JSONB,
ADD COLUMN IF NOT EXISTS last_saved_at TIMESTAMPTZ;

-- Index for drafts
CREATE INDEX IF NOT EXISTS idx_course_contributions_drafts ON public.course_contributions(contributor_id, is_draft) WHERE is_draft = TRUE;

-- ============================================
-- 3. CONTRIBUTOR REPUTATION
-- ============================================
CREATE TABLE IF NOT EXISTS public.contributor_reputation (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
    reputation_score DECIMAL(5,2) DEFAULT 0.0,
    -- Breakdown
    contributions_count INTEGER DEFAULT 0,
    verified_contributions_count INTEGER DEFAULT 0,
    confirmations_received INTEGER DEFAULT 0,
    discrepancies_found INTEGER DEFAULT 0,
    photos_uploaded INTEGER DEFAULT 0,
    -- Quality metrics
    avg_confirmation_confidence DECIMAL(3,2),
    completion_rate DECIMAL(5,2), -- % of contributions that are complete
    -- Status
    is_trusted_contributor BOOLEAN DEFAULT FALSE,
    trusted_since TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_contributor_reputation_score ON public.contributor_reputation(reputation_score DESC);
CREATE INDEX IF NOT EXISTS idx_contributor_reputation_trusted ON public.contributor_reputation(is_trusted_contributor) WHERE is_trusted_contributor = TRUE;

ALTER TABLE public.contributor_reputation ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view reputation" ON public.contributor_reputation
    FOR SELECT USING (TRUE);

CREATE POLICY "System can update reputation" ON public.contributor_reputation
    FOR ALL USING (TRUE);

-- ============================================
-- 4. COURSE VERSIONING & HISTORY
-- ============================================
CREATE TABLE IF NOT EXISTS public.course_versions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE NOT NULL,
    version_number INTEGER NOT NULL,
    -- What changed
    changed_fields JSONB DEFAULT '{}',
    changed_by UUID REFERENCES public.profiles(id),
    change_type TEXT CHECK (change_type IN ('create', 'update', 'merge', 'revert')) NOT NULL,
    -- Snapshot of course data at this version
    course_snapshot JSONB,
    -- Metadata
    change_reason TEXT,
    reverted_from_version INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(course_id, version_number)
);

CREATE INDEX IF NOT EXISTS idx_course_versions_course_id ON public.course_versions(course_id);
CREATE INDEX IF NOT EXISTS idx_course_versions_created_at ON public.course_versions(course_id, created_at DESC);

ALTER TABLE public.course_versions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view course versions" ON public.course_versions
    FOR SELECT USING (TRUE);

-- Add version tracking to courses
ALTER TABLE public.courses
ADD COLUMN IF NOT EXISTS current_version INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS last_updated_by UUID REFERENCES public.profiles(id);

-- ============================================
-- 5. DUPLICATE DETECTION & MERGE REQUESTS
-- ============================================
CREATE TABLE IF NOT EXISTS public.course_duplicates (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    course1_id UUID REFERENCES public.courses(id) ON DELETE CASCADE NOT NULL,
    course2_id UUID REFERENCES public.courses(id) ON DELETE CASCADE NOT NULL,
    similarity_score DECIMAL(5,2) NOT NULL, -- 0-100
    -- Similarity breakdown
    name_similarity DECIMAL(5,2),
    location_distance_meters INTEGER,
    -- Status
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'merged')),
    suggested_by UUID REFERENCES public.profiles(id),
    reviewed_by UUID REFERENCES public.profiles(id),
    review_notes TEXT,
    -- Votes
    merge_votes INTEGER DEFAULT 0,
    keep_separate_votes INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CHECK (course1_id != course2_id)
);

CREATE INDEX IF NOT EXISTS idx_course_duplicates_course1 ON public.course_duplicates(course1_id);
CREATE INDEX IF NOT EXISTS idx_course_duplicates_course2 ON public.course_duplicates(course2_id);
CREATE INDEX IF NOT EXISTS idx_course_duplicates_status ON public.course_duplicates(status);
CREATE INDEX IF NOT EXISTS idx_course_duplicates_similarity ON public.course_duplicates(similarity_score DESC);

ALTER TABLE public.course_duplicates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view duplicates" ON public.course_duplicates
    FOR SELECT USING (TRUE);

CREATE POLICY "Users can suggest duplicates" ON public.course_duplicates
    FOR INSERT WITH CHECK (auth.uid() = suggested_by);

-- Duplicate votes
CREATE TABLE IF NOT EXISTS public.duplicate_votes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    duplicate_id UUID REFERENCES public.course_duplicates(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    vote TEXT CHECK (vote IN ('merge', 'keep_separate')) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(duplicate_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_duplicate_votes_duplicate ON public.duplicate_votes(duplicate_id);

ALTER TABLE public.duplicate_votes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view votes" ON public.duplicate_votes
    FOR SELECT USING (TRUE);

CREATE POLICY "Users can vote" ON public.duplicate_votes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 6. DATA COMPLETENESS TRACKING
-- ============================================
ALTER TABLE public.course_contributions
ADD COLUMN IF NOT EXISTS completeness_score INTEGER DEFAULT 0, -- 0-100
ADD COLUMN IF NOT EXISTS missing_fields TEXT[] DEFAULT '{}';

ALTER TABLE public.courses
ADD COLUMN IF NOT EXISTS completeness_score INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS missing_critical_fields TEXT[] DEFAULT '{}';

-- ============================================
-- 7. NOTIFICATIONS SYSTEM
-- ============================================
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL CHECK (type IN (
        'course_confirmed',
        'course_verified',
        'contribution_approved',
        'contribution_rejected',
        'duplicate_suggested',
        'merge_approved',
        'thank_you_received',
        'question_asked',
        'milestone_reached'
    )),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    -- Related entities
    course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE,
    contribution_id UUID REFERENCES public.course_contributions(id) ON DELETE CASCADE,
    related_user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    -- Status
    read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id, read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON public.notifications(user_id, read) WHERE read = FALSE;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own notifications" ON public.notifications
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications" ON public.notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- ============================================
-- 8. COMMUNITY FEATURES
-- ============================================
-- Course discussions/questions
CREATE TABLE IF NOT EXISTS public.course_discussions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    discussion_type TEXT DEFAULT 'question' CHECK (discussion_type IN ('question', 'discussion', 'correction_request')),
    -- Status
    resolved BOOLEAN DEFAULT FALSE,
    resolved_by UUID REFERENCES public.profiles(id),
    resolved_at TIMESTAMPTZ,
    -- Engagement
    upvotes INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_course_discussions_course ON public.course_discussions(course_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_course_discussions_user ON public.course_discussions(user_id);

ALTER TABLE public.course_discussions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view discussions" ON public.course_discussions
    FOR SELECT USING (TRUE);

CREATE POLICY "Users can create discussions" ON public.course_discussions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own discussions" ON public.course_discussions
    FOR UPDATE USING (auth.uid() = user_id);

-- Discussion replies
CREATE TABLE IF NOT EXISTS public.discussion_replies (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    discussion_id UUID REFERENCES public.course_discussions(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    content TEXT NOT NULL,
    upvotes INTEGER DEFAULT 0,
    is_solution BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_discussion_replies_discussion ON public.discussion_replies(discussion_id, created_at);

ALTER TABLE public.discussion_replies ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view replies" ON public.discussion_replies
    FOR SELECT USING (TRUE);

CREATE POLICY "Users can create replies" ON public.discussion_replies
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own replies" ON public.discussion_replies
    FOR UPDATE USING (auth.uid() = user_id);

-- Thank you system
CREATE TABLE IF NOT EXISTS public.contributor_thanks (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    contributor_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    thanked_by UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE,
    contribution_id UUID REFERENCES public.course_contributions(id) ON DELETE CASCADE,
    message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(contributor_id, thanked_by, contribution_id)
);

CREATE INDEX IF NOT EXISTS idx_contributor_thanks_contributor ON public.contributor_thanks(contributor_id);

ALTER TABLE public.contributor_thanks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view thanks" ON public.contributor_thanks
    FOR SELECT USING (TRUE);

CREATE POLICY "Users can thank contributors" ON public.contributor_thanks
    FOR INSERT WITH CHECK (auth.uid() = thanked_by);

-- ============================================
-- 9. GAMIFICATION - CHALLENGES & STREAKS
-- ============================================
CREATE TABLE IF NOT EXISTS public.contribution_challenges (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    challenge_type TEXT CHECK (challenge_type IN ('monthly', 'weekly', 'special')) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    target_contributions INTEGER,
    target_verifications INTEGER,
    reward_points INTEGER DEFAULT 0,
    reward_badge_id TEXT REFERENCES public.achievement_definitions(id),
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.user_challenge_progress (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    challenge_id UUID REFERENCES public.contribution_challenges(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    contributions_count INTEGER DEFAULT 0,
    verifications_count INTEGER DEFAULT 0,
    completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(challenge_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_challenge_progress_user ON public.user_challenge_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_user_challenge_progress_challenge ON public.user_challenge_progress(challenge_id);

ALTER TABLE public.user_challenge_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own challenge progress" ON public.user_challenge_progress
    FOR SELECT USING (auth.uid() = user_id);

-- Contribution streaks
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS contribution_streak_days INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_contribution_date DATE,
ADD COLUMN IF NOT EXISTS longest_streak_days INTEGER DEFAULT 0;

-- ============================================
-- 10. POINTS SYSTEM
-- ============================================
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS contribution_points INTEGER DEFAULT 0;

-- Points for different actions (stored in achievement_definitions or separate)
CREATE TABLE IF NOT EXISTS public.point_transactions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    points INTEGER NOT NULL,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN (
        'contribution',
        'verification',
        'confirmation',
        'photo_upload',
        'challenge_completion',
        'streak_bonus',
        'quality_bonus'
    )),
    related_id UUID, -- contribution_id, challenge_id, etc.
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_point_transactions_user ON public.point_transactions(user_id, created_at DESC);

ALTER TABLE public.point_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own point transactions" ON public.point_transactions
    FOR SELECT USING (auth.uid() = user_id);

-- ============================================
-- 11. FUNCTIONS FOR AUTO-UPDATES
-- ============================================

-- Function to calculate completeness score
CREATE OR REPLACE FUNCTION calculate_contribution_completeness(p_contribution_id UUID)
RETURNS INTEGER AS $$
DECLARE
    v_score INTEGER := 0;
    v_missing TEXT[] := '{}';
    v_contrib RECORD;
BEGIN
    SELECT * INTO v_contrib FROM public.course_contributions WHERE id = p_contribution_id;
    
    -- Basic info (30 points)
    IF v_contrib.name IS NOT NULL AND v_contrib.name != '' THEN v_score := v_score + 5; ELSE v_missing := array_append(v_missing, 'name'); END IF;
    IF v_contrib.latitude IS NOT NULL AND v_contrib.longitude IS NOT NULL THEN v_score := v_score + 10; ELSE v_missing := array_append(v_missing, 'location'); END IF;
    IF v_contrib.city IS NOT NULL OR v_contrib.state IS NOT NULL THEN v_score := v_score + 5; ELSE v_missing := array_append(v_missing, 'address'); END IF;
    IF v_contrib.par IS NOT NULL THEN v_score := v_score + 5; ELSE v_missing := array_append(v_missing, 'par'); END IF;
    IF v_contrib.course_rating IS NOT NULL AND v_contrib.slope_rating IS NOT NULL THEN v_score := v_score + 5; ELSE v_missing := array_append(v_missing, 'ratings'); END IF;
    
    -- GPS data (40 points)
    IF v_contrib.hole_data IS NOT NULL AND jsonb_array_length(v_contrib.hole_data) > 0 THEN
        v_score := v_score + 20;
        -- Check for tee locations and greens
        IF EXISTS (
            SELECT 1 FROM jsonb_array_elements(v_contrib.hole_data) AS hole
            WHERE (hole->>'tee_locations')::jsonb IS NOT NULL
            AND jsonb_array_length((hole->>'tee_locations')::jsonb) > 0
        ) THEN v_score := v_score + 10; ELSE v_missing := array_append(v_missing, 'tee_locations'); END IF;
        
        IF EXISTS (
            SELECT 1 FROM jsonb_array_elements(v_contrib.hole_data) AS hole
            WHERE (hole->>'green_center')::jsonb IS NOT NULL
            AND (hole->'green_center'->>'lat')::numeric != 0
        ) THEN v_score := v_score + 10; ELSE v_missing := array_append(v_missing, 'green_locations'); END IF;
    ELSE
        v_missing := array_append(v_missing, 'hole_data');
    END IF;
    
    -- Photos (10 points)
    IF v_contrib.photos IS NOT NULL AND jsonb_array_length(v_contrib.photos) > 0 THEN
        v_score := v_score + 10;
    ELSE
        v_missing := array_append(v_missing, 'photos');
    END IF;
    
    -- Additional details (20 points)
    IF v_contrib.phone IS NOT NULL THEN v_score := v_score + 5; END IF;
    IF v_contrib.website IS NOT NULL THEN v_score := v_score + 5; END IF;
    IF v_contrib.address IS NOT NULL THEN v_score := v_score + 5; END IF;
    -- Check if yardages exist (yardages is a JSONB object, check if it has keys)
    IF v_contrib.hole_data IS NOT NULL 
       AND jsonb_array_length(v_contrib.hole_data) > 0 
       AND (v_contrib.hole_data->0->'yardages') IS NOT NULL 
       AND (v_contrib.hole_data->0->'yardages')::text != 'null'
       AND (v_contrib.hole_data->0->'yardages')::text != '{}'
    THEN v_score := v_score + 5; END IF;
    
    -- Update the contribution
    UPDATE public.course_contributions
    SET completeness_score = v_score, missing_fields = v_missing
    WHERE id = p_contribution_id;
    
    RETURN v_score;
END;
$$ LANGUAGE plpgsql;

-- Function to update reputation
CREATE OR REPLACE FUNCTION update_contributor_reputation(p_user_id UUID)
RETURNS VOID AS $$
DECLARE
    v_reputation RECORD;
    v_score DECIMAL(5,2) := 0.0;
BEGIN
    -- Calculate reputation based on contributions, verifications, quality
    SELECT 
        COUNT(*) FILTER (WHERE status IN ('approved', 'merged')) as verified_count,
        COUNT(*) as total_count,
        AVG(completeness_score) as avg_completeness,
        COUNT(*) FILTER (WHERE photos IS NOT NULL AND jsonb_array_length(photos) > 0) as photos_count
    INTO v_reputation
    FROM public.course_contributions
    WHERE contributor_id = p_user_id;
    
    -- Base score from verified contributions
    v_score := COALESCE(v_reputation.verified_count, 0) * 10.0;
    
    -- Quality bonus
    v_score := v_score + COALESCE(v_reputation.avg_completeness, 0) * 0.5;
    
    -- Photo bonus
    v_score := v_score + COALESCE(v_reputation.photos_count, 0) * 2.0;
    
    -- Confirmation bonus (from courses they contributed)
    SELECT COUNT(*) INTO v_reputation.confirmations_received
    FROM public.course_confirmations cc
    JOIN public.courses c ON c.id = cc.course_id
    WHERE c.contributed_by = p_user_id;
    
    v_score := v_score + COALESCE(v_reputation.confirmations_received, 0) * 1.0;
    
    -- Update or insert reputation
    INSERT INTO public.contributor_reputation (
        user_id, reputation_score, contributions_count, verified_contributions_count,
        photos_uploaded, completion_rate, confirmations_received
    ) VALUES (
        p_user_id, v_score, 
        COALESCE(v_reputation.total_count, 0),
        COALESCE(v_reputation.verified_count, 0),
        COALESCE(v_reputation.photos_count, 0),
        COALESCE(v_reputation.avg_completeness, 0),
        COALESCE(v_reputation.confirmations_received, 0)
    )
    ON CONFLICT (user_id) DO UPDATE SET
        reputation_score = EXCLUDED.reputation_score,
        contributions_count = EXCLUDED.contributions_count,
        verified_contributions_count = EXCLUDED.verified_contributions_count,
        photos_uploaded = EXCLUDED.photos_uploaded,
        completion_rate = EXCLUDED.completion_rate,
        confirmations_received = EXCLUDED.confirmations_received,
        is_trusted_contributor = (EXCLUDED.reputation_score >= 100 AND EXCLUDED.verified_contributions_count >= 5),
        trusted_since = CASE 
            WHEN (EXCLUDED.reputation_score >= 100 AND EXCLUDED.verified_contributions_count >= 5) 
            AND NOT EXISTS (SELECT 1 FROM public.contributor_reputation WHERE user_id = p_user_id AND is_trusted_contributor = TRUE)
            THEN NOW()
            ELSE (SELECT trusted_since FROM public.contributor_reputation WHERE user_id = p_user_id)
        END,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Trigger to update completeness on contribution changes
CREATE OR REPLACE FUNCTION trigger_update_completeness()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM calculate_contribution_completeness(NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_contribution_completeness
    AFTER INSERT OR UPDATE ON public.course_contributions
    FOR EACH ROW EXECUTE FUNCTION trigger_update_completeness();

-- Trigger to update reputation when contributions change
CREATE OR REPLACE FUNCTION trigger_update_reputation()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM update_contributor_reputation(COALESCE(NEW.contributor_id, OLD.contributor_id));
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_contributor_reputation_on_contribution
    AFTER INSERT OR UPDATE OR DELETE ON public.course_contributions
    FOR EACH ROW EXECUTE FUNCTION trigger_update_reputation();

-- ============================================
-- 12. UPDATE TRIGGERS
-- ============================================
CREATE TRIGGER update_course_duplicates_updated_at
    BEFORE UPDATE ON public.course_duplicates
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_course_discussions_updated_at
    BEFORE UPDATE ON public.course_discussions
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_discussion_replies_updated_at
    BEFORE UPDATE ON public.discussion_replies
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_contributor_reputation_updated_at
    BEFORE UPDATE ON public.contributor_reputation
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_user_challenge_progress_updated_at
    BEFORE UPDATE ON public.user_challenge_progress
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
