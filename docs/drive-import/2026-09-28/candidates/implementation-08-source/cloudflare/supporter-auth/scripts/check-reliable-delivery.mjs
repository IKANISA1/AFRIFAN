import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {queuePolicy} from '../src/delivery-policy.mjs';
export function checkHealthConfiguration(c, {ready = false} = {}) {
  const demand = (ok) => {if (!ok) throw new Error('invalid_health_configuration');};
  demand(c?.name === 'africlub-otp-queue-health-staging' && c.main === 'src/delivery-health-worker.mjs');
  demand(c.workers_dev === false && c.preview_urls === false && Array.isArray(c.routes) && !c.routes.length);
  demand(!c.services?.length && !c.triggers?.crons?.length && c.observability?.enabled === false);
  demand(c.d1_databases?.length === 1 && c.d1_databases[0].binding === 'AUTH_DB');
  const vars = c.vars;
  demand(vars && Object.keys(vars).sort().join('|') === ['AUTH_DELIVERY_HEALTH_ENABLED','AUTH_DELIVERY_MODE','AUTH_DELIVERY_POLICY_JSON'].sort().join('|'));
  demand(vars.AUTH_DELIVERY_MODE === 'private-deduplicated');
  if (ready) {
    demand(vars.AUTH_DELIVERY_HEALTH_ENABLED === 'true' && /^[a-f0-9]{32}$/.test(c.account_id));
    demand(/^[a-f0-9-]{36}$/.test(c.d1_databases[0].database_id));queuePolicy(vars);
  } else demand(vars.AUTH_DELIVERY_HEALTH_ENABLED === 'false');
  return {configuration: ready ? 'ready_shape_only' : 'disabled', liveAccessVerified:false, operatorAuthorizationVerified:false};
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {console.log(JSON.stringify(checkHealthConfiguration(JSON.parse(readFileSync(process.argv[2] ?? new URL('../wrangler.delivery-health.staging.jsonc', import.meta.url), 'utf8')), {ready: process.argv.includes('--ready')})));}
  catch {console.error('invalid_health_configuration');process.exitCode=1;}
}
