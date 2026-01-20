-- Fix the array_length error in BOTH completeness functions
-- The trigger calls calculate_contribution_completeness, so we need to fix that one too

-- Fix calculate_contribution_completeness (called by trigger on INSERT/UPDATE)
CREATE OR REPLACE FUNCTION public.calculate_contribution_completeness(p_contribution_id UUID)
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
    
    -- Update the contribution (only if values changed to avoid trigger recursion)
    UPDATE public.course_contributions
    SET completeness_score = v_score, 
        missing_fields = v_missing
    WHERE id = p_contribution_id
      AND (completeness_score IS DISTINCT FROM v_score 
           OR missing_fields IS DISTINCT FROM v_missing);
    
    RETURN v_score;
END;
$$ LANGUAGE plpgsql;

-- Fix calculate_completeness_score (if it exists)
CREATE OR REPLACE FUNCTION public.calculate_completeness_score(p_contribution_id UUID)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_contrib public.course_contributions%ROWTYPE;
    v_score INTEGER := 0;
    v_missing TEXT[] := ARRAY[]::TEXT[];
    hole JSONB;
BEGIN
    -- Get the contribution
    SELECT * INTO v_contrib
    FROM public.course_contributions
    WHERE id = p_contribution_id;
    
    IF NOT FOUND THEN
        RETURN;
    END IF;
    
    -- Basic information (30 points)
    IF v_contrib.name IS NOT NULL AND v_contrib.name != '' THEN
        v_score := v_score + 10;
    ELSE
        v_missing := array_append(v_missing, 'name');
    END IF;
    
    IF v_contrib.latitude IS NOT NULL AND v_contrib.longitude IS NOT NULL THEN
        v_score := v_score + 10;
    ELSE
        v_missing := array_append(v_missing, 'location');
    END IF;
    
    IF v_contrib.city IS NOT NULL OR v_contrib.country IS NOT NULL THEN
        v_score := v_score + 10;
    ELSE
        v_missing := array_append(v_missing, 'city/country');
    END IF;
    
    -- Hole data (30 points)
    IF v_contrib.hole_data IS NOT NULL AND jsonb_array_length(v_contrib.hole_data) > 0 THEN
        v_score := v_score + 20;
        
        -- Check for tee locations
        FOR hole IN SELECT * FROM jsonb_array_elements(v_contrib.hole_data)
        LOOP
            IF (hole->>'tee_locations') IS NOT NULL 
                AND jsonb_array_length((hole->>'tee_locations')::jsonb) > 0 
            THEN
                v_score := v_score + 10;
                EXIT; -- Only count once
            END IF;
        END LOOP;
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
    
    -- Update the contribution (only if values changed to avoid trigger recursion)
    UPDATE public.course_contributions
    SET completeness_score = v_score, 
        missing_fields = v_missing
    WHERE id = p_contribution_id
      AND (completeness_score IS DISTINCT FROM v_score 
           OR missing_fields IS DISTINCT FROM v_missing);
END;
$$;
