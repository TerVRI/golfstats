-- Subscriptions table for tracking both Apple IAP and Stripe web subscriptions
-- This enables the dual-payment model where users can pay via iOS or web

-- Create enum for subscription sources (if not exists)
DO $$ BEGIN
    CREATE TYPE subscription_source AS ENUM ('apple', 'stripe', 'promo');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Create enum for subscription status (if not exists)
DO $$ BEGIN
    CREATE TYPE subscription_status AS ENUM ('active', 'trialing', 'past_due', 'cancelled', 'expired');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Create enum for plan types (if not exists)
DO $$ BEGIN
    CREATE TYPE subscription_plan AS ENUM ('monthly', 'annual');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Main subscriptions table
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Subscription details
    source subscription_source NOT NULL,
    plan subscription_plan NOT NULL,
    status subscription_status NOT NULL DEFAULT 'active',
    
    -- Pricing (in cents)
    price_cents INTEGER,
    currency TEXT DEFAULT 'USD',
    
    -- Important dates
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    current_period_start TIMESTAMPTZ,
    current_period_end TIMESTAMPTZ,
    trial_end TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    
    -- External references
    apple_transaction_id TEXT,
    apple_original_transaction_id TEXT,
    stripe_subscription_id TEXT UNIQUE,
    stripe_customer_id TEXT,
    
    -- Metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Ensure one active subscription per user per source
    CONSTRAINT unique_active_subscription UNIQUE (user_id, source)
);

-- Create index for fast user lookups
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_stripe_id ON subscriptions(stripe_subscription_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_apple_id ON subscriptions(apple_original_transaction_id);

-- Drop existing functions if they exist (to handle parameter name changes)
DROP FUNCTION IF EXISTS has_pro_access(UUID);
DROP FUNCTION IF EXISTS get_subscription_status(UUID);

-- Function to check if user has pro access (from ANY source)
CREATE OR REPLACE FUNCTION has_pro_access(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM subscriptions 
        WHERE user_id = p_user_id 
        AND status IN ('active', 'trialing')
        AND (current_period_end IS NULL OR current_period_end > NOW())
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's active subscription details
CREATE OR REPLACE FUNCTION get_subscription_status(p_user_id UUID)
RETURNS TABLE (
    has_pro BOOLEAN,
    source subscription_source,
    plan subscription_plan,
    status subscription_status,
    expires_at TIMESTAMPTZ,
    is_trial BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        TRUE as has_pro,
        s.source,
        s.plan,
        s.status,
        s.current_period_end as expires_at,
        (s.status = 'trialing') as is_trial
    FROM subscriptions s
    WHERE s.user_id = p_user_id 
    AND s.status IN ('active', 'trialing')
    AND (s.current_period_end IS NULL OR s.current_period_end > NOW())
    ORDER BY s.created_at DESC
    LIMIT 1;
    
    -- If no rows returned, return default "no subscription" row
    IF NOT FOUND THEN
        RETURN QUERY SELECT 
            FALSE as has_pro,
            NULL::subscription_source,
            NULL::subscription_plan,
            NULL::subscription_status,
            NULL::TIMESTAMPTZ,
            FALSE as is_trial;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_subscription_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS subscriptions_updated_at ON subscriptions;
CREATE TRIGGER subscriptions_updated_at
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_subscription_timestamp();

-- Row Level Security
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own subscriptions" ON subscriptions;
DROP POLICY IF EXISTS "Service role can manage subscriptions" ON subscriptions;

-- Users can read their own subscriptions
CREATE POLICY "Users can view own subscriptions"
    ON subscriptions FOR SELECT
    USING (auth.uid() = user_id);

-- Only service role can insert/update (via webhooks)
CREATE POLICY "Service role can manage subscriptions"
    ON subscriptions FOR ALL
    USING (auth.jwt()->>'role' = 'service_role');

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION has_pro_access(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_subscription_status(UUID) TO authenticated;

-- Add subscription_tier to profiles if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'subscription_tier'
    ) THEN
        ALTER TABLE profiles ADD COLUMN subscription_tier TEXT DEFAULT 'free';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' AND column_name = 'stripe_customer_id'
    ) THEN
        ALTER TABLE profiles ADD COLUMN stripe_customer_id TEXT;
    END IF;
END $$;

-- Index for Stripe customer lookup
CREATE INDEX IF NOT EXISTS idx_profiles_stripe_customer ON profiles(stripe_customer_id) WHERE stripe_customer_id IS NOT NULL;

COMMENT ON TABLE subscriptions IS 'Tracks user subscriptions from Apple IAP and Stripe web payments';
COMMENT ON FUNCTION has_pro_access IS 'Returns true if user has any active pro subscription';
COMMENT ON FUNCTION get_subscription_status IS 'Returns detailed subscription status for a user';
