import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {UI_SOURCE_HASHES,UI_HTML,UI_ASSETS,UI_BINARY_ASSETS} from '../src/ui-assets.mjs';
const read=p=>readFileSync(new URL(p,import.meta.url),'utf8');
const tokens=read('../../../apps/rayon_sports/web/src/ui-kit/tokens.css');
const html=read('../ui/page.html'),app=read('../ui/app.mjs'),css=read('../ui/styles.css');
// These are source/structure checks, NOT claims of rendered browser behavior.
test('generated UI assets match every recorded source hash and inherited tokens',()=>{
 for(const [name,expected] of Object.entries(UI_SOURCE_HASHES)){
  const text=name==='shared-ui-tokens'?tokens:readFileSync(new URL('../'+name,import.meta.url));
  assert.equal(createHash('sha256').update(text).digest('hex'),expected,name);
 }
 assert.equal(UI_HTML,html);assert.equal(UI_ASSETS['app.js'],app);assert.equal(UI_ASSETS['controller.js'],read('../ui/controller.mjs'));
 assert.equal(UI_ASSETS['styles.css'],tokens+'\n'+css);
 assert.deepEqual(Buffer.from(UI_BINARY_ASSETS['inter-latin-wght-normal.woff2'],'base64'),readFileSync(new URL('../ui/fonts/inter-latin-wght-normal.woff2',import.meta.url)));
});
test('all literal DOM bindings and form labels refer to unique existing IDs',()=>{
 const ids=[...html.matchAll(/\bid="([^"]+)"/g)].map(m=>m[1]);assert.equal(ids.length,new Set(ids).size);
 for(const m of app.matchAll(/\$\('([^']+)'\)/g))assert.ok(ids.includes(m[1]),m[1]);
 for(const m of html.matchAll(/\bfor="([^"]+)"/g))assert.ok(ids.includes(m[1]),m[1]);
 assert.match(html,/<html lang="en">/);assert.match(html,/role="alert"/);assert.match(html,/role="status"/);assert.match(html,/Skip to publication workspace/);
});
test('HTML patterns compile under browser Unicode-set syntax and preserve expected inputs',()=>{
 for(const m of html.matchAll(/\bpattern="([^"]+)"/g))assert.doesNotThrow(()=>new RegExp(m[1],'v'));
 const p=html.match(/id="evidence"[^>]+pattern="([^"]+)"/)[1],check=new RegExp('^(?:'+p+')$','v');
 assert.ok(check.test('editorial:2026-09-26/path'));assert.equal(check.test('<script>'),false);assert.equal(check.test('with space'),false);
});
test('UI has no inline executable handlers, styles, media fetches or external assets',()=>{
 assert.doesNotMatch(html,/<script(?![^>]+src=)|\son\w+=|\sstyle=|<img\b|<iframe\b/i);
 for(const m of html.matchAll(/\b(?:src|href)="([^"]+)"/g))assert.ok(m[1]==='#main'||m[1].startsWith('/operator/assets/'));
 assert.doesNotMatch(app,/\.innerHTML\b|insertAdjacentHTML|document\.write|eval\(/);
});
test('CSS semantic variables are present in the existing token contract',()=>{
 const available=new Set([...tokens.matchAll(/(--[a-z0-9-]+)\s*:/gi)].map(m=>m[1]));
 for(const m of css.matchAll(/var\((--[a-z0-9-]+)/gi))assert.ok(available.has(m[1]),m[1]);
 assert.match(css,/\[hidden\]\{display:none!important\}/);assert.match(css,/prefers-reduced-motion/);assert.match(css,/forced-colors/);
});
