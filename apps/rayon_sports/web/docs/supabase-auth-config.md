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

Supabase uses Twilio as the underlying provider for WhatsApp OTP.

#### Required Supabase Auth Settings (Dashboard → Authentication → Phone)
- **Enable phone provider**: ✅ ON
- **SMS Provider**: Twilio
- **Twilio Account SID**: (from Twilio dashboard)
- **Twilio Auth Token**: (from Twilio dashboard)
- **Twilio Message Service SID or Sender Phone**: (WhatsApp-enabled number)

#### Required Twilio Configuration
- WhatsApp Business profile connected to Twilio number
- WhatsApp message template approved for OTP delivery
- Twilio Messaging Service configured with WhatsApp channel

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
  token: "123456",
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
