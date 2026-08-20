"use client";

import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { ui } from "@/ui-kit";
import { useVenueOnline } from "../../_components/venue-shell-client";

type DetectorResult = { rawValue?: string };
type Detector = { detect(source: HTMLVideoElement): Promise<DetectorResult[]> };
type DetectorConstructor = new (options: { formats: string[] }) => Detector;

type VerificationResult = {
  status?: string;
  code?: string;
  ticket_number?: string;
  seat_type?: string;
  gate_code?: string | null;
  first_admitted_at?: string | null;
};

type ViewState =
  | { kind: "idle" }
  | { kind: "starting" }
  | { kind: "scanning" }
  | { kind: "submitting" }
  | { kind: "admitted"; result: VerificationResult }
  | { kind: "rejected"; result: VerificationResult }
  | { kind: "error"; message: string };

const resultCopy: Record<string, string> = {
  already_used: "Ticket already used",
  pending_payment: "Payment is not confirmed",
  cancelled: "Ticket cancelled",
  refunded: "Ticket refunded",
  voided: "Ticket voided",
  expired: "Entry window closed",
  outside_window: "Entry window not open",
  wrong_gate: "Ticket belongs at another assigned gate",
  permission_denied: "You are not assigned to verify this event",
  credential_inactive: "Ticket credential is no longer active",
};

function resultTitle(result: VerificationResult) {
  if (result.status === "admitted") return "Admit supporter";
  return resultCopy[result.code ?? ""] ?? "Do not admit";
}

