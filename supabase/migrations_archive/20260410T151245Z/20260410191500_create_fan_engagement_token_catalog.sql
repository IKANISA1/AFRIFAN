-- =============================================================================
-- Admin-managed Fan Engagement Token catalog
-- Seeds the initial Rayon Sports reward catalog with generic and club-specific
-- FET definitions that can be activated or deactivated from the admin panel.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.fan_engagement_token_catalog (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id              bigint NOT NULL REFERENCES public.african_football_clubs(id) ON DELETE CASCADE,
  code                 text NOT NULL,
  template_scope       text NOT NULL DEFAULT 'generic'
    CHECK (template_scope IN ('generic', 'club_specific')),
  category             text NOT NULL DEFAULT 'General',
  item_name            text NOT NULL DEFAULT 'Fan engagement reward',
  fet_value            integer NOT NULL DEFAULT 0 CHECK (fet_value >= 0),
  trigger_condition    text NOT NULL DEFAULT 'Defined by club operations.',
  activation_timing    text NOT NULL DEFAULT 'Always on',
  description          text NOT NULL DEFAULT '',
  badge_name           text NOT NULL DEFAULT '',
  implementation_notes text,
  sort_order           integer NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
  is_active            boolean NOT NULL DEFAULT true,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_fet_catalog_club_code
  ON public.fan_engagement_token_catalog (club_id, code);

CREATE INDEX IF NOT EXISTS idx_fet_catalog_club_scope_sort
  ON public.fan_engagement_token_catalog (
    club_id,
    template_scope,
    is_active,
    sort_order,
    code
  );

DROP TRIGGER IF EXISTS trg_fet_catalog_updated ON public.fan_engagement_token_catalog;
CREATE TRIGGER trg_fet_catalog_updated
  BEFORE UPDATE ON public.fan_engagement_token_catalog
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.fan_engagement_token_catalog ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fet_catalog_public_read ON public.fan_engagement_token_catalog;
CREATE POLICY fet_catalog_public_read
  ON public.fan_engagement_token_catalog FOR SELECT
  USING (
    is_active = true
    AND club_id::text = public.requesting_club_id()
  );

DROP POLICY IF EXISTS fet_catalog_admin_all ON public.fan_engagement_token_catalog;
CREATE POLICY fet_catalog_admin_all
  ON public.fan_engagement_token_catalog FOR ALL
  USING (
    club_id::text = public.requesting_club_id()
    AND public.is_club_admin(club_id)
  )
  WITH CHECK (
    club_id::text = public.requesting_club_id()
    AND public.is_club_admin(club_id)
  );

GRANT SELECT ON public.fan_engagement_token_catalog TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.fan_engagement_token_catalog TO authenticated;

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
      "activation_timing": "Derby week, five days before Rayon vs Rayon Sports",
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
  24 AS club_id,
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
ON CONFLICT (club_id, code) DO NOTHING;

NOTIFY pgrst, 'reload schema';
