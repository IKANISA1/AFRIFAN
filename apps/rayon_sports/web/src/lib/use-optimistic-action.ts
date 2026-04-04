"use client";

import { useCallback, useState, useTransition } from "react";
import { showAdminToast } from "@/components/admin/admin-toast";

/**
 * Optimistic mutation hook for admin actions.
 *
 * Immediately updates the UI with the expected result,
 * then reverts if the server request fails.
 *
 * @example
 * const { execute, isPending } = useOptimisticAction(
 *   async (newTitle: string) => {
 *     await updateMatchTitle(matchId, newTitle);
 *   },
 *   {
 *     onOptimistic: (newTitle) => setTitle(newTitle),
 *     onRevert: () => setTitle(previousTitle),
 *     successMessage: "Match title updated",
 *   }
 * );
 */

interface UseOptimisticActionOptions<TInput> {
  /** Called immediately before the server action — apply optimistic update here. */
  onOptimistic?: (input: TInput) => void;
  /** Called if the server action fails — revert the optimistic update here. */
  onRevert?: (input: TInput) => void;
  /** Toast message on success. */
  successMessage?: string;
  /** Toast message on failure. Falls back to the error message. */
  errorMessage?: string;
}

interface UseOptimisticActionReturn<TInput> {
  execute: (input: TInput) => Promise<void>;
  isPending: boolean;
}

export function useOptimisticAction<TInput>(
  action: (input: TInput) => Promise<void>,
  options: UseOptimisticActionOptions<TInput> = {},
): UseOptimisticActionReturn<TInput> {
  const [isPending, startTransition] = useTransition();
  const [, setError] = useState<Error | null>(null);

  const execute = useCallback(
    async (input: TInput) => {
      // Apply optimistic update immediately
      options.onOptimistic?.(input);

      startTransition(async () => {
        try {
          await action(input);
          if (options.successMessage) {
            showAdminToast(options.successMessage, "success");
          }
          setError(null);
        } catch (caught) {
          // Revert optimistic update
          options.onRevert?.(input);

          const message =
            options.errorMessage ??
            (caught instanceof Error ? caught.message : "Action failed");
          showAdminToast(message, "error");
          setError(caught instanceof Error ? caught : new Error(message));
        }
      });
    },
    [action, options],
  );

  return { execute, isPending };
}
