import type { SupabaseClient } from '@supabase/supabase-js';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { launchPaidMembership } from './membership-payment';
import { setMemberSignOutPending } from './member-session';

const payment = { club_id: 24, tier: 'gold', amount: 1000, ussd_code: '*182*8*1*1000*12345#' };
function setup(data: unknown = payment) {
  const getUser = vi.fn().mockResolvedValue({ data: { user: { id: 'supporter' } }, error: null });
  const rpc = vi.fn().mockResolvedValue({ data, error: null });
  const launch = vi.fn();
  const client = { auth: { getUser }, rpc } as unknown as SupabaseClient;
  return { getUser, rpc, launch, client };
}
beforeEach(() => setMemberSignOutPending(false));
describe('paid membership launch', () => {
  it('opens the authoritative dialer directly with only a tier and expected club', async () => {
    const { client, rpc, launch } = setup();
    await expect(launchPaidMembership(client, 'gold', 24, launch)).resolves.toBe(true);
    expect(rpc).toHaveBeenCalledExactlyOnceWith('prepare_membership_payment_for_club', { p_tier: 'gold', p_expected_club_id: 24 });
    expect(launch).toHaveBeenCalledExactlyOnceWith('tel:*182*8*1*1000*12345%23');
  });
  it.each([null, { ...payment, amount: 0 }, { ...payment, amount: 1.5 }, { ...payment, club_id: 26 }, { ...payment, tier: 'silver' }, { ...payment, ussd_code: 'https://example.org' }])('never launches invalid or cross-club instructions: %j', async data => {
    const { client, launch } = setup(data);
    await expect(launchPaidMembership(client, 'gold', 24, launch)).rejects.toThrow('MEMBERSHIP_PAYMENT_INVALID');
    expect(launch).not.toHaveBeenCalled();
  });
  it('does not prepare payment for a signed-out supporter', async () => {
    const { client, getUser, rpc, launch } = setup();
    getUser.mockResolvedValue({ data: { user: null }, error: null });
    await expect(launchPaidMembership(client, 'gold', 24, launch)).rejects.toThrow('MEMBER_AUTH_REQUIRED');
    expect(rpc).not.toHaveBeenCalled(); expect(launch).not.toHaveBeenCalled();
  });
  it('ignores a prepared payment when the account changes', async () => {
    const { client, getUser, launch } = setup();
    getUser.mockResolvedValueOnce({ data: { user: { id: 'old' } }, error: null });
    await expect(launchPaidMembership(client, 'gold', 24, launch)).rejects.toThrow('MEMBER_AUTH_REQUIRED');
    expect(launch).not.toHaveBeenCalled();
  });
  it('ignores a payment when the visible club or mounted screen changes', async () => {
    const { client, launch } = setup(); let checks = 0;
    await expect(launchPaidMembership(client, 'gold', 24, launch, () => ++checks < 2)).resolves.toBe(false);
    expect(launch).not.toHaveBeenCalled();
  });
  it('does not launch when sign-out begins while preparing payment', async () => {
    const { client, rpc, launch } = setup();
    rpc.mockImplementation(async () => { setMemberSignOutPending(true); return {data: payment, error: null}; });
    await expect(launchPaidMembership(client, 'gold', 24, launch)).rejects.toThrow('MEMBER_AUTH_REQUIRED');
    expect(launch).not.toHaveBeenCalled();
  });
});
