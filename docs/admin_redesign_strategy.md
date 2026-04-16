# Gikundiro Admin Workspace Redesign Strategy

## 1. Full Admin Panel Redesign Strategy
The primary goal of the Gikundiro admin redesign is to unify the operational management of both the website and the mobile app into a single, world-class back office. This redesign transitions from a fragmented CMS structure to an operationally driven, table-first interface built for speed and clarity. 

Key strategies:
- **Unified Workspace:** Bring web and app operations under a single, context-aware shell.
- **Table-First Operations:** Transition from card-based layouts to dense, scannable data grids for bulk operations, quick reviews, and moderation.
- **Progressive Disclosure:** Expose only primary decisions on list views; utilize side drawers for detailed object editing without breaking operational context.
- **Consistent Visual Language:** Implement "Soft Liquid Glass" aesthetics tailored for a calm, professional admin environment, heavily utilizing the `admin-workspace` CSS tokens.

## 2. Updated Admin Information Architecture
The architecture is flattened to ensure quick access to critical operations, organized by functional domain rather than delivery platform.

- **Dashboard:** Unified metrics, pending approvals, alerts, and quick actions.
- **Content:** Unified CMS (Stories, Banners, Announcements, App Modules).
- **Matchday:** Fixtures, Results, Standings, Live Centre.
- **Ticketing & Memberships:** Ticket campaigns, membership plans, applications, verification.
- **Community:** Support Circles, Fan Clubs / Chapters, Moderation Queues.
- **Users:** Unified supporter profiles (Web + App), roles, account health.
- **Analytics:** Platform performance, membership trends.
- **Settings:** Platform configs, WhatsApp Admin integrations, Audit Logs.

## 3. Dashboard Redesign Concept
The dashboard acts as the live pulse of the Gikundiro platform. 
- **Top Row (KPIs):** Active users, Memberships pending verification, Active Support Circles, Recent Ticket Sales.
- **Second Row (Operational Lanes):** Actionable lists such as "Pending Content Approvals", "Reported Fan Comments", "Live Match Status".
- **Interaction:** One-click resolution from the dashboard or deep-link into specific module drawers.

## 4. Module-by-Module Admin Page Concepts
- **Content Module:** Split-pane view where the left side is a searchable/filterable table of content assets, and the right side is an inline editor with real-time preview toggles for "Web" vs. "App".
- **Users Module:** Scannable table of users with inline status badges (Active, Suspended). Bulk action bar for mass communications. Drawer for detailed supporter history (tickets bought, circles joined).
- **Matchday Module:** Timeline-based editor for live updates, integrated with push notification triggers for the mobile app.

## 5. Unified Website + App Operations Model
Instead of having a "Website CMS" and an "App CMS", operations are object-based.
- When an admin creates an "Announcement", they select the target distribution: `Web`, `App`, or `Both`.
- Content scheduling, featured flags, and banners respect this distribution model. 
- A single API powers both frontends, managed by this unified admin backend.

## 6. Reusable Admin Component Library
A disciplined set of React components designed for high-density operations:
- `AdminSurface` / `AdminPageHeader`: For structural consistency.
- `AdminDataGrid`: Sortable, filterable table component.
- `AdminStatusBadge`: Standardized tones (Success, Warning, Danger, Info).
- `AdminActionDrawer`: Slide-out panel for CRUD operations.
- `AdminFilterBar`: Sticky bar for complex state filtering.

## 7. Role and Permissions Structure Guidance
- **Super Admin:** Full access to all modules, destructive actions, and settings.
- **Content Editor:** Can draft, edit, and schedule content. Cannot approve final publication.
- **Publisher:** Can approve and publish drafted content to Web/App.
- **Community Moderator:** Access restricted to Support Circles, Fan Clubs, and User flagging.

## 8. Moderation and Approval Workflow Guidance
- **Two-Step Publishing:** Drafts require approval from a Publisher role before going live.
- **Community Flagging:** User-generated content (e.g., in Support Circles) flagged by fans goes to a central Moderation Queue.
- **Resolutions:** Admins can `Approve`, `Reject`, or `Suspend User` directly from the queue using row-level actions.

## 9. Analytics and Reporting Dashboard Guidance
- Move heavy analytics off the main dashboard into a dedicated module.
- Provide exportable reports (CSV/PDF) for Ticket Sales, Membership Growth, and Matchday Engagement.
- Focus on actionable insights rather than vanity metrics.

## 10. Final Design Language
The admin panel must feel like a "Soft Liquid Glass" command center.
- **Colors:** Deep neutral slates for background (`--admin-bg-top`), crisp graphite for surfaces.
- **Typography:** Sentence case, highly legible fonts, minimal decorative text.
- **Interaction:** Fast state updates, optimistic UI for toggles, and clear, descriptive empty states.
