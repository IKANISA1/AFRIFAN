import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { HttpError, requireClubAdminCaller } from "../_shared/auth.ts";
import {
  corsPreflightResponse,
  jsonError,
  jsonOk,
} from "../_shared/response.ts";
import { createAdminClient } from "../_shared/supabase.ts";

type DraftOption = {
  key: string;
  label: string;
};

type DraftInput = {
  prompt?: unknown;
  options?: unknown;
  correct_option_key?: unknown;
  explanation?: unknown;
  category?: unknown;
  difficulty?: unknown;
  language?: unknown;
};

type QuestionDraftPayload = {
  drafts: DraftInput[];
  source_notes: string[];
};

type GenerateDraftRequest = {
  club_id?: unknown;
  source?: unknown;
  drafts?: unknown;
  count?: unknown;
  language?: unknown;
  category?: unknown;
  model?: unknown;
};

type NormalizedSource = {
  source_url: string | null;
  source_title: string;
  source_date: string | null;
  extracted_fact: string;
  trust_tier: "official" | "trusted_media" | "academic" | "venue_supplied" | "review_required";
};

type NormalizedDraft = {
  prompt: string;
  options: DraftOption[];
  correct_option_key: string;
  explanation: string;
  category: string;
  difficulty: "easy" | "medium" | "hard";
  language: string;
};

type Dependencies = {
  createAdminClient: typeof createAdminClient;
  fetch: typeof fetch;
  requireClubAdminCaller: typeof requireClubAdminCaller;
};

const defaultDependencies: Dependencies = {
  createAdminClient,
  fetch,
  requireClubAdminCaller,
};

const questionDraftSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    drafts: {
      type: "array",
      minItems: 1,
      maxItems: 10,
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          prompt: { type: "string" },
          options: {
            type: "array",
            minItems: 2,
            maxItems: 6,
            items: {
              type: "object",
              additionalProperties: false,
              properties: {
                key: { type: "string" },
                label: { type: "string" },
              },
              required: ["key", "label"],
            },
          },
          correct_option_key: { type: "string" },
          explanation: { type: "string" },
          category: { type: "string" },
          difficulty: { type: "string", enum: ["easy", "medium", "hard"] },
          language: { type: "string" },
        },
        required: [
          "prompt",
          "options",
          "correct_option_key",
          "explanation",
          "category",
          "difficulty",
          "language",
        ],
      },
    },
    source_notes: { type: "array", items: { type: "string" } },
  },
  required: ["drafts", "source_notes"],
};

