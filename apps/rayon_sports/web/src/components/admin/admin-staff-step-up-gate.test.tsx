import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AdminStaffStepUpGate } from "./admin-staff-step-up-gate";

const mocks = vi.hoisted(() => ({
  getClaims: vi.fn(), getUser: vi.fn(), listFactors: vi.fn(), enroll: vi.fn(),
  challengeAndVerify: vi.fn(), unenroll: vi.fn(), refresh: vi.fn(), signOut: vi.fn(),
  owner: "staff-a", token: "token-a",
}));
const mockClient = { auth: { getClaims: mocks.getClaims, getUser: mocks.getUser, mfa: {
  listFactors: mocks.listFactors, enroll: mocks.enroll, challengeAndVerify: mocks.challengeAndVerify, unenroll: mocks.unenroll,
} } };
vi.mock("./admin-portal-provider", () => ({ useAdminPortal: () => ({
  client: mockClient, user: { id: mocks.owner }, session: { access_token: mocks.token },
  controlledEvidence: false, refresh: mocks.refresh, signOut: mocks.signOut,
}) }));

const factor = { id: "factor-a", friendly_name: "AFRICLUB staff", status: "verified", factor_type: "totp" };
function claims(aal = "aal1", timestamp = Math.floor(Date.now() / 1000), owner = mocks.owner) {
  return { data: { claims: { sub: owner, role: "authenticated", is_anonymous: false, aal, exp: Math.floor(Date.now() / 1000) + 600, amr: [{ method: "totp", timestamp }] } }, error: null };
}
function factors(all = [factor]) {
  return { data: { all, totp: all.filter((entry) => entry.status === "verified") }, error: null };
}
function show() { return render(<AdminStaffStepUpGate key={mocks.owner}><input aria-label="Staff draft" defaultValue="Preserved draft" /></AdminStaffStepUpGate>); }
async function enterCode() {
  const input = await screen.findByLabelText("Authenticator code");
  fireEvent.change(input, { target: { value: "123456" } });
  fireEvent.click(screen.getByRole("button", { name: "Verify and continue" }));
}

