import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { useState } from "react";
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
});
