"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type { AdminAccess } from "./types";
import { type AdminMediaKind, hasPendingAdminGeneration, readPendingAdminUpload } from "./data/admin/media";
import { AdminUploadLegacyReferenceError, withAdminUploadJournal } from "./data/admin/media-upload-journal";

const prefix = "africlub.admin-media-draft.v1";
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const unavailable = "This composer cannot retain its image reference. Check browser storage and close its other window before continuing.";
const pendingMessage = "Recover the original image command in this composer before clearing, closing, saving, or selecting another record.";
interface Draft { version: 1; userId: string; clubId: string; kind: AdminMediaKind; draftId: string }
interface State { owner: string; scopeKey: string | null; error: string | null; legacyUnbound: boolean }

function ownerKey(access: AdminAccess, kind: AdminMediaKind) {
  if (!access.userId || !/^[0-9a-f-]{36}$/i.test(access.userId) || !access.clubId || !/^[1-9]\d*$/.test(access.clubId)) return null;
  return `${prefix}:${access.userId}:${access.clubId}:${kind}`;
}
function read(key: string, access: AdminAccess, kind: AdminMediaKind): Draft | null {
  const raw = localStorage.getItem(key);
  if (raw === null) return null;
  const draft = JSON.parse(raw) as Draft;
  if (Object.keys(draft).sort().join(",") !== "clubId,draftId,kind,userId,version" || draft.version !== 1
    || draft.userId !== access.userId || draft.clubId !== access.clubId || draft.kind !== kind || !uuid.test(draft.draftId)
    || localStorage.getItem(`${key}:${draft.draftId}`) !== raw) throw new Error(unavailable);
  return draft;
}
function retain(key: string, draft: Draft) {
  const raw = JSON.stringify(draft);
  // Keep every original composer identity recoverable, including after rotation.
  localStorage.setItem(`${key}:${draft.draftId}`, raw);
  if (localStorage.getItem(`${key}:${draft.draftId}`) !== raw) throw new Error(unavailable);
  localStorage.setItem(key, raw);
  if (localStorage.getItem(key) !== raw) throw new Error(unavailable);
}

