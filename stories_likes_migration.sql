-- ==============================================================================
-- MIGRATION: STORY LIKES
-- ==============================================================================

-- 1. Create story_likes table
create table if not exists public.story_likes (
  story_id uuid references public.stories(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (story_id, user_id)
);

-- 2. Enable RLS
alter table public.story_likes enable row level security;

-- 3. Policies
-- Insert: Users can like stories
create policy "Users can insert their own likes"
  on public.story_likes for insert
  to authenticated
  with check (auth.uid() = user_id);

-- Delete: Users can unlike
create policy "Users can delete their own likes"
  on public.story_likes for delete
  to authenticated
  using (auth.uid() = user_id);

-- Select: Everyone can see likes (needed to count or check status)
create policy "Users can view likes"
  on public.story_likes for select
  to authenticated
  using (true);
