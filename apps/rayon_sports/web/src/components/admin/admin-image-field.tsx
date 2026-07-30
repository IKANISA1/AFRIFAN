"use client";

import { useId, useState, type ChangeEvent } from "react";
import { ImagePlus, Sparkles, Trash2, Upload } from "lucide-react";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { cn } from "@/lib/utils";
import {
  type AdminMediaKind,
  defaultAspectRatioForAdminMediaKind,
  generateAdminImage,
  uploadAdminImage,
} from "@/lib/data/admin/media";

interface AdminImageFieldProps {
  label: string;
  value: string;
  onChange: (nextValue: string) => void;
  mediaKind: AdminMediaKind;
  name?: string;
  subject?: string | null;
  previewAlt?: string;
  promptPlaceholder?: string;
  className?: string;
  disabled?: boolean;
}

export function AdminImageField({
  label,
  value,
  onChange,
  mediaKind,
  name,
  subject,
  previewAlt = "Image preview",
  promptPlaceholder,
  className,
  disabled: externallyDisabled = false,
}: AdminImageFieldProps) {
  const inputId = useId();
  const { client, access, activeClub } = useAdminPortal();
  const [prompt, setPrompt] = useState("");
  const [uploading, setUploading] = useState(false);
  const [generating, setGenerating] = useState(false);

  async function handleFileChange(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file || client == null) {
      return;
    }

    setUploading(true);
    showAdminToast("Uploading image...", "info");
    try {
      const uploaded = await uploadAdminImage(client, access, {
        file,
        kind: mediaKind,
        clubSlug: activeClub?.clubSlug ?? null,
      });
      onChange(uploaded.publicUrl);
      showAdminToast("Image uploaded and attached to the form.", "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Image upload failed.",
        "error",
      );
    } finally {
      setUploading(false);
    }
  }

  async function handleGenerate() {
    if (client == null) {
      showAdminToast("Supabase browser client is not ready.", "error");
      return;
    }

    setGenerating(true);
    showAdminToast("Generating image with Gemini Nano Banana...", "info");
    try {
      const generated = await generateAdminImage(client, access, {
        kind: mediaKind,
        prompt,
        subject,
        aspectRatio: defaultAspectRatioForAdminMediaKind(mediaKind),
      });
      onChange(generated.publicUrl);
      setPrompt("");
      showAdminToast(
        `Image generated with ${generated.model}. Save the form to persist it.`,
        "success",
      );
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Image generation failed.",
        "error",
      );
    } finally {
      setGenerating(false);
    }
  }

  const disabled =
    externallyDisabled || client == null || !access.hasAccess || !access.clubId;

  return (
    <div
      className={cn(
        "grid gap-3 rounded-[22px] border border-border-soft bg-white/5 p-4",
        className,
      )}
    >
      {name ? <input type="hidden" name={name} value={value} readOnly /> : null}
      <div className="flex items-center justify-between gap-3">
        <div>
          <p className="text-sm font-semibold text-[var(--admin-text-strong)]">{label}</p>
          <p className="text-xs text-[var(--admin-text-muted)]">
            Upload a file or generate one with Gemini Nano Banana. Manual URL entry is disabled.
          </p>
        </div>
        {value ? (
          <button
            type="button"
            onClick={() => onChange("")}
            disabled={disabled}
            className="min-h-12 min-w-12 rounded-full border border-border-soft p-3 text-[var(--admin-text-strong)] transition hover:bg-white/8"
            title="Remove image"
          >
            <Trash2 size={14} />
          </button>
        ) : null}
      </div>

      <div className="flex flex-wrap gap-3">
        <label
          htmlFor={inputId}
          aria-disabled={disabled || uploading || generating}
          className={cn(
            "inline-flex min-h-12 items-center gap-2 rounded-full border border-border-soft px-4 py-3 text-sm font-semibold text-[var(--admin-text-strong)] transition hover:bg-white/8",
            disabled || uploading || generating
              ? "cursor-not-allowed opacity-60"
              : "cursor-pointer",
          )}
        >
          <Upload size={14} />
          {uploading ? "Uploading..." : "Upload image"}
        </label>
        <input
          id={inputId}
          type="file"
          accept="image/png,image/jpeg,image/webp"
          onChange={handleFileChange}
          disabled={disabled || uploading || generating}
          className="sr-only"
        />
        <button
          type="button"
          onClick={() => {
            void handleGenerate();
          }}
          disabled={disabled || uploading || generating || !prompt.trim()}
          className="inline-flex min-h-12 items-center gap-2 rounded-full bg-club-primary px-4 py-3 text-sm font-semibold text-white transition hover:bg-club-secondary disabled:opacity-60"
        >
          <Sparkles size={14} />
          {generating ? "Generating..." : "Generate image"}
        </button>
      </div>

      <label className="grid gap-2 text-sm">
        <span className="text-[var(--admin-text-strong)]">Prompt</span>
        <textarea
          rows={3}
          value={prompt}
          onChange={(event) => setPrompt(event.target.value)}
          disabled={disabled || uploading || generating}
          placeholder={
            promptPlaceholder ??
            "Describe the image you want the admin panel to generate for this entry."
          }
          className="dashboard-input min-h-24 resize-y"
        />
      </label>

      {value ? (
        <div className="overflow-hidden rounded-[20px] border border-border-soft bg-slate-950/40">
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
