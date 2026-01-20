-- Fix the update_contributor_reputation function
-- The issue: v_reputation.confirmations_received can't be assigned because it's not in the SELECT
-- Solution: Use a separate variable for confirmations_received

CREATE OR REPLACE FUNCTION update_contributor_reputation(p_user_id UUID)
RETURNS VOID AS $$
DECLARE
    v_reputation RECORD;
    v_confirmations_received INTEGER := 0;
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
    SELECT COUNT(*) INTO v_confirmations_received
    FROM public.course_confirmations cc
    JOIN public.courses c ON c.id = cc.course_id
    WHERE c.contributed_by = p_user_id;
    
    v_score := v_score + COALESCE(v_confirmations_received, 0) * 1.0;
    
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
        COALESCE(v_confirmations_received, 0)
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
