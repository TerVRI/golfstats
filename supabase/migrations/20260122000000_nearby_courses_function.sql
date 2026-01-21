-- ============================================
-- NEARBY COURSES FUNCTION (PostGIS)
-- ============================================
-- This function efficiently finds courses near a given location
-- Uses PostGIS for optimized distance calculations

-- Create the function
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
        -- Calculate distance in miles using the Haversine formula via PostGIS
        (ST_DistanceSphere(
            ST_SetSRID(ST_MakePoint(c.longitude::float, c.latitude::float), 4326),
            ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)
        ) / 1609.34)::DOUBLE PRECISION AS distance_miles
    FROM public.courses c
    WHERE 
        c.latitude IS NOT NULL 
        AND c.longitude IS NOT NULL
        -- Pre-filter using bounding box for efficiency (rough filter)
        AND c.latitude BETWEEN (p_latitude - (p_radius_miles / 69.0)) AND (p_latitude + (p_radius_miles / 69.0))
        AND c.longitude BETWEEN (p_longitude - (p_radius_miles / (69.0 * COS(RADIANS(p_latitude))))) 
                            AND (p_longitude + (p_radius_miles / (69.0 * COS(RADIANS(p_latitude)))))
    ORDER BY distance_miles ASC
    LIMIT p_limit;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_nearby_courses TO anon, authenticated;

-- Add comment
COMMENT ON FUNCTION get_nearby_courses IS 'Returns courses within specified radius of a location, sorted by distance';
