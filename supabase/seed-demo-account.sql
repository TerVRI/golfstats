-- ============================================
-- DEMO ACCOUNT SEED DATA FOR APPLE APP STORE REVIEW
-- ============================================
--
-- DEMO CREDENTIALS (provide to Apple):
--   Email: demo@roundcaddy.app
--   Password: DemoReview2026!
--
-- SETUP INSTRUCTIONS:
-- 1. First, create the demo user in Supabase Dashboard:
--    - Go to Authentication → Users → "Add user"
--    - Email: demo@roundcaddy.app
--    - Password: DemoReview2026!
--    - Check "Auto Confirm User"
-- 2. Then run this seed script in the SQL Editor
--
-- This script will automatically find the demo user by email
-- and populate all sample data.
-- ============================================

DO $$
DECLARE
    demo_user_id UUID;
    demo_round_1 UUID;
    demo_round_2 UUID;
    demo_round_3 UUID;
    demo_round_4 UUID;
    demo_round_5 UUID;
    demo_round_6 UUID;
BEGIN
    -- Find the demo user by email
    SELECT id INTO demo_user_id 
    FROM auth.users 
    WHERE email = 'demo@roundcaddy.app'
    LIMIT 1;
    
    -- If user doesn't exist, raise an error
    IF demo_user_id IS NULL THEN
        RAISE EXCEPTION 'Demo user not found! Please create a user with email: demo@roundcaddy.app in the Supabase Dashboard first.';
    END IF;
    
    -- Generate UUIDs for rounds (using built-in gen_random_uuid)
    demo_round_1 := gen_random_uuid();
    demo_round_2 := gen_random_uuid();
    demo_round_3 := gen_random_uuid();
    demo_round_4 := gen_random_uuid();
    demo_round_5 := gen_random_uuid();
    demo_round_6 := gen_random_uuid();
    
    RAISE NOTICE 'Found demo user: %', demo_user_id;
    RAISE NOTICE 'Populating demo data...';

    -- ============================================
    -- UPDATE DEMO PROFILE
    -- ============================================
    UPDATE public.profiles SET
        name = 'Demo Golfer',
        handicap = 14.2,
        bio = 'Golf enthusiast tracking my journey to single digits!',
        is_public = true,
        home_course = 'Pebble Beach Golf Links',
        low_handicap = 12.8,
        rounds_played = 42,
        preferences = '{
            "theme": "dark",
            "units": "yards",
            "default_tees": "white",
            "notifications": true,
            "public_stats": true
        }'::jsonb,
        updated_at = NOW()
    WHERE id = demo_user_id;

    -- ============================================
    -- DELETE EXISTING DEMO DATA (for re-running)
    -- ============================================
    DELETE FROM public.clubs WHERE user_id = demo_user_id;
    DELETE FROM public.rounds WHERE user_id = demo_user_id;
    DELETE FROM public.practice_sessions WHERE user_id = demo_user_id;
    DELETE FROM public.goals WHERE user_id = demo_user_id;
    DELETE FROM public.user_achievements WHERE user_id = demo_user_id;

    -- ============================================
    -- DEMO CLUBS (Golf Bag)
    -- ============================================
    INSERT INTO public.clubs (user_id, name, brand, model, loft, shaft, shaft_material, club_type, in_bag, avg_distance, total_shots, display_order)
    VALUES
        (demo_user_id, 'Driver', 'TaylorMade', 'Stealth 2 Plus', 10.5, 'Stiff', 'graphite', 'driver', true, 255, 156, 1),
        (demo_user_id, '3 Wood', 'TaylorMade', 'Stealth 2', 15.0, 'Stiff', 'graphite', 'wood', true, 230, 89, 2),
        (demo_user_id, '5 Wood', 'TaylorMade', 'Stealth 2', 18.0, 'Stiff', 'graphite', 'wood', true, 210, 45, 3),
        (demo_user_id, '4 Hybrid', 'Callaway', 'Paradym', 21.0, 'Stiff', 'graphite', 'hybrid', true, 195, 67, 4),
        (demo_user_id, '5 Iron', 'Titleist', 'T200', 23.0, 'Stiff', 'steel', 'iron', true, 180, 78, 5),
        (demo_user_id, '6 Iron', 'Titleist', 'T200', 26.0, 'Stiff', 'steel', 'iron', true, 170, 124, 6),
        (demo_user_id, '7 Iron', 'Titleist', 'T200', 30.0, 'Stiff', 'steel', 'iron', true, 160, 189, 7),
        (demo_user_id, '8 Iron', 'Titleist', 'T200', 34.0, 'Stiff', 'steel', 'iron', true, 150, 167, 8),
        (demo_user_id, '9 Iron', 'Titleist', 'T200', 38.0, 'Stiff', 'steel', 'iron', true, 140, 145, 9),
        (demo_user_id, 'PW', 'Titleist', 'T200', 43.0, 'Stiff', 'steel', 'wedge', true, 130, 198, 10),
        (demo_user_id, '52° Wedge', 'Titleist', 'Vokey SM9', 52.0, 'Wedge', 'steel', 'wedge', true, 105, 234, 11),
        (demo_user_id, '56° Wedge', 'Titleist', 'Vokey SM9', 56.0, 'Wedge', 'steel', 'wedge', true, 85, 312, 12),
        (demo_user_id, '60° Wedge', 'Titleist', 'Vokey SM9', 60.0, 'Wedge', 'steel', 'wedge', true, 65, 156, 13),
        (demo_user_id, 'Putter', 'Scotty Cameron', 'Phantom X 5', NULL, NULL, 'steel', 'putter', true, NULL, 756, 14);

    -- ============================================
    -- DEMO ROUNDS
    -- ============================================
    
    -- Round 1: Most recent - Pebble Beach (Great round!)
    INSERT INTO public.rounds (id, user_id, course_name, course_rating, slope_rating, played_at, total_score, total_putts, fairways_hit, fairways_total, gir, penalties, sg_total, sg_off_tee, sg_approach, sg_around_green, sg_putting, scoring_format, notes)
    VALUES (
        demo_round_1,
        demo_user_id,
        'Pebble Beach Golf Links',
        72.8,
        145,
        CURRENT_DATE - INTERVAL '2 days',
        82,
        32,
        9,
        14,
        8,
        1,
        1.2,
        0.5,
        0.8,
        -0.3,
        0.2,
        'stroke',
        'Beautiful day at Pebble! Started strong with birdie on 4. Struggled a bit on the back nine but saved par on 18 with a great up and down.'
    );

    -- Round 2: Torrey Pines South
    INSERT INTO public.rounds (id, user_id, course_name, course_rating, slope_rating, played_at, total_score, total_putts, fairways_hit, fairways_total, gir, penalties, sg_total, sg_off_tee, sg_approach, sg_around_green, sg_putting, scoring_format, notes)
    VALUES (
        demo_round_2,
        demo_user_id,
        'Torrey Pines (South)',
        75.8,
        143,
        CURRENT_DATE - INTERVAL '9 days',
        88,
        35,
        7,
        14,
        6,
        2,
        -1.5,
        -0.8,
        -0.2,
        -0.1,
        -0.4,
        'stroke',
        'Tough conditions with wind off the ocean. Double on 12 hurt. Need to work on 3-putts.'
    );

    -- Round 3: TPC Sawgrass
    INSERT INTO public.rounds (id, user_id, course_name, course_rating, slope_rating, played_at, total_score, total_putts, fairways_hit, fairways_total, gir, penalties, sg_total, sg_off_tee, sg_approach, sg_around_green, sg_putting, scoring_format, notes)
    VALUES (
        demo_round_3,
        demo_user_id,
        'TPC Sawgrass (Stadium)',
        74.7,
        147,
        CURRENT_DATE - INTERVAL '16 days',
        85,
        33,
        8,
        14,
        7,
        1,
        0.3,
        0.2,
        0.4,
        -0.5,
        0.2,
        'stroke',
        'Made par on the island green 17! Approached to 15 feet and two-putted. Best ball striking round in a while.'
    );

    -- Round 4: Pebble Beach again
    INSERT INTO public.rounds (id, user_id, course_name, course_rating, slope_rating, played_at, total_score, total_putts, fairways_hit, fairways_total, gir, penalties, sg_total, sg_off_tee, sg_approach, sg_around_green, sg_putting, scoring_format, notes)
    VALUES (
        demo_round_4,
        demo_user_id,
        'Pebble Beach Golf Links',
        72.8,
        145,
        CURRENT_DATE - INTERVAL '23 days',
        86,
        34,
        6,
        14,
        5,
        3,
        -0.8,
        -1.2,
        0.1,
        0.1,
        0.2,
        'stroke',
        'Driver was not cooperating today. Three penalty strokes from wayward tee shots. Short game saved me.'
    );

    -- Round 5: Bethpage Black
    INSERT INTO public.rounds (id, user_id, course_name, course_rating, slope_rating, played_at, total_score, total_putts, fairways_hit, fairways_total, gir, penalties, sg_total, sg_off_tee, sg_approach, sg_around_green, sg_putting, scoring_format, notes)
    VALUES (
        demo_round_5,
        demo_user_id,
        'Bethpage Black',
        77.5,
        155,
        CURRENT_DATE - INTERVAL '30 days',
        92,
        36,
        5,
        14,
        4,
        2,
        -2.8,
        -1.0,
        -0.8,
        -0.5,
        -0.5,
        'stroke',
        'Beast of a course! Shot selection was poor. Mental note: dont try to be a hero from the rough.'
    );

    -- Round 6: Best round
    INSERT INTO public.rounds (id, user_id, course_name, course_rating, slope_rating, played_at, total_score, total_putts, fairways_hit, fairways_total, gir, penalties, sg_total, sg_off_tee, sg_approach, sg_around_green, sg_putting, scoring_format, notes)
    VALUES (
        demo_round_6,
        demo_user_id,
        'Pebble Beach Golf Links',
        72.8,
        145,
        CURRENT_DATE - INTERVAL '45 days',
        84,
        31,
        10,
        14,
        9,
        0,
        1.8,
        0.9,
        1.1,
        -0.4,
        0.2,
        'stroke',
        'Best ball striking round of the year! Drove it consistently and hit 9 greens. Putting was solid too. This is the game I know I have!'
    );

    -- ============================================
    -- DEMO HOLE SCORES (for Round 1 - Pebble Beach)
    -- ============================================
    INSERT INTO public.hole_scores (round_id, hole_number, par, score, putts, fairway_hit, gir, penalties, tee_club, approach_club, approach_result, up_and_down, first_putt_distance, sg_off_tee, sg_approach, sg_around_green, sg_putting)
    VALUES
        (demo_round_1, 1, 4, 5, 2, true, false, 0, 'Driver', '7 Iron', 'right', false, 25, 0.1, -0.3, -0.2, 0.1),
        (demo_round_1, 2, 5, 5, 2, true, true, 0, 'Driver', '5 Wood', 'green', NULL, 35, 0.2, 0.3, 0.0, -0.1),
        (demo_round_1, 3, 4, 4, 2, false, true, 0, 'Driver', '8 Iron', 'green', NULL, 18, -0.3, 0.4, 0.0, 0.1),
        (demo_round_1, 4, 4, 3, 1, true, true, 0, 'Driver', '9 Iron', 'green', NULL, 8, 0.3, 0.5, 0.0, 0.4),
        (demo_round_1, 5, 3, 3, 2, NULL, true, 0, NULL, '6 Iron', 'green', NULL, 22, 0.0, 0.2, 0.0, 0.0),
        (demo_round_1, 6, 5, 5, 2, true, true, 0, 'Driver', '4 Hybrid', 'green', NULL, 40, 0.1, 0.2, 0.0, -0.2),
        (demo_round_1, 7, 3, 4, 2, NULL, false, 0, NULL, '8 Iron', 'bunker', false, 15, 0.0, -0.5, -0.3, 0.2),
        (demo_round_1, 8, 4, 4, 2, true, true, 0, 'Driver', '7 Iron', 'green', NULL, 12, 0.2, 0.3, 0.0, 0.0),
        (demo_round_1, 9, 4, 5, 2, false, false, 1, 'Driver', 'PW', 'greenside_rough', false, 30, -0.8, -0.2, -0.2, 0.0),
        (demo_round_1, 10, 4, 4, 2, true, true, 0, 'Driver', '6 Iron', 'green', NULL, 20, 0.1, 0.2, 0.0, 0.0),
        (demo_round_1, 11, 4, 5, 2, false, false, 0, 'Driver', '8 Iron', 'fringe', true, 18, -0.2, -0.1, 0.3, -0.1),
        (demo_round_1, 12, 3, 3, 2, NULL, true, 0, NULL, '7 Iron', 'green', NULL, 15, 0.0, 0.3, 0.0, 0.1),
        (demo_round_1, 13, 4, 4, 2, true, false, 0, 'Driver', '9 Iron', 'short', true, 12, 0.2, -0.2, 0.4, 0.0),
        (demo_round_1, 14, 5, 5, 2, true, true, 0, 'Driver', '5 Iron', 'green', NULL, 45, 0.3, 0.1, 0.0, -0.3),
        (demo_round_1, 15, 4, 5, 2, false, false, 0, 'Driver', '6 Iron', 'left', false, 20, -0.4, -0.3, -0.3, 0.1),
        (demo_round_1, 16, 4, 4, 2, true, true, 0, 'Driver', '7 Iron', 'green', NULL, 10, 0.1, 0.2, 0.0, 0.1),
        (demo_round_1, 17, 3, 4, 2, NULL, false, 0, NULL, '7 Iron', 'bunker', false, 25, 0.0, -0.4, -0.4, 0.2),
        (demo_round_1, 18, 5, 5, 1, true, false, 0, 'Driver', '3 Wood', 'fringe', true, 6, 0.4, 0.1, 0.5, 0.2);

    -- ============================================
    -- HOLE SCORES FOR ROUND 2 (Torrey Pines)
    -- ============================================
    INSERT INTO public.hole_scores (round_id, hole_number, par, score, putts, fairway_hit, gir, penalties, tee_club, approach_club, approach_result, up_and_down, first_putt_distance, sg_off_tee, sg_approach, sg_around_green, sg_putting)
    VALUES
        (demo_round_2, 1, 4, 5, 2, true, false, 0, 'Driver', '6 Iron', 'short', false, 20, 0.2, -0.2, -0.3, 0.0),
        (demo_round_2, 2, 4, 4, 2, false, true, 0, '3 Wood', '7 Iron', 'green', NULL, 15, -0.3, 0.3, 0.0, 0.1),
        (demo_round_2, 3, 3, 4, 3, NULL, false, 0, NULL, '5 Iron', 'fringe', false, 30, 0.0, -0.1, -0.2, -0.4),
        (demo_round_2, 4, 5, 5, 2, true, true, 0, 'Driver', '5 Wood', 'green', NULL, 25, 0.1, 0.2, 0.0, 0.0),
        (demo_round_2, 5, 4, 5, 2, false, false, 0, 'Driver', '8 Iron', 'right', false, 22, -0.4, -0.1, -0.2, 0.0),
        (demo_round_2, 6, 4, 4, 2, true, true, 0, 'Driver', '7 Iron', 'green', NULL, 18, 0.2, 0.1, 0.0, 0.0),
        (demo_round_2, 7, 4, 5, 2, false, false, 0, 'Driver', '6 Iron', 'bunker', false, 15, -0.3, -0.3, -0.2, 0.1),
        (demo_round_2, 8, 3, 3, 2, NULL, true, 0, NULL, '6 Iron', 'green', NULL, 20, 0.0, 0.3, 0.0, 0.0),
        (demo_round_2, 9, 5, 6, 3, true, false, 1, 'Driver', '4 Hybrid', 'greenside_rough', false, 35, 0.1, -0.2, -0.2, -0.3),
        (demo_round_2, 10, 4, 4, 2, true, true, 0, 'Driver', '8 Iron', 'green', NULL, 12, 0.1, 0.2, 0.0, 0.1),
        (demo_round_2, 11, 3, 4, 2, NULL, false, 0, NULL, '7 Iron', 'left', false, 18, 0.0, -0.3, -0.2, 0.1),
        (demo_round_2, 12, 5, 7, 3, false, false, 1, 'Driver', '5 Wood', 'greenside_rough', false, 40, -0.8, -0.4, -0.3, -0.2),
        (demo_round_2, 13, 4, 5, 2, true, false, 0, '3 Wood', '6 Iron', 'short', false, 25, -0.1, -0.2, -0.2, 0.0),
        (demo_round_2, 14, 4, 4, 2, true, true, 0, 'Driver', '9 Iron', 'green', NULL, 8, 0.2, 0.4, 0.0, 0.2),
        (demo_round_2, 15, 4, 5, 2, false, false, 0, 'Driver', '7 Iron', 'fringe', false, 22, -0.2, -0.1, -0.1, 0.0),
        (demo_round_2, 16, 3, 3, 1, NULL, true, 0, NULL, '8 Iron', 'green', NULL, 5, 0.0, 0.4, 0.0, 0.3),
        (demo_round_2, 17, 4, 5, 2, true, false, 0, 'Driver', '6 Iron', 'long', false, 28, 0.1, -0.2, -0.2, 0.0),
        (demo_round_2, 18, 5, 5, 2, true, true, 0, 'Driver', '3 Wood', 'green', NULL, 30, 0.3, 0.1, 0.0, -0.1);

    -- ============================================
    -- DEMO PRACTICE SESSIONS
    -- ============================================
    INSERT INTO public.practice_sessions (user_id, session_date, duration_minutes, driving_range, chipping, pitching, bunker, putting, focus_area, balls_hit, notes, rating)
    VALUES
        (demo_user_id, CURRENT_DATE - INTERVAL '1 day', 90, 45, 15, 10, 10, 10, 'off_tee', 75, 'Worked on driver consistency. Focused on tempo and keeping the lead arm straight. Good progress!', 4),
        (demo_user_id, CURRENT_DATE - INTERVAL '4 days', 60, 0, 20, 20, 10, 10, 'around_green', 0, 'Short game session. Chipping from various lies around the practice green. Need to trust the bounce more.', 3),
        (demo_user_id, CURRENT_DATE - INTERVAL '8 days', 45, 0, 0, 0, 0, 45, 'putting', 0, 'Putting only. Gate drill and lag putting. Made 23 out of 25 from 3 feet.', 5),
        (demo_user_id, CURRENT_DATE - INTERVAL '12 days', 120, 60, 20, 15, 10, 15, 'general', 120, 'Full practice session before the Torrey Pines round. Feeling confident about iron play.', 4),
        (demo_user_id, CURRENT_DATE - INTERVAL '20 days', 75, 30, 15, 15, 0, 15, 'approach', 60, 'Dialed in my wedge distances. 52° going 105, 56° going 85, 60° going 65.', 4),
        (demo_user_id, CURRENT_DATE - INTERVAL '25 days', 60, 40, 10, 10, 0, 0, 'off_tee', 80, 'Driver session. Working on my fade to avoid trouble left.', 3),
        (demo_user_id, CURRENT_DATE - INTERVAL '35 days', 90, 30, 15, 15, 15, 15, 'general', 50, 'Pre-round warmup turned into a full session. Bunker play felt great today.', 4);

    -- ============================================
    -- DEMO GOALS
    -- ============================================
    INSERT INTO public.goals (user_id, title, description, category, target_value, current_value, target_date, status)
    VALUES
        (demo_user_id, 'Break 80', 'Shoot a round under 80 strokes', 'score', 79, 82, CURRENT_DATE + INTERVAL '90 days', 'active'),
        (demo_user_id, 'Single Digit Handicap', 'Get handicap index below 10', 'handicap', 9.9, 14.2, CURRENT_DATE + INTERVAL '365 days', 'active'),
        (demo_user_id, 'Hit 10+ fairways per round', 'Improve driving accuracy', 'driving', 10, 8, CURRENT_DATE + INTERVAL '60 days', 'active'),
        (demo_user_id, 'Eliminate 3-putts', 'No more than 1 three-putt per round average', 'putting', 1, 2.5, CURRENT_DATE + INTERVAL '30 days', 'active'),
        (demo_user_id, 'Play 50 rounds this year', 'Get more time on the course', 'rounds', 50, 42, '2026-12-31', 'active'),
        (demo_user_id, 'Break 90', 'Consistently shoot under 90', 'score', 89, 84, CURRENT_DATE - INTERVAL '30 days', 'completed'),
        (demo_user_id, 'Positive Strokes Gained', 'Achieve positive total strokes gained', 'strokes_gained', 0, 1.2, CURRENT_DATE - INTERVAL '2 days', 'completed');

    -- ============================================
    -- DEMO ACHIEVEMENTS
    -- ============================================
    INSERT INTO public.user_achievements (user_id, achievement_id, unlocked_at, round_id, progress)
    VALUES
        (demo_user_id, 'first_birdie', CURRENT_DATE - INTERVAL '180 days', NULL, 1),
        (demo_user_id, 'break_90', CURRENT_DATE - INTERVAL '90 days', demo_round_6, 1),
        (demo_user_id, 'rounds_5', CURRENT_DATE - INTERVAL '150 days', NULL, 5),
        (demo_user_id, 'rounds_25', CURRENT_DATE - INTERVAL '60 days', NULL, 25),
        (demo_user_id, 'courses_5', CURRENT_DATE - INTERVAL '45 days', NULL, 5),
        (demo_user_id, 'no_3putts', CURRENT_DATE - INTERVAL '30 days', demo_round_6, 1),
        (demo_user_id, 'sg_positive', CURRENT_DATE - INTERVAL '2 days', demo_round_1, 1);

    RAISE NOTICE 'Demo data populated successfully!';
    RAISE NOTICE '================================';
    RAISE NOTICE 'Demo Account Credentials:';
    RAISE NOTICE 'Email: demo@roundcaddy.app';
    RAISE NOTICE 'Password: DemoReview2026!';
    RAISE NOTICE '================================';

END $$;
