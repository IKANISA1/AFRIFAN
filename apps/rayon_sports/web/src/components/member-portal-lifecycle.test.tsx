import {act, cleanup, fireEvent, render, screen, waitFor} from '@testing-library/react';
import {afterEach, beforeEach, describe, expect, it, vi} from 'vitest';
import {MemberPortal} from './member-portal';
const mocks=vi.hoisted(()=>({getUser:vi.fn(),signInWithOtp:vi.fn(),verifyOtp:vi.fn(),signOut:vi.fn(),rpc:vi.fn(),onAuthStateChange:vi.fn(),from:vi.fn(),unsubscribe:vi.fn()}));
vi.mock('@/lib/supabase/browser',()=>({getBrowserSupabase:()=>({auth:mocks,from:mocks.from,rpc:mocks.rpc})}));
type Result={data:unknown;error:null|{message:string}};
let rows:Record<string,Result|Promise<Result>>;
let authChanged:(event:string,session:{user:{id:string}}|null)=>void;
const membership={member_code:'123456',membership_number:'QA-1',club_id:24,tier:'fan',status:'active',joined_at:'2026-09-16'};
const contribution={id:'receipt',initiative_id:'campaign',amount:1000,status:'confirmed',momo_reference:'QA-confirmed',created_at:'2026-09-16',confirmed_at:'2026-09-16'};
const queryCalls:{table:string;filters:unknown[][]}[]=[];
const refresh=()=>fireEvent.click(screen.getByRole('button',{name:'Refresh contribution history'}));
const mount=async()=>{render(<MemberPortal clubShortName="Rayon Sports FC"/>);await screen.findByText('123456');};
function deferred(){let resolve!:(v:Result)=>void;const promise=new Promise<Result>(r=>{resolve=r;});return {promise,resolve};}
beforeEach(()=>{
 vi.clearAllMocks();queryCalls.length=0;
 rows={fan_memberships:{data:membership,error:null},initiatives:{data:[{id:'campaign',title:'Club campaign'}],error:null},initiative_contributions:{data:[contribution],error:null}};
 mocks.signInWithOtp.mockResolvedValue({error:null});mocks.verifyOtp.mockResolvedValue({error:null});
 mocks.getUser.mockResolvedValue({data:{user:{id:'supporter'}},error:null});mocks.signOut.mockResolvedValue({error:null});mocks.rpc.mockResolvedValue({data:[],error:null});
 mocks.onAuthStateChange.mockImplementation((callback)=>{authChanged=callback;return {data:{subscription:{unsubscribe:mocks.unsubscribe}}};});
 mocks.from.mockImplementation((table:string)=>{const entry={table,filters:[] as unknown[][]};queryCalls.push(entry);const q={select:()=>q,eq:(...args:unknown[])=>{entry.filters.push(args);return q;},order:()=>q,limit:()=>q,maybeSingle:()=>Promise.resolve(rows[table]),then:(resolve:(v:Result)=>unknown,reject:(e:unknown)=>unknown)=>Promise.resolve(rows[table]).then(resolve,reject)};return q;});
});
afterEach(()=>{cleanup();vi.useRealTimers();});
describe('member portal authenticated data lifecycle',()=>{
 it('preserves confirmed history and reports a failed refresh',async()=>{await mount();rows.initiative_contributions={data:null,error:{message:'backend unavailable'}};refresh();await screen.findByRole('alert');expect(screen.getByText('QA-confirmed')).toBeVisible();expect(screen.getAllByText(/1,000/).length).toBeGreaterThan(0);expect(screen.queryByText('No contribution intents recorded yet.')).not.toBeInTheDocument();});
 it('does not present a campaign failure as an empty catalogue',async()=>{rows.initiatives={data:null,error:{message:'permission denied'}};render(<MemberPortal clubShortName="Rayon"/>);await screen.findByRole('alert');expect(screen.queryByText('No active campaign confirmed')).not.toBeInTheDocument();expect(screen.getByRole('button',{name:'Retry member area'})).toBeVisible();});
 it('recovers an initial data failure without reactivating membership',async()=>{rows.initiative_contributions={data:null,error:{message:'unavailable'}};render(<MemberPortal clubShortName="Rayon"/>);await screen.findByRole('alert');rows.initiative_contributions={data:[contribution],error:null};fireEvent.click(screen.getByRole('button',{name:'Retry member area'}));await screen.findByText('QA-confirmed');expect(mocks.rpc).not.toHaveBeenCalled();});
 it('scopes campaign and history queries to the verified membership club',async()=>{await mount();for(const table of ['initiatives','initiative_contributions'])expect(queryCalls.find(x=>x.table===table)?.filters).toContainEqual(['club_id',24]);});
 it('ignores a late history response after explicit sign-out',async()=>{await mount();const held=deferred();rows.initiative_contributions=held.promise;refresh();await waitFor(()=>expect(queryCalls.filter(x=>x.table==='initiative_contributions')).toHaveLength(2));fireEvent.click(screen.getByRole('button',{name:'Sign out of member area'}));await screen.findByLabelText('WhatsApp number');await act(async()=>held.resolve({data:[contribution],error:null}));expect(screen.queryByText('123456')).not.toBeInTheDocument();expect(screen.queryByText('QA-confirmed')).not.toBeInTheDocument();});
 it('clears private data when another tab signs out',async()=>{await mount();act(()=>authChanged('SIGNED_OUT',null));expect(screen.queryByText('123456')).not.toBeInTheDocument();expect(screen.getByLabelText('WhatsApp number')).toBeVisible();});
 it('clears old data while a different account loads and rejects the old response',async()=>{await mount();const held=deferred();rows.initiative_contributions=held.promise;refresh();await waitFor(()=>expect(queryCalls.filter(x=>x.table==='initiative_contributions')).toHaveLength(2));mocks.getUser.mockResolvedValue({data:{user:{id:'other'}},error:null});rows.fan_memberships={data:null,error:null};act(()=>authChanged('SIGNED_IN',{user:{id:'other'}}));expect(screen.queryByText('123456')).not.toBeInTheDocument();await screen.findByRole('button',{name:'Activate my membership'});await act(async()=>held.resolve({data:[contribution],error:null}));expect(screen.queryByText('QA-confirmed')).not.toBeInTheDocument();expect(mocks.rpc).not.toHaveBeenCalled();});
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
   expect(mocks.rpc).not.toHaveBeenCalled();
 });
 it('discards a contribution response from a signed-out account',async()=>{
   await mount();const held=deferred();mocks.rpc.mockReturnValueOnce(held.promise);
   fireEvent.click(screen.getByRole('button',{name:'Open official MoMo dialer'}));
   await waitFor(()=>expect(mocks.rpc).toHaveBeenCalledOnce());
   fireEvent.click(screen.getByRole('button',{name:'Sign out of member area'}));
   await screen.findByLabelText('WhatsApp number');
   await act(async()=>held.resolve({data:[{contribution_id:'intent',amount:5000,status:'pending',momo_reference:'PRIVATE-INTENT',ussd_code:'*182*8*1*123456*5000#'}],error:null}));
   expect(screen.queryByText(/PRIVATE-INTENT/)).not.toBeInTheDocument();
   expect(screen.queryByText('Waiting for external confirmation')).not.toBeInTheDocument();
 });

});
