import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  corsPreflightResponse,
  corsHeaders,
  jsonOk,
  jsonError,
} from "../_shared/response.ts";
import { validateRequest, isErrorResponse } from "../_shared/validation.ts";
import {
  recordEdgeFunctionFailure,
  recordOperationalHealthEvent,
} from "../_shared/observability.ts";
import { createAdminClient } from "../_shared/supabase.ts";
import { enforceRateLimit } from "../_shared/rate_limit.ts";
import {
  type AiProvider,
  buildPrompt,
  callGemini,
  callOpenAi,
  getAiProvider,
  getModel,
  normalizeParsedSms,
  type RawSmsRecord,
} from "./ai_parser.ts";
import {
  buildManualReviewResult,
  ledgerEntryType,
  reconcileParsedSms,
} from "./reconciliation.ts";

type ParseRequest = {
  rawSmsId?: string;
  forceReparse?: boolean;
  provider?: "openai" | "gemini";
};

const PROMPT_VERSION = "v1";

function asString(value: unknown): string | null {
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : null;
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  return null;
}

function deriveLedgerScope(
  targetTable: string | null,
): "wallet" | "group" | "partner" {
  switch (targetTable) {
    case "group_contributions":
      return "group";
    case "partner_payment_routes":
    case "rs_tickets":
    case "rs_shop_orders":
    case "rs_initiative_contributions":
      return "partner";
    default:
      return "wallet";
  }
}

