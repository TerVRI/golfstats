-- Delete test OSM courses from specific regions to allow full re-import
-- This removes the single test courses we imported, so we can import all courses from those regions

-- Get the RoundCaddy user ID
DO $$
DECLARE
    v_roundcaddy_id UUID;
    v_deleted_count INTEGER;
BEGIN
    -- Find RoundCaddy user
    SELECT id INTO v_roundcaddy_id
    FROM public.profiles
    WHERE email = 'roundcaddy@roundcaddy.com'
    LIMIT 1;
    
    IF v_roundcaddy_id IS NULL THEN
        RAISE NOTICE 'RoundCaddy user not found';
        RETURN;
    END IF;
    
    RAISE NOTICE 'Found RoundCaddy user: %', v_roundcaddy_id;
    
    -- Delete courses from specific regions (bounding boxes)
    -- North America: [-180, 10, -50, 85]
    DELETE FROM public.course_contributions
    WHERE contributor_id = v_roundcaddy_id
      AND source = 'osm'
      AND latitude BETWEEN 10 AND 85
      AND longitude BETWEEN -180 AND -50;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % courses from North America', v_deleted_count;
    
    -- Europe: [-15, 35, 40, 72]
    DELETE FROM public.course_contributions
    WHERE contributor_id = v_roundcaddy_id
      AND source = 'osm'
      AND latitude BETWEEN 35 AND 72
      AND longitude BETWEEN -15 AND 40;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % courses from Europe', v_deleted_count;
    
    -- Asia: [60, -10, 180, 55]
    DELETE FROM public.course_contributions
    WHERE contributor_id = v_roundcaddy_id
      AND source = 'osm'
      AND latitude BETWEEN -10 AND 55
      AND longitude BETWEEN 60 AND 180;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % courses from Asia', v_deleted_count;
    
    -- Central Africa: [8, -12, 30, 8]
    DELETE FROM public.course_contributions
    WHERE contributor_id = v_roundcaddy_id
      AND source = 'osm'
      AND latitude BETWEEN -12 AND 8
      AND longitude BETWEEN 8 AND 30;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % courses from Central Africa', v_deleted_count;
    
    -- Southern Africa: [10, -35, 55, -10]
    DELETE FROM public.course_contributions
    WHERE contributor_id = v_roundcaddy_id
      AND source = 'osm'
      AND latitude BETWEEN -35 AND -10
      AND longitude BETWEEN 10 AND 55;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % courses from Southern Africa', v_deleted_count;
    
    -- Oceania: [110, -50, 180, 0]
    DELETE FROM public.course_contributions
    WHERE contributor_id = v_roundcaddy_id
      AND source = 'osm'
      AND latitude BETWEEN -50 AND 0
      AND longitude BETWEEN 110 AND 180;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % courses from Oceania', v_deleted_count;
    
    -- Middle East: [25, 12, 60, 40]
    DELETE FROM public.course_contributions
    WHERE contributor_id = v_roundcaddy_id
      AND source = 'osm'
      AND latitude BETWEEN 12 AND 40
      AND longitude BETWEEN 25 AND 60;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % courses from Middle East', v_deleted_count;
    
    -- Caribbean: [-90, 10, -60, 28]
    DELETE FROM public.course_contributions
    WHERE contributor_id = v_roundcaddy_id
      AND source = 'osm'
      AND latitude BETWEEN 10 AND 28
      AND longitude BETWEEN -90 AND -60;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % courses from Caribbean', v_deleted_count;
    
    -- Central America: [-92, 7, -77, 20]
    DELETE FROM public.course_contributions
    WHERE contributor_id = v_roundcaddy_id
      AND source = 'osm'
      AND latitude BETWEEN 7 AND 20
      AND longitude BETWEEN -92 AND -77;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % courses from Central America', v_deleted_count;
    
    RAISE NOTICE 'Done! You can now re-run the import script.';
END $$;
