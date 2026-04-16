-- Create initial admin user for WhatsApp login
DO $$
DECLARE
  v_user_id uuid := gen_random_uuid();
BEGIN
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE phone = '250788767816') THEN
    INSERT INTO auth.users (id, phone, encrypted_password, created_at, updated_at)
    VALUES (v_user_id, '250788767816', crypt('initial_admin_placeholder', gen_salt('bf')), now(), now());

    INSERT INTO public.admin_role_assignments (user_id, role)
    VALUES (v_user_id, 'admin');
  END IF;
END $$;
