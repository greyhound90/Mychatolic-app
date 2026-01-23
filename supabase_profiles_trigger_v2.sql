-- TRIGGER FUNCTION TO COPY METADATA TO PUBLIC.PROFILES
-- Run this in Supabase SQL Editor to fix "missing data" on sign up.

-- 1. Create or Replace the Function
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (
    id,
    email,
    full_name,
    role,
    is_approved,
    ethnicity,
    jenis_kelamin,
    parish,
    diocese,
    country,
    avatar_url
  )
  values (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    coalesce(new.raw_user_meta_data->>'role', 'umat'),
    false, -- Default is_approved
    new.raw_user_meta_data->>'suku',
    new.raw_user_meta_data->>'jenis_kelamin',
    new.raw_user_meta_data->>'parish_name', -- Mapped from metadata
    new.raw_user_meta_data->>'diocese_name',
    new.raw_user_meta_data->>'country_name',
    new.raw_user_meta_data->>'verification_doc_url' -- Optional init avatar? Or leave null
  );
  return new;
end;
$$ language plpgsql security definer;

-- 2. Bind the Trigger (Drop first to be safe)
drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 3. VERIFY
-- Try signing up a new user from the App.
-- Check 'profiles' table.
