-- Fix Rayon Sports colors: brand is Blue & White, not Red.
-- White is dropped per DESIGN.md UI token rule.
-- Secondary uses a deep blue variant instead of white.

UPDATE african_football_clubs SET
  primary_color_hex   = '#0038A8',
  secondary_color_hex = '#001F5C',
  accent_color_hex    = '#D4A017',
  updated_at = now()
WHERE club_slug = 'rayon_sports_rw';
