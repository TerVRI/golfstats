-- Add admin role to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS admin_granted_at TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS admin_granted_by UUID REFERENCES auth.users(id);

-- Create index for admin lookups
CREATE INDEX IF NOT EXISTS idx_profiles_is_admin ON profiles(is_admin) WHERE is_admin = TRUE;

-- Function to check if current user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = auth.uid() 
        AND is_admin = TRUE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if a specific user is admin
CREATE OR REPLACE FUNCTION is_user_admin(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = p_user_id 
        AND is_admin = TRUE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant admin role to a user (only admins can do this)
CREATE OR REPLACE FUNCTION grant_admin(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    -- Check if caller is admin
    IF NOT is_admin() THEN
        RAISE EXCEPTION 'Only admins can grant admin privileges';
    END IF;
    
    UPDATE profiles 
    SET is_admin = TRUE,
        admin_granted_at = NOW(),
        admin_granted_by = auth.uid()
    WHERE id = p_user_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Revoke admin role from a user
CREATE OR REPLACE FUNCTION revoke_admin(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    -- Check if caller is admin
    IF NOT is_admin() THEN
        RAISE EXCEPTION 'Only admins can revoke admin privileges';
    END IF;
    
    -- Prevent revoking own admin
    IF p_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Cannot revoke your own admin privileges';
    END IF;
    
    UPDATE profiles 
    SET is_admin = FALSE,
        admin_granted_at = NULL,
        admin_granted_by = NULL
    WHERE id = p_user_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION is_user_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION grant_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION revoke_admin(UUID) TO authenticated;

-- Admin stats view (for dashboard)
CREATE OR REPLACE VIEW admin_stats AS
SELECT
    (SELECT COUNT(*) FROM profiles) as total_users,
    (SELECT COUNT(*) FROM profiles WHERE created_at > NOW() - INTERVAL '7 days') as new_users_7d,
    (SELECT COUNT(*) FROM profiles WHERE created_at > NOW() - INTERVAL '30 days') as new_users_30d,
    (SELECT COUNT(*) FROM rounds) as total_rounds,
    (SELECT COUNT(*) FROM rounds WHERE created_at > NOW() - INTERVAL '7 days') as new_rounds_7d,
    (SELECT COUNT(*) FROM courses) as total_courses,
    (SELECT COUNT(*) FROM subscriptions WHERE status IN ('active', 'trialing')) as active_subscriptions,
    (SELECT COUNT(*) FROM subscriptions WHERE source = 'apple' AND status IN ('active', 'trialing')) as apple_subscriptions,
    (SELECT COUNT(*) FROM subscriptions WHERE source = 'stripe' AND status IN ('active', 'trialing')) as stripe_subscriptions;

-- Grant access to admin stats only for admins
CREATE POLICY "Only admins can view admin stats"
    ON profiles FOR SELECT
    USING (is_admin() OR id = auth.uid());

COMMENT ON FUNCTION is_admin IS 'Check if current user has admin role';
COMMENT ON FUNCTION grant_admin IS 'Grant admin privileges to a user (admin only)';
COMMENT ON FUNCTION revoke_admin IS 'Revoke admin privileges from a user (admin only)';
