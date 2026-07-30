import type { Dispatch, SetStateAction } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { showAdminToast } from "@/components/admin/admin-toast";
import { saveAdminFanEngagementToken } from "@/lib/data/admin/gamification";
import type { AdminAccess } from "@/lib/types";
import { emptyFetForm, type FetForm } from "./fet-state";
import { isAdminMutationConflict } from "@/lib/data/admin/http";

interface FetEditorFormProps {
  form: FetForm;
  setForm: Dispatch<SetStateAction<FetForm>>;
  client: SupabaseClient | null;
  access: AdminAccess;
  disabled: boolean;
  onSaved: () => Promise<void>;
  onConflict: () => Promise<void>;
  onFailure: (error: unknown) => void;
}

export function FetEditorForm({
  form,
  setForm,
  client,
  access,
  disabled,
  onSaved,
  onConflict,
  onFailure,
}: FetEditorFormProps) {
  async function submitForm(formData: FormData) {
    if (client == null) return;

    showAdminToast(
      form.id ? "Saving FET item..." : "Creating FET item...",
      "info",
    );
    try {
      await saveAdminFanEngagementToken(client, access, {
        id: form.id || null,
        expectedUpdatedAt: form.expectedUpdatedAt || null,
        code: String(formData.get("code") ?? ""),
        templateScope:
          String(formData.get("templateScope") ?? "generic") === "club_specific"
            ? "club_specific"
            : "generic",
        category: String(formData.get("category") ?? ""),
        itemName: String(formData.get("itemName") ?? ""),
        fetValue: Number(formData.get("fetValue") ?? 0),
        triggerCondition: String(formData.get("triggerCondition") ?? ""),
        activationTiming: String(formData.get("activationTiming") ?? ""),
        description: String(formData.get("description") ?? ""),
        badgeName: String(formData.get("badgeName") ?? ""),
        implementationNotes: String(formData.get("implementationNotes") ?? ""),
        sortOrder: Number(formData.get("sortOrder") ?? 0),
        isActive: formData.get("isActive") === "on",
      });
      setForm(emptyFetForm);
      await onSaved();
      showAdminToast("FET catalog entry saved.", "success");
    } catch (caught) {
      onFailure(caught);
      if (isAdminMutationConflict(caught)) {
        await onConflict();
      }
      showAdminToast("Could not save the reward definition.", "error");
    }
  }

  return (
    <form
      action={submitForm}
      data-mutation-disabled={disabled || undefined}
      className="glass-panel grid min-w-0 gap-4 rounded-[32px] p-6"
    >
      <div className="flex items-center justify-between gap-3">
        <p className="font-display text-3xl font-bold uppercase leading-none">
          {form.id ? "Edit FET" : "New FET"}
        </p>
        {form.id ? (
          <button
            type="button"
            disabled={disabled}
            onClick={() => setForm(emptyFetForm)}
            className="admin-action-button"
          >
            Clear
          </button>
        ) : null}
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <label className="grid gap-2 text-sm">
          Code
          <input
            name="code"
            required
            placeholder="G001"
            value={form.code}
            onChange={(event) =>
              setForm((current) => ({
                ...current,
                code: event.target.value.toUpperCase(),
              }))
            }
            className="dashboard-input"
          />
        </label>
        <label className="grid gap-2 text-sm">
          Template scope
          <select
            name="templateScope"
            value={form.templateScope}
            onChange={(event) =>
              setForm((current) => ({
                ...current,
                templateScope:
                  event.target.value === "club_specific"
                    ? "club_specific"
                    : "generic",
              }))
            }
            className="dashboard-input"
          >
            <option value="generic">Generic</option>
            <option value="club_specific">Club specific</option>
          </select>
        </label>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <label className="grid gap-2 text-sm">
          Category
          <input
            name="category"
            required
            value={form.category}
            onChange={(event) =>
              setForm((current) => ({
                ...current,
                category: event.target.value,
              }))
            }
            className="dashboard-input"
          />
        </label>
        <label className="grid gap-2 text-sm">
          FET value
          <input
            type="number"
            name="fetValue"
            min="0"
            value={form.fetValue}
            onChange={(event) =>
              setForm((current) => ({
                ...current,
                fetValue: event.target.value,
              }))
            }
            className="dashboard-input"
          />
        </label>
      </div>

      <label className="grid gap-2 text-sm">
        Gamification item
        <input
          name="itemName"
          required
          value={form.itemName}
          onChange={(event) =>
            setForm((current) => ({
              ...current,
              itemName: event.target.value,
            }))
          }
          className="dashboard-input"
        />
      </label>

      <label className="grid gap-2 text-sm">
        Trigger / condition
        <textarea
          name="triggerCondition"
          rows={2}
          value={form.triggerCondition}
          onChange={(event) =>
            setForm((current) => ({
              ...current,
              triggerCondition: event.target.value,
            }))
          }
          className="dashboard-input min-h-20 resize-y"
        />
      </label>

      <label className="grid gap-2 text-sm">
        Activation timing
        <textarea
          name="activationTiming"
          rows={2}
          value={form.activationTiming}
          onChange={(event) =>
            setForm((current) => ({
              ...current,
              activationTiming: event.target.value,
            }))
          }
          className="dashboard-input min-h-20 resize-y"
        />
      </label>

      <label className="grid gap-2 text-sm">
        Description
        <textarea
          name="description"
          rows={3}
          value={form.description}
          onChange={(event) =>
            setForm((current) => ({
              ...current,
              description: event.target.value,
            }))
          }
          className="dashboard-input min-h-24 resize-y"
        />
      </label>

      <div className="grid gap-4 sm:grid-cols-2">
        <label className="grid gap-2 text-sm">
          Badge
          <input
            name="badgeName"
            value={form.badgeName}
            onChange={(event) =>
              setForm((current) => ({
                ...current,
                badgeName: event.target.value,
              }))
            }
            className="dashboard-input"
          />
        </label>
        <label className="grid gap-2 text-sm">
          Sort order
          <input
            type="number"
            name="sortOrder"
            value={form.sortOrder}
            onChange={(event) =>
              setForm((current) => ({
                ...current,
                sortOrder: event.target.value,
              }))
            }
            className="dashboard-input"
          />
        </label>
      </div>

      <label className="grid gap-2 text-sm">
        Implementation notes
        <textarea
          name="implementationNotes"
          rows={4}
          value={form.implementationNotes}
          onChange={(event) =>
            setForm((current) => ({
              ...current,
              implementationNotes: event.target.value,
            }))
          }
          className="dashboard-input min-h-28 resize-y"
        />
      </label>

      <label className="flex items-center gap-3 rounded-[22px] border border-[var(--admin-border)] bg-[var(--admin-surface-muted)] px-4 py-3 text-sm">
        <input
          type="checkbox"
          name="isActive"
          checked={form.isActive}
          onChange={(event) =>
            setForm((current) => ({
              ...current,
              isActive: event.target.checked,
            }))
          }
        />
        Active and available in this club catalog
      </label>

      <button
        type="submit"
        disabled={disabled}
        className="ui-button ui-button-primary"
      >
        {form.id ? "Save FET item" : "Create FET item"}
      </button>
    </form>
  );
}
