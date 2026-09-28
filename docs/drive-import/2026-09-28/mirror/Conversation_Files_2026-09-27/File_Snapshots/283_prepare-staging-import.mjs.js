import {readFileSync,writeFileSync,statSync,lstatSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
import {exact,demand,uuid,club,amount,timestamp,sha,reference,provider} from '../src/policy.mjs';
const shape={
 clubs:['club_id','club_slug','country','currency'],
 subjects:['user_id','club_id'],
 receivers:['receiver_id','club_id','partner_id','provider','country','currency','recipient'],
 memberships:['membership_id','user_id','club_id','partner_id','tier','status','payment_status','points','membership_number','member_code','renewed_at_ms','expires_at_ms'],
 orders:['order_id','source_intent_id','kind','user_id','club_id','partner_id','receiver_id','amount','currency','country','provider','recipient','tier','initiative_id','checkout_reference','expires_at_ms','created_at_ms','source_sha256'],
 historicalClaims:['provider','provider_reference','claim_ref','source_sha256']
};
const tables={clubs:'pa_clubs',subjects:'pa_subjects',receivers:'pa_receivers',memberships:'pa_memberships',orders:'pa_orders',historicalClaims:'pa_external_claims'};
/** Produces a disabled, parameterized import plan. It never executes or enables it. */
export function buildPlan(bytes,expectedHash) {
  demand(bytes instanceof Uint8Array&&bytes.byteLength<=16*1024*1024,'input_too_large');
  const sourceHash=createHash('sha256').update(bytes).digest('hex');demand(sha(expectedHash)&&sourceHash===expectedHash,'source_hash_mismatch');
  let input;try{input=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));}catch{demand(false,'invalid_import');}
  exact(input,['schemaVersion',...Object.keys(shape)]);demand(input.schemaVersion===1,'invalid_import');
  for(const [group,keys] of Object.entries(shape)){
    demand(Array.isArray(input[group])&&input[group].length<=10000,'invalid_import');
    for(const row of input[group])exact(row,keys);
  }
  demand(input.clubs.length>0&&input.clubs.length<=5,'invalid_import');
  const unique=(rows,key)=>{const values=rows.map(key);demand(new Set(values).size===values.length,'duplicate_import_identity');};
  for(const [group,key] of [['clubs','club_id'],['receivers','receiver_id'],['memberships','membership_id'],['orders','order_id']])unique(input[group],r=>r[key]);
  unique(input.clubs,r=>r.club_slug);unique(input.subjects,r=>`${r.club_id}:${r.user_id}`);
  unique(input.orders,r=>r.source_intent_id);unique(input.memberships,r=>`${r.club_id}:${r.user_id}`);
  unique(input.memberships,r=>r.membership_number);unique(input.memberships,r=>r.member_code);
  const clubs=new Map(input.clubs.map(r=>[r.club_id,r])),subjects=new Set(input.subjects.map(r=>`${r.club_id}:${r.user_id}`));
  for(const r of input.clubs)demand(club(r.club_id)&&/^[a-z][a-z0-9_-]{1,63}$/.test(r.club_slug)&&/^[A-Z]{2}$/.test(r.country)&&/^[A-Z]{3}$/.test(r.currency),'invalid_import');
  for(const r of input.subjects)demand(uuid(r.user_id)&&clubs.has(r.club_id),'invalid_import');
  for(const r of input.receivers){const c=clubs.get(r.club_id);demand(uuid(r.receiver_id)&&uuid(r.partner_id)&&c&&r.provider===provider(r.provider)&&r.country===c.country&&r.currency===c.currency&&/^[0-9]{3,32}$/.test(r.recipient),'invalid_import');}
  const receivers=new Map(input.receivers.map(r=>[r.receiver_id,r]));
  for(const r of input.memberships){
    demand(uuid(r.membership_id)&&subjects.has(`${r.club_id}:${r.user_id}`)&&uuid(r.partner_id)&&/^[a-z][a-z0-9_-]{0,63}$/.test(r.tier),'invalid_import');
    demand(['active','suspended','expired'].includes(r.status)&&['pending','verified'].includes(r.payment_status)&&Number.isSafeInteger(r.points)&&r.points>=0,'invalid_import');
    demand(reference(r.membership_number)&&/^[0-9]{6}$/.test(r.member_code)&&(r.renewed_at_ms===null||timestamp(r.renewed_at_ms))&&(r.expires_at_ms===null||timestamp(r.expires_at_ms)),'invalid_import');
  }
  for(const r of input.orders){
    const c=clubs.get(r.club_id),receiver=receivers.get(r.receiver_id);
    demand(uuid(r.order_id)&&uuid(r.source_intent_id)&&uuid(r.partner_id)&&subjects.has(`${r.club_id}:${r.user_id}`)&&receiver&&c,'invalid_import');
    demand(receiver.club_id===r.club_id&&receiver.partner_id===r.partner_id&&receiver.provider===r.provider&&receiver.recipient===r.recipient&&receiver.country===r.country&&receiver.currency===r.currency,'order_route_mismatch');
    demand(amount(r.amount)&&timestamp(r.created_at_ms)&&(r.expires_at_ms===null||timestamp(r.expires_at_ms))&&reference(r.checkout_reference)&&sha(r.source_sha256),'invalid_import');
    demand((r.kind==='membership'&&typeof r.tier==='string'&&/^[a-z][a-z0-9_-]{0,63}$/.test(r.tier)&&r.initiative_id===null&&r.expires_at_ms>r.created_at_ms)
      ||(r.kind==='contribution'&&r.tier===null&&uuid(r.initiative_id)&&r.currency==='RWF'&&r.amount>=100&&r.amount<=5000000),'invalid_import');
  }
  for(const r of input.historicalClaims)demand(r.provider===provider(r.provider)&&reference(r.provider_reference)&&reference(r.claim_ref)&&sha(r.source_sha256),'invalid_import');
  unique(input.historicalClaims,r=>`${r.provider}:${r.provider_reference}`);
  const statements=[];
  for(const group of Object.keys(shape))for(const inputRow of input[group]){
    const row={...inputRow};if(group==='historicalClaims')row.origin='historical';
    const keys=Object.keys(row);statements.push({sql:`INSERT INTO ${tables[group]}(${keys.join(',')}) VALUES(${keys.map(()=>'?').join(',')})`,params:keys.map(k=>row[k])});
  }
  return {schemaVersion:1,sourceSha256:sourceHash,purpose:'disabled-isolated-staging-import',
    sourceReconciliationVerified:false,historicalDeduplicationComplete:false,productionReleaseAuthorized:false,
    counts:Object.fromEntries(Object.keys(shape).map(k=>[k,input[k].length])),statements};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
  try{const [source,output,expected,...extra]=process.argv.slice(2);demand(source&&output&&expected&&extra.length===0,'usage_input_output_sha256');
    demand(!lstatSync(source).isSymbolicLink()&&statSync(source).size<=16*1024*1024,'invalid_input_file');
    const plan=buildPlan(readFileSync(source),expected);writeFileSync(output,JSON.stringify(plan,null,2)+'\n',{flag:'wx',mode:0o600});
    console.log(JSON.stringify({written:true,counts:plan.counts,disabled:true,sourceSha256:plan.sourceSha256}));
  }catch(error){console.error(error.code??'import_plan_failed');process.exitCode=1;}
}