export function createGenerateQuestionDraftsHandler(
  dependencies: Partial<Dependencies> = {},
) {
  const deps: Dependencies = { ...defaultDependencies, ...dependencies };

  return async (request: Request) => {
    if (request.method === "OPTIONS") return corsPreflightResponse();
    if (request.method === "GET") {
      return jsonOk({ success: true, function: "generate-question-drafts" });
    }
    if (request.method !== "POST") return jsonError("Method not allowed", 405);

    try {
      const body = await readJsonBody(request);
      const clubId = requirePositiveInteger(body.club_id, "club_id");
      await deps.requireClubAdminCaller(request, clubId);

      const source = normalizeSource(body.source);
      const requestedCount = clamp(
        parsePositiveInteger(body.count) ?? 5,
        1,
        10,
      );
      const language = asTrimmedString(body.language) || "en";
      const category = asTrimmedString(body.category) || "club_knowledge";
      const model = asTrimmedString(body.model) ||
        Deno.env.get("OPENAI_QUESTION_DRAFT_MODEL")?.trim() ||
        "gpt-4.1-mini";

      const explicitDrafts = Array.isArray(body.drafts)
        ? body.drafts as DraftInput[]
        : [];
      const aiMode = explicitDrafts.length === 0;
      const draftPayload = aiMode
        ? await collectDraftsWithOpenAi(
          deps.fetch,
          source,
          requestedCount,
          language,
          category,
          model,
        )
        : {
          drafts: explicitDrafts,
          source_notes: ["Manual draft payload supplied by club admin."],
        };

      const normalizedDrafts = draftPayload.drafts
        .map((draft) => normalizeDraft(draft, { language, category }))
        .filter((draft): draft is NormalizedDraft => draft != null)
        .slice(0, requestedCount);

      if (normalizedDrafts.length === 0) {
        throw new HttpError(400, "No valid question drafts were produced.");
      }

      const adminClient = deps.createAdminClient().schema("africlub_game");
      const { data: sourceRow, error: sourceError } = await adminClient
        .from("question_sources")
        .insert({
          club_id: clubId,
          source_url: source.source_url,
          source_title: source.source_title,
          source_date: source.source_date,
          extracted_fact: source.extracted_fact,
          trust_tier: source.trust_tier,
          metadata: {
            generation_mode: aiMode ? "ai_assisted" : "manual_import",
            source_notes: draftPayload.source_notes,
          },
        })
        .select("id")
        .single();

      if (sourceError) throw new Error(sourceError.message);
      const sourceId = String(sourceRow.id);

      const { data: draftRows, error: draftError } = await adminClient
        .from("question_drafts")
        .insert(normalizedDrafts.map((draft) => ({
          club_id: clubId,
          source_id: sourceId,
          prompt: draft.prompt,
          options: draft.options,
          correct_option_key: draft.correct_option_key,
          explanation: draft.explanation,
          category: draft.category,
          difficulty: draft.difficulty,
          language: draft.language,
          model_name: aiMode ? model : null,
          validation_status: "pending_review",
          validation_notes: "Awaiting human review.",
          metadata: {
            generation_mode: aiMode ? "ai_assisted" : "manual_import",
          },
        })))
        .select("id");

      if (draftError) throw new Error(draftError.message);

      return jsonOk({
        success: true,
        data: {
          sourceId,
          draftIds: (draftRows ?? []).map((row) => String(row.id)),
          mode: aiMode ? "ai_assisted" : "manual_import",
          count: normalizedDrafts.length,
        },
      });
    } catch (error) {
      const status = error instanceof HttpError ? error.status : 500;
      console.error("generate-question-drafts failed:", error);
      return jsonError(messageOf(error), status);
    }
  };
}

async function readJsonBody(request: Request): Promise<GenerateDraftRequest> {
  try {
    return await request.json() as GenerateDraftRequest;
  } catch (_) {
    return {};
  }
}

function normalizeSource(value: unknown): NormalizedSource {
  if (value == null || typeof value !== "object") {
    throw new HttpError(400, "source is required.");
  }
  const source = value as Record<string, unknown>;
  const sourceTitle = asTrimmedString(source.source_title ?? source.title);
  const extractedFact = asTrimmedString(
    source.extracted_fact ?? source.fact ?? source.summary,
  );
  if (!sourceTitle || !extractedFact) {
    throw new HttpError(400, "source_title and extracted_fact are required.");
  }

  const trustTier = asTrustTier(source.trust_tier ?? source.trustTier);
  return {
    source_url: asTrimmedString(source.source_url ?? source.url) || null,
    source_title: sourceTitle,
    source_date: normalizeDate(source.source_date ?? source.date),
    extracted_fact: extractedFact,
    trust_tier: trustTier,
  };
}

async function collectDraftsWithOpenAi(
  fetchFn: typeof fetch,
  source: NormalizedSource,
  count: number,
  language: string,
  category: string,
  model: string,
): Promise<QuestionDraftPayload> {
  const apiKey = Deno.env.get("OPENAI_API_KEY")?.trim();
  if (!apiKey) {
    throw new HttpError(
      503,
      "OPENAI_API_KEY is not configured. Provide manual drafts or configure the AI draft provider.",
    );
  }

  const response = await fetchFn("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      max_output_tokens: 3500,
      input: buildDraftPrompt(source, count, language, category),
      text: {
        format: {
          type: "json_schema",
          name: "africlub_question_drafts",
          schema: questionDraftSchema,
          strict: true,
        },
      },
      metadata: {
        product: "africlub",
        workflow: "game_question_drafts",
      },
    }),
  });

  const responseBody = await response.json();
  if (!response.ok) {
    throw new Error(
      `AI draft generation failed with ${response.status}: ${truncateForLog(JSON.stringify(responseBody))}`,
    );
  }

  return JSON.parse(extractOpenAiText(responseBody)) as QuestionDraftPayload;
}

