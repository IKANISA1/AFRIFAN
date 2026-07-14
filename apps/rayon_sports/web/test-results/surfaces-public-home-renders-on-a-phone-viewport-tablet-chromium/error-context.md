# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: surfaces.spec.ts >> public home renders on a phone viewport
- Location: e2e/surfaces.spec.ts:48:5

# Error details

```
Error: expect(locator).toBeVisible() failed

Locator: getByRole('heading', { name: /this is gikundiro/i })
Expected: visible
Error: strict mode violation: getByRole('heading', { name: /this is gikundiro/i }) resolved to 2 elements:
    1) <h1 class="font-display text-5xl font-black uppercase italic leading-[0.9] tracking-tighter text-white drop-shadow-xl lg:text-8xl">This is Gikundiro.</h1> aka getByRole('heading', { name: 'This is Gikundiro.' }).first()
    2) <h1 class="font-display text-5xl font-black uppercase italic leading-[0.9] tracking-tighter text-white drop-shadow-xl lg:text-8xl">This is Gikundiro.</h1> aka getByRole('heading', { name: 'This is Gikundiro.' }).nth(1)

Call log:
  - Expect "toBeVisible" with timeout 5000ms
  - waiting for getByRole('heading', { name: /this is gikundiro/i })

```

# Page snapshot

