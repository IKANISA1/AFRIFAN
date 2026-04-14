-- Create the payment status ENUM for RB-4 validation
CREATE TYPE public.payment_status AS ENUM (
    'pending_verification',
    'verified',
    'failed'
);

-- Add payment_status to fan_memberships (defaults to verified for legacy rows)
ALTER TABLE public.fan_memberships
ADD COLUMN payment_status public.payment_status DEFAULT 'verified'::public.payment_status NOT NULL;

-- Add payment_status to contributions (defaults to verified for legacy rows)
ALTER TABLE public.contributions
ADD COLUMN payment_status public.payment_status DEFAULT 'verified'::public.payment_status NOT NULL;

-- Also add to season_memberships and group_contributions if applicable
ALTER TABLE public.season_memberships
ADD COLUMN payment_status public.payment_status DEFAULT 'verified'::public.payment_status NOT NULL;

ALTER TABLE public.group_contributions
ADD COLUMN payment_status public.payment_status DEFAULT 'verified'::public.payment_status NOT NULL;
