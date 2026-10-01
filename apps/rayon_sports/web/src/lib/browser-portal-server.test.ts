// @vitest-environment node
import {afterEach,beforeEach,describe,expect,it,vi} from 'vitest';

const {getPlatformProxy}=vi.hoisted(()=>({
 getPlatformProxy:vi.fn(async()=>({env:{},cf:{},ctx:{}})),
}));
vi.mock('server-only',()=>({}));
vi.mock('wrangler',()=>({getPlatformProxy}));
// Use the actual installed OpenNext context lookup; only its local runtime
// factory is intercepted, so a regression cannot start Miniflare or a socket.
import {browserPortalConfig} from './browser-portal-server';

const symbol=Symbol.for('__cloudflare-context__');
const globals=globalThis as typeof globalThis & Record<symbol,unknown>;
const original=Object.getOwnPropertyDescriptor(globals,symbol);
const portalEnv={AFRICLUB_BROWSER_PORTAL_MODE:'cookie-v1',
 AFRICLUB_BROWSER_PORTAL_ORIGIN:'https://club.example.invalid',AFRICLUB_BROWSER_PORTAL_CLUB_ID:'24'};

describe('browser portal installed runtime context',()=>{
 beforeEach(()=>{
  delete globals[symbol];
  vi.stubEnv('NEXT_RUNTIME','nodejs');
  vi.stubEnv('AFRICLUB_BROWSER_PORTAL_MODE',undefined);
  getPlatformProxy.mockClear();
 });
 afterEach(()=>{
  delete globals[symbol];
  if(original)Object.defineProperty(globals,symbol,original);
  vi.unstubAllEnvs();
 });
 it.each([undefined,'legacy'])('returns legacy in a plain Node preview with mode %s without starting a runtime',async mode=>{
  vi.stubEnv('AFRICLUB_BROWSER_PORTAL_MODE',mode);
  await expect(browserPortalConfig(24,'club.example.invalid')).resolves.toBeNull();
  expect(getPlatformProxy).not.toHaveBeenCalled();
  expect(globals[symbol]===undefined).toBe(true);
 });
 it.each(['cookie-v1','invalid-mode',''])('rejects enabled mode %s when the request context is unavailable',async mode=>{
  vi.stubEnv('AFRICLUB_BROWSER_PORTAL_MODE',mode);
  await expect(browserPortalConfig(24,'club.example.invalid')).rejects.toThrow('browser_portal_unavailable');
  expect(getPlatformProxy).not.toHaveBeenCalled();
 });
 it('uses the actual Workers or initialized dev context rather than process environment',async()=>{
  vi.stubEnv('AFRICLUB_BROWSER_PORTAL_MODE','legacy');
  globals[symbol]={env:portalEnv,cf:{},ctx:{}};
  await expect(browserPortalConfig(24,'club.example.invalid')).resolves.toEqual({origin:portalEnv.AFRICLUB_BROWSER_PORTAL_ORIGIN,clubId:24});
  expect(getPlatformProxy).not.toHaveBeenCalled();
 });
 it.each([{}, {AFRICLUB_BROWSER_PORTAL_MODE:'legacy'}])('retains actual legacy bindings %j',async env=>{
  vi.stubEnv('AFRICLUB_BROWSER_PORTAL_MODE','cookie-v1');
  globals[symbol]={env,cf:{},ctx:{}};
  await expect(browserPortalConfig(24,'club.example.invalid')).resolves.toBeNull();
  expect(getPlatformProxy).not.toHaveBeenCalled();
 });
 it.each([[26,'club.example.invalid'],[24,'foreign.example.invalid'],[24,null]] as const)('rejects mismatched request club %s or host %s without fallback',async(clubId,host)=>{
  globals[symbol]={env:portalEnv,cf:{},ctx:{}};
  await expect(browserPortalConfig(clubId,host)).rejects.toThrow('browser_portal_unavailable');
  expect(getPlatformProxy).not.toHaveBeenCalled();
 });
 it('rejects invalid enabled bindings even when process mode is legacy',async()=>{
  vi.stubEnv('AFRICLUB_BROWSER_PORTAL_MODE','legacy');
  globals[symbol]={env:{...portalEnv,AFRICLUB_BROWSER_PORTAL_ORIGIN:'http://club.example.invalid'},cf:{},ctx:{}};
  await expect(browserPortalConfig(24,'club.example.invalid')).rejects.toThrow('browser_portal_unavailable');
  expect(getPlatformProxy).not.toHaveBeenCalled();
 });
});
