# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: surfaces.spec.ts >> admin surfaces an offline indicator when network is disabled
- Location: e2e/surfaces.spec.ts:142:5

# Error details

```
Error: expect(locator).toBeVisible() failed

Locator: getByText(/admin shell stays available|live admin data and writes require the network/i)
Expected: visible
Timeout: 5000ms
Error: element(s) not found

Call log:
  - Expect "toBeVisible" with timeout 5000ms
  - waiting for getByText(/admin shell stays available|live admin data and writes require the network/i)

```

# Page snapshot

```yaml
- generic [ref=e3]:
  - img [ref=e4]
  - heading "This page couldn’t load" [level=1] [ref=e6]
  - paragraph [ref=e7]: Reload to try again, or go back.
  - generic [ref=e8]:
    - button "Reload" [ref=e10] [cursor=pointer]
    - button "Back" [ref=e11] [cursor=pointer]
```

# Test source

```ts
  62  |   await page.goto("/supporters", { waitUntil: "domcontentloaded" });
  63  |   await expect(
  64  |     page.getByRole("heading", {
  65  |       name: /the supporter journey continues on mobile/i,
  66  |     }),
  67  |   ).toBeVisible();
  68  |   await expect(
  69  |     page.getByRole("heading", {
  70  |       name: /admin-managed fan engagement rewards/i,
  71  |     }),
  72  |   ).toBeVisible();
  73  | });
  74  | 
  75  | /* ────────────────────────────────────────────────────────── */
  76  | /*  Admin: OTP sign-in surface (replaces magic-link test)    */
  77  | /* ────────────────────────────────────────────────────────── */
  78  | 
  79  | test("admin route renders the phone OTP sign-in surface", async ({
  80  |   page,
  81  |   browserName,
  82  | }) => {
  83  |   test.skip(
  84  |     browserName === "webkit",
  85  |     "Playwright WebKit can remain on the admin loading shell during auth bootstrap.",
  86  |   );
  87  | 
  88  |   await page.goto("/admin", {
  89  |     waitUntil: browserName === "webkit" ? "networkidle" : "domcontentloaded",
  90  |   });
  91  | 
  92  |   // Admin auth heading
  93  |   await expect(page.getByText(/secure sign in/i)).toBeVisible();
  94  | 
  95  |   // Phone number input (OTP flow)
  96  |   const phoneInput = page.locator('input[type="tel"]');
  97  |   await expect(phoneInput).toBeVisible({
  98  |     timeout: browserName === "webkit" ? 15_000 : 5_000,
  99  |   });
  100 | 
  101 |   // Submit button for OTP
  102 |   await expect(
  103 |     page.getByRole("button", { name: /send code|send otp|sign in/i }),
  104 |   ).toBeVisible();
  105 | });
  106 | 
  107 | /* ────────────────────────────────────────────────────────── */
  108 | /*  PWA manifest + offline                                   */
  109 | /* ────────────────────────────────────────────────────────── */
  110 | 
  111 | test("pwa manifest and offline route are reachable", async ({
  112 |   page,
  113 |   request,
  114 | }) => {
  115 |   const manifestResponse = await request.get("/manifest.webmanifest");
  116 |   expect(manifestResponse.ok()).toBeTruthy();
  117 |   const manifest = await manifestResponse.json();
  118 | 
  119 |   // Public manifest should include the usual fields
  120 |   expect(manifest).toMatchObject({
  121 |     display: "standalone",
  122 |     start_url: "/",
  123 |   });
  124 |   // Public manifest should NOT have admin scope
  125 |   expect(manifest.scope).not.toBe("/admin");
  126 | 
  127 |   await page.goto("/offline", { waitUntil: "domcontentloaded" });
  128 |   await expect(
  129 |     page.getByRole("heading", { name: /cached pages stay available/i }),
  130 |   ).toBeVisible();
  131 | 
  132 |   await page.goto("/admin-offline", { waitUntil: "domcontentloaded" });
  133 |   await expect(
  134 |     page.getByRole("heading", { name: /admin data needs a live connection/i }),
  135 |   ).toBeVisible();
  136 | });
  137 | 
  138 | /* ────────────────────────────────────────────────────────── */
  139 | /*  Offline synthetic test                                    */
  140 | /* ────────────────────────────────────────────────────────── */
  141 | 
  142 | test("admin surfaces an offline indicator when network is disabled", async ({
  143 |   page,
  144 |   context,
  145 |   browserName,
  146 | }) => {
  147 |   test.skip(
  148 |     browserName === "webkit",
  149 |     "Playwright WebKit is unreliable for admin service worker control checks.",
  150 |   );
  151 | 
  152 |   // First visit the admin shell so the page has a mounted offline listener.
  153 |   await page.goto("/admin", { waitUntil: "domcontentloaded" });
  154 |   await expect(page.getByText(/secure sign in/i)).toBeVisible();
  155 | 
  156 |   // Go offline
  157 |   await context.setOffline(true);
  158 |   await expect(
  159 |     page.getByText(
  160 |       /admin shell stays available|live admin data and writes require the network/i,
  161 |     ),
> 162 |   ).toBeVisible({ timeout: 5_000 });
      |     ^ Error: expect(locator).toBeVisible() failed
  163 | 
  164 |   // Restore network
  165 |   await context.setOffline(false);
  166 | });
  167 | 
  168 | /* ────────────────────────────────────────────────────────── */
  169 | /*  Admin: assignment-backed session (conditional)           */
  170 | /* ────────────────────────────────────────────────────────── */
  171 | 
  172 | test("admin auth with assignment-backed session reaches dashboard", async ({
  173 |   page,
  174 |   baseURL,
  175 |   browserName,
  176 | }) => {
  177 |   test.skip(
  178 |     browserName === "webkit",
  179 |     "Playwright WebKit is unreliable for live Supabase magic-link admin sessions.",
  180 |   );
  181 | 
  182 |   const serviceClient = createAdminServiceClient();
  183 |   if (serviceClient == null) {
  184 |     test.skip(true, "Live Supabase admin credentials are missing.");
  185 |     return;
  186 |   }
  187 | 
  188 |   const email = `playwright-admin-${Date.now()}@example.com`;
  189 |   let userId = "";
  190 | 
  191 |   try {
  192 |     // Create an admin user with a real assignment
  193 |     const created = await serviceClient.auth.admin.createUser({
  194 |       email,
  195 |       email_confirm: true,
  196 |       app_metadata: { role: "club_admin", club_id: CLUB_ID },
  197 |     });
  198 |     if (created.error) {
  199 |       throw created.error;
  200 |     }
  201 |     userId = created.data.user.id;
  202 | 
  203 |     const assignment = await serviceClient
  204 |       .from("admin_role_assignments")
  205 |       .insert({
  206 |         user_id: userId,
  207 |         role: "club_admin",
  208 |         is_active: true,
  209 |         club_id: CLUB_ID,
  210 |         notes: "temporary playwright verification user",
  211 |       });
  212 |     if (assignment.error) {
  213 |       throw assignment.error;
  214 |     }
  215 | 
  216 |     // Use magic link as a bridge to bypass OTP in CI.
  217 |     // The WhatsApp Cloud API OTP delivery hook is exercised separately.
  218 |     const redirectTo = `${baseURL}/auth/callback?next=/admin`;
  219 |     const link = await serviceClient.auth.admin.generateLink({
  220 |       type: "magiclink",
  221 |       email,
  222 |       options: { redirectTo },
  223 |     });
  224 | 
  225 |     // If magic link generation fails (user has no email), skip gracefully
  226 |     if (link.error) {
  227 |       test.skip(true, `Magic link bridge unavailable: ${link.error.message}`);
  228 |       return;
  229 |     }
  230 | 
  231 |     await page.goto(link.data.properties.action_link, {
  232 |       waitUntil: "networkidle",
  233 |       timeout: 120_000,
  234 |     });
  235 | 
  236 |     // After sign-in, we should see the operations dashboard
  237 |     await expect(
  238 |       page
  239 |         .locator("#admin-main-content")
  240 |         .getByRole("heading", { name: /operations dashboard/i })
  241 |         .first(),
  242 |     ).toBeVisible({
  243 |       timeout: 20_000,
  244 |     });
  245 |     await expect(
  246 |       page
  247 |         .locator("#admin-main-content")
  248 |         .getByRole("heading", { name: /quick actions/i })
  249 |         .first(),
  250 |     ).toBeVisible();
  251 |     await expect(
  252 |       page
  253 |         .locator("#admin-main-content")
  254 |         .getByRole("heading", { name: /recent activity/i })
  255 |         .first(),
  256 |     ).toBeVisible();
  257 | 
  258 |     const moreButton = page.getByRole("button", {
  259 |       name: /show more admin options/i,
  260 |     });
  261 |     await expect(moreButton).toBeVisible();
  262 |     await moreButton.click();
```