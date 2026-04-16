-- F-002: Ensure push token uniqueness constraint
-- This migration ensures that user_fcm_tokens has a unique constraint on the 'token' column
-- to prevent silent failures during .upsert() calls on upgraded databases.

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_constraint 
        WHERE conname = 'user_fcm_tokens_token_key'
    ) THEN
        ALTER TABLE public.user_fcm_tokens 
        ADD CONSTRAINT user_fcm_tokens_token_key UNIQUE (token);
    END IF;
END $$;
