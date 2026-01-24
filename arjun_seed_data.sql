-- INSTRUKSI:
-- 1. Buka Supabase Dashboard > SQL Editor.
-- 2. Ganti 'YOUR_USER_ID_HERE' dengan UUID user Anda (bisa dilihat di menu Authentication > Users).
-- 3. Jalankan script ini.

-- 1. UPDATE PROFILE
UPDATE public.profiles
SET 
  full_name = 'Arjun Sltohang',
  bio = 'Biografi',
  avatar_url = 'https://images.unsplash.com/photo-1542909168-82c3e7fdca5c?q=80&w=300&auto=format&fit=crop',
  user_role = 'umat',
  account_status = 'verified_catholic',
  parish = 'Paroki Hayam Wuruk',
  diocese = 'Keuskupan Agung Medan',
  country = 'Indonesia',
  followers_count = 10000,
  following_count = 60000
WHERE id = 'YOUR_USER_ID_HERE'; 

-- 2. INSERT POSTS (Contoh 6 Postingan)
INSERT INTO public.posts (user_id, caption, image_url, likes_count, comments_count, created_at)
VALUES 
('YOUR_USER_ID_HERE', 'Weekly vibe', ARRAY['https://images.unsplash.com/photo-1493612276216-9c59019558f3?q=80&w=800&auto=format&fit=crop'], 50, 5, NOW() - INTERVAL '1 day'),
('YOUR_USER_ID_HERE', 'Momen indah', ARRAY['https://images.unsplash.com/photo-1543791959-8b61074e8979?q=80&w=801&auto=format&fit=crop'], 52, 5, NOW() - INTERVAL '2 days'),
('YOUR_USER_ID_HERE', 'Gereja hari ini', ARRAY['https://images.unsplash.com/photo-1437603568260-1950d3ca6eab?q=80&w=802&auto=format&fit=crop'], 54, 5, NOW() - INTERVAL '3 days'),
('YOUR_USER_ID_HERE', 'Refleksi iman', ARRAY['https://images.unsplash.com/photo-1518621736915-f3b1c41bfd00?q=80&w=803&auto=format&fit=crop'], 56, 5, NOW() - INTERVAL '4 days'),
('YOUR_USER_ID_HERE', 'Pelayanan', ARRAY['https://images.unsplash.com/photo-1543791959-8b61074e8979?q=80&w=804&auto=format&fit=crop'], 58, 5, NOW() - INTERVAL '5 days'),
('YOUR_USER_ID_HERE', 'Komunitas', ARRAY['https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=805&auto=format&fit=crop'], 60, 5, NOW() - INTERVAL '6 days');
