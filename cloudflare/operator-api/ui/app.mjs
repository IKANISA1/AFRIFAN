import {OperatorPublicationClient} from './client.js';
import {PublicationController,KEY_PREFIX} from './controller.js';
const $=id=>document.getElementById(id),clubId=Number(document.body.dataset.clubId);
const messages={
 request_interrupted:'The request was interrupted. A confirmation may already have reached the server. Check the result before taking another action.',
 invalid_response:'The server returned an unexpected response. No success is assumed. Check the recorded operation.',
 operator_not_authorized:'Your club permission is missing, expired, or revoked. Contact the club administrator.',
 access_required:'Sign-in is required. Sign in through the protected operator address, then refresh access.',
 operator_identity_changed:'The signed-in operator changed. Refresh access. The previous operator’s recovery record has been preserved.',
 publication_conflict:'The published version changed. Do not confirm this review. Check the result or leave an unsent review and inspect the new version.',
 review_expired:'This review has expired. An unsent review can be left and recreated; an uncertain publication must be checked first.',
 review_no_longer_authorized:'This review is no longer authorized. Refresh access and check any outstanding result.',
 local_recovery_unavailable:'This browser cannot provide durable recovery storage and cross-tab locking. Publication is disabled; use a supported secure browser with storage enabled.',
 local_recovery_corrupt:'A stored recovery record cannot be validated. Publication is blocked. Preserve the record and contact support rather than starting a duplicate operation.',
 recovery_mismatch:'The stored operation does not match the server response. Publication is blocked. Preserve this record and contact support.',
 pending_operation_exists:'An existing review or publication must be resolved first. Refresh access to load it.',
 another_tab_busy:'Another tab is handling this club’s publication. Let that action finish, then check the result here.',
 another_tab_changed:'Another tab changed the pending operation. Check the result before continuing.',
 unknown_outcome_unresolved:'The previous outcome is still unknown. Only status checks or an explicit retry of the same operation are allowed.',
 explicit_confirmation_required:'Review the exact candidate, select the acknowledgement, and type the displayed confirmation phrase.',
 snapshot_not_reviewable:'This snapshot is stale, inconsistent, or not reviewable. Choose a fresh complete import.',
 snapshot_not_verified:'Create a verification review before loading the public projection.',
 source_stale:'The source snapshot is stale. A new approved import is required.',
 rate_limited:'The operator request limit was reached. Pause before checking again; no automatic retry will occur.',
 invalid_review_reference:'Use the actual editorial review reference: 3–160 letters, numbers, periods, underscores, colons, slashes or hyphens.',
 operator_api_disabled:'The operator service is disabled. Publication is not available.',publication_disabled:'The publisher is disabled. No new publication is available.',
};
const el=(tag,text,cls)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=String(text);if(cls)n.className=cls;return n;};
const displayDate=x=>x?new Date(x).toLocaleString('en-GB',{dateStyle:'medium',timeStyle:'short',timeZone:'UTC'})+' UTC':'None';
const readable=k=>k.replace(/([a-z])([A-Z])/g,'$1 $2').replace(/_/g,' ').replace(/^./,s=>s.toUpperCase());
function details(target,pairs){const dl=el('dl');for(const [k,v,cls] of pairs){dl.append(el('dt',k),el('dd',v??'None',cls));}target.replaceChildren(dl);}
function setHidden(id,hidden){$(id).hidden=hidden;}
let lastPhase='',lastReview=null,lastState;
let storage;try{storage=window.localStorage;}catch{storage=null;}
const client=new OperatorPublicationClient(location.origin);
const controller=new PublicationController(client,clubId,{storage,locks:navigator.locks,onChange:render});
function confirmAvailability(){
 const s=lastState;if(!s)return;
 $('publish').disabled=s.busy||!s.canMutate||!s.session?.canPublish||s.review?.state!=='ready'||controller.remainingSeconds===0||
   !$('acknowledge').checked||$('confirmation').value!==controller.confirmationText;
 $('countdown').textContent=s.review?`Review expires ${displayDate(s.review.expiresAt)} · ${controller.remainingSeconds}s remaining`:'';
}
function render(s){
 lastState=s;document.title='Content publication · AFRICLUB';
 $('club-context').textContent=s.session?`${s.session.clubSlug} · Club ${clubId}`:'Checking operator access…';
 $('permission-context').textContent=s.session?(s.session.canPublish?'Review and publication permitted':s.session.canReview?'Review permitted · Publication not permitted':'Read-only access'):'';
 const phaseLabels={loading:'Loading protected workspace…',select:'Choose a snapshot to inspect.',inspect:'Inspect the import and record the actual editorial review.',reviewed:'Verification passed. Nothing has been published.',unknown:'Publication outcome requires verification.',expired:'The review has expired.',invalidated:'Permissions changed after review.',published:'The server returned a publication receipt.',unavailable:'The workspace is unavailable.',identity_changed:'Sign-in changed. Refresh access.'};
 $('status').textContent=s.busy?'Checking authoritative state…':phaseLabels[s.phase]??'Check the review state.';
 $('error').textContent=s.error?(messages[s.error]??'The action could not be verified. Refresh access or check the existing operation; no success is assumed.'):'';setHidden('error',!s.error);
 details($('head-details'),s.head?[
   ['Snapshot',s.head.snapshotId??'No published snapshot','hash'],['Captured',displayDate(s.head.capturedAt)],['Published',displayDate(s.head.activatedAt)],['Freshness',s.head.snapshotId?(s.head.fresh?'Fresh source':'Stale source'):'Not published']
 ]:[['Status',s.currentHeadUnavailable?'Current version could not be checked':'Not loaded']]);
 setHidden('select-section',!s.session||!!s.pending);setHidden('candidate-section',!s.candidate);
 setHidden('review-form',!!s.pending);setHidden('review-section',!s.review||s.phase==='published');
 setHidden('confirm-section',!s.pending||s.phase==='published');setHidden('receipt-section',!s.receipt);setHidden('recovery-note',s.pending?.phase!=='unknown');
 $('reload').disabled=s.busy;$('inspect').disabled=s.busy||!!s.pending;
 const buttons=[];for(const c of s.candidates){const b=el('button',undefined,'secondary');b.type='button';b.disabled=s.busy||!!s.pending;b.setAttribute('aria-label',`Inspect snapshot ${c.snapshotId.slice(0,12)}`);b.setAttribute('aria-current',String(c.snapshotId===s.candidate?.snapshotId));
 b.append(el('span',`${displayDate(c.capturedAt)} · ${c.fresh?'Fresh':'Stale'}`),el('span',`${c.status} · ${c.snapshotId.slice(0,16)}…`,'small hash'));
 b.addEventListener('click',()=>controller.inspect(c.snapshotId));buttons.push(b);}
 $('candidates').replaceChildren(...(buttons.length?buttons:[el('p','No reviewable snapshots are available. Import a complete approved source first.','muted')]));setHidden('more',!s.hasMore);
 if(s.candidate){const c=s.candidate;details($('candidate-details'),[['Snapshot ID',c.snapshotId,'hash'],['Manifest hash',c.manifestHash,'hash'],['Captured',displayDate(c.capturedAt)],['Import state',c.status],['Source records',c.rowCount],['Registered media',c.mediaCount],['Freshness',c.fresh?'Fresh':'Stale']]);
   const table=el('table',undefined,'table-counts');const caption=el('caption','Imported record counts');caption.className='small muted';table.append(caption);
   const h=el('tr');const sourceHeader=el('th','Source table'),countHeader=el('th','Records');sourceHeader.scope='col';countHeader.scope='col';h.append(sourceHeader,countHeader);const head=el('thead');head.append(h);table.append(head);const body=el('tbody');
   for(const t of c.tables){const row=el('tr');row.append(el('td',readable(t.name)),el('td',t.count));body.append(row);}table.append(body);$('table-counts').replaceChildren(table);
 }
 $('review').disabled=s.busy||!s.canMutate||!s.session?.canReview||!s.candidate?.fresh||!['importing','sealed','verified'].includes(s.candidate?.status)||s.candidate?.snapshotId!==s.candidate?.manifestHash;
 if(s.review){const r=s.review;details($('review-details'),[['Review ID',r.reviewId,'hash'],['Reviewed snapshot',r.snapshotId,'hash'],['Previous snapshot',r.expectedPreviousId??'First publication','hash'],['Evidence reference',r.reviewRef],['Review state',r.state]]);
   if(lastReview!==r.reviewId){$('acknowledge').checked=false;$('confirmation').value='';lastReview=r.reviewId;}
 }
 $('confirmation-phrase').textContent=controller.confirmationText;
 $('publish').textContent=s.pending?.phase==='unknown'?'Retry same publication':'Publish reviewed snapshot';
 $('check-result').disabled=s.busy;$('reset').disabled=s.busy||!s.canMutate;setHidden('reset',s.pending?.phase==='unknown');
 $('acknowledge').disabled=s.busy;$('confirmation').disabled=s.busy;$('evidence').disabled=s.busy;
 $('preview-load').disabled=s.busy||!s.review||!['ready','published'].includes(s.review.state);$('preview-next').disabled=s.busy;
 if(s.preview){const p=s.preview;const nodes=[el('p',`${p.route} · ${p.offset+1}–${p.offset+p.rows.length} of ${p.total} public records`,'small muted')];
   if(!p.rows.length)nodes[0].textContent='No eligible public records for this section.';
   for(const row of p.rows){const article=el('article');article.append(el('h3',String(row.title??row.name??row.homeTeam??row.id??'Public record')));const pairs=[];
     for(const [key,value] of Object.entries(row)){const text=value===null?'None':typeof value==='object'?JSON.stringify(value,null,2):String(value);pairs.push([readable(key),text]);}
     const body=el('div');details(body,pairs);article.append(body);nodes.push(article);}
   $('preview').replaceChildren(...nodes);
 }else $('preview').replaceChildren();
 setHidden('preview-next',!s.preview||s.preview.nextOffset===null);
 if(s.receipt){const r=s.receipt;details($('receipt-details'),[['Operation ID',r.operationId,'hash'],['Snapshot',r.snapshotId,'hash'],['Previous snapshot',r.previousSnapshotId??'First publication','hash'],['Confirmed at',displayDate(r.publishedAt)],['Result',r.replayed?'Recovered existing receipt':'Published'],['Currently active',s.currentHeadUnavailable?'Not verified':s.head?.snapshotId===r.snapshotId?'Yes':'No; another version may now be active']]);}
 $('next-review').disabled=s.busy||!s.canMutate;
 confirmAvailability();
 if(!s.busy&&s.phase!==lastPhase){const target={inspect:'candidate-heading',reviewed:'review-heading',published:'receipt-heading'}[s.phase];if(target)$(target).focus();lastPhase=s.phase;}
}
$('inspect-form').addEventListener('submit',e=>{e.preventDefault();controller.inspect($('snapshot-input').value.trim());});
$('review-form').addEventListener('submit',e=>{e.preventDefault();controller.review($('evidence').value.trim());});
$('confirm-form').addEventListener('submit',e=>{e.preventDefault();controller.confirm({acknowledged:$('acknowledge').checked,confirmation:$('confirmation').value});$('acknowledge').checked=false;$('confirmation').value='';});
$('acknowledge').addEventListener('change',confirmAvailability);$('confirmation').addEventListener('input',confirmAvailability);
$('reload').addEventListener('click',()=>{lastReview=null;$('acknowledge').checked=false;$('confirmation').value='';controller.init();});
$('check-result').addEventListener('click',()=>controller.checkResult());$('reset').addEventListener('click',()=>controller.reset());$('next-review').addEventListener('click',()=>controller.reset());
$('preview-load').addEventListener('click',()=>controller.loadPreview($('preview-route').value));
$('preview-next').addEventListener('click',()=>controller.loadPreview(lastState.preview.route,lastState.preview.nextOffset));
window.addEventListener('storage',e=>{if(e.key?.startsWith(KEY_PREFIX)&&!lastState?.busy){lastReview=null;controller.init();}});
window.addEventListener('pageshow',e=>{if(e.persisted){lastReview=null;controller.init();}});
window.addEventListener('beforeunload',e=>{if(lastState?.busy&&lastState?.pending?.phase==='unknown'){e.preventDefault();e.returnValue='';}});
setInterval(confirmAvailability,1000);controller.init();
