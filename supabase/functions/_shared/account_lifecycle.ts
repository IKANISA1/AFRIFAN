import { HttpError } from "./http_error.ts";

export type AccountClosureReceipt = {
  request_id: string;
  status: "deletion_pending" | "failed" | "completed";
  access_revoked: boolean;
  requested_at: string;
};
type RpcClient = {
  rpc(
    name: string,
    args?: Record<string, unknown>,
  ): PromiseLike<{ data: any; error: unknown }>;
};
type WorkerClient = RpcClient & {
  storage: {
    from(
      bucket: string,
    ): { remove(names: string[]): PromiseLike<{ error: unknown }> };
  };
  auth: {
    admin: {
      deleteUser(id: string, soft: boolean): PromiseLike<{ error: unknown }>;
    };
  };
};
export async function lifecycleRpc<T>(
  client: RpcClient,
  name: string,
  args?: Record<string, unknown>,
): Promise<T> {
  const { data, error } = await client.rpc(name, args);
  if (error || data == null) {
    throw new HttpError(503, "Account closure processing is unavailable.");
  }
  return data as T;
}
export async function requestAccountClosure(
  client: RpcClient,
  userId: string,
  requestId?: string,
): Promise<AccountClosureReceipt> {
  const receipt = await lifecycleRpc<AccountClosureReceipt>(
    client,
    "request_account_erasure",
    { p_user_id: userId, p_request_id: requestId ?? null },
  );
  if (
    !receipt.request_id ||
    !["deletion_pending", "failed", "completed"].includes(receipt.status) ||
    receipt.access_revoked !== true
  ) {
    throw new HttpError(503, "Account closure processing is unavailable.");
  }
  return receipt;
}

/** Bounded worker. Durable receipt already exists before Storage/Auth side effects.
 * Replay removes the remaining objects and verifies SQL acknowledgements.
 * Processor/backup obligations can only be acknowledged with attributable evidence.
 */
export async function processAccountClosures(
  client: WorkerClient,
  { now = Date.now, budgetMs = 45_000 } = {},
) {
  const deadline = now() + Math.min(45_000, Math.max(1, budgetMs));
  const jobs = await lifecycleRpc<any[]>(client, "claim_account_erasure_jobs", {
    p_limit: 5,
  });
  const result = { claimed: jobs.length, pending: 0, failed: 0 };
  for (const job of jobs) {
    const args = { p_job_id: job.request_id, p_lease_token: job.lease_token };
    let stage = "local_data";
    try {
      if (now() >= deadline) {
        result.pending++;
        continue;
      }
      if (job.steps.local_data !== "completed") {
        const local = await lifecycleRpc<{ has_more: boolean }>(
          client,
          "erase_account_local_batch",
          { ...args, p_batch_size: 250 },
        );
        if (local.has_more) {
          result.pending++;
          continue;
        }
      }
      if (job.steps.storage !== "completed") {
        stage = "storage";
        const objects = await lifecycleRpc<{ bucket: string; name: string }[]>(
          client,
          "account_erasure_storage_batch",
          { ...args, p_limit: 100 },
        );
        const buckets = new Map<string, string[]>();
        for (const object of objects) {
          buckets.set(object.bucket, [
            ...(buckets.get(object.bucket) ?? []),
            object.name,
          ]);
        }
        for (const [bucket, names] of buckets) {
          if (now() >= deadline) throw new Error("deadline");
          const { error } = await client.storage.from(bucket).remove(names);
          if (error) throw new Error("storage");
        }
        const remaining = await lifecycleRpc<any[]>(
          client,
          "account_erasure_storage_batch",
          { ...args, p_limit: 1 },
        );
        if (remaining.length) {
          result.pending++;
          continue;
        }
        await lifecycleRpc(client, "record_account_erasure_step", {
          ...args,
          p_step: "storage",
          p_success: true,
          p_evidence_reference: "storage-api-remove-and-db-readback",
        });
      }
      if (job.steps.auth !== "completed") {
        stage = "auth";
        if (now() >= deadline) {
          result.pending++;
          continue;
        }
        const { error } = await client.auth.admin.deleteUser(job.user_id, true);
        if (error) throw new Error("auth");
        await lifecycleRpc(client, "record_account_erasure_step", {
          ...args,
          p_step: "auth",
          p_success: true,
          p_evidence_reference: "auth-api-soft-delete-and-db-readback",
        });
      }
      result.pending++; // External processor and backup evidence remains required.
    } catch {
      result.failed++;
      // Public diagnostics never include provider/SQL messages or user identifiers.
      try {
        await lifecycleRpc(client, "record_account_erasure_step", {
          ...args,
          p_step: stage,
          p_success: false,
        });
      } catch { /* lease expiry is recovered by the next claim */ }
    } finally {
      // SQL void responses are null; this operation intentionally does not use lifecycleRpc.
      await client.rpc("release_account_erasure_lease", args);
    }
  }
  return result;
}