```yaml
- generic [active] [ref=e1]:
  - generic [ref=e2]:
    - link "Skip to content" [ref=e3] [cursor=pointer]:
      - /url: "#main-content"
    - generic [ref=e4]:
      - generic [ref=e6]:
        - generic [ref=e7]:
          - img [ref=e8]
          - generic [ref=e10]: Next
          - generic [ref=e11]: Rayon Sports vs Police FC
          - generic [ref=e12]: Sun, 26 Apr, 18:00
        - link "Details" [ref=e13] [cursor=pointer]:
          - /url: /fixtures/featured-home-fixture
      - navigation [ref=e14]:
        - link "Rayon Sports FC" [ref=e15] [cursor=pointer]:
          - /url: /
          - img "Rayon Sports FC" [ref=e17]
        - generic [ref=e18]:
          - link "Fan Portal" [ref=e19] [cursor=pointer]:
            - /url: /supporters
            - img [ref=e20]
            - generic [ref=e23]: Fan Portal
          - button "Open menu" [ref=e24] [cursor=pointer]:
            - img [ref=e25]
    - main [ref=e26]:
      - generic [ref=e27]:
        - generic [ref=e28]:
          - generic [ref=e29]:
            - img "Rayon Sports FC generated brand surface" [ref=e31]
            - generic [ref=e35]:
              - paragraph [ref=e36]: The Beloved, live in the browser
              - heading "This is Gikundiro." [level=1] [ref=e37]
              - paragraph [ref=e38]: Get tickets, follow live matches, back supporter circles, and join the Rayon Sports family — all from your browser.
              - generic [ref=e39]:
                - link "Join the Beloved" [ref=e40] [cursor=pointer]:
                  - /url: /membership
                  - text: Join the Beloved
                  - img [ref=e41]
                - link "Open supporter app" [ref=e43] [cursor=pointer]:
                  - /url: /supporters
            - generic [ref=e45]:
              - generic [ref=e47]:
                - generic [ref=e48]:
                  - generic [ref=e49]: RS
                  - paragraph [ref=e50]: Rayon Sports
                - generic [ref=e51]:
                  - generic [ref=e52]: Rwanda Premier League
                  - paragraph [ref=e53]: VS
                  - paragraph [ref=e54]: Sun, 26 Apr, 18:00
                - generic [ref=e55]:
                  - generic [ref=e56]: PF
                  - paragraph [ref=e57]: Police FC
              - generic [ref=e59]:
                - generic [ref=e60]:
                  - img [ref=e61]
                  - paragraph [ref=e64]: Amahoro Stadium
                - generic [ref=e65]:
                  - img [ref=e66]
                  - paragraph [ref=e68]: 18:00
                - link "Buy Tickets" [ref=e69] [cursor=pointer]:
                  - /url: /tickets
                  - img [ref=e70]
                  - text: Buy Tickets
          - generic [ref=e72]:
            - link "Fan portal" [ref=e73] [cursor=pointer]:
              - /url: /supporters
            - link "Buy tickets" [ref=e74] [cursor=pointer]:
              - /url: /tickets
            - link "Support Groups" [ref=e75] [cursor=pointer]:
              - /url: /Groups
            - link "Membership tiers" [ref=e76] [cursor=pointer]:
              - /url: /membership
            - link "Latest club news" [ref=e77] [cursor=pointer]:
              - /url: /news
            - link "Shop new drop" [ref=e78] [cursor=pointer]:
              - /url: /shop
        - generic [ref=e79]:
          - generic [ref=e80]:
            - img "Rayon Sports FC generated brand surface" [ref=e82]
            - generic [ref=e86]:
              - paragraph [ref=e87]: The Beloved, live in the browser
              - heading "This is Gikundiro." [level=1] [ref=e88]
              - paragraph [ref=e89]: Get tickets, follow live matches, back supporter circles, and join the Rayon Sports family — all from your browser.
              - generic [ref=e90]:
                - link "Join the Beloved" [ref=e91] [cursor=pointer]:
                  - /url: /membership
                  - text: Join the Beloved
                  - img [ref=e92]
                - link "Open supporter app" [ref=e94] [cursor=pointer]:
                  - /url: /supporters
            - generic [ref=e96]:
              - generic [ref=e98]:
                - generic [ref=e99]:
                  - generic [ref=e100]: RS
                  - paragraph [ref=e101]: Rayon Sports
                - generic [ref=e102]:
                  - generic [ref=e103]: Rwanda Premier League
                  - paragraph [ref=e104]: VS
                  - paragraph [ref=e105]: Sun, 26 Apr, 18:00
                - generic [ref=e106]:
                  - generic [ref=e107]: PF
                  - paragraph [ref=e108]: Police FC
              - generic [ref=e110]:
                - generic [ref=e111]:
                  - img [ref=e112]
                  - paragraph [ref=e115]: Amahoro Stadium
                - generic [ref=e116]:
                  - img [ref=e117]
                  - paragraph [ref=e119]: 18:00
                - link "Buy Tickets" [ref=e120] [cursor=pointer]:
                  - /url: /tickets
                  - img [ref=e121]
                  - text: Buy Tickets
          - generic [ref=e123]:
            - link "Fan portal" [ref=e124] [cursor=pointer]:
              - /url: /supporters
            - link "Buy tickets" [ref=e125] [cursor=pointer]:
              - /url: /tickets
            - link "Support Groups" [ref=e126] [cursor=pointer]:
              - /url: /Groups
            - link "Membership tiers" [ref=e127] [cursor=pointer]:
              - /url: /membership
            - link "Latest club news" [ref=e128] [cursor=pointer]:
              - /url: /news
            - link "Shop new drop" [ref=e129] [cursor=pointer]:
              - /url: /shop
        - generic [ref=e131]:
          - generic [ref=e132]:
            - paragraph [ref=e133]: Fixtures
            - heading "Matchday schedule." [level=2] [ref=e134]
          - link "Full fixtures" [ref=e135] [cursor=pointer]:
            - /url: /fixtures
            - text: Full fixtures
            - img [ref=e136]
        - generic [ref=e138]:
          - generic [ref=e139]:
            - generic [ref=e140]:
              - paragraph [ref=e141]: Membership
              - heading "Join the Gikundiro (The Beloved) family." [level=2] [ref=e142]
            - link "Compare plans" [ref=e143] [cursor=pointer]:
              - /url: /membership
              - text: Compare plans
              - img [ref=e144]
          - generic [ref=e147]:
            - generic [ref=e148]:
              - generic [ref=e149]:
                - paragraph [ref=e150]: Standings
                - heading "Where we stand." [level=2] [ref=e151]
              - table [ref=e153]:
                - rowgroup [ref=e154]:
                  - row "Pos Club P GD Pts" [ref=e155]:
                    - columnheader "Pos" [ref=e156]
                    - columnheader "Club" [ref=e157]
                    - columnheader "P" [ref=e158]
                    - columnheader "GD" [ref=e159]
                    - columnheader "Pts" [ref=e160]
                - rowgroup [ref=e161]:
                  - row "1 Rayon Sports FC 24 25 54" [ref=e162]:
                    - cell "1" [ref=e163]
                    - cell "Rayon Sports FC" [ref=e164]
                    - cell "24" [ref=e165]
                    - cell "25" [ref=e166]
                    - cell "54" [ref=e167]
                  - row "2 Rayon Sports 24 18 50" [ref=e168]:
                    - cell "2" [ref=e169]
                    - cell "Rayon Sports" [ref=e170]
                    - cell "24" [ref=e171]
                    - cell "18" [ref=e172]
                    - cell "50" [ref=e173]
                  - row "3 Police FC 24 13 44" [ref=e174]:
                    - cell "3" [ref=e175]
                    - cell "Police FC" [ref=e176]
                    - cell "24" [ref=e177]
                    - cell "13" [ref=e178]
                    - cell "44" [ref=e179]
                  - row "4 Kiyovu Sports 24 8 39" [ref=e180]:
                    - cell "4" [ref=e181]
                    - cell "Kiyovu Sports" [ref=e182]
                    - cell "24" [ref=e183]
                    - cell "8" [ref=e184]
                    - cell "39" [ref=e185]
                  - row "5 Etincelles FC 24 6 37" [ref=e186]:
                    - cell "5" [ref=e187]
                    - cell "Etincelles FC" [ref=e188]
                    - cell "24" [ref=e189]
                    - cell "6" [ref=e190]
                    - cell "37" [ref=e191]
                  - row "6 AS Kigali 24 5 35" [ref=e192]:
                    - cell "6" [ref=e193]
                    - cell "AS Kigali" [ref=e194]
                    - cell "24" [ref=e195]
                    - cell "5" [ref=e196]
                    - cell "35" [ref=e197]
                  - row "7 Musanze FC 24 2 33" [ref=e198]:
                    - cell "7" [ref=e199]
                    - cell "Musanze FC" [ref=e200]
                    - cell "24" [ref=e201]
                    - cell "2" [ref=e202]
                    - cell "33" [ref=e203]
                  - row "8 Mukura VS 24 -1 32" [ref=e204]:
                    - cell "8" [ref=e205]
                    - cell "Mukura VS" [ref=e206]
                    - cell "24" [ref=e207]
                    - cell "-1" [ref=e208]
                    - cell "32" [ref=e209]
              - link "Full table" [ref=e210] [cursor=pointer]:
                - /url: /standings
                - text: Full table
                - img [ref=e211]
            - generic [ref=e217]:
              - generic [ref=e218]:
                - paragraph [ref=e219]: Supporter network
                - heading "Our supporter chapters." [level=2] [ref=e220]
              - generic [ref=e221]:
                - article [ref=e222]:
                  - paragraph [ref=e223]: Kinyaga Fan Club
                  - paragraph [ref=e224]: Western
                  - paragraph [ref=e225]: An official supporter chapter.
                - article [ref=e226]:
                  - paragraph [ref=e227]: Bugarama & Rusizi Fan Club
                  - paragraph [ref=e228]: Western
                  - paragraph [ref=e229]: An official supporter chapter.
                - article [ref=e230]:
                  - paragraph [ref=e231]: Dream Unity Fan Club
                  - paragraph [ref=e232]: Kigali
                  - paragraph [ref=e233]: An official supporter chapter.
              - link "Explore chapters" [ref=e234] [cursor=pointer]:
                - /url: /fan-clubs
                - text: Explore chapters
                - img [ref=e235]
        - generic [ref=e240]:
          - generic [ref=e241]:
            - generic [ref=e242]:
              - paragraph [ref=e243]: Editorial
              - heading "Inside Rayon Sports FC." [level=2] [ref=e244]
            - link "Newsroom" [ref=e245] [cursor=pointer]:
              - /url: /news
              - text: Newsroom
              - img [ref=e246]
          - generic [ref=e248]:
            - 'link "The Blue Wall: Preparing for Matchday at the Cathedral Transfers 1 min read Club media Sat, 28 Mar The Blue Wall: Preparing for Matchday at the Cathedral Rayon Sports FC is finalizing a world-class matchday experience for our supporters. From the choreographed Blue Wall tifo to enhanced hospitality in the Platinum Lounge, every deta Read story" [ref=e250] [cursor=pointer]':
              - /url: /news/8593cbdb-90ff-443a-9e18-43b8707adb31
              - generic [ref=e251]:
                - 'img "The Blue Wall: Preparing for Matchday at the Cathedral" [ref=e252]'
                - generic [ref=e253]:
                  - generic [ref=e254]: Transfers
                  - generic [ref=e255]: 1 min read
              - generic [ref=e256]:
                - generic [ref=e257]:
                  - generic [ref=e258]: Club media
                  - generic [ref=e259]: Sat, 28 Mar
                - 'heading "The Blue Wall: Preparing for Matchday at the Cathedral" [level=3] [ref=e260]'
                - paragraph [ref=e261]: Rayon Sports FC is finalizing a world-class matchday experience for our supporters. From the choreographed Blue Wall tifo to enhanced hospitality in the Platinum Lounge, every deta
              - generic [ref=e262]:
                - generic [ref=e263]: Read story
                - img [ref=e264]
            - 'link "Digital Fan Identity: Your Portal to the Beloved Match Day 1 min read Club media Wed, 25 Mar Digital Fan Identity: Your Portal to the Beloved Being a member of Rayon Sports is more than just a ticket—it''s a digital-first identity. Our new fan portal allows supporters across Rwanda and the diaspora to manage their tiers, Read story" [ref=e267] [cursor=pointer]':
              - /url: /news/b3705b99-163e-4323-aa00-6409a42d61a5
              - generic [ref=e268]:
                - 'img "Digital Fan Identity: Your Portal to the Beloved" [ref=e269]'
                - generic [ref=e270]:
                  - generic [ref=e271]: Match Day
                  - generic [ref=e272]: 1 min read
              - generic [ref=e273]:
                - generic [ref=e274]:
                  - generic [ref=e275]: Club media
                  - generic [ref=e276]: Wed, 25 Mar
                - 'heading "Digital Fan Identity: Your Portal to the Beloved" [level=3] [ref=e277]'
                - paragraph [ref=e278]: Being a member of Rayon Sports is more than just a ticket—it's a digital-first identity. Our new fan portal allows supporters across Rwanda and the diaspora to manage their tiers,
              - generic [ref=e279]:
                - generic [ref=e280]: Read story
                - img [ref=e281]
            - 'link "The 2026 Heritage Collection: Out Now Academy 1 min read Club media Mon, 23 Mar The 2026 Heritage Collection: Out Now Our 2026 Heritage Collection is officially live. Featuring the iconic cobalt blue with gold accents, the new home replica jersey combines breathable performance fabrics with the pr Read story" [ref=e284] [cursor=pointer]':
              - /url: /news/6ea4fcc7-9960-4625-9be5-35b30932f50c
              - generic [ref=e285]:
                - 'img "The 2026 Heritage Collection: Out Now" [ref=e286]'
                - generic [ref=e287]:
                  - generic [ref=e288]: Academy
                  - generic [ref=e289]: 1 min read
              - generic [ref=e290]:
                - generic [ref=e291]:
                  - generic [ref=e292]: Club media
                  - generic [ref=e293]: Mon, 23 Mar
                - 'heading "The 2026 Heritage Collection: Out Now" [level=3] [ref=e294]'
                - paragraph [ref=e295]: Our 2026 Heritage Collection is officially live. Featuring the iconic cobalt blue with gold accents, the new home replica jersey combines breathable performance fabrics with the pr
              - generic [ref=e296]:
                - generic [ref=e297]: Read story
                - img [ref=e298]
        - generic [ref=e300]:
          - generic [ref=e301]:
            - generic [ref=e302]:
              - generic [ref=e303]:
                - paragraph [ref=e304]: Shop
                - heading "Wear the badge." [level=2] [ref=e305]
              - link "Shop all" [ref=e306] [cursor=pointer]:
                - /url: /shop
                - text: Shop all
                - img [ref=e307]
            - generic [ref=e309]:
              - link "2026 Home Replica Jersey Kits Kits 2026 Home Replica Jersey Matchday fit, club crest embroidery, breathable knit. RF 35,000 View product" [ref=e311] [cursor=pointer]:
                - /url: /shop/463f9444-4e45-42b3-9ae2-02e31a26de1a
                - generic [ref=e312]:
                  - img "2026 Home Replica Jersey" [ref=e313]
                  - generic [ref=e314]:
                    - generic [ref=e315]: Kits
                    - generic [ref=e316]: Kits
                - generic [ref=e322]:
                  - heading "2026 Home Replica Jersey" [level=3] [ref=e323]
                  - paragraph [ref=e324]: Matchday fit, club crest embroidery, breathable knit.
                - generic [ref=e325]:
                  - generic [ref=e326]:
                    - img [ref=e327]
                    - generic [ref=e330]: RF 35,000
                  - generic [ref=e331]:
                    - text: View product
                    - img [ref=e332]
              - link "Blue Travel Hoodie Outerwear Outerwear Blue Travel Hoodie Heavyweight fleece with a tonal crest hit. RF 42,000 View product" [ref=e335] [cursor=pointer]:
                - /url: /shop/772094d4-a363-4255-b949-7d0dabf93c09
                - generic [ref=e336]:
                  - img "Blue Travel Hoodie" [ref=e337]
                  - generic [ref=e338]:
                    - generic [ref=e339]: Outerwear
                    - generic [ref=e340]: Outerwear
                - generic [ref=e346]:
                  - heading "Blue Travel Hoodie" [level=3] [ref=e347]
                  - paragraph [ref=e348]: Heavyweight fleece with a tonal crest hit.
                - generic [ref=e349]:
                  - generic [ref=e350]:
                    - img [ref=e351]
                    - generic [ref=e354]: RF 42,000
                  - generic [ref=e355]:
                    - text: View product
                    - img [ref=e356]
              - link "Rayon Sports Matchday Scarf Accessories Accessories Rayon Sports Matchday Scarf Stadium knit in blue, white, and gold. RF 12,000 View product" [ref=e359] [cursor=pointer]:
                - /url: /shop/6830fbd4-3ee4-41be-8f0e-4eedbd6e0a54
                - generic [ref=e360]:
                  - img "Rayon Sports Matchday Scarf" [ref=e361]
                  - generic [ref=e362]:
                    - generic [ref=e363]: Accessories
                    - generic [ref=e364]: Accessories
                - generic [ref=e370]:
                  - heading "Rayon Sports Matchday Scarf" [level=3] [ref=e371]
                  - paragraph [ref=e372]: Stadium knit in blue, white, and gold.
                - generic [ref=e373]:
                  - generic [ref=e374]:
                    - img [ref=e375]
                    - generic [ref=e378]: RF 12,000
                  - generic [ref=e379]:
                    - text: View product
                    - img [ref=e380]
          - generic [ref=e382]:
            - generic [ref=e383]:
              - generic [ref=e384]:
                - paragraph [ref=e385]: Club identity
                - heading "Gikundiro (The Beloved) — club identity." [level=2] [ref=e386]
              - generic [ref=e387]:
                - article [ref=e388]:
                  - paragraph [ref=e389]: The beloved identity
                  - paragraph [ref=e390]: Gikundiro means "the beloved" in Kinyarwanda. The name carries the weight of a supporter culture built on loyalty, matchday ritual, and collective identity. It is not a slogan — it is the relationship between club and community.
                - article [ref=e391]:
                  - paragraph [ref=e392]: The beloved identity
                  - paragraph [ref=e393]: Gikundiro means "the beloved" in Kinyarwanda. The name carries the weight of a supporter culture built on loyalty, matchday ritual, and collective identity. It is not a slogan — it is the relationship between club and community.
                - article [ref=e394]:
                  - paragraph [ref=e395]: Matchday at scale
                  - paragraph [ref=e396]: "The website anchors matchday: live scores, lineup drops, and ticketing in real time. It extends the stadium experience beyond seats, connecting the diaspora and local supporters on one platform."
                - article [ref=e397]:
                  - paragraph [ref=e398]: Matchday at scale
                  - paragraph [ref=e399]: "The website anchors matchday: live scores, lineup drops, and ticketing in real time. It extends the stadium experience beyond seats, connecting the diaspora and local supporters on one platform."
                - article [ref=e400]:
                  - paragraph [ref=e401]: One supporter account
                  - paragraph [ref=e402]: The web and mobile products share a single supporter account — membership, XP, ticket history, and contribution records follow the user across devices. The web is not a secondary product.
                - article [ref=e403]:
                  - paragraph [ref=e404]: One supporter account
                  - paragraph [ref=e405]: The web and mobile products share a single supporter account — membership, XP, ticket history, and contribution records follow the user across devices. The web is not a secondary product.
            - generic [ref=e406]:
              - generic [ref=e407]:
                - paragraph [ref=e408]: Fan app
                - heading "Your supporter account." [level=2] [ref=e409]
              - generic [ref=e410]:
                - link "Continue to fan app" [ref=e411] [cursor=pointer]:
                  - /url: /supporters
                - link "Explore club history" [ref=e412] [cursor=pointer]:
                  - /url: /history
    - contentinfo [ref=e413]:
      - generic [ref=e414]:
        - generic [ref=e415]:
          - generic [ref=e416]:
            - link "Rayon Sports FC Rayon Sports FC Gikundiro (The Beloved)" [ref=e417] [cursor=pointer]:
              - /url: /
              - img "Rayon Sports FC" [ref=e419]
              - generic [ref=e420]:
                - paragraph [ref=e421]: Rayon Sports FC
                - paragraph [ref=e422]: Gikundiro (The Beloved)
            - paragraph [ref=e423]: Experience the pulse of Rwandan football. From matchday magic at the Cathedral to digital fan engagement across the globe.
            - generic [ref=e424]:
              - link "facebook" [ref=e425] [cursor=pointer]:
                - /url: fb.com/RayonSportsOfficial
                - img [ref=e426]
              - link "instagram" [ref=e429] [cursor=pointer]:
                - /url: instagram.com/rayonsports_official
                - img [ref=e430]
              - link "x" [ref=e433] [cursor=pointer]:
                - /url: x.com/rayon_sports
                - img [ref=e434]
              - link "tiktok" [ref=e437] [cursor=pointer]:
                - /url: tiktok.com/@rayonsports
                - img [ref=e438]
          - generic [ref=e442]:
            - generic [ref=e443]:
              - paragraph [ref=e444]: Matchday
              - list [ref=e445]:
                - listitem [ref=e446]:
                  - link "Fixtures" [ref=e447] [cursor=pointer]:
                    - /url: /fixtures
                - listitem [ref=e448]:
                  - link "Tickets" [ref=e449] [cursor=pointer]:
                    - /url: /tickets
                - listitem [ref=e450]:
                  - link "Results" [ref=e451] [cursor=pointer]:
                    - /url: /results
                - listitem [ref=e452]:
                  - link "Standings" [ref=e453] [cursor=pointer]:
                    - /url: /standings
            - generic [ref=e454]:
              - paragraph [ref=e455]: Supporters
              - list [ref=e456]:
                - listitem [ref=e457]:
                  - link "Membership" [ref=e458] [cursor=pointer]:
                    - /url: /membership
                - listitem [ref=e459]:
                  - link "Support Groups" [ref=e460] [cursor=pointer]:
                    - /url: /Groups
                - listitem [ref=e461]:
                  - link "Fan Clubs" [ref=e462] [cursor=pointer]:
                    - /url: /fan-clubs
                - listitem [ref=e463]:
                  - link "Fan App" [ref=e464] [cursor=pointer]:
                    - /url: /supporters
            - generic [ref=e465]:
              - paragraph [ref=e466]: Club
              - list [ref=e467]:
                - listitem [ref=e468]:
                  - link "News" [ref=e469] [cursor=pointer]:
                    - /url: /news
                - listitem [ref=e470]:
                  - link "Squad" [ref=e471] [cursor=pointer]:
                    - /url: /squad
                - listitem [ref=e472]:
                  - link "History" [ref=e473] [cursor=pointer]:
                    - /url: /history
                - listitem [ref=e474]:
                  - link "Contact" [ref=e475] [cursor=pointer]:
                    - /url: /contact
            - generic [ref=e476]:
              - paragraph [ref=e477]: Legal
              - list [ref=e478]:
                - listitem [ref=e479]:
                  - link "Privacy" [ref=e480] [cursor=pointer]:
                    - /url: /privacy
                - listitem [ref=e481]:
                  - link "Terms" [ref=e482] [cursor=pointer]:
                    - /url: /terms
        - generic [ref=e483]:
          - generic [ref=e484]:
            - generic [ref=e485]: © 2026 Rayon Sports FC
            - link "Privacy Policy" [ref=e486] [cursor=pointer]:
              - /url: /privacy
            - link "Terms of Service" [ref=e487] [cursor=pointer]:
              - /url: /terms
          - generic [ref=e488]:
            - generic [ref=e489]: Powered by
            - generic [ref=e490]: AFRICLUB
  - alert [ref=e491]
```

