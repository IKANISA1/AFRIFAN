import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import type { AuthChangeEvent, Session } from "@supabase/supabase-js";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { AdminPortalProvider, useAdminPortal } from "./admin-portal-provider";
import { AdminShell } from "./admin-shell";
import { emptyAdminAccess } from "@/lib/data/admin/access";
import { getBrowserSupabase } from "@/lib/supabase/browser";

const mocks = vi.hoisted(() => ({ resolveAccess: vi.fn(), clubOptions: vi.fn() }));
vi.mock("next/navigation", () => ({ usePathname: () => "/admin/shop" }));
vi.mock("@/lib/supabase/browser", () => ({ getBrowserSupabase: vi.fn() }));
vi.mock("@/lib/data/admin/access", async (original) => ({
  ...await original<typeof import("@/lib/data/admin/access")>(), resolveAdminAccess: mocks.resolveAccess,
}));
vi.mock("@/lib/data/admin/settings", () => ({ getAdminClubScopeOptions: mocks.clubOptions }));

const user = { id: "staff-a", app_metadata: {}, user_metadata: {} } as Session["user"];
const access = { ...emptyAdminAccess, isAuthenticated: true, hasAccess: true, userId: user.id,
  clubId: "24", role: "club_admin" as const, assignmentCount: 1 };
function Draft() { const { access } = useAdminPortal(); return <><input aria-label="Shop description draft" defaultValue="Initial description" /><output aria-label="Workspace access">{access.hasAccess ? "granted" : "denied"}</output></>; }
function setup() {
  let onAuth!: (event: AuthChangeEvent, session: Session | null) => void;
  let session = { access_token: "initial-token", user } as Session;
  const client = { auth: {
    onAuthStateChange: vi.fn((callback) => { onAuth = callback; return { data: { subscription: { unsubscribe: vi.fn() } } }; }),
    getSession: vi.fn(async () => ({ data: { session }, error: null })),
    getUser: vi.fn(async () => ({ data: { user }, error: null as Error | null })),
    getClaims: vi.fn(async () => ({ data: { claims: { sub: user.id, role: "authenticated", is_anonymous: false,
      aal: "aal2", exp: Math.floor(Date.now() / 1000) + 600, amr: [{ method: "totp", timestamp: Math.floor(Date.now() / 1000) }] } }, error: null })),
  } };
  vi.mocked(getBrowserSupabase).mockReturnValue(client as unknown as ReturnType<typeof getBrowserSupabase>);
  mocks.resolveAccess.mockResolvedValue(access); mocks.clubOptions.mockResolvedValue([]);
  render(<AdminPortalProvider initialState={{ session, user, access, clubOptions: [], error: null }}><AdminShell><Draft /></AdminShell></AdminPortalProvider>);
  return { client, refreshToken: async () => { session = { ...session, access_token: "refreshed-token" }; await act(async () => onAuth("TOKEN_REFRESHED", session)); } };
}

describe("actual admin shell session recovery", () => {
  beforeEach(() => vi.resetAllMocks());

  it("locks a same-account workspace after a temporary provider failure and restores the same draft after current checks", async () => {
    const { client, refreshToken } = setup();
    const draft = await screen.findByLabelText("Shop description draft");
    fireEvent.change(draft, { target: { value: "Unsubmitted description" } });
    client.auth.getUser.mockRejectedValueOnce(new Error("Temporary identity service failure"));
    await refreshToken();
    await waitFor(() => expect(screen.getByRole("alert")).toHaveTextContent("Your draft is kept"));
    expect(draft).not.toBeVisible();
    expect(draft).toHaveValue("Unsubmitted description");
    expect(screen.getByLabelText("Workspace access")).toHaveTextContent("denied");
    fireEvent.click(screen.getByRole("button", { name: "Check status" }));
    await waitFor(() => expect(draft).toBeVisible());
    expect(screen.getByLabelText("Shop description draft")).toBe(draft);
    expect(draft).toHaveValue("Unsubmitted description");
    expect(screen.getByLabelText("Workspace access")).toHaveTextContent("granted");
  });

  it("discards the old workspace on an explicit provider authentication rejection", async () => {
    const { client, refreshToken } = setup();
    await screen.findByLabelText("Shop description draft");
    client.auth.getUser.mockResolvedValueOnce({ data: { user }, error: Object.assign(new Error("Session expired"), { status: 401 }) });
    await refreshToken();
    await waitFor(() => expect(screen.queryByLabelText("Shop description draft")).not.toBeInTheDocument());
    expect(screen.queryByText("Your draft is kept")).not.toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Secure sign in" })).toBeVisible();
  });
});
