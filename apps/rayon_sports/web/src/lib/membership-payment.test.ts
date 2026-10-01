import type { SupabaseClient } from '@supabase/supabase-js';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { confirmPaidMembership, MembershipPaymentChangedError, preparePaidMembership } from './membership-payment';
import { setMemberSignOutPending } from './member-session';

const payment = { id: '99590000-0000-4000-8000-000000000101', club_id: 24, tier: 'gold', amount: 1200, currency: 'RWF', recipient_code: '12345', country: 'RW', ussd_code: '*182*8*1*1200*12345#' };
function setup(data: unknown = payment) {
  const getUser = vi.fn().mockResolvedValue({ data: { user: { id: 'supporter' } }, error: null });
  const rpc = vi.fn().mockResolvedValue({ data, error: null });
  const launch = vi.fn();
  const client = { auth: { getUser }, rpc } as unknown as SupabaseClient;
  return { getUser, rpc, launch, client };
}
beforeEach(() => setMemberSignOutPending(false));
describe('paid membership review and confirmation', () => {
  it('prepares authoritative facts without opening a dialer, and revalidates them on explicit confirmation', async () => {
    const { client, rpc, launch } = setup();
    const review = await preparePaidMembership(client, 'gold', 24, 'RWF');
    expect(review).toMatchObject({amount: 1200, currency: 'RWF', recipientCode: '12345', id: payment.id});
    expect(launch).not.toHaveBeenCalled();
    await expect(confirmPaidMembership(client, review!, launch)).resolves.toBe(true);
    expect(rpc).toHaveBeenCalledWith('prepare_membership_payment_for_club', { p_tier: 'gold', p_expected_club_id: 24 });
    expect(rpc).toHaveBeenCalledTimes(2);
    expect(launch).toHaveBeenCalledExactlyOnceWith('tel:*182*8*1*1200*12345%23');
  });
  it.each([null, { ...payment, id: 'bad' }, { ...payment, amount: 0 }, { ...payment, amount: 1.5 }, { ...payment, club_id: 26 }, { ...payment, tier: 'silver' }, { ...payment, currency: 'ZMW' }, { ...payment, recipient_code: '' }, { ...payment, country: '' }, { ...payment, ussd_code: 'https://example.org' }])('never accepts invalid or cross-club instructions: %j', async data => {
    const { client, launch } = setup(data);
    await expect(preparePaidMembership(client, 'gold', 24, 'RWF')).rejects.toThrow('MEMBERSHIP_PAYMENT_INVALID');
    expect(launch).not.toHaveBeenCalled();
  });
  it.each(['id','amount','recipient_code','country','ussd_code'] as const)('requires a fresh review when the authoritative %s changes', async field => {
    const {client, rpc, launch} = setup();
    const review = await preparePaidMembership(client, 'gold', 24, 'RWF');
    const changed = {...payment, [field]: {id: '99590000-0000-4000-8000-000000000102', amount: 1500, recipient_code: '67890', country: 'BI', ussd_code: '*182*8*1*1500*67890#'}[field]};
    rpc.mockResolvedValue({data: changed, error: null});
    await expect(confirmPaidMembership(client, review!, launch)).rejects.toBeInstanceOf(MembershipPaymentChangedError);
    expect(launch).not.toHaveBeenCalled();
  });
  it('launches only the updated server instruction after the supporter confirms its matching review', async () => {
    const {client, rpc, launch} = setup();
    const review = await preparePaidMembership(client, 'gold', 24, 'RWF');
    const changed = {...payment, id: '99590000-0000-4000-8000-000000000102', amount: 1500, recipient_code: '67890', ussd_code: '*182*8*1*1500*67890#'};
    rpc.mockResolvedValue({data: changed, error: null});
    const error = await confirmPaidMembership(client, review!, launch).catch(error => error);
    expect(error).toBeInstanceOf(MembershipPaymentChangedError);
    expect(launch).not.toHaveBeenCalled();
    await expect(confirmPaidMembership(client, (error as MembershipPaymentChangedError).review, launch)).resolves.toBe(true);
    expect(launch).toHaveBeenCalledExactlyOnceWith('tel:*182*8*1*1500*67890%23');
  });
  it('does not prepare payment for a signed-out supporter', async () => {
    const { client, getUser, rpc } = setup();
    getUser.mockResolvedValue({ data: { user: null }, error: null });
    await expect(preparePaidMembership(client, 'gold', 24, 'RWF')).rejects.toThrow('MEMBER_AUTH_REQUIRED');
    expect(rpc).not.toHaveBeenCalled();
  });
  it('rejects account switching during preparation and after review', async () => {
    const { client, getUser, launch } = setup();
    getUser.mockResolvedValueOnce({ data: { user: { id: 'old' } }, error: null });
    await expect(preparePaidMembership(client, 'gold', 24, 'RWF')).rejects.toThrow('MEMBER_AUTH_REQUIRED');
    const review = await preparePaidMembership(client, 'gold', 24, 'RWF');
    getUser.mockResolvedValue({ data: { user: { id: 'other' } }, error: null });
    await expect(confirmPaidMembership(client, review!, launch)).rejects.toThrow('MEMBER_AUTH_REQUIRED');
    expect(launch).not.toHaveBeenCalled();
  });
  it('ignores preparation and confirmation when the mounted club changes', async () => {
    const { client, launch } = setup(); let checks = 0;
    await expect(preparePaidMembership(client, 'gold', 24, 'RWF', () => ++checks < 2)).resolves.toBeNull();
    const review = await preparePaidMembership(client, 'gold', 24, 'RWF');
    await expect(confirmPaidMembership(client, review!, launch, () => false)).resolves.toBe(false);
    expect(launch).not.toHaveBeenCalled();
  });
  it('does not accept or launch when sign-out begins during preparation', async () => {
    const { client, rpc, launch } = setup();
    rpc.mockImplementation(async () => { setMemberSignOutPending(true); return {data: payment, error: null}; });
    await expect(preparePaidMembership(client, 'gold', 24, 'RWF')).rejects.toThrow('MEMBER_AUTH_REQUIRED');
    expect(launch).not.toHaveBeenCalled();
  });
});
