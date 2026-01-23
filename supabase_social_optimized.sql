-- 1. Create Posts Table
create table if not exists public.posts (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  caption text,
  image_url text, -- Stores the single image URL. Use text[] if multiple needed.
  likes_count int default 0,
  comments_count int default 0,
  created_at timestamptz default now()
);

-- Enable RLS for Posts
alter table public.posts enable row level security;

-- Policies for Posts
create policy "Public posts are viewable by everyone." 
  on public.posts for select 
  using (true);

create policy "Users can insert their own posts." 
  on public.posts for insert 
  with check (auth.uid() = user_id);

create policy "Users can delete their own posts." 
  on public.posts for delete 
  using (auth.uid() = user_id);

-- 2. Create Likes Table
create table if not exists public.likes (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  post_id uuid references public.posts on delete cascade not null,
  created_at timestamptz default now(),
  unique(user_id, post_id) -- Prevent double likes
);

-- Enable RLS for Likes
alter table public.likes enable row level security;

-- Policies for Likes
create policy "Public likes are viewable by everyone." 
  on public.likes for select 
  using (true);

create policy "Users can insert their own likes." 
  on public.likes for insert 
  with check (auth.uid() = user_id);

create policy "Users can delete their own likes." 
  on public.likes for delete 
  using (auth.uid() = user_id);

-- 3. Create Comments Table
create table if not exists public.comments (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  post_id uuid references public.posts on delete cascade not null,
  content text not null,
  created_at timestamptz default now()
);

-- Enable RLS for Comments
alter table public.comments enable row level security;

-- Policies for Comments
create policy "Public comments are viewable by everyone." 
  on public.comments for select 
  using (true);

create policy "Users can insert their own comments." 
  on public.comments for insert 
  with check (auth.uid() = user_id);

create policy "Users can delete their own comments." 
  on public.comments for delete 
  using (auth.uid() = user_id);

-- 4. Performance Triggers (Atomic Counters)

-- Trigger Function: Update Post Likes Count
create or replace function update_post_likes_count()
returns trigger as $$
begin
  if (TG_OP = 'INSERT') then
    update public.posts
    set likes_count = likes_count + 1
    where id = new.post_id;
    return new;
  elsif (TG_OP = 'DELETE') then
    update public.posts
    set likes_count = likes_count - 1
    where id = old.post_id;
    return old;
  end if;
  return null;
end;
$$ language plpgsql security definer;

-- Attach Trigger to Likes Table
drop trigger if exists trigger_update_post_likes_count on public.likes;
create trigger trigger_update_post_likes_count
after insert or delete on public.likes
for each row execute function update_post_likes_count();

-- Trigger Function: Update Post Comments Count
create or replace function update_post_comments_count()
returns trigger as $$
begin
  if (TG_OP = 'INSERT') then
    update public.posts
    set comments_count = comments_count + 1
    where id = new.post_id;
    return new;
  elsif (TG_OP = 'DELETE') then
    update public.posts
    set comments_count = comments_count - 1
    where id = old.post_id;
    return old;
  end if;
  return null;
end;
$$ language plpgsql security definer;

-- Attach Trigger to Comments Table
drop trigger if exists trigger_update_post_comments_count on public.comments;
create trigger trigger_update_post_comments_count
after insert or delete on public.comments
for each row execute function update_post_comments_count();

-- 5. Storage Bucket Configuration
insert into storage.buckets (id, name, public)
values ('post_images', 'post_images', true)
on conflict (id) do nothing;

create policy "Authenticated users can upload post images"
on storage.objects for insert
with check (
  bucket_id = 'post_images' and 
  auth.role() = 'authenticated'
);
