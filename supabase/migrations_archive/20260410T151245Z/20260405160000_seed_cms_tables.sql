-- ============================================================================
-- Seed CMS tables: home_banners, ai_content, app_config
-- Migrates all hardcoded content from content.ts into the database.
-- ============================================================================

-- ─── Home Banners (hero quick links) ─────────────────────────────────────────

INSERT INTO public.home_banners (title, subtitle, badge_label, cta_label, route, sort_order, is_active)
VALUES
  ('Buy tickets',     'Get matchday entry',              'NEW',   'Buy tickets',      '/tickets',    1, true),
  ('Support Groups', 'Pool funds for tifos and travel',  NULL,    'Support Groups',  '/Groups',    2, true),
  ('Membership',      'Fan, Bronze, Gold, Platinum',     NULL,    'Membership tiers',  '/membership', 3, true),
  ('Club news',       'Latest stories and press',        NULL,    'Latest club news',  '/news',       4, true),
  ('Shop',            'New season gear and kits',        'DROP',  'Shop new drop',     '/shop',       5, true)
ON CONFLICT DO NOTHING;

-- ─── AI Content: Hero headline ───────────────────────────────────────────────

INSERT INTO public.ai_content (content_type, title, subtitle, body, sort_order, is_active, status)
VALUES
  (
    'hero_headline',
    'This is Gikundiro.',
    'The Beloved, live in the browser',
    'Get tickets, follow live matches, back supporter Groups, and join the Rayon Sports family — all from your browser.',
    1, true, 'approved'
  )
ON CONFLICT DO NOTHING;

-- ─── AI Content: Club history moments ────────────────────────────────────────

INSERT INTO public.ai_content (content_type, title, subtitle, body, sort_order, is_active, status)
VALUES
  (
    'club_history',
    'The beloved identity',
    'Club name origin',
    'Gikundiro means "the beloved" in Kinyarwanda. The name carries the weight of a supporter culture built on loyalty, matchday ritual, and collective identity. It is not a slogan — it is the relationship between club and community.',
    1, true, 'approved'
  ),
  (
    'club_history',
    'Matchday at scale',
    'Digital presence',
    'The website anchors matchday: live scores, lineup drops, and ticketing in real time. It extends the stadium experience beyond seats, connecting the diaspora and local supporters on one platform.',
    2, true, 'approved'
  ),
  (
    'club_history',
    'One supporter account',
    'Unified identity',
    'The web and mobile products share a single supporter account — membership, FET, ticket history, and contribution records follow the user across devices. The web is not a secondary product.',
    3, true, 'approved'
  )
ON CONFLICT DO NOTHING;

-- ─── AI Content: Privacy policy ──────────────────────────────────────────────

INSERT INTO public.ai_content (content_type, title, subtitle, body, sort_order, is_active, status)
VALUES
  (
    'privacy_policy',
    'Supporter data with clear boundaries.',
    'Privacy',
    'The Gikundiro web experience stores only the minimum supporter data required to run portal services such as membership, tickets, shop orders, and support Groups. Sensitive payment and private contact details remain segmented from public profile data.

We do not sell or share supporter data with third parties. Authentication is handled via Supabase Auth with industry-standard encryption. Session tokens are stored locally and expire after inactivity.

For data deletion requests or privacy inquiries, contact the club through official channels listed on the contact page.',
    1, true, 'approved'
  )
ON CONFLICT DO NOTHING;

-- ─── AI Content: Terms and conditions ────────────────────────────────────────

INSERT INTO public.ai_content (content_type, title, subtitle, body, sort_order, is_active, status)
VALUES
  (
    'terms',
    'One supporter platform across web and portal.',
    'Terms',
    'Ticketing, shop orders, memberships, and contribution records created through the website are part of the same Rayon Sports supporter platform used by the mobile app. Availability, pricing, and supporter eligibility remain subject to club policy and live operational status.

Tickets are non-transferable unless explicitly enabled by the club for specific fixtures. Refund policies follow the club''s published matchday guidelines. Membership benefits are tied to the active subscription period.

By using this platform, you agree to the club''s supporter code of conduct and community guidelines.',
    1, true, 'approved'
  )
ON CONFLICT DO NOTHING;

-- ─── AI Content: Contact / digital support ───────────────────────────────────

INSERT INTO public.ai_content (content_type, title, subtitle, body, sort_order, is_active, status)
VALUES
  (
    'contact_support',
    'Fan portal support',
    'Digital support',
    'Membership, tickets, and orders stay in the portal for authenticated follow-up.',
    1, true, 'approved'
  ),
  (
    'contact_support',
    'Public enquiries',
    'Club communication',
    'Public contact stays focused on club communication, media, and general supporter questions.',
    2, true, 'approved'
  )
ON CONFLICT DO NOTHING;

-- ─── AI Content: BioPay information ──────────────────────────────────────────

INSERT INTO public.ai_content (content_type, title, subtitle, body, sort_order, is_active, status)
VALUES
  (
    'BioPay_info',
    'Pay without reaching for your wallet.',
    'About BioPay',
    'BioPay links your supporter identity to biometric and contactless payment. Enrol in the native app, then pay at gates and vendor stalls with a glance or tap.',
    1, true, 'approved'
  )
ON CONFLICT DO NOTHING;

-- ─── App Config: Feature flags and settings ──────────────────────────────────

INSERT INTO public.app_config (key, value, description, country)
VALUES
  ('BioPay_face_enabled',   'false', 'Whether BioPay Face Scan is available on web', NULL),
  ('BioPay_nfc_enabled',    'false', 'Whether BioPay NFC Tap is available on web',   NULL),
  ('BioPay_qr_enabled',     'true',  'Whether BioPay QR code is available on web',   NULL),
  ('BioPay_scan_enabled',   'true',  'Whether BioPay Scan QR is available on web',   NULL),
  ('install_prompt_delay',  '45',    'Seconds before showing PWA install prompt',    NULL),
  ('default_currency',      'RWF',   'Default currency for pricing display',         'RW'),
  ('club_short_name',       'Rayon', 'Short display name for the club',              NULL),
  ('support_email',         'support@rayonsports.rw', 'Club support email address',  NULL)
ON CONFLICT (key) DO NOTHING;
