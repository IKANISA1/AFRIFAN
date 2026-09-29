import {otpQueueHealth} from './reliable-delivery.mjs';
/** Fixed configured tenant aggregate. No request-selected tenant, SQL, delivery or
 * identity authority. A trusted operator gateway must authorize human access.
 */
export async function readDeliveryHealth(env, input = {}) {
  if (!input || typeof input !== 'object' || Array.isArray(input) || Object.keys(input).length) {
    return {ok: false, error: {code: 'invalid_health_request', status: 400}};
  }
  try {return {ok: true, data: await otpQueueHealth(env)};}
  catch {return {ok: false, error: {code: 'delivery_health_unavailable', status: 503}};}
}
