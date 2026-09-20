/** Activate only on an explicit refresh. Other tabs retain their current page. */
export function activatePwaUpdate(
  registration: ServiceWorkerRegistration,
  container: ServiceWorkerContainer,
  signal: AbortSignal,
): Promise<void> {
  if (signal.aborted) return Promise.reject(new Error("Update cancelled"));
  const worker = registration.waiting;
  // Another tab may already have activated the update while this one was editing.
  if (!worker) return Promise.resolve();
  const previous = container.controller;
  return new Promise<void>((resolve, reject) => {
    const cleanup = () => {
      clearTimeout(timer);
      container.removeEventListener("controllerchange", changed);
      signal.removeEventListener("abort", aborted);
    };
    const changed = () => {
      if (container.controller && container.controller !== previous) {
        cleanup();
        resolve();
      }
    };
    const aborted = () => { cleanup(); reject(new Error("Update cancelled")); };
    const timer = setTimeout(() => {
      cleanup();
      reject(new Error("The update is not ready yet. Your page has been kept open. Try again."));
    }, 15_000);
    container.addEventListener("controllerchange", changed);
    signal.addEventListener("abort", aborted, { once: true });
    try { worker.postMessage({ type: "SKIP_WAITING" }); }
    catch (error) { cleanup(); reject(error); }
  });
}
