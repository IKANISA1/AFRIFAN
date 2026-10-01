import {act, cleanup, fireEvent, render, screen, waitFor} from '@testing-library/react';
import {afterEach, beforeEach, describe, expect, it, vi} from 'vitest';
import {MemberPortal, normalizeMemberPhone} from './member-portal';
import {memberRequestTimeoutMs, setMemberSignOutPending} from '../lib/member-session';
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
 setMemberSignOutPending(false);
 vi.resetAllMocks();queryCalls.length=0;confirmedTotal='1000';nextCursor=null;historyOverride=null;
 rows={fan_memberships:{data:membership,error:null},initiatives:{data:[{id:'campaign',title:'Club campaign'}],error:null},initiative_contributions:{data:[contribution],error:null}};
 mocks.signInWithOtp.mockResolvedValue({error:null});mocks.verifyOtp.mockResolvedValue({error:null});
 mocks.getUser.mockResolvedValue({data:{user:{id:'supporter'}},error:null});mocks.signOut.mockResolvedValue({error:null});mocks.rpc.mockImplementation((name:string)=>{
   if(name!=='member_contribution_history')return Promise.resolve({data:[],error:null});
   queryCalls.push({table:'initiative_contributions',filters:[]});
   return historyOverride??Promise.resolve(rows.initiative_contributions).then(r=>r.error?r:{data:{confirmed_total:confirmedTotal,entries:r.data,next_cursor:nextCursor},error:null});
 });
 mocks.onAuthStateChange.mockImplementation((callback)=>{authChanged=callback;return {data:{subscription:{unsubscribe:mocks.unsubscribe}}};});
 mocks.from.mockImplementation((table:string)=>{const entry={table,filters:[] as unknown[][]};queryCalls.push(entry);const q={select:()=>q,eq:(...args:unknown[])=>{entry.filters.push(args);return q;},neq:(...args:unknown[])=>{entry.filters.push(args);return q;},gt:(...args:unknown[])=>{entry.filters.push(args);return q;},order:()=>q,limit:()=>q,maybeSingle:()=>Promise.resolve(rows[table]),then:(resolve:(v:Result)=>unknown,reject:(e:unknown)=>unknown)=>Promise.resolve(rows[table]).then(resolve,reject)};return q;});
});
afterEach(()=>{cleanup();setMemberSignOutPending(false);vi.useRealTimers();});
describe('member portal authenticated data lifecycle',()=>{
 it('focuses the code step and associates correctable errors with their fields',async()=>{
   mocks.getUser.mockResolvedValue({data:{user:null},error:null});
   render(<MemberPortal clubShortName="Rayon"/>);
   const phone=await screen.findByLabelText('WhatsApp number');
   fireEvent.change(phone,{target:{value:'not a number'}});
   fireEvent.click(screen.getByRole('button',{name:'Send code on WhatsApp'}));
   expect(phone).toHaveFocus();expect(phone).toHaveAttribute('aria-invalid','true');
   expect(phone).toHaveAttribute('aria-describedby','member-phone-error');
   expect(mocks.signInWithOtp).not.toHaveBeenCalled();
   fireEvent.change(phone,{target:{value:'+250788123456'}});
   expect(phone).not.toHaveAttribute('aria-invalid');
   fireEvent.click(screen.getByRole('button',{name:'Send code on WhatsApp'}));
   const code=await screen.findByLabelText('WhatsApp verification code');
   expect(code).toHaveFocus();expect(code).toHaveAttribute('autocomplete','one-time-code');
   fireEvent.change(code,{target:{value:'123'}});fireEvent.click(screen.getByRole('button',{name:'Verify code'}));
   expect(code).toHaveAttribute('aria-invalid','true');
   expect(code).toHaveAttribute('aria-describedby','member-otp-help member-otp-error');
   expect(mocks.verifyOtp).not.toHaveBeenCalled();
 });
 it('recovers expired codes through a bounded resend to the same destination and preserves autofill',async()=>{
   mocks.getUser.mockResolvedValue({data:{user:null},error:null});render(<MemberPortal clubShortName="Rayon"/>);
   fireEvent.change(await screen.findByLabelText('WhatsApp number'),{target:{value:'+250788123456'}});
   vi.useFakeTimers(); await act(async()=>fireEvent.click(screen.getByRole('button',{name:'Send code on WhatsApp'})));
   const code=screen.getByLabelText('WhatsApp verification code');
   const resend=screen.getByRole('button',{name:'Resend WhatsApp code'});
   expect(resend).toBeDisabled();fireEvent.click(resend);expect(mocks.signInWithOtp).toHaveBeenCalledTimes(1);
   mocks.verifyOtp.mockResolvedValueOnce({error:{message:'Token has expired'}});
   fireEvent.change(code,{target:{value:'123456'}});await act(async()=>fireEvent.click(screen.getByRole('button',{name:'Verify code'})));
   expect(screen.getByRole('alert')).toHaveTextContent('invalid or expired');
   expect(code).toHaveAttribute('aria-invalid','true');
   await act(async()=>{await vi.advanceTimersByTimeAsync(60001);});
   expect(resend).toBeEnabled();
   await act(async()=>fireEvent.click(resend));
   expect(mocks.signInWithOtp).toHaveBeenCalledTimes(2);
   expect(mocks.signInWithOtp.mock.calls[1]).toEqual(mocks.signInWithOtp.mock.calls[0]);
   expect(code).toHaveValue('');expect(code).toHaveFocus();expect(code).not.toHaveAttribute('aria-invalid');
   expect(resend).toBeDisabled();expect(screen.getByRole('status')).toHaveTextContent('latest code');
 });
 it('moves activation to the existing tier heading without losing member authentication',async()=>{
   rows.fan_memberships={data:null,error:null};
   render(<><MemberPortal clubShortName="Rayon"/><h2 id="membership-tiers" tabIndex={-1}>Available tiers</h2></>);
   const choose=await screen.findByRole('link',{name:'Choose a membership tier'});
   fireEvent.click(choose);
   expect(screen.getByRole('heading',{name:'Available tiers'})).toHaveFocus();
   expect(window.location.hash).toBe('#membership-tiers');expect(mocks.signOut).not.toHaveBeenCalled();
 });
 it('preserves confirmed history and reports a failed refresh',async()=>{await mount();rows.initiative_contributions={data:null,error:{message:'backend unavailable'}};refresh();await screen.findByRole('alert');expect(screen.getByText('QA-confirmed')).toBeVisible();expect(screen.getAllByText(/1,000/).length).toBeGreaterThan(0);expect(screen.queryByText('No contribution intents recorded yet.')).not.toBeInTheDocument();});
 it('does not present a campaign failure as an empty catalogue',async()=>{rows.initiatives={data:null,error:{message:'permission denied'}};render(<MemberPortal clubShortName="Rayon"/>);await screen.findByRole('alert');expect(screen.queryByText('No active campaign confirmed')).not.toBeInTheDocument();expect(screen.getByRole('button',{name:'Retry member area'})).toBeVisible();});
 it('recovers an initial data failure without reactivating membership',async()=>{rows.initiative_contributions={data:null,error:{message:'unavailable'}};render(<MemberPortal clubShortName="Rayon"/>);await screen.findByRole('alert');rows.initiative_contributions={data:[contribution],error:null};fireEvent.click(screen.getByRole('button',{name:'Retry member area'}));await screen.findByText('QA-confirmed');expect(mocks.rpc.mock.calls.some(([name])=>name==='activate_free_fan_membership_for_club')).toBe(false);});
 it('scopes campaign and history queries to the verified membership club',async()=>{await mount();expect(queryCalls.find(x=>x.table==='initiatives')?.filters).toContainEqual(['club_id',24]);expect(mocks.rpc).toHaveBeenCalledWith('member_contribution_history');});
 it('ignores a late history response after explicit sign-out',async()=>{await mount();const held=deferred();rows.initiative_contributions=held.promise;refresh();await waitFor(()=>expect(queryCalls.filter(x=>x.table==='initiative_contributions')).toHaveLength(2));fireEvent.click(screen.getByRole('button',{name:'Sign out of member area'}));await screen.findByLabelText('WhatsApp number');await act(async()=>held.resolve({data:[contribution],error:null}));expect(screen.queryByText('123456')).not.toBeInTheDocument();expect(screen.queryByText('QA-confirmed')).not.toBeInTheDocument();});
 it('clears private data when another tab signs out',async()=>{await mount();act(()=>authChanged('SIGNED_OUT',null));expect(screen.queryByText('123456')).not.toBeInTheDocument();expect(screen.getByLabelText('WhatsApp number')).toBeVisible();});
 it('clears old data while a different account loads and rejects the old response',async()=>{await mount();const held=deferred();rows.initiative_contributions=held.promise;refresh();await waitFor(()=>expect(queryCalls.filter(x=>x.table==='initiative_contributions')).toHaveLength(2));mocks.getUser.mockResolvedValue({data:{user:{id:'other'}},error:null});rows.fan_memberships={data:null,error:null};act(()=>authChanged('SIGNED_IN',{user:{id:'other'}}));expect(screen.queryByText('123456')).not.toBeInTheDocument();await screen.findByRole('link',{name:'Choose a membership tier'});await act(async()=>held.resolve({data:[contribution],error:null}));expect(screen.queryByText('QA-confirmed')).not.toBeInTheDocument();expect(mocks.rpc.mock.calls.some(([name])=>name==='activate_free_fan_membership_for_club')).toBe(false);});
 it('shows only the newest refresh result when older work completes later',async()=>{await mount();const held=deferred();rows.initiative_contributions=held.promise;refresh();await waitFor(()=>expect(queryCalls.filter(x=>x.table==='initiative_contributions')).toHaveLength(2));rows.initiative_contributions={data:[{...contribution,momo_reference:'QA-newest'}],error:null};refresh();await screen.findByText('QA-newest');await act(async()=>held.resolve({data:[contribution],error:null}));expect(screen.queryByText('QA-confirmed')).not.toBeInTheDocument();});
 it('unsubscribes from auth events when leaving the portal',async()=>{await mount();cleanup();expect(mocks.unsubscribe).toHaveBeenCalledTimes(1);});
 it('requires a paid tier choice after successful OTP verification',async()=>{
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
   await screen.findByRole('link',{name:'Choose a membership tier'});
   expect(mocks.rpc.mock.calls.some(([name])=>name==='activate_free_fan_membership_for_club')).toBe(false);
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

 it('bounds a stalled refresh and keeps confirmed data; a late response stays ignored', async()=>{
   await mount(); const held=deferred();historyOverride=held.promise;
   vi.useFakeTimers();refresh();await act(async()=>{await vi.advanceTimersByTimeAsync(memberRequestTimeoutMs+1);});
   expect(screen.getByRole('alert')).toBeVisible();expect(screen.getByText('QA-confirmed')).toBeVisible();
   expect(screen.getByRole('button',{name:'Refresh contribution history'})).toBeEnabled();
   await act(async()=>held.resolve({data:{confirmed_total:'99999',entries:[],next_cursor:null},error:null}));
   expect(screen.getByText('QA-confirmed')).toBeVisible();expect(screen.queryByText(/99,999/)).not.toBeInTheDocument();
 });
 it('an offline identity refresh keeps confirmed information and supports unchanged-input retry',async()=>{
   await mount();mocks.getUser.mockResolvedValueOnce({data:{user:null},error:{name:'AuthRetryableFetchError',status:0,message:'offline'}});
   refresh();await screen.findByRole('alert');expect(screen.getByText('QA-confirmed')).toBeVisible();
   refresh();await waitFor(()=>expect(screen.queryByRole('alert')).not.toBeInTheDocument());
 });
 it('failed sign-out stays locked across remount and offers retry without loading private data',async()=>{
   await mount();mocks.signOut.mockResolvedValueOnce({error:{message:'unavailable'}});
   fireEvent.click(screen.getByRole('button',{name:'Sign out of member area'}));await screen.findByRole('button',{name:'Retry sign out'});
   await screen.findByRole('alert');expect(screen.queryByText('QA-confirmed')).not.toBeInTheDocument();
   cleanup();mocks.getUser.mockClear();render(<MemberPortal clubShortName="Rayon"/>);
   await screen.findByRole('button',{name:'Retry sign out'});expect(mocks.getUser).not.toHaveBeenCalled();
   act(()=>authChanged('TOKEN_REFRESHED',{user:{id:'supporter'}}));
   expect(screen.queryByText('QA-confirmed')).not.toBeInTheDocument();
   fireEvent.click(screen.getByRole('button',{name:'Retry sign out'}));await screen.findByLabelText('WhatsApp number');
 });
 it('a stalled sign-out unlocks the retry control without exposing private data',async()=>{
   await mount();mocks.signOut.mockReturnValueOnce(new Promise(()=>{}));vi.useFakeTimers();
   fireEvent.click(screen.getByRole('button',{name:'Sign out of member area'}));
   await act(async()=>{await vi.advanceTimersByTimeAsync(memberRequestTimeoutMs+1);});
   expect(screen.getByRole('button',{name:'Retry sign out'})).toBeEnabled();expect(screen.queryByText('QA-confirmed')).not.toBeInTheDocument();
 });
 it('another tab beginning sign-out immediately hides private member data',async()=>{
   await mount();act(()=>{setMemberSignOutPending(true);window.dispatchEvent(new StorageEvent('storage',{key:'africlub:member:sign-out-pending',newValue:'1'}));});
   expect(screen.queryByText('QA-confirmed')).not.toBeInTheDocument();expect(screen.getByRole('button',{name:'Retry sign out'})).toBeVisible();
 });

 it('bounds a stalled code request, ignores its late result and retries the unchanged number', async()=>{
   mocks.getUser.mockResolvedValue({data:{user:null},error:null});
   render(<MemberPortal clubShortName="Rayon"/>);
   fireEvent.change(await screen.findByLabelText('WhatsApp number'),{target:{value:'+250788123456'}});
   const held=deferred();mocks.signInWithOtp.mockReturnValueOnce(held.promise);vi.useFakeTimers();
   fireEvent.click(screen.getByRole('button',{name:'Send code on WhatsApp'}));
   await act(async()=>{await vi.advanceTimersByTimeAsync(memberRequestTimeoutMs+1);});
   expect(screen.getByRole('alert')).toHaveTextContent('could not be confirmed');
   expect(screen.getByRole('button',{name:'Send code on WhatsApp'})).toBeEnabled();
   await act(async()=>held.resolve({data:null,error:null}));
   expect(screen.queryByLabelText('WhatsApp verification code')).not.toBeInTheDocument();
   await act(async()=>fireEvent.click(screen.getByRole('button',{name:'Send code on WhatsApp'})));
   expect(screen.getByLabelText('WhatsApp verification code')).toBeVisible();
   expect(mocks.signInWithOtp.mock.calls[1]).toEqual(mocks.signInWithOtp.mock.calls[0]);
 });
 it('bounds stalled verification and lets the same code retry without activating membership',async()=>{
   mocks.getUser.mockResolvedValue({data:{user:null},error:null});render(<MemberPortal clubShortName="Rayon"/>);
   fireEvent.change(await screen.findByLabelText('WhatsApp number'),{target:{value:'+250788123456'}});
   fireEvent.click(screen.getByRole('button',{name:'Send code on WhatsApp'}));
   fireEvent.change(await screen.findByLabelText('WhatsApp verification code'),{target:{value:'123456'}});
   const held=deferred();mocks.verifyOtp.mockReturnValueOnce(held.promise);vi.useFakeTimers();
   fireEvent.click(screen.getByRole('button',{name:'Verify code'}));
   await act(async()=>{await vi.advanceTimersByTimeAsync(memberRequestTimeoutMs+1);});
   expect(screen.getByRole('button',{name:'Verify code'})).toBeEnabled();
   await act(async()=>held.resolve({data:null,error:null}));
   expect(screen.getByLabelText('WhatsApp verification code')).toHaveValue('123456');
   mocks.getUser.mockResolvedValue({data:{user:{id:'supporter'}},error:null});rows.fan_memberships={data:null,error:null};
   await act(async()=>fireEvent.click(screen.getByRole('button',{name:'Verify code'})));
   expect(screen.getByRole('link',{name:'Choose a membership tier'})).toBeVisible();
   expect(mocks.verifyOtp.mock.calls[1]).toEqual(mocks.verifyOtp.mock.calls[0]);
   expect(mocks.rpc.mock.calls.some(([name])=>name==='activate_free_fan_membership_for_club')).toBe(false);
 });
 it('bounds an uncertain contribution request without launching a late dialer or changing the retry',async()=>{
   await mount();const held=deferred();mocks.rpc.mockReturnValueOnce(held.promise);vi.useFakeTimers();
   fireEvent.click(screen.getByRole('button',{name:'Open official MoMo dialer'}));
   await act(async()=>{await vi.advanceTimersByTimeAsync(memberRequestTimeoutMs+1);});
   expect(screen.getByRole('alert')).toHaveTextContent('Check your history');
   expect(screen.getByRole('button',{name:'Open official MoMo dialer'})).toBeEnabled();
   expect(screen.getByText('QA-confirmed')).toBeVisible();
   await act(async()=>held.resolve({data:[{contribution_id:'intent',amount:5000,status:'pending',momo_reference:'LATE-INTENT',ussd_code:'*182*8*1*123456*5000#'}],error:null}));
   expect(screen.queryByText(/LATE-INTENT/)).not.toBeInTheDocument();
   mocks.rpc.mockResolvedValueOnce({data:null,error:{message:'unavailable'}});
   await act(async()=>fireEvent.click(screen.getByRole('button',{name:'Open official MoMo dialer'})));
   const calls=mocks.rpc.mock.calls.filter(([name])=>name==='create_member_contribution_intent');
   expect(calls).toHaveLength(2);expect(calls[1]).toEqual(calls[0]);
 });
 it('recovers from a thrown contribution transport failure without hiding confirmed history',async()=>{
   await mount();mocks.rpc.mockRejectedValueOnce(new TypeError('Network unavailable'));
   fireEvent.click(screen.getByRole('button',{name:'Open official MoMo dialer'}));
   expect(await screen.findByRole('alert')).toHaveTextContent('could not be confirmed');
   expect(screen.getByRole('button',{name:'Open official MoMo dialer'})).toBeEnabled();
   expect(screen.getByText('QA-confirmed')).toBeVisible();
 });

 it.each([[44,"Vital'O",'BI','BIF','+25779123456'],[26,'Nkana FC','ZM','ZMW','+260971234567'],[6,'AS Vita Club','CD','CDF','+243991234567']] as const)('uses club %i identity, currency and international phone access',async(clubId,clubShortName,countryCode,currencyCode,phone)=>{
   expect(normalizeMemberPhone(phone,countryCode)).toBe(phone);
   expect(normalizeMemberPhone('invalid',countryCode)).toBeNull();
   rows.fan_memberships={data:{...membership,club_id:clubId},error:null};
   render(<MemberPortal clubId={clubId} clubShortName={clubShortName} countryCode={countryCode} currencyCode={currencyCode}/>);
   await screen.findByText('123456');expect(screen.getByLabelText(`Amount in ${currencyCode}`)).toBeVisible();
   expect(screen.getByRole('heading',{name:`Your place at ${clubShortName}.`})).toBeVisible();
   expect(screen.queryByText(/Blue Wall|Gikundiro|RWF/)).not.toBeInTheDocument();
 });
 it('never displays another club membership or labels its money in the current club currency',async()=>{
   render(<MemberPortal clubId={26} clubShortName="Nkana FC" countryCode="ZM" currencyCode="ZMW"/>);
   expect(await screen.findByRole('alert')).toHaveTextContent('belongs to another club');
   expect(screen.queryByText('123456')).not.toBeInTheDocument();expect(screen.queryByText('QA-confirmed')).not.toBeInTheDocument();
   expect(mocks.rpc.mock.calls.some(([name])=>name==='member_contribution_history')).toBe(false);
 });
 it('opens paid tier selection without free activation',async()=>{
   rows.fan_memberships={data:null,error:null};render(<MemberPortal clubId={26} clubShortName="Nkana FC" countryCode="ZM" currencyCode="ZMW"/>);
   expect(await screen.findByRole('link',{name:'Choose a membership tier'})).toHaveAttribute('href','/membership#membership-tiers');
   expect(mocks.rpc.mock.calls.some(([name])=>name==='activate_free_fan_membership_for_club')).toBe(false);
 });

});
