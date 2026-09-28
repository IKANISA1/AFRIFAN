-- Forward-only performance support for fair tenant-scoped OTP dispatch.
-- No policy, user, role, source data or runtime enablement is changed.
CREATE INDEX IF NOT EXISTS auth_club_delivery_due
ON auth_challenges(club_id,next_attempt_ms,challenge_id)
WHERE state='open' AND delivery_cipher IS NOT NULL AND delivery_attempts<3;
