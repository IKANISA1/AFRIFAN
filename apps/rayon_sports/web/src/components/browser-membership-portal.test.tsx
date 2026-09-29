// @vitest-environment-options {"url":"https://qa.example.invalid"}
import {act, cleanup, fireEvent, render, screen, waitFor} from '@testing-library/react';
import {afterEach, beforeEach, describe, expect, it, vi} from 'vitest';
import {BrowserMembershipPortal} from './browser-membership-portal';

const origin='https://qa.example.invalid';
const user='99590000-0000-4000-8000-000000000100';
const session='99590000-0000-4000-8000-000000000200';
const membership='99590000-0000-4000-8000-000000000300';
let signedIn:boolean,club:number,holdSession:Promise<Response>|null;
let checkoutEnabled:boolean,loseCheckout:boolean;
const order='99590000-0000-4000-8000-000000000400';
let originalKey:string|null;
let authenticatedAt:number;
const transport=vi.fn();
const reply=(v:unknown,status=200)=>new Response(JSON.stringify(v),{status,headers:{'content-type':'application/json'}});
const sessionView=()=>({schemaVersion:1,clubId:club,userId:user,sessionId:session,authenticatedAt,
 expiresAt:Date.now()+300000,absoluteExpiresAt:Date.now()+3600000,role:'supporter',phoneVerified:true,csrfToken:'a'.repeat(64)});

beforeEach(()=>{
 authenticatedAt=Date.now()-1000;signedIn=true;club=24;holdSession=null;checkoutEnabled=false;loseCheckout=false;originalKey=null;transport.mockReset();localStorage.clear();
 Object.defineProperty(document,'visibilityState',{value:'visible',configurable:true});
 Object.defineProperty(navigator,'onLine',{value:true,configurable:true});
 Object.defineProperty(navigator,'locks',{value:undefined,configurable:true});
 Object.defineProperty(navigator,'serviceWorker',{value:undefined,configurable:true});
 transport.mockImplementation(async (url:string,init:RequestInit)=>{
  const path=new URL(url).pathname;
  if(path==='/v1/browser/session')return holdSession??(signedIn?reply(sessionView()):reply({schemaVersion:1,error:'unauthenticated'},401));
  if(path==='/v1/browser/membership/status')return reply({schemaVersion:1,clubId:club,userId:user,observedAt:Date.now(),historical:false,currentStatus:'active',isActive:true,
   membership:{membershipId:membership,tier:'gold',recordedStatus:'active',paymentStatus:'verified',renewedAt:Date.now()-1000,expiresAt:Date.now()+300000}});
  if(path==='/v1/browser/membership/offers')return checkoutEnabled?reply({schemaVersion:1,clubId:club,observedAt:Date.now(),preparationOnly:true,offers:[{tier:'gold',amount:10000,currency:'RWF',country:'RW'}]}):reply({schemaVersion:1,error:'browser_disabled'},503);
  if(path==='/v1/browser/membership/checkouts'){
   originalKey=new Headers(init.headers).get('idempotency-key');
   if(loseCheckout)return reply({schemaVersion:1,error:'checkout_outcome_unknown',outcome:'unknown',requestId:originalKey},503);
   return reply({schemaVersion:1,clubId:club,requestId:originalKey,orderId:order,tier:'gold',reused:false,paymentVerified:false,membershipActivated:false});
  }
  if(path==='/v1/browser/membership/checkouts/'+order)return reply({schemaVersion:1,clubId:club,orderId:order,tier:'gold',status:'pending_current',paymentEvidenceAllocated:false,observedAt:Date.now(),expiresAt:Date.now()+300000,
   paymentInstruction:{amount:10000,currency:'RWF',country:'RW',provider:'mtn',recipient:'123456',ussdCode:'*182*8*1*123456*10000#'}});
  if(path==='/v1/browser/session/logout'){signedIn=false;return reply({schemaVersion:1,loggedOut:true,scope:'current'});}
  if(path==='/v1/browser/session/start')return reply({schemaVersion:1,clubId:club,csrfToken:'b'.repeat(64),expiresAt:Date.now()+60000});
  if(path==='/v1/browser/session/challenge')return reply({schemaVersion:1,clubId:club,challengeId:session,expiresAt:Date.now()+60000,delivery:'queued_or_pending'});
  throw new Error(`Unexpected local test request: ${path} ${init.method}`);
 });
 vi.stubGlobal('fetch',transport);
});
afterEach(()=>{cleanup();vi.unstubAllGlobals();});
const mount=()=>render(<BrowserMembershipPortal origin={origin} clubId={club} clubName="Rayon"/>);

