import { useState } from "react";
import { act, render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import type { SupabaseClient } from "@supabase/supabase-js";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { AdminToastProvider } from "@/components/admin/admin-toast";
import type { AdminAccess } from "@/lib/types";
import { MembershipEditorForm } from "./membership-editor-form";
import { emptyForm, type MembershipForm } from "./membership-state";

const saveAdminMembershipPackage = vi.fn();

vi.mock("@/lib/data/admin/membership", async (importOriginal) => ({
  ...await importOriginal<typeof import("@/lib/data/admin/membership")>(),
  saveAdminMembershipPackage: (...args: unknown[]) =>
    saveAdminMembershipPackage(...args),
}));

describe("MembershipEditorForm accessibility recovery", () => {
  beforeEach(() => {
    saveAdminMembershipPackage.mockReset();
  });

  it("announces save failure, retains values, focuses recovery, and does not trap Tab", async () => {
    saveAdminMembershipPackage.mockRejectedValue(
      new Error("Membership service is temporarily unavailable."),
    );

    const user = userEvent.setup();

    render(
      <>
        <Harness />
        <AdminToastProvider />
      </>,
    );

    await user.selectOptions(screen.getByRole("combobox", { name: "Current club partner" }), partner.id);
    await user.type(screen.getByRole("textbox", { name: "Subtitle" }), "Family supporter membership");
    const title = screen.getByRole("textbox", { name: "Title" });
    await user.type(title, "Family tier");
    await user.type(
      screen.getByRole("textbox", { name: "Description" }),
      "Family membership benefits.",
    );
    await user.type(
      screen.getByRole("spinbutton", { name: "Annual price (RWF)" }),
      "1000",
    );
    await user.click(screen.getByRole("button", { name: "Create tier" }));

    await screen.findAllByRole("alert");
    const formElement = screen.getByRole("form", { name: "New tier" });
    const inlineAlert = within(formElement).getByRole("alert");
    expect(title).toHaveValue("Family tier");
    expect(formElement).toHaveAttribute(
      "aria-describedby",
      "membership-form-error",
    );
    expect(inlineAlert).toHaveFocus();
    expect(screen.getAllByRole("alert")).toHaveLength(2);

    await user.tab();
    await waitFor(() => expect(inlineAlert).not.toHaveFocus());
  });

  it("blocks duplicate save while busy and exposes the loading state", async () => {
    let resolveSave: (() => void) | undefined;
    saveAdminMembershipPackage.mockImplementation(
      () =>
        new Promise<void>((resolve) => {
          resolveSave = resolve;
        }),
    );
    const user = userEvent.setup();
    render(
      <>
        <Harness />
        <AdminToastProvider />
      </>,
    );

    await user.selectOptions(screen.getByRole("combobox", { name: "Current club partner" }), partner.id);
    await user.type(screen.getByRole("textbox", { name: "Subtitle" }), "Family supporter membership");
    await user.type(screen.getByRole("textbox", { name: "Title" }), "Family tier");
    await user.type(
      screen.getByRole("textbox", { name: "Description" }),
      "Family membership benefits.",
    );
    await user.type(
      screen.getByRole("spinbutton", { name: "Annual price (RWF)" }),
      "1000",
    );
    expect(screen.getByRole("textbox", { name: "Title" })).toBeRequired();
    expect(screen.getByRole("spinbutton", { name: "Annual price (RWF)" })).toHaveAttribute(
      "type",
      "number",
    );
    await user.click(screen.getByRole("button", { name: "Create tier" }));

    const busyButton = screen.getByRole("button", { name: "Creating tier..." });
    expect(busyButton).toBeDisabled();
    expect(busyButton).toHaveAttribute("aria-busy", "true");
    await user.click(busyButton);
    expect(saveAdminMembershipPackage).toHaveBeenCalledTimes(1);

    resolveSave?.();
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Create tier" })).toBeEnabled(),
    );
  });

  it("refuses a zero-price membership tier", async () => {
    const user = userEvent.setup();
    render(<Harness />);
    await user.selectOptions(screen.getByRole("combobox", { name: "Current club partner" }), partner.id);
    await user.type(screen.getByRole("textbox", { name: "Subtitle" }), "Gold supporter membership");
    await user.type(screen.getByRole("textbox", { name: "Title" }), "Gold");
    await user.type(screen.getByRole("textbox", { name: "Description" }), "Gold benefits");
    const price = screen.getByRole("spinbutton", { name: "Annual price (RWF)" });
    await user.type(price, "0");
    await user.click(screen.getByRole("button", { name: "Create tier" }));
    expect(price).toBeInvalid();
    expect(saveAdminMembershipPackage).not.toHaveBeenCalled();
  });

  it("clears an edit draft only through the explicit cancellation action", async () => {
    const user = userEvent.setup();
    render(<EditHarness />);

    expect(screen.getByRole("textbox", { name: "Title" })).toHaveValue(
      "Existing tier",
    );
    await user.click(screen.getByRole("button", { name: "Clear" }));
    expect(screen.getByRole("textbox", { name: "Title" })).toHaveValue("");
    expect(screen.getByRole("button", { name: "Create tier" })).toBeEnabled();
    expect(saveAdminMembershipPackage).not.toHaveBeenCalled();
  });

  it("keeps compact keyboard-open fields and form actions in one scroll contract", () => {
    render(<EditHarness />);

    const formElement = screen.getByRole("form", { name: "Edit tier" });
    const title = screen.getByRole("textbox", { name: "Title" });
    const actions = formElement.querySelector(
      '[data-keyboard-safe-actions="true"]',
    );

    expect(formElement).toHaveAttribute("data-keyboard-safe-form", "true");
    expect(formElement).toHaveClass(
      "max-sm:max-h-[calc(100dvh-8rem)]",
      "max-sm:overflow-y-auto",
      "max-sm:overscroll-contain",
      "max-sm:scroll-pb-24",
    );
    expect(title).toHaveClass("scroll-mb-24");
    expect(actions).toHaveClass(
      "max-sm:sticky",
      "max-sm:bottom-0",
      "max-sm:grid-cols-2",
    );
    expect(within(actions as HTMLElement).getByRole("button", { name: "Clear" }))
      .toBeEnabled();
    expect(
      within(actions as HTMLElement).getByRole("button", { name: "Save tier" }),
    ).toBeEnabled();
  });
  it("retains the original creation reference and required partner/subtitle after an unknown save", async () => {
    saveAdminMembershipPackage.mockRejectedValueOnce(new Error("Committed response was lost")).mockResolvedValueOnce(partner.id);
    const user = userEvent.setup(); render(<Harness />);
    await user.selectOptions(screen.getByRole("combobox", { name: "Current club partner" }), partner.id);
    await user.type(screen.getByRole("textbox", { name: "Title" }), "Family tier");
    await user.type(screen.getByRole("textbox", { name: "Subtitle" }), "Family supporter membership");
    await user.type(screen.getByRole("textbox", { name: "Description" }), "Annual supporter access");
    await user.type(screen.getByRole("spinbutton", { name: "Annual price (RWF)" }), "1000");
    await user.click(screen.getByRole("button", { name: "Create tier" })); await screen.findByRole("alert");
    const original = saveAdminMembershipPackage.mock.calls[0][2];
    expect(original).toMatchObject({ partnerId: partner.id, subtitle: "Family supporter membership", isActive: false });
    expect(original.creationId).toMatch(/^[0-9a-f-]{36}$/);
    await user.click(screen.getByRole("button", { name: "Create tier" }));
    await waitFor(() => expect(saveAdminMembershipPackage).toHaveBeenCalledTimes(2));
    expect(saveAdminMembershipPackage.mock.calls[1][2]).toEqual(original);
  });
  it("locks creation when no current club partner is configured and keeps moderators read-only", () => {
    const view = render(<Harness partners={[]} />);
    expect(screen.getByRole("button", { name: "Create tier" })).toBeDisabled();
    expect(screen.getByText(/No active partner is configured/)).toBeVisible();
    view.rerender(<Harness grantedAccess={{ ...access, role: "club_moderator" }} />);
    expect(screen.getByRole("button", { name: "Create tier" })).toBeDisabled();
    expect(screen.getByRole("textbox", { name: "Title" })).toBeDisabled();
    expect(saveAdminMembershipPackage).not.toHaveBeenCalled();
  });
  it("does not publish an old-owner save completion after its form has unmounted", async () => {
    let resolveSave: () => void = () => {};
    saveAdminMembershipPackage.mockImplementation(() => new Promise<void>(resolve => { resolveSave = resolve; }));
    const user = userEvent.setup(); const view = render(<><Harness /><AdminToastProvider /></>);
    await user.selectOptions(screen.getByRole("combobox", { name: "Current club partner" }), partner.id);
    await user.type(screen.getByRole("textbox", { name: "Title" }), "Old owner tier");
    await user.type(screen.getByRole("textbox", { name: "Subtitle" }), "Annual supporter tier");
    await user.type(screen.getByRole("textbox", { name: "Description" }), "Supporter benefits");
    await user.type(screen.getByRole("spinbutton", { name: "Annual price (RWF)" }), "1000");
    await user.click(screen.getByRole("button", { name: "Create tier" }));
    view.rerender(<AdminToastProvider />); await act(async () => resolveSave());
    expect(screen.queryByText("Membership tier saved.")).toBeNull();
  });
});

