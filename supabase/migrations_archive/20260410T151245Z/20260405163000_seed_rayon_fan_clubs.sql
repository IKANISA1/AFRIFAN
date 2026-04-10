-- ==============================================================================
-- Seed Rayon Sports Fan Clubs
-- ==============================================================================

DO $$
DECLARE
  v_club_id bigint;
  v_partner_id uuid;
  v_rec record;
BEGIN
  -- 1) Get Rayon Sports club ID
  SELECT id INTO v_club_id
  FROM public.african_football_clubs
  WHERE club_name = 'Rayon Sports FC'
  LIMIT 1;

  IF v_club_id IS NULL THEN
    RAISE NOTICE 'Rayon Sports FC not found, skipping fan clubs seed';
    RETURN;
  END IF;

  -- 1.5) Get Rayon Sports Partner ID to satisfy legacy foreign keys
  SELECT id INTO v_partner_id
  FROM public.partners
  WHERE name = 'Rayon Sports FC'
  LIMIT 1;

  IF v_partner_id IS NULL THEN
    RAISE NOTICE 'Rayon Sports FC partner not found in legacy table, skipping fan clubs seed';
    RETURN;
  END IF;

  -- 2) Insert fan clubs idempotently with regions
  FOR v_rec IN (
    SELECT * FROM (VALUES
      ('Bugarama & Rusizi Fan Club', 'Western'),
      ('Dream Unity Fan Club', 'Kigali'),
      ('DYNA Fan Club', 'Kigali'),
      ('Friends Fan Club', 'Kigali'),
      ('Gikundiro Forever Fan Club', 'Kigali'),
      ('Gikundiro Iwacu Nyamagabe Fan Club', 'Southern'),
      ('Gikundiro Lovers Fan Club', 'Kigali'),
      ('Gikundiro Senior Fan Club', 'Kigali'),
      ('Gikundiro Yacu Fan Club', 'Kigali'),
      ('Gisaka Fan Club', 'Eastern'),
      ('Ijwi ry''Aba-Rayon Fan Club', 'Kigali'),
      ('Ijwi ry''Aba-Rayon Senior', 'Kigali'),
      ('Intwari Fan Club', 'Kigali'),
      ('Inyambo / Nyagatare Fan Club', 'Eastern'),
      ('Isaro Fan Club', 'Kigali'),
      ('Ishema ry''Umu-Rayon', 'Kigali'),
      ('Isibo Fan Club', 'Kigali'),
      ('Kinyaga Fan Club', 'Western'),
      ('Kivu Blue Fan Club', 'Western'),
      ('New Vision Fan Club', 'Kigali'),
      ('Rayon Sports Family', 'Kigali'),
      ('Rayon Sports Special Fan Club', 'Kigali'),
      ('Rayon Sports Super Fans', 'Kigali'),
      ('Rayon Twifuza Fan Club', 'Kigali'),
      ('Rubavu Fan Club', 'Western'),
      ('Ruhango Fan Club', 'Southern'),
      ('Smart Blue Fan Club', 'Kigali'),
      ('TBW Fan Club', 'Kigali'),
      ('The Blue Family Fan Club', 'Kigali'),
      ('The Blue Sky Fan Club', 'Kigali'),
      ('Thé Vert Fan Club', 'Kigali'),
      ('Trust Supporters Fan Club', 'Kigali'),
      ('Ubumwe bw''Abarayon Fan Club', 'Kigali'),
      ('Ururembo / Diaspora Fan Club', 'International'),
      ('Winning Team Fan Club', 'Kigali'),
      ('Gasabo Fan Club', 'Kigali'),
      ('Kicukiro Fan Club', 'Kigali'),
      ('Nyarugenge Fan Club', 'Kigali'),
      ('Burera Fan Club', 'Northern'),
      ('Gakenke Fan Club', 'Northern'),
      ('Gicumbi Fan Club', 'Northern'),
      ('Musanze Fan Club', 'Northern'),
      ('Rulindo Fan Club', 'Northern'),
      ('Gisagara Fan Club', 'Southern'),
      ('Huye Fan Club', 'Southern'),
      ('Kamonyi Fan Club', 'Southern'),
      ('Muhanga Fan Club', 'Southern'),
      ('Nyanza Fan Club', 'Southern'),
      ('Nyaruguru Fan Club', 'Southern'),
      ('Bugesera Fan Club', 'Eastern'),
      ('Gatsibo Fan Club', 'Eastern'),
      ('Kayonza Fan Club', 'Eastern'),
      ('Kirehe Fan Club', 'Eastern'),
      ('Ngoma Fan Club', 'Eastern'),
      ('Rwamagana Fan Club', 'Eastern'),
      ('Karongi Fan Club', 'Western'),
      ('Ngororero Fan Club', 'Western'),
      ('Nyabihu Fan Club', 'Western'),
      ('Nyamasheke Fan Club', 'Western'),
      ('Rutsiro Fan Club', 'Western'),
      ('EastAfrica Fan Club', 'International'),
      ('Canada Fan Club', 'International'),
      ('USA Fan Club', 'International'),
      ('Belgium Fan Club', 'International'),
      ('France Fan Club', 'International')
    ) AS t(name, region)
  )
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM public.fan_clubs
      WHERE club_id = v_club_id AND name = v_rec.name
    ) THEN
      INSERT INTO public.fan_clubs (club_id, partner_id, name, region)
      VALUES (v_club_id, v_partner_id, v_rec.name, v_rec.region);
    END IF;
  END LOOP;
END;
$$;
