import { fireEvent, render, screen } from "@testing-library/react";
import { AdminResourceStatusBanner } from "./admin-resource-status-banner";

function setup() {
  const onInteractionChange = vi.fn();
  const onRefresh = vi.fn();
  render(<AdminResourceStatusBanner
    status="ready" label="Confirmed records" detail="Current synthetic records"
    busy={false} refreshLabel="Refresh records" onRefresh={onRefresh}
    onInteractionChange={onInteractionChange}
  />);
  return { button: screen.getByRole("button", { name: "Refresh records" }), onInteractionChange, onRefresh };
}

it.each(["focus", "blur"] as const)("keeps a held pointer pressed when the browser emits %s", (event) => {
  const { button, onInteractionChange, onRefresh } = setup();
  fireEvent.pointerDown(button, { pointerId: 1 });
  fireEvent[event](button);
  expect(onInteractionChange).toHaveBeenLastCalledWith("pressed");
  expect(onRefresh).not.toHaveBeenCalled();
  fireEvent.pointerUp(button, { pointerId: 1 });
  expect(onInteractionChange).toHaveBeenLastCalledWith("idle");
});

it.each(["pointerCancel", "lostPointerCapture"] as const)("clears a held press after %s and restores keyboard focus behavior", (event) => {
  const { button, onInteractionChange, onRefresh } = setup();
  fireEvent.pointerDown(button, { pointerId: 1 });
  fireEvent[event](button, { pointerId: 1 });
  expect(onInteractionChange).toHaveBeenLastCalledWith("idle");
  fireEvent.focus(button);
  expect(onInteractionChange).toHaveBeenLastCalledWith("focused");
  expect(onRefresh).not.toHaveBeenCalled();
});
