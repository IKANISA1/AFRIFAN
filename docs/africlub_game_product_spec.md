# AFRICLUB Game Product Spec

Date: 2026-07-02

This is the canonical implementation contract for the AFRICLUB game platform.
It normalizes the July 2026 product-design notes and the architecture review
into one build target.

## Product Contract

- TV/display is the stage.
- Mobile is the controller.
- Admin is the control room.
- Supabase is the authority.
- Points are social status only.
- AI drafts content, but humans publish.
- No real-money betting, odds, staking, payouts, customer wallet, cash-out, or
  transferable-value framing appears in launch-visible surfaces.

## MVP Surfaces

1. Mobile controller: join a session, answer questions, see result state, and
   recover from reconnects without local winner decisions.
2. TV display: render only screen-safe state for attract, lobby, question,
   claim, reveal, leaderboard, and end states.
3. Admin control room: create sessions, pair displays, open/reveal questions,
   review packs, and inspect audit state.
4. Supabase backend: own game state, scoring, first-correct claim locking,
   idempotency, RLS, and audit.

## Backend Rules

- One player attempt is accepted per session question.
- The first correct answer creates the only claim for that session question.
- Correct-answer keys and explanations must not be visible to TV or player
  clients before claim, reveal, or closed states.
- Host/admin actions must be club scoped.
- Realtime reads must be filtered by tenant, screen, venue, session, player, or
  equivalent identifiers.
- Sensitive writes go through RPCs or Edge Functions.

## MVP Data Domains

- Game templates and packs.
- Question sources, drafts, and approved questions.
- TV devices and display pairing.
- Game sessions, teams, players, and session questions.
- Answer attempts and answer claims.
- Points ledger and audit log.

## Launch Gates

- Product-boundary scan reports no launch-visible betting or wallet copy.
- Scoped realtime scan passes.
- SQL contract tests prove game schema, unique claim, one-attempt constraint,
  RLS enablement, and key RPCs.
- Admin, TV, and mobile UAT covers open question, submit answer, first claim,
  reveal, reconnect, and close session.
- No manual database writes are needed for a pilot round.
