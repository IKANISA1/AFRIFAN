CREATE OR REPLACE FUNCTION public.purchase_club_tickets(
  p_match_id uuid,
  p_user_id uuid,
  p_seat_type text,
  p_quantity integer,
  p_payment_reference text
) RETURNS TABLE(id uuid)
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
DECLARE
  v_match RECORD;
  v_ticket_amount integer;
  v_seat_type text;
  v_index integer;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Authenticated user must match the requested ticket owner.';
  END IF;

  IF p_quantity IS NULL OR p_quantity < 1 THEN
    RAISE EXCEPTION 'Ticket quantity must be at least 1.';
  END IF;

  v_seat_type := CASE
    WHEN lower(coalesce(p_seat_type, '')) = 'vip' THEN 'vip'
    ELSE 'general'
  END;

  SELECT
    id,
    club_id,
    is_on_sale,
    ticket_general_price,
    ticket_vip_price
  INTO v_match
  FROM public.matches
  WHERE id = p_match_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match % was not found.', p_match_id;
  END IF;

  IF coalesce(v_match.is_on_sale, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'Tickets are not on sale for this match.';
  END IF;

  v_ticket_amount := CASE
    WHEN v_seat_type = 'vip' THEN coalesce(v_match.ticket_vip_price, 0)
    ELSE coalesce(v_match.ticket_general_price, 0)
  END;

  FOR v_index IN 1..p_quantity LOOP
    RETURN QUERY
    INSERT INTO public.tickets (
      match_id,
      user_id,
      club_id,
      seat_type,
      amount_paid,
      momo_reference,
      status,
      purchased_at,
      confirmed_at
    )
    VALUES (
      p_match_id,
      p_user_id,
      v_match.club_id,
      v_seat_type,
      v_ticket_amount,
      nullif(btrim(coalesce(p_payment_reference, '')), ''),
      'pending',
      timezone('utc', now()),
      null
    )
    RETURNING tickets.id;
  END LOOP;
END;
$$;
