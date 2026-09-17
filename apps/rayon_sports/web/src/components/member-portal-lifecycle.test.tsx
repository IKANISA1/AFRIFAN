import {act, cleanup, fireEvent, render, screen, waitFor} from '@testing-library/react';
import {afterEach, beforeEach, describe, expect, it, vi} from 'vitest';
import {MemberPortal} from './member-portal';
const mocks=vi.hoisted(()=>({getUser:vi.fn(),signInWithOtp:vi.fn(),verifyOtp:vi.fn(),signOut:vi.fn(),rpc:vi.fn(),onAuthStateChange:vi.fn(),from:vi.fn(),unsubscribe:vi.fn()}));
vi.mock('@/lib/supabase/browser',()=>({getBrowserSupabase:()=>({auth:mocks,from:mocks.from,rpc:mocks.rpc})}));
type Result={data:unknown;error:null|{message:string}};
let rows:Record<string,Result|Promise<Result>>;
let confirmedTotal: string;
let nextCursor: {created_at:string;id:string}|null;
let historyOverride: Result|Promise<Result>|null;
let authChanged:(event:string,session:{user:{id:string}}|null)=>void;
const membership={member_code:'123456',membership_number:'QA-1',club_id:24,tier:'fan',status:'active',joined_at:'2026-09-16'};
const contribution={id:'99590000-0000-4000-8000-000000000401',initiative_id:'99590000-0000-4000-8000-000000000200',amount:1000,status:'confirmed',momo_reference:'QA-confirmed',created_at:'2026-09-16',confirmed_at:'2026-09-16'};
const queryCalls:{table:string;filters:unknown[][]}[]=[];
const refresh=()=>fireEvent.click(screen.getByRole('button',{name:'Refresh contribution history'}));
const mount=async()=>{render(<MemberPortal clubShortName="Rayon Sports FC"/>);await screen.findByText('123456');};
function deferred(){let resolve!:(v:Result)=>void;const promise=new Promise<Result>(r=>{resolve=r;});return {promise,resolve};}
beforeEach(()=>{
 vi.resetAllMocks();queryCalls.length=0;confirmedTotal='1000';nextCursor=null;historyOverride=null;
 rows={fan_memberships:{data:membership,error:null},initiatives:{data:[{id:'campaign',title:'Club campaign'}],error:null},initiative_contributions:{data:[contribution],error:null}};
 mocks.signInWithOtp.mockResolvedValue({error:null});mocks.verifyOtp.mockResolvedValue({error:null});
 mocks.getUser.mockResolvedValue({data:{user:{id:'supporter'}},error:null});mocks.signOut.mockResolvedValue({error:null});mocks.rpc.mockImplementation((name:string)=>{
   if(name!=='member_contribution_history')return Promise.resolve({data:[],error:null});
   queryCalls.push({table:'initiative_contributions',filters:[]});
   return historyOverride??Promise.resolve(rows.initiative_contributions).then(r=>r.error?r:{data:{confirmed_total:confirmedTotal,entries:r.data,next_cursor:nextCursor},error:null});
 });
 mocks.onAuthStateChange.mockImplementation((callback)=>{authChanged=callback;return {data:{subscription:{unsubscribe:mocks.unsubscribe}}};});
 mocks.from.mockImplementation((table:string)=>{const entry={table,filters:[] as unknown[][]};queryCalls.push(entry);const q={select:()=>q,eq:(...args:unknown[])=>{entry.filters.push(args);return q;},order:()=>q,limit:()=>q,maybeSingle:()=>Promise.resolve(rows[table]),then:(resolve:(v:Result)=>unknown,reject:(e:unknown)=>unknown)=>Promise.resolve(rows[table]).then(resolve,reject)};return q;});
});
afterEach(()=>{cleanup();vi.useRealTimers();});
describe('member portal authenticated data lifecycle',()=>{
 it('preserves confirmed history and reports a failed refresh',async()=>{await mount();rows.initiative_contributions={data:null,error:{message:'backend unavailable'}};refresh();await screen.findByRole('alert');expect(screen.getByText('QA-confirmed')).toBeVisible();expect(screen.getAllByText(/1,000/).length).toBeGreaterThan(0);expect(screen.queryByText('No contribution intents recorded yet.')).not.toBeInTheDocument();});
 it('does not present a campaign failure as an empty catalogue',async()=>{rows.initiatives={data:null,error:{message:'permission denied'}};render(<MemberPortal clubShortName="Rayon"/>);await screen.findByRole('alert');expect(screen.queryByText('No active campaign confirmed')).not.toBeInTheDocument();expect(screen.getByRole('button',{name:'Retry member area'})).toBeVisible();});
 it('recovers an initial data failure without reactivating membership',async()=>{rows.initiative_contributions={data:null,error:{message:'unavailable'}};render(<MemberPortal clubShortName="Rayon"/>);await screen.findByRole('alert');rows.initiative_contributions={data:[contribution],error:null};fireEvent.click(screen.getByRole('button',{name:'Retry member area'}));await screen.findByText('QA-confirmed');expect(mocks.rpc.mock.calls.some(([name])=>name==='activate_free_fan_membership')).toBe(false);});
 it('scopes campaign and history queries to the verified membership club',async()=>{await mount();expect(queryCalls.find(x=>x.table==='initiatives')?.filters).toContainEqual(['club_id',24]);expect(mocks.rpc).toHaveBeenCalledWith('member_contribution_history');});
 it('ignores a late history response after explicit sign-out',async()=>{await mount();const held=deferred();rows.initiative_contributions=held.promise;refresh();await waitFor(()=>expect(queryCalls.filter(x=>x.table==='initiative_contributions')).toHaveLength(2));fireEvent.click(screen.getByRole('button',{name:'Sign out of member area'}));await screen.findByLabelText('WhatsApp number');await act(async()=>held.resolve({data:[contribution],error:null}));expect(screen.queryByText('123456')).not.toBeInTheDocument();expect(screen.queryByText('QA-confirmed')).not.toBeInTheDocument();});
 it('clears private data when another tab signs out',async()=>{await mount();act(()=>authChanged('SIGNED_OUT',null));expect(screen.queryByText('123456')).not.toBeInTheDocument();expect(screen.getByLabelText('WhatsApp number')).toBeVisible();});
 it('clears old data while a different account loads and rejects the old response',async()=>{await mount();const held=deferred();rows.initiative_contributions=held.promise;refresh();await waitFor(()=>expect(queryCalls.filter(x=>x.table==='initiative_contributions')).toHaveLength(2));mocks.getUser.mockResolvedValue({data:{user:{id:'other'}},error:null});rows.fan_memberships={data:null,error:null};act(()=>authChanged('SIGNED_IN',{user:{id:'other'}}));expect(screen.queryByText('123456')).not.toBeInTheDocument();await screen.findByRole('button',{name:'Activate my membership'});await act(async()=>held.resolve({data:[contribution],error:null}));expect(screen.queryByText('QA-confirmed')).not.toBeInTheDocument();expect(mocks.rpc.mock.calls.some(([name])=>name==='activate_free_fan_membership')).toBe(false);});
 it('shows only the newest refresh result when older work completes later',async()=>{await mount();const held=deferred();rows.initiative_contributions=held.promise;refresh();await waitFor(()=>expect(queryCalls.filter(x=>x.table==='initiative_contributions')).toHaveLength(2));rows.initiative_contributions={data:[{...contribution,momo_reference:'QA-newest'}],error:null};refresh();await screen.findByText('QA-newest');await act(async()=>held.resolve({data:[contribution],error:null}));expect(screen.queryByText('QA-confirmed')).not.toBeInTheDocument();});
 it('unsubscribes from auth events when leaving the portal',async()=>{await mount();cleanup();expect(mocks.unsubscribe).toHaveBeenCalledTimes(1);});
 it('requires explicit activation after successful OTP verification',async()=>{
   mocks.getUser.mockResolvedValue({data:{user:null},error:null});
   render(<MemberPortal clubShortName="Rayon"/>);
   const phone=await screen.findByLabelText('WhatsApp number');
   fireEvent.change(phone,{target:{value:'+250788123456'}});
   fireEvent.click(screen.getByRole('button',{name:'Send code on WhatsApp'}));
   await screen.findByLabelText('WhatsApp verification code');
   mocks.getUser.mockResolvedValue({data:{user:{id:'supporter'}},error:null});
   rows.fan_memberships={data:null,error:null};
   fireEvent.change(screen.getByLabelText('WhatsApp verification code'),{target:{value:'123456'}});
   fireEvent.click(screen.getByRole('button',{name:'Verify code'}));
   await screen.findByRole('button',{name:'Activate my membership'});
   expect(mocks.rpc.mock.calls.some(([name])=>name==='activate_free_fan_membership')).toBe(false);
 });
 it('discards a contribution response from a signed-out account',async()=>{
   await mount();const held=deferred();mocks.rpc.mockReturnValueOnce(held.promise);
   fireEvent.click(screen.getByRole('button',{name:'Open official MoMo dialer'}));
   await waitFor(()=>expect(mocks.rpc).toHaveBeenCalledWith('create_member_contribution_intent',expect.any(Object)));
   fireEvent.click(screen.getByRole('button',{name:'Sign out of member area'}));
   await screen.findByLabelText('WhatsApp number');
   await act(async()=>held.resolve({data:[{contribution_id:'intent',amount:5000,status:'pending',momo_reference:'PRIVATE-INTENT',ussd_code:'*182*8*1*123456*5000#'}],error:null}));
   expect(screen.queryByText(/PRIVATE-INTENT/)).not.toBeInTheDocument();
   expect(screen.queryByText('Waiting for external confirmation')).not.toBeInTheDocument();
 });

 it('uses the complete exact server total rather than summing the visible page',async()=>{
   confirmedTotal='9007199254740993';await mount();
   expect(screen.getByText(/9,007,199,254,740,993/)).toBeVisible();
 });
 it('appends older history and hides the control on the last page',async()=>{
   nextCursor={created_at:contribution.created_at,id:contribution.id};await mount();
   historyOverride={data:{confirmed_total:'21000',entries:[{...contribution,id:'99590000-0000-4000-8000-000000000400',momo_reference:'QA-older'}],next_cursor:null},error:null};
   fireEvent.click(screen.getByRole('button',{name:'Load older contributions'}));
   await screen.findByText('QA-older');expect(screen.getByText('QA-confirmed')).toBeVisible();
   expect(screen.getByText(/21,000/)).toBeVisible();
   expect(screen.queryByRole('button',{name:'Load older contributions'})).not.toBeInTheDocument();
   expect(mocks.rpc).toHaveBeenCalledWith('member_contribution_history',{p_before_created_at:contribution.created_at,p_before_id:contribution.id});
 });
 it('retains history and retries the same cursor after an older-page error',async()=>{
   nextCursor={created_at:contribution.created_at,id:contribution.id};await mount();
   historyOverride={data:null,error:{message:'unavailable'}};
   fireEvent.click(screen.getByRole('button',{name:'Load older contributions'}));
   await screen.findByRole('alert');expect(screen.getByText('QA-confirmed')).toBeVisible();
   historyOverride={data:{confirmed_total:'1000',entries:[],next_cursor:null},error:null};
   fireEvent.click(screen.getByRole('button',{name:'Load older contributions'}));
   await waitFor(()=>expect(screen.queryByRole('button',{name:'Load older contributions'})).not.toBeInTheDocument());
   const calls=mocks.rpc.mock.calls.filter(([,args])=>args?.p_before_id);expect(calls[1]).toEqual(calls[0]);
 });
 it('does not append an older page after a newer refresh',async()=>{
   nextCursor={created_at:contribution.created_at,id:contribution.id};await mount();
   const held=deferred();historyOverride=held.promise;
   fireEvent.click(screen.getByRole('button',{name:'Load older contributions'}));
   historyOverride={data:{confirmed_total:'1000',entries:[{...contribution,momo_reference:'QA-refreshed'}],next_cursor:null},error:null};refresh();
   await screen.findByText('QA-refreshed');await act(async()=>held.resolve({data:{confirmed_total:'1000',entries:[{...contribution,id:'99590000-0000-4000-8000-000000000400',momo_reference:'QA-obsolete-page'}],next_cursor:null},error:null}));
   expect(screen.queryByText('QA-obsolete-page')).not.toBeInTheDocument();
 });
 it('blocks duplicate older-page clicks and discards the page after logout',async()=>{
   nextCursor={created_at:contribution.created_at,id:contribution.id};await mount();
   const held=deferred();historyOverride=held.promise;const button=screen.getByRole('button',{name:'Load older contributions'});
   fireEvent.click(button);fireEvent.click(button);
   expect(mocks.rpc.mock.calls.filter(([,args])=>args?.p_before_id)).toHaveLength(1);
   fireEvent.click(screen.getByRole('button',{name:'Sign out of member area'}));await screen.findByLabelText('WhatsApp number');
   await act(async()=>held.resolve({data:{confirmed_total:'1000',entries:[contribution],next_cursor:null},error:null}));
   expect(screen.queryByText('QA-confirmed')).not.toBeInTheDocument();
 });
 it('does not replace a verified total when the server sends malformed history',async()=>{
   await mount();historyOverride={data:{confirmed_total:'not money',entries:[],next_cursor:null},error:null};refresh();
   await screen.findByRole('alert');expect(screen.getByText('QA-confirmed')).toBeVisible();
 });
 it.each(['100.99','1e3'])('rejects a non-whole-decimal contribution amount %s without creating an intent',async amount=>{
   await mount();fireEvent.change(screen.getByLabelText('Amount in RWF'),{target:{value:amount}});
   fireEvent.click(screen.getByRole('button',{name:'Open official MoMo dialer'}));await screen.findByRole('alert');
   expect(mocks.rpc.mock.calls.some(([name])=>name==='create_member_contribution_intent')).toBe(false);
 });
 it('explains a malformed MoMo route without presenting an OTP error',async()=>{
   await mount();mocks.rpc.mockResolvedValueOnce({data:null,error:{message:'The official Rayon Sports MoMo route is invalid.'}});
   fireEvent.click(screen.getByRole('button',{name:'Open official MoMo dialer'}));
   expect(await screen.findByRole('alert')).toHaveTextContent('MoMo route');
 });

});
