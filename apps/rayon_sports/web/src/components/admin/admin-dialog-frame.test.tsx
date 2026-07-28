import { useState } from "react";
import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";
import { AdminDialogFrame } from "./admin-dialog-frame";

describe("AdminDialogFrame focus contract", () => {
  it("contains focus in task order and restores the opening trigger", async () => {
    const user = userEvent.setup();
    render(<Harness />);

    const trigger = screen.getByRole("button", { name: "Open review" });
    trigger.focus();
    await user.keyboard("{Enter}");

    const dialog = await screen.findByRole("dialog", {
      name: "Review membership",
    });
    const close = within(dialog).getByRole("button", { name: "Close review" });
    await waitFor(() => expect(close).toHaveFocus());

    await user.tab();
    expect(screen.getByRole("textbox", { name: "Reviewer note" })).toHaveFocus();

    await user.tab();
    expect(screen.getByRole("button", { name: "Confirm review" })).toHaveFocus();

    await user.tab();
    expect(close).toHaveFocus();
    expect(dialog).toHaveAttribute("aria-modal", "true");

    await user.keyboard("{Escape}");
    await waitFor(() => expect(trigger).toHaveFocus());
    expect(screen.queryByRole("dialog")).toBeNull();
  });
});

function Harness() {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button type="button" onClick={() => setOpen(true)}>
        Open review
      </button>
      <AdminDialogFrame
        open={open}
        onClose={() => setOpen(false)}
        title="Review membership"
        closeLabel="Close review"
        footer={<button type="button">Confirm review</button>}
      >
        <label>
          Reviewer note
          <input type="text" />
        </label>
      </AdminDialogFrame>
    </>
  );
}
