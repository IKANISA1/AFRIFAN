import {describe,expect,it} from 'vitest';
import {parseBrowserPortalConfig} from './browser-portal-config';
const env={AFRICLUB_BROWSER_PORTAL_MODE:'cookie-v1',AFRICLUB_BROWSER_PORTAL_ORIGIN:'https://club.example.invalid',AFRICLUB_BROWSER_PORTAL_CLUB_ID:'24'};
describe('explicit browser portal configuration',()=>{
 it.each([{}, {AFRICLUB_BROWSER_PORTAL_MODE:'legacy'}])('retains legacy only for an absent or explicit legacy mode',v=>{expect(parseBrowserPortalConfig(v,24,null)).toBeNull();});
 it('accepts only the exact approved host and tenant',()=>{expect(parseBrowserPortalConfig(env,24,'club.example.invalid')).toEqual({origin:env.AFRICLUB_BROWSER_PORTAL_ORIGIN,clubId:24});});
 it.each([
  {AFRICLUB_BROWSER_PORTAL_MODE:'true'}, {AFRICLUB_BROWSER_PORTAL_CLUB_ID:'024'}, {AFRICLUB_BROWSER_PORTAL_CLUB_ID:'26'},
  {AFRICLUB_BROWSER_PORTAL_ORIGIN:'http://club.example.invalid'}, {AFRICLUB_BROWSER_PORTAL_ORIGIN:'https://club.example.invalid/'},
  {AFRICLUB_BROWSER_PORTAL_ORIGIN:'https://name:secret@club.example.invalid'}, {AFRICLUB_BROWSER_PORTAL_ORIGIN:'https://club.example.invalid.'},
  {AFRICLUB_BROWSER_PORTAL_ORIGIN:'not a URL'}, {AFRICLUB_BROWSER_PORTAL_ORIGIN:undefined}
 ])('blocks an invalid enabled configuration without legacy fallback: %j',patch=>{expect(()=>parseBrowserPortalConfig({...env,...patch},24,'club.example.invalid')).toThrow();});
 it.each([null,'foreign.example.invalid','club.example.invalid:443','club.example.invalid,foreign.example.invalid'])('blocks an unapproved request host %s',host=>{expect(()=>parseBrowserPortalConfig(env,24,host)).toThrow();});
});
