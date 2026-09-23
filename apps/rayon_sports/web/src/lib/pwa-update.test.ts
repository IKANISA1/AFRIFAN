import { activatePwaUpdate } from "./pwa-update";

function fixture() {
  const container = Object.assign(new EventTarget(), { controller: { state: "activated" } });
  const postMessage = vi.fn();
  const registration = { waiting: { postMessage } };
  const abort = new AbortController();
  const start = () => activatePwaUpdate(
    registration as unknown as ServiceWorkerRegistration,
    container as unknown as ServiceWorkerContainer,
    abort.signal,
  );
  return { container, postMessage, registration, abort, start };
}

afterEach(() => { vi.useRealTimers(); });

it("waits for the new controller rather than reloading immediately after the activation message", async () => {
  const f = fixture();
  const complete = vi.fn();
  const pending = f.start().then(complete);
  expect(f.postMessage).toHaveBeenCalledWith({ type: "SKIP_WAITING" });
  await Promise.resolve();
  expect(complete).not.toHaveBeenCalled();
  f.container.dispatchEvent(new Event("controllerchange"));
  await Promise.resolve();
  expect(complete).not.toHaveBeenCalled();
  f.container.controller = { state: "activated" };
  f.container.dispatchEvent(new Event("controllerchange"));
  await pending;
  expect(complete).toHaveBeenCalledOnce();
});

it("times out without later completing when a delayed update eventually activates", async () => {
  vi.useFakeTimers();
  const f = fixture();
  const pending = expect(f.start()).rejects.toThrow("kept open");
  await vi.advanceTimersByTimeAsync(15_000);
  await pending;
  f.container.controller = { state: "activated" };
  f.container.dispatchEvent(new Event("controllerchange"));
  expect(vi.getTimerCount()).toBe(0);
});

it("cancels pending activation on keep editing or unmount", async () => {
  const f = fixture();
  const pending = expect(f.start()).rejects.toThrow("cancelled");
  f.abort.abort();
  await pending;
});

it("can refresh after another tab has already activated the update", async () => {
  const f = fixture();
  await expect(activatePwaUpdate(
    { waiting: null } as ServiceWorkerRegistration,
    f.container as unknown as ServiceWorkerContainer,
    f.abort.signal,
  )).resolves.toBeUndefined();
  expect(f.postMessage).not.toHaveBeenCalled();
});

it("reports a worker messaging failure without leaving a pending timer", async () => {
  vi.useFakeTimers();
  const f = fixture();
  f.postMessage.mockImplementation(() => { throw new Error("Worker unavailable"); });
  await expect(f.start()).rejects.toThrow("Worker unavailable");
  expect(vi.getTimerCount()).toBe(0);
});
