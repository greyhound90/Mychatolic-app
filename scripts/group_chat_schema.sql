-- 1. Modify social_chats table to support groups
ALTER TABLE social_chats
ADD COLUMN is_group BOOLEAN DEFAULT FALSE,
ADD COLUMN group_name TEXT,
ADD COLUMN group_avatar_url TEXT,
ADD COLUMN admin_id UUID REFERENCES auth.users(id);

-- 2. Create chat_participants table (Pivot)
CREATE TABLE chat_participants (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  chat_id UUID REFERENCES social_chats(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(chat_id, user_id)
);

-- Optional: Index for performance
CREATE INDEX idx_chat_participants_user ON chat_participants(user_id);
CREATE INDEX idx_chat_participants_chat ON chat_participants(chat_id);

-- NOTE FOR DEVELOPER:
-- Even with chat_participants table, please CONTINUE to maintain the 'participants' array column 
-- in 'social_chats' table to ensure high performance for the Inbox Query (ChatPage).
-- The array column acts as a cache for "Who is in this chat".
