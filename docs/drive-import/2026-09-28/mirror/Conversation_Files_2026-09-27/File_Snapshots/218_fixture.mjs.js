import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import { OperatorPublicationService, serviceResult } from '../../../rayon-public/src/operator-publication.mjs';
import { PUBLIC_SOURCE_TABLES,sha256 } from '../../../rayon-public/src/snapshot-publication.mjs';
import gateway from '../../src/index.mjs';
// This adapter runs genuine SQLite SQL but is NOT a Cloudflare D1 emulator.
export class Database {
  constructor(){
    this.sqlite=new DatabaseSync(':memory:');this.sqlite.exec('PRAGMA foreign_keys=ON');
    for(const file of ['0001_source_staging.sql','0002_snapshot_publication.sql','0003_immutable_public_snapshots.sql','0004_operator_publication.sql'])
      this.sqlite.exec(readFileSync(new URL(`../../../rayon-public/migrations/${file}`,import.meta.url),'utf8'));
    this.failAt=null;this.afterCommitError=false;this.beforeBatch=null;this.sessions=[];
  }
  withSession(mode){this.sessions.push(mode);return this;}
  prepare(sql){const db=this;return {sql,args:[],bind(...args){return {...this,args};},
    async first(){return db.sqlite.prepare(sql).get(...this.args)??null;},
    async all(){return {results:db.sqlite.prepare(sql).all(...this.args)};},
    async run(){const r=db.sqlite.prepare(sql).run(...this.args);return {success:true,meta:{changes:Number(r.changes)}};}};}
  async batch(statements){
    if(this.beforeBatch){const fn=this.beforeBatch;this.beforeBatch=null;await fn();}
    // D1 batch does not yield between statements. Preserve that atomicity here.
    this.sqlite.exec('BEGIN IMMEDIATE');
    const results=[];
    try {
      for(let i=0;i<statements.length;i++){
        if(this.failAt===i)throw new Error('injected SQL failure containing sensitive internal details');
        const s=statements[i],r=this.sqlite.prepare(s.sql).run(...s.args);results.push({success:true,meta:{changes:Number(r.changes)}});
      }
      this.sqlite.exec('COMMIT');
    }catch(error){this.sqlite.exec('ROLLBACK');throw error;}
    if(this.afterCommitError){this.afterCommitError=false;throw new Error('response lost after commit');}
    return results;
  }
}
export const ACCOUNT='a'.repeat(32),AUD='b'.repeat(64),SUBJECT='11111111-1111-4111-8111-111111111111',PRINCIPAL='22222222-2222-4222-8222-222222222222';
export const ASSET='33333333-3333-4333-8333-333333333333';
export function fixture(t){
 const db=new Database();t.after(()=>db.sqlite.close());
 const clock={now:Date.now()};const blobs=new Map();let onMedia=null;
 const bucket={async get(key){if(onMedia){const fn=onMedia;onMedia=null;await fn();}const b=blobs.get(key);return b?{
   size:b.length,async arrayBuffer(){return b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength)},
   get body(){return new Uint8Array(b)},writeHttpMetadata(h){h.set('content-type','image/png')}}:null;}};
 const env={PUBLICATION_ENABLED:'true',TARGET_CLUB_ID:'24',ACCESS_ACCOUNT_ID:ACCOUNT,ACCESS_AUD:AUD,RAYON_PUBLIC_DB:db,RAYON_PUBLIC_MEDIA:bucket};
 const service=new OperatorPublicationService(env,{clock:()=>clock.now});
 const identity={accountId:ACCOUNT,audience:AUD,subject:SUBJECT};
 db.sqlite.prepare('INSERT INTO public_operator_tenants(club_id,club_slug,source_club_id,enabled) VALUES(?,?,?,1)').run(24,'rayon_sports_rw','source-24');
 db.sqlite.prepare('INSERT INTO public_operator_principals(principal_id,access_account_id,access_subject,enabled) VALUES(?,?,?,1)').run(PRINCIPAL,ACCOUNT,SUBJECT);
 db.sqlite.prepare('INSERT INTO public_operator_grants(principal_id,club_id,can_review,can_publish,enabled,expires_at_ms) VALUES(?,?,1,1,1,?)').run(PRINCIPAL,24,clock.now+3600000);
 const ctx={access:{aud:AUD,async getIdentity(){return {account_id:ACCOUNT,user_uuid:SUBJECT,email:'synthetic@example.invalid',service_token_status:false}}}};
 const rpc={};for(const method of ['head','review','publish','publication'])rpc[method]=input=>serviceResult(service,method,input);
 const httpEnv={OPERATOR_API_ENABLED:'true',OPERATOR_API_ORIGIN:'https://operator.example.invalid',ACCESS_AUD:AUD,ACCESS_ACCOUNT_ID:ACCOUNT,PUBLIC_SOURCE_PUBLISHER:rpc};
 const call=(resource,{method,body,headers={},envOverride={},context=ctx,url}={})=>gateway.fetch(new Request(url??`https://operator.example.invalid/v1/admin/clubs/24/public-source/${resource}`,{
   method:method??(body?'POST':'GET'),headers:{...(body?{'content-type':'application/json','origin':'https://operator.example.invalid','x-africlub-action':'publish-review'}:{}),...headers},
   ...(body===undefined?{}:{body:typeof body==='string'?body:JSON.stringify(body)})}),{...httpEnv,...envOverride},context);
 return {db,clock,blobs,bucket,env,service,identity,ctx,httpEnv,call,mediaHook(fn){onMedia=fn},
   review:async(s,previous=null)=>service.review({identity,clubId:24,snapshotId:s.id,expectedPreviousId:previous,reviewRef:'review:synthetic'}),
   publish:async(r,key='request_key_12345678')=>service.publish({identity,clubId:24,reviewId:r.reviewId,idempotencyKey:key}),
   sql:(s,...args)=>db.sqlite.prepare(s).all(...args)};
}
export async function imported(f,{title='Synthetic news',at=f.clock.now-1000,source='source-24',media=true}={}){
 const shared={club_id:source,approval_status:'approved',active:true,visibility:'public'};
 const rows=Object.fromEntries(PUBLIC_SOURCE_TABLES.map(t=>[t,[]]));rows.clubs=[{id:source,slug:'rayon_sports_rw'}];
 rows.news_posts=[{...shared,id:'news-1',title,excerpt:'Synthetic approved excerpt',status:'published',post_type:'news_feed',
   published_at:new Date(at).toISOString(),source_url:'https://club.example.invalid/news'}];
 const bytes=new TextEncoder().encode('synthetic image content'),hash=await sha256(bytes);
 const mediaRows=[];
 if(media){rows.media_assets=[{...shared,id:ASSET,storage_bucket:'source',storage_path:'image.png',checksum_sha256:hash,
   usage_rights:'club-approved',usage_scopes:['squad']}];rows.players=[{...shared,id:'player-1',display_name:'Synthetic player',photo_asset_id:ASSET}];
   mediaRows.push([ASSET,'source','image.png',bytes.length,hash,['squad'],'club-approved',`assets/${hash}.bin`]);}
 const records=[];
 for(const table of PUBLIC_SOURCE_TABLES)for(const row of rows[table]){const payload=JSON.stringify(row);records.push([table,String(row.id),source,payload,await sha256(payload)]);}
 const manifest={schemaVersion:1,sourceClubId:source,capturedAt:new Date(at).toISOString(),tables:Object.fromEntries(PUBLIC_SOURCE_TABLES.map(t=>[t,rows[t].length])),records:records.map(([t,id,,p,h])=>[t,id,h]),media:mediaRows};
 const text=JSON.stringify(manifest),id=await sha256(text);
 f.db.sqlite.prepare('INSERT INTO public_snapshots(snapshot_id,source_club_id,captured_at_utc,manifest_json) VALUES(?,?,?,?)').run(id,source,new Date(at).toISOString(),text);
 for(const r of records)f.db.sqlite.prepare('INSERT INTO public_snapshot_records VALUES(?,?,?,?,?,?)').run(id,...r);
 for(const [a,b,p,n,h,s,r,k] of mediaRows)f.db.sqlite.prepare('INSERT INTO public_snapshot_media VALUES(?,?,?,?,?,?,?,?,?)').run(id,a,b,p,n,h,JSON.stringify(s),r,k);
 if(media)f.blobs.set(`assets/${hash}.bin`,bytes);
 return {id,hash,bytes};
}
