-- ============================================
-- CREATE ROUNDCADDY USER FOR OSM IMPORTS
-- ============================================
-- Run this in Supabase SQL Editor before running the import script
-- This creates a special user "RoundCaddy" who will be credited
-- as the contributor for all OpenStreetMap course imports

-- Create auth user (if it doesn't exist)
INSERT INTO auth.users (
  id,
  instance_id,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data,
  is_super_admin,
  role
)
SELECT 
  gen_random_uuid(),
  '00000000-0000-0000-0000-000000000000',
  'roundcaddy@roundcaddy.com',
  crypt('temp-password-' || gen_random_uuid()::text, gen_salt('bf')),
  NOW(),
  NOW(),
  NOW(),
  '{"provider":"email","providers":["email"]}',
  '{"name":"RoundCaddy"}',
  false,
  'authenticated'
WHERE NOT EXISTS (
  SELECT 1 FROM auth.users WHERE email = 'roundcaddy@roundcaddy.com'
)
RETURNING id;

-- Create profile for RoundCaddy
INSERT INTO public.profiles (id, email, name)
SELECT 
  id,
  email,
  'RoundCaddy'
FROM auth.users
WHERE email = 'roundcaddy@roundcaddy.com'
ON CONFLICT (id) DO NOTHING;

-- Verify the user was created
SELECT id, email, name 
FROM public.profiles 
WHERE email = 'roundcaddy@roundcaddy.com';

-- If the user already exists, you'll see their info above
-- You can use this ID in the import script if needed
