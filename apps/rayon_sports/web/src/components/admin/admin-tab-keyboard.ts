import type { KeyboardEvent } from "react";

/** Move and activate horizontal tabs through their existing click handlers. */
export function handleAdminTabKeyDown(event: KeyboardEvent<HTMLButtonElement>) {
  if (event.altKey || event.ctrlKey || event.metaKey) return;
  if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;

  const current = event.currentTarget;
  const tablist = current.closest('[role="tablist"]');
  if (tablist == null || current.disabled || current.getAttribute("aria-disabled") === "true") return;

  const tabs = Array.from(
    tablist.querySelectorAll<HTMLButtonElement>('button[role="tab"]'),
  ).filter(
    (tab) =>
      tab.closest('[role="tablist"]') === tablist &&
      !tab.disabled &&
      tab.getAttribute("aria-disabled") !== "true",
  );
  const index = tabs.indexOf(current);
  if (index === -1 || tabs.length === 0) return;

  const nextIndex =
    event.key === "Home" ? 0 :
    event.key === "End" ? tabs.length - 1 :
    (index + (event.key === "ArrowRight" ? 1 : -1) + tabs.length) % tabs.length;
  event.preventDefault();
  tabs[nextIndex].focus();
  tabs[nextIndex].click();
}
