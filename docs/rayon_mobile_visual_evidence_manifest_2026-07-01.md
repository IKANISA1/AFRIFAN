# Rayon Mobile Visual Evidence Manifest

Date: 2026-07-02

This manifest binds the supporter launch routes in `docs/screen_inventory.md`
to the current visual evidence set used by the Mobi-borrowing implementation
goal.

Evidence source:

- `output/product_design_screen_report/20260702T141428Z/screenshots_53_device_actual`
- feature golden folders under `packages/features/*/test/goldens`

Admin/internal routes are excluded from supporter launch route coverage and
remain opt-in/guarded. This manifest covers supporter launch routes only.

| Route | Screen | Evidence | States tracked |
| --- | --- | --- | --- |
| `/splash` | Splash | `04_splash.png` | data, loading |
| `/onboarding` | Onboarding | `05_onboarding.png`; onboarding goldens | data, large text |
| `/auth/phone` | WhatsApp Number | `06_whatsapp_number.png` | data, error |
| `/auth/otp` | WhatsApp OTP | `07_whatsapp_otp.png` | data, error |
| `/home` | Home | `01_home.png`; home goldens | data, loading, empty, error, large text |
| `/fanzone` | Fan Zone | `02_fanzone_hub.png`; fanzone goldens | data, loading, error |
| `/settings` | Settings | `03_settings.png`; settings goldens | data, large text |
| `/tickets` | Tickets List | `08_tickets_list.png`; ticketing goldens | data, loading, empty, error, large text |
| `/membership` | Membership | `13_membership.png`; membership goldens | data, loading, empty, error, large text |
| `/shop` | Shop | `21_shop.png` | data, empty, error |
