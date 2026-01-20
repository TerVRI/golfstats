-- Check OSM import status and statistics

-- Total OSM courses imported
SELECT 
    COUNT(*) as total_osm_courses,
    COUNT(*) FILTER (WHERE status = 'pending') as pending,
    COUNT(*) FILTER (WHERE status = 'approved') as approved,
    COUNT(*) FILTER (WHERE status = 'rejected') as rejected
FROM public.course_contributions
WHERE source = 'osm';

-- Count by country (top 20)
SELECT 
    country,
    COUNT(*) as course_count
FROM public.course_contributions
WHERE source = 'osm'
GROUP BY country
ORDER BY COUNT(*) DESC
LIMIT 20;

-- Count by region (using bounding boxes to estimate)
SELECT 
    CASE 
        WHEN latitude BETWEEN 10 AND 85 AND longitude BETWEEN -180 AND -50 THEN 'North America'
        WHEN latitude BETWEEN 35 AND 72 AND longitude BETWEEN -15 AND 40 THEN 'Europe'
        WHEN latitude BETWEEN -10 AND 55 AND longitude BETWEEN 60 AND 180 THEN 'Asia'
        WHEN latitude BETWEEN -60 AND 15 AND longitude BETWEEN -90 AND -30 THEN 'South America'
        WHEN latitude BETWEEN 20 AND 38 AND longitude BETWEEN -20 AND 40 THEN 'North Africa'
        WHEN latitude BETWEEN -35 AND -10 AND longitude BETWEEN 10 AND 55 THEN 'Southern Africa'
        WHEN latitude BETWEEN -50 AND 0 AND longitude BETWEEN 110 AND 180 THEN 'Oceania'
        WHEN latitude BETWEEN 12 AND 40 AND longitude BETWEEN 25 AND 60 THEN 'Middle East'
        WHEN latitude BETWEEN 10 AND 28 AND longitude BETWEEN -90 AND -60 THEN 'Caribbean'
        WHEN latitude BETWEEN 7 AND 20 AND longitude BETWEEN -92 AND -77 THEN 'Central America'
        ELSE 'Other'
    END as region,
    COUNT(*) as course_count
FROM public.course_contributions
WHERE source = 'osm'
GROUP BY region
ORDER BY COUNT(*) DESC;
