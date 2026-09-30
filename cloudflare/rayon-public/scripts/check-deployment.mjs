import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

const expectedDatabase = {
 binding:'RAYON_PUBLIC_DB',database_name:'africlub-rayon-public-staging',
 database_id:'18893ae3-e504-457f-a196-bfc075edada6',migrations_dir:'migrations',
};
const expectedBucket = {binding:'RAYON_PUBLIC_MEDIA',bucket_name:'africlub-rayon-public-media-staging'};
const templates = [
 {file:'wrangler.publisher.staging.jsonc',name:'africlub-rayon-public-publisher-staging',
  main:'src/publication-worker.mjs',compatibility_date:'2026-08-08',vars:{PUBLICATION_ENABLED:'false'}},
 {file:'wrangler.authorized-publisher.staging.jsonc',name:'africlub-rayon-authorized-publisher-staging',
  main:'src/authorized-publication-worker.mjs',compatibility_date:'2026-09-26',
  vars:{PUBLICATION_ENABLED:'false',TARGET_CLUB_ID:'24',ACCESS_AUD:'',ACCESS_ACCOUNT_ID:''}},
];
function same(actual, expected) {
 if (!actual || typeof actual!=='object' || Array.isArray(actual)!==Array.isArray(expected)) return false;
 if (Array.isArray(expected)) return actual.length===expected.length && actual.every((v,i)=>same(v,expected[i]));
 const keys=Object.keys(expected);
 return Object.keys(actual).length===keys.length && keys.every(k=>
  expected[k]!==null && typeof expected[k]==='object' ? same(actual[k],expected[k]) : actual[k]===expected[k]);
}
export function validateDisabledPublication(config, templateName) {
 const t=templates.find(v=>v.file===templateName);
 if(!t)throw new Error('unknown_publication_template');
 const expected={name:t.name,main:t.main,compatibility_date:t.compatibility_date,
  workers_dev:false,preview_urls:false,vars:t.vars,d1_databases:[expectedDatabase],r2_buckets:[expectedBucket]};
 if(!same(config,expected))throw new Error('disabled_publication_configuration_mismatch');
 return {template:templateName,publicationEnabled:false,publicUrlEnabled:false,
  databaseVerified:true,bucketVerified:true,operatorConfigured:false,runtimeReady:false};
}
export function checkDisabledPublicationTemplates() {
 return templates.map(t=>validateDisabledPublication(JSON.parse(readFileSync(new URL('../'+t.file,import.meta.url),'utf8')),t.file));
}
if(process.argv[1] && path.resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
 try { console.log(JSON.stringify({schemaVersion:1,status:'disabled_templates_verified',templates:checkDisabledPublicationTemplates()},null,2)); }
 catch(error) { console.error(error.message);process.exitCode=1; }
}
