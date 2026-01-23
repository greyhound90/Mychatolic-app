-- 1. Create table 'follows'
create table public.follows (
  follower_id uuid references auth.users not null,
  following_id uuid references auth.users not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (follower_id, following_id)
);

-- 2. Enable Row Level Security (RLS)
alter table public.follows enable row level security;

-- 3. Create Policies

-- Allow anyone to read follows (to count followers/following)
create policy "Anyone can read follows"
  on public.follows for select
  using ( true );

-- Allow authenticated users to insert their own follow (follow someone)
create policy "Users can follow others"
  on public.follows for insert
  with check ( auth.uid() = follower_id );

-- Allow authenticated users to delete their own follow (unfollow)
create policy "Users can unfollow"
  on public.follows for delete
  using ( auth.uid() = follower_id );

-- 4. Optional: Setup Realtime for this table
alter publication supabase_realtime add table public.follows;
