-- ===========================================
-- SUBSCRIPTION MANAGEMENT FOR ROUNDCADDY
-- ===========================================
-- This migration adds server-side subscription tracking
-- Date: 2026-01-23

-- 1. USER SUBSCRIPTIONS TABLE
CREATE TABLE IF NOT EXISTS public.user_subscriptions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
    
    -- Subscription status
    status TEXT NOT NULL DEFAULT 'free' CHECK (status IN ('free', 'trial', 'pro', 'cancelled', 'expired')),
    
    -- Plan details
    plan_type TEXT CHECK (plan_type IN ('monthly', 'annual', 'lifetime', 'developer')),
    
    -- Dates
    trial_started_at TIMESTAMPTZ,
    trial_ends_at TIMESTAMPTZ,
    subscription_started_at TIMESTAMPTZ,
    subscription_ends_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    
    -- App Store / Play Store tracking
    store_transaction_id TEXT,
    store_product_id TEXT,
    store_platform TEXT CHECK (store_platform IN ('ios', 'android', 'web')),
    
    -- Developer/test accounts
    is_developer_account BOOLEAN DEFAULT FALSE,
    developer_granted_by UUID REFERENCES public.profiles(id),
    developer_granted_at TIMESTAMPTZ,
    developer_notes TEXT,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. INDEXES
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_id ON public.user_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_status ON public.user_subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_ends_at ON public.user_subscriptions(subscription_ends_at) WHERE status = 'pro';

-- 3. ROW LEVEL SECURITY
ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;

-- Users can read their own subscription
CREATE POLICY "Users can read own subscription"
    ON public.user_subscriptions
    FOR SELECT
    USING (auth.uid() = user_id);

-- Only service role can modify subscriptions (for webhook processing)
CREATE POLICY "Service role can manage subscriptions"
    ON public.user_subscriptions
    FOR ALL
    USING (auth.role() = 'service_role');

-- 4. UPDATE TRIGGER
CREATE OR REPLACE FUNCTION update_user_subscriptions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_user_subscriptions_updated_at
    BEFORE UPDATE ON public.user_subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_user_subscriptions_updated_at();

-- 5. FUNCTION TO CHECK PRO STATUS
CREATE OR REPLACE FUNCTION public.has_pro_access(check_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    sub_record RECORD;
BEGIN
    SELECT * INTO sub_record
    FROM public.user_subscriptions
    WHERE user_id = check_user_id;
    
    -- No subscription record = free user
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Developer accounts always have access
    IF sub_record.is_developer_account THEN
        RETURN TRUE;
    END IF;
    
    -- Check if pro and not expired
    IF sub_record.status = 'pro' AND (sub_record.subscription_ends_at IS NULL OR sub_record.subscription_ends_at > NOW()) THEN
        RETURN TRUE;
    END IF;
    
    -- Check if trial is active
    IF sub_record.status = 'trial' AND sub_record.trial_ends_at > NOW() THEN
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. GRANT DEVELOPER ACCESS FUNCTION (for admins)
CREATE OR REPLACE FUNCTION public.grant_developer_access(
    target_email TEXT,
    granted_by_id UUID,
    notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    target_user_id UUID;
BEGIN
    -- Find user by email
    SELECT id INTO target_user_id
    FROM public.profiles
    WHERE email = target_email;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User with email % not found', target_email;
    END IF;
    
    -- Upsert subscription record
    INSERT INTO public.user_subscriptions (
        user_id,
        status,
        plan_type,
        is_developer_account,
        developer_granted_by,
        developer_granted_at,
        developer_notes
    ) VALUES (
        target_user_id,
        'pro',
        'developer',
        TRUE,
        granted_by_id,
        NOW(),
        notes
    )
    ON CONFLICT (user_id) DO UPDATE SET
        status = 'pro',
        plan_type = 'developer',
        is_developer_account = TRUE,
        developer_granted_by = granted_by_id,
        developer_granted_at = NOW(),
        developer_notes = COALESCE(notes, user_subscriptions.developer_notes),
        updated_at = NOW();
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. GRANT DEVELOPER ACCESS TO TERRY (run this after migration)
-- This will be executed separately since profiles table might not have the user yet
-- SELECT public.grant_developer_access('terry@vrim.ie', NULL, 'App developer - permanent pro access');

COMMENT ON TABLE public.user_subscriptions IS 'Tracks user subscription status for RoundCaddy Pro features';
COMMENT ON COLUMN public.user_subscriptions.is_developer_account IS 'Developer/tester accounts with permanent pro access';
