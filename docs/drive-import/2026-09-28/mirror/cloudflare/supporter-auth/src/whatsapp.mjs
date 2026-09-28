import { requireValue, phoneNumber } from './errors.mjs';
// Port of the inspected repository's English authentication-template payload.
// Account, template approval and provider version MUST be verified before enablement.
export async function sendWhatsAppOtp(env,{phone,code,template},{fetcher=fetch,timeoutMs=4000}={}){
 requireValue(env.AUTH_DELIVERY_ENABLED==='true','delivery_disabled',503);phoneNumber(phone);
 requireValue(typeof code==='string'&&/^\d{6}$/.test(code));requireValue(typeof template==='string'&&/^[a-z0-9_]{1,512}$/.test(template));
 const version=env.WHATSAPP_GRAPH_API_VERSION,id=env.WHATSAPP_PHONE_NUMBER_ID,token=env.WHATSAPP_CLOUD_API_TOKEN;
 requireValue(typeof version==='string'&&/^v\d+\.0$/.test(version)&&typeof id==='string'&&/^\d{5,32}$/.test(id)&&typeof token==='string'&&token.length>=20&&!/\s/.test(token),'provider_not_configured',503);
 const payload={messaging_product:'whatsapp',recipient_type:'individual',to:phone.slice(1),type:'template',template:{name:template,language:{code:'en_US'},components:[
  {type:'body',parameters:[{type:'text',text:code}]},{type:'button',sub_type:'url',index:'0',parameters:[{type:'text',text:code}]}]}};
 const controller=new AbortController();let timer;
 try{return await Promise.race([(async()=>{
  const response=await fetcher(`https://graph.facebook.com/${version}/${id}/messages`,{method:'POST',redirect:'error',headers:{authorization:`Bearer ${token}`,'content-type':'application/json'},body:JSON.stringify(payload),signal:controller.signal});
  requireValue(response.ok,'provider_rejected',502);const reader=response.body?.getReader();requireValue(reader,'provider_response_invalid',502);
  const chunks=[];let size=0;try{while(true){const {value,done}=await reader.read();if(done)break;size+=value.length;requireValue(size<=16384,'provider_response_invalid',502);chunks.push(value);}}
  finally{await reader.cancel().catch(()=>{});reader.releaseLock();}
  const bytes=new Uint8Array(size);let off=0;for(const c of chunks){bytes.set(c,off);off+=c.length;}
  let result;try{result=JSON.parse(new TextDecoder().decode(bytes));}catch{requireValue(false,'provider_response_invalid',502);}
  const messageId=result?.messages?.[0]?.id;requireValue(typeof messageId==='string'&&messageId.length<=256&&/^wamid\.[A-Za-z0-9+/_=:.-]+$/.test(messageId),'provider_response_invalid',502);
  return {accepted:true,messageId};})(),new Promise((_,reject)=>{timer=setTimeout(()=>{controller.abort();reject(new Error('provider_timeout'));},timeoutMs);})]);}
 finally{clearTimeout(timer);}
}
