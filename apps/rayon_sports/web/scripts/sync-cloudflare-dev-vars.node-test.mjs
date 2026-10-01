import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync,readFileSync,statSync,writeFileSync,symlinkSync,readdirSync,linkSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {writePrivateDevVars} from './sync-cloudflare-dev-vars.mjs';
function directory(t){const dir=mkdtempSync(join(tmpdir(),'africlub-private-vars-'));t.after(()=>rmSync(dir,{recursive:true,force:true}));return dir;}
test('fresh and replacement environment files have exact owner-only permissions and no temporary copy',t=>{
 const dir=directory(t);writePrivateDevVars(dir,'NEXTJS_ENV=development\nSYNTHETIC_SETTING=first\n');
 const target=join(dir,'.dev.vars');assert.equal(statSync(target).mode&0o777,0o600);
 writePrivateDevVars(dir,'NEXTJS_ENV=development\nSYNTHETIC_SETTING=second\n');
 assert.equal(statSync(target).mode&0o777,0o600);
 assert.equal(readFileSync(target,'utf8'),'NEXTJS_ENV=development\nSYNTHETIC_SETTING=second\n');
 assert.deepEqual(readdirSync(dir),['.dev.vars']);
});
for(const dangling of [false,true])test('private writes reject '+(dangling?'dangling':'existing')+' symlinks without changing their targets',t=>{
 const dir=directory(t),outside=join(dir,'protected'),target=join(dir,'.dev.vars');
 if(!dangling)writeFileSync(outside,'synthetic_original');symlinkSync(outside,target);
 assert.throws(()=>writePrivateDevVars(dir,'synthetic_new'),/unsafe_private_environment_target/);
 if(!dangling)assert.equal(readFileSync(outside,'utf8'),'synthetic_original');
});
test('atomic replacement does not modify another hardlink to the previous file',t=>{
 const dir=directory(t),target=join(dir,'.dev.vars'),other=join(dir,'original');
 writeFileSync(target,'synthetic_original',{mode:0o600});linkSync(target,other);
 writePrivateDevVars(dir,'synthetic_new');
 assert.equal(readFileSync(other,'utf8'),'synthetic_original');assert.equal(readFileSync(target,'utf8'),'synthetic_new');
 assert.equal(statSync(target).mode&0o777,0o600);
});