export function TicketVerifier({ gates }: { gates: Array<string | null> }) {
  const online = useVenueOnline();
  const videoRef = useRef<HTMLVideoElement>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const frameRef = useRef<number | null>(null);
  const detectingRef = useRef(false);
  const [state, setState] = useState<ViewState>({ kind: "idle" });
  const [manualCode, setManualCode] = useState("");
  const [gateCode, setGateCode] = useState<string | null>(gates[0] ?? null);

  const cameraSupported = useMemo(() => {
    if (typeof window === "undefined") return false;
    const detector = (window as unknown as { BarcodeDetector?: DetectorConstructor })
      .BarcodeDetector;
    return detector != null && navigator.mediaDevices?.getUserMedia != null;
  }, []);

  const stopCamera = useCallback(() => {
    if (frameRef.current != null) cancelAnimationFrame(frameRef.current);
    frameRef.current = null;
    detectingRef.current = false;
    for (const track of streamRef.current?.getTracks() ?? []) track.stop();
    streamRef.current = null;
    if (videoRef.current != null) videoRef.current.srcObject = null;
  }, []);

  useEffect(() => stopCamera, [stopCamera]);

  const submitCode = useCallback(async (ticketCode: string) => {
    const normalized = ticketCode.trim();
    if (!online) {
      setState({ kind: "error", message: "Reconnect before verifying a ticket." });
      return;
    }
    if (normalized.length < 20) {
      setState({ kind: "error", message: "Scan or enter a complete ticket code." });
      return;
    }
    stopCamera();
    setState({ kind: "submitting" });
    try {
      const response = await fetch("/api/venue/tickets/verify", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-africlub-csrf": "1",
        },
        body: JSON.stringify({
          ticket_code: normalized,
          operation_id: crypto.randomUUID(),
          gate_code: gateCode,
        }),
        cache: "no-store",
      });
      const payload = await response.json().catch(() => null) as
        | { data?: { result?: VerificationResult }; error?: string }
        | null;
      if (!response.ok || payload?.data?.result == null) {
        throw new Error(
          response.status === 409
            ? "The rotating code expired. Scan the current code again."
            : payload?.error ?? "Ticket verification could not be completed.",
        );
      }
      const result = payload.data.result;
      setState(
        result.status === "admitted"
          ? { kind: "admitted", result }
          : { kind: "rejected", result },
      );
      setManualCode("");
      if (result.status === "admitted") navigator.vibrate?.(120);
    } catch (error) {
      setState({
        kind: "error",
        message: error instanceof Error
          ? error.message
          : "Ticket verification could not be completed.",
      });
    }
  }, [gateCode, online, stopCamera]);

  const startCamera = useCallback(async () => {
    if (!cameraSupported) {
      setState({
        kind: "error",
        message: "Camera scanning is unavailable in this browser. Use the code field below.",
      });
      return;
    }
    setState({ kind: "starting" });
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: false,
        video: { facingMode: { ideal: "environment" } },
      });
      streamRef.current = stream;
      const video = videoRef.current;
      if (video == null) throw new Error("Camera preview is unavailable.");
      video.srcObject = stream;
      await video.play();
      const DetectorType = (window as unknown as {
        BarcodeDetector: DetectorConstructor;
      }).BarcodeDetector;
      const detector = new DetectorType({ formats: ["qr_code"] });
      setState({ kind: "scanning" });
      let lastDetectionAt = 0;
      const scan = async (timestamp: number) => {
        if (streamRef.current == null) return;
        if (!detectingRef.current && timestamp - lastDetectionAt >= 180) {
          lastDetectionAt = timestamp;
          detectingRef.current = true;
          try {
            const values = await detector.detect(video);
            const code = values.find((value) => value.rawValue?.trim())?.rawValue;
            if (code) {
              await submitCode(code);
              return;
            }
          } catch {
            stopCamera();
            setState({
              kind: "error",
              message: "Camera scanning stopped. Start it again or use the code field.",
            });
            return;
          } finally {
            detectingRef.current = false;
          }
        }
        frameRef.current = requestAnimationFrame(scan);
      };
      frameRef.current = requestAnimationFrame(scan);
    } catch {
      stopCamera();
      setState({
        kind: "error",
        message:
          "Camera access was not granted or is unavailable. Use the code field below.",
      });
    }
  }, [cameraSupported, stopCamera, submitCode]);

  const busy = state.kind === "starting" || state.kind === "submitting";
  const result = state.kind === "admitted" || state.kind === "rejected"
    ? state.result
    : null;

  return (
    <div className="grid gap-6 lg:grid-cols-[minmax(0,1.35fr)_minmax(19rem,0.65fr)]">
      <section className={`${ui.panelElevated} rounded-lg p-5`}>
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <p className={ui.kicker}>Live camera</p>
            <h2 className="mt-2 text-2xl font-bold uppercase">Scan rotating QR</h2>
          </div>
          {state.kind === "scanning" ? (
            <button className={ui.buttonSecondary} type="button" onClick={() => {
              stopCamera();
              setState({ kind: "idle" });
            }}>
              Stop camera
            </button>
          ) : (
            <button
              className={ui.buttonPrimary}
              type="button"
              disabled={!online || busy}
              onClick={startCamera}
            >
              {state.kind === "starting" ? "Starting camera…" : "Start camera"}
            </button>
          )}
        </div>

        <div className="mt-5 aspect-[4/3] overflow-hidden rounded-lg border border-white/10 bg-black">
          <video
            ref={videoRef}
            className="h-full w-full object-cover"
            muted
            playsInline
            aria-label="Ticket QR camera preview"
          />
        </div>
        <p className="mt-3 text-sm leading-6 text-slate-300">
          The camera starts only after you select the button. Codes are checked
          online against your current event, venue, gate, and shift assignment.
        </p>
      </section>

      <aside className="grid content-start gap-5">
        <section className={`${ui.panel} rounded-lg p-5`}>
          <label className="text-sm font-bold uppercase" htmlFor="ticket-gate">
            Active gate
          </label>
          <select
            id="ticket-gate"
            className={`${ui.input} mt-3 w-full`}
            value={gateCode ?? ""}
            onChange={(event) => setGateCode(event.target.value || null)}
          >
            {gates.map((gate) => (
              <option key={gate ?? "all-assigned"} value={gate ?? ""}>
                {gate ?? "All assigned gates"}
              </option>
            ))}
          </select>

          <label className="mt-5 block text-sm font-bold uppercase" htmlFor="ticket-code">
            External scanner or code
          </label>
          <textarea
            id="ticket-code"
            className={`${ui.input} mt-3 min-h-28 w-full font-mono text-xs`}
            value={manualCode}
            maxLength={180}
            autoCapitalize="none"
            autoCorrect="off"
            spellCheck={false}
            onChange={(event) => setManualCode(event.target.value)}
            placeholder="Scan with a connected reader or paste the rotating code"
          />
          <button
            type="button"
            className={`${ui.buttonSecondary} mt-3 w-full justify-center`}
            disabled={!online || busy || manualCode.trim().length < 20}
            onClick={() => submitCode(manualCode)}
          >
            {state.kind === "submitting" ? "Checking ticket…" : "Verify code"}
          </button>
        </section>

        <section
          className={`${ui.panelElevated} rounded-lg border p-5 ${
            state.kind === "admitted"
              ? "border-emerald-400/70 bg-emerald-950/50"
              : state.kind === "rejected" || state.kind === "error"
                ? "border-red-400/60 bg-red-950/40"
                : "border-white/10"
          }`}
          role="status"
          aria-live="assertive"
        >
          <p className={ui.kicker}>Verification result</p>
          <h2 className="mt-2 text-2xl font-bold uppercase">
            {result != null
              ? resultTitle(result)
              : state.kind === "error"
                ? "Check not completed"
                : state.kind === "submitting"
                  ? "Checking authoritative ticket…"
                  : "Ready for next ticket"}
          </h2>
          {state.kind === "error" ? (
            <p className="mt-3 text-sm leading-6 text-red-100">{state.message}</p>
          ) : result != null ? (
            <dl className="mt-4 grid gap-3 text-sm">
              {result.ticket_number ? (
                <div>
                  <dt className="text-slate-400">Ticket</dt>
                  <dd className="font-mono font-bold">{result.ticket_number}</dd>
                </div>
              ) : null}
              {result.seat_type ? (
                <div>
                  <dt className="text-slate-400">Admission type</dt>
                  <dd className="font-bold uppercase">{result.seat_type}</dd>
                </div>
              ) : null}
              {result.first_admitted_at ? (
                <div>
                  <dt className="text-slate-400">First admitted</dt>
                  <dd>{new Date(result.first_admitted_at).toLocaleString()}</dd>
                </div>
              ) : null}
            </dl>
          ) : (
            <p className="mt-3 text-sm leading-6 text-slate-300">
              A green result is required before admission. An HTTP success alone
              never means the ticket is valid.
            </p>
          )}
          {(state.kind === "admitted" || state.kind === "rejected" || state.kind === "error") ? (
            <button
              className={`${ui.buttonTertiary} mt-5`}
              type="button"
              onClick={() => setState({ kind: "idle" })}
            >
              Clear result
            </button>
          ) : null}
        </section>
      </aside>
    </div>
  );
}
