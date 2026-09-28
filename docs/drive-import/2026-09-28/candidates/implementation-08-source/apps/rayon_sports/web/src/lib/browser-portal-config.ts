export interface BrowserPortalConfig {origin:string;clubId:number}
/** Absence preserves the existing application. An invalid/failed enabled mode never falls back. */
export function parseBrowserPortalConfig(env:Record<string,unknown>,clubId:number,host:string|null):BrowserPortalConfig|null {
 const mode=env.AFRICLUB_BROWSER_PORTAL_MODE;
 if(mode===undefined||mode==='legacy')return null;
 if(mode!=='cookie-v1')throw new Error('browser_portal_unavailable');
 const raw=env.AFRICLUB_BROWSER_PORTAL_ORIGIN,id=env.AFRICLUB_BROWSER_PORTAL_CLUB_ID;
 if(typeof raw!=='string'||typeof id!=='string'||!/^\d+$/.test(id))throw new Error('browser_portal_unavailable');
 const u=new URL(raw);
 if(u.origin!==raw||u.protocol!=='https:'||u.username||u.password||!u.hostname.includes('.')||u.hostname.endsWith('.')||
   u.host!==host||!Number.isSafeInteger(clubId)||clubId<=0||String(clubId)!==id)throw new Error('browser_portal_unavailable');
 return {origin:raw,clubId};
}
