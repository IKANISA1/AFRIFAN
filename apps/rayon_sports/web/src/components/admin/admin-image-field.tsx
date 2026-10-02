"use client";

import { useEffect, useId, useRef, useState, type ChangeEvent } from "react";
import { ImagePlus, Sparkles, Trash2, Upload } from "lucide-react";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { cn } from "@/lib/utils";
import {
  type AdminMediaKind,
  defaultAspectRatioForAdminMediaKind,
  generateAdminImage,
  readPendingAdminGeneration,
  checkAdminImageGenerationStatus,
  readPendingAdminUpload,
  checkAdminImageUploadStatus,
  releaseUnadmittedAdminImageUpload,
  AdminUploadLegacyReferenceError,
  type AdminUploadJournalEntry,
  type AdminImageGenerationReceipt,
  uploadAdminImage,
} from "@/lib/data/admin/media";
import type { StaffCommandReference } from "@/lib/data/admin/staff-command-journal";

interface AdminImageFieldProps {
  label: string;
  value: string;
  onChange: (nextValue: string) => void;
  mediaKind: AdminMediaKind;
  scopeKey: string;
  name?: string;
  subject?: string | null;
  previewAlt?: string;
  promptPlaceholder?: string;
  className?: string;
  disabled?: boolean;
  recoveryOnly?: boolean;
  onRecoveryResolved?: () => void;
}

