import {PaymentCaseClient} from './case-client.js';
import {CaseController,actionsFor} from './case-controller.js';
const $=id=>document.getElementById(id),clubId=Number(document.body.dataset.clubId);
// Storage access itself may throw in privacy-restricted browsers. Fail at use,
// rather than constructing a silent in-memory fallback for pending operations.
const storage={getItem:k=>localStorage.getItem(k),setItem:(k,v)=>localStorage.setItem(k,v),removeItem:k=>localStorage.removeItem(k)};
const controller=new CaseController({client:new PaymentCaseClient(location.origin),clubId,storage,foreground:()=>document.visibilityState==='visible'});
let opening=false,working=false;
const labels={open:'Open a case',triage:'Start investigation',propose:'Propose disposition',approve:'Approve proposal',reject:'Reject proposal',close:'Close reviewed case',reopen:'Reopen case'};
const errors={not_found:'No result is currently visible. This does not prove an in-flight command failed.',stale_review:'The case changed. Refresh it and review the new revision.',stale_revision:'The server rejected an outdated revision. Check the original operation before starting a new review.',
 action_not_allowed:'Your current role or case state does not permit this action.',operator_changed:'The signed-in operator changed. Reload to establish a new workspace.',
 recovery_storage_unavailable:'Recovery storage is unavailable or changed. Writes are blocked. Preserve the operation ID and contact support; do not clear storage to retry.',
 forbidden:'Access is no longer permitted. Refresh access after an authorized operator resolves it.',authentication_required:'Sign-in is required. No new operation should be started until the original result is checked.',
 foreground_required:'Return to this page and review the command before confirming.',review_invalidated:'The review was invalidated. Review the current case again.',reference_required:'Provide a valid order or evidence UUID.',invalid_category:'Select a supported category.',
 evidence_digest_required:'Provide the existing evidence’s 64-character SHA-256 digest.',invalid_recovery_record:'The command or recovery record is invalid. Check the references and digest.',
 recovery_required:'Resolve the pending command before preparing another.',acknowledgement_required:'Acknowledge the exact command before continuing.'};