describe('cookie portal presentation and lifecycle',()=>{
 it('mounts through the real client with reads only; disabled checkout preserves membership',async()=>{
  mount();expect(await screen.findByText(membership)).toBeVisible();
  expect(transport.mock.calls.every(([,init])=>init.method==='GET')).toBe(true);
  expect(screen.getByRole('status')).toHaveTextContent('New checkouts are disabled');
  expect(screen.queryByRole('button',{name:/Confirm preparation/})).not.toBeInTheDocument();
 });
 it.each(['offline','pagehide'])('conceals private fields immediately on %s without a business write',async event=>{
  mount();await screen.findByText(membership);
  act(()=>window.dispatchEvent(new Event(event)));
  expect(screen.queryByText(membership)).not.toBeInTheDocument();
  expect(transport.mock.calls.some(([,init])=>init.method==='POST')).toBe(false);
 });
 it('conceals private fields on hidden lifecycle and back-forward restoration',async()=>{
  mount();await screen.findByText(membership);
  Object.defineProperty(document,'visibilityState',{value:'hidden',configurable:true});
  act(()=>document.dispatchEvent(new Event('visibilitychange')));
  expect(screen.queryByText(membership)).not.toBeInTheDocument();
  Object.defineProperty(document,'visibilityState',{value:'visible',configurable:true});
  fireEvent.click(screen.getByRole('button',{name:'Check session and refresh'}));await screen.findByText(membership);
  act(()=>window.dispatchEvent(new PageTransitionEvent('pageshow',{persisted:true})));
  expect(screen.queryByText(membership)).not.toBeInTheDocument();
 });
 it('another tab session signal hides private state; unrelated storage does not',async()=>{
  mount();await screen.findByText(membership);
  act(()=>window.dispatchEvent(new StorageEvent('storage',{key:'unrelated'})));
  expect(screen.getByText(membership)).toBeVisible();
  act(()=>window.dispatchEvent(new StorageEvent('storage',{key:'africlub-browser-session-change:v1'})));
  expect(screen.queryByText(membership)).not.toBeInTheDocument();
 });
 it('changes club with no previous-club presentation while the new read is unresolved',async()=>{
  const view=mount();await screen.findByText(membership);
  club=26;holdSession=new Promise(()=>{});
  view.rerender(<BrowserMembershipPortal origin={origin} clubId={26} clubName="Nkana"/>);
  expect(screen.queryByText(membership)).not.toBeInTheDocument();
  expect(screen.getByText('Nkana · Supporter membership')).toBeVisible();
  expect(screen.queryByText('Rayon · Supporter membership')).not.toBeInTheDocument();
 });
 it('rejects an origin mismatch without issuing session or checkout calls',async()=>{
  render(<BrowserMembershipPortal origin="https://foreign.example.invalid" clubId={24} clubName="Rayon"/>);
  expect(await screen.findByRole('alert')).toHaveTextContent('not configured');
  expect(transport).not.toHaveBeenCalled();
 });
 it('does not publish a delayed private read after unmount',async()=>{
  let release!:(r:Response)=>void;holdSession=new Promise(r=>{release=r;});
  const view=mount();await waitFor(()=>expect(transport).toHaveBeenCalled());view.unmount();
  await act(async()=>release(reply(sessionView())));
  expect(screen.queryByText(membership)).not.toBeInTheDocument();
 });
 it('requires labelled phone input and an explicit submit for code delivery',async()=>{
  signedIn=false;mount();const phone=await screen.findByLabelText('Phone number, including country code');
  expect(transport.mock.calls.some(([,init])=>init.method==='POST')).toBe(false);
  fireEvent.change(phone,{target:{value:'+250700000001'}});
  fireEvent.click(screen.getByRole('button',{name:'Request sign-in code'}));
  await screen.findByLabelText('One-time code');
  const calls=transport.mock.calls.filter(([,init])=>init.method==='POST');expect(calls).toHaveLength(2);
  expect(JSON.parse(calls[1][1].body)).toEqual({phone:'+250700000001'});
  expect(localStorage.length).toBe(0);
 });
 it('requires separate review and confirmation; double click prepares only one order',async()=>{
  checkoutEnabled=true;
  Object.defineProperty(navigator,'locks',{value:{request:async(_key:string,_options:unknown,fn:()=>unknown)=>await fn()},configurable:true});
  mount();await screen.findByText(membership);
  expect(transport.mock.calls.some(([,init])=>init.method==='POST')).toBe(false);
  fireEvent.click(screen.getByRole('button',{name:'Review gold'}));
  expect(screen.getByRole('heading',{name:'Review checkout preparation'})).toBeVisible();
  expect(transport.mock.calls.some(([,init])=>init.method==='POST')).toBe(false);
  const confirm=screen.getByRole('button',{name:'Confirm preparation only'});fireEvent.click(confirm);fireEvent.click(confirm);
  await screen.findByText(order);
  const writes=transport.mock.calls.filter(([,init])=>init.method==='POST');expect(writes).toHaveLength(1);
  expect(screen.getByText('*182*8*1*123456*10000#')).toBeVisible();
  expect(screen.queryByRole('link',{name:/dial|pay/i})).not.toBeInTheDocument();
  const saved=Object.values(localStorage);expect(JSON.stringify(saved)).not.toMatch(/csrfToken|phone|code|cookie/);
 });
 it('requires explicit confirmation before retrying an uncertain original checkout',async()=>{
  checkoutEnabled=true;loseCheckout=true;
  Object.defineProperty(navigator,'locks',{value:{request:async(_key:string,_options:unknown,fn:()=>unknown)=>await fn()},configurable:true});
  mount();await screen.findByText(membership);fireEvent.click(screen.getByRole('button',{name:'Review gold'}));
  fireEvent.click(screen.getByRole('button',{name:'Confirm preparation only'}));
  const retry=await screen.findByRole('button',{name:'Retry original checkout request'});
  expect(retry).toBeDisabled();await waitFor(()=>expect(screen.getByRole('status')).toHaveTextContent('outcome is unknown'));
  const key=originalKey;expect(key).toBeTruthy();loseCheckout=false;
  fireEvent.click(screen.getByRole('checkbox'));fireEvent.click(retry);await screen.findByText(order);
  const writes=transport.mock.calls.filter(([,init])=>init.method==='POST');expect(writes).toHaveLength(2);
  expect(new Headers(writes[1][1].headers).get('idempotency-key')).toBe(key);
 });
 it('signs out explicitly and conceals membership before the response',async()=>{
  mount();await screen.findByText(membership);
  fireEvent.click(screen.getByRole('button',{name:'Sign out'}));
  expect(screen.queryByText(membership)).not.toBeInTheDocument();
  await screen.findByLabelText('Phone number, including country code');
  const writes=transport.mock.calls.filter(([,init])=>init.method==='POST');expect(writes).toHaveLength(1);
  expect(new URL(writes[0][0]).pathname).toBe('/v1/browser/session/logout');
 });
});
