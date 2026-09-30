import { WorkerEntrypoint } from 'cloudflare:workers';
import { OperatorPublicationService, serviceResult } from './operator-publication.mjs';
import {rpcOperation} from '../../shared-telemetry/entrypoints.mjs';
/** Bind ONLY to the Access-protected operator gateway; never to a browser,
 * supporter Worker, public content Worker, Queue consumer or arbitrary service.
 * The gateway derives identity from ctx.access. The service rechecks live grants.
 */
export class AuthorizedPublicSourcePublisher extends WorkerEntrypoint {
  async session(input) { return rpcOperation(this,{service:'rayon_public',operation:'publication_read'},input,()=>serviceResult(new OperatorPublicationService(this.env),'session',input)); }
  async candidates(input) { return rpcOperation(this,{service:'rayon_public',operation:'publication_read'},input,()=>serviceResult(new OperatorPublicationService(this.env),'candidates',input)); }
  async candidate(input) { return rpcOperation(this,{service:'rayon_public',operation:'publication_read'},input,()=>serviceResult(new OperatorPublicationService(this.env),'candidate',input)); }
  async preview(input) { return rpcOperation(this,{service:'rayon_public',operation:'publication_read'},input,()=>serviceResult(new OperatorPublicationService(this.env),'preview',input)); }
  async reviewStatus(input) { return rpcOperation(this,{service:'rayon_public',operation:'publication_read'},input,()=>serviceResult(new OperatorPublicationService(this.env),'reviewStatus',input)); }
  async review(input) { return rpcOperation(this,{service:'rayon_public',operation:'publication_command',mutating:true},input,()=>serviceResult(new OperatorPublicationService(this.env),'review',input)); }
  async publish(input) { return rpcOperation(this,{service:'rayon_public',operation:'publication_command',mutating:true},input,()=>serviceResult(new OperatorPublicationService(this.env),'publish',input)); }
  async head(input) { return rpcOperation(this,{service:'rayon_public',operation:'publication_read'},input,()=>serviceResult(new OperatorPublicationService(this.env),'head',input)); }
  async publication(input) { return rpcOperation(this,{service:'rayon_public',operation:'publication_read'},input,()=>serviceResult(new OperatorPublicationService(this.env),'publication',input)); }
}
export default { fetch() { return new Response('Not found',{status:404,headers:{'cache-control':'no-store'}}); } };
