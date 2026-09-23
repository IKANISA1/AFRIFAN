"use client";

import { useEffect, useState } from "react";
import dynamic from "next/dynamic";
import { usePathname } from "next/navigation";

const PwaShell = dynamic(
  () => import("./pwa-shell").then((mod) => mod.PwaShell),
  { ssr: false, loading: () => null },
);

function scheduleWhenIdle(callback: () => void) {
  if ("requestIdleCallback" in window) {
    const handle = window.requestIdleCallback(callback, { timeout: 1500 });
    return () => window.cancelIdleCallback(handle);
  }

  const handle = globalThis.setTimeout(callback, 700);
  return () => globalThis.clearTimeout(handle);
}

function scheduleDeferred(callback: () => void) {
  const timeoutHandle = globalThis.setTimeout(() => {
    cancelIdle = scheduleWhenIdle(callback);
  }, 2500);
  let cancelIdle = () => {};

  return () => {
    globalThis.clearTimeout(timeoutHandle);
    cancelIdle();
  };
}

export function DeferredPwaShell() {
  const pathname = usePathname();
  const isPrioritySurface =
    pathname.startsWith("/supporters") || pathname.startsWith("/admin");
  const [readyPathname, setReadyPathname] = useState<string | null>(
    isPrioritySurface ? pathname : null,
  );

  useEffect(() => {
    if (isPrioritySurface) {
      return;
    }

    let cancelScheduled = () => {};

    const enableShell = () => {
      setReadyPathname(pathname);
    };

    if (document.readyState === "complete") {
      cancelScheduled = scheduleDeferred(enableShell);
    } else {
      const handleLoad = () => {
        cancelScheduled = scheduleDeferred(enableShell);
      };
      window.addEventListener("load", handleLoad, { once: true });
      cancelScheduled = () => {
        window.removeEventListener("load", handleLoad);
      };
    }

    return () => {
      cancelScheduled();
    };
  }, [isPrioritySurface, pathname]);

  if (isPrioritySurface) {
    return <PwaShell />;
  }

  if (readyPathname !== pathname) {
    return null;
  }

  return <PwaShell />;
}
