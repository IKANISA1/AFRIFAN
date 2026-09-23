import registry from './team-assets.generated.json';

const aliases: Record<string, number> = registry.aliases;
const keyFor = (value: string) => value.toLowerCase().replace(/[^a-z0-9]/g, '');

export function teamAssetFor(name: string, crestUrl?: string | null) {
  const index = aliases[keyFor(name)] ?? (crestUrl ? aliases[keyFor(crestUrl)] : undefined);
  return index == null ? null : registry.teams[index];
}

export function teamInitials(name: string) {
  const registered = teamAssetFor(name);
  if (registered) return registered.initials;
  const words = name.trim().split(/[^A-Za-z0-9]+/).filter(Boolean);
  if (!words.length) return '—';
  return (words.length === 1 ? words[0] : words.map(word => word[0]).join('')).slice(0, 4).toUpperCase();
}

export function teamCrestUrl(name: string, crestUrl?: string | null) {
  const asset = teamAssetFor(name, crestUrl)?.asset;
  if (asset) return `/crests/${asset}`;
  try { const parsed = new URL(crestUrl ?? ''); return parsed.protocol === 'https:' ? parsed.href : null; }
  catch { return null; }
}

export const fixtureInitials = (first: string, second: string) => `${teamInitials(first)} · ${teamInitials(second)}`;
export const teamOptions = registry.teams;