const partner = { id: "99967000-0000-4000-8000-000000000100", name: "Current club partner", slug: "club-partner", category: "football" };
function Harness({ partners = [partner], grantedAccess = access } = {}) {
  const [form, setForm] = useState<MembershipForm>(emptyForm);
  return (
    <MembershipEditorForm
      form={form}
      setForm={setForm}
      currencyCode="RWF"
      client={{} as SupabaseClient}
      access={grantedAccess}
      partners={partners}
      onSaved={vi.fn()}
      onConflict={vi.fn()}
    />
  );
}

function EditHarness() {
  const [form, setForm] = useState<MembershipForm>({
    ...emptyForm,
    id: "tier-1",
    title: "Existing tier",
  });
  return (
    <MembershipEditorForm
      form={form}
      setForm={setForm}
      currencyCode="RWF"
      client={{} as SupabaseClient}
      access={access}
      partners={[partner]}
      onSaved={vi.fn()}
      onConflict={vi.fn()}
    />
  );
}

const access: AdminAccess = {
  hasAccess: true,
  isAuthenticated: true,
  isSuperAdmin: false,
  userId: "admin-1",
  role: "club_admin",
  clubId: "24",
  availableClubIds: ["24"],
  canSelectClub: false,
  assignmentCount: 1,
};
