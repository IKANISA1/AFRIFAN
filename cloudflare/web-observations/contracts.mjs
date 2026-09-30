// Shared browser/server projection. No actor, location, navigation, payload or metric identifiers.
export const VITAL_NAMES = Object.freeze(['CLS','FCP','INP','LCP','TTFB']);
export const PWA_EVENTS = Object.freeze(['sw-update-ready','sw-update-applied','install-prompt-captured',
 'install-completed','install-prompt-accepted','install-prompt-dismissed',
 'ios-install-guide-shown','ios-install-guide-dismissed','push-subscribed','push-preview-sent']);
const RATINGS=['good','needs-improvement','poor'],SURFACES=['site','portal','live','admin','ios-guide'],
 MODES=['browser','standalone','minimal-ui'];
const object=v=>v!==null&&typeof v==='object'&&!Array.isArray(v);
const exact=(v,keys)=>object(v)&&Object.keys(v).length===keys.length&&keys.every(k=>Object.hasOwn(v,k));
const rounded=(name,value)=>name==='CLS'?Math.round(value*1000)/1000:Math.round(value/10)*10;
export function projectWebVital(value){try{
 if(!object(value)||!VITAL_NAMES.includes(value.name)||!RATINGS.includes(value.rating)||
  typeof value.value!=='number'||!Number.isFinite(value.value)||value.value<0||
  value.value>(value.name==='CLS'?10:600000))return null;
 return Object.freeze({schemaVersion:1,event:'web_vital',name:value.name,
  value:rounded(value.name,value.value),rating:value.rating});
}catch{return null;}}
export function projectPwaEvent(value){try{
 if(!object(value)||!PWA_EVENTS.includes(value.eventType)||!SURFACES.includes(value.surface)||
  !MODES.includes(value.displayMode))return null;
 return Object.freeze({schemaVersion:1,event:'pwa_event',eventType:value.eventType,
  surface:value.surface,displayMode:value.displayMode});
}catch{return null;}}
export function normalizeObservation(value){try{
 if(value?.schemaVersion!==1)return null;
 if(value.event==='web_vital'&&exact(value,['schemaVersion','event','name','value','rating'])){
  const projected=projectWebVital(value);return projected?.value===value.value?projected:null;
 }
 if(value.event==='pwa_event'&&exact(value,['schemaVersion','event','eventType','surface','displayMode']))
  return projectPwaEvent(value);
 return null;
}catch{return null;}}
export function parseObservationJson(raw){try{
 if(typeof raw!=='string'||new TextEncoder().encode(raw).byteLength>1024)return null;
 const value=JSON.parse(raw),keys=[...raw.matchAll(/"((?:\\.|[^"\\])*)"\s*:/g)]
  .map(match=>JSON.parse('"'+match[1]+'"'));
 if(!object(value)||keys.length!==Object.keys(value).length||new Set(keys).size!==keys.length)return null;
 return normalizeObservation(value);
}catch{return null;}}
export function observationConfiguration(env,store=false){try{
 if(env?.[store?'WEB_OBSERVATIONS_STORE_ENABLED':'WEB_OBSERVATIONS_ENABLED']!=='true'||
  env.WEB_OBSERVATIONS_ENVIRONMENT!=='isolated-staging')return null;
 const origin=new URL(env.WEB_OBSERVATIONS_ORIGIN);
 if(origin.protocol!=='https:'||origin.origin!==env.WEB_OBSERVATIONS_ORIGIN||
  origin.username||origin.password||origin.search||origin.hash)return null;
 const club=env.WEB_OBSERVATIONS_CLUB_ID,retention=env.WEB_OBSERVATIONS_RETENTION_MS,
  policyRef=env.WEB_OBSERVATIONS_POLICY_REF;
 if(typeof club!=='string'||!['6','24','26','44','1001'].includes(club)||
  typeof retention!=='string'||!/^[1-9][0-9]{0,10}$/.test(retention)||
  Number(retention)<3600000||Number(retention)>31622400000||
  typeof policyRef!=='string'||!/^[A-Z][A-Z0-9_-]{3,63}$/.test(policyRef))return null;
 return Object.freeze({origin:origin.origin,clubId:Number(club),retentionMs:Number(retention),policyRef});
}catch{return null;}}
