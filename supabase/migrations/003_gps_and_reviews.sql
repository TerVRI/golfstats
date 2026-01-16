-- ============================================
-- ENABLE POSTGIS EXTENSION FOR GPS DATA
-- ============================================
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================
-- UPDATE COURSES TABLE WITH GPS DATA
-- ============================================
ALTER TABLE public.courses 
ADD COLUMN IF NOT EXISTS geojson_data JSONB,
ADD COLUMN IF NOT EXISTS latitude DECIMAL(10, 7),
ADD COLUMN IF NOT EXISTS longitude DECIMAL(10, 7),
ADD COLUMN IF NOT EXISTS address TEXT,
ADD COLUMN IF NOT EXISTS phone TEXT,
ADD COLUMN IF NOT EXISTS website TEXT,
ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS contributed_by UUID REFERENCES public.profiles(id);

-- Add hole_data for detailed hole information with GPS
ALTER TABLE public.courses
ADD COLUMN IF NOT EXISTS hole_data JSONB;

-- Example hole_data structure:
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

-- ============================================
-- SHOTS TABLE FOR TRACKING INDIVIDUAL SHOTS WITH GPS
-- ============================================
-- Add missing columns to existing shots table
ALTER TABLE public.shots ADD COLUMN IF NOT EXISTS round_id UUID REFERENCES public.rounds(id) ON DELETE CASCADE;
ALTER TABLE public.shots ADD COLUMN IF NOT EXISTS hole_number INTEGER;
ALTER TABLE public.shots ADD COLUMN IF NOT EXISTS shot_number INTEGER;
ALTER TABLE public.shots ADD COLUMN IF NOT EXISTS club_id UUID REFERENCES public.clubs(id) ON DELETE SET NULL;
ALTER TABLE public.shots ADD COLUMN IF NOT EXISTS club_name TEXT;
ALTER TABLE public.shots ADD COLUMN IF NOT EXISTS lie TEXT;
ALTER TABLE public.shots ADD COLUMN IF NOT EXISTS latitude DECIMAL(10, 7);
ALTER TABLE public.shots ADD COLUMN IF NOT EXISTS longitude DECIMAL(10, 7);
ALTER TABLE public.shots ADD COLUMN IF NOT EXISTS distance_to_pin INTEGER;
ALTER TABLE public.shots ADD COLUMN IF NOT EXISTS result TEXT;
ALTER TABLE public.shots ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.shots ADD COLUMN IF NOT EXISTS shot_time TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.shots ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.shots ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Users can view shots from their rounds" ON public.shots
        FOR SELECT USING (
            round_id IN (SELECT id FROM public.rounds WHERE user_id = auth.uid())
        );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE POLICY "Users can insert shots to their rounds" ON public.shots
        FOR INSERT WITH CHECK (
            round_id IN (SELECT id FROM public.rounds WHERE user_id = auth.uid())
        );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE POLICY "Users can update shots in their rounds" ON public.shots
        FOR UPDATE USING (
            round_id IN (SELECT id FROM public.rounds WHERE user_id = auth.uid())
        );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE POLICY "Users can delete shots from their rounds" ON public.shots
        FOR DELETE USING (
            round_id IN (SELECT id FROM public.rounds WHERE user_id = auth.uid())
        );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_shots_round_id ON public.shots(round_id);
CREATE INDEX IF NOT EXISTS idx_shots_hole ON public.shots(round_id, hole_number);

