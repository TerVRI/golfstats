-- Golf Stats Database Schema
-- Run this in your Supabase SQL Editor to set up the database

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT NOT NULL,
  name TEXT,
  handicap DECIMAL(4,1),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Rounds table
CREATE TABLE IF NOT EXISTS public.rounds (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  course_name TEXT NOT NULL,
  course_rating DECIMAL(4,1),
  slope_rating INTEGER,
  played_at DATE NOT NULL DEFAULT CURRENT_DATE,
  total_score INTEGER NOT NULL,
  total_putts INTEGER DEFAULT 0,
  fairways_hit INTEGER DEFAULT 0,
  fairways_total INTEGER DEFAULT 14,
  gir INTEGER DEFAULT 0,
  penalties INTEGER DEFAULT 0,
  -- Strokes Gained totals
  sg_total DECIMAL(5,2) DEFAULT 0,
  sg_off_tee DECIMAL(5,2) DEFAULT 0,
  sg_approach DECIMAL(5,2) DEFAULT 0,
  sg_around_green DECIMAL(5,2) DEFAULT 0,
  sg_putting DECIMAL(5,2) DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Hole scores table
CREATE TABLE IF NOT EXISTS public.hole_scores (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  round_id UUID REFERENCES public.rounds(id) ON DELETE CASCADE NOT NULL,
  hole_number INTEGER NOT NULL CHECK (hole_number >= 1 AND hole_number <= 18),
  par INTEGER NOT NULL CHECK (par >= 3 AND par <= 6),
  score INTEGER NOT NULL CHECK (score >= 1),
  putts INTEGER DEFAULT 0 CHECK (putts >= 0),
  fairway_hit BOOLEAN, -- NULL for par 3s
  gir BOOLEAN DEFAULT FALSE,
  penalties INTEGER DEFAULT 0,
  -- Shot tracking
  tee_club TEXT,
  approach_distance INTEGER, -- yards
  approach_club TEXT,
  approach_result TEXT CHECK (approach_result IN ('green', 'fringe', 'greenside_rough', 'bunker', 'short', 'long', 'left', 'right')),
  up_and_down BOOLEAN,
  sand_save BOOLEAN,
  first_putt_distance INTEGER, -- feet
  -- Strokes Gained per hole
  sg_off_tee DECIMAL(4,2) DEFAULT 0,
  sg_approach DECIMAL(4,2) DEFAULT 0,
  sg_around_green DECIMAL(4,2) DEFAULT 0,
  sg_putting DECIMAL(4,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(round_id, hole_number)
);

-- Indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_rounds_user_id ON public.rounds(user_id);
CREATE INDEX IF NOT EXISTS idx_rounds_played_at ON public.rounds(played_at DESC);
CREATE INDEX IF NOT EXISTS idx_hole_scores_round_id ON public.hole_scores(round_id);

-- Row Level Security (RLS) Policies
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hole_scores ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Rounds policies
CREATE POLICY "Users can view own rounds" ON public.rounds
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own rounds" ON public.rounds
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own rounds" ON public.rounds
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own rounds" ON public.rounds
  FOR DELETE USING (auth.uid() = user_id);

-- Hole scores policies
CREATE POLICY "Users can view own hole scores" ON public.hole_scores
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.rounds 
      WHERE rounds.id = hole_scores.round_id 
      AND rounds.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own hole scores" ON public.hole_scores
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.rounds 
      WHERE rounds.id = hole_scores.round_id 
      AND rounds.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own hole scores" ON public.hole_scores
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.rounds 
      WHERE rounds.id = hole_scores.round_id 
      AND rounds.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete own hole scores" ON public.hole_scores
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.rounds 
      WHERE rounds.id = hole_scores.round_id 
      AND rounds.user_id = auth.uid()
    )
  );

-- Function to automatically create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'name', ''));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_rounds_updated_at
  BEFORE UPDATE ON public.rounds
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