export async function handleRequest(request: Request) {
  if (request.method === "OPTIONS") {
    return corsPreflightResponse();
  }

  if (request.method !== "POST") {
    return jsonError("Method not allowed", 405);
  }

  const validated = await validateRequest(request);
  if (isErrorResponse(validated)) return validated;
  const { userId } = validated;

  try {
    const body = await request.json() as ParseRequest;
    const rawSmsId = body.rawSmsId?.trim();
    if (!rawSmsId) {
      return jsonError("rawSmsId is required", 400);
    }

    const adminClient = createAdminClient();

    // Rate limit: max 60 parse requests per 5 minutes per user.
    await enforceRateLimit(adminClient, userId, "parse-momo-sms", {
      maxRequests: 60,
      windowSeconds: 300,
    });

    const rawSmsResult = await adminClient
      .from("momo_sms_raw")
      .select("*")
      .eq("id", rawSmsId)
      .eq("user_id", userId)
      .maybeSingle();

    if (rawSmsResult.error) {
      throw rawSmsResult.error;
    }

    const rawSms = rawSmsResult.data as RawSmsRecord | null;
    if (!rawSms) {
      return jsonError("Raw SMS record not found", 404);
    }

    if (rawSmsResult.data?.parse_status === "parsed" && !body.forceReparse) {
      return jsonOk({
        success: true,
        skipped: true,
        reason: "already_parsed",
        rawSmsId,
      });
    }

    // A parse retry is not a correction to posted financial evidence. Keep
    // its original interpretation and require the separate review workflow.
    const previousParse = await adminClient.from("momo_sms_parsed")
      .select("id").eq("raw_sms_id", rawSmsId).maybeSingle();
    if (previousParse.error) throw previousParse.error;
    if (previousParse.data) {
      const [ledger, reconciliation] = await Promise.all([
        adminClient.from("momo_ledger_entries").select("id")
          .eq("parsed_sms_id", previousParse.data.id)
          .eq("ledger_status", "posted").maybeSingle(),
        adminClient.from("momo_reconciliations").select("id")
          .eq("parsed_sms_id", previousParse.data.id)
          .eq("match_status", "matched").maybeSingle(),
      ]);
      if (ledger.error) throw ledger.error;
      if (reconciliation.error) throw reconciliation.error;
      if (ledger.data || reconciliation.data) {
        return jsonError("Reconciled payment evidence cannot be reparsed.", 409);
      }
    }

    const prompt = buildPrompt(rawSms);

    // The original version must still own this attempt. In particular, a
    // force request cannot overtake a running parse or a just-finished parse.
    const claim = await adminClient
      .from("momo_sms_raw")
      .update({ parse_status: "processing", updated_at: new Date().toISOString() })
      .eq("id", rawSmsId)
      .eq("user_id", userId)
      .eq("parse_status", rawSmsResult.data.parse_status)
      .eq("updated_at", rawSmsResult.data.updated_at)
      .neq("parse_status", "processing")
      .select("id")
      .maybeSingle();
    if (claim.error) throw claim.error;
    if (!claim.data) {
      return jsonError("SMS parsing is in progress or its state changed. Refresh before retrying.", 409);
    }
    const runProviderAttempt = async (provider: AiProvider) => {
      const model = getModel(provider);
      const attemptsResult = await adminClient
        .from("momo_parse_attempts")
        .select("attempt_number")
        .eq("raw_sms_id", rawSmsId)
        .eq("provider", provider);

      if (attemptsResult.error) {
        throw attemptsResult.error;
      }

      const attemptNumber = (attemptsResult.data?.length ?? 0) + 1;
      const attemptInsert = await adminClient
        .from("momo_parse_attempts")
        .insert({
          raw_sms_id: rawSmsId,
          user_id: rawSms.user_id,
          provider,
          model,
          attempt_number: attemptNumber,
          status: "pending",
          prompt_version: PROMPT_VERSION,
        })
        .select("id")
        .single();

      if (attemptInsert.error) {
        throw attemptInsert.error;
      }

      const attemptId = attemptInsert.data.id as string;

      try {
        const aiResult = provider === "gemini"
          ? await callGemini(prompt)
          : await callOpenAi(prompt);

        return {
          attemptId,
          provider,
          aiResult,
          parsed: normalizeParsedSms(
            JSON.parse(aiResult.text) as Record<string, unknown>,
          ),
        };
      } catch (error) {
        await adminClient
          .from("momo_parse_attempts")
          .update({
            status: "failed",
            error_message: error instanceof Error
              ? error.message
              : "AI parse failed",
          })
          .eq("id", attemptId);

        throw error;
      }
    };

    let selectedAttemptId: string | null = null;

    try {
      const primaryProvider = getAiProvider(body.provider);
      const openAiFallbackAvailable = primaryProvider === "gemini" &&
        (Deno.env.get("OPENAI_API_KEY") ?? "").trim().length > 0;

      let selectedAttempt;
      try {
        selectedAttempt = await runProviderAttempt(primaryProvider);
      } catch (primaryError) {
        if (!openAiFallbackAvailable) {
          throw primaryError;
        }

        console.error(
          "parse-momo-sms gemini attempt failed, retrying with OpenAI",
          primaryError,
        );
        selectedAttempt = await runProviderAttempt("openai");
      }

      selectedAttemptId = selectedAttempt.attemptId;
      const { aiResult, parsed, provider } = selectedAttempt;
      const timestamp = new Date().toISOString();

      const parsedUpsert = await adminClient
        .from("momo_sms_parsed")
        .upsert({
          raw_sms_id: rawSms.id,
          user_id: rawSms.user_id,
          country_code: rawSms.country_code ?? null,
          parser_provider: provider,
          parser_model: aiResult.model,
          parse_status: parsed.parse_status,
          confidence: parsed.confidence,
          tx_direction: parsed.tx_direction,
          tx_type: parsed.tx_type,
          tx_category: parsed.tx_category,
          cashflow_bucket: parsed.cashflow_bucket,
          momo_tx_id: parsed.momo_tx_id,
          amount: parsed.amount,
          currency: parsed.currency,
          tx_date: parsed.tx_date,
          tx_time: parsed.tx_time,
          tx_datetime: parsed.tx_datetime_iso,
          payer_name: parsed.payer_name,
          payer_number_last3: parsed.payer_number_last3,
          payer_number_full: parsed.payer_number_full,
          payee_name: parsed.payee_name,
          payee_number_or_code: parsed.payee_number_or_code,
          merchant_code: parsed.merchant_code,
          fee_amount: parsed.fee_amount,
          balance_after: parsed.balance_after,
          counterparty_name: parsed.counterparty_name,
          ai_summary: parsed.ai_summary,
          recurring_pattern_hint: parsed.recurring_pattern_hint,
          narrative: parsed.narrative ?? parsed.notes,
          structured_data: parsed,
          updated_at: timestamp,
        }, { onConflict: "raw_sms_id" })
        .select("id")
        .single();

      if (parsedUpsert.error) {
        throw parsedUpsert.error;
      }

      const parsedSmsId = parsedUpsert.data.id as string;
      let autoReconciliation = parsed.parse_status === "parsed"
        ? buildManualReviewResult(
          "Parsed SMS is ready for review, but auto-reconciliation has not run yet.",
          { reason: "auto_reconciliation_not_attempted" },
        )
        : buildManualReviewResult(
          "Parsed SMS needs manual review before reconciliation.",
          { reason: "parsed_status_requires_review" },
        );

      if (parsed.parse_status === "parsed") {
        try {
          autoReconciliation = await reconcileParsedSms(
            adminClient,
            rawSms,
            parsed,
            parsedSmsId,
            timestamp,
          );
        } catch (reconciliationError) {
          console.error(
            "parse-momo-sms reconciliation failed",
            reconciliationError,
          );
          autoReconciliation = buildManualReviewResult(
            "AI parsing succeeded, but reconciliation failed and needs manual review.",
            {
              reason: "reconciliation_error",
              error: reconciliationError instanceof Error
                ? reconciliationError.message
                : "unknown_reconciliation_error",
            },
          );
        }
      }

      if (
        parsed.amount != null &&
        parsed.amount > 0 &&
        autoReconciliation.matchStatus === "matched"
      ) {
        const payeeGroupId = asString(autoReconciliation.metadata.group_id);
        const payeePartnerId = asString(autoReconciliation.metadata.partner_id);
        const ledgerUpsert = await adminClient
          .from("momo_ledger_entries")
          .upsert({
            parsed_sms_id: parsedSmsId,
            user_id: rawSms.user_id,
            country_code: rawSms.country_code ?? null,
            entry_type: ledgerEntryType(parsed),
            ledger_scope: deriveLedgerScope(autoReconciliation.targetTable),
            ledger_status: autoReconciliation.ledgerStatus,
            amount: parsed.amount,
            currency: parsed.currency,
            tx_datetime: parsed.tx_datetime_iso ?? rawSms.sms_received_at,
            tx_category: parsed.tx_category,
            cashflow_bucket: parsed.cashflow_bucket,
            counterparty_name: parsed.counterparty_name,
            statement_label: parsed.ai_summary ??
              parsed.narrative ??
              `Mobile money ${parsed.tx_type}`,
            external_reference: parsed.momo_tx_id ??
              autoReconciliation.matchedReference,
            target_table: autoReconciliation.targetTable,
            target_record_id: autoReconciliation.targetRecordId,
            payee_group_id: payeeGroupId,
            payee_partner_id: payeePartnerId,
            description: parsed.ai_summary ??
              parsed.narrative ??
              `AI parsed ${parsed.tx_type} from MoMo SMS`,
            metadata: {
              parser_provider: provider,
              parser_model: aiResult.model,
              confidence: parsed.confidence,
              tx_category: parsed.tx_category,
              cashflow_bucket: parsed.cashflow_bucket,
              recurring_pattern_hint: parsed.recurring_pattern_hint,
              source_raw_sms_id: rawSms.id,
              matched_reference: autoReconciliation.matchedReference,
              ...autoReconciliation.metadata,
            },
            updated_at: timestamp,
          }, { onConflict: "parsed_sms_id" });

        if (ledgerUpsert.error) {
          throw ledgerUpsert.error;
        }
      }

      const reconciliationUpsert = await adminClient
        .from("momo_reconciliations")
        .upsert({
          parsed_sms_id: parsedSmsId,
          user_id: rawSms.user_id,
          country_code: rawSms.country_code ?? null,
          target_table: autoReconciliation.targetTable,
          target_record_id: autoReconciliation.targetRecordId,
          match_type: autoReconciliation.matchType,
          match_status: autoReconciliation.matchStatus,
          confidence: parsed.confidence,
          notes: autoReconciliation.notes ?? parsed.notes,
          metadata: {
            parser_provider: provider,
            parser_model: aiResult.model,
            source_raw_sms_id: rawSms.id,
            matched_reference: autoReconciliation.matchedReference,
            ...autoReconciliation.metadata,
          },
          reconciled_at: autoReconciliation.matchStatus === "matched"
            ? timestamp
            : null,
          updated_at: timestamp,
        }, { onConflict: "parsed_sms_id" });

      if (reconciliationUpsert.error) {
        throw reconciliationUpsert.error;
      }

      await adminClient
        .from("momo_parse_attempts")
        .update({
          status: "success",
          request_payload: aiResult.requestPayload,
          response_payload: aiResult.responseBody,
        })
        .eq("id", selectedAttemptId);

      await adminClient
        .from("momo_sms_raw")
        .update({
          parse_status: "parsed",
          updated_at: timestamp,
        })
        .eq("id", rawSmsId);

      await recordOperationalHealthEvent(adminClient, {
        service: "momo_parsing",
        component: "parse-momo-sms",
        status: autoReconciliation.matchStatus === "matched" ? "ok" : "warn",
        severity: autoReconciliation.matchStatus === "matched"
          ? "info"
          : "warning",
        issueCode: autoReconciliation.matchStatus === "matched"
          ? null
          : "payment_requires_review",
        message: autoReconciliation.matchStatus === "matched"
          ? "MoMo SMS parsed and reconciled successfully."
          : "MoMo SMS parsed, but reconciliation requires manual review.",
        functionName: "parse-momo-sms",
        userId: rawSms.user_id,
        subjectType: "momo_sms_raw",
        subjectId: rawSmsId,
        metadata: {
          parsed_sms_id: parsedSmsId,
          parser_provider: provider,
          parser_model: aiResult.model,
          parse_status: parsed.parse_status,
          match_status: autoReconciliation.matchStatus,
          match_type: autoReconciliation.matchType,
          matched_reference: autoReconciliation.matchedReference,
        },
      });

      // ── Push notification for successfully parsed payment ──────────
      if (
        parsed.parse_status === "parsed" &&
        parsed.amount != null &&
        parsed.amount > 0
      ) {
        try {
          const { sendToUser } = await import("../_shared/fcm.ts");
          const amountStr = new Intl.NumberFormat("en-RW", {
            minimumFractionDigits: 0,
            maximumFractionDigits: 0,
          }).format(parsed.amount);
          const currency = parsed.currency ?? "RWF";
          const counterparty = parsed.counterparty_name ?? "MoMo";
          const direction = parsed.tx_direction === "credit"
            ? "received from"
            : "sent to";

          await sendToUser(rawSms.user_id, {
            title: parsed.tx_direction === "credit"
              ? "Payment Received 💰"
              : "Payment Sent",
            body: `${amountStr} ${currency} ${direction} ${counterparty}`,
          }, {
            route: "/momo",
            type: "momo_payment",
            raw_sms_id: rawSmsId,
          });
        } catch (notifError) {
          // Non-fatal: log but don't fail the parse flow.
          console.error("parse-momo-sms push notification failed:", notifError);
        }
      }

      return jsonOk({
        success: true,
        rawSmsId,
        parsedSmsId,
        provider,
        model: aiResult.model,
        parseStatus: parsed.parse_status,
        confidence: parsed.confidence,
        reconciliation: {
          matchType: autoReconciliation.matchType,
          matchStatus: autoReconciliation.matchStatus,
          targetTable: autoReconciliation.targetTable,
          targetRecordId: autoReconciliation.targetRecordId,
          matchedReference: autoReconciliation.matchedReference,
          txCategory: parsed.tx_category,
        },
      });
    } catch (error) {
      if (selectedAttemptId != null) {
        await adminClient
          .from("momo_parse_attempts")
          .update({
            status: "failed",
            error_message: error instanceof Error
              ? error.message
              : "AI parse failed",
          })
          .eq("id", selectedAttemptId);
      }

      await adminClient
        .from("momo_sms_raw")
        .update({
          parse_status: "failed",
          updated_at: new Date().toISOString(),
        })
        .eq("id", rawSmsId);

      await recordOperationalHealthEvent(adminClient, {
        service: "momo_parsing",
        component: "parse-momo-sms",
        status: "error",
        severity: "critical",
        issueCode: "momo_parse_failed",
        message: error instanceof Error
          ? error.message
          : "Failed to parse MoMo SMS.",
        functionName: "parse-momo-sms",
        userId: rawSms.user_id,
        subjectType: "momo_sms_raw",
        subjectId: rawSmsId,
        metadata: {
          selected_attempt_id: selectedAttemptId,
        },
      });

      await recordEdgeFunctionFailure(adminClient, {
        functionName: "parse-momo-sms",
        error,
        userId: rawSms.user_id,
        subjectType: "momo_sms_raw",
        subjectId: rawSmsId,
        metadata: {
          selected_attempt_id: selectedAttemptId,
        },
      });

      throw error;
    }
  } catch (error) {
    console.error("parse-momo-sms failed", error);
    return jsonError(
      error instanceof Error ? error.message : "Failed to parse MoMo SMS",
      500,
    );
  }
}

if (import.meta.main) {
  Deno.serve((req: Request) => handleRequest(req).then(
    (res) => new Response(res.body, {
      status: res.status,
      statusText: res.statusText,
      headers: { ...Object.fromEntries(res.headers.entries()), ...corsHeaders() },
    })
  ));
}
