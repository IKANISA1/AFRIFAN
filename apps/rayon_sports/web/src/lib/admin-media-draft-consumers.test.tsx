import { webcrypto } from "node:crypto";
import { useState } from "react";
import { act, cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { useAdminMediaDraftScope } from "./use-admin-media-draft-scope";
import { retainAdminUpload, withAdminUploadJournal } from "./data/admin/media-upload-journal";
import type { AdminAccess } from "./types";
import { MatchForm } from "../app/admin/matches/_components/match-form";
import { emptyMatchForm } from "../app/admin/matches/_components/match-form-state";
import { SquadEditorForm } from "../app/admin/squad/_components/squad-form";
import { emptySquadForm } from "../app/admin/squad/_components/squad-form-state";
import { CMSContentEditor } from "../app/admin/cms/_components/cms-content-editor";
import { emptyArticleForm } from "../app/admin/cms/_components/cms-state";
import { CommunityContentEditor } from "../app/admin/community/_components/community-content-editor";
import { emptyForm as emptyChapterForm } from "../app/admin/community/_components/community-state";
import MatchesPage from "../app/admin/matches/page";
import ShopPage from "../app/admin/shop/page";
import BannerPage from "../app/admin/cms/banners/page";
import type { AdminMediaKind } from "./data/admin/media";

const mocks = vi.hoisted(() => ({ saveMatch: vi.fn(), saveSquad: vi.fn(), saveShop: vi.fn(), saveBanner: vi.fn(), toast: vi.fn() }));
const access: AdminAccess = { userId: "99969000-0000-4000-8000-000000000001", clubId: "24", hasAccess: true,
  isAuthenticated: true, isSuperAdmin: false, role: "club_admin", availableClubIds: ["24"], canSelectClub: false, assignmentCount: 1 };
const client = {} as never;
vi.mock("../components/admin/admin-portal-provider", () => ({ useAdminPortal: () => ({ access, client, activeClub: null }) }));
vi.mock("../components/admin/admin-toast", () => ({ showAdminToast: mocks.toast }));
vi.mock("../components/admin/admin-image-field", () => ({ AdminImageField: (props: { scopeKey: string; recoveryOnly: boolean; disabled: boolean }) =>
  <output data-testid="image-scope" data-recovery-only={String(props.recoveryOnly)} data-disabled={String(props.disabled)}>{props.scopeKey}</output> }));
vi.mock("../lib/use-hydrated", () => ({ useHydrated: () => true }));
vi.mock("../lib/use-admin-resource-state", () => ({ useAdminResourceState: () => ({ data: [], status: "empty", hasConfirmed: true, busy: false,
  initialLoading: false, refresh: vi.fn(), applyFailure: () => "error" }) }));
vi.mock("../lib/data/admin/matches", async original => ({ ...await original<object>(), saveAdminMatch: mocks.saveMatch }));
vi.mock("../lib/data/admin/squad", async original => ({ ...await original<object>(), saveAdminSquadPlayer: mocks.saveSquad }));
vi.mock("../lib/data/admin/shop", async original => ({ ...await original<object>(), saveAdminProduct: mocks.saveShop }));
vi.mock("../lib/data/admin/cms-content", async original => ({ ...await original<object>(), saveAdminBanner: mocks.saveBanner }));
beforeEach(() => {
  vi.stubGlobal("crypto", webcrypto); localStorage.clear(); vi.clearAllMocks();
  const held = new Set<string>(); const queues = new Map<string, Promise<unknown>>();
  Object.defineProperty(navigator, "locks", { configurable: true, value: { request: (key: string,
    options: object | (() => unknown), callback?: (lock: object | null) => unknown) => {
    if (typeof options !== "function") {
      if (held.has(key)) return Promise.resolve(callback!(null));
      held.add(key); return Promise.resolve(callback!({ name: key })).finally(() => held.delete(key));
    }
    const result = (queues.get(key) ?? Promise.resolve()).then(() => (options as () => unknown)()); queues.set(key, result.catch(() => undefined)); return result;
  } } });
});
afterEach(() => { cleanup(); vi.restoreAllMocks(); vi.unstubAllGlobals(); });
function Editor({ kind }: { kind: "match" | "squad_player" | "news_article" | "fan_club" }) {
  const draft = useAdminMediaDraftScope(access, kind);
  const [match, setMatch] = useState(emptyMatchForm);
  const [squad, setSquad] = useState(emptySquadForm);
  const [article, setArticle] = useState(emptyArticleForm);
  const [chapter, setChapter] = useState(emptyChapterForm);
  const common = { draft, client, access, onSaved: async () => {}, onConflict: async () => {} };
  if (kind === "match") return <MatchForm {...common} form={match} setForm={setMatch} emptyForm={emptyMatchForm} />;
  if (kind === "squad_player") return <SquadEditorForm {...common} form={squad} setForm={setSquad} />;
  if (kind === "news_article") return <CMSContentEditor draft={draft} form={article} setForm={setArticle} onSubmit={() => {}}
    onClear={async () => { if (await draft.resetDraft(article.id || undefined)) setArticle(emptyArticleForm); }} />;
  return <CommunityContentEditor draft={draft} form={chapter} setForm={setChapter} onSubmit={() => {}}
    onClear={async () => { if (await draft.resetDraft(chapter.id || undefined)) setChapter(emptyChapterForm); }} />;
}
async function scope() { await waitFor(() => expect(screen.getByTestId("image-scope").textContent).toMatch(/^draft:/)); return screen.getByTestId("image-scope").textContent!; }
async function unknown(kind: AdminMediaKind, original: string) {
  return withAdminUploadJournal(access, kind, original, async (_, hash) => retainAdminUpload(access, kind, hash,
    { mimeType: "image/png", byteLength: 8, contentSha256: "a".repeat(64) }));
}
describe("actual admin image composer callers", () => {
  test("actual fixture drawer Close retains unknown upload; reload reopens the original composer for recovery", async () => {
    const first = render(<MatchesPage />);
    await waitFor(() => expect((screen.getByRole("button", { name: /^Create fixture$/ }) as HTMLButtonElement).disabled).toBe(false));
    fireEvent.click(screen.getByRole("button", { name: /^Create fixture$/ }));
    const original = await scope(); await unknown("match", original);
    fireEvent.click(screen.getByRole("button", { name: /^Close$/ }));
    await waitFor(() => expect(screen.getByRole("alert").textContent).toContain("Recover the original"));
    expect(screen.getByRole("dialog")).toBeTruthy(); expect(screen.getByTestId("image-scope").textContent).toBe(original);
    first.unmount(); await act(async () => { await Promise.resolve(); });
    render(<MatchesPage />);
    await waitFor(() => expect((screen.getByRole("button", { name: /^Create fixture$/ }) as HTMLButtonElement).disabled).toBe(false));
    fireEvent.click(screen.getByRole("button", { name: /^Create fixture$/ }));
    expect(await scope()).toBe(original);
  });
  test("actual confirmed fixture Save rotates the composer before its next blank creation", async () => {
    mocks.saveMatch.mockResolvedValue("saved-fixture");
    render(<Editor kind="match" />); const original = await scope();
    await act(async () => { fireEvent.submit(screen.getByTestId("image-scope").closest("form")!); });
    await waitFor(() => expect(mocks.saveMatch).toHaveBeenCalledTimes(1));
    await waitFor(() => expect(screen.getByTestId("image-scope").textContent).not.toBe(original));
    expect(mocks.saveMatch.mock.calls[0][2].id).toBeNull(); // Draft identity never becomes a persisted row ID.
  });
  test.each(["match", "squad_player", "news_article", "fan_club"] as const)("%s extracted editor Clear rotates an identical blank draft and unknown reference blocks it", async kind => {
    render(<Editor kind={kind} />); const first = await scope();
    fireEvent.click(screen.getByRole("button", { name: "Clear" }));
    await waitFor(() => expect(screen.getByTestId("image-scope").textContent).not.toBe(first));
    const original = await scope(); await unknown(kind, original);
    fireEvent.click(screen.getByRole("button", { name: "Clear" }));
    await waitFor(() => expect(screen.getByRole("alert").textContent).toContain("Recover the original"));
    expect(screen.getByTestId("image-scope").textContent).toBe(original);
  });
  test.each(["shop_product", "home_banner"] as const)("%s actual page reset rotates its own blank composer and preserves unknown upload", async kind => {
    render(kind === "shop_product" ? <ShopPage /> : <BannerPage />); const first = await scope();
    fireEvent.click(screen.getByRole("button", { name: "Clear" }));
    await waitFor(() => expect(screen.getByTestId("image-scope").textContent).not.toBe(first));
    const original = await scope(); await unknown(kind, original);
    fireEvent.click(screen.getByRole("button", { name: "Clear" }));
    await waitFor(() => expect(screen.getByRole("alert").textContent).toContain("Recover the original"));
    expect(screen.getByTestId("image-scope").textContent).toBe(original);
  });
  test.each(["match", "squad_player", "shop_product", "home_banner"] as const)("%s actual submit never mutates while its original upload is unknown", async kind => {
    render(kind === "shop_product" ? <ShopPage /> : kind === "home_banner" ? <BannerPage /> : <Editor kind={kind} />);
    const original = await scope(); await unknown(kind, original);
    const form = screen.getByTestId("image-scope").closest("form")!;
    await act(async () => { fireEvent.submit(form); });
    await waitFor(() => expect(screen.getByRole("alert").textContent).toContain("Recover the original"));
    expect(mocks.saveMatch).not.toHaveBeenCalled(); expect(mocks.saveSquad).not.toHaveBeenCalled();
    expect(mocks.saveShop).not.toHaveBeenCalled(); expect(mocks.saveBanner).not.toHaveBeenCalled();
    expect(screen.getByTestId("image-scope").textContent).toBe(original);
  });
});
