import {UI_HTML,CASES_HTML,UI_ASSETS} from './ui-assets.mjs';
export function uiResponse(clubId,asset,view='publication'){
 let body,type;
 if(asset){
  if(!Object.hasOwn(UI_ASSETS,asset))throw new Error('Unknown UI asset');
  body=UI_ASSETS[asset];type=asset.endsWith('.css')?'text/css; charset=utf-8':'text/javascript; charset=utf-8';
 }else{
  if(!Number.isSafeInteger(clubId)||clubId<=0)throw new Error('Invalid club');
  body=(view==='cases'?CASES_HTML:UI_HTML).replace('__CLUB_ID__',String(clubId));type='text/html; charset=utf-8';
 }
 return new Response(body,{headers:{'content-type':type,'cache-control':'no-store','referrer-policy':'no-referrer',
  'x-content-type-options':'nosniff','x-frame-options':'DENY','cross-origin-resource-policy':'same-origin',
  'permissions-policy':'camera=(), microphone=(), geolocation=()',
  'content-security-policy':"default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"}});
}
