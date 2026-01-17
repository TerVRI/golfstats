-- ============================================
-- MIGRATION 002: Clubs, Achievements, Scoring Formats
-- ============================================

-- ============================================
-- 1. CLUBS / BAG MANAGEMENT
-- ============================================
CREATE TABLE IF NOT EXISTS public.clubs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL, -- e.g., "Driver", "7 Iron"
  brand TEXT, -- e.g., "TaylorMade", "Callaway"
  model TEXT, -- e.g., "Stealth 2", "Paradym"
  loft DECIMAL(4,1), -- degrees
  shaft TEXT, -- e.g., "Regular", "Stiff", "X-Stiff"
  shaft_material TEXT CHECK (shaft_material IN ('graphite', 'steel')),
  club_type TEXT CHECK (club_type IN ('driver', 'wood', 'hybrid', 'iron', 'wedge', 'putter')) NOT NULL,
  purchase_date DATE,
  in_bag BOOLEAN DEFAULT true, -- currently in the bag?
  avg_distance INTEGER, -- auto-calculated from shots
  total_shots INTEGER DEFAULT 0,
  notes TEXT,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS for clubs
ALTER TABLE public.clubs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own clubs" ON public.clubs
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own clubs" ON public.clubs
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own clubs" ON public.clubs
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own clubs" ON public.clubs
  FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_clubs_user ON public.clubs(user_id);
CREATE INDEX IF NOT EXISTS idx_clubs_in_bag ON public.clubs(user_id, in_bag);

-- Update shots table to reference user's clubs
ALTER TABLE public.shots ADD COLUMN IF NOT EXISTS club_id UUID REFERENCES public.clubs(id) ON DELETE SET NULL;
ALTER TABLE public.shots ADD COLUMN IF NOT EXISTS distance_carried INTEGER; -- actual distance hit

-- ============================================
-- 2. ACHIEVEMENTS / BADGES
-- ============================================
CREATE TABLE IF NOT EXISTS public.achievement_definitions (
  id TEXT PRIMARY KEY, -- e.g., 'first_birdie', 'eagle_club'
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  icon TEXT NOT NULL, -- emoji or icon name
  category TEXT CHECK (category IN ('scoring', 'consistency', 'improvement', 'milestones', 'social')) NOT NULL,
  points INTEGER DEFAULT 10,
  tier TEXT CHECK (tier IN ('bronze', 'silver', 'gold', 'platinum')) DEFAULT 'bronze',
  requirement_type TEXT NOT NULL, -- 'single', 'cumulative', 'streak'
  requirement_value INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User's unlocked achievements
CREATE TABLE IF NOT EXISTS public.user_achievements (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  achievement_id TEXT REFERENCES public.achievement_definitions(id) ON DELETE CASCADE NOT NULL,
  unlocked_at TIMESTAMPTZ DEFAULT NOW(),
  round_id UUID REFERENCES public.rounds(id) ON DELETE SET NULL, -- which round triggered it
  progress INTEGER DEFAULT 0, -- for cumulative achievements
  UNIQUE(user_id, achievement_id)
);

-- RLS for achievements
ALTER TABLE public.achievement_definitions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view achievements" ON public.achievement_definitions FOR SELECT USING (true);

ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own achievements" ON public.user_achievements
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can view others achievements" ON public.user_achievements
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = user_achievements.user_id AND p.is_public = true
    )
  );
CREATE POLICY "System can insert achievements" ON public.user_achievements
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Pre-populate achievements
INSERT INTO public.achievement_definitions (id, name, description, icon, category, tier, requirement_type, requirement_value, points) VALUES
  -- Scoring achievements
  ('first_birdie', 'First Birdie', 'Score your first birdie', '🐦', 'scoring', 'bronze', 'single', 1, 10),
  ('first_eagle', 'Eagle Eye', 'Score your first eagle', '🦅', 'scoring', 'silver', 'single', 1, 25),
  ('first_ace', 'Hole in One!', 'Make a hole-in-one', '🎯', 'scoring', 'platinum', 'single', 1, 100),
  ('birdie_streak_3', 'Birdie Machine', 'Make 3 birdies in a single round', '🔥', 'scoring', 'silver', 'single', 3, 30),
  ('under_par', 'Under Par', 'Finish a round under par', '⬇️', 'scoring', 'gold', 'single', 1, 50),
  ('break_80', 'Breaking 80', 'Shoot a round under 80', '8️⃣', 'scoring', 'silver', 'single', 1, 40),
  ('break_90', 'Breaking 90', 'Shoot a round under 90', '9️⃣', 'scoring', 'bronze', 'single', 1, 20),
  ('break_100', 'Breaking 100', 'Shoot a round under 100', '💯', 'scoring', 'bronze', 'single', 1, 15),
  
  -- Milestones
  ('rounds_5', 'Getting Started', 'Play 5 rounds', '🏌️', 'milestones', 'bronze', 'cumulative', 5, 10),
  ('rounds_25', 'Regular Player', 'Play 25 rounds', '📊', 'milestones', 'silver', 'cumulative', 25, 30),
  ('rounds_100', 'Century Club', 'Play 100 rounds', '🏆', 'milestones', 'gold', 'cumulative', 100, 75),
  ('courses_5', 'Course Explorer', 'Play 5 different courses', '🗺️', 'milestones', 'bronze', 'cumulative', 5, 15),
  ('courses_20', 'Golf Nomad', 'Play 20 different courses', '🌍', 'milestones', 'silver', 'cumulative', 20, 40),
  
  -- Consistency
  ('all_fairways', 'Fairway Finder', 'Hit all fairways in a round', '🎯', 'consistency', 'gold', 'single', 1, 50),
  ('all_greens', 'GIR Master', 'Hit all greens in regulation', '🟢', 'consistency', 'platinum', 'single', 1, 75),
  ('no_3putts', 'No Three-Putts', 'Complete a round without 3-putting', '⛳', 'consistency', 'silver', 'single', 1, 30),
  ('bogey_free_9', 'Bogey-Free Nine', 'Play 9 holes without a bogey', '✨', 'consistency', 'silver', 'single', 1, 35),
  
  -- Improvement
  ('pb_broken', 'Personal Best', 'Break your personal best score', '📈', 'improvement', 'silver', 'single', 1, 40),
  ('handicap_drop', 'Handicap Drop', 'Lower your handicap by 1 stroke', '⬇️', 'improvement', 'bronze', 'cumulative', 1, 20),
  ('sg_positive', 'Strokes Gained Positive', 'Achieve positive strokes gained', '➕', 'improvement', 'silver', 'single', 1, 30),
  
  -- Social
  ('first_share', 'Social Golfer', 'Share your first round', '📤', 'social', 'bronze', 'single', 1, 5),
  ('followers_10', 'Rising Star', 'Get 10 followers', '⭐', 'social', 'silver', 'cumulative', 10, 25),
  
  -- Course Contributions
  ('first_course_contribution', 'Course Mapper', 'Contribute your first course', '🗺️', 'social', 'bronze', 'single', 1, 25),
  ('course_contributions_5', 'Course Builder', 'Contribute 5 courses', '🏗️', 'social', 'silver', 'cumulative', 5, 50),
  ('course_contributions_10', 'Course Architect', 'Contribute 10 courses', '🏛️', 'social', 'gold', 'cumulative', 10, 100),
  ('course_contributions_25', 'Master Cartographer', 'Contribute 25 courses', '📐', 'social', 'platinum', 'cumulative', 25, 250),
  ('verified_course_contributor', 'Verified Contributor', 'Have a course you contributed verified', '✅', 'social', 'silver', 'single', 1, 75),
  ('course_confirmation_5', 'Course Validator', 'Confirm 5 courses', '✓', 'social', 'bronze', 'cumulative', 5, 30),
  ('course_confirmation_20', 'Course Inspector', 'Confirm 20 courses', '🔍', 'social', 'silver', 'cumulative', 20, 80)
