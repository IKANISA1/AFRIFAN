import {afterEach, describe, expect, it} from 'vitest';
import {getFanAppDestinations, hasFanAppDestination, parseFanAppDestinations, resolveFanAppHref, siteConfig} from './config';

const originalUrl = siteConfig.fanAppUrl;
const originalDestinations = siteConfig.fanAppDestinations;
afterEach(() => { siteConfig.fanAppUrl = originalUrl; siteConfig.fanAppDestinations = originalDestinations; });
describe('club-scoped supporter destinations', () => {
  it('validates external HTTPS destinations and ignores malformed or prototype-bearing entries', () => {
    const parsed = parseFanAppDestinations('{"nkana_zm":{"ios":"https://apps.apple.com/example","android":"javascript:alert(1)","web":"https://user:password@example.org"},"__proto__":{"web":"https://foreign.example"}}');
    expect(parsed.nkana_zm).toEqual({ios: 'https://apps.apple.com/example', android: undefined, web: undefined});
    expect(Object.getPrototypeOf(parsed)).toBeNull();
    expect(parsed.__proto__).toBeUndefined();
    expect(parseFanAppDestinations('[{"web":"https://foreign.example"}]')).toEqual({});
  });
  it('never applies a single legacy URL to other clubs or context-free recovery', () => {
    siteConfig.fanAppUrl = 'https://gikundiro.example';
    expect(getFanAppDestinations('nkana_zm')).toEqual({});
    expect(resolveFanAppHref('nkana_zm')).toBe('/app');
    expect(resolveFanAppHref()).toBe('/app');
  });
  it('keeps independent platform choices and does not infer availability', () => {
    siteConfig.fanAppDestinations = parseFanAppDestinations('{"nkana_zm":{"ios":"https://ios.example","android":"https://android.example"},"vitalo_bi":{"web":"https://vitalo.example"}}');
    expect(hasFanAppDestination('nkana_zm')).toBe(true);
    expect(resolveFanAppHref('nkana_zm')).toBe('/app');
    expect(getFanAppDestinations('nkana_zm')).toMatchObject({ios: 'https://ios.example/', android: 'https://android.example/'});
    expect(resolveFanAppHref('vitalo_bi')).toBe('https://vitalo.example/');
    expect(hasFanAppDestination('costa_do_sol_mz')).toBe(false);
  });
});
