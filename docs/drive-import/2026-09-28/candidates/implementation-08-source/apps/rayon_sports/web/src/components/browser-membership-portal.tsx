"use client";
import {useEffect,useState,useSyncExternalStore} from 'react';
import {BrowserMemberClient,createBrowserRecoveryStore} from '../../../../../cloudflare/supporter-browser-api/client';
import {MembershipPortalController,INITIAL_PORTAL_STATE} from '../../../../../cloudflare/supporter-browser-api/portal-controller';
import {checkPrivateCacheBoundary} from '../../../../../cloudflare/supporter-browser-api/browser-platform';
import styles from './browser-membership-portal.module.css';
const SIGNAL='africlub-browser-session-change:v1';
const subscribeNone=()=>()=>{};
const snapshotInitial=()=>INITIAL_PORTAL_STATE;

export function BrowserMembershipPortal({origin,clubId,clubName}:{origin:string;clubId:number;clubName:string}){
 const [controller,setController]=useState<MembershipPortalController|null>(null);
 const [setupError,setSetupError]=useState(false),[phone,setPhone]=useState(''),[code,setCode]=useState('');
 const [retryConfirmed,setRetryConfirmed]=useState(false);
 const state=useSyncExternalStore(controller?.subscribe??subscribeNone,controller?.getSnapshot??snapshotInitial,snapshotInitial);
 useEffect(()=>{
  if(window.location.origin!==origin){setSetupError(true);return;}
  let store;
  try{if(navigator.locks)store=createBrowserRecoveryStore(window.localStorage,navigator.locks);}catch{/* Read-only presentation remains possible. */}
  const client=new BrowserMemberClient(origin,clubId,{recoveryStore:store,rememberLastCheckout:true});
  const c=new MembershipPortalController(client,{canCheckout:!!store,key:()=>crypto.randomUUID(),
   active:()=>document.visibilityState==='visible'&&navigator.onLine,
   checkCacheBoundary:()=>checkPrivateCacheBoundary(navigator.serviceWorker),
   notifySessionChange:()=>{try{window.localStorage.setItem(SIGNAL,crypto.randomUUID());}catch{/* No business retry. */}}});
  setController(c);void c.refresh();
  const conceal=()=>{setPhone('');setCode('');setRetryConfirmed(false);c.invalidate();};
  const visibility=()=>{if(document.visibilityState!=='visible')conceal();};
  const storage=(event:StorageEvent)=>{if(event.key===SIGNAL)conceal();};
  window.addEventListener('storage',storage);window.addEventListener('offline',conceal);window.addEventListener('pagehide',conceal);
  document.addEventListener('visibilitychange',visibility);
  navigator.serviceWorker?.addEventListener('controllerchange',conceal);
  const restored=(event:PageTransitionEvent)=>{if(event.persisted)conceal();};window.addEventListener('pageshow',restored);
  const tick=window.setInterval(()=>c.tick(Date.now()),1000);
  return ()=>{clearInterval(tick);c.invalidate();window.removeEventListener('storage',storage);window.removeEventListener('offline',conceal);
   window.removeEventListener('pagehide',conceal);document.removeEventListener('visibilitychange',visibility);navigator.serviceWorker?.removeEventListener('controllerchange',conceal);window.removeEventListener('pageshow',restored);};
 },[origin,clubId]);
 const disabled=!controller||state.busy;
 const money=(amount:number,currency:string)=>`${amount.toLocaleString('en')} ${currency}`;
 const time=(ms:number)=>new Date(ms).toLocaleString();
 return <section className={styles.portal} aria-labelledby="browser-membership-title" aria-busy={state.busy}>
  <header><p className={styles.eyebrow}>{clubName} · Supporter membership</p><h1 id="browser-membership-title">Your club. Your membership.</h1>
   <p>Sign in to see your current membership and review club-approved checkout details.</p></header>
  {setupError?<p role="alert">This membership page is not configured for this website. Contact support.</p>:<>
   <div className={styles.actions}><button disabled={disabled} onClick={()=>void controller?.refresh()}>Check session and refresh</button><a href="/support">Help and support</a></div>
   <p role="status" aria-live="polite" className={styles.message}>{state.busy?'Checking your request…':state.message}</p>
   {state.phase==='signed_out'&&<form className={styles.card} onSubmit={event=>{event.preventDefault();const value=phone;setPhone('');void controller?.requestCode(value);}}>
    <h2>Sign in</h2><label htmlFor="browser-member-phone">Phone number, including country code</label>
    <input id="browser-member-phone" type="tel" autoComplete="tel" inputMode="tel" required pattern="\+[1-9][0-9]{7,14}" value={phone} onChange={e=>setPhone(e.target.value)} disabled={disabled}/>
    <button disabled={disabled||state.canRetrySignIn}>Request sign-in code</button><p>Never enter your mobile-money PIN here.</p>
   </form>}
   {state.phase==='code_sent'&&<form className={styles.card} onSubmit={event=>{event.preventDefault();const value=code;setCode('');void controller?.verifyCode(value);}}>
    <h2>Enter your sign-in code</h2><label htmlFor="browser-member-code">One-time code</label>
    <input id="browser-member-code" type="text" inputMode="numeric" autoComplete="one-time-code" required pattern="[0-9]{6}" maxLength={6} value={code} onChange={e=>setCode(e.target.value)} disabled={disabled}/>
    <button disabled={disabled||state.canRetrySignIn}>Verify code</button>
   </form>}
   {state.canRetrySignIn&&<button disabled={disabled} onClick={()=>void controller?.retrySignIn()}>Retry the same sign-in request</button>}
   {state.canRetrySession&&<button disabled={disabled} onClick={()=>void controller?.retrySession()}>Retry the same session request</button>}
   {state.phase==='member'&&<>
    <article className={styles.card}><h2>Current membership</h2><p className={styles.status}>{state.membership?.currentStatus.replace('_',' ')}</p>
     <p>This is the current observed status, not a historical payment receipt.</p>
     {state.membership?.membership&&<dl><dt>Membership number</dt><dd>{state.membership.membership.membershipId}</dd><dt>Tier</dt><dd>{state.membership.membership.tier}</dd>
      <dt>Expiry</dt><dd>{state.membership.membership.expiresAt===null?'Not confirmed':time(state.membership.membership.expiresAt)}</dd></dl>}
     {state.membership&&<p>Observed {time(state.membership.observedAt)}</p>}
     <div className={styles.actions}><button disabled={disabled||state.canRetrySession} onClick={()=>void controller?.rotate()}>Renew browser session</button><button disabled={disabled||state.canRetrySession} onClick={()=>void controller?.logout()}>Sign out</button></div>
    </article>
    <article className={styles.card} aria-labelledby="membership-history-title"><h2 id="membership-history-title">Membership payment history</h2>
     <p>Recorded membership allocations, not a wallet balance or proof of current membership. Historical records do not confirm external settlement.</p>
     <div className={styles.actions}><button disabled={disabled||state.canRetrySession} onClick={()=>void controller?.loadHistory(false)}>Load latest records</button>
      {state.historyCursor&&<button disabled={disabled||state.canRetrySession} onClick={()=>void controller?.loadHistory(true)}>Show older records</button>}</div>
     {state.historyLoaded&&!state.history.length&&<p>No membership allocations were found in this page.</p>}
     {state.history.length>0&&<ul className={styles.offers}>{state.history.map(item=><li key={item.allocationId}>
      <h3>{money(item.amount,item.currency)}</h3><p>{time(item.recordedAt)}</p><p>Order <span>{item.orderId}</span></p>
      <button disabled={disabled||state.canRetrySession} aria-label={`Read historical receipt for order ${item.orderId}`} onClick={()=>void controller?.readHistoryReceipt(item.orderId)}>Read receipt</button>
     </li>)}</ul>}
     {state.historyLoaded&&!state.historyCursor&&state.history.length>0&&<p>No older records were returned for this observation. Refresh to check for later changes.</p>}
    </article>
    {state.historyReceipt&&<article className={styles.card} aria-labelledby="selected-history-receipt"><h2 id="selected-history-receipt">Selected historical receipt</h2>
     <dl><dt>Order</dt><dd>{state.historyReceipt.orderId}</dd><dt>Allocation</dt><dd>{state.historyReceipt.allocationId}</dd><dt>Recorded amount</dt><dd>{money(state.historyReceipt.amount,state.historyReceipt.currency)}</dd><dt>Recorded at</dt><dd>{time(state.historyReceipt.recordedAt)}</dd><dt>Membership at allocation</dt><dd>{state.historyReceipt.membershipAtAllocation.status}</dd></dl>
     <p>This historical status does not override suspension or expiry. No new order or payment has been made.</p>
     <button disabled={disabled} onClick={()=>controller?.closeHistoryReceipt()}>Close historical receipt</button>
    </article>}
    {state.pending&&<article className={styles.card}><h2>Unresolved checkout request</h2><p>Do not create a replacement request or assume that a payment failed. First check the original result.</p>
     <button disabled={disabled||state.canRetrySession} onClick={()=>void controller?.recoverCheckout()}>Check original result</button>
     <label><input type="checkbox" checked={retryConfirmed} onChange={e=>setRetryConfirmed(e.target.checked)}/> I am retrying the same preparation request, not making another payment.</label>
     <button disabled={disabled||!retryConfirmed||state.canRetrySession} onClick={()=>{setRetryConfirmed(false);void controller?.retryCheckout();}}>Retry original checkout request</button>
    </article>}
    <article className={styles.card}><h2>Available membership tiers</h2><p>Amounts use the checkout service’s configured units. Preparation does not send money or activate membership.</p>
     {!state.offers.length?<p>No approved checkout tiers are available.</p>:<ul className={styles.offers}>{state.offers.map(offer=><li key={offer.tier}><h3>{offer.tier}</h3><p>{money(offer.amount,offer.currency)}</p>
      <button disabled={disabled||!state.canCheckout||state.pending||state.canRetrySession} onClick={()=>controller?.selectTier(offer.tier)}>Review {offer.tier}</button></li>)}</ul>}
    </article>
    {state.review&&<article className={styles.card} aria-labelledby="browser-checkout-review"><h2 id="browser-checkout-review">Review checkout preparation</h2><p>{state.review.tier} · {money(state.review.amount,state.review.currency)}</p>
     <p>This prepares an order only. The current recipient, price and payment route will be shown afterwards. No dialer opens and no money is sent.</p>
     <div className={styles.actions}><button disabled={disabled||state.canRetrySession} onClick={()=>void controller?.confirmCheckout()}>Confirm preparation only</button><button disabled={disabled} onClick={()=>controller?.cancelReview()}>Cancel</button></div>
    </article>}
    {state.checkout&&<article className={styles.card}><h2>Current checkout</h2><dl><dt>Order</dt><dd>{state.checkout.orderId}</dd><dt>Status</dt><dd>{state.checkout.status.replaceAll('_',' ')}</dd></dl>
     {state.checkout.paymentInstruction&&<><p>Verify these server-provided details before any separate payment. This page does not place a call or enter a PIN.</p><dl>
      <dt>Amount</dt><dd>{money(state.checkout.paymentInstruction.amount,state.checkout.paymentInstruction.currency)}</dd><dt>Recipient</dt><dd>{state.checkout.paymentInstruction.recipient}</dd>
      <dt>Provider</dt><dd>{state.checkout.paymentInstruction.provider}</dd><dt>USSD instruction</dt><dd><code>{state.checkout.paymentInstruction.ussdCode}</code></dd></dl></>}
     <p>{state.checkout.paymentEvidenceAllocated?'Payment evidence is allocated; check current membership separately.':'No payment confirmation is shown.'}</p>
     <div className={styles.actions}><button disabled={disabled} onClick={()=>void controller?.refreshCheckout()}>Check current order</button>{state.checkout.status==='allocated'&&<button disabled={disabled} onClick={()=>void controller?.readReceipt()}>Read historical receipt</button>}</div>
    </article>}
    {state.receipt&&<article className={styles.card}><h2>Historical receipt</h2><p>{money(state.receipt.amount,state.receipt.currency)} · {time(state.receipt.recordedAt)}</p><p>Membership at allocation: {state.receipt.membershipAtAllocation.status}. This does not override current suspension or expiry.</p></article>}
   </>}
  </>}
 </section>;
}
