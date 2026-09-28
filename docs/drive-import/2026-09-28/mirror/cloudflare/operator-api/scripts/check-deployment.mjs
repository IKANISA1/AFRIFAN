#!/usr/bin/env node
import {readFileSync} from 'node:fs';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {HEX64} from '../src/errors.mjs';

/** Configuration checks are NOT proof that remote Access policies are installed. */
export function checkDeployment(gateway,publisher,{ready=false}={}) {
  const failures=[];
  const check=(condition,message)=>{if(!condition)failures.push(message);};
  for(const [name,config] of [['gateway',gateway],['publisher',publisher]]) {
    check(config.workers_dev===false && config.preview_urls===false,`${name}: alternate ingress must be disabled`);
    check(!config.assets,`${name}: Static Assets hides the runtime Access context`);
    check(!config.access?.dev,`${name}: simulated identity must not enter deployment configuration`);
    check(config.compatibility_date==='2026-09-26',`${name}: review any compatibility-date change`);
    check(!config.env,`${name}: validate the fully resolved environment, not an unreviewed env override`);
  }
  check(gateway.main==='src/index.mjs','gateway: incorrect entrypoint');
  check(publisher.main==='src/authorized-publication-worker.mjs','publisher: incorrect entrypoint');
  check(!publisher.routes?.length&&!publisher.route,'publisher: private RPC worker must have no public route');
  check(!gateway.d1_databases?.length&&!gateway.r2_buckets?.length,'gateway: storage access belongs only to the publisher');
  const binding=gateway.services?.find(x=>x.binding==='PUBLIC_SOURCE_PUBLISHER');
  check(gateway.services?.length===1 && binding?.entrypoint==='AuthorizedPublicSourcePublisher' && binding?.service===publisher.name,
    'gateway: bind only the authorized publisher entrypoint');
  check(publisher.vars?.TARGET_CLUB_ID==='24','publisher: this delivery is scoped to the Rayon staging database');
  check(publisher.d1_databases?.length===1 && publisher.d1_databases[0].binding==='RAYON_PUBLIC_DB' &&
    publisher.d1_databases[0].database_id==='18893ae3-e504-457f-a196-bfc075edada6','publisher: unreviewed staging database binding');
  check(publisher.r2_buckets?.length===1 && publisher.r2_buckets[0].binding==='RAYON_PUBLIC_MEDIA' &&
    publisher.r2_buckets[0].bucket_name==='africlub-rayon-public-media-staging','publisher: unreviewed staging media binding');
  const gv=gateway.vars??{},pv=publisher.vars??{};
  if(!ready) {
    check(gv.OPERATOR_API_ENABLED==='false' && pv.PUBLICATION_ENABLED==='false','template: both publication switches must be disabled');
    check(!gateway.routes?.length&&!gateway.route,'template: no public routes should be provisioned');
    check(gv.ACCESS_AUD===''&&pv.ACCESS_AUD===''&&gv.ACCESS_ACCOUNT_ID===''&&pv.ACCESS_ACCOUNT_ID==='',
      'template: account and audience must be supplied from independently verified Access configuration');
  } else {
    check(gv.OPERATOR_API_ENABLED==='true'&&pv.PUBLICATION_ENABLED==='true','ready: both switches must be explicitly enabled');
    check(HEX64.test(gv.ACCESS_AUD??'') && gv.ACCESS_AUD===pv.ACCESS_AUD,'ready: exact matching Access audiences required');
    check(/^[a-f0-9]{32}$/.test(gv.ACCESS_ACCOUNT_ID??'') && gv.ACCESS_ACCOUNT_ID===pv.ACCESS_ACCOUNT_ID,'ready: exact matching Access accounts required');
    let origin=null;try{origin=new URL(gv.OPERATOR_API_ORIGIN);}catch{}
    check(origin?.protocol==='https:' && origin?.origin===gv.OPERATOR_API_ORIGIN && !origin?.username&&!origin?.password,'ready: exact HTTPS origin required');
    const routes=gateway.routes??[];
    check(!gateway.route && routes.length===1 && routes[0].custom_domain===true && routes[0].pattern===origin?.hostname,
      'ready: one reviewed same-origin custom domain required');
  }
  return {mode:ready?'configuration-ready-only':'disabled-template',failures,
    liveAccessVerified:false,remoteRuntimeVerified:false,releaseAuthorized:false};
}
if(import.meta.url===pathToFileURL(process.argv[1]??'').href) {
  const args=process.argv.slice(2),ready=args.includes('--ready');
  const positional=args.filter(x=>x!=='--ready');
  if(args.some(x=>x.startsWith('--')&&x!=='--ready')||positional.length>2) {
    console.error('Usage: node check-deployment.mjs [gateway.json publisher.json] [--ready]');process.exit(2);
  }
  try {
    const gateway=JSON.parse(readFileSync(positional[0]??fileURLToPath(new URL('../wrangler.staging.jsonc',import.meta.url)),'utf8'));
    const publisher=JSON.parse(readFileSync(positional[1]??fileURLToPath(new URL('../../rayon-public/wrangler.authorized-publisher.staging.jsonc',import.meta.url)),'utf8'));
    const result=checkDeployment(gateway,publisher,{ready});console.log(JSON.stringify(result,null,2));
    process.exitCode=result.failures.length?1:0;
  }catch{console.error('Configuration could not be read as strict JSON.');process.exitCode=2;}
}
