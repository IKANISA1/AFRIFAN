import { useState } from "react";
import { act, fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";
import { AdminDialogFrame } from "./admin-dialog-frame";

describe("AdminDialogFrame focus contract", () => {
  it("respects a field focused before the initial autofocus frame", async () => {
    render(<Harness />);
    fireEvent.click(screen.getByRole("button", { name: "Open review" }));
    const note = screen.getByRole("textbox", { name: "Reviewer note" });
    note.focus();
    await act(async () => {
      await new Promise<void>((resolve) => requestAnimationFrame(() => resolve()));
    });
    expect(note).toHaveFocus();
  });

  it("keeps the active field focused while a controlled draft rerenders", async () => {
    const user = userEvent.setup({ delay: 25 });
    render(<Harness />);
    await user.click(screen.getByRole("button", { name: "Open review" }));
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Close review" })).toHaveFocus(),
    );
    const note = screen.getByRole("textbox", { name: "Reviewer note" });
    await user.type(note, "Keep this draft");
    expect(note).toHaveValue("Keep this draft");
    expect(note).toHaveFocus();
    await user.keyboard("{Escape}");
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "Open review" })).toHaveFocus(),
    );
    expect(screen.getByLabelText("Dismissed note")).toHaveTextContent(
      "Keep this draft",
    );
  });

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
  const [note, setNote] = useState("");
  const [dismissedNote, setDismissedNote] = useState("");
  return (
    <>
      <button type="button" onClick={() => setOpen(true)}>
        Open review
      </button>
      <output aria-label="Dismissed note">{dismissedNote}</output>
      <AdminDialogFrame
        open={open}
        onClose={() => {
          setDismissedNote(note);
          setOpen(false);
        }}
        title="Review membership"
        closeLabel="Close review"
        footer={<button type="button">Confirm review</button>}
      >
        <label>
          Reviewer note
          <input
            type="text"
            value={note}
            onChange={(event) => setNote(event.target.value)}
          />
        </label>
      </AdminDialogFrame>
    </>
  );
}