-- ============================================
-- ROUND TRACKS TABLE FOR GPS TRACKING PATH
-- ============================================
CREATE TABLE IF NOT EXISTS public.round_tracks (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    round_id UUID REFERENCES public.rounds(id) ON DELETE CASCADE NOT NULL UNIQUE,
    track_points JSONB NOT NULL DEFAULT '[]',
    -- track_points structure: [{ "lat": 40.7128, "lon": -74.0060, "timestamp": "2024-01-15T10:30:00Z", "accuracy": 5 }, ...]
    total_distance_yards INTEGER,
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.round_tracks ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Users can view tracks from their rounds" ON public.round_tracks
        FOR SELECT USING (
            round_id IN (SELECT id FROM public.rounds WHERE user_id = auth.uid())
        );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE POLICY "Users can insert tracks to their rounds" ON public.round_tracks
        FOR INSERT WITH CHECK (
            round_id IN (SELECT id FROM public.rounds WHERE user_id = auth.uid())
        );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE POLICY "Users can update tracks in their rounds" ON public.round_tracks
        FOR UPDATE USING (
            round_id IN (SELECT id FROM public.rounds WHERE user_id = auth.uid())
        );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE POLICY "Users can delete tracks from their rounds" ON public.round_tracks
        FOR DELETE USING (
            round_id IN (SELECT id FROM public.rounds WHERE user_id = auth.uid())
        );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================
-- COURSE REVIEWS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.course_reviews (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    title TEXT,
    review_text TEXT,
    conditions_rating INTEGER CHECK (conditions_rating >= 1 AND conditions_rating <= 5),
    pace_rating INTEGER CHECK (pace_rating >= 1 AND pace_rating <= 5),
    value_rating INTEGER CHECK (value_rating >= 1 AND value_rating <= 5),
    difficulty TEXT CHECK (difficulty IN ('easy', 'moderate', 'difficult', 'very_difficult')),
    would_recommend BOOLEAN DEFAULT TRUE,
    played_at DATE,
    photos JSONB DEFAULT '[]', -- Array of photo URLs
    helpful_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(course_id, user_id)
);

ALTER TABLE public.course_reviews ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Anyone can view course reviews" ON public.course_reviews
        FOR SELECT USING (TRUE);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE POLICY "Users can insert own reviews" ON public.course_reviews
        FOR INSERT WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE POLICY "Users can update own reviews" ON public.course_reviews
        FOR UPDATE USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE POLICY "Users can delete own reviews" ON public.course_reviews
        FOR DELETE USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_course_reviews_course_id ON public.course_reviews(course_id);
CREATE INDEX IF NOT EXISTS idx_course_reviews_user_id ON public.course_reviews(user_id);
CREATE INDEX IF NOT EXISTS idx_course_reviews_rating ON public.course_reviews(rating);

-- ============================================
-- REVIEW HELPFUL VOTES
-- ============================================
CREATE TABLE IF NOT EXISTS public.review_votes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    review_id UUID REFERENCES public.course_reviews(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    is_helpful BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(review_id, user_id)
);

ALTER TABLE public.review_votes ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Users can view votes" ON public.review_votes FOR SELECT USING (TRUE);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE POLICY "Users can insert own votes" ON public.review_votes FOR INSERT WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE POLICY "Users can update own votes" ON public.review_votes FOR UPDATE USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE POLICY "Users can delete own votes" ON public.review_votes FOR DELETE USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================
-- WEATHER DATA TABLE (cached from Open-Meteo)
-- ============================================
CREATE TABLE IF NOT EXISTS public.weather_cache (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    latitude DECIMAL(10, 7) NOT NULL,
    longitude DECIMAL(10, 7) NOT NULL,
    weather_data JSONB NOT NULL,
    -- weather_data structure: { "temperature": 72, "wind_speed": 10, "wind_direction": 180, "precipitation_chance": 20, "conditions": "sunny" }
    fetched_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_weather_cache_location ON public.weather_cache(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_weather_cache_expires ON public.weather_cache(expires_at);

-- RLS not needed for cache table as it's managed by backend

-- ============================================
-- FUNCTION TO UPDATE COURSE AVERAGE RATING
-- ============================================
CREATE OR REPLACE FUNCTION update_course_avg_rating()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the courses table with new average rating
    -- This would require adding avg_rating column to courses
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add avg_rating to courses
ALTER TABLE public.courses
ADD COLUMN IF NOT EXISTS avg_rating DECIMAL(2, 1),
ADD COLUMN IF NOT EXISTS review_count INTEGER DEFAULT 0;

-- Trigger to update course rating when reviews change
CREATE OR REPLACE FUNCTION refresh_course_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.courses 
    SET 
        avg_rating = (
            SELECT AVG(rating)::DECIMAL(2,1) 
            FROM public.course_reviews 
            WHERE course_id = COALESCE(NEW.course_id, OLD.course_id)
        ),
        review_count = (
            SELECT COUNT(*) 
            FROM public.course_reviews 
            WHERE course_id = COALESCE(NEW.course_id, OLD.course_id)
        )
    WHERE id = COALESCE(NEW.course_id, OLD.course_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_course_rating_on_review
    AFTER INSERT OR UPDATE OR DELETE ON public.course_reviews
    FOR EACH ROW EXECUTE FUNCTION refresh_course_rating();

-- Update triggers for timestamps
CREATE TRIGGER update_course_reviews_updated_at
    BEFORE UPDATE ON public.course_reviews
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
