import {WorkerEntrypoint} from 'cloudflare:workers';
import {ServerHandoffService} from './handoff-service.mjs';
const hidden=()=>new Response(null,{status:404,headers:{'cache-control':'no-store'}});
export default {fetch:hidden};
export class MembershipHandoffReserve extends WorkerEntrypoint {
  fetch(){return hidden();}
  reserve(input){return new ServerHandoffService(this.env,this.env.HANDOFF_RESERVE_PRINCIPAL_ID).reserve(input);}
}
export class MembershipHandoffRecovery extends WorkerEntrypoint {
  fetch(){return hidden();}
  active(input){return new ServerHandoffService(this.env,this.env.HANDOFF_READ_PRINCIPAL_ID).active(input);}
}
