"use client";

import { ScanFace, Nfc, QrCode, ScanLine } from "lucide-react";
import { SectionHeading } from "@/components/section-heading";

/**
 * BioPay hub — matches the Flutter native app's 2×2 payment method grid.
 *
 * Flutter source: packages/features/feat_biopay/lib/src/screens/biopay_screen.dart
 * Methods: Face Scan, NFC Tap, Get QR, Scan QR
 *
 * On web, biometric face scan and NFC are not available.
 * This page explains BioPay and guides users to the native app.
 */

const methods = [
  {
    icon: ScanFace,
    label: "Face Scan",
    color: "text-blue-400",
    bgColor: "bg-blue-500/12 border-blue-500/25",
    available: false,
    description: "Pay with your face at supported venues.",
  },
  {
    icon: Nfc,
    label: "NFC Tap",
    color: "text-violet-400",
    bgColor: "bg-violet-500/12 border-violet-500/25",
    available: false,
    description: "Tap your phone to pay at the gate.",
  },
  {
    icon: QrCode,
    label: "Get QR",
    color: "text-amber-400",
    bgColor: "bg-amber-500/12 border-amber-500/25",
    available: true,
    description: "Generate a payment QR for vendors to scan.",
  },
  {
    icon: ScanLine,
    label: "Scan QR",
    color: "text-teal-400",
    bgColor: "bg-teal-500/12 border-teal-500/25",
    available: true,
    description: "Scan a vendor QR to complete payment.",
  },
] as const;

export default function FanBioPayPage() {
  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="BioPay"
        title="How you want to pay today."
        description="Biometric, NFC, and QR payments tied to your supporter identity."
      />

      <div className="grid gap-4 sm:grid-cols-2">
        {methods.map((method) => {
          const Icon = method.icon;

          return (
            <div
              key={method.label}
              className={`glass-panel relative overflow-hidden rounded-[28px] border p-6 transition ${
                method.available
                  ? "card-interactive cursor-pointer"
                  : "opacity-60"
              } ${method.bgColor}`}
            >
              {!method.available ? (
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
          Pay without reaching for your wallet.
        </p>
        <p className="mt-4 max-w-2xl text-sm leading-7 text-slate-300">
          BioPay links your supporter identity to biometric and contactless
          payment. Enrol in the native app, then pay at gates and vendor stalls
          with a glance or tap.
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
