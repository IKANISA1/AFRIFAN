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

  const disabled = client == null || !access.hasAccess || !access.clubId;

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
          <p className="text-sm font-semibold text-white">{label}</p>
          <p className="text-xs text-slate-400">
            Upload a file or generate one with Gemini Nano Banana. Manual URL entry is disabled.
          </p>
        </div>
        {value ? (
          <button
            type="button"
            onClick={() => onChange("")}
            className="rounded-full border border-border-soft p-2 text-slate-300 transition hover:bg-white/8"
            title="Remove image"
          >
            <Trash2 size={14} />
          </button>
        ) : null}
      </div>

      <div className="flex flex-wrap gap-3">
        <label
          htmlFor={inputId}
          className="inline-flex cursor-pointer items-center gap-2 rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-100 transition hover:bg-white/8"
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
          className="inline-flex items-center gap-2 rounded-full bg-club-primary px-4 py-2 text-sm font-semibold text-white transition hover:bg-club-secondary disabled:opacity-60"
        >
          <Sparkles size={14} />
          {generating ? "Generating..." : "Generate image"}
        </button>
      </div>

      <label className="grid gap-2 text-sm">
        <span className="text-slate-200">Prompt</span>
        <textarea
          rows={3}
          value={prompt}
          onChange={(event) => setPrompt(event.target.value)}
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
        <div className="flex min-h-32 items-center justify-center rounded-[20px] border border-dashed border-border-soft bg-slate-950/30 text-sm text-slate-500">
          <span className="inline-flex items-center gap-2">
            <ImagePlus size={16} />
            No image selected
          </span>
        </div>
      )}
    </div>
  );
}
