/** Server-side/private-binding client. Never put these bindings or operational records in a public browser. */
export type DeliveryState = 'pending'|'leased'|'retry'|'dead'|'delivered';
export type ReviewReason = 'dependency_restored'|'configuration_corrected';
export interface ReviewBinding { inspect(input:unknown):Promise<unknown>; redrive(input:unknown):Promise<unknown>; health(input:unknown):Promise<unknown>; }
export interface DeliveryItem { eventId:string; revision:number; state:DeliveryState; attempts:number; cycleAttempts:number; reason:string; leaseUntil:number|null; }
export interface DeliveryPage { schemaVersion:1; clubId:number; items:DeliveryItem[]; nextAfterEventId:string|null; meaning:string; snapshot:false; }
export interface RedriveRequest {clubId:number;eventId:string;expectedRevision:number;requestId:string;reason:ReviewReason;}
export interface CommandReceipt {schemaVersion:1;operationId:string;eventId:string;action:'redrive';committed:true;resultingRevision:number;}
export interface Health {schemaVersion:1;clubId:number;observedAt:number;counts:Record<DeliveryState,number>;unmanagedLegacyAttempted:number;capped:boolean;snapshot:false;meaning:string;}
export class DeliveryClientError extends Error {constructor(public readonly code:string){super(code);this.name='DeliveryClientError';}}
const uuid=(x:unknown):x is string=>typeof x==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(x);
const int=(x:unknown):x is number=>typeof x==='number'&&Number.isSafeInteger(x)&&x>=0;
const states:DeliveryState[]=['pending','leased','retry','dead','delivered'];
function demand(x:unknown,code='invalid_response'):asserts x{if(!x)throw new DeliveryClientError(code);}
function object(x:unknown):asserts x is Record<string,unknown>{demand(x!==null&&typeof x==='object'&&!Array.isArray(x));}
function keys(x:Record<string,unknown>,names:string[]){demand(Object.keys(x).length===names.length&&names.every(k=>Object.hasOwn(x,k)));}
function positiveClub(x:number){demand(int(x)&&x>0,'invalid_request');}
/** Caller supplies original operation IDs explicitly. Constructors and reads never issue writes. */
export class DeliveryReviewClient {
 constructor(private readonly binding:ReviewBinding){}
 async inspect(clubId:number,state:DeliveryState,afterEventId:string|null=null,limit=25):Promise<DeliveryPage>{
  positiveClub(clubId);demand(states.includes(state)&&(afterEventId===null||uuid(afterEventId))&&int(limit)&&limit>=1&&limit<=50,'invalid_request');
  const value=await this.binding.inspect({clubId,state,afterEventId,limit});object(value);
  keys(value,['schemaVersion','clubId','items','nextAfterEventId','meaning','snapshot']);
  demand(value.schemaVersion===1&&value.clubId===clubId&&value.snapshot===false&&typeof value.meaning==='string'&&Array.isArray(value.items)&&value.items.length<=limit);
  let last=afterEventId??'';
  for(const item of value.items){object(item);keys(item,['eventId','revision','state','attempts','cycleAttempts','reason','leaseUntil']);
   demand(uuid(item.eventId)&&item.eventId>last&&int(item.revision)&&item.revision>0&&item.state===state&&int(item.attempts)&&int(item.cycleAttempts)&&item.cycleAttempts<=item.attempts
    &&typeof item.reason==='string'&&(item.leaseUntil===null||int(item.leaseUntil)));last=item.eventId;}
  demand(value.nextAfterEventId===null||(uuid(value.nextAfterEventId)&&value.items.length===limit&&value.nextAfterEventId===last));
  return value as unknown as DeliveryPage;
 }
 async redrive(input:RedriveRequest):Promise<CommandReceipt>{
  positiveClub(input.clubId);demand(uuid(input.eventId)&&uuid(input.requestId)&&int(input.expectedRevision)&&input.expectedRevision>0
   &&['dependency_restored','configuration_corrected'].includes(input.reason),'invalid_request');
  // Sending may commit even if the transport rejects. Caller retains this same input for an explicit retry.
  let result:unknown;try{result=await this.binding.redrive({...input});}catch{throw new DeliveryClientError('write_outcome_unknown');}
  try{object(result);keys(result,['schemaVersion','operationId','eventId','action','committed','resultingRevision']);
   demand(result.schemaVersion===1&&result.operationId===input.requestId&&result.eventId===input.eventId&&result.action==='redrive'
    &&result.committed===true&&result.resultingRevision===input.expectedRevision+1);
   return result as unknown as CommandReceipt;
  }catch{throw new DeliveryClientError('write_outcome_unknown');}
 }
 async health(clubId:number):Promise<Health>{
  positiveClub(clubId);const value=await this.binding.health({clubId});object(value);
  keys(value,['schemaVersion','clubId','observedAt','counts','unmanagedLegacyAttempted','capped','snapshot','meaning']);
  demand(value.schemaVersion===1&&value.clubId===clubId&&int(value.observedAt)&&value.snapshot===false&&typeof value.capped==='boolean'&&typeof value.meaning==='string');
  object(value.counts);keys(value.counts,states);for(const n of Object.values(value.counts))demand(int(n)&&n<=1000);
  demand(int(value.unmanagedLegacyAttempted)&&value.unmanagedLegacyAttempted<=1000);
  return value as unknown as Health;
 }
}
