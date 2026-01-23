-- Migration to support Personal Invite in Radars table

DO $$ 
BEGIN
    -- Add 'type' column if not exists (default to 'group' for existing radars)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'radars' AND column_name = 'type') THEN
        ALTER TABLE public.radars ADD COLUMN type text DEFAULT 'group';
    END IF;

    -- Add 'target_user_id' column if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'radars' AND column_name = 'target_user_id') THEN
        ALTER TABLE public.radars ADD COLUMN target_user_id UUID REFERENCES auth.users(id);
    END IF;
    
    -- Add 'location_name' if we just want to store string location instead of church_id (optional, based on request 'Input Lokasi: Dropdown/Search' usually implies string or ID)
    -- User prompt said: "location: Nama gereja yang dipilih".
    -- Existing radars use 'church_id'. We should probably stick to 'church_id' if possible, or add 'location_name'.
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'radars' AND column_name = 'location_name') THEN
         ALTER TABLE public.radars ADD COLUMN location_name text;
    END IF;

END $$;
