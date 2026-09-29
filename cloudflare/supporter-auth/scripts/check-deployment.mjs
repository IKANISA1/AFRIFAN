import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';

const ZERO = '00000000-0000-0000-0000-000000000000';
const baseKeys = ['name','main','compatibility_date','workers_dev','preview_urls','routes','observability','d1_databases','vars','services'];
const sameKeys = (o, keys) => o && typeof o === 'object' && !Array.isArray(o) &&
  Object.keys(o).length === keys.length && keys.every(k => Object.hasOwn(o,k));
const gatewayVars = ['AUTH_SERVICE_ENABLED','AUTH_DELIVERY_ENABLED','AUTH_KEY_VERSION','AUTH_ORIGIN',
  'AUTH_ISSUANCE_POLICY_JSON','AUTH_DELIVERY_MODE','AUTH_DELIVERY_POLICY_JSON'];

/** Disabled source templates only. Never provisions, authorizes or enables anything. */
export function checkDeployment(configs) {
  const errors = [], check = (ok, message) => {if (!ok) errors.push(message);};
  if (!Array.isArray(configs) || configs.length !== 2) return {configurationPassed:false, errors:['two identity configurations required'], deployable:false};
  configs.forEach((c, i) => {
    const label = i === 0 ? 'native' : 'verifier';
    check(sameKeys(c, i === 0 ? [...baseKeys,'ratelimits'] : baseKeys), `${label}: unexpected keys or bindings`);
    check(c?.name === (i === 0 ? 'africlub-supporter-identity-staging' : 'africlub-supporter-identity-verifier-staging') &&
      c?.main === (i === 0 ? 'src/index.mjs' : 'src/identity-verifier-worker.mjs'), `${label}: wrong worker entrypoint`);
    check(c?.compatibility_date === '2026-09-28', `${label}: unexpected compatibility version`);
    check(c?.workers_dev === false && c?.preview_urls === false && Array.isArray(c?.routes) && c.routes.length === 0,
      `${label}: template public ingress forbidden`);
    check(sameKeys(c?.observability,['enabled']) && c.observability.enabled === false, `${label}: invocation logging forbidden`);
    const db = c?.d1_databases?.[0];
    check(Array.isArray(c?.d1_databases) && c.d1_databases.length === 1 &&
      sameKeys(db,['binding','database_name','database_id','migrations_dir']) && db.binding === 'AUTH_DB' &&
      db.database_name === 'africlub-supporter-identity-staging' && db.database_id === ZERO && db.migrations_dir === 'migrations',
      `${label}: isolated placeholder identity database required`);
    check(sameKeys(c?.vars,i === 0 ? gatewayVars : ['AUTH_SERVICE_ENABLED','AUTH_KEY_VERSION']), `${label}: unexpected variables or plaintext secrets`);
    check(c?.vars?.AUTH_SERVICE_ENABLED === 'false' && c?.vars?.AUTH_KEY_VERSION === '1', `${label}: disabled version-one identity required`);
    if (i === 0) {
      check(c?.vars?.AUTH_DELIVERY_ENABLED === 'false' && c.vars.AUTH_ORIGIN === '' &&
        c.vars.AUTH_ISSUANCE_POLICY_JSON === '' && c.vars.AUTH_DELIVERY_POLICY_JSON === '' &&
        c.vars.AUTH_DELIVERY_MODE === 'private-deduplicated', 'native: disabled reviewed-private queue template required');
      const service = c?.services?.[0];
      check(Array.isArray(c?.services) && c.services.length === 1 && sameKeys(service,['binding','service','entrypoint']) &&
        service.binding === 'OTP_DELIVERY' && service.service === 'africlub-auth-code-delivery-staging' &&
        service.entrypoint === 'AuthenticationCodeDelivery', 'native: exclusive private delivery binding required');
      const rate = c?.ratelimits?.[0];
      check(Array.isArray(c?.ratelimits) && c.ratelimits.length === 1 && sameKeys(rate,['name','namespace_id','simple']) &&
        rate.name === 'AUTH_EDGE_LIMIT' && rate.namespace_id === '0' && sameKeys(rate.simple,['limit','period']) &&
        rate.simple.limit === 100 && rate.simple.period === 60, 'native: isolated placeholder edge rate binding required');
    } else check(Array.isArray(c?.services) && c.services.length === 0, 'verifier: provider/outbound bindings forbidden');
  });
  return {configurationPassed:errors.length === 0, errors, templatesOnly:true, deployable:false,
    enabled:false, liveImportVerified:false, secretsProvisioned:false, actualCloudflareRuntimeVerified:false,
    providerAcceptanceVerified:false, supabaseRetired:false, releaseAuthorized:false, deploymentPerformed:false};
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const paths = process.argv.slice(2);
    if (paths.length !== 0 && paths.length !== 2) throw new Error();
    const defaults = ['wrangler.native-identity.staging.jsonc','wrangler.identity-verifier.staging.jsonc'];
    const result = checkDeployment((paths.length ? paths : defaults.map(p => new URL('../'+p,import.meta.url)))
      .map(p => JSON.parse(readFileSync(p,'utf8'))));
    console.log(JSON.stringify(result,null,2));
    if (!result.configurationPassed) process.exitCode = 1;
  } catch {console.error('invalid_identity_configuration');process.exitCode = 1;}
}
