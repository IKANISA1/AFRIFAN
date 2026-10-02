import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { AdminImageField } from "./admin-image-field";

const mocks = vi.hoisted(() => ({
  upload: vi.fn(), status: vi.fn(), release: vi.fn(), pending: vi.fn(), generate: vi.fn(), generationPending: vi.fn(), generationStatus: vi.fn(), toast: vi.fn(),
  LegacyError: class extends Error {},
  access: { hasAccess: true, userId: "staff-a", clubId: "24", role: "club_admin" },
}));
const client = {};
vi.mock("./admin-portal-provider", () => ({ useAdminPortal: () => ({ client, access: mocks.access, activeClub: null }) }));
vi.mock("./admin-toast", () => ({ showAdminToast: mocks.toast }));
vi.mock("@/lib/data/admin/media", () => ({
  uploadAdminImage: mocks.upload, checkAdminImageUploadStatus: mocks.status,
  readPendingAdminUpload: mocks.pending, generateAdminImage: mocks.generate,
  readPendingAdminGeneration: mocks.generationPending, checkAdminImageGenerationStatus: mocks.generationStatus,
  releaseUnadmittedAdminImageUpload: mocks.release, AdminUploadLegacyReferenceError: mocks.LegacyError,
  defaultAspectRatioForAdminMediaKind: () => "1:1",
}));

const file = () => new File([new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10])], "club.png", { type: "image/png" });
function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>(done => { resolve = done; });
  return { promise, resolve };
}
const uploaded = { publicUrl: "https://storage.test/club.png", storagePath: "club-24/admin/shop_product/original.png" };
async function show(onChange = vi.fn(), scopeKey = "product-a") {
  const props = { label: "Product image", value: "", mediaKind: "shop_product" as const, scopeKey, onChange };
  const view = render(<AdminImageField {...props} />);
  await waitFor(() => expect(view.container.querySelector('input[type="file"]')).toBeEnabled());
  return { ...view, props, onChange };
}
function select(container: HTMLElement, image = file()) {
  fireEvent.change(container.querySelector('input[type="file"]')!, { target: { files: [image] } });
  return image;
}