ON CONFLICT (id) DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_user_achievements_user ON public.user_achievements(user_id);

-- ============================================
-- 3. SCORING FORMATS
-- ============================================
-- Add scoring format to rounds table
ALTER TABLE public.rounds ADD COLUMN IF NOT EXISTS scoring_format TEXT 
  CHECK (scoring_format IN ('stroke', 'stableford', 'match', 'skins', 'best_ball', 'scramble')) 
  DEFAULT 'stroke';

-- Stableford points per hole (calculated field)
ALTER TABLE public.hole_scores ADD COLUMN IF NOT EXISTS stableford_points INTEGER DEFAULT 0;

-- Match play result per hole (-1 = lost, 0 = halved, 1 = won)
ALTER TABLE public.hole_scores ADD COLUMN IF NOT EXISTS match_result INTEGER CHECK (match_result IN (-1, 0, 1));

-- Skins: whether this hole was won in skins
ALTER TABLE public.hole_scores ADD COLUMN IF NOT EXISTS skin_won BOOLEAN DEFAULT false;

-- ============================================
-- 4. USER PREFERENCES (for theme, etc)
-- ============================================
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS preferences JSONB DEFAULT '{
  "theme": "dark",
  "units": "yards",
  "default_tees": "white",
  "notifications": true,
  "public_stats": false
}'::jsonb;

-- Update function for calculating Stableford points
CREATE OR REPLACE FUNCTION public.calculate_stableford_points(p_score INTEGER, p_par INTEGER, p_handicap_strokes INTEGER DEFAULT 0)
RETURNS INTEGER AS $$
DECLARE
  v_net_score INTEGER;
  v_relative INTEGER;
BEGIN
  v_net_score := p_score - p_handicap_strokes;
  v_relative := v_net_score - p_par;
  
  RETURN CASE
    WHEN v_relative <= -3 THEN 5  -- Albatross or better
    WHEN v_relative = -2 THEN 4   -- Eagle
    WHEN v_relative = -1 THEN 3   -- Birdie
    WHEN v_relative = 0 THEN 2    -- Par
    WHEN v_relative = 1 THEN 1    -- Bogey
    ELSE 0                         -- Double bogey or worse
  END;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update club stats
CREATE TRIGGER update_clubs_updated_at
  BEFORE UPDATE ON public.clubs
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================
-- 5. CLUB STATISTICS VIEW
-- ============================================
CREATE OR REPLACE VIEW public.club_stats AS
SELECT 
  c.id as club_id,
  c.user_id,
  c.name,
  c.brand,
  c.model,
  c.club_type,
  COUNT(s.id) as total_shots,
  ROUND(AVG(s.distance_carried)::numeric, 0) as avg_distance,
  ROUND(AVG(CASE WHEN s.quality = 'excellent' THEN 5 WHEN s.quality = 'good' THEN 4 WHEN s.quality = 'okay' THEN 3 WHEN s.quality = 'poor' THEN 2 ELSE 1 END)::numeric, 1) as avg_quality,
  COUNT(CASE WHEN s.result_lie = 'green' OR s.result_lie = 'hole' THEN 1 END) as greens_hit,
  COUNT(CASE WHEN s.result_lie = 'fairway' THEN 1 END) as fairways_hit
FROM public.clubs c
LEFT JOIN public.shots s ON s.club_id = c.id
GROUP BY c.id, c.user_id, c.name, c.brand, c.model, c.club_type;

