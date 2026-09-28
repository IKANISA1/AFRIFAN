import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {AuthenticationCodeDeliveryService} from '../src/service.mjs';
export const NOW=Date.UTC(2026,8,26,13,0),PHONE='+250700000001';
export class Db {
 constructor(){this.sql=new DatabaseSync(':memory:');this.sql.exec(readFileSync(new URL('../migrations/0001_dispatch_claims.sql',import.meta.url),'utf8'));this.failInsert=false;this.failUpdate=false;this.loseInsert=false;this.loseUpdate=false;}
 withSession(p){if(p!=='first-primary')throw new Error('not primary');return this;}
 prepare(sql){const db=this;return {args:[],bind(...a){return {...this,args:a};},async first(){
  if(db.failInsert&&sql.startsWith('INSERT'))throw new Error('injected db failure');
  const r=db.sql.prepare(sql).get(...this.args)??null;
  if(db.loseInsert&&sql.startsWith('INSERT')){db.loseInsert=false;throw new Error('lost insert reply');}return r;},
  async run(){if(db.failUpdate)throw new Error('injected update failure');const r=db.sql.prepare(sql).run(...this.args);
  if(db.loseUpdate){db.loseUpdate=false;throw new Error('lost update reply');}return {meta:{changes:Number(r.changes)}};}};}
 close(){this.sql.close();}
}
export function fixture(){
 const db=new Db();let now=NOW;
 const route={clubId:24,phoneNumberId:'100000000000001',templateId:'100000000000002',templateName:'africlub_auth',language:'en_US',reviewRef:'TEST-ONLY-NOT-APPROVAL',reviewExpiresAt:NOW+86400000};
 const env={DELIVERY_ENABLED:'true',DELIVERY_DB:db,WA_ACCESS_TOKEN:'synthetic-credential-for-tests-only-not-real',DISPATCH_HMAC_KEY:'a2'.repeat(32),WA_GRAPH_VERSION:'v99.0',DELIVERY_ROUTES_JSON:JSON.stringify([route])};
 const input={challengeId:crypto.randomUUID(),clubId:24,phone:PHONE,code:'012345',expiresAt:NOW+300000,channel:'whatsapp'};
 const calls=[];let override=null;
 const template=()=>({id:route.templateId,name:route.templateName,language:route.language,status:'APPROVED',category:'AUTHENTICATION'});
 const success=(request=input)=>({messaging_product:'whatsapp',contacts:[{input:request.phone.slice(1),wa_id:request.phone.slice(1)}],messages:[{id:'wamid.SYNTHETIC',message_status:'accepted'}]});
 const fetcher=async(url,init)=>{calls.push({url,init});if(override)return override(url,init);
  return Response.json(init.method==='GET'?template():success());};
 const service=new AuthenticationCodeDeliveryService(env,{clock:()=>now,fetcher});
 return {db,route,env,input,service,calls,template,success,fetcher,now:()=>now,advance(ms){now+=ms;},override(fn){override=fn;},close(){db.close();}};
}
