create or replace function public.sync_partner_club_columns() returns trigger
language plpgsql
as $$
begin
  if new.club_id is null and new.partner_id is not null then
    new.club_id := public.compat_parse_partner_id(new.partner_id);
  end if;

  if new.partner_id is null and new.club_id is not null then
    if pg_typeof(new.partner_id)::text = 'text' then
      new.partner_id := new.club_id::text;
    end if;
  end if;

  return new;
end;
$$;