function buildDraftPrompt(
  source: NormalizedSource,
  count: number,
  language: string,
  category: string,
) {
  return [
    "Create AFRICLUB matchday quiz draft questions for a club-admin moderation queue.",
    "Use only the provided source fact. Do not invent records, dates, scores, names, or venues.",
    "Keep every draft entertainment-only and points-based. Avoid financial-value framing.",
    "Each question must have 2 to 6 options and exactly one correct option key.",
    "The correct option key must match one option key exactly.",
    "Return concise explanations that cite the provided fact, not external knowledge.",
    `Draft count: ${count}.`,
    `Language: ${language}.`,
    `Default category: ${category}.`,
    "",
    `Source title: ${source.source_title}`,
    `Source URL: ${source.source_url ?? "none"}`,
    `Source date: ${source.source_date ?? "unknown"}`,
    `Trust tier: ${source.trust_tier}`,
    `Fact: ${source.extracted_fact}`,
  ].join("\n");
}

function normalizeDraft(
  value: DraftInput,
  defaults: { language: string; category: string },
): NormalizedDraft | null {
  if (value == null || typeof value !== "object") return null;
  const prompt = asTrimmedString(value.prompt);
  const options = normalizeOptions(value.options);
  const correctOptionKey = asTrimmedString(value.correct_option_key)
    .toLowerCase();
  const explanation = asTrimmedString(value.explanation);
  const category = asTrimmedString(value.category) || defaults.category;
  const language = asTrimmedString(value.language) || defaults.language;
  const difficulty = asDifficulty(value.difficulty);

  if (!prompt || !explanation || options.length < 2 || options.length > 6) {
    return null;
  }
  if (!options.some((option) => option.key === correctOptionKey)) {
    return null;
  }

  return {
    prompt,
    options,
    correct_option_key: correctOptionKey,
    explanation,
    category,
    difficulty,
    language,
  };
}

function normalizeOptions(value: unknown): DraftOption[] {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  const options: DraftOption[] = [];
  for (const item of value) {
    if (item == null || typeof item !== "object") continue;
    const record = item as Record<string, unknown>;
    const key = asTrimmedString(record.key).toLowerCase();
    const label = asTrimmedString(record.label);
    if (!key || !label || seen.has(key)) continue;
    seen.add(key);
    options.push({ key, label });
  }
  return options;
}

function extractOpenAiText(responseBody: unknown): string {
  const body = responseBody as Record<string, unknown>;
  const outputText = body.output_text;
  if (typeof outputText === "string" && outputText.trim()) return outputText;

  const output = Array.isArray(body.output) ? body.output : [];
  for (const item of output) {
    const content = (item as Record<string, unknown>)?.content;
    if (!Array.isArray(content)) continue;
    for (const part of content) {
      const text = (part as Record<string, unknown>)?.text;
      if (typeof text === "string" && text.trim()) return text;
    }
  }

  throw new Error("AI response did not include draft JSON.");
}

function asTrimmedString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asDifficulty(value: unknown): "easy" | "medium" | "hard" {
  const normalized = asTrimmedString(value).toLowerCase();
  return normalized === "easy" || normalized === "hard" ? normalized : "medium";
}

function asTrustTier(value: unknown): NormalizedSource["trust_tier"] {
  const normalized = asTrimmedString(value).toLowerCase();
  if (
    normalized === "official" ||
    normalized === "trusted_media" ||
    normalized === "academic" ||
    normalized === "venue_supplied"
  ) {
    return normalized;
  }
  return "review_required";
}

function normalizeDate(value: unknown): string | null {
  const raw = asTrimmedString(value);
  if (!raw) return null;
  return /^\d{4}-\d{2}-\d{2}$/.test(raw) ? raw : null;
}

function parsePositiveInteger(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    const integer = Math.trunc(value);
    return integer > 0 ? integer : null;
  }
  if (typeof value === "string") {
    const parsed = Number.parseInt(value.trim(), 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
  }
  return null;
}

function requirePositiveInteger(value: unknown, field: string): number {
  const parsed = parsePositiveInteger(value);
  if (parsed == null) throw new HttpError(400, `${field} must be a positive integer.`);
  return parsed;
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function truncateForLog(value: string, max = 1200) {
  return value.length > max ? `${value.slice(0, max)}...` : value;
}

function messageOf(error: unknown) {
  return error instanceof Error ? error.message : "Unexpected error.";
}

Deno.serve(createGenerateQuestionDraftsHandler());
