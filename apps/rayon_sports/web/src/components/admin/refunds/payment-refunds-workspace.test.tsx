import { act, cleanup, fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import AdminRefundsPage from "@/app/admin/refunds/page";
import { normalizePaymentRefund, normalizePaymentRefundDashboard, type PaymentRefundCommand, type PaymentRefund } from "@/lib/data/admin/payment-refunds";
import { refundAccess, refundIds, refundPayment, refundReceipt } from "@/lib/data/admin/payment-refunds.test-fixtures";
import { readPendingRefundOperation } from "./refund-operation-journal";

const portal = vi.hoisted(() => ({ access: {} as typeof refundAccess, accessUnavailable: false }));
vi.mock("../admin-portal-provider", () => ({ useAdminPortal: () => portal }));
let requests: PaymentRefund[]; let commands: PaymentRefundCommand[];
let mutate: (command: PaymentRefundCommand) => Promise<PaymentRefund>;
let recover: (operationId: string) => Promise<PaymentRefund | null>;
let locks: { request: ReturnType<typeof vi.fn> };
const response = (data: unknown) => new Response(JSON.stringify({ data }), { headers: { "content-type": "application/json" } });
function dashboard() {
  const value = normalizePaymentRefundDashboard({ club_id: 24, payments: [{ ...refundPayment, capability_enabled: false, reserved_amount: requests.reduce((n, r) => n + (r.status === "rejected" ? 0 : r.amount), 0) }], requests: [] }, 24);
  return { ...value, requests };
}
function startRequest() {
  fireEvent.change(screen.getByLabelText("Original confirmed payment"), { target: { value: refundIds.payment } });
  fireEvent.change(screen.getByLabelText("Requested return amount (RWF)"), { target: { value: "2500" } });
  fireEvent.click(screen.getByRole("button", { name: "Retain request for separate review" }));
}
beforeEach(() => {
  portal.access = { ...refundAccess }; portal.accessUnavailable = false; requests = []; commands = []; localStorage.clear();
  locks = { request: vi.fn(async (_name: string, handler: () => unknown) => handler()) };
  Object.defineProperty(navigator, "locks", { configurable: true, value: locks });
  mutate = async command => {
    const value = normalizePaymentRefund(refundReceipt({ operation_id: command.operationId,
      status: command.action === "prepare" ? "awaiting_review" : command.action === "review" ? (command.approve ? "approved" : "rejected") : "pending",
      revision: command.action === "prepare" ? 1 : command.action === "review" ? 2 : 3 }), 24);
    requests = [value]; return value;
  };
  recover = async operationId => normalizePaymentRefund(refundReceipt({ operation_id: operationId }), 24);
  vi.stubGlobal("fetch", vi.fn(async (input: RequestInfo | URL, options?: RequestInit) => {
    const url = new URL(String(input));
    expect(url.searchParams.get("club")).toBe("24");
    if (options?.method === "POST") {
      const command = JSON.parse(String(options.body)) as PaymentRefundCommand;
      expect(readPendingRefundOperation(portal.access.userId!, "24")?.command.operationId).toBe(command.operationId);
      commands.push(command); return response(await mutate(command));
    }
    const operation = url.searchParams.get("operation_id");
    return response(operation ? await recover(operation) : dashboard());
  }));
});
afterEach(() => { cleanup(); vi.restoreAllMocks(); vi.unstubAllGlobals(); });

describe("actual reachable refund review and restart recovery", () => {
  it("retains a same-owner draft through temporary verification failure while denying commands", async () => {
    const view = render(<AdminRefundsPage />); await screen.findByText("No refund requests in this club.");
    const payment = screen.getByLabelText("Original confirmed payment");
    const amount = screen.getByLabelText("Requested return amount");
    const reason = screen.getByLabelText("Reason");
    fireEvent.change(payment, { target: { value: refundIds.payment } });
    fireEvent.change(amount, { target: { value: "1000" } });
    fireEvent.change(reason, { target: { value: "duplicate_payment" } });
    const submit = screen.getByRole("button", { name: "Retain request for separate review" });
    portal.accessUnavailable = true; portal.access = { ...refundAccess, hasAccess: false, isSuperAdmin: false };
    view.rerender(<AdminRefundsPage />);
    expect(payment).toBeInTheDocument(); expect(payment).not.toBeVisible(); expect(submit).toBeDisabled();
    expect(payment.closest("[inert]")).not.toBeNull();
    fireEvent.submit(submit.closest("form")!); expect(commands).toEqual([]);
    portal.accessUnavailable = false; portal.access = { ...refundAccess }; view.rerender(<AdminRefundsPage />);
    await waitFor(() => expect(submit).toBeEnabled());
    expect(screen.getByLabelText("Original confirmed payment")).toBe(payment);
    expect(screen.getByLabelText("Requested return amount (RWF)")).toHaveValue(1000);
    expect(reason).toHaveValue("duplicate_payment");
    portal.access = { ...refundAccess, hasAccess: false, isSuperAdmin: false }; view.rerender(<AdminRefundsPage />);
    expect(payment).not.toBeInTheDocument();
  });
  it("denies a queued original command and recovery while same-owner verification is unavailable", async () => {
    let start: () => unknown = () => {}; locks.request.mockImplementation((_scope: string, handler: () => unknown) => new Promise(resolve => { start = () => resolve(handler()); }));
    const view = render(<AdminRefundsPage />); await screen.findByText("No refund requests in this club."); startRequest();
    portal.accessUnavailable = true; portal.access = { ...refundAccess, hasAccess: false, isSuperAdmin: false }; view.rerender(<AdminRefundsPage />);
    await act(async () => { await start(); }); expect(commands).toEqual([]);
    const pending = readPendingRefundOperation(refundIds.maker, "24"); expect(pending?.command.action).toBe("prepare");
    const getCount = vi.mocked(fetch).mock.calls.length;
    const recovery = screen.getByText("Recover original operation", { selector: "button" });
    expect(recovery).toBeDisabled(); fireEvent.click(recovery); expect(vi.mocked(fetch).mock.calls).toHaveLength(getCount);
    portal.accessUnavailable = false; portal.access = { ...refundAccess }; view.rerender(<AdminRefundsPage />);
    await waitFor(() => expect(recovery).toBeEnabled());
    expect(readPendingRefundOperation(refundIds.maker, "24")?.command.operationId).toBe(pending?.command.operationId);
  });
  it("retains the reference before mutation and displays closed execution and original money", async () => {
    render(<AdminRefundsPage />); await screen.findByText("No refund requests in this club."); startRequest();
    await screen.findByRole("dialog", { name: "Review original refund" });
    expect(commands).toHaveLength(1); expect(commands[0]).toMatchObject({ action: "prepare", amount: 2500, paymentEventId: refundIds.payment });
    expect(screen.getByRole("button", { name: "Approve reviewed refund" })).toBeDisabled();
    expect(screen.getAllByText("ORIGINAL-PAYMENT-201").length).toBeGreaterThan(0);
    expect(screen.getByText(/A different current platform administrator must review/)).toBeVisible();
    expect(readPendingRefundOperation(refundIds.maker, "24")).toBeNull();
    expect(localStorage.length).toBe(2); // Original key and confirmed marker remain retained.
  });
  it("requires current distinct checker review of exact terms and issues a truthful pending instruction", async () => {
    portal.access = { ...refundAccess, userId: refundIds.checker };
    requests = [normalizePaymentRefund(refundReceipt(), 24)];
    render(<AdminRefundsPage />); fireEvent.click(await screen.findByRole("button", { name: /Awaiting a different reviewer/ }));
    const dialog = await screen.findByRole("dialog"); const approve = within(dialog).getByRole("button", { name: "Approve reviewed refund" });
    expect(approve).toBeDisabled(); expect(within(dialog).getByText("terms-reference")).toBeVisible();
    fireEvent.click(within(dialog).getByRole("checkbox")); fireEvent.click(approve);
    await screen.findAllByText("The reviewed refund is approved. It has not been issued.");
    expect(commands[0]).toMatchObject({ action: "review", refundId: refundIds.refund, revision: 1, approve: true });
    const issue = screen.getByRole("button", { name: "Issue original refund instruction" }); expect(issue).toBeDisabled();
    fireEvent.click(screen.getByRole("checkbox")); fireEvent.click(issue);
    await screen.findAllByText("Original instruction issued. Provider refund is pending confirmation.");
    expect(commands[1]).toMatchObject({ action: "dispatch", refundId: refundIds.refund });
    expect(screen.getAllByText("Provider confirmation pending").length).toBeGreaterThan(0);
    expect(screen.queryByRole("button", { name: "Issue original refund instruction" })).toBeNull();
  });
  it("does not approve when current provider capability is closed", async () => {
    portal.access = { ...refundAccess, userId: refundIds.checker };
    requests = [normalizePaymentRefund(refundReceipt({ current_approval: null }), 24)];
    render(<AdminRefundsPage />); fireEvent.click(await screen.findByRole("button", { name: /Awaiting a different reviewer/ }));
    fireEvent.click(screen.getByRole("checkbox")); expect(screen.getByRole("button", { name: "Approve reviewed refund" })).toBeDisabled();
    expect(screen.getByText(/Provider capability and terms are awaiting acceptance/)).toBeVisible(); expect(commands).toEqual([]);
  });
  it("recovers lost committed response after relaunch without another preparation or stale outcome", async () => {
    mutate = async command => {
      requests = [normalizePaymentRefund(refundReceipt({ operation_id: command.operationId, status: "refunded", confirmed_amount: 2500, payment_confirmed_amount: 2500 }), 24)];
      throw new Error("Response lost after commit");
    };
    const view = render(<AdminRefundsPage />); await screen.findByText("No refund requests in this club."); startRequest();
    await screen.findByRole("button", { name: "Recover original operation" }); const saved = commands[0].operationId;
    view.unmount(); render(<AdminRefundsPage />);
    await screen.findByText(saved); fireEvent.click(screen.getByRole("button", { name: "Recover original operation" }));
    await screen.findAllByText("Original operation recovered. The list shows the latest refund status.");
    expect(commands).toHaveLength(1); expect(screen.getAllByText("Requested refund confirmed").length).toBeGreaterThan(0);
    expect(readPendingRefundOperation(refundIds.maker, "24")).toBeNull();
  });
  it("keeps original key when recovery finds no commit and requires explicit original retry", async () => {
    let failed = true; const original = mutate;
    mutate = async command => { if (failed) throw new Error("Connection unavailable"); return original(command); };
    recover = async () => null;
    render(<AdminRefundsPage />); await screen.findByText("No refund requests in this club."); startRequest();
    fireEvent.click(await screen.findByRole("button", { name: "Recover original operation" }));
    await screen.findByRole("button", { name: "Retry original command" }); expect(commands).toHaveLength(1);
    expect(screen.getByRole("button", { name: "Retain request for separate review" })).toBeDisabled();
    failed = false; fireEvent.click(screen.getByRole("button", { name: "Retry original command" }));
    await screen.findByRole("dialog"); expect(commands).toHaveLength(2); expect(commands[1]).toEqual(commands[0]);
  });
  it("fails closed before any mutation if durable storage or operation locking fails", async () => {
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => { throw new Error("Storage unavailable"); });
    render(<AdminRefundsPage />); await screen.findByText("No refund requests in this club."); startRequest();
    await screen.findByRole("alert"); expect(commands).toEqual([]);
  });
  it("retains a pending key when the reply names a different operation", async () => {
    mutate = async () => normalizePaymentRefund(refundReceipt({ operation_id: refundIds.order }), 24);
    render(<AdminRefundsPage />); await screen.findByText("No refund requests in this club."); startRequest();
    await screen.findByRole("button", { name: "Recover original operation" }); expect(commands).toHaveLength(1);
    expect(readPendingRefundOperation(refundIds.maker, "24")?.command.operationId).toBe(commands[0].operationId);
    expect(screen.queryByRole("dialog")).toBeNull();
  });
  it("does not disclose another account's pending reference or accept an old account completion", async () => {
    let finish: (value: PaymentRefund) => void = () => {};
    mutate = () => new Promise(resolve => { finish = resolve; });
    const view = render(<AdminRefundsPage />); await screen.findByText("No refund requests in this club."); startRequest();
    await waitFor(() => expect(commands).toHaveLength(1)); const originalKey = commands[0].operationId;
    portal.access = { ...refundAccess, userId: refundIds.checker }; view.rerender(<AdminRefundsPage />);
    await screen.findByText("No refund requests in this club."); expect(screen.queryByText(originalKey)).toBeNull();
    await act(async () => finish(normalizePaymentRefund(refundReceipt({ operation_id: originalKey }), 24)));
    expect(screen.queryByRole("dialog")).toBeNull(); expect(screen.queryByText(/Refund request retained for/)).toBeNull();
    expect(readPendingRefundOperation(refundIds.checker, "24")).toBeNull();
  });
  it("blocks a command queued for the old mount before its first HTTP mutation", async () => {
    let start: () => unknown = () => {}; locks.request.mockImplementation((_scope: string, handler: () => unknown) => new Promise(resolve => { start = () => resolve(handler()); }));
    const view = render(<AdminRefundsPage />); await screen.findByText("No refund requests in this club."); startRequest();
    portal.access = { ...refundAccess, userId: refundIds.checker }; view.rerender(<AdminRefundsPage />);
    await act(async () => { await start(); }); expect(commands).toEqual([]);
    expect(readPendingRefundOperation(refundIds.maker, "24")?.command.action).toBe("prepare");
    expect(screen.queryByRole("dialog")).toBeNull();
  });
  it("shows partial/unknown confirmation without removing stock or claiming full cash return", async () => {
    requests = [normalizePaymentRefund(refundReceipt({ status: "partially_refunded", confirmed_amount: 1000, payment_confirmed_amount: 1000 }), 24)];
    render(<AdminRefundsPage />); fireEvent.click(await screen.findByRole("button", { name: /Partially confirmed/ }));
    expect(screen.getByText(/Partial returns retain stock and entitlements/)).toBeVisible();
    expect(screen.queryByText("Recorded full-refund consequences")).toBeNull();
    expect(screen.queryByRole("button", { name: "Issue original refund instruction" })).toBeNull(); expect(commands).toEqual([]);
  });
});
