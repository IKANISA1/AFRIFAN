-- Add distribution column to CMS tables to support unified Web + App operations
ALTER TABLE public.home_banners ADD COLUMN IF NOT EXISTS distribution text DEFAULT 'both' CHECK (distribution IN ('web', 'app', 'both'));
ALTER TABLE public.ai_content ADD COLUMN IF NOT EXISTS distribution text DEFAULT 'both' CHECK (distribution IN ('web', 'app', 'both'));

COMMENT ON COLUMN public.home_banners.distribution IS 'Target platform for the banner: web, app, or both.';
COMMENT ON COLUMN public.ai_content.distribution IS 'Target platform for the content block: web, app, or both.';
