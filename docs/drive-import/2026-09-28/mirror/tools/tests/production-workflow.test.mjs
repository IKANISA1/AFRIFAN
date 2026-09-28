import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL('../../'+p,import.meta.url),'utf8');
const ci=read('.github/workflows/ci.yaml'),deploy=read('.github/workflows/deploy-gikundiro-web.yml');
test('main CI includes backend and real Dart gate',()=>{assert.match(ci,/cloudflare-contracts:/);assert.match(ci,/verify_production_candidate.py --ci/);assert.match(ci,/verify_native_membership.py/);assert.match(ci,/needs: \[flutter-ci, cloudflare-contracts\]/)});
test('candidate preparation never deploys or carries deployment credentials',()=>{assert.doesNotMatch(deploy,/wrangler deploy|CLOUDFLARE_API_TOKEN|CLOUDFLARE_ACCOUNT_ID|\n  push:/);assert.match(deploy,/workflow_dispatch:/);assert.match(deploy,/persist-credentials: false/)});
test('candidate identifier passed through env rather than injected into shell',()=>{assert.match(deploy,/CANDIDATE_SHA: \$\{\{ inputs.candidate_sha \}\}/);assert.doesNotMatch(deploy,/run:.*\$\{\{ inputs/)});
test('build checks precede sealing and sealing precedes upload',()=>{assert.ok(deploy.indexOf('npm run typecheck')<deploy.indexOf('candidate-integrity.mjs seal'));assert.ok(deploy.indexOf('candidate-integrity.mjs seal')<deploy.indexOf('actions/upload-artifact'))});
test('Next cannot ignore build errors',()=>assert.match(read('apps/rayon_sports/web/next.config.ts'),/ignoreBuildErrors: false/));
test('root compiler requirements preserved',()=>{const text=read('pubspec.yaml');assert.match(text,/sdk: ">=3\.10\.0 <4\.0\.0"/);assert.match(text,/flutter: ">=3\.38\.0"/)});