# Test source

```ts
  1   | import fs from "node:fs";
  2   | import path from "node:path";
  3   | import { expect, test } from "@playwright/test";
  4   | import { createClient } from "@supabase/supabase-js";
  5   | 
  6   | const CLUB_ID = 24;
  7   | 
  8   | function loadLocalEnv() {
  9   |   const envPath = path.join(process.cwd(), ".env.local");
  10  |   if (!fs.existsSync(envPath)) {
  11  |     return {} as Record<string, string>;
  12  |   }
  13  | 
  14  |   return Object.fromEntries(
  15  |     fs
  16  |       .readFileSync(envPath, "utf8")
  17  |       .split(/\n+/)
  18  |       .filter(Boolean)
  19  |       .filter((line) => !line.startsWith("#"))
  20  |       .map((line) => {
  21  |         const separatorIndex = line.indexOf("=");
  22  |         return [line.slice(0, separatorIndex), line.slice(separatorIndex + 1)];
  23  |       }),
  24  |   );
  25  | }
  26  | 
  27  | function createAdminServiceClient() {
  28  |   const env = loadLocalEnv();
  29  |   const supabaseUrl = env.SUPABASE_URL ?? env.NEXT_PUBLIC_SUPABASE_URL ?? "";
  30  |   const serviceRoleKey = env.SUPABASE_SERVICE_ROLE_KEY ?? "";
  31  | 
  32  |   if (!supabaseUrl || !serviceRoleKey) {
  33  |     return null;
  34  |   }
  35  | 
  36  |   return createClient(supabaseUrl, serviceRoleKey, {
  37  |     auth: {
  38  |       autoRefreshToken: false,
  39  |       persistSession: false,
  40  |     },
  41  |   });
  42  | }
  43  | 
  44  | /* ────────────────────────────────────────────────────────── */
  45  | /*  Public surfaces                                          */
  46  | /* ────────────────────────────────────────────────────────── */
  47  | 
  48  | test("public home renders on a phone viewport", async ({ page }) => {
  49  |   await page.goto("/");
  50  | 
  51  |   await expect(
  52  |     page.getByRole("heading", { name: /this is gikundiro/i }),
> 53  |   ).toBeVisible();
      |     ^ Error: expect(locator).toBeVisible() failed
  54  |   await expect(
  55  |     page.getByRole("link", {
  56  |       name: /app y'abafana|open fan app|open supporter app/i,
  57  |     }),
  58  |   ).toBeVisible();
  59  | });
  60  | 
  61  | test("supporters handoff page renders on tablet", async ({ page }) => {
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
```