-- User Profiles Migration
-- Stores user personalization settings, golf preferences, and app settings

-- Create user_profiles table
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Personal Information
    birthday DATE,
    gender TEXT CHECK (gender IN ('male', 'female', 'other', 'prefer_not_to_say')),
    handedness TEXT DEFAULT 'right' CHECK (handedness IN ('right', 'left')),
    
    -- Golf-Specific Info
    handicap_index DECIMAL(4,1),
    target_handicap DECIMAL(4,1),
    skill_level TEXT DEFAULT 'intermediate' CHECK (skill_level IN ('beginner', 'casual', 'intermediate', 'advanced', 'expert', 'tour_pro')),
    driver_distance INTEGER DEFAULT 220,
    playing_frequency TEXT DEFAULT 'occasional' CHECK (playing_frequency IN ('rarely', 'occasional', 'regular', 'frequent', 'very_frequent')),
    preferred_tees TEXT DEFAULT 'white' CHECK (preferred_tees IN ('black', 'blue', 'white', 'yellow', 'red', 'gold', 'green')),
    
    -- App Preferences
    distance_unit TEXT DEFAULT 'yards' CHECK (distance_unit IN ('yards', 'meters')),
    temperature_unit TEXT DEFAULT 'fahrenheit' CHECK (temperature_unit IN ('fahrenheit', 'celsius')),
    speed_unit TEXT DEFAULT 'mph' CHECK (speed_unit IN ('mph', 'kph', 'mps')),
    
    -- Onboarding Status
    onboarding_completed BOOLEAN DEFAULT false,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure one profile per user
    UNIQUE(user_id)
);

-- Create index on user_id for fast lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);

-- Create app_settings table (separate from profile for local-only settings)
CREATE TABLE IF NOT EXISTS user_app_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Notification Preferences
    round_reminder_enabled BOOLEAN DEFAULT true,
    weather_alert_enabled BOOLEAN DEFAULT true,
    tee_time_reminder_enabled BOOLEAN DEFAULT true,
    achievement_notifications_enabled BOOLEAN DEFAULT true,
    social_notifications_enabled BOOLEAN DEFAULT true,
    marketing_notifications_enabled BOOLEAN DEFAULT false,
    
    -- Sound & Haptics
    sound_enabled BOOLEAN DEFAULT true,
    haptic_feedback_enabled BOOLEAN DEFAULT true,
    voice_announcements_enabled BOOLEAN DEFAULT false,
    
    -- Privacy
    share_rounds_publicly BOOLEAN DEFAULT false,
    show_on_leaderboards BOOLEAN DEFAULT true,
    allow_friend_requests BOOLEAN DEFAULT true,
    
    -- Display
    keep_screen_on_during_round BOOLEAN DEFAULT true,
    auto_advance_hole BOOLEAN DEFAULT false,
    show_yardage_markers BOOLEAN DEFAULT true,
    show_hazard_warnings BOOLEAN DEFAULT true,
    map_style_preference TEXT DEFAULT 'satellite' CHECK (map_style_preference IN ('satellite', 'standard', 'hybrid')),
    
    -- Data & Storage
    auto_backup_enabled BOOLEAN DEFAULT true,
    offline_download_on_wifi_only BOOLEAN DEFAULT true,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(user_id)
);

-- Create index on user_id
CREATE INDEX IF NOT EXISTS idx_user_app_settings_user_id ON user_app_settings(user_id);

-- Create issue_reports table
CREATE TABLE IF NOT EXISTS issue_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    round_id UUID REFERENCES rounds(id) ON DELETE SET NULL,
    course_id UUID REFERENCES golf_courses(id) ON DELETE SET NULL,
    hole_number INTEGER,
    
    -- Issue types stored as JSONB array
    issue_types JSONB NOT NULL DEFAULT '[]',
    additional_details TEXT,
    
    -- Status tracking
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewing', 'resolved', 'closed')),
    resolution_notes TEXT,
    resolved_at TIMESTAMPTZ,
    resolved_by UUID REFERENCES auth.users(id),
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for issue reports
CREATE INDEX IF NOT EXISTS idx_issue_reports_user_id ON issue_reports(user_id);
CREATE INDEX IF NOT EXISTS idx_issue_reports_status ON issue_reports(status);
CREATE INDEX IF NOT EXISTS idx_issue_reports_course_id ON issue_reports(course_id);
CREATE INDEX IF NOT EXISTS idx_issue_reports_created_at ON issue_reports(created_at DESC);

-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE issue_reports ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_profiles
CREATE POLICY "Users can view own profile"
    ON user_profiles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile"
    ON user_profiles FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
    ON user_profiles FOR UPDATE
    USING (auth.uid() = user_id);

-- RLS Policies for user_app_settings
CREATE POLICY "Users can view own settings"
    ON user_app_settings FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own settings"
    ON user_app_settings FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own settings"
    ON user_app_settings FOR UPDATE
    USING (auth.uid() = user_id);

-- RLS Policies for issue_reports
CREATE POLICY "Users can view own reports"
    ON issue_reports FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create reports"
    ON issue_reports FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own reports"
    ON issue_reports FOR UPDATE
    USING (auth.uid() = user_id);

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply trigger to all tables
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_app_settings_updated_at
    BEFORE UPDATE ON user_app_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_issue_reports_updated_at
    BEFORE UPDATE ON issue_reports
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to get or create user profile
CREATE OR REPLACE FUNCTION get_or_create_user_profile(p_user_id UUID)
RETURNS user_profiles AS $$
DECLARE
    profile user_profiles;
BEGIN
    -- Try to get existing profile
    SELECT * INTO profile FROM user_profiles WHERE user_id = p_user_id;
    
    -- If not found, create one
    IF NOT FOUND THEN
        INSERT INTO user_profiles (user_id)
        VALUES (p_user_id)
        RETURNING * INTO profile;
    END IF;
    
    RETURN profile;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_or_create_user_profile(UUID) TO authenticated;

COMMENT ON TABLE user_profiles IS 'Stores user personalization settings and golf preferences';
COMMENT ON TABLE user_app_settings IS 'Stores user app preferences for notifications, display, etc.';
COMMENT ON TABLE issue_reports IS 'Stores user-submitted issue reports for tracking and resolution';
