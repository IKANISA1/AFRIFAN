import test from 'node:test';import assert from 'node:assert/strict';
import {mkdtempSync,writeFileSync,mkdirSync,symlinkSync,linkSync,rmSync} from 'node:fs';import {tmpdir} from 'node:os';import {join} from 'node:path';
import {generateKeyPairSync,sign} from 'node:crypto';
import {sealArtifact,verifyArtifact,verifyApprovals,digest} from '../release/candidate-integrity.mjs';
const commit='a'.repeat(40),now=Date.now();
function fixture(t){const root=mkdtempSync(join(tmpdir(),'africlub-integrity-'));t.after(()=>rmSync(root,{force:true,recursive:true}));writeFileSync(join(root,'worker.mjs'),'export default {};\n');return root;}
function signed(){const pairs=['security','operations','product','privacy'].map((role,i)=>({...generateKeyPairSync('ed25519'),role,keyId:'test_'+i}));const hash='b'.repeat(64);
 const keys=pairs.map(p=>({keyId:p.keyId,role:p.role,publicKeyPem:p.publicKey.export({type:'spki',format:'pem'}),revoked:false}));
 const approvals={schemaVersion:1,approvals:pairs.map(p=>{const payload={schemaVersion:1,candidateCommit:commit,artifactDigest:hash,environment:'production',role:p.role,keyId:p.keyId,issuedAt:now-1000,expiresAt:now+60000};return {payload,signature:sign(null,Buffer.from(JSON.stringify(payload)),p.privateKey).toString('base64')};})};return {pairs,keys,approvals,hash};}
test('sealed artifact roundtrip verifies all files against trusted hash',t=>{const root=fixture(t),m=sealArtifact(root,commit);assert.equal(verifyArtifact(root,m,commit,m.artifactDigest).fileCount,1);});
test('changed runtime byte fails verification',t=>{const root=fixture(t),m=sealArtifact(root,commit);writeFileSync(join(root,'worker.mjs'),'different');assert.throws(()=>verifyArtifact(root,m,commit,m.artifactDigest),/contents/);});
test('additional executable fails verification',t=>{const root=fixture(t),m=sealArtifact(root,commit);writeFileSync(join(root,'extra.js'),'x');assert.throws(()=>verifyArtifact(root,m,commit,m.artifactDigest),/contents/);});
test('missing file fails verification',t=>{const root=fixture(t),m=sealArtifact(root,commit);writeFileSync(join(root,'other'),'x');rmSync(join(root,'worker.mjs'));assert.throws(()=>verifyArtifact(root,m,commit,m.artifactDigest),/contents/);});
test('manifest cannot replace trusted target commit',t=>{const root=fixture(t),m=sealArtifact(root,commit);assert.throws(()=>verifyArtifact(root,m,'c'.repeat(40),m.artifactDigest),/identity/);});
test('manifest cannot replace trusted digest',t=>{const root=fixture(t),m=sealArtifact(root,commit);assert.throws(()=>verifyArtifact(root,m,commit,'c'.repeat(64)),/identity/);});
for(const name of ['.env.local','upload-keystore.jks','keystore.properties','key.pem','credentials.json','service-account-prod.json'])test('artifact denies sensitive filename '+name,t=>{const root=fixture(t);writeFileSync(join(root,name),'not real credentials');assert.throws(()=>sealArtifact(root,commit),/sensitive/);});
test('artifact denies symlink to outside content',t=>{const root=fixture(t);symlinkSync('/etc/hosts',join(root,'escape'));assert.throws(()=>sealArtifact(root,commit),/symlink/);});
test('artifact denies hardlinks',t=>{const root=fixture(t);linkSync(join(root,'worker.mjs'),join(root,'shared'));assert.throws(()=>sealArtifact(root,commit),/regular/);});
test('artifact rejects case-folding name collisions',t=>{const root=fixture(t);writeFileSync(join(root,'Worker.mjs'),'x');assert.throws(()=>sealArtifact(root,commit),/collision/);});
test('artifact does not include Git history',t=>{const root=fixture(t);mkdirSync(join(root,'.git'));assert.throws(()=>sealArtifact(root,commit),/directory/);});
test('legitimate bundled dependency directory is included in digest',t=>{const root=fixture(t);mkdirSync(join(root,'node_modules'));writeFileSync(join(root,'node_modules','runtime.js'),'x');assert.equal(sealArtifact(root,commit).files.length,2);});
test('private signing material is rejected',t=>{const root=fixture(t);const key=generateKeyPairSync('ed25519').privateKey.export({type:'pkcs8',format:'pem'});writeFileSync(join(root,'bad.txt'),key);assert.throws(()=>sealArtifact(root,commit),/private_key/);});
test('four distinct scoped signatures verify',()=>{const f=signed();assert.equal(verifyApprovals(f.approvals,f.keys,commit,f.hash,{now}).approved,true);});
for(const kind of ['missing','tampered','expired','future','different_commit','different_artifact','different_environment','revoked','unknown_key','repeated_role','untrusted_roles','signature','extra'])test('release rejects '+kind+' approval',()=>{
 const f=signed(),a=f.approvals.approvals[0];
 if(kind==='missing')f.approvals.approvals.pop();
 if(kind==='tampered')a.payload.issuedAt--;
 if(kind==='expired')a.payload.expiresAt=now;
 if(kind==='future')a.payload.issuedAt=now+10000;
 if(kind==='different_commit')a.payload.candidateCommit='c'.repeat(40);
 if(kind==='different_artifact')a.payload.artifactDigest='d'.repeat(64);
 if(kind==='different_environment')a.payload.environment='staging';
 if(kind==='revoked')f.keys[0].revoked=true;
 if(kind==='unknown_key')a.payload.keyId='unknown';
 if(kind==='repeated_role')f.approvals.approvals[1]=structuredClone(a);
 if(kind==='untrusted_roles')f.keys[0].role='operations';
 if(kind==='signature')a.signature='A'.repeat(86)+'==';
 if(kind==='extra')a.payload.uncheckedApproval=true;
 assert.throws(()=>verifyApprovals(f.approvals,f.keys,commit,f.hash,{now}));
});
test('same signing key cannot impersonate four independent signers',()=>{
 const f=signed();for(let i=1;i<4;i++){f.keys[i].publicKeyPem=f.keys[0].publicKeyPem;f.approvals.approvals[i].signature=sign(null,Buffer.from(JSON.stringify(f.approvals.approvals[i].payload)),f.pairs[0].privateKey).toString('base64');}
 assert.throws(()=>verifyApprovals(f.approvals,f.keys,commit,f.hash,{now}),/distinct/);
});
test('production trust is not taken from self supplied approval key',()=>{const f=signed();assert.throws(()=>verifyApprovals(f.approvals,[],commit,f.hash,{now}),/trusted/);});
