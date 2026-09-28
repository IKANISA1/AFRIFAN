-- Fifth supported club. Identity: https://cdcostadosol.s1.emjogo.pt/pt/
-- Country code: https://www.itu.int/oth/t0202
-- Currency code MZN: Banco de Moçambique published ISO transition.
-- No provider, payment recipient, operator grant, or release credential is set.
-- UI palette is provisional pending approved brand values.
begin;

insert into public.countries
  (id, name, dialing_code, currency, phone_placeholder, is_active)
values ('MZ', 'Mozambique', '+258', 'MZN', '', false)
on conflict (id) do nothing;

do $$
begin
  if exists (
    select 1 from public.african_football_clubs
    where (id = 1001 and club_slug <> 'costa_do_sol_mz')
       or (club_slug = 'costa_do_sol_mz' and id <> 1001)
  ) then
    raise exception 'CD Costa do Sol tenant identity conflicts with an existing club';
  end if;
end;
$$;

insert into public.african_football_clubs
  (id, club_name, country_name, club_slug, currency_code, currency_symbol,
   league, nickname_brand_identity, country_iso_code, primary_color_hex,
   secondary_color_hex, accent_color_hex, primary_brand_colors, club_profile)
overriding system value values
  (1001, 'CD Costa do Sol', 'Mozambique', 'costa_do_sol_mz', 'MZN', 'MT',
   null, 'Os Canarinhos', 'MZ', '#F6C400', '#144B8B', '#122F5C',
   'Yellow, Blue', jsonb_build_object(
     'full_name', 'Clube de Desportos da Costa do Sol',
     'identity_note', 'Os Canarinhos',
     'source_locale', 'pt',
     'source_urls', jsonb_build_array('https://cdcostadosol.s1.emjogo.pt/pt/')
   ))
on conflict (id) do nothing;

select setval(
  pg_get_serial_sequence('public.african_football_clubs', 'id'),
  greatest((select last_value from public.african_football_clubs_id_seq),
           (select max(id) from public.african_football_clubs)),
  true
);

commit;
