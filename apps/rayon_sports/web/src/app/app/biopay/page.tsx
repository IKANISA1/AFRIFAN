"use client";

import { useEffect, useState } from "react";
import { ScanFace, Nfc, QrCode, ScanLine } from "lucide-react";
import { SectionHeading } from "@/components/section-heading";
import { getBrowserSupabase } from "@/lib/supabase/browser";

/**
 * BioPay hub — matches the Flutter native app's 2×2 payment method grid.
 *
 * Method availability is driven by app_config keys:
 *   biopay_face_enabled, biopay_nfc_enabled, biopay_qr_enabled, biopay_scan_enabled
 *
 * About section copy comes from ai_content (content_type = biopay_info).
 */

interface MethodDef {
  key: string;
  icon: typeof ScanFace;
  label: string;
  color: string;
  bgColor: string;
  defaultAvailable: boolean;
  description: string;
}

const methodDefs: MethodDef[] = [
  {
    key: "biopay_face_enabled",
    icon: ScanFace,
    label: "Face Scan",
    color: "text-blue-400",
    bgColor: "bg-blue-500/12 border-blue-500/25",
    defaultAvailable: false,
    description: "Pay with your face at supported venues.",
  },
  {
    key: "biopay_nfc_enabled",
    icon: Nfc,
    label: "NFC Tap",
    color: "text-violet-400",
    bgColor: "bg-violet-500/12 border-violet-500/25",
    defaultAvailable: false,
    description: "Tap your phone to pay at the gate.",
  },
  {
    key: "biopay_qr_enabled",
    icon: QrCode,
    label: "Get QR",
    color: "text-amber-400",
    bgColor: "bg-amber-500/12 border-amber-500/25",
    defaultAvailable: true,
    description: "Generate a payment QR for vendors to scan.",
  },
  {
    key: "biopay_scan_enabled",
    icon: ScanLine,
    label: "Scan QR",
    color: "text-teal-400",
    bgColor: "bg-teal-500/12 border-teal-500/25",
    defaultAvailable: true,
    description: "Scan a vendor QR to complete payment.",
  },
];

const defaultAbout = {
  title: "Pay without reaching for your wallet.",
  body: "BioPay links your supporter identity to biometric and contactless payment. Enrol in the native app, then pay at gates and vendor stalls with a glance or tap.",
};

export default function FanBioPayPage() {
  const [config, setConfig] = useState<Record<string, string>>({});
  const [about, setAbout] = useState(defaultAbout);

  useEffect(() => {
    const client = getBrowserSupabase();
    if (!client) return;

    // Load config flags
    client
      .from("app_config")
      .select("key, value")
      .like("key", "biopay_%")
      .then(({ data }: { data: Array<{ key: string; value: string }> | null }) => {
        if (data) {
          const map: Record<string, string> = {};
          for (const row of data) map[String(row.key)] = String(row.value);
          setConfig(map);
        }
      });

    // Load about section copy
    client
      .from("ai_content")
      .select("title, body")
      .eq("content_type", "biopay_info")
      .eq("is_active", true)
      .limit(1)
      .maybeSingle()
      .then(({ data }: { data: { title: string; body: string } | null }) => {
        if (data?.title) {
          setAbout({
            title: String(data.title),
            body: String(data.body ?? defaultAbout.body),
          });
        }
      });
  }, []);

  function isAvailable(method: MethodDef): boolean {
    const val = config[method.key];
    if (val === undefined) return method.defaultAvailable;
    return val === "true";
  }

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="BioPay"
        title="How you want to pay today."
        description="Biometric, NFC, and QR payments tied to your supporter identity."
      />

      <div className="grid gap-4 sm:grid-cols-2">
        {methodDefs.map((method) => {
          const Icon = method.icon;
          const available = isAvailable(method);

          return (
            <div
              key={method.label}
              className={`glass-panel relative overflow-hidden rounded-[28px] border p-6 transition ${
                available
                  ? "card-interactive cursor-pointer"
                  : "opacity-60"
              } ${method.bgColor}`}
            >
              {!available ? (
                <span className="absolute top-4 right-4 rounded-full border border-border-soft bg-black/30 px-3 py-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-slate-300">
                  Native app only
                </span>
              ) : null}
              <div className="flex items-center gap-4">
                <div
                  className={`flex h-14 w-14 items-center justify-center rounded-[18px] border border-border-soft bg-black/20 ${method.color}`}
                >
                  <Icon size={28} />
                </div>
                <div>
                  <p className="font-display text-2xl font-bold uppercase text-white">
                    {method.label}
                  </p>
                  <p className="mt-1 text-sm leading-6 text-slate-300">
                    {method.description}
                  </p>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      <div className="glass-panel rounded-[28px] p-6">
        <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
          About BioPay
        </p>
        <p className="mt-4 font-display text-3xl font-bold uppercase leading-none text-white">
          {about.title}
        </p>
        <p className="mt-4 max-w-2xl text-sm leading-7 text-slate-300">
          {about.body}
        </p>
        <div className="mt-6 grid gap-3 sm:grid-cols-3">
          <div className="rounded-[22px] border border-border-soft bg-white/5 px-4 py-4">
            <p className="text-[11px] uppercase tracking-[0.2em] text-slate-300">
              Enrolled
            </p>
            <p className="mt-2 font-display text-2xl font-bold uppercase text-white">
              —
            </p>
          </div>
          <div className="rounded-[22px] border border-border-soft bg-white/5 px-4 py-4">
            <p className="text-[11px] uppercase tracking-[0.2em] text-slate-300">
              Transactions
            </p>
            <p className="mt-2 font-display text-2xl font-bold uppercase text-white">
              —
            </p>
          </div>
          <div className="rounded-[22px] border border-border-soft bg-white/5 px-4 py-4">
            <p className="text-[11px] uppercase tracking-[0.2em] text-slate-300">
              Status
            </p>
            <p className="mt-2 font-display text-2xl font-bold uppercase text-white">
              Pending
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