describe("staff authenticator task gate", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    mocks.owner = "staff-a"; mocks.token = "token-a";
    mocks.getClaims.mockImplementation(async () => claims());
    mocks.getUser.mockImplementation(async () => ({ data: { user: { id: mocks.owner } }, error: null }));
    mocks.listFactors.mockResolvedValue(factors());
    mocks.refresh.mockResolvedValue(undefined);
    mocks.signOut.mockResolvedValue(undefined);
  });
  afterEach(() => { vi.useRealTimers(); });

  it("keeps staff content unmounted until actual fresh claims follow verification", async () => {
    show();
    expect(screen.queryByLabelText("Staff draft")).not.toBeInTheDocument();
    await screen.findByLabelText("Authenticator code");
    mocks.challengeAndVerify.mockResolvedValue({ data: {}, error: null });
    mocks.getClaims.mockImplementation(async () => claims("aal2"));
    await enterCode();
    expect(await screen.findByLabelText("Staff draft")).toBeVisible();
    expect(mocks.challengeAndVerify).toHaveBeenCalledExactlyOnceWith({ factorId: "factor-a", code: "123456" });
    expect(mocks.refresh).toHaveBeenCalledOnce();
  });

  it("does not treat a successful challenge response as assurance", async () => {
    mocks.challengeAndVerify.mockResolvedValue({ data: {}, error: null });
    show(); await enterCode();
    expect(await screen.findByRole("alert")).toHaveTextContent("code could not be verified");
    expect(screen.queryByLabelText("Staff draft")).not.toBeInTheDocument();
    expect(mocks.refresh).not.toHaveBeenCalled();
  });

  it("prevents rapid duplicate verification while the original challenge is pending", async () => {
    let finish!: (value: unknown) => void;
    mocks.challengeAndVerify.mockImplementation(() => new Promise((resolve) => { finish = resolve; }));
    show(); await enterCode();
    await waitFor(() => expect(mocks.challengeAndVerify).toHaveBeenCalledOnce());
    fireEvent.click(screen.getByRole("button", { name: "Verifying…" }));
    expect(mocks.challengeAndVerify).toHaveBeenCalledOnce();
    mocks.getClaims.mockImplementation(async () => claims("aal2"));
    await act(async () => finish({ data: {}, error: null }));
    expect(await screen.findByLabelText("Staff draft")).toBeVisible();
  });

  it("enrolls through the actual SDK and never persists a setup secret", async () => {
    mocks.listFactors.mockResolvedValue(factors([]));
    mocks.enroll.mockResolvedValue({ data: { id: "new-factor", type: "totp", totp: { secret: "SYNTHETICKEY123" } }, error: null });
    const storageWrite = vi.spyOn(Storage.prototype, "setItem");
    show();
    fireEvent.click(await screen.findByRole("button", { name: "Set up authenticator" }));
    const input = await screen.findByLabelText("Setup key");
    expect(input).toHaveAttribute("type", "password");
    fireEvent.click(screen.getByRole("button", { name: "Show setup key" }));
    expect(input).toHaveAttribute("type", "text");
    expect(mocks.enroll).toHaveBeenCalledExactlyOnceWith({ factorType: "totp", issuer: "AFRICLUB", friendlyName: "AFRICLUB staff" });
    expect(storageWrite).not.toHaveBeenCalled();
    storageWrite.mockRestore();
  });

  it("reconciles an existing unfinished setup instead of creating a duplicate", async () => {
    mocks.listFactors.mockResolvedValue(factors([{ ...factor, status: "unverified" }]));
    mocks.unenroll.mockResolvedValue({ data: {}, error: null });
    show();
    fireEvent.click(await screen.findByRole("button", { name: "Remove unfinished setup" }));
    await waitFor(() => expect(mocks.unenroll).toHaveBeenCalledExactlyOnceWith({ factorId: "factor-a" }));
    expect(mocks.enroll).not.toHaveBeenCalled();
  });

  it("does not resend timed-out setup while its original SDK write is in flight and reconciles its late factor", async () => {
    vi.useFakeTimers();
    let finish!: (value: unknown) => void;
    mocks.listFactors.mockResolvedValue(factors([]));
    mocks.enroll.mockImplementation(() => new Promise((resolve) => { finish = resolve; }));
    show(); await act(async () => { await vi.advanceTimersByTimeAsync(1); });
    await act(async () => { fireEvent.click(screen.getByRole("button", { name: "Set up authenticator" })); await vi.advanceTimersByTimeAsync(1); });
    expect(mocks.enroll).toHaveBeenCalledOnce();
    await act(async () => { await vi.advanceTimersByTimeAsync(12_001); });
    expect(screen.getByRole("alert")).toHaveTextContent("Setup could not be confirmed");
    await act(async () => { fireEvent.click(screen.getByRole("button", { name: "Check status" })); await vi.advanceTimersByTimeAsync(1); });
    expect(screen.getByRole("alert")).toHaveTextContent("still awaiting a response");
    expect(screen.queryByRole("button", { name: "Set up authenticator" })).not.toBeInTheDocument();
    expect(mocks.enroll).toHaveBeenCalledOnce();
    mocks.listFactors.mockResolvedValue(factors([{ ...factor, status: "unverified" }]));
    await act(async () => finish({ data: { id: factor.id, type: "totp", totp: { secret: "LATEPRIVATESETUP" } }, error: null }));
    await act(async () => { fireEvent.click(screen.getByRole("button", { name: "Check status" })); await vi.advanceTimersByTimeAsync(1); });
    expect(screen.getByRole("button", { name: "Remove unfinished setup" })).toBeVisible();
    expect(screen.queryByLabelText("Setup key")).not.toBeInTheDocument();
    expect(mocks.enroll).toHaveBeenCalledOnce();
  });

  it("refuses to remove a factor that became verified after the screen loaded", async () => {
    mocks.listFactors.mockResolvedValueOnce(factors([{ ...factor, status: "unverified" }])).mockResolvedValue(factors());
    show(); fireEvent.click(await screen.findByRole("button", { name: "Remove unfinished setup" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("Setup could not be confirmed");
    expect(mocks.unenroll).not.toHaveBeenCalled();
  });

  it("discards a late verification result after an account switch", async () => {
    let finish!: (value: unknown) => void;
    mocks.challengeAndVerify.mockImplementation(() => new Promise((resolve) => { finish = resolve; }));
    const view = show(); await enterCode();
    await waitFor(() => expect(mocks.challengeAndVerify).toHaveBeenCalledOnce());
    mocks.owner = "staff-b"; mocks.token = "token-b";
    view.rerender(<AdminStaffStepUpGate key={mocks.owner}><input aria-label="Staff draft" /></AdminStaffStepUpGate>);
    await screen.findByLabelText("Authenticator code");
    await act(async () => finish({ data: {}, error: null }));
    expect(screen.queryByLabelText("Staff draft")).not.toBeInTheDocument();
    expect(mocks.refresh).not.toHaveBeenCalled();
  });

  it("rejects a changed provider identity before sending a challenge", async () => {
    mocks.getUser.mockResolvedValue({ data: { user: { id: "other-account" } }, error: null });
    show(); await enterCode();
    expect(await screen.findByRole("alert")).toHaveTextContent("code could not be verified");
    expect(mocks.challengeAndVerify).not.toHaveBeenCalled();
  });

  it("hides expired staff content while retaining its draft for reauthentication", async () => {
    vi.useFakeTimers();
    const initial = Math.floor(Date.now() / 1000);
    mocks.getClaims.mockImplementation(async () => claims("aal2", initial - 295));
    show(); await act(async () => { await vi.advanceTimersByTimeAsync(1); });
    const draft = screen.getByLabelText("Staff draft");
    fireEvent.change(draft, { target: { value: "Edited draft" } });
    await act(async () => { await vi.advanceTimersByTimeAsync(5_100); });
    expect(draft).not.toBeVisible();
    expect(screen.getByLabelText("Authenticator code")).toBeVisible();
    mocks.challengeAndVerify.mockResolvedValue({ data: {}, error: null });
    mocks.getClaims.mockImplementation(async () => claims("aal2"));
    fireEvent.change(screen.getByLabelText("Authenticator code"), { target: { value: "123456" } });
    await act(async () => { fireEvent.click(screen.getByRole("button", { name: "Verify and continue" })); await vi.advanceTimersByTimeAsync(1); });
    expect(draft).toBeVisible();
    expect(draft).toHaveValue("Edited draft");
  });

  it("fails closed on provider verification error with a reachable status retry", async () => {
    mocks.getClaims.mockResolvedValue({ data: null, error: new Error("network") });
    show();
    expect(await screen.findByRole("alert")).toHaveTextContent("could not be checked");
    expect(screen.queryByLabelText("Staff draft")).not.toBeInTheDocument();
    expect(mocks.listFactors).not.toHaveBeenCalled();
    expect(screen.getByRole("button", { name: "Check status" })).toBeEnabled();
  });
});
