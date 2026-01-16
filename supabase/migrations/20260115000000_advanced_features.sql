-- Advanced Features Migration
-- Run this in your Supabase SQL Editor to add new features

-- ============================================
-- 1. COURSES TABLE (Course Database)
-- ============================================
CREATE TABLE IF NOT EXISTS public.courses (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  city TEXT,
  state TEXT,
  country TEXT DEFAULT 'USA',
  course_rating DECIMAL(4,1),
  slope_rating INTEGER,
  par INTEGER DEFAULT 72,
  holes INTEGER DEFAULT 18,
  -- Hole-by-hole pars (JSON array)
  hole_pars JSONB,
  -- Metadata
  website TEXT,
  phone TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add some popular courses
INSERT INTO public.courses (name, city, state, course_rating, slope_rating, par) VALUES
  ('Pebble Beach Golf Links', 'Pebble Beach', 'CA', 75.5, 145, 72),
  ('TPC Sawgrass (Stadium)', 'Ponte Vedra Beach', 'FL', 76.4, 155, 72),
  ('Augusta National Golf Club', 'Augusta', 'GA', 76.2, 148, 72),
  ('St Andrews - Old Course', 'St Andrews', 'Scotland', 73.1, 132, 72),
  ('Cypress Point Club', 'Pebble Beach', 'CA', 72.4, 135, 72),
  ('Pinehurst No. 2', 'Pinehurst', 'NC', 75.3, 141, 72),
  ('Torrey Pines (South)', 'La Jolla', 'CA', 76.4, 142, 72),
  ('Bethpage Black', 'Farmingdale', 'NY', 77.5, 155, 71),
  ('Whistling Straits (Straits)', 'Kohler', 'WI', 76.7, 151, 72),
  ('Bandon Dunes', 'Bandon', 'OR', 74.5, 140, 72)
ON CONFLICT DO NOTHING;

-- Allow public read access to courses
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view courses" ON public.courses FOR SELECT USING (true);

-- Index for course search
CREATE INDEX IF NOT EXISTS idx_courses_name ON public.courses USING gin(to_tsvector('english', name));

-- ============================================
-- 2. PRACTICE SESSIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.practice_sessions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  session_date DATE NOT NULL DEFAULT CURRENT_DATE,
  duration_minutes INTEGER,
  -- Practice areas (time spent in minutes)
  driving_range INTEGER DEFAULT 0,
  chipping INTEGER DEFAULT 0,
  pitching INTEGER DEFAULT 0,
  bunker INTEGER DEFAULT 0,
  putting INTEGER DEFAULT 0,
  -- Specific drills/notes
  focus_area TEXT CHECK (focus_area IN ('off_tee', 'approach', 'around_green', 'putting', 'general')),
  balls_hit INTEGER,
  notes TEXT,
  rating INTEGER CHECK (rating >= 1 AND rating <= 5), -- How good was the session?
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS for practice sessions
ALTER TABLE public.practice_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own practice sessions" ON public.practice_sessions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own practice sessions" ON public.practice_sessions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own practice sessions" ON public.practice_sessions
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own practice sessions" ON public.practice_sessions
  FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_practice_sessions_user ON public.practice_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_practice_sessions_date ON public.practice_sessions(session_date DESC);

-- ============================================
-- 3. GOALS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.goals (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  category TEXT CHECK (category IN ('handicap', 'score', 'strokes_gained', 'putting', 'driving', 'approach', 'practice', 'rounds', 'other')),
  target_value DECIMAL(10,2),
  current_value DECIMAL(10,2),
  target_date DATE,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'abandoned')),
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS for goals
ALTER TABLE public.goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own goals" ON public.goals
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own goals" ON public.goals
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own goals" ON public.goals
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own goals" ON public.goals
  FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_goals_user ON public.goals(user_id);
CREATE INDEX IF NOT EXISTS idx_goals_status ON public.goals(status);

