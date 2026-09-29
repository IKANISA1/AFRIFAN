import {DeliveryError,LIMITS,demand} from './policy.mjs';
export async function boundedJson(response,signal) {
  const type=(response.headers.get('content-type')??'').split(';')[0].trim().toLowerCase();
  demand(type==='application/json','invalid_provider_response');
  const length=response.headers.get('content-length');
  demand(length===null||(/^\d+$/.test(length)&&Number(length)<=LIMITS.responseBytes),'invalid_provider_response');
  demand(response.body,'invalid_provider_response');
  const reader=response.body.getReader(),chunks=[];let size=0;
  try{
    while(true){
      if(signal.aborted)throw new DeliveryError('provider_timeout');
      const {done,value}=await reader.read();if(done)break;size+=value.byteLength;
      demand(size<=LIMITS.responseBytes,'invalid_provider_response');chunks.push(value);
    }
    const bytes=new Uint8Array(size);let offset=0;for(const c of chunks){bytes.set(c,offset);offset+=c.length;}
    let parsed;try{parsed=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));}catch{throw new DeliveryError('invalid_provider_response');}
    demand(parsed&&typeof parsed==='object'&&!Array.isArray(parsed),'invalid_provider_response');return parsed;
  }finally{try{await reader.cancel();}catch{}reader.releaseLock();}
}
export function payload(input,route) {
  return {messaging_product:'whatsapp',recipient_type:'individual',to:input.phone.slice(1),type:'template',
    template:{name:route.templateName,language:{code:route.language},components:[
      {type:'body',parameters:[{type:'text',text:input.code}]},
      {type:'button',sub_type:'url',index:'0',parameters:[{type:'text',text:input.code}]},
    ]}};
}
export async function graphJson(fetcher,config,path,token,{body,signal}={}) {
  // Fixed origin; identifiers and version have already been validated. No redirects.
  demand(!signal?.aborted,'provider_timeout');
  let response;
  try{response=await fetcher(`https://graph.facebook.com/${config.version}/${path}`,{
    method:body?'POST':'GET',redirect:'error',signal,
    headers:{authorization:`Bearer ${token}`,'content-type':'application/json',accept:'application/json'},
    ...(body?{body:JSON.stringify(body)}:{}),
  });}catch{throw new DeliveryError(signal?.aborted?'provider_timeout':'provider_unreachable');}
  if(response.status!==200){
    try{await response.body?.cancel();}catch{}
    throw new DeliveryError(response.status>=400&&response.status<500?'provider_rejected':'provider_unknown');
  }
  return boundedJson(response,signal);
}
export async function inspectTemplate(fetcher,config,route,token,signal) {
  const result=await graphJson(fetcher,config,`${route.templateId}?fields=id,name,status,category,language`,token,{signal});
  demand(result.id===route.templateId&&result.name===route.templateName&&result.language===route.language&&
    result.category==='AUTHENTICATION'&&result.status==='APPROVED','template_not_approved');
  // Copy-code button anatomy/expiry, sender ownership and consent require separate live review.
  return {templateId:result.id,templateName:result.name,language:result.language,status:result.status,category:result.category};
}
export function acceptedMessage(body,input) {
  demand(!Object.hasOwn(body,'error')&&body.messaging_product==='whatsapp'&&Array.isArray(body.messages)&&body.messages.length===1&&
    Array.isArray(body.contacts)&&body.contacts.length===1,'invalid_provider_response');
  const m=body.messages[0],c=body.contacts[0];
  demand(typeof m.id==='string'&&/^wamid\.[A-Za-z0-9+/_=.-]{1,250}$/.test(m.id),'invalid_provider_response');
  demand(c.wa_id===input.phone.slice(1)&&(c.input===input.phone||c.input===input.phone.slice(1)),'invalid_provider_response');
  demand(m.message_status===undefined||m.message_status==='accepted','provider_not_accepted');
  return m.id;
}
export async function withDeadline(work,ms=LIMITS.deadlineMs) {
  const controller=new AbortController();let timer;
  try{return await Promise.race([work(controller.signal),new Promise((_,reject)=>{
    timer=setTimeout(()=>{controller.abort();reject(new DeliveryError('provider_timeout'));},ms);
  })]);}finally{clearTimeout(timer);controller.abort();}
}
