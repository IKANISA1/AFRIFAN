import { useState } from "react";
import { fireEvent, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { handleAdminTabKeyDown } from "./admin-tab-keyboard";

const names = ["Overview", "Sources", "Logs"];

function Tabs({ disabled = [], ariaDisabled = [], onActivate = () => {} }: {
  disabled?: string[];
  ariaDisabled?: string[];
  onActivate?: (name: string) => void;
}) {
  const [active, setActive] = useState(names[0]);
  return <>
    <div role="tablist" aria-label="Synchronization views">
      {names.map((name) => <button
        key={name}
        id={`tab-${name}`}
        type="button"
        role="tab"
        aria-selected={active === name}
        aria-controls="test-panel"
        aria-disabled={ariaDisabled.includes(name) || undefined}
        tabIndex={active === name ? 0 : -1}
        disabled={disabled.includes(name)}
        onKeyDown={handleAdminTabKeyDown}
        onClick={() => { setActive(name); onActivate(name); }}
      >{name}</button>)}
    </div>
    <div id="test-panel" role="tabpanel" aria-labelledby={`tab-${active}`} tabIndex={0}>
      {active} content
    </div>
  </>;
}

describe("admin horizontal tab keyboard navigation", () => {
  it.each([
    ["Overview", "ArrowRight", "Sources"],
    ["Sources", "ArrowLeft", "Overview"],
    ["Overview", "ArrowLeft", "Logs"],
    ["Logs", "ArrowRight", "Overview"],
    ["Sources", "Home", "Overview"],
    ["Sources", "End", "Logs"],
  ])("moves %s with %s to %s and uses the existing activation handler", (start, key, target) => {
    const activated = vi.fn();
    render(<Tabs onActivate={activated} />);
    const source = screen.getByRole("tab", { name: start });
    fireEvent.click(source);
    activated.mockClear();
    source.focus();
    expect(fireEvent.keyDown(source, { key })).toBe(false);
    const destination = screen.getByRole("tab", { name: target });
    expect(destination).toHaveFocus();
    expect(destination).toHaveAttribute("aria-selected", "true");
    expect(destination).toHaveAttribute("tabindex", "0");
    expect(screen.getByRole("tabpanel", { name: target })).toHaveTextContent(`${target} content`);
    expect(activated).toHaveBeenCalledExactlyOnceWith(target);
    for (const tab of screen.getAllByRole("tab")) {
      if (tab !== destination) expect(tab).toHaveAttribute("tabindex", "-1");
    }
  });

  it("skips natively disabled tabs while wrapping", () => {
    render(<Tabs disabled={["Sources"]} />);
    const first = screen.getByRole("tab", { name: "Overview" });
    first.focus();
    fireEvent.keyDown(first, { key: "ArrowRight" });
    const last = screen.getByRole("tab", { name: "Logs" });
    expect(last).toHaveFocus();
    fireEvent.keyDown(last, { key: "ArrowLeft" });
    expect(first).toHaveFocus();
  });

  it("skips aria-disabled tabs for endpoint navigation", () => {
    render(<Tabs ariaDisabled={["Logs"]} />);
    const first = screen.getByRole("tab", { name: "Overview" });
    first.focus();
    fireEvent.keyDown(first, { key: "End" });
    expect(screen.getByRole("tab", { name: "Sources" })).toHaveFocus();
  });

  it.each(["Tab", "ArrowUp", "ArrowDown", "Enter", " "])("preserves native handling of %s", (key) => {
    const activated = vi.fn();
    render(<Tabs onActivate={activated} />);
    const first = screen.getByRole("tab", { name: "Overview" });
    first.focus();
    expect(fireEvent.keyDown(first, { key })).toBe(true);
    expect(first).toHaveFocus();
    expect(activated).not.toHaveBeenCalled();
  });

  it.each(["altKey", "ctrlKey", "metaKey"])("preserves %s browser shortcuts", (modifier) => {
    const activated = vi.fn();
    render(<Tabs onActivate={activated} />);
    const first = screen.getByRole("tab", { name: "Overview" });
    expect(fireEvent.keyDown(first, { key: "ArrowRight", [modifier]: true })).toBe(true);
    expect(activated).not.toHaveBeenCalled();
  });

  it("leaves a disabled current tab unchanged", () => {
    const activated = vi.fn();
    render(<Tabs disabled={names} onActivate={activated} />);
    expect(fireEvent.keyDown(screen.getByRole("tab", { name: "Overview" }), { key: "Home" })).toBe(true);
    expect(activated).not.toHaveBeenCalled();
  });

  it("ignores handlers outside a tablist", () => {
    const activated = vi.fn();
    render(<button role="tab" onKeyDown={handleAdminTabKeyDown} onClick={activated}>Unowned tab</button>);
    expect(fireEvent.keyDown(screen.getByRole("tab"), { key: "ArrowRight" })).toBe(true);
    expect(activated).not.toHaveBeenCalled();
  });

  it("places only the active tab in the normal focus order before its panel", async () => {
    const user = userEvent.setup();
    render(<Tabs />);
    await user.tab();
    expect(screen.getByRole("tab", { name: "Overview" })).toHaveFocus();
    await user.keyboard("{End}");
    expect(screen.getByRole("tab", { name: "Logs" })).toHaveFocus();
    await user.tab();
    expect(screen.getByRole("tabpanel", { name: "Logs" })).toHaveFocus();
    await user.tab({ shift: true });
    expect(screen.getByRole("tab", { name: "Logs" })).toHaveFocus();
  });
});
