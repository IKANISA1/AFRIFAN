/** Local JS entrypoint harness only. Wrangler separately verifies real Worker
 * bundling; this stub does not emulate Cloudflare RPC, workerd or hosted D1. */
export async function resolve(specifier,context,nextResolve){
 if(specifier==='cloudflare:workers')return {url:'data:text/javascript,export class WorkerEntrypoint {}',shortCircuit:true};
 return nextResolve(specifier,context);
}
