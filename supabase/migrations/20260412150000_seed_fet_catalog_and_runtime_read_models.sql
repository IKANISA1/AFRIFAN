-- =============================================================================
-- Canonical Fan Engagement Token catalog seed and public read models.
-- Keeps public.fan_engagement_token_catalog as the single source of truth and
-- exposes runtime-safe RPCs for mobile and web surfaces.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fet_resolve_public_club_id(
  p_club_id bigint DEFAULT NULL::bigint
) RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT COALESCE(
    p_club_id,
    CASE
      WHEN COALESCE(public.requesting_club_id(), '') ~ '^[0-9]+$'
        THEN public.requesting_club_id()::bigint
      ELSE NULL::bigint
    END
  );
$$;

CREATE OR REPLACE FUNCTION public.fet_get_catalog(
  p_club_id bigint DEFAULT NULL::bigint,
  p_include_inactive boolean DEFAULT false
) RETURNS TABLE(
  id uuid,
  club_id bigint,
  code text,
  template_scope text,
  category text,
  item_name text,
  fet_value integer,
  trigger_condition text,
  activation_timing text,
  description text,
  badge_name text,
  implementation_notes text,
  sort_order integer,
  is_active boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_club_id bigint;
BEGIN
  v_club_id := public.fet_resolve_public_club_id(p_club_id);
  IF v_club_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    fet.id,
    fet.club_id,
    fet.code,
    fet.template_scope,
    fet.category,
    fet.item_name,
    fet.fet_value,
    fet.trigger_condition,
    fet.activation_timing,
    fet.description,
    fet.badge_name,
    fet.implementation_notes,
    fet.sort_order,
    fet.is_active
  FROM public.fan_engagement_token_catalog AS fet
  WHERE fet.club_id = v_club_id
    AND (p_include_inactive OR fet.is_active = true)
  ORDER BY fet.sort_order ASC, fet.code ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.fet_get_leaderboard(
  p_club_id bigint DEFAULT NULL::bigint,
  p_limit integer DEFAULT 10
) RETURNS TABLE(
  rank integer,
  user_id uuid,
  supporter_alias text,
  display_name text,
  total_fet integer,
  tier text,
  is_current_user boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_club_id bigint;
  v_limit integer := GREATEST(COALESCE(p_limit, 10), 1);
BEGIN
  v_club_id := public.fet_resolve_public_club_id(p_club_id);
  IF v_club_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH ranked_rows AS (
    SELECT
      ROW_NUMBER() OVER (
        ORDER BY fm.points DESC, fm.joined_at ASC, fm.user_id ASC
      )::integer AS rank,
      fm.user_id,
      COALESCE(
        NULLIF(BTRIM(pr.public_user_id), ''),
        NULLIF(BTRIM(fm.display_name), ''),
        NULLIF(BTRIM(u.public_user_id), ''),
        '000000'
      ) AS supporter_alias,
      COALESCE(
        NULLIF(BTRIM(pr.display_name), ''),
        NULLIF(BTRIM(fm.display_name), ''),
        NULLIF(BTRIM(u.full_name), ''),
        'Supporter'
      ) AS display_name,
      GREATEST(COALESCE(fm.points, 0), 0)::integer AS total_fet,
      COALESCE(
        NULLIF(BTRIM(fm.tier), ''),
        public.resolve_fan_tier(GREATEST(COALESCE(fm.points, 0), 0))
      ) AS tier,
      (fm.user_id = auth.uid()) AS is_current_user
    FROM public.fan_memberships AS fm
    LEFT JOIN public.profiles AS pr
      ON pr.id = fm.user_id
    LEFT JOIN public.users AS u
      ON u.id = fm.user_id
    WHERE fm.club_id = v_club_id
  ),
  top_rows AS (
    SELECT *
    FROM ranked_rows
    ORDER BY rank ASC
    LIMIT v_limit
  ),
  current_row AS (
    SELECT *
    FROM ranked_rows AS ranked_entry
    WHERE ranked_entry.user_id = auth.uid()
      AND NOT EXISTS (
        SELECT 1
        FROM top_rows
        WHERE top_rows.user_id = auth.uid()
      )
  )
  SELECT
    combined.rank,
    combined.user_id,
    combined.supporter_alias,
    combined.display_name,
    combined.total_fet,
    combined.tier,
    combined.is_current_user
  FROM (
    SELECT * FROM top_rows
    UNION ALL
    SELECT * FROM current_row
  ) AS combined
  ORDER BY combined.rank ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fet_resolve_public_club_id(bigint) TO anon;
GRANT EXECUTE ON FUNCTION public.fet_resolve_public_club_id(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fet_resolve_public_club_id(bigint) TO service_role;

GRANT EXECUTE ON FUNCTION public.fet_get_catalog(bigint, boolean) TO anon;
GRANT EXECUTE ON FUNCTION public.fet_get_catalog(bigint, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fet_get_catalog(bigint, boolean) TO service_role;

GRANT EXECUTE ON FUNCTION public.fet_get_leaderboard(bigint, integer) TO anon;
GRANT EXECUTE ON FUNCTION public.fet_get_leaderboard(bigint, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fet_get_leaderboard(bigint, integer) TO service_role;

DO $fet_seed$
DECLARE
  v_rayon_club_id bigint;
BEGIN
  SELECT afc.id
    INTO v_rayon_club_id
  FROM public.african_football_clubs AS afc
  WHERE lower(regexp_replace(COALESCE(afc.club_slug, ''), '[^a-z0-9]+', '', 'g'))
          IN ('rayonsportsrw', 'rayonsports')
     OR lower(regexp_replace(COALESCE(afc.club_name, ''), '[^a-z0-9]+', '', 'g'))
          IN ('rayonsportsfc', 'rayonsports')
  ORDER BY
    CASE WHEN afc.club_slug = 'rayon_sports_rw' THEN 0 ELSE 1 END,
    afc.id ASC
  LIMIT 1;

  IF v_rayon_club_id IS NULL THEN
    RAISE NOTICE 'Skipping FET seed because Rayon Sports could not be resolved.';
    RETURN;
  END IF;

  WITH seed AS (
    SELECT $$[
      {
        "sort_order": 10,
        "code": "G001",
        "template_scope": "generic",
        "category": "Identity & Profile",
        "item_name": "Create Your Fan Profile",
        "fet_value": 100,
        "trigger_condition": "Complete registration.",
        "activation_timing": "Day 0 - onboarding",
        "description": "Complete your name, avatar, favourite player, and fan zone.",
        "badge_name": "👤",
        "implementation_notes": "First touchpoint. Critical for churn prevention."
      },
      {
        "sort_order": 20,
        "code": "G002",
        "template_scope": "club_specific",
        "category": "Identity & Profile",
        "item_name": "Join Fan Club",
        "fet_value": 100,
        "trigger_condition": "Pick a Rayon Squad Era.",
        "activation_timing": "Day 0 - onboarding",
        "description": "Fans align with a Rayon squad era to create sub-community identity.",
        "badge_name": "🏛️",
        "implementation_notes": "Drives nostalgia marketing segmentation."
      },
      {
        "sort_order": 30,
        "code": "G006",
        "template_scope": "club_specific",
        "category": "Match Day",
        "item_name": "Stadium Check-In",
        "fet_value": 100,
        "trigger_condition": "GPS check-in at Amahoro Stadium or an approved away ground.",
        "activation_timing": "Match day",
        "description": "Geofenced check-in within 500m of the stadium.",
        "badge_name": "🏟️",
        "implementation_notes": "Drives physical attendance. Verify with QR at the gate."
      },
      {
        "sort_order": 40,
        "code": "G007",
        "template_scope": "generic",
        "category": "Match Day",
        "item_name": "First 11 In",
        "fet_value": 100,
        "trigger_condition": "Check in before kickoff and be among the first 100 fans.",
        "activation_timing": "Match day - pre-kickoff",
        "description": "Bonus for being among the first 100 fans to check in before kickoff.",
        "badge_name": "🥇",
        "implementation_notes": "Creates urgency to arrive early and helps control stadium flow."
      },
      {
        "sort_order": 50,
        "code": "G010",
        "template_scope": "club_specific",
        "category": "Match Day",
        "item_name": "Away Game Pilgrim",
        "fet_value": 100,
        "trigger_condition": "Check in at an away stadium in Rwanda.",
        "activation_timing": "Away match day",
        "description": "Extra FET for travelling to support Rayon away from Kigali.",
        "badge_name": "🚌",
        "implementation_notes": "Rewards dedication. Coordinate with supporter buses."
      },
      {
        "sort_order": 60,
        "code": "G014",
        "template_scope": "generic",
        "category": "Predictions",
        "item_name": "Match Score Predictor",
        "fet_value": 100,
        "trigger_condition": "Submit a score prediction before kickoff.",
        "activation_timing": "Pre-match, closes at kickoff",
        "description": "Predict the exact score before kickoff.",
        "badge_name": "🎯",
        "implementation_notes": "Daily return driver. 24-hour window before match."
      },
      {
        "sort_order": 70,
        "code": "G015",
        "template_scope": "club_specific",
        "category": "Predictions",
        "item_name": "First Goalscorer Bet",
        "fet_value": 100,
        "trigger_condition": "Predict the first Rayon goalscorer before kickoff.",
        "activation_timing": "Pre-match, closes at kickoff",
        "description": "Predict which Rayon player scores first. Correct picks unlock FET and a player card.",
        "badge_name": "⚽",
        "implementation_notes": "Links to the player card economy."
      },
      {
        "sort_order": 80,
        "code": "G016",
        "template_scope": "generic",
        "category": "Predictions",
        "item_name": "Weekly Predictor Streak",
        "fet_value": 300,
        "trigger_condition": "Get correct predictions for three consecutive weeks.",
        "activation_timing": "Ongoing, weekly",
        "description": "Bonus for three consecutive weeks of correct predictions.",
        "badge_name": "📊",
        "implementation_notes": "Drives weekly engagement."
      },
      {
        "sort_order": 90,
        "code": "G017",
        "template_scope": "club_specific",
        "category": "Predictions",
        "item_name": "Club History Quiz",
        "fet_value": 100,
        "trigger_condition": "Complete the 10-question Rayon history quiz.",
        "activation_timing": "Onboarding and monthly refresh",
        "description": "Ten questions on the club's founding year, titles, and legendary players.",
        "badge_name": "📚",
        "implementation_notes": "Deepens club identity. Refresh questions monthly."
      },
      {
        "sort_order": 100,
        "code": "G018",
        "template_scope": "generic",
        "category": "Predictions",
        "item_name": "Player Stats Master",
        "fet_value": 100,
        "trigger_condition": "Answer the live stats quiz correctly at halftime.",
        "activation_timing": "Live match - halftime",
        "description": "Quick-fire halftime quiz based on live match stats.",
        "badge_name": "📈",
        "implementation_notes": "Halftime retention mechanic."
      },
      {
        "sort_order": 110,
        "code": "G019",
        "template_scope": "generic",
        "category": "Predictions",
        "item_name": "Season Predictor",
        "fet_value": 1000,
        "trigger_condition": "Submit a full pre-season prediction set.",
        "activation_timing": "Season start only",
        "description": "Submit season outcome predictions and settle them at season end.",
        "badge_name": "🏆",
        "implementation_notes": "High delayed-reward mechanic for season-long investment."
      },
      {
        "sort_order": 120,
        "code": "G020",
        "template_scope": "generic",
        "category": "Predictions",
        "item_name": "Formation Genius",
        "fet_value": 100,
        "trigger_condition": "Submit a starting XI prediction and get at least 8 correct.",
        "activation_timing": "Pre-match, 48 hours before kickoff",
        "description": "Predict the starting XI and get at least 8 correct.",
        "badge_name": "♟️",
        "implementation_notes": "Rewards deep squad knowledge."
      },
      {
        "sort_order": 130,
        "code": "G021",
        "template_scope": "generic",
        "category": "Social",
        "item_name": "Bring a Friend",
        "fet_value": 100,
        "trigger_condition": "Referral registration via a unique link.",
        "activation_timing": "Ongoing",
        "description": "Earn FET when a referred friend downloads the app and checks in to a first match.",
        "badge_name": "👥",
        "implementation_notes": "Highest ROI acquisition mechanic."
      },
      {
        "sort_order": 140,
        "code": "G022",
        "template_scope": "generic",
        "category": "Social",
        "item_name": "Fan Squad Formation",
        "fet_value": 300,
        "trigger_condition": "Create or join a group of 25 or more fans.",
        "activation_timing": "Ongoing",
        "description": "Create or join a 25-plus fan group that earns collective FET and leaderboard status.",
        "badge_name": "🛡️",
        "implementation_notes": "Ubuntu mechanic: collective beats individual."
      },
      {
        "sort_order": 150,
        "code": "G029",
        "template_scope": "generic",
        "category": "Content",
        "item_name": "Match Day Blog Post",
        "fet_value": 300,
        "trigger_condition": "Submit a 200-plus word post-match write-up.",
        "activation_timing": "Post-match, six-hour window",
        "description": "Submit a 200-plus word post-match report. Top entries can land in the club newsletter.",
        "badge_name": "✍️",
        "implementation_notes": "Creates an editorial pipeline. Reward editors monthly."
      },
      {
        "sort_order": 160,
        "code": "G030",
        "template_scope": "generic",
        "category": "Content",
        "item_name": "Player Rating Submission",
        "fet_value": 100,
        "trigger_condition": "Rate all 11 players after the match.",
        "activation_timing": "Post-match, 24-hour window",
        "description": "Rate all 11 players after the match to contribute to official fan ratings.",
        "badge_name": "⭐",
        "implementation_notes": "Lightweight engagement and a valuable data asset."
      },
      {
        "sort_order": 170,
        "code": "G031",
        "template_scope": "club_specific",
        "category": "Content",
        "item_name": "TikTok/Reels Mention",
        "fet_value": 100,
        "trigger_condition": "Post a video mentioning Rayon Sports with the app link.",
        "activation_timing": "Ongoing",
        "description": "Post a short video that mentions Rayon Sports and includes the app link.",
        "badge_name": "🎬",
        "implementation_notes": "Organic social amplification."
      },
      {
        "sort_order": 180,
        "code": "G032",
        "template_scope": "generic",
        "category": "Content",
        "item_name": "Fan Art Submission",
        "fet_value": 100,
        "trigger_condition": "Upload original fan art.",
        "activation_timing": "Ongoing, with seasonal prompts",
        "description": "Upload original fan art such as player portraits or tifo concepts.",
        "badge_name": "🎨",
        "implementation_notes": "Creative community mechanic with seasonal prompts."
      },
      {
        "sort_order": 190,
        "code": "G033",
        "template_scope": "generic",
        "category": "Content",
        "item_name": "Tifo Design Vote",
        "fet_value": 100,
        "trigger_condition": "Vote on the proposed tifo design for the next big match.",
        "activation_timing": "Activated three weeks before derby or continental matches",
        "description": "Fans vote on the tifo concept for the next big match. Winning designers earn FET.",
        "badge_name": "🎭",
        "implementation_notes": "Real-world matchday impact increases authenticity."
      },
      {
        "sort_order": 200,
        "code": "G035",
        "template_scope": "generic",
        "category": "Loyalty",
        "item_name": "Season Ticket Holder Bonus",
        "fet_value": 3000,
        "trigger_condition": "Verify a season ticket purchase.",
        "activation_timing": "Season start",
        "description": "Season ticket holders get a permanent FET boost after ticket verification.",
        "badge_name": "🎫",
        "implementation_notes": "Cross-commercial integration with ticketing."
      },
      {
        "sort_order": 210,
        "code": "G036",
        "template_scope": "generic",
        "category": "Loyalty",
        "item_name": "1-Year Anniversary Badge",
        "fet_value": 500,
        "trigger_condition": "Reach the app account anniversary date.",
        "activation_timing": "Annual, automatic",
        "description": "Automatic annual badge with year-specific variants.",
        "badge_name": "🎂",
        "implementation_notes": "Annual retention touchpoint."
      },
      {
        "sort_order": 220,
        "code": "G037",
        "template_scope": "generic",
        "category": "Loyalty",
        "item_name": "Birthday Match Attendance",
        "fet_value": 500,
        "trigger_condition": "Check in to a match on your birthday.",
        "activation_timing": "Birthday match day",
        "description": "Attend a match on your birthday. The app can remind fans when a fixture lands nearby.",
        "badge_name": "🎁",
        "implementation_notes": "High emotional resonance."
      },
      {
        "sort_order": 230,
        "code": "G038",
        "template_scope": "generic",
        "category": "Loyalty",
        "item_name": "Never Miss a Home Match",
        "fet_value": 1500,
        "trigger_condition": "Attend every home league match in a season.",
        "activation_timing": "End of season",
        "description": "Perfect attendance across all home league matches in a season.",
        "badge_name": "🏠",
        "implementation_notes": "Season-long aspiration that maximises attendance."
      },
      {
        "sort_order": 240,
        "code": "G040",
        "template_scope": "club_specific",
        "category": "Challenges",
        "item_name": "Derby Prep Challenge",
        "fet_value": 600,
        "trigger_condition": "Complete three derby-week tasks.",
        "activation_timing": "Derby week, five days before Rayon vs APR",
        "description": "Special challenge bundle during derby week with three stacked tasks.",
        "badge_name": "⚔️",
        "implementation_notes": "Highest engagement week. Maximise with challenge stacking."
      },
      {
        "sort_order": 250,
        "code": "G041",
        "template_scope": "generic",
        "category": "Challenges",
        "item_name": "100 FET Daily Mission",
        "fet_value": 100,
        "trigger_condition": "Complete three daily micro-tasks.",
        "activation_timing": "Every day",
        "description": "Complete three daily micro-tasks such as rating a player, sharing a post, and answering trivia.",
        "badge_name": "☀️",
        "implementation_notes": "Guarantees a daily FET path on non-match days."
      },
      {
        "sort_order": 260,
        "code": "G044",
        "template_scope": "generic",
        "category": "Challenges",
        "item_name": "Win Streak Amplifier",
        "fet_value": 400,
        "trigger_condition": "Rayon wins three matches in a row.",
        "activation_timing": "Triggered by the third consecutive win",
        "description": "Unlock a 48-hour double-reward window after a three-match win streak.",
        "badge_name": "🔥",
        "implementation_notes": "Links positive on-pitch form to in-app engagement."
      },
      {
        "sort_order": 270,
        "code": "G047",
        "template_scope": "club_specific",
        "category": "Leaderboards",
        "item_name": "District #1 Fan",
        "fet_value": 100,
        "trigger_condition": "Finish with the top monthly FET total in a Kigali district.",
        "activation_timing": "Monthly, auto-awarded",
        "description": "Top fan in each Kigali district earns a featured profile and champion badge.",
        "badge_name": "🏆",
        "implementation_notes": "Hyper-local rivalry mechanic."
      },
      {
        "sort_order": 280,
        "code": "G048",
        "template_scope": "generic",
        "category": "Leaderboards",
        "item_name": "Squad Leaderboard #1",
        "fet_value": 100,
        "trigger_condition": "Lead the monthly Fan Squad leaderboard.",
        "activation_timing": "Monthly, auto-awarded",
        "description": "Top fan squad of the month is featured on the homepage and members earn a bonus.",
        "badge_name": "🥇",
        "implementation_notes": "Group competition intensifies individual engagement."
      },
      {
        "sort_order": 290,
        "code": "G049",
        "template_scope": "generic",
        "category": "Leaderboards",
        "item_name": "Season All-Time Top Fan",
        "fet_value": 3000,
        "trigger_condition": "Finish in the top three by cumulative season FET.",
        "activation_timing": "Season end",
        "description": "Top three fans by cumulative season FET earn premium end-of-season rewards.",
        "badge_name": "👑",
        "implementation_notes": "Season-defining reward announced at the end-of-season event."
      },
      {
        "sort_order": 300,
        "code": "G050",
        "template_scope": "generic",
        "category": "Leaderboards",
        "item_name": "Monthly Top Predictor",
        "fet_value": 100,
        "trigger_condition": "Post the best prediction accuracy in a calendar month.",
        "activation_timing": "Monthly",
        "description": "Best prediction accuracy in the month earns the Oracle Crown for 30 days.",
        "badge_name": "🔮",
        "implementation_notes": "Rewards knowledge, not just activity."
      },
      {
        "sort_order": 310,
        "code": "G052",
        "template_scope": "generic",
        "category": "Seasonal",
        "item_name": "Pre-Season Pledge",
        "fet_value": 300,
        "trigger_condition": "Submit a pre-season pledge and prediction.",
        "activation_timing": "Pre-season launch",
        "description": "Record and share a pre-season pledge and prediction for the coming campaign.",
        "badge_name": "🤜",
        "implementation_notes": "Activates fans before competitive football starts."
      },
      {
        "sort_order": 320,
        "code": "G058",
        "template_scope": "generic",
        "category": "Club Contribution",
        "item_name": "Merchandise Purchase",
        "fet_value": 200,
        "trigger_condition": "Purchase from the official club store in-app.",
        "activation_timing": "Ongoing",
        "description": "Earn FET for every official merchandise purchase completed in-app.",
        "badge_name": "👕",
        "implementation_notes": "Commercial integration for kits and merch."
      },
      {
        "sort_order": 330,
        "code": "G059",
        "template_scope": "generic",
        "category": "Club Contribution",
        "item_name": "Feedback Submission",
        "fet_value": 100,
        "trigger_condition": "Submit structured feedback about the matchday experience.",
        "activation_timing": "Post-match, 48-hour window",
        "description": "Submit structured feedback about the matchday experience.",
        "badge_name": "📋",
        "implementation_notes": "Data collection dressed as engagement."
      },
      {
        "sort_order": 340,
        "code": "G060",
        "template_scope": "generic",
        "category": "Club Contribution",
        "item_name": "Community Clean-Up Event",
        "fet_value": 100,
        "trigger_condition": "Participate in an official club community outreach event.",
        "activation_timing": "Monthly community event",
        "description": "Check in at club community outreach events and collect a civic badge.",
        "badge_name": "🌱",
        "implementation_notes": "CSR and engagement fusion with strong local resonance."
      },
      {
        "sort_order": 350,
        "code": "G061",
        "template_scope": "club_specific",
        "category": "Partner",
        "item_name": "Buy an Insurance Policy",
        "fet_value": 3000,
        "trigger_condition": "Purchase a motor, health, or life policy via the in-app partner link.",
        "activation_timing": "Year-round while the partner offer is active",
        "description": "Purchase a motor, health, or life insurance policy through the partner flow.",
        "badge_name": "💼",
        "implementation_notes": "High-value conversion event for insurer partners."
      },
      {
        "sort_order": 360,
        "code": "G062",
        "template_scope": "club_specific",
        "category": "Partner",
        "item_name": "Renew Your Policy",
        "fet_value": 3000,
        "trigger_condition": "Renew an existing policy before expiry via the app.",
        "activation_timing": "Active 30 days before renewal date",
        "description": "Renew an existing policy through the partner flow before expiry.",
        "badge_name": "🔄",
        "implementation_notes": "Annual retention revenue for the insurer."
      },
      {
        "sort_order": 370,
        "code": "G063",
        "template_scope": "club_specific",
        "category": "Partner",
        "item_name": "Refer a Friend to Insure",
        "fet_value": 1000,
        "trigger_condition": "A referred friend purchases a policy.",
        "activation_timing": "Year-round",
        "description": "Earn FET when a referred friend binds a policy.",
        "badge_name": "🤝",
        "implementation_notes": "Viral insurance acquisition mechanic."
      },
      {
        "sort_order": 380,
        "code": "G064",
        "template_scope": "club_specific",
        "category": "Partner",
        "item_name": "Skol Match Day Order",
        "fet_value": 500,
        "trigger_condition": "Order six or more Skol bottles at a partner venue on match day.",
        "activation_timing": "Match day window at partner venues",
        "description": "Order six or more Skol bottles at an approved matchday venue.",
        "badge_name": "🍺",
        "implementation_notes": "Partner bar revenue via QR or POS validation."
      },
      {
        "sort_order": 390,
        "code": "G065",
        "template_scope": "club_specific",
        "category": "Partner",
        "item_name": "Skol Round for the Squad",
        "fet_value": 1000,
        "trigger_condition": "Buy a round of 10 or more Skol bottles for your fan squad.",
        "activation_timing": "Match day and two hours post-match",
        "description": "Buy a round of 10 or more Skol bottles for your fan squad.",
        "badge_name": "🥂",
        "implementation_notes": "Group spending mechanic with receipt or app payment verification."
      },
      {
        "sort_order": 400,
        "code": "G066",
        "template_scope": "club_specific",
        "category": "Partner",
        "item_name": "Check-In at Skol Fan Zone",
        "fet_value": 500,
        "trigger_condition": "Check in at an official Skol Fan Zone.",
        "activation_timing": "Match day and designated Skol events",
        "description": "Check in at an official Skol Fan Zone at the stadium or a partner venue.",
        "badge_name": "📍",
        "implementation_notes": "Activates Skol-branded physical spaces."
      },
      {
        "sort_order": 410,
        "code": "G067",
        "template_scope": "club_specific",
        "category": "Partner",
        "item_name": "Skol Photo Challenge",
        "fet_value": 100,
        "trigger_condition": "Post a photo with a Skol product and the club hashtag.",
        "activation_timing": "Match day only",
        "description": "Share a matchday photo featuring Skol with the partner hashtag.",
        "badge_name": "📸",
        "implementation_notes": "UGC campaign that turns fans into brand ambassadors."
      },
      {
        "sort_order": 420,
        "code": "G068",
        "template_scope": "club_specific",
        "category": "Partner",
        "item_name": "Create Group Saving",
        "fet_value": 500,
        "trigger_condition": "Install the Cool app and create a group savings pot with 20-plus members and 100,000-plus in total savings.",
        "activation_timing": "Year-round, with push notification support",
        "description": "Install the Cool app and create a group savings pot with 20-plus members and 100,000-plus in total savings.",
        "badge_name": "🏦",
        "implementation_notes": "High-value banking acquisition event."
      },
      {
        "sort_order": 430,
        "code": "G069",
        "template_scope": "club_specific",
        "category": "Partner",
        "item_name": "Join Group Saving",
        "fet_value": 100,
        "trigger_condition": "Join a group savings product and contribute at least 5,000.",
        "activation_timing": "Year-round",
        "description": "Join a group savings product and contribute at least 5,000 through the partner flow.",
        "badge_name": "💳",
        "implementation_notes": "Drives savings activation and recurring deposits."
      },
      {
        "sort_order": 440,
        "code": "G070",
        "template_scope": "club_specific",
        "category": "Partner",
        "item_name": "Share Cool",
        "fet_value": 100,
        "trigger_condition": "Share the Cool group savings app.",
        "activation_timing": "Year-round",
        "description": "Share the Cool group savings experience with other fans.",
        "badge_name": "🎯",
        "implementation_notes": "Expands partner reach through peer-to-peer sharing."
      },
      {
        "sort_order": 450,
        "code": "G071",
        "template_scope": "club_specific",
        "category": "Partner",
        "item_name": "Buy Official Rayon Kit",
        "fet_value": 500,
        "trigger_condition": "Purchase the current season home or away kit via the partner store.",
        "activation_timing": "Season kit launch and ongoing",
        "description": "Purchase the current season home or away Rayon kit through the partner store.",
        "badge_name": "👕",
        "implementation_notes": "Kit sales revenue share tied to seasonal launches."
      },
      {
        "sort_order": 460,
        "code": "G072",
        "template_scope": "club_specific",
        "category": "Partner",
        "item_name": "Ride to Match with Mobio",
        "fet_value": 100,
        "trigger_condition": "Install the Mobio app and book a ride to the stadium on match day.",
        "activation_timing": "Match day, activated three hours before kickoff",
        "description": "Install the Mobio app and complete a ride to the stadium on match day.",
        "badge_name": "🚗",
        "implementation_notes": "Cross-product synergy between Mobio and Rayon."
      },
      {
        "sort_order": 470,
        "code": "G073",
        "template_scope": "club_specific",
        "category": "Partner",
        "item_name": "Share a Mobio with Fan",
        "fet_value": 100,
        "trigger_condition": "Share Mobio with another fan or complete a shared ride.",
        "activation_timing": "Match day",
        "description": "Share the Mobio app or complete a shared ride with another fan user.",
        "badge_name": "🚌",
        "implementation_notes": "Social transport mechanic that grows GMV and fan connection."
      },
      {
        "sort_order": 480,
        "code": "G074",
        "template_scope": "club_specific",
        "category": "Partner",
        "item_name": "Attend Partner Event",
        "fet_value": 500,
        "trigger_condition": "Check in at an official pre-match fan event at a partner venue.",
        "activation_timing": "Activated four hours before major matches",
        "description": "Check in at an official pre-match event run at a partner venue.",
        "badge_name": "🎊",
        "implementation_notes": "Hospitality revenue and premium fan experience."
      }
    ]$$::jsonb AS payload
  )
  INSERT INTO public.fan_engagement_token_catalog (
    club_id,
    code,
    template_scope,
    category,
    item_name,
    fet_value,
    trigger_condition,
    activation_timing,
    description,
    badge_name,
    implementation_notes,
    sort_order,
    is_active
  )
  SELECT
    v_rayon_club_id AS club_id,
    trim(entry->>'code') AS code,
    CASE
      WHEN entry->>'template_scope' = 'club_specific' THEN 'club_specific'
      ELSE 'generic'
    END AS template_scope,
    COALESCE(NULLIF(trim(entry->>'category'), ''), 'General') AS category,
    COALESCE(NULLIF(trim(entry->>'item_name'), ''), 'Fan engagement reward') AS item_name,
    COALESCE((entry->>'fet_value')::integer, 0) AS fet_value,
    COALESCE(NULLIF(trim(entry->>'trigger_condition'), ''), 'Defined by club operations.') AS trigger_condition,
    COALESCE(NULLIF(trim(entry->>'activation_timing'), ''), 'Always on') AS activation_timing,
    COALESCE(entry->>'description', '') AS description,
    COALESCE(entry->>'badge_name', '') AS badge_name,
    NULLIF(entry->>'implementation_notes', '') AS implementation_notes,
    COALESCE((entry->>'sort_order')::integer, 0) AS sort_order,
    true AS is_active
  FROM seed
  CROSS JOIN LATERAL jsonb_array_elements(payload) AS entry
  ON CONFLICT (club_id, code) DO UPDATE
  SET
    template_scope = EXCLUDED.template_scope,
    category = EXCLUDED.category,
    item_name = EXCLUDED.item_name,
    fet_value = EXCLUDED.fet_value,
    trigger_condition = EXCLUDED.trigger_condition,
    activation_timing = EXCLUDED.activation_timing,
    description = EXCLUDED.description,
    badge_name = EXCLUDED.badge_name,
    implementation_notes = EXCLUDED.implementation_notes,
    sort_order = EXCLUDED.sort_order,
    updated_at = now();
END;
$fet_seed$;

NOTIFY pgrst, 'reload schema';
