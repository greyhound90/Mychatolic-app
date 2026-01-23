-- ==============================================================================
-- MIGRATION: STORIES FEATURE (Instagram Style)
-- ==============================================================================

-- 1. Create stories table
create table if not exists public.stories (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  media_url text not null,
  media_type text check (media_type in ('image', 'video')) not null,
  caption text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  expires_at timestamp with time zone default timezone('utc'::text, now() + interval '24 hours') not null
);

-- Index for fast filtering of active stories
create index if not exists stories_expires_at_idx on public.stories (expires_at);
create index if not exists stories_user_id_idx on public.stories (user_id);

-- 2. Create story_views table
create table if not exists public.story_views (
  story_id uuid references public.stories(id) on delete cascade not null,
  viewer_id uuid references auth.users(id) on delete cascade not null,
  viewed_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (story_id, viewer_id) -- Ensures one view per user per story
);

-- 3. Enable Row Level Security (RLS)
alter table public.stories enable row level security;
alter table public.story_views enable row level security;

-- ==============================================================================
-- POLICIES: STORIES
-- ==============================================================================

-- Policy: Public (Authenticated) can view Active Stories only
create policy "Authenticated users can view active stories"
  on public.stories for select
  to authenticated
  using (expires_at > now());

-- Policy: Users can insert their own stories
create policy "Users can insert their own stories"
  on public.stories for insert
  to authenticated
  with check (auth.uid() = user_id);

-- Policy: Users can delete their own stories
create policy "Users can delete their own stories"
  on public.stories for delete
  to authenticated
  using (auth.uid() = user_id);

-- ==============================================================================
-- POLICIES: STORY VIEWS
-- ==============================================================================

-- Policy: Users can insert their own view (mark as seen)
create policy "Users can insert their own views"
  on public.story_views for insert
  to authenticated
  with check (auth.uid() = viewer_id);

-- Policy: Story owner can see who viewed their story
create policy "Story owners can see views"
  on public.story_views for select
  to authenticated
  using (
    exists (
      select 1 from public.stories s
      where s.id = story_views.story_id
      and s.user_id = auth.uid()
    )
  );

-- Policy: Viewer can see their own view record (optional, useful for client checks)
create policy "Users can see their own view records"
  on public.story_views for select
  to authenticated
  using (auth.uid() = viewer_id);
