import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { serverSupabaseConfig } from "@/lib/config";
import { rejectInsecureMutation, rejectRateLimitedRequest } from "@/lib/security";
import type { GameQuestionDraftGenerationBody } from "@/lib/game-runtime";

export const dynamic = "force-dynamic";

type GenerateQuestionDraftsRouteDependencies = {
  fetcher: typeof fetch;
  rejectInsecureMutation: typeof rejectInsecureMutation;
  rejectRateLimitedRequest: typeof rejectRateLimitedRequest;
  supabaseUrl: string;
  supabaseAnonKey: string;
};

function defaultDependencies(): GenerateQuestionDraftsRouteDependencies {
  return {
    fetcher: fetch,
    rejectInsecureMutation,
    rejectRateLimitedRequest,
    supabaseUrl: serverSupabaseConfig.url,
    supabaseAnonKey: serverSupabaseConfig.anonKey,
  };
}

function isSource(value: unknown) {
  if (value == null || typeof value !== "object") return false;
  const source = value as Record<string, unknown>;
  const title = source.source_title ?? source.title;
  const fact = source.extracted_fact ?? source.fact ?? source.summary;
  return (
    typeof title === "string" &&
    title.trim().length > 0 &&
    typeof fact === "string" &&
    fact.trim().length > 0 &&
    (source.source_url == null || typeof source.source_url === "string") &&
    (source.url == null || typeof source.url === "string") &&
    (source.source_date == null || typeof source.source_date === "string") &&
    (source.date == null || typeof source.date === "string") &&
    (source.trust_tier == null || typeof source.trust_tier === "string")
  );
}

function isValidBody(value: unknown): value is GameQuestionDraftGenerationBody {
  if (value == null || typeof value !== "object") return false;
  const body = value as Record<string, unknown>;
  return (
    typeof body.club_id === "number" &&
    Number.isFinite(body.club_id) &&
    isSource(body.source) &&
    (body.count == null ||
      (typeof body.count === "number" &&
        Number.isFinite(body.count) &&
        body.count > 0 &&
        body.count <= 10)) &&
    (body.language == null || typeof body.language === "string") &&
    (body.category == null || typeof body.category === "string") &&
    (body.model == null || typeof body.model === "string") &&
    (body.drafts == null || Array.isArray(body.drafts))
  );
}

function authHeaders(request: NextRequest, anonKey: string) {
  const authorization = request.headers.get("authorization");
  const headers: Record<string, string> = {
    apikey: anonKey,
    "Content-Type": "application/json",
  };
  if (authorization) {
    headers.Authorization = authorization;
  }
  return headers;
}

export function createGenerateQuestionDraftsRouteHandler(
  partialDependencies: Partial<GenerateQuestionDraftsRouteDependencies> = {},
) {
  const deps = {
    ...defaultDependencies(),
    ...partialDependencies,
  };

  return async function postGenerateQuestionDrafts(request: NextRequest) {
    const rejectedOrigin = deps.rejectInsecureMutation(request);
    if (rejectedOrigin) {
      return rejectedOrigin;
    }

    const rejectedLimit = await deps.rejectRateLimitedRequest(
      request,
      "generate-question-drafts",
      24,
      60_000,
    );
    if (rejectedLimit) {
      return rejectedLimit;
    }

    const body = await request.json().catch(() => null);
    if (!isValidBody(body)) {
      return NextResponse.json(
        { error: "Invalid question draft generation payload." },
        { status: 400 },
      );
    }

    if (!deps.supabaseUrl || !deps.supabaseAnonKey) {
      return NextResponse.json(
        { error: "Supabase server configuration is not available." },
        { status: 503 },
      );
    }

    const upstream = await deps.fetcher(
      `${deps.supabaseUrl}/functions/v1/generate-question-drafts`,
      {
        method: "POST",
        headers: authHeaders(request, deps.supabaseAnonKey),
        body: JSON.stringify(body),
        cache: "no-store",
      },
    );

    const responseText = await upstream.text();
    const contentType =
      upstream.headers.get("content-type") ?? "application/json";

    return new NextResponse(responseText, {
      status: upstream.status,
      headers: {
        "Content-Type": contentType,
        "Cache-Control": "no-store",
      },
    });
  };
}

export const POST = createGenerateQuestionDraftsRouteHandler();