function text(tag,value,className){const e=document.createElement(tag);e.textContent=value===null?'Not recorded':String(value);if(className)e.className=className;return e;}
function details(id,values){const root=$(id);root.replaceChildren();const dl=document.createElement('dl');for(const [k,v] of Object.entries(values)){dl.append(text('dt',k),text('dd',v));}root.append(dl);}
function message(error){$('error').textContent=errors[error?.code]??'The request could not be verified. Preserve any pending operation and check its original result.';$('error').hidden=false;}
function commandFields(){const a=$('action').value;$('open-fields').hidden=a!=='open';$('propose-fields').hidden=a!=='propose';$('evidence-digest').required=['propose','close'].includes(a);}
function render(){
 const c=controller,access=c.session,locked=working||c.busy||c.accessLost;
 $('club-context').textContent=access?`Club ${clubId} · authenticated operator`:'Access not established';
 $('role-context').textContent=access&&!c.accessLost?[access.canMake?'Case maker':null,access.canReview?'Case checker':null,!access.canMake&&!access.canReview?'Read-only':null].filter(Boolean).join(' · '):'Access must be refreshed';
 $('pending-section').hidden=!c.pending;$('receipt-section').hidden=!c.receipt;
 if(c.pending)details('pending-details',{'Operation':c.pending.operationId,'Case':c.pending.caseId,'Action':labels[c.pending.action],'Expected revision':c.pending.expectedRevision});
 if(c.receipt)details('receipt-details',{'Operation':c.receipt.outcome.operationId,'Recorded action':labels[c.receipt.outcome.action],'Recorded revision':c.receipt.outcome.revision,'Latest revision':c.receipt.currentCase.revision,'Latest state':c.receipt.currentCase.state,'Financial effect':'None'});
 $('check-operation').disabled=locked;$('retry-operation').disabled=locked||!$('retry-ack').checked||c.storageFault;
 $('discard-rejected').hidden=!c.rejected;$('discard-rejected').disabled=locked||!$('retry-ack').checked;
 $('case-list').replaceChildren();
 if(!c.cases.length)$('case-list').append(text('p','No cases in this loaded page.','muted'));
 for(const r of c.cases){const b=text('button','');b.type='button';b.disabled=locked;b.append(text('span',r.category.replaceAll('_',' ')),text('span',`${r.state} · revision ${r.revision}`,'small'),text('span',r.caseId,'hash'));b.addEventListener('click',()=>run(async()=>{opening=false;await c.select(r.caseId);},'detail-heading'));$('case-list').append(b);}
 $('more-cases').hidden=!c.nextCaseId;$('more-cases').disabled=locked;$('refresh-list').disabled=locked||!access;
 $('state-filter').disabled=locked||!access;$('new-case').disabled=locked||!access?.canMake||!!c.pending||c.storageFault;
 $('refresh-access').disabled=working||c.busy;
 $('detail-section').hidden=!c.record;$('refresh-selected').disabled=locked||!c.record;
 if(c.record){const r=c.record;details('case-details',{'Case':r.caseId,'Category':r.category,'State':r.state,'Revision':r.revision,'Order reference':r.orderId,'Evidence reference':r.evidenceId,'Disposition':r.disposition,'Proposal digest':r.proposalDigest,'Proposer':r.proposerSubject,'Reviewer':r.reviewerSubject,'Financial effect':'None','References verified':'No'});}
 $('self-review-note').hidden=!(c.record?.state==='awaiting_review'&&c.record.proposerSubject===access?.subject);
 const actions=opening?actionsFor(access,null):c.record?actionsFor(access,c.record):[];
 const prev=$('action').value;$('action').replaceChildren(...actions.map(a=>{const o=text('option',labels[a]);o.value=a;return o;}));if(actions.includes(prev))$('action').value=prev;
 $('command-section').hidden=actions.length===0||!!c.pending||c.accessLost||c.storageFault;
 $('stage-command').disabled=locked;commandFields();
 $('confirm-section').hidden=!c.draft;
 if(c.draft)details('review-details',{'Club':clubId,'Case':c.draft.caseId,'Action':labels[c.draft.action],'Expected revision':c.draft.expectedRevision,'Operation':c.draft.operationId,...c.draft.detail});
 $('confirm-command').disabled=locked||!$('confirm-ack').checked;$('cancel-review').disabled=locked;
 $('history-section').hidden=!c.record;$('case-history').replaceChildren();
 for(const e of c.events){const a=document.createElement('article');a.append(text('h3',`Revision ${e.revision} · ${labels[e.action]}`),text('p',`${e.reasonCode} · ${new Date(e.recordedAt).toISOString()}`,'small'),text('p',`Actor: ${e.actorSubject}`,'hash'),text('p',`Operation: ${e.operationId}`,'hash'));$('case-history').append(a);}
 $('more-history').hidden=!c.nextRevision;$('more-history').disabled=locked;
}
async function run(fn,focus){
 if(working)return;working=true;$('error').hidden=true;$('status').textContent='Checking the authoritative case service…';render();
 try{await fn();$('status').textContent='Workspace updated. Case review does not move money.';}
 catch(e){if([401,403].includes(e.status))controller.suspend();message(e);$('status').textContent='The request was not verified.';}
 finally{working=false;render();if(focus&&!$(focus).closest('[hidden]'))$(focus).focus();}
}
$('refresh-access').addEventListener('click',()=>run(()=>controller.boot()));
$('refresh-list').addEventListener('click',()=>run(()=>controller.list(false)));
$('more-cases').addEventListener('click',()=>run(()=>controller.list(true)));
$('state-filter').addEventListener('change',()=>run(async()=>{controller.stateFilter=$('state-filter').value||null;await controller.list(false);}));
$('new-case').addEventListener('click',()=>{opening=true;controller.invalidateReview();controller.record=null;controller.events=[];$('command-form').reset();render();$('command-heading').focus();});
$('action').addEventListener('change',()=>{controller.invalidateReview();commandFields();render();});
$('command-form').addEventListener('input',()=>{if(controller.draft){controller.invalidateReview();render();}});
$('command-form').addEventListener('submit',e=>{e.preventDefault();run(async()=>{
 const action=$('action').value,detail={reasonCode:$('reason').value,evidenceDigest:$('evidence-digest').value.trim()||null};
 if(action==='open')Object.assign(detail,{category:$('category').value,orderId:$('order-id').value.trim()||null,evidenceId:$('evidence-id').value.trim()||null});
 if(action==='propose')detail.disposition=$('disposition').value;
 controller.stage(action,detail);$('confirm-ack').checked=false;
 },'confirm-heading');});
$('confirm-ack').addEventListener('change',render);$('retry-ack').addEventListener('change',render);
$('cancel-review').addEventListener('click',()=>{controller.invalidateReview();render();});
$('confirm-form').addEventListener('submit',e=>{e.preventDefault();run(async()=>{await controller.confirm($('confirm-ack').checked);opening=false;},'receipt-heading');});
$('check-operation').addEventListener('click',()=>run(()=>controller.recover(),'receipt-heading'));
$('retry-operation').addEventListener('click',()=>run(()=>controller.retry($('retry-ack').checked),'receipt-heading'));
$('discard-rejected').addEventListener('click',()=>run(async()=>controller.discardRejected($('retry-ack').checked)));
$('refresh-selected').addEventListener('click',()=>run(()=>controller.select(controller.record.caseId),'detail-heading'));
$('more-history').addEventListener('click',()=>run(()=>controller.moreHistory()));
// No background/resume timer can issue a command. Invalidating a review does not
// claim to cancel a request which was already sent to the server.
document.addEventListener('visibilitychange',()=>{if(document.visibilityState!=='visible'){controller.invalidateReview();render();}});
window.addEventListener('pagehide',()=>controller.invalidateReview());
window.addEventListener('storage',e=>{if(controller.session&&e.key===controller.key){controller.invalidateReview();if(!controller.busy){try{controller.loadPending();}catch(error){message(error);}render();}}});
run(()=>controller.boot());
