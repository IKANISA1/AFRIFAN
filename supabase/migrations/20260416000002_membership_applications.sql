-- Add status to fan_memberships to manage supporter state
ALTER TABLE public.fan_memberships ADD COLUMN IF NOT EXISTS status text DEFAULT 'active' CHECK (status IN ('active', 'pending', 'suspended', 'expired'));
COMMENT ON COLUMN public.fan_memberships.status IS 'Current status of the fan membership.';

-- Create membership_applications table for tier upgrade requests
CREATE TABLE IF NOT EXISTS public.membership_applications (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    club_id bigint NOT NULL,
    tier text NOT NULL,
    status text DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    payment_status text DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid', 'failed')),
    application_date timestamp with time zone DEFAULT now() NOT NULL,
    review_date timestamp with time zone,
    reviewer_id uuid REFERENCES auth.users(id),
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Enable RLS on membership_applications
ALTER TABLE public.membership_applications ENABLE ROW LEVEL SECURITY;

-- Policies for membership_applications
CREATE POLICY membership_applications_select_own ON public.membership_applications
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY membership_applications_insert_own ON public.membership_applications
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY membership_applications_admin_all ON public.membership_applications
    USING (public.is_admin_user() OR public.is_club_admin(club_id));

-- Trigger for updated_at
CREATE TRIGGER trg_membership_applications_set_updated_at
    BEFORE UPDATE ON public.membership_applications
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Comment
COMMENT ON TABLE public.membership_applications IS 'Fan applications for specific membership tiers, requiring admin review or payment verification.';
