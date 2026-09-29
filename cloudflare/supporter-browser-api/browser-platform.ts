/** A controlled old service worker must acknowledge the private-cache protocol before portal use.
 * No controller means this page is not being intercepted; this does not inspect other browser caches. */
export async function checkPrivateCacheBoundary(serviceWorkers:Pick<ServiceWorkerContainer,'controller'>|undefined,
 makeChannel:()=>MessageChannel=()=>new MessageChannel(),timeoutMs=2000):Promise<boolean>{
 const worker=serviceWorkers?.controller;if(!worker)return true;
 return new Promise(resolve=>{
  const channel=makeChannel();let done=false;
  const finish=(ok:boolean)=>{if(done)return;done=true;clearTimeout(timer);channel.port1.close();channel.port2.close();resolve(ok);};
  const timer=setTimeout(()=>finish(false),timeoutMs);
  channel.port1.onmessage=event=>finish(event.data?.protocol==='africlub-private-cache-v1'&&event.data?.purged===true);
  try{worker.postMessage({type:'AFRICLUB_PRIVATE_CACHE_CHECK'},[channel.port2]);}catch{finish(false);}
 });
}
