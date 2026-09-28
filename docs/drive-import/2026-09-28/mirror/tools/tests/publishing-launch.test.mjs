import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync,rmSync,readFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {pathToFileURL} from 'node:url';
const dir=mkdtempSync(join(tmpdir(),'africlub-launch-'));
const source=new URL('../../apps/rayon_sports/web/src/lib/publishing-launch.ts',import.meta.url);
execFileSync('tsc',['--strict','--target','ES2022','--module','ES2022','--skipLibCheck','--outDir',dir,source.pathname]);
const {publishingLaunchUrl:launch}=await import(pathToFileURL(join(dir,'publishing-launch.js')));
process.on('exit',()=>rmSync(dir,{recursive:true,force:true}));
const yes={hasAccess:true,isAuthenticated:true,clubId:'24'};
test('authorized launcher carries no credentials or arbitrary redirect',()=>assert.equal(launch('true','https://operator.example.invalid',yes),'https://operator.example.invalid/operator/clubs/24/public-source'));
for(const origin of [undefined,'http://operator.invalid','https://x.invalid/','https://x.invalid/path','https://u:p@x.invalid','https://x.invalid?token=x','https://x.invalid#x','https://localhost','https://127.0.0.1'])
 test('unsafe launcher origin denied '+String(origin),()=>assert.equal(launch('true',origin,yes),null));
for(const access of [null,{...yes,hasAccess:false},{...yes,isAuthenticated:false},{...yes,clubId:'44'}])
 test('launcher permission/club rejected '+JSON.stringify(access),()=>assert.equal(launch('true','https://operator.invalid',access),null));
test('disabled launcher and controlled evidence denied',()=>{assert.equal(launch(undefined,'https://operator.invalid',yes),null);assert.equal(launch('true','https://operator.invalid',yes,true),null)});
test('page never forwards session data and link opens safely',()=>{const text=readFileSync(new URL('../../apps/rayon_sports/web/src/app/admin/publishing/page.tsx',import.meta.url),'utf8');assert.match(text,/rel="noopener noreferrer"/);assert.doesNotMatch(text,/access_token|refresh_token|dangerouslySetInnerHTML|fetch\(/)});
