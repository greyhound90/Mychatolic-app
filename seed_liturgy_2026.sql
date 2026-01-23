-- Seeding Liturgy Data for Jan 25, 2026 - Feb 01, 2026
-- Cycle: Year B (Sundays), Year II (Weekdays)
-- Note: Logic adheres to USER Request (Year B/Cycle II) overriding 2026 Standard (Year A) if applicable.

-- 1. Clean existing data to avoid duplicates
DELETE FROM daily_liturgy 
WHERE date BETWEEN '2026-01-25' AND '2026-02-01';

-- 2. Insert Data
INSERT INTO daily_liturgy (date, color, feast_name, readings) VALUES
(
    '2026-01-25',
    'green',
    'HARI MINGGU BIASA III',
    '{
        "bacaan1": "Yun 3:1-5,10",
        "mazmur": "Mzm 25:4-5,6-7,8-9",
        "bacaan2": "1 Kor 7:29-31",
        "injil": "Mrk 1:14-20"
    }'::jsonb
),
(
    '2026-01-26',
    'white',
    'Pw. S. Timotius dan Titus, Uskup',
    '{
        "bacaan1": "2 Tim 1:1-8",
        "mazmur": "Mzm 96:1-3,7-8,10",
        "injil": "Luk 10:1-9"
    }'::jsonb
),
(
    '2026-01-27',
    'green',
    'Hari Biasa',
    '{
        "bacaan1": "2 Sam 6:12-15,17-19",
        "mazmur": "Mzm 24:7-10",
        "injil": "Mrk 3:31-35"
    }'::jsonb
),
(
    '2026-01-28',
    'white',
    'Pw. S. Thomas Aquinas, Imam dan Pujangga Gereja',
    '{
        "bacaan1": "2 Sam 7:4-17",
        "mazmur": "Mzm 89:4-5,27-30",
        "injil": "Mrk 4:1-20"
    }'::jsonb
),
(
    '2026-01-29',
    'green',
    'Hari Biasa',
    '{
        "bacaan1": "2 Sam 7:18-19,24-29",
        "mazmur": "Mzm 132:1-5,11-14",
        "injil": "Mrk 4:21-25"
    }'::jsonb
),
(
    '2026-01-30',
    'green',
    'Hari Biasa',
    '{
        "bacaan1": "2 Sam 11:1-4,5-10,13-17",
        "mazmur": "Mzm 51:3-7,10-11",
        "injil": "Mrk 4:26-34"
    }'::jsonb
),
(
    '2026-01-31',
    'white',
    'Pw. S. Yohanes Bosco, Imam',
    '{
        "bacaan1": "2 Sam 12:1-7,10-17",
        "mazmur": "Mzm 51:12-17",
        "injil": "Mrk 4:35-41"
    }'::jsonb
),
(
    '2026-02-01',
    'green',
    'HARI MINGGU BIASA IV',
    '{
        "bacaan1": "Ul 18:15-20",
        "mazmur": "Mzm 95:1-2,6-9",
        "bacaan2": "1 Kor 7:32-35",
        "injil": "Mrk 1:21-28"
    }'::jsonb
);
