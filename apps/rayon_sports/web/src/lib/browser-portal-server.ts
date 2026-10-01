import 'server-only';
import {getCloudflareContext} from '@opennextjs/cloudflare';
import {parseBrowserPortalConfig} from './browser-portal-config';
export async function browserPortalConfig(clubId:number,host:string|null){
 let env:Record<string,unknown>;
 // Workers and initialized next dev requests already carry this context.
 // Async lookup without it can start Wrangler/Miniflare in a Node preview.
 try{env=getCloudflareContext().env as unknown as Record<string,unknown>;}
 catch{
  // An ordinary Node preview with no enabled mode retains the original site. Enabled cookie mode needs actual Workers context.
  const mode=process.env.AFRICLUB_BROWSER_PORTAL_MODE;
  if(mode!==undefined&&mode!=='legacy')throw new Error('browser_portal_unavailable');
  return null;
 }
 return parseBrowserPortalConfig(env,clubId,host);
}
