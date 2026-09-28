import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';
import { teamAssetFor, teamCrestUrl, teamInitials } from './team-identity';

describe('published team identity', () => {
  it.each([
    ['Rayon Sports FC', 'RAY', 'rayon-sports.png'],
    ['rayon_sports_rw', 'RAY', 'rayon-sports.png'],
    ['Nkana', 'NKA', 'nkana.png'],
    ['AS Vita Club', 'VIT', 'as-vita.png'],
    ['Vital’O FC', 'VFC', 'vitalo.png'],
    ['APR FC', 'APR', 'apr-fc.png'],
  ])('uses the published crest for %s', (name, initials, asset) => {
    expect(teamInitials(name)).toBe(initials);
    expect(teamCrestUrl(name, 'https://example.test/wrong-image.png')).toBe(`/crests/${asset}`);
  });
  it('uses identical verified bytes in both frontend bundles', () => {
    const native = resolve(process.cwd(), '../../../packages/core/core_theme/assets');
    const register = JSON.parse(readFileSync(resolve(native, 'team-assets.json'), 'utf8'));
    for (const team of register.teams) {
      if (!team.asset) continue;
      for (const path of [resolve(native, 'crests', team.asset), resolve('public/crests', team.asset)]) {
        expect(createHash('sha256').update(readFileSync(path)).digest('hex')).toBe(team.sha256);
      }
    }
  });
  it('never fabricates a crest or borrows a partial name match', () => {
    expect(teamAssetFor('Another Rayon Sports')).toBeNull();
    expect(teamCrestUrl('Unknown United')).toBeNull();
    expect(teamCrestUrl('Unknown United', 'javascript:alert(1)')).toBeNull();
    expect(teamInitials('Unknown United')).toBe('UU');
    expect(teamInitials('CD Costa do Sol')).toBe('CDS');
    expect(teamCrestUrl('CD Costa do Sol')).toBeNull();
  });
});
