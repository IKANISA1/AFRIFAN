# Gikundiro — Supabase Auth Configuration

## Required Project Settings

### Site URL
```
https://gikundiro.com
```

### Redirect Allow-List
```
https://gikundiro.com/**
https://www.gikundiro.com/**
https://admin.gikundiro.com/**
https://fans.gikundiro.com/**
```

> These must be configured in Supabase Dashboard → Authentication → URL Configuration.

### WhatsApp OTP Provider

Supabase Auth calls the `send-sms` Edge Function, which delivers OTP messages
through the WhatsApp Cloud API using the approved `gikundiro` authentication
template. The Flutter app must keep using `OtpChannel.whatsapp`; it must not
call the Meta Graph API or carry WhatsApp Cloud API secrets.

#### Required Supabase Auth Settings (Dashboard -> Authentication -> Hooks)
- **Phone provider**: ON
- **Send SMS hook**: `https://<project-ref>.supabase.co/functions/v1/send-sms`
- **Local test OTP**: `250788767816 = "12345"` in `supabase/config.toml`

#### Required Edge Function Secrets
- `SUPABASE_AUTH_HOOK_SEND_SMS_SECRET` — the Standard Webhooks signing secret
  configured for the Supabase Send SMS HTTP Hook
- `WHATSAPP_PHONE_NUMBER_ID`
- `WHATSAPP_CLOUD_API_TOKEN` or `WHATSAPP_CLOUD_ACCESS_TOKEN`
- `WHATSAPP_AUTH_TEMPLATE_NAME=gikundiro`
- `WHATSAPP_AUTH_TEMPLATE_LANGUAGE=en_US`
- `WHATSAPP_GRAPH_API_VERSION` optional, defaults to `v25.0`

The hook must fail closed when its signing secret is absent or the
`webhook-id`, `webhook-timestamp`, and `webhook-signature` headers do not
verify. OTP values and phone numbers must never be written to application
logs. The former Next.js `/api/admin/auth/whatsapp-webhook` duplicate is
retired; only the signed `send-sms` Edge Function is an approved delivery
boundary.

#### Client-Side Usage
```ts
// Send OTP via WhatsApp channel
await supabase.auth.signInWithOtp({
  phone: "+250788xxxxxx",
  options: {
    shouldCreateUser: false,
    channel: "whatsapp",
  },
});

// Verify OTP (uses "sms" type for both SMS and WhatsApp)
await supabase.auth.verifyOtp({
  phone: "+250788xxxxxx",
  token: "12345",
  type: "sms",
});
```

### Admin Phone Access Table

The `admin_phone_access` table must be populated with approved admin phone numbers:

```sql
INSERT INTO admin_phone_access (phone, normalized_phone, club_ids)
VALUES ('+250788767816', '250788767816', ARRAY[1]);
```

### Admin Role Assignments

After a phone user signs in for the first time, assign their admin role:

```sql
INSERT INTO admin_role_assignments (user_id, role, club_id, is_active)
VALUES ('<user-uuid>', 'super_admin', 1, true);
```

### Rate Limiting RPC

The `consume_request_rate_limit` function must exist for server-side rate limiting:

```sql
-- Already created by migration: 20260416180000_harden_platform_feature_management.sql
-- Verify existence:
SELECT proname FROM pg_proc WHERE proname = 'consume_request_rate_limit';
```

## Environment Variables

### Web App (.env.local)
```env
NEXT_PUBLIC_SUPABASE_URL=https://<project-ref>.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=<anon-key>
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<service-role-key>
```

### Cloudflare Worker (wrangler.toml secrets)
```
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
```