describe("owned admin image operations", () => {
  beforeEach(() => {
    vi.resetAllMocks(); mocks.pending.mockResolvedValue(null); mocks.generationPending.mockResolvedValue(null);
    mocks.access = { hasAccess: true, userId: "staff-a", clubId: "24", role: "club_admin" };
  });
  it("confirms an earlier unbound draft without attaching its image or permitting another upload", async () => {
    mocks.pending.mockResolvedValue({ operationId: "earlier-draft" });
    mocks.status.mockImplementation(async () => { mocks.pending.mockResolvedValue(null); return { status: "completed", publicUrl: uploaded.publicUrl }; });
    const onChange = vi.fn(), resolved = vi.fn();
    const view = render(<AdminImageField label="Earlier image" value="" mediaKind="shop_product" scopeKey="new"
      recoveryOnly onChange={onChange} onRecoveryResolved={resolved} />);
    const check = await screen.findByRole("button", { name: "Check upload status" });
    await waitFor(() => expect(check).toBeEnabled());
    expect(view.container.querySelector('input[type="file"]')).toBeDisabled();
    expect(screen.getByRole("button", { name: "Generate image" })).toBeDisabled();
    fireEvent.click(check);
    await waitFor(() => expect(resolved).toHaveBeenCalledOnce());
    expect(onChange).not.toHaveBeenCalled(); expect(mocks.upload).not.toHaveBeenCalled();
    expect(screen.getByText("The earlier upload is confirmed. Its image was kept separate from this new draft.")).toBeInTheDocument();
  });
  it("retains unknown generation and offers status without another generation or image attachment", async () => {
    const saved = { operationId: "original-generation" };
    mocks.generate.mockImplementation(async () => { mocks.generationPending.mockResolvedValue(saved); throw new Error("Generation remains unconfirmed."); });
    mocks.generationStatus.mockResolvedValue({ operationId: saved.operationId, status: "unknown", image: null });
    const view = await show();
    fireEvent.change(screen.getByRole("textbox", { name: "Prompt" }), { target: { value: "Original prompt" } });
    fireEvent.click(screen.getByRole("button", { name: "Generate image" }));
    const check = await screen.findByRole("button", { name: "Check generation status" });
    await waitFor(() => expect(check).toBeEnabled());
    expect(screen.getByRole("button", { name: "Confirm original generation" })).toBeDisabled();
    expect(view.container.querySelector('input[type="file"]')).toBeDisabled();
    fireEvent.click(check);
    await waitFor(() => expect(mocks.generationStatus).toHaveBeenCalledOnce());
    expect(view.onChange).not.toHaveBeenCalled(); expect(mocks.generate).toHaveBeenCalledOnce();
  });
  it("recovers an earlier generation without attaching it to a new draft", async () => {
    mocks.generationPending.mockResolvedValue({ operationId: "earlier-generation" });
    mocks.generationStatus.mockImplementation(async () => {
      mocks.generationPending.mockResolvedValue(null);
      return { status: "completed", image: uploaded, request: { kind: "shop_product", prompt: "Earlier private prompt", subject: null, aspectRatio: "1:1" } };
    });
    const onChange = vi.fn(), resolved = vi.fn();
    render(<AdminImageField label="Earlier generation" value="" mediaKind="shop_product" scopeKey="new"
      recoveryOnly onChange={onChange} onRecoveryResolved={resolved} />);
    const check = await screen.findByRole("button", { name: "Check generation status" });
    await waitFor(() => expect(check).toBeEnabled()); fireEvent.click(check);
    await waitFor(() => expect(resolved).toHaveBeenCalledOnce());
    expect(onChange).not.toHaveBeenCalled(); expect(mocks.generate).not.toHaveBeenCalled();
  });

  it("blocks duplicate dispatch synchronously and attaches one confirmed upload", async () => {
    const response = deferred<typeof uploaded>(); mocks.upload.mockReturnValue(response.promise);
    const view = await show(); select(view.container); select(view.container);
    expect(mocks.upload).toHaveBeenCalledOnce();
    expect(mocks.upload.mock.calls[0][2].isCurrent()).toBe(true);
    await act(async () => { response.resolve(uploaded); });
    expect(view.onChange).toHaveBeenCalledExactlyOnceWith(uploaded.publicUrl);
  });

  it.each(["account", "club", "record"])("discards a late upload after the %s owner changes", async boundary => {
    const response = deferred<typeof uploaded>(); mocks.upload.mockReturnValue(response.promise);
    const view = await show(); select(view.container);
    const current = mocks.upload.mock.calls[0][2].isCurrent;
    if (boundary === "account") mocks.access = { ...mocks.access, userId: "staff-b" };
    if (boundary === "club") mocks.access = { ...mocks.access, clubId: "25" };
    view.rerender(<AdminImageField {...view.props} scopeKey={boundary === "record" ? "product-b" : "product-a"} />);
    expect(current()).toBe(false);
    await act(async () => { response.resolve(uploaded); });
    expect(view.onChange).not.toHaveBeenCalled();
    expect(mocks.toast).not.toHaveBeenCalledWith(expect.any(String), "success");
  });

  it("keeps the original file and saved operation after an unknown response", async () => {
    const retained = { version: 2, scopeHash: "a".repeat(64), operationId: "original-upload", userId: "staff-a", clubId: "24", kind: "shop_product" };
    mocks.upload.mockImplementationOnce(async () => { mocks.pending.mockResolvedValue(retained); throw new Error("Upload outcome is unknown. Check its saved reference."); });
    const view = await show(); const originalFile = select(view.container);
    const confirm = await screen.findByRole("button", { name: "Confirm same image" });
    expect(view.onChange).not.toHaveBeenCalled();
    mocks.upload.mockResolvedValueOnce(uploaded);
    fireEvent.click(confirm);
    await waitFor(() => expect(view.onChange).toHaveBeenCalledWith(uploaded.publicUrl));
    expect(mocks.upload.mock.calls[1][2].file).toBe(originalFile);
  });

  it("checks saved status without sending new bytes and attaches only a confirmed receipt", async () => {
    mocks.pending.mockResolvedValue({ operationId: "original-upload" });
    mocks.status.mockResolvedValue({ status: "completed", publicUrl: uploaded.publicUrl });
    const view = await show();
    fireEvent.click(await screen.findByRole("button", { name: "Check upload status" }));
    await waitFor(() => expect(view.onChange).toHaveBeenCalledWith(uploaded.publicUrl));
    expect(mocks.upload).not.toHaveBeenCalled();
  });

  it("does not attach results or confirm saved uploads while current staff access is unavailable", async () => {
    const response = deferred<typeof uploaded>(); mocks.upload.mockReturnValue(response.promise);
    const view = await show(); select(view.container);
    mocks.access = { ...mocks.access, hasAccess: false };
    view.rerender(<AdminImageField {...view.props} />);
    await act(async () => { response.resolve(uploaded); });
    expect(view.onChange).not.toHaveBeenCalled();
    expect(mocks.upload.mock.calls[0][2].isCurrent()).toBe(false);
  });

  it("restores saved recovery and the same file after current access returns", async () => {
    const response = deferred<typeof uploaded>(); mocks.upload.mockReturnValueOnce(response.promise);
    const view = await show(); const originalFile = select(view.container);
    mocks.access = { ...mocks.access, hasAccess: false };
    view.rerender(<AdminImageField {...view.props} />);
    mocks.pending.mockResolvedValue({ operationId: "original-upload" });
    await act(async () => { response.resolve(uploaded); });
    expect(view.onChange).not.toHaveBeenCalled();
    mocks.access = { ...mocks.access, hasAccess: true };
    view.rerender(<AdminImageField {...view.props} />);
    expect(await screen.findByRole("button", { name: "Check upload status" })).toBeEnabled();
    mocks.upload.mockResolvedValueOnce(uploaded);
    fireEvent.click(screen.getByRole("button", { name: "Confirm same image" }));
    await waitFor(() => expect(view.onChange).toHaveBeenCalledWith(uploaded.publicUrl));
    expect(mocks.upload.mock.calls[1][2].file).toBe(originalFile);
  });

  it("discards both upload and generation completion after unmount", async () => {
    const response = deferred<typeof uploaded>(); mocks.upload.mockReturnValue(response.promise);
    const uploadView = await show(); select(uploadView.container); uploadView.unmount();
    await act(async () => { response.resolve(uploaded); });
    expect(uploadView.onChange).not.toHaveBeenCalled();
    const generation = deferred<typeof uploaded>(); mocks.generate.mockReturnValue(generation.promise);
    const generatedView = await show();
    fireEvent.change(screen.getByLabelText("Prompt"), { target: { value: "Club jersey" } });
    fireEvent.click(screen.getByRole("button", { name: "Generate image" }));
    generatedView.unmount();
    await act(async () => { generation.resolve(uploaded); });
    expect(generatedView.onChange).not.toHaveBeenCalled();
  });

  it("recovers saved status only in the original record after switching records", async () => {
    const retained = { operationId: "original-upload" };
    mocks.pending.mockImplementation(async (_access, _kind, scopeKey) => scopeKey === "product-a" ? retained : null);
    mocks.status.mockResolvedValue({ status: "completed", publicUrl: uploaded.publicUrl });
    const view = await show();
    expect(screen.getByRole("button", { name: "Check upload status" })).toBeVisible();
    view.rerender(<AdminImageField {...view.props} scopeKey="product-b" />);
    await waitFor(() => expect(view.container.querySelector('input[type="file"]')).toBeEnabled());
    expect(screen.queryByRole("button", { name: "Check upload status" })).toBeNull();
    expect(view.onChange).not.toHaveBeenCalled();
    expect(mocks.status).not.toHaveBeenCalled();
    view.rerender(<AdminImageField {...view.props} />);
    fireEvent.click(await screen.findByRole("button", { name: "Check upload status" }));
    await waitFor(() => expect(view.onChange).toHaveBeenCalledExactlyOnceWith(uploaded.publicUrl));
    expect(mocks.status.mock.calls[0][3].scopeKey).toBe("product-a");
  });

  it("discards an old async journal read after the record changes", async () => {
    const oldRead = deferred<{ operationId: string }>();
    mocks.pending.mockImplementation((_access, _kind, scopeKey) => scopeKey === "product-a" ? oldRead.promise : Promise.resolve(null));
    const onChange = vi.fn();
    const props = { label: "Image", value: "", mediaKind: "shop_product" as const, scopeKey: "product-a", onChange };
    const view = render(<AdminImageField {...props} />);
    view.rerender(<AdminImageField {...props} scopeKey="product-b" />);
    await waitFor(() => expect(view.container.querySelector('input[type="file"]')).toBeEnabled());
    await act(async () => { oldRead.resolve({ operationId: "original-upload" }); });
    expect(screen.queryByRole("button", { name: "Check upload status" })).toBeNull();
    expect(onChange).not.toHaveBeenCalled();
  });

  it("releases an unused reference once without attaching an image", async () => {
    mocks.pending.mockResolvedValue({ operationId: "original-upload" });
    mocks.status.mockResolvedValue(null);
    const release = deferred<{ operationId: string; released: true }>();
    mocks.release.mockReturnValue(release.promise);
    const view = await show();
    fireEvent.click(screen.getByRole("button", { name: "Check upload status" }));
    const button = await screen.findByRole("button", { name: "Release unused upload" });
    fireEvent.click(button); fireEvent.click(button);
    expect(mocks.release).toHaveBeenCalledOnce();
    expect(mocks.release.mock.calls[0][3].scopeKey).toBe("product-a");
    mocks.pending.mockResolvedValue(null);
    await act(async () => { release.resolve({ operationId: "original-upload", released: true }); });
    expect(view.onChange).not.toHaveBeenCalled();
    expect(screen.queryByRole("button", { name: "Check upload status" })).toBeNull();
    expect(view.container.querySelector('input[type="file"]')).toBeEnabled();
  });

  it("offers only explicit unused-reference release for a validated legacy journal", async () => {
    mocks.pending.mockRejectedValue(new mocks.LegacyError("Legacy reference needs release"));
    mocks.release.mockRejectedValue(new Error("The original operation was already admitted."));
    const onChange = vi.fn();
    const view = render(<AdminImageField label="Image" value="" mediaKind="shop_product" scopeKey="product-b" onChange={onChange} />);
    const button = await screen.findByRole("button", { name: "Release unused upload" });
    expect(view.container.querySelector('input[type="file"]')).toBeDisabled();
    expect(screen.queryByRole("button", { name: "Check upload status" })).toBeNull();
    fireEvent.click(button);
    await screen.findByText("The original operation was already admitted.");
    expect(onChange).not.toHaveBeenCalled();
    expect(view.container.querySelector('input[type="file"]')).toBeDisabled();
    expect(mocks.status).not.toHaveBeenCalled();
  });

});
