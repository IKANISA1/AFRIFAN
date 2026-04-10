-- ==========================================================================
-- AfriClub — Shop Products & News Articles (image-first, no emoji)
-- ==========================================================================
-- Creates the shop products table and news articles table with proper
-- image_url columns for AI-generated, team-branded product photography.
-- Also creates the Supabase Storage bucket for generated images.
-- ==========================================================================

-- ── Shop Products Table ──
create table if not exists public.rs_shop_products (
  id                uuid primary key default gen_random_uuid(),
  club_id           bigint references public.african_football_clubs(id),

  -- Product identity
  name              text not null,
  subtitle          text,
  category          text not null default 'Kits',
  badge_label       text,            -- "LIMITED EDITION", "NEW ARRIVAL", etc.
  product_id        text,            -- Numeric alias for display (e.g. "882-041")

  -- Pricing
  price             numeric(10,2) not null default 0,
  currency          text not null default 'USD',

  -- Image (AI-generated, stored in Supabase Storage)
  image_url         text,            -- Public URL from product-images bucket
  image_prompt      text,            -- The prompt used to generate the image (for audit)

  -- Product metadata
  product_type      text not null default 'kit',  -- kit, jacket, scarf, ball, guards, accessory
  stock             int not null default 0,
  is_active         boolean not null default true,
  is_new            boolean not null default false,
  sort_order        int not null default 0,

  -- Lifecycle
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index if not exists idx_shop_products_club
  on public.rs_shop_products (club_id);

create index if not exists idx_shop_products_active
  on public.rs_shop_products (is_active)
  where is_active = true;

create index if not exists idx_shop_products_category
  on public.rs_shop_products (category);

comment on table public.rs_shop_products is
  'Club merchandise catalog. Images are AI-generated via the generate-product-image Edge Function using team-specific brand prompts.';

-- ── RLS ──
alter table public.rs_shop_products enable row level security;

create policy "Anyone can read active products"
  on public.rs_shop_products for select
  using (is_active = true);

create policy "Admins can manage products"
  on public.rs_shop_products for all
  using (
    auth.role() = 'authenticated' and
    exists (
      select 1 from auth.users u
      where u.id = auth.uid()
      and (u.raw_user_meta_data ->> 'role')::text = 'admin'
    )
  );


-- ==========================================================================
-- News Articles Table
-- ==========================================================================

create table if not exists public.rs_news_articles (
  id                uuid primary key default gen_random_uuid(),
  club_id           bigint references public.african_football_clubs(id),

  -- Article content
  title             text not null,
  subtitle          text,
  body              text,
  category          text not null default 'News',

  -- Image (AI-generated stadium/action photography)
  image_url         text,
  image_prompt      text,

  -- Publishing
  is_published      boolean not null default false,
  published_at      timestamptz,
  is_featured       boolean not null default false,
  sort_order        int not null default 0,

  -- Lifecycle
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index if not exists idx_news_articles_club
  on public.rs_news_articles (club_id);

create index if not exists idx_news_articles_published
  on public.rs_news_articles (is_published, published_at desc)
  where is_published = true;

comment on table public.rs_news_articles is
  'CMS-driven news/intel articles per club. Header images are AI-generated using team brand context.';

-- ── RLS ──
alter table public.rs_news_articles enable row level security;

create policy "Anyone can read published articles"
  on public.rs_news_articles for select
  using (is_published = true);

create policy "Admins can manage articles"
  on public.rs_news_articles for all
  using (
    auth.role() = 'authenticated' and
    exists (
      select 1 from auth.users u
      where u.id = auth.uid()
      and (u.raw_user_meta_data ->> 'role')::text = 'admin'
    )
  );


-- ==========================================================================
-- Supabase Storage Bucket
-- ==========================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-images',
  'product-images',
  true,
  5242880,  -- 5MB max
  array['image/png', 'image/jpeg', 'image/webp']
)
on conflict (id) do nothing;

-- Public read policy for the bucket
create policy "Public read product images"
  on storage.objects for select
  using (bucket_id = 'product-images');

-- Admin upload policy
create policy "Admin upload product images"
  on storage.objects for insert
  with check (
    bucket_id = 'product-images' and
    auth.role() = 'authenticated'
  );

-- Service role can also upload (for Edge Functions)
create policy "Service role upload product images"
  on storage.objects for insert
  with check (
    bucket_id = 'product-images' and
    auth.role() = 'service_role'
  );


-- ==========================================================================
-- Seed data: Rayon Sports FC pilot shop products (no emoji!)
-- ==========================================================================

-- First, get the Rayon Sports club ID
do $$
declare
  rayon_id bigint;
begin
  select id into rayon_id
  from public.african_football_clubs
  where club_name = 'Rayon Sports FC';

  if rayon_id is null then
    raise notice 'Rayon Sports FC not found in african_football_clubs, skipping seed';
    return;
  end if;

  -- Insert products (image_url will be populated by the generate-product-image Edge Function)
  insert into public.rs_shop_products (
    club_id, name, subtitle, category, badge_label, product_id,
    price, product_type, stock, is_active, is_new, sort_order
  )
  values
    (rayon_id, 'KINETIC HOME ''24', 'Authentic Matchwear', 'Kits', 'LIMITED EDITION', '882-041',
     124.99, 'kit', 50, true, false, 1),

    (rayon_id, 'STEALTH JACKET', 'Performance Shell', 'Outerwear', 'NEW ARRIVAL', '114-003',
     89.00, 'jacket', 30, true, true, 2),

    (rayon_id, 'GOLD CREST SCARF', 'Fan Collectible', 'Accessories', 'HERITAGE', '773-019',
     35.00, 'scarf', 100, true, false, 3),

    (rayon_id, 'OMNI MATCH BALL', 'FIFA Quality Pro Certified', 'Equipment', 'PRO GRADE', '901-238',
     150.00, 'ball', 20, true, false, 4),

    (rayon_id, 'CARBON GUARDS', 'Protection Elite', 'Equipment', 'ULTRA LIGHT', '441-008',
     45.00, 'guards', 40, true, true, 5)

  on conflict do nothing;

  -- Insert news articles
  insert into public.rs_news_articles (
    club_id, title, subtitle, category, is_published, published_at, is_featured, sort_order
  )
  values
    (rayon_id, 'TRANSFER WINDOW: DEFENSIVE REINFORCEMENTS',
     'The club secures two major signings from the West African regional leagues to strengthen the backline ahead of continental competition.',
     'Transfers', true, now() - interval '2 days', true, 1),

    (rayon_id, 'MATCH DAY: STADIUM GUIDE',
     'New protocols for the upcoming season including digital ticketing and enhanced fan experience zones at Kigali Arena.',
     'Match Day', true, now() - interval '5 days', false, 2),

    (rayon_id, 'YOUTH ACADEMY SPOTLIGHT',
     'Three graduates make the first team squad for the continental campaign, showcasing Rayon''s commitment to homegrown talent development.',
     'Academy', true, now() - interval '7 days', false, 3)

  on conflict do nothing;

  raise notice 'Seeded % shop products and 3 news articles for Rayon Sports FC (club_id=%)', 5, rayon_id;
end $$;
