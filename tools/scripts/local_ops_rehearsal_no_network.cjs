/* Local verification preload: deny outbound sockets, HTTP, fetch and DNS without logging destinations. */
const net=require('node:net'),http=require('node:http'),https=require('node:https'),dns=require('node:dns');
let blocked=0;
const fail=()=>{blocked++;throw Object.assign(new Error('network_disabled_for_local_validation'),{code:'LOCAL_VALIDATION_NETWORK_DISABLED'});};
const connect=net.Socket.prototype.connect;
net.Socket.prototype.connect=function(...args){
 const options=args[0];
 if(options&&typeof options==='object'&&typeof options.path==='string'&&options.path.startsWith('/'))return connect.apply(this,args);
 if(typeof options==='string'&&options.startsWith('/'))return connect.apply(this,args);
 return fail();
};
http.request=fail;http.get=fail;https.request=fail;https.get=fail;
globalThis.fetch=async()=>fail();
for(const name of ['lookup','lookupService','resolve','resolve4','resolve6','resolveAny','resolveCaa','resolveCname','resolveMx','resolveNaptr','resolveNs','resolvePtr','resolveSoa','resolveSrv','resolveTxt','reverse']){
 if(typeof dns[name]==='function')dns[name]=fail;
 if(typeof dns.promises[name]==='function')dns.promises[name]=async()=>fail();
}
process.on('exit',()=>process.stdout.write(JSON.stringify({localValidationNetworkGuard:true,outboundNetworkAttemptsBlocked:blocked})+'\n'));
