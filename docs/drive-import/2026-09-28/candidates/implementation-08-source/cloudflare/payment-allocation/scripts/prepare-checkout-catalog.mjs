import {readFileSync,writeFileSync,statSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {uuid,club,provider,exact,hash,MAX_AMOUNT} from '../src/policy.mjs';
import {requireCheckout as need,CheckoutError} from '../src/checkout-policy.mjs';
const checksum=bytes=>createHash('sha256').update(bytes).digest('hex');
function optionalPrice(n){return n===null||(Number.isSafeInteger(n)&&n>=0&&n<=MAX_AMOUNT);}
/** Minimal catalog projection only. No raw database dump conversion or activation. */
export async function planCheckoutCatalog(bytes,expectedHash){
 need(bytes.byteLength<=1048576&&/^[a-f0-9]{64}$/.test(expectedHash)&&checksum(bytes)===expectedHash,'source_hash_mismatch');
 let v;try{v=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));}catch{throw new CheckoutError('invalid_catalog');}
 try{exact(v,['schemaVersion','sourceProject','clubs','packages','routes']);}catch{throw new CheckoutError('invalid_catalog');}
 need(v.schemaVersion===1&&typeof v.sourceProject==='string'&&/^[A-Za-z0-9_-]{3,100}$/.test(v.sourceProject),'invalid_catalog');
 need(Array.isArray(v.clubs)&&v.clubs.length>0&&v.clubs.length<=5&&Array.isArray(v.packages)&&v.packages.length<=500&&Array.isArray(v.routes)&&v.routes.length<=500,'invalid_catalog');
 const clubs=new Set(),packages=new Set(),routes=new Set(),statements=[];
 for(const c of v.clubs){
  exact(c,['clubId','ussdTemplate']);need(club(c.clubId)&&!clubs.has(c.clubId),'duplicate_club');clubs.add(c.clubId);
  need(typeof c.ussdTemplate==='string'&&c.ussdTemplate.length<=128&&c.ussdTemplate.includes('{amount}')&&/\{(?:recipient|momo|code)\}/.test(c.ussdTemplate),'invalid_payment_route');
  need(/^\*[0-9*]+#$/.test(c.ussdTemplate.replaceAll('{amount}','100').replaceAll('{momo}','123456').replaceAll('{recipient}','123456').replaceAll('{code}','123456')),'invalid_payment_route');
  statements.push({sql:'INSERT INTO pa_checkout_clubs(club_id,ussd_template,active,source_sha256) VALUES(?,?,0,?)',params:[c.clubId,c.ussdTemplate,await hash(c)]});
 }
 for(const p of v.packages){
  exact(p,['id','clubId','partnerId','tier','annualPrice','price','sortOrder','isActive']);
  need(uuid(p.id)&&!packages.has(p.id),'duplicate_package');packages.add(p.id);
  need(clubs.has(p.clubId)&&uuid(p.partnerId)&&typeof p.tier==='string'&&/^[a-z0-9][a-z0-9_-]{0,31}$/.test(p.tier)&&optionalPrice(p.annualPrice)&&optionalPrice(p.price)&&Number.isSafeInteger(p.sortOrder)&&typeof p.isActive==='boolean','invalid_package');
  statements.push({sql:'INSERT INTO pa_checkout_packages(package_id,club_id,partner_id,tier,annual_price,price,sort_order,active,source_sha256) VALUES(?,?,?,?,?,?,?,0,?)',params:[p.id,p.clubId,p.partnerId,p.tier,p.annualPrice,p.price,p.sortOrder,await hash(p)]});
 }
 for(const x of v.routes){
  exact(x,['id','clubId','partnerId','provider','country','recipient','isActive']);
  need(uuid(x.id)&&!routes.has(x.id),'duplicate_route');routes.add(x.id);
  need(clubs.has(x.clubId)&&uuid(x.partnerId)&&typeof x.country==='string'&&/^[A-Z]{2}$/.test(x.country)&&typeof x.recipient==='string'&&/^[0-9]{3,32}$/.test(x.recipient)&&typeof x.isActive==='boolean','invalid_route');
  const canonical=provider(x.provider);
  statements.push({sql:'INSERT INTO pa_checkout_routes(route_id,club_id,partner_id,provider,country,recipient,active,source_sha256) VALUES(?,?,?,?,?,?,0,?)',params:[x.id,x.clubId,x.partnerId,canonical,x.country,x.recipient,await hash(x)]});
 }
 return {schemaVersion:1,kind:'disabled-membership-catalog-plan',sourceProject:v.sourceProject,sourceSha256:expectedHash,
 counts:{clubs:clubs.size,packages:packages.size,routes:routes.size},allControlsDisabled:true,permissionsGranted:false,executed:false,
 sourceStates:{activePackages:v.packages.filter(p=>p.isActive).map(p=>p.id),activeRoutes:v.routes.filter(p=>p.isActive).map(p=>p.id)},statements};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 try{const [input,output,expected,...rest]=process.argv.slice(2);need(input&&output&&expected&&!rest.length,'usage');need(statSync(input).size<=1048576,'invalid_catalog');
  const plan=await planCheckoutCatalog(readFileSync(input),expected);const bytes=JSON.stringify(plan,null,2)+'\n';
  writeFileSync(output,bytes,{flag:'wx',mode:0o600});console.log(JSON.stringify({output,sha256:checksum(Buffer.from(bytes)),counts:plan.counts,executed:false,enabled:false}));
 }catch{console.error('catalog_plan_failed');process.exitCode=1;}
}