/** One metadata-only composer lease. Private text and media bytes never persist. */
export function useAdminMediaDraftScope(access: AdminAccess, kind: AdminMediaKind) {
  const owner = ownerKey(access, kind);
  const latest = useRef({ access, owner });
  latest.current = { access, owner };
  const lease = useRef<string | null>(null);
  const action = useRef<string | null>(null);
  const previousLease = useRef<Promise<unknown> | null>(null);
  const [retry, setRetry] = useState(0);
  const [state, setState] = useState<State>({ owner: "", scopeKey: null, error: null, legacyUnbound: false });
  const [working, setWorking] = useState(false);
  const stateRef = useRef(state);
  stateRef.current = state;
  const publish = useCallback((next: State) => { stateRef.current = next; setState(next); }, []);

  const initialize = useCallback(async (key: string) => {
    if (latest.current.owner !== key || lease.current !== key) return;
    const currentAccess = latest.current.access;
    try {
      const old = await readPendingAdminUpload(currentAccess, kind, "new");
      const generation = await hasPendingAdminGeneration(currentAccess, kind, "new");
      if (latest.current.owner !== key || lease.current !== key) return;
      if (old || generation) { publish({ owner: key, scopeKey: "new", error: pendingMessage, legacyUnbound: true }); return; }
      const original = read(key, currentAccess, kind);
      const draft = original ?? { version: 1 as const, userId: currentAccess.userId!, clubId: currentAccess.clubId!, kind, draftId: crypto.randomUUID() };
      if (!original) retain(key, draft);
      if (latest.current.owner === key && lease.current === key) publish({ owner: key, scopeKey: `draft:${draft.draftId}`, error: null, legacyUnbound: false });
    } catch (error) {
      if (latest.current.owner !== key || lease.current !== key) return;
      publish({ owner: key, scopeKey: error instanceof AdminUploadLegacyReferenceError ? "new" : null,
        error: error instanceof AdminUploadLegacyReferenceError ? pendingMessage : unavailable, legacyUnbound: error instanceof AdminUploadLegacyReferenceError });
    }
  }, [kind, publish]);

  useEffect(() => {
    if (!owner) return;
    action.current = null;
    setWorking(false);
    let active = true;
    let release: (() => void) | undefined;
    const held = new Promise<void>(done => { release = done; });
    if (!navigator.locks?.request) { publish({ owner, scopeKey: null, error: unavailable, legacyUnbound: false }); return; }
    // Wait only for this hook's prior cleanup. A different window never waits
    // behind the lease and then silently starts operating a changed composer.
    const request = Promise.resolve(previousLease.current).then(() => navigator.locks.request(`${owner}:composer`, { ifAvailable: true }, async lock => {
      if (!active) return;
      if (!lock) { publish({ owner, scopeKey: null, error: unavailable, legacyUnbound: false }); return; }
      lease.current = owner;
      await initialize(owner);
      await held;
      if (lease.current === owner) lease.current = null;
    })).catch(() => { if (active) publish({ owner, scopeKey: null, error: unavailable, legacyUnbound: false }); });
    previousLease.current = request;
    return () => { active = false; release?.(); if (lease.current === owner) lease.current = null; };
  }, [owner, initialize, publish, retry]);

  useEffect(() => {
    const onFocus = () => {
      if (!owner || !latest.current.access.hasAccess || action.current) return;
      if (lease.current === owner) void initialize(owner);
      else setRetry(value => value + 1);
    };
    window.addEventListener("focus", onFocus);
    return () => window.removeEventListener("focus", onFocus);
  }, [owner, initialize]);

  const guard = useCallback(async (rotate: boolean, recordScope?: string): Promise<boolean> => {
    const owned = latest.current.owner;
    const current = stateRef.current;
    if (!owned || lease.current !== owned || !latest.current.access.hasAccess || current.owner !== owned || !current.scopeKey || current.legacyUnbound || current.error === unavailable || action.current === owned) return false;
    action.current = owned;
    const currentScope = current.scopeKey;
    setWorking(true);
    try {
      const accessAtStart = latest.current.access;
      return await withAdminUploadJournal(accessAtStart, kind, currentScope, async pending => {
        if (pending || await hasPendingAdminGeneration(accessAtStart, kind, currentScope)
          || (recordScope && recordScope !== currentScope && (await readPendingAdminUpload(accessAtStart, kind, recordScope)
            || await hasPendingAdminGeneration(accessAtStart, kind, recordScope)))) throw new Error(pendingMessage);
        if (latest.current.owner !== owned || lease.current !== owned || !latest.current.access.hasAccess
          || `draft:${read(owned, accessAtStart, kind)?.draftId}` !== current.scopeKey) throw new Error(unavailable);
        if (rotate) {
          const draft: Draft = { version: 1, userId: accessAtStart.userId!, clubId: accessAtStart.clubId!, kind, draftId: crypto.randomUUID() };
          retain(owned, draft);
          publish({ owner: owned, scopeKey: `draft:${draft.draftId}`, error: null, legacyUnbound: false });
        } else publish({ ...current, error: null });
        return true;
      });
    } catch (error) {
      if (latest.current.owner === owned && lease.current === owned) publish({ ...current, error: error instanceof Error && error.message === pendingMessage ? pendingMessage : unavailable });
      return false;
    } finally { if (action.current === owned) action.current = null; if (latest.current.owner === owned) setWorking(false); }
  }, [kind, publish]);
  const visible = owner === state.owner ? state : null;
  async function runSave<T>(save: () => Promise<T>, recordScope?: string): Promise<T> {
    if (!await guard(false, recordScope)) throw new Error(pendingMessage);
    const owned = latest.current.owner;
    if (!owned || lease.current !== owned || action.current || !latest.current.access.hasAccess) throw new Error(unavailable);
    action.current = owned;
    setWorking(true);
    try {
      const result = await save();
      if (latest.current.owner !== owned || lease.current !== owned || !latest.current.access.hasAccess) throw new Error(unavailable);
      return result;
    } finally { if (action.current === owned) action.current = null; if (latest.current.owner === owned) setWorking(false); }
  }
  return {
    scopeKey: visible?.scopeKey ?? null,
    ready: !!visible?.scopeKey && !visible.legacyUnbound && visible.error !== unavailable && !working && lease.current === owner && access.hasAccess,
    error: visible?.error ?? null,
    legacyUnbound: visible?.legacyUnbound ?? false,
    canLeaveDraft: (recordScope?: string) => guard(false, recordScope),
    resetDraft: (recordScope?: string) => guard(true, recordScope),
    runSave,
    refreshRecovery: () => { if (owner && lease.current === owner) void initialize(owner); },
  };
}
