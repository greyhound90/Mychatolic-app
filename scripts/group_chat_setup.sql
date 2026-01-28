-- 1. Modify social_chats table to support groups
ALTER TABLE social_chats
ADD COLUMN IF NOT EXISTS is_group BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS group_name TEXT,
ADD COLUMN IF NOT EXISTS group_avatar_url TEXT,
ADD COLUMN IF NOT EXISTS admin_id UUID REFERENCES public.profiles(id);

-- 2. Create chat_members pivot table
CREATE TABLE IF NOT EXISTS chat_members (
  chat_id UUID REFERENCES social_chats(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (chat_id, user_id)
);

-- 3. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_chat_members_user ON chat_members(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_members_chat ON chat_members(chat_id);

-- Optional: RLS Policy example (if RLS is enabled)
-- ALTER TABLE chat_members ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Members can view their chats" ON chat_members FOR SELECT USING (auth.uid() = user_id);
