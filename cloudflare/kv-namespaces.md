# Fantasy KV Namespaces

Create a dedicated KV namespace for the fantasy worker and bind it as `FANTASY_KV`.

Recommended keys:

- `live_fixtures:{league}:{season}` for cached live fixture payloads
- `fixture_players:{fixtureId}` for cached player stat payloads
- `competition_id:{slug}` for active competition lookup
- `active_gw:{slug}` for the live or next gameweek id

Suggested TTLs:

- live fixtures: 90 seconds
- fixture players: 90 seconds
- competition id: 10 minutes
- active gameweek id: 5 minutes
