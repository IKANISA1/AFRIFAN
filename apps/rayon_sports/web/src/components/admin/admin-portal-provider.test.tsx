import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { useState } from "react";
import type { AuthChangeEvent, Session } from "@supabase/supabase-js";
import { afterEach, describe, expect, it, vi } from "vitest";

import {
  AdminPortalProvider,
  useAdminPortal,
} from "@/components/admin/admin-portal-provider";
import { emptyAdminAccess } from "@/lib/data/admin/access";
import { getBrowserSupabase } from "@/lib/supabase/browser";

vi.mock("@/lib/supabase/browser", () => ({
  getBrowserSupabase: vi.fn(),
}));
const ownershipMocks = vi.hoisted(() => ({ resolveAccess: vi.fn(), clubOptions: vi.fn() }));
vi.mock("@/lib/data/admin/access", async (original) => ({
  ...await original<typeof import("@/lib/data/admin/access")>(), resolveAdminAccess: ownershipMocks.resolveAccess,
}));
vi.mock("@/lib/data/admin/settings", () => ({ getAdminClubScopeOptions: ownershipMocks.clubOptions }));

function TimeoutHarness() {
  const { authBusy, notice, requestPhoneCode } = useAdminPortal();
  const [outcome, setOutcome] = useState("ready");

  return (
    <>
      <button
        type="button"
        onClick={() => {
          void requestPhoneCode("+250788123456")
            .then(() => setOutcome("sent"))
            .catch((error: unknown) => {
              setOutcome(error instanceof Error ? error.message : "failed");
            });
        }}
      >
        Request code
      </button>
      <output aria-label="busy">{authBusy ? "busy" : "idle"}</output>
      <output aria-label="outcome">{outcome}</output>
      <output aria-label="notice">{notice ?? ""}</output>
    </>
  );
}

function ClientAvailabilityHarness() {
  const { client } = useAdminPortal();
  return <output aria-label="client-state">{client == null ? "missing" : "ready"}</output>;
}

function OwnershipHarness() {
  const { refresh, signOut, user, access, error, notice } = useAdminPortal();
  return <>
    <button onClick={() => void refresh()}>Refresh identity</button>
    <button onClick={() => void signOut().catch(() => {})}>Sign out identity</button>
    <output aria-label="current-owner">{user?.id ?? "signed-out"}</output>
    <output aria-label="current-access">{access.hasAccess ? "granted" : "denied"}</output>
    <output aria-label="logout-error">{error ?? ""}</output>
    <output aria-label="logout-notice">{notice ?? ""}</output>
  </>;
}

function ownedSession(id: string) {
  return { access_token: `token-${id}`, user: { id, app_metadata: {}, user_metadata: {} } } as Session;
}
function ownedAccess(id: string) {
  return { ...emptyAdminAccess, isAuthenticated: true, hasAccess: true, userId: id, role: "club_admin" as const, clubId: "24", assignmentCount: 1 };
}

