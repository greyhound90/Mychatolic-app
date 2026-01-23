-- ==============================================================================
-- FIX RLS POLICIES FOR POSTS & LIKES
-- ==============================================================================
-- Description: Unblocks access to 'posts' and 'post_likes' tables.
--              Currently likely blocked by "Deny All" default RLS behavior.

-- ------------------------------------------------------------------------------
-- 1. POSTS TABLE
-- ------------------------------------------------------------------------------
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

-- ALLOW READ: Everyone (Public + Authenticated) can see all posts
DROP POLICY IF EXISTS "Anyone can view posts" ON public.posts;
CREATE POLICY "Anyone can view posts"
ON public.posts FOR SELECT
USING (true);

-- ALLOW INSERT: Authenticated users can create posts as themselves
DROP POLICY IF EXISTS "Users can insert own posts" ON public.posts;
CREATE POLICY "Users can insert own posts"
ON public.posts FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- ALLOW UPDATE: Only the author
DROP POLICY IF EXISTS "Users can update own posts" ON public.posts;
CREATE POLICY "Users can update own posts"
ON public.posts FOR UPDATE
USING (auth.uid() = user_id);

-- ALLOW DELETE: Only the author
DROP POLICY IF EXISTS "Users can delete own posts" ON public.posts;
CREATE POLICY "Users can delete own posts"
ON public.posts FOR DELETE
USING (auth.uid() = user_id);


-- ------------------------------------------------------------------------------
-- 2. POST_LIKES TABLE (Fixes 'permission denied for table post_likes')
-- ------------------------------------------------------------------------------
-- Ensure table exists first (just in case)
CREATE TABLE IF NOT EXISTS public.post_likes (
    post_id BIGINT REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (post_id, user_id)
);

ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;

-- ALLOW READ: Everyone
DROP POLICY IF EXISTS "Anyone can view likes" ON public.post_likes;
CREATE POLICY "Anyone can view likes"
ON public.post_likes FOR SELECT
USING (true);

-- ALLOW INSERT/DELETE: Toggle Like (Self only)
DROP POLICY IF EXISTS "Users can like posts" ON public.post_likes;
CREATE POLICY "Users can like posts"
ON public.post_likes FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can unlike posts" ON public.post_likes;
CREATE POLICY "Users can unlike posts"
ON public.post_likes FOR DELETE
USING (auth.uid() = user_id);

-- ==============================================================================
-- 3. TEXT_POSTS (If you use separate table for text, though we unified them)
--    Just in case, safeguard it too.
-- ==============================================================================
ALTER TABLE IF EXISTS public.text_posts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view text_posts" ON public.text_posts;
CREATE POLICY "Anyone can view text_posts" 
ON public.text_posts FOR SELECT USING (true);
