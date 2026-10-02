# Manual football synchronization commands

Forward migration31 and the corresponding `football-sync` Edge implementation
pass the complete local database and Edge checkpoints recorded in
[CURRENT_RELEASE](../release/CURRENT_RELEASE.md). This document describes that
source contract; hosted schema, function deployment and provider acceptance
are unverified.

Manual synchronization has global targets and requires the actual currently
assigned global administrator, a live Auth session and fresh TOTP assurance.
There is no selected-club input. The public admin website's LiveScore source
management is a separate workflow and is not an API-Football command client.

The operator retains one UUIDv4 operation identifier and the exact original
arguments before sending a manual POST. For example:

```json
{
  "action": "submit",
  "operation_id": "5da5c0c3-e001-4f79-b761-1c0c3a32ad58",
  "command": "sync-fixtures"
}
```

The example identifier is illustrative. Each genuinely new command needs its
own retained identifier. An uncertain response does not justify a new identifier
or repeating provider work. Check the original command with a separate POST:

```json
{
  "action": "status",
  "operation_id": "5da5c0c3-e001-4f79-b761-1c0c3a32ad58"
}
```

This `action: "status"` reads the original command record. The existing
`command: "status"` is an API-Football quota query and therefore still belongs
to an original submitted command. Legacy manual requests without the retained
identifier fail closed. Service cron requests retain their existing separate
cron-secret authority and command payloads.

Supported manual commands remain `discover-leagues`, `register-league`,
`sync-fixtures`, `sync-standings`, `sync-live`, `sync-history`, `download-logos`,
`seed-leagues`, `status`, `full-sync` and `auto-settle`. Their existing command
arguments are bounded and canonicalized; fields from a different command or
private dispatch-proof fields are rejected. Admission binds the original
arguments and authoritative global target snapshot to the actual caller.

The public receipt identifies the original operation, actor, global scope,
command, argument/snapshot hashes, state and bounded outcomes. Worker proof and
lease information stays private. Each provider request reserves its durable
attempt before dispatch. Original session, current global grant and assurance
deadline are checked after waits and at publication. A newer proof cannot give
an old worker authority.

An unknown API-Football or CDN request is retained for investigation and is not
sent again automatically. Manual logo upload requires the configured
`football-assets` bucket. An unknown upload may only reconcile the exact
original stored object and actual byte hash; it cannot fetch or upload a new
object. Ordinary cron bucket provisioning remains its existing separate path.

Roll out the forward database migration before the matching Edge function.
Verify the actual hosted function/schema identities, configured bucket and
provider behavior before admitting production use. Local tests and migration
replay do not establish those hosted outcomes.