describe("AdminPortalProvider", () => {
  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
    vi.clearAllMocks();
  });

  it("releases the auth busy state after an eligibility timeout", async () => {
    vi.useFakeTimers();
    vi.stubGlobal("fetch", vi.fn(() => new Promise<Response>(() => {})));

    const unsubscribe = vi.fn();
    const client = {
      auth: {
        onAuthStateChange: vi.fn(() => ({
          data: { subscription: { unsubscribe } },
        })),
        signInWithOtp: vi.fn(),
      },
    };
    vi.mocked(getBrowserSupabase).mockReturnValue(
      client as unknown as ReturnType<typeof getBrowserSupabase>,
    );

    render(
      <AdminPortalProvider
        initialState={{
          session: null,
          user: null,
          access: emptyAdminAccess,
          clubOptions: [],
          error: null,
        }}
      >
        <TimeoutHarness />
      </AdminPortalProvider>,
    );

    fireEvent.click(screen.getByRole("button", { name: "Request code" }));
    expect(screen.getByLabelText("busy")).toHaveTextContent("busy");

    await act(async () => {
      await vi.advanceTimersByTimeAsync(12_000);
    });

    expect(screen.getByLabelText("busy")).toHaveTextContent("idle");
    expect(screen.getByLabelText("outcome")).toHaveTextContent(
      "Admin eligibility check timed out",
    );
    expect(screen.getByLabelText("outcome")).toHaveTextContent(
      "No change was confirmed",
    );
    expect(client.auth.signInWithOtp).not.toHaveBeenCalled();
  });

  it("does not duplicate the server-side OTP request in the browser", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        new Response(
          JSON.stringify({
            code: "ADMIN_OTP_REQUEST_ACCEPTED",
            accepted: true,
          }),
          {
            status: 202,
            headers: { "content-type": "application/json" },
          },
        ),
      ),
    );

    const client = {
      auth: {
        onAuthStateChange: vi.fn(() => ({
          data: { subscription: { unsubscribe: vi.fn() } },
        })),
        signInWithOtp: vi.fn(),
      },
    };
    vi.mocked(getBrowserSupabase).mockReturnValue(
      client as unknown as ReturnType<typeof getBrowserSupabase>,
    );

    render(
      <AdminPortalProvider
        initialState={{
          session: null,
          user: null,
          access: emptyAdminAccess,
          clubOptions: [],
          error: null,
        }}
      >
        <TimeoutHarness />
      </AdminPortalProvider>,
    );

    fireEvent.click(screen.getByRole("button", { name: "Request code" }));

    await waitFor(() => {
      expect(screen.getByLabelText("outcome")).toHaveTextContent("sent");
    });
    expect(screen.getByLabelText("notice")).toHaveTextContent(
      "If +250 788 123 456 is approved",
    );
    expect(client.auth.signInWithOtp).not.toHaveBeenCalled();
  });

  it("does not hydrate or subscribe a server-authorized controlled evidence shell", () => {
    const client = {
      auth: {
        onAuthStateChange: vi.fn(),
        getSession: vi.fn(),
      },
    };
    vi.mocked(getBrowserSupabase).mockReturnValue(
      client as unknown as ReturnType<typeof getBrowserSupabase>,
    );

    render(
      <AdminPortalProvider
        initialState={{
          session: null,
          user: {
            id: "controlled-admin-evidence",
            app_metadata: {},
            user_metadata: {},
            aud: "authenticated",
            created_at: "2026-07-29T00:00:00.000Z",
          },
          access: {
            hasAccess: true,
            isAuthenticated: true,
            isSuperAdmin: true,
            userId: "controlled-admin-evidence",
            role: "super_admin",
            clubId: "24",
            availableClubIds: ["24"],
            canSelectClub: false,
            assignmentCount: 1,
          },
          clubOptions: [],
          error: null,
          controlledEvidence: true,
        }}
      >
        <span>Controlled evidence content</span>
      </AdminPortalProvider>,
    );

    expect(screen.getByText("Controlled evidence content")).toBeVisible();
    expect(client.auth.onAuthStateChange).not.toHaveBeenCalled();
    expect(client.auth.getSession).not.toHaveBeenCalled();
  });

  it("exposes a same-origin API sentinel for controlled evidence without browser credentials", () => {
    vi.mocked(getBrowserSupabase).mockReturnValue(null);

    render(
      <AdminPortalProvider
        initialState={{
          session: null,
          user: {
            id: "controlled-admin-evidence",
            app_metadata: {},
            user_metadata: {},
            aud: "authenticated",
            created_at: "2026-07-29T00:00:00.000Z",
          },
          access: {
            hasAccess: true,
            isAuthenticated: true,
            isSuperAdmin: true,
            userId: "controlled-admin-evidence",
            role: "super_admin",
            clubId: "24",
            availableClubIds: ["24"],
            canSelectClub: false,
            assignmentCount: 1,
          },
          clubOptions: [],
          error: null,
          controlledEvidence: true,
        }}
      >
        <ClientAvailabilityHarness />
      </AdminPortalProvider>,
    );

    expect(screen.getByLabelText("client-state")).toHaveTextContent("ready");
  });

  it("does not restore an old cached session when refresh completes after sign-out", async () => {
    let finish!: (value: unknown) => void;
    const session = ownedSession("staff-a");
    const client = { auth: {
      onAuthStateChange: vi.fn(() => ({ data: { subscription: { unsubscribe: vi.fn() } } })),
      getSession: vi.fn(() => new Promise((resolve) => { finish = resolve; })),
      getUser: vi.fn(), signOut: vi.fn().mockResolvedValue({ error: null }),
    } };
    vi.mocked(getBrowserSupabase).mockReturnValue(client as unknown as ReturnType<typeof getBrowserSupabase>);
    render(<AdminPortalProvider initialState={{ session, user: session.user, access: ownedAccess("staff-a"), clubOptions: [], error: null }}><OwnershipHarness /></AdminPortalProvider>);
    fireEvent.click(screen.getByRole("button", { name: "Refresh identity" }));
    await waitFor(() => expect(client.auth.getSession).toHaveBeenCalledOnce());
    fireEvent.click(screen.getByRole("button", { name: "Sign out identity" }));
    await act(async () => finish({ data: { session }, error: null }));
    expect(screen.getByLabelText("current-owner")).toHaveTextContent("signed-out");
    expect(screen.getByLabelText("current-access")).toHaveTextContent("denied");
    expect(client.auth.getUser).not.toHaveBeenCalled();
    expect(ownershipMocks.resolveAccess).not.toHaveBeenCalled();
  });

  it("discards an old role query after a new account becomes current", async () => {
    let event!: (event: AuthChangeEvent, value: Session | null) => void;
    let finishRole!: (value: unknown) => void;
    let currentSession = ownedSession("staff-a");
    ownershipMocks.resolveAccess.mockImplementation(async (_client, user) => user.id === "staff-a" ? new Promise((resolve) => { finishRole = resolve; }) : ownedAccess("staff-b"));
    ownershipMocks.clubOptions.mockResolvedValue([]);
    const client = { auth: {
      onAuthStateChange: vi.fn((callback) => { event = callback; return { data: { subscription: { unsubscribe: vi.fn() } } }; }),
      getSession: vi.fn(async () => ({ data: { session: currentSession }, error: null })),
      getUser: vi.fn(async () => ({ data: { user: currentSession.user }, error: null })),
    } };
    vi.mocked(getBrowserSupabase).mockReturnValue(client as unknown as ReturnType<typeof getBrowserSupabase>);
    render(<AdminPortalProvider initialState={{ session: currentSession, user: currentSession.user, access: ownedAccess("staff-a"), clubOptions: [], error: null }}><OwnershipHarness /></AdminPortalProvider>);
    fireEvent.click(screen.getByRole("button", { name: "Refresh identity" }));
    await waitFor(() => expect(ownershipMocks.resolveAccess).toHaveBeenCalledOnce());
    currentSession = ownedSession("staff-b");
    await act(async () => event("SIGNED_IN", currentSession));
    await waitFor(() => expect(screen.getByLabelText("current-owner")).toHaveTextContent("staff-b"));
    await act(async () => finishRole(ownedAccess("staff-a")));
    expect(screen.getByLabelText("current-owner")).toHaveTextContent("staff-b");
    expect(screen.getByLabelText("current-access")).toHaveTextContent("granted");
  });

  it("rejects cached session identity that differs from provider getUser", async () => {
    const session = ownedSession("staff-a");
    const client = { auth: {
      onAuthStateChange: vi.fn(() => ({ data: { subscription: { unsubscribe: vi.fn() } } })),
      getSession: vi.fn(async () => ({ data: { session }, error: null })),
      getUser: vi.fn(async () => ({ data: { user: ownedSession("staff-b").user }, error: null })),
    } };
    vi.mocked(getBrowserSupabase).mockReturnValue(client as unknown as ReturnType<typeof getBrowserSupabase>);
    render(<AdminPortalProvider initialState={{ session, user: session.user, access: ownedAccess("staff-a"), clubOptions: [], error: null }}><OwnershipHarness /></AdminPortalProvider>);
    fireEvent.click(screen.getByRole("button", { name: "Refresh identity" }));
    await waitFor(() => expect(screen.getByLabelText("current-owner")).toHaveTextContent("signed-out"));
    expect(screen.getByLabelText("current-access")).toHaveTextContent("denied");
    expect(ownershipMocks.resolveAccess).not.toHaveBeenCalled();
  });

  it("keeps SDK-style logout errors unresolved instead of announcing successful sign-out", async () => {
    const session = ownedSession("staff-a");
    const client = { auth: {
      onAuthStateChange: vi.fn(() => ({ data: { subscription: { unsubscribe: vi.fn() } } })),
      getSession: vi.fn(), getUser: vi.fn(),
      signOut: vi.fn().mockResolvedValue({ error: new Error("private provider logout failure") }),
    } };
    vi.mocked(getBrowserSupabase).mockReturnValue(client as unknown as ReturnType<typeof getBrowserSupabase>);
    render(<AdminPortalProvider initialState={{ session, user: session.user, access: ownedAccess("staff-a"), clubOptions: [], error: null }}><OwnershipHarness /></AdminPortalProvider>);
    fireEvent.click(screen.getByRole("button", { name: "Sign out identity" }));
    await waitFor(() => expect(screen.getByLabelText("logout-error")).toHaveTextContent("Sign-out could not be confirmed"));
    expect(screen.getByLabelText("logout-notice")).toBeEmptyDOMElement();
    expect(screen.getByLabelText("current-owner")).toHaveTextContent("signed-out");
    expect(screen.getByLabelText("current-access")).toHaveTextContent("denied");
    expect(client.auth.getSession).not.toHaveBeenCalled();
  });
});
