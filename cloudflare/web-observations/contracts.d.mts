export type WebVitalName = "CLS" | "FCP" | "INP" | "LCP" | "TTFB";
export type WebVitalObservation = Readonly<{schemaVersion:1;event:"web_vital";name:WebVitalName;
 value:number;rating:"good"|"needs-improvement"|"poor"}>;
export type PwaObservation = Readonly<{schemaVersion:1;event:"pwa_event";eventType:string;
 surface:string;displayMode:string}>;
export type WebObservation = WebVitalObservation | PwaObservation;
export const VITAL_NAMES: readonly WebVitalName[];
export const PWA_EVENTS: readonly string[];
export function projectWebVital(value: unknown): WebVitalObservation | null;
export function projectPwaEvent(value: unknown): PwaObservation | null;
export function normalizeObservation(value: unknown): WebObservation | null;
export function parseObservationJson(raw: unknown): WebObservation | null;
export function observationConfiguration(env: unknown, store?:boolean): Readonly<{
 origin:string;clubId:number;retentionMs:number;policyRef:string}> | null;
