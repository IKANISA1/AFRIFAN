# Screen Reader Test Checklist

**Product:** Gikundiro Admin PWA  
**Standard:** WCAG 2.2 AA  
**Testers:** Assigned QA / accessibility champion

---

## Test Environment Matrix

| Screen Reader | Browser | OS | Priority |
|:--|:--|:--|:--:|
| VoiceOver | Safari | iOS 16.4+ | P1 |
| VoiceOver | Safari | macOS | P1 |
| TalkBack | Chrome | Android 13+ | P1 |
| NVDA | Firefox | Windows | P2 |
| JAWS | Chrome | Windows | P3 |

---

## Pre-Test Setup

1. Enable screen reader on test device
2. Ensure latest browser version
3. Clear cache and cookies
4. Navigate to `admin.gikundiro.com`

---

## Test Scenarios

### 1. Admin Sign-In Flow

| Step | Expected Behavior | Pass? |
|:--|:--|:--:|
| Navigate to `/admin` | SR announces "Admin workspace" heading | ☐ |
| Tab to phone input | SR announces "Phone number" label and input type "telephone" | ☐ |
| Enter phone number | SR reads back typed digits | ☐ |
| Tab to "Send code" button | SR announces "Send code, button" | ☐ |
| Activate button | SR announces loading state or OTP input appears | ☐ |
| Tab to OTP input | SR announces "Verification code" label and `inputMode: numeric` | ☐ |
| Invalid code submission | SR announces error message from toast (assertive live region) | ☐ |

### 2. Admin Dashboard Navigation

| Step | Expected Behavior | Pass? |
|:--|:--|:--:|
| Skip-to-content link | First tab stop is skip link; activating scrolls to main | ☐ |
| Sidebar navigation | SR announces nav landmark with "Admin navigation" label | ☐ |
| Nav items | SR announces each link with `aria-current="page"` for active item | ☐ |
| Dashboard heading | SR announces "Admin dashboard" eyebrow + main heading | ☐ |
| Metric cards | SR reads label + value (e.g., "Total users: 312") | ☐ |
| Quick action links | SR announces link text and navigates on activation | ☐ |
| Recent activity feed | SR reads each activity item with title, detail, and timestamp | ☐ |

### 3. Admin Notification Form

| Step | Expected Behavior | Pass? |
|:--|:--|:--:|
| Title input | SR announces label "Title" and character count | ☐ |
| Body textarea | SR announces label "Body" and character count | ☐ |
| Audience select | SR announces "Audience" label and current value | ☐ |
| Delivery mode select | SR announces "Delivery mode" and options | ☐ |
| Conditional fields | Tier/group select appears and is announced when relevant | ☐ |
| Submit button | SR announces "Send notification, button" or "Schedule notification" | ☐ |
| Success toast | SR announces via `aria-live="polite"` region | ☐ |
| Error toast | SR announces via `role="alert"` with assertive live region | ☐ |

### 4. PWA Install Prompts

| Step | Expected Behavior | Pass? |
|:--|:--|:--:|
| Install banner appears | SR announces banner text and "Install app" button | ☐ |
| Dismiss button | SR announces "Not now, button" | ☐ |
| iOS Safari guide | SR reads step-by-step instructions with share icon description | ☐ |
| Update banner | SR announces "A fresher admin build is ready" and "Refresh app" button | ☐ |

### 5. Offline State

| Step | Expected Behavior | Pass? |
|:--|:--|:--:|
| Offline banner | SR announces offline warning message | ☐ |
| Admin offline page | SR reads heading and "Retry" / "Open public site" links | ☐ |

---

## Common Issues to Watch For

- [ ] Images without alt text
- [ ] Form inputs without associated labels
- [ ] Non-descriptive link text ("Click here", "Read more")
- [ ] Focus traps in modals or overlays
- [ ] Dynamic content updates not announced (missing `aria-live`)
- [ ] Color-only information (status badges should have text alternative)
- [ ] Touch targets < 48px (affects switch/checkbox controls)

---

## Sign-Off

| Reviewer | Date | Result | Notes |
|:--|:--|:--|:--|
| | | ☐ Pass / ☐ Fail | |

Filed: `docs/screen-reader-test-checklist.md`
