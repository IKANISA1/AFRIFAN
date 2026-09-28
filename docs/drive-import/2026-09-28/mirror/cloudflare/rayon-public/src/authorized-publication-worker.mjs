import { WorkerEntrypoint } from 'cloudflare:workers';
import { OperatorPublicationService, serviceResult } from './operator-publication.mjs';
/** Bind ONLY to the Access-protected operator gateway; never to a browser,
 * supporter Worker, public content Worker, Queue consumer or arbitrary service.
 * The gateway derives identity from ctx.access. The service rechecks live grants.
 */
export class AuthorizedPublicSourcePublisher extends WorkerEntrypoint {
  async review(input) { return serviceResult(new OperatorPublicationService(this.env),'review',input); }
  async publish(input) { return serviceResult(new OperatorPublicationService(this.env),'publish',input); }
  async head(input) { return serviceResult(new OperatorPublicationService(this.env),'head',input); }
  async publication(input) { return serviceResult(new OperatorPublicationService(this.env),'publication',input); }
}
export default { fetch() { return new Response('Not found',{status:404,headers:{'cache-control':'no-store'}}); } };
