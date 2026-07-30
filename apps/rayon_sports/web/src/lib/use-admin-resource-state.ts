"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import {
  resolveAdminResourceFailure,
  type AdminResourceStatus,
  withAdminResourceTimeout,
} from "@/lib/admin-resource-state";

export function useAdminResourceState<T>({
  enabled = true,
  emptyValue,
  isEmpty,
  load,
  normalize,
  onPermissionDenied,
  resourceLabel,
}: {
  enabled?: boolean;
  emptyValue: T;
  isEmpty: (value: T) => boolean;
  load: (signal: AbortSignal) => Promise<unknown>;
  normalize: (value: unknown) => T;
  onPermissionDenied?: () => void;
  resourceLabel: string;
}) {
  const [data, setData] = useState<T>(emptyValue);
  const [status, setStatus] = useState<AdminResourceStatus>("loading");
  const [hasConfirmed, setHasConfirmed] = useState(false);
  const hasConfirmedRef = useRef(false);
  const activeController = useRef<AbortController | null>(null);
  const mounted = useRef(true);

  const applyFailure = useCallback(
    (error: unknown) => {
      const nextStatus = resolveAdminResourceFailure(
        error,
        typeof navigator === "undefined" ? true : navigator.onLine,
      );
      if (nextStatus === "permission_denied") {
        setData(emptyValue);
        setHasConfirmed(false);
        hasConfirmedRef.current = false;
        onPermissionDenied?.();
      }
      setStatus(nextStatus);
      return nextStatus;
    },
    [emptyValue, onPermissionDenied],
  );

  const refresh = useCallback(async () => {
    if (!enabled) {
      return;
    }
    if (typeof navigator !== "undefined" && !navigator.onLine) {
      setStatus("offline");
      return;
    }

    activeController.current?.abort();
    const controller = new AbortController();
    activeController.current = controller;
    setStatus(hasConfirmedRef.current ? "syncing" : "loading");

    try {
      const result = await withAdminResourceTimeout({
        operation: load(controller.signal),
        controller,
        resourceLabel,
      });
      if (!mounted.current) {
        return;
      }
      const normalized = normalize(result);
      setData(normalized);
      setHasConfirmed(true);
      hasConfirmedRef.current = true;
      setStatus(isEmpty(normalized) ? "empty" : "ready");
    } catch (caught) {
      if (
        caught instanceof DOMException &&
        caught.name === "AbortError" &&
        activeController.current !== controller
      ) {
        return;
      }
      if (mounted.current) {
        applyFailure(caught);
      }
    } finally {
      if (activeController.current === controller) {
        activeController.current = null;
      }
    }
  }, [applyFailure, enabled, isEmpty, load, normalize, resourceLabel]);

  useEffect(() => {
    mounted.current = true;
    void refresh();

    const markOffline = () => setStatus("offline");
    const recoverOnline = () => void refresh();
    window.addEventListener("offline", markOffline);
    window.addEventListener("online", recoverOnline);
    return () => {
      mounted.current = false;
      activeController.current?.abort();
      window.removeEventListener("offline", markOffline);
      window.removeEventListener("online", recoverOnline);
    };
  }, [refresh]);

  return {
    data,
    setData,
    status,
    setStatus,
    hasConfirmed,
    busy: status === "loading" || status === "syncing",
    initialLoading: status === "loading" && !hasConfirmed,
    refresh,
    applyFailure,
  };
}
