import 'server-only';
import {getCloudflareContext} from '@opennextjs/cloudflare';
import {parseBrowserPortalConfig} from './browser-portal-config';
export async function browserPortalConfig(clubId:number,host:string|null){
 let env:Record<string,unknown>;
 try{env=(await getCloudflareContext({async:true})).env as unknown as Record<string,unknown>;}
 catch{
  // An ordinary Node preview with no enabled mode retains the original site. Enabled cookie mode needs actual Workers context.
  if(process.env.AFRICLUB_BROWSER_PORTAL_MODE&&process.env.AFRICLUB_BROWSER_PORTAL_MODE!=='legacy')throw new Error('browser_portal_unavailable');
  return null;
 }
 return parseBrowserPortalConfig(env,clubId,host);
}
