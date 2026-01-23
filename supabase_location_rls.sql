-- ENABLE PUBLIC READ ACCESS FOR LOCATION TABLES
-- Run this in Supabase SQL Editor

-- 1. COUNTRIES table
ALTER TABLE countries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can read countries"
ON countries
FOR SELECT
TO public
USING (true);

-- 2. DIOCESES table
ALTER TABLE dioceses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can read dioceses"
ON dioceses
FOR SELECT
TO public
USING (true);

-- 3. CHURCHES table
ALTER TABLE churches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can read churches"
ON churches
FOR SELECT
TO public
USING (true);

-- OPTIONAL: Verify data exists
-- SELECT count(*) FROM countries;
-- SELECT count(*) FROM dioceses;
-- SELECT count(*) FROM churches;