-- ============================================
-- 4. SHOT TRACKING TABLE (Per-shot data)
-- ============================================
CREATE TABLE IF NOT EXISTS public.shots (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  hole_score_id UUID REFERENCES public.hole_scores(id) ON DELETE CASCADE NOT NULL,
  shot_number INTEGER NOT NULL,
  club TEXT,
  -- Distance
  distance_to_pin INTEGER, -- yards before shot
  distance_after INTEGER, -- yards/feet after shot
  -- Location
  lie TEXT CHECK (lie IN ('tee', 'fairway', 'rough', 'bunker', 'fringe', 'green', 'hazard', 'other')),
  result_lie TEXT CHECK (result_lie IN ('fairway', 'rough', 'bunker', 'fringe', 'green', 'hazard', 'hole', 'other')),
  -- Quality
  quality TEXT CHECK (quality IN ('excellent', 'good', 'okay', 'poor', 'terrible')),
  miss_direction TEXT CHECK (miss_direction IN ('left', 'right', 'short', 'long', 'on_target')),
  -- Strokes gained for this shot
  sg_value DECIMAL(4,2),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(hole_score_id, shot_number)
);

-- RLS for shots (inherits from hole_scores)
ALTER TABLE public.shots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own shots" ON public.shots
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.hole_scores hs
      JOIN public.rounds r ON r.id = hs.round_id
      WHERE hs.id = shots.hole_score_id 
      AND r.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own shots" ON public.shots
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.hole_scores hs
      JOIN public.rounds r ON r.id = hs.round_id
      WHERE hs.id = shots.hole_score_id 
      AND r.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own shots" ON public.shots
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.hole_scores hs
      JOIN public.rounds r ON r.id = hs.round_id
      WHERE hs.id = shots.hole_score_id 
      AND r.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete own shots" ON public.shots
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.hole_scores hs
      JOIN public.rounds r ON r.id = hs.round_id
      WHERE hs.id = shots.hole_score_id 
      AND r.user_id = auth.uid()
    )
  );

CREATE INDEX IF NOT EXISTS idx_shots_hole_score ON public.shots(hole_score_id);

-- ============================================
-- 5. LEADERBOARDS / SOCIAL FEATURES
-- ============================================

-- User followers
CREATE TABLE IF NOT EXISTS public.follows (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  follower_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  following_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(follower_id, following_id),
  CHECK (follower_id != following_id)
);

-- RLS for follows
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view follows" ON public.follows FOR SELECT USING (true);
CREATE POLICY "Users can follow others" ON public.follows FOR INSERT WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "Users can unfollow" ON public.follows FOR DELETE USING (auth.uid() = follower_id);

-- Update profiles for social features
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS home_course TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS low_handicap DECIMAL(4,1);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS rounds_played INTEGER DEFAULT 0;

-- Allow viewing public profiles
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view profiles" ON public.profiles
  FOR SELECT USING (auth.uid() = id OR is_public = true);

-- Add updated_at trigger for new tables
CREATE TRIGGER update_practice_sessions_updated_at
  BEFORE UPDATE ON public.practice_sessions
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_goals_updated_at
  BEFORE UPDATE ON public.goals
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_courses_updated_at
  BEFORE UPDATE ON public.courses
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================
-- 6. HANDICAP CALCULATION FUNCTION
-- ============================================
CREATE OR REPLACE FUNCTION public.calculate_handicap_index(p_user_id UUID)
RETURNS DECIMAL(4,1) AS $$
DECLARE
  v_handicap DECIMAL(4,1);
  v_count INTEGER;
BEGIN
  -- Get count of rounds with course rating
  SELECT COUNT(*) INTO v_count
  FROM public.rounds
  WHERE user_id = p_user_id 
  AND course_rating IS NOT NULL 
  AND slope_rating IS NOT NULL;
  
  IF v_count < 3 THEN
    RETURN NULL; -- Need at least 3 rounds
  END IF;
  
  -- Calculate handicap differential for best rounds
  -- Handicap Differential = (Score - Course Rating) x 113 / Slope Rating
  -- Use best 8 of last 20 rounds (simplified)
  WITH differentials AS (
    SELECT 
      ((total_score - course_rating) * 113.0 / slope_rating) as diff
    FROM public.rounds
    WHERE user_id = p_user_id 
    AND course_rating IS NOT NULL 
    AND slope_rating IS NOT NULL
    ORDER BY played_at DESC
    LIMIT 20
  ),
  best_diffs AS (
    SELECT diff
    FROM differentials
    ORDER BY diff ASC
    LIMIT GREATEST(1, (SELECT COUNT(*) * 0.4 FROM differentials)::INTEGER)
  )
  SELECT ROUND(AVG(diff) * 0.96, 1) INTO v_handicap FROM best_diffs;
  
  RETURN v_handicap;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

