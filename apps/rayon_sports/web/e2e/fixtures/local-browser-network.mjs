const guardedContexts = new WeakSet();
const networkCounts = new WeakMap();

/** @param {import('@playwright/test').BrowserContext} context */
export function stateEvidenceNetworkCounts(context) {
  const counts = networkCounts.get(context);
  if (!counts) throw new Error("State evidence context has no network fence");
  return { ...counts };
}

/** @param {import('@playwright/test').BrowserContext} context */
export async function guardStateEvidenceContext(context) {
  if (guardedContexts.has(context)) return;
  const counts = { httpAllowed: 0, httpBlocked: 0, webSocketAllowed: 0, webSocketBlocked: 0 };
  networkCounts.set(context, counts);
  context.once("close", () => console.log(JSON.stringify({ localBrowserNetworkGuard: 1, ...counts })));
  await context.route("**/*", async (route) => {
    const url = new URL(route.request().url());
    if (url.origin === "http://127.0.0.1:3200") {
      counts.httpAllowed++;
      await route.fallback();
    } else {
      counts.httpBlocked++;
      await route.abort("blockedbyclient");
    }
  });
  await context.routeWebSocket("**/*", async (socket) => {
    const url = new URL(socket.url());
    if (url.origin === "ws://127.0.0.1:3200") {
      counts.webSocketAllowed++;
      socket.connectToServer();
    } else {
      counts.webSocketBlocked++;
      await socket.close({ code: 1008, reason: "Local validation network fence" });
    }
  });
  guardedContexts.add(context);
}

/**
 * @param {import('@playwright/test').Browser} browser
 * @param {import('@playwright/test').BrowserContextOptions} options
 */
export async function createStateEvidenceContext(browser, options) {
  const context = await browser.newContext({ ...options, serviceWorkers: "block" });
  try {
    await guardStateEvidenceContext(context);
    return context;
  } catch (error) {
    await context.close();
    throw error;
  }
}