export function AdminImageField({
  label,
  value,
  onChange,
  mediaKind,
  scopeKey,
  name,
  subject,
  previewAlt = "Image preview",
  promptPlaceholder,
  className,
  disabled: externallyDisabled = false,
  recoveryOnly = false,
  onRecoveryResolved,
}: AdminImageFieldProps) {
  const inputId = useId();
  const { client, access, activeClub } = useAdminPortal();
  const [prompt, setPrompt] = useState("");
  const [uploading, setUploading] = useState(false);
  const [generating, setGenerating] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [pending, setPending] = useState<AdminUploadJournalEntry | null>(null);
  const [pendingGeneration, setPendingGeneration] = useState<StaffCommandReference | null>(null);
  const [generationRetryable, setGenerationRetryable] = useState(false);
  const [generationRequest, setGenerationRequest] = useState<AdminImageGenerationReceipt["request"] | null>(null);
  const [uploadMessage, setUploadMessage] = useState<string | null>(null);
  const [journalUnavailable, setJournalUnavailable] = useState(false);
  const [journalLoading, setJournalLoading] = useState(true);
  const [unadmitted, setUnadmitted] = useState(false);
  const [legacyUnbound, setLegacyUnbound] = useState(false);
  const busy = useRef(false);
  const epoch = useRef(0);
  const mounted = useRef(false);
  const fileInput = useRef<HTMLInputElement | null>(null);
  const fieldOwner = `${access.userId ?? ""}:${access.clubId ?? ""}:${access.role ?? ""}:${mediaKind}:${scopeKey}:${recoveryOnly}`;
  const latest = useRef({ fieldOwner, client, allowed: false });
  const latestAccess = useRef(access);
  latestAccess.current = access;
  latest.current = { fieldOwner, client, allowed: !externallyDisabled && client != null && access.hasAccess && !!access.userId && !!access.clubId };

  useEffect(() => {
    const ownedEpoch = epoch;
    const ownedMounted = mounted;
    ownedMounted.current = true;
    ++ownedEpoch.current;
    busy.current = false;
    setUploading(false);
    setGenerating(false);
    setSelectedFile(null);
    if (fileInput.current) fileInput.current.value = "";
    setPrompt("");
    setPending(null); setPendingGeneration(null); setGenerationRetryable(false); setGenerationRequest(null);
    setUploadMessage(null); setJournalUnavailable(false);
    setJournalLoading(true); setUnadmitted(false); setLegacyUnbound(false);
    return () => { ownedMounted.current = false; ++ownedEpoch.current; };
  }, [fieldOwner, client, mediaKind]);

  useEffect(() => {
    if (!latest.current.allowed) { setJournalLoading(false); return; }
    const ownedEpoch = epoch.current;
    let active = true;
    const current = () => active && mounted.current && epoch.current === ownedEpoch
      && latest.current.fieldOwner === fieldOwner && latest.current.client === client && latest.current.allowed;
    setJournalLoading(true);
    void (async () => {
      try {
        const [saved, generation] = await Promise.all([readPendingAdminUpload(latestAccess.current, mediaKind, scopeKey),
          readPendingAdminGeneration(latestAccess.current, mediaKind, scopeKey)]);
        if (!current()) return;
        setPending(saved); setPendingGeneration(generation); setJournalUnavailable(false); setLegacyUnbound(false);
      } catch (caught) {
        if (!current()) return;
        setPending(null); setJournalUnavailable(true);
        setLegacyUnbound(caught instanceof AdminUploadLegacyReferenceError);
        setUploadMessage(caught instanceof AdminUploadLegacyReferenceError
          ? "An earlier upload has no saved form binding. Release its unused reference before sending another image."
          : "The saved upload could not be read. Check browser storage before sending another image.");
      } finally { if (current()) setJournalLoading(false); }
    })();
    return () => { active = false; };
  }, [access.hasAccess, externallyDisabled, fieldOwner, mediaKind, client, scopeKey]);

  function ownOperation() {
    const ownedEpoch = epoch.current;
    return () => mounted.current && epoch.current === ownedEpoch && latest.current.fieldOwner === fieldOwner
      && latest.current.client === client && latest.current.allowed;
  }

  async function syncPending(current: () => boolean) {
    try {
      const saved = await readPendingAdminUpload(access, mediaKind, scopeKey);
      if (!current()) return null;
      setPending(saved); setJournalUnavailable(false); setLegacyUnbound(false);
      return saved;
    } catch (caught) {
      if (!current()) return null;
      setJournalUnavailable(true); setLegacyUnbound(caught instanceof AdminUploadLegacyReferenceError);
      setUploadMessage("The saved upload could not be read. Check browser storage before sending another image.");
      return null;
    }
  }

  async function handleFileChange(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (recoveryOnly || pendingGeneration || !file || client == null || busy.current || journalLoading || journalUnavailable || !latest.current.allowed) return;
    setSelectedFile(file);
    await handleUpload(file);
  }

  async function handleUpload(file: File) {
    if (recoveryOnly || pendingGeneration || client == null || busy.current || journalLoading || journalUnavailable || !latest.current.allowed) return;
    const current = ownOperation();
    const epochAtStart = epoch.current;
    busy.current = true;
    setUploading(true);
    setUploadMessage(null);
    showAdminToast("Uploading image...", "info");
    try {
      const uploaded = await uploadAdminImage(client, access, {
        file,
        kind: mediaKind,
        clubSlug: activeClub?.clubSlug ?? null,
        scopeKey,
        isCurrent: current,
      });
      if (!current()) return;
      await syncPending(current);
      if (!current()) return;
      onChange(uploaded.publicUrl);
      setSelectedFile(null);
      if (fileInput.current) fileInput.current.value = "";
      setUnadmitted(false);
      setUploadMessage("Image uploaded. Save the form to keep it attached.");
      onRecoveryResolved?.();
      showAdminToast("Image uploaded and attached to the form.", "success");
    } catch (caught) {
      if (!current()) return;
      await syncPending(current);
      if (!current()) return;
      setUploadMessage(caught instanceof Error ? caught.message : "The upload could not be confirmed. Check its status before sending another image.");
      showAdminToast(
        caught instanceof Error ? caught.message : "Image upload failed.",
        "error",
      );
    } finally {
      if (mounted.current && epoch.current === epochAtStart) { busy.current = false; setUploading(false); }
    }
  }

  async function handleCheckStatus() {
    if (client == null || busy.current || journalLoading || journalUnavailable || !latest.current.allowed) return;
    const current = ownOperation();
    const ownedEpoch = epoch.current;
    busy.current = true; setUploading(true);
    try {
      const receipt = await checkAdminImageUploadStatus(client, access, mediaKind, { scopeKey, isCurrent: current });
      if (!current()) return;
      const saved = await syncPending(current);
      if (!current()) return;
      setUnadmitted(receipt === null && saved !== null);
      if (receipt?.status === "completed" && receipt.publicUrl) {
        if (!recoveryOnly) onChange(receipt.publicUrl);
        setSelectedFile(null);
        if (fileInput.current) fileInput.current.value = "";
        setUploadMessage(recoveryOnly ? "The earlier upload is confirmed. Its image was kept separate from this new draft."
          : "Image uploaded. Save the form to keep it attached.");
        if (saved === null) onRecoveryResolved?.();
      } else setUploadMessage(receipt === null && saved !== null
        ? "The original upload has not been admitted. You can safely release its unused reference."
        : receipt?.status === "staged"
        ? "The image is stored. Confirm the same image with your current staff session."
        : "The upload is awaiting confirmation. Keep its saved reference and check again.");
    } catch (caught) {
      if (current()) setUploadMessage(caught instanceof Error ? caught.message : "Upload status could not be checked.");
    } finally {
      if (mounted.current && epoch.current === ownedEpoch) { busy.current = false; setUploading(false); }
    }
  }

  async function handleReleaseUnused() {
    if (client == null || busy.current || journalLoading || !latest.current.allowed) return;
    const current = ownOperation(); const ownedEpoch = epoch.current;
    busy.current = true; setUploading(true);
    try {
      const released = await releaseUnadmittedAdminImageUpload(client, access, mediaKind, { scopeKey, isCurrent: current });
      if (!current()) return;
      await syncPending(current);
      if (!current()) return;
      setUnadmitted(false); setLegacyUnbound(false); setSelectedFile(null);
      if (fileInput.current) fileInput.current.value = "";
      setUploadMessage(released ? "The unused reference is released. You can choose another image."
        : "No saved upload needs release.");
      onRecoveryResolved?.();
    } catch (caught) {
      if (current()) setUploadMessage(caught instanceof Error ? caught.message : "The unused reference could not be released. Keep it and check again.");
    } finally {
      if (mounted.current && epoch.current === ownedEpoch) { busy.current = false; setUploading(false); }
    }
  }

  async function handleGenerate() {
    if ((recoveryOnly && !(pendingGeneration && generationRetryable && generationRequest)) || (pendingGeneration && !generationRetryable)
      || busy.current || journalLoading || journalUnavailable || pending || !latest.current.allowed) return;
    if (client == null) {
      showAdminToast("Supabase browser client is not ready.", "error");
      return;
    }

    const current = ownOperation();
    const ownedEpoch = epoch.current;
    busy.current = true;
    setGenerating(true);
    showAdminToast("Generating image...", "info");
    try {
      const generated = await generateAdminImage(client, access, {
        ...(generationRequest ?? { kind: mediaKind, prompt, subject, aspectRatio: defaultAspectRatioForAdminMediaKind(mediaKind) }),
        scopeKey,
        isCurrent: current,
      });
      if (!current()) return;
      const savedGeneration = await readPendingAdminGeneration(access, mediaKind, scopeKey);
      if (!current()) return;
      setPendingGeneration(savedGeneration);
      if (!recoveryOnly) onChange(generated.publicUrl);
      onRecoveryResolved?.();
      setGenerationRetryable(false); setGenerationRequest(null);
      setPrompt("");
      showAdminToast(recoveryOnly ? "The earlier generation is confirmed and kept separate from this draft."
        : "Image generated. Save the form to keep it attached.", "success");
    } catch (caught) {
      if (!current()) return;
      setGenerationRetryable(false);
      try {
        const savedGeneration = await readPendingAdminGeneration(access, mediaKind, scopeKey);
        if (current()) setPendingGeneration(savedGeneration);
      }
      catch { if (current()) setJournalUnavailable(true); }
      if (!current()) return;
      setUploadMessage(caught instanceof Error ? caught.message : "Image generation remains unconfirmed.");
      showAdminToast(
        caught instanceof Error ? caught.message : "Image generation failed.",
        "error",
      );
    } finally {
      if (mounted.current && epoch.current === ownedEpoch) { busy.current = false; setGenerating(false); }
    }
  }

  async function handleGenerationStatus() {
    if (!client || busy.current || journalLoading || journalUnavailable || !latest.current.allowed) return;
    const current = ownOperation(), ownedEpoch = epoch.current;
    busy.current = true; setGenerating(true);
    try {
      const receipt = await checkAdminImageGenerationStatus(client, access, mediaKind, { scopeKey, isCurrent: current });
      if (!current()) return;
      const saved = await readPendingAdminGeneration(access, mediaKind, scopeKey);
      if (!current()) return;
      setPendingGeneration(saved);
      setGenerationRetryable(receipt === null || ["pending", "staged"].includes(receipt.status));
      setGenerationRequest(receipt && ["pending", "staged"].includes(receipt.status) ? receipt.request : null);
      if (receipt?.status === "completed" && receipt.image) {
        if (!recoveryOnly) onChange(receipt.image.publicUrl);
        setUploadMessage(recoveryOnly ? "The earlier generation is confirmed. Its image was kept separate from this new draft."
          : "Image generation is confirmed. Save the form to keep it attached.");
        if (saved === null) onRecoveryResolved?.();
      } else {
        if (receipt && ["pending", "staged"].includes(receipt.status) && !recoveryOnly) setPrompt(receipt.request.prompt);
        setUploadMessage(receipt === null ? "The original generation has not been admitted. Its reference is retained; re-enter the same prompt to retry it."
          : receipt.status === "staged" ? "The original image is stored. Confirm its saved request with your current staff session."
          : "Generation remains unconfirmed. Its reference is retained; it will not be generated again.");
      }
    } catch (caught) { if (current()) setUploadMessage(caught instanceof Error ? caught.message : "Generation status is unavailable. Keep its reference."); }
    finally { if (mounted.current && epoch.current === ownedEpoch) { busy.current = false; setGenerating(false); } }
  }

  const disabled =
    externallyDisabled || journalUnavailable || journalLoading || client == null || !access.hasAccess || !access.userId || !access.clubId;
  const creationDisabled = disabled || recoveryOnly || uploading || generating;

  return (
    <div
      className={cn(
        "grid gap-3 rounded-[22px] border border-border-soft bg-[var(--admin-surface-muted)] p-4",
        className,
      )}
    >
      {name ? <input type="hidden" name={name} value={value} readOnly /> : null}
      <div className="flex items-center justify-between gap-3">
        <div>
          <p className="text-sm font-semibold text-[var(--admin-text-strong)]">{label}</p>
          <p className="text-xs text-[var(--admin-text-muted)]">
            Upload an image, or describe one to generate.
          </p>
        </div>
        {value ? (
          <button
            type="button"
            onClick={() => onChange("")}
            disabled={creationDisabled}
            className="min-h-12 min-w-12 rounded-full border border-border-soft p-3 text-[var(--admin-text-strong)] transition hover:bg-[var(--admin-surface-hover)]"
            title="Remove image"
          >
            <Trash2 size={14} />
          </button>
        ) : null}
      </div>

      {pending || uploadMessage ? <div className="grid gap-2 text-sm" role="status" aria-live="polite">
        <p className="text-[var(--admin-text-muted)]">{uploadMessage ?? "An upload is saved and awaiting confirmation."}</p>
        {pending ? <div className="flex flex-wrap gap-2">
          <button type="button" className="dashboard-button-secondary min-h-12" disabled={disabled || uploading || generating} onClick={() => { void handleCheckStatus(); }}>Check upload status</button>
          {!recoveryOnly && (selectedFile ? <button type="button" className="dashboard-button-secondary min-h-12" disabled={disabled || uploading || generating} onClick={() => { void handleUpload(selectedFile); }}>Confirm same image</button> : <p className="text-xs text-[var(--admin-text-muted)]">Select the same file to confirm the saved upload.</p>)}
        </div> : null}
        {unadmitted || legacyUnbound ? <button type="button" className="dashboard-button-secondary min-h-12 justify-self-start"
          disabled={externallyDisabled || journalLoading || uploading || generating || !latest.current.allowed}
          onClick={() => { void handleReleaseUnused(); }}>Release unused upload</button> : null}
      </div> : null}
      {pendingGeneration ? <div className="grid gap-2 text-sm" role="status" aria-live="polite">
        <p className="break-all text-[var(--admin-text-muted)]">Original generation: {pendingGeneration.operationId}</p>
        <button type="button" className="dashboard-button-secondary min-h-12 justify-self-start" disabled={disabled || uploading || generating}
          onClick={() => { void handleGenerationStatus(); }}>Check generation status</button>
        {recoveryOnly && generationRetryable && generationRequest ? <button type="button" className="dashboard-button-secondary min-h-12 justify-self-start"
          disabled={disabled || uploading || generating} onClick={() => { void handleGenerate(); }}>Confirm earlier generation</button> : null}
      </div> : null}

      <div className="flex flex-wrap gap-3">
        <label
          htmlFor={inputId}
          aria-disabled={creationDisabled || !!pendingGeneration}
          className={cn(
            "inline-flex min-h-12 items-center gap-2 rounded-full border border-border-soft px-4 py-3 text-sm font-semibold text-[var(--admin-text-strong)] transition hover:bg-[var(--admin-surface-hover)]",
            creationDisabled || !!pendingGeneration
              ? "cursor-not-allowed opacity-60"
              : "cursor-pointer",
          )}
        >
          <Upload size={14} />
          {uploading ? "Uploading..." : "Upload image"}
        </label>
        <input
          ref={fileInput}
          id={inputId}
          type="file"
          accept="image/png,image/jpeg,image/webp"
          onChange={handleFileChange}
          disabled={creationDisabled || !!pendingGeneration}
          className="sr-only"
        />
        <button
          type="button"
          onClick={() => {
            void handleGenerate();
          }}
          disabled={creationDisabled || !!pending || (!!pendingGeneration && !generationRetryable) || !prompt.trim()}
          className="inline-flex min-h-12 items-center gap-2 rounded-full bg-action-blue px-4 py-3 text-sm font-semibold text-white transition hover:bg-action-blue-hover disabled:opacity-60"
        >
          <Sparkles size={14} />
          {generating ? "Checking image..." : pendingGeneration ? "Confirm original generation" : "Generate image"}
        </button>
      </div>

      <label className="grid gap-2 text-sm">
        <span className="text-[var(--admin-text-strong)]">Prompt</span>
        <textarea
          rows={3}
          value={prompt}
          onChange={(event) => setPrompt(event.target.value)}
          disabled={creationDisabled || !!generationRequest}
          placeholder={
            promptPlaceholder ??
            "Describe the image you want the admin panel to generate for this entry."
          }
          className="dashboard-input min-h-24 resize-y"
        />
      </label>

      {value ? (
        <div className="overflow-hidden rounded-[20px] border border-border-soft bg-background/40">
          {/* eslint-disable-next-line @next/next/no-img-element -- Admin media previews can point to runtime-generated Supabase storage URLs. */}
          <img src={value} alt={previewAlt} className="h-32 w-full object-cover" />
        </div>
      ) : (
        <div className="flex min-h-32 items-center justify-center rounded-[20px] border border-dashed border-border-soft bg-[var(--admin-surface-muted)] text-sm text-[var(--admin-text-muted)]">
          <span className="inline-flex items-center gap-2">
            <ImagePlus size={16} />
            No image selected
          </span>
        </div>
      )}
    </div>
  );
}
