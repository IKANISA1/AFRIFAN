import { WorkerEntrypoint } from 'cloudflare:workers';
import { publishSnapshot, PublicationError } from './snapshot-publication.mjs';
import {rpcOperation} from '../../shared-telemetry/entrypoints.mjs';

/** Private capability endpoint. Bind ONLY to a separately authenticated admin
 * approval service which derives approvedBy from its authenticated operator.
 * Never bind this service to the public content Worker or a supporter client.
 * This service does not provide operator authentication itself.
 */
export class PublicSourcePublisher extends WorkerEntrypoint {
  async publish(input) {
    return rpcOperation(this,{service:'rayon_public',operation:'publication_command',mutating:true},input,async()=>{
    if (this.env.PUBLICATION_ENABLED !== 'true') throw new PublicationError('publication_disabled');
    if (!input || Object.keys(input).some(key =>
      !['snapshotId', 'approvedBy', 'approvalRef', 'expectedPreviousId'].includes(key))) {
      throw new PublicationError('invalid_publication_request');
    }
    // Deliberately do not accept a caller-supplied clock to bypass freshness.
    return publishSnapshot(this.env.RAYON_PUBLIC_DB, this.env.RAYON_PUBLIC_MEDIA, input);
    });
  }
}

// There is no HTTP publication route, even when this Worker is invoked by URL.
export default { fetch() { return new Response('Not found', { status: 404, headers: { 'cache-control': 'no-store' } }); } };
