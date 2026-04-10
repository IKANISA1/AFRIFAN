"use client";

import { useCallback, useEffect, useState } from "react";
import { Award } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { SectionHeading } from "@/components/section-heading";
import {
  deleteAdminFanEngagementToken,
  getAdminFanEngagementTokens,
  saveAdminFanEngagementToken,
} from "@/lib/data/admin/gamification";
import type { AdminFanEngagementToken } from "@/lib/types";
import {
  emptyFetForm,
  type FetForm,
  tokenToForm,
} from "./_components/fet-state";
import { FetEditorForm } from "./_components/fet-editor-form";
import { FetList } from "./_components/fet-list";

export default function AdminGamificationPage() {
  const { access, client } = useAdminPortal();
  const [tokens, setTokens] = useState<AdminFanEngagementToken[]>([]);
  const [form, setForm] = useState<FetForm>(emptyFetForm);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (client == null) return;

    setLoading(true);
    try {
      setTokens(await getAdminFanEngagementTokens(client, access));
    } catch (caught) {
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not load FET catalog.",
        "error",
      );
    } finally {
      setLoading(false);
    }
  }, [access, client]);

  useEffect(() => {
    if (client == null || !access.hasAccess) return;
    load().catch(() => {});
  }, [access.hasAccess, client, load]);

  function beginEdit(token: AdminFanEngagementToken) {
    setForm(tokenToForm(token));
    showAdminToast(`Editing ${token.code}.`, "info");
  }

  async function removeToken(token: AdminFanEngagementToken) {
    if (client == null) return;

    showAdminToast(`Removing ${token.code}...`, "info");
    try {
      await deleteAdminFanEngagementToken(client, access, token.id);
      await load();
      if (form.id === token.id) {
        setForm(emptyFetForm);
      }
      showAdminToast(`${token.code} removed.`, "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not remove FET item.",
        "error",
      );
    }
  }

  async function toggleActive(token: AdminFanEngagementToken) {
    if (client == null) return;

    showAdminToast(
      `${token.isActive ? "Deactivating" : "Activating"} ${token.code}...`,
      "info",
    );
    try {
      await saveAdminFanEngagementToken(client, access, {
        id: token.id,
        code: token.code,
        templateScope: token.templateScope,
        category: token.category,
        itemName: token.itemName,
        fetValue: token.fetValue,
        triggerCondition: token.triggerCondition,
        activationTiming: token.activationTiming,
        description: token.description,
        badgeName: token.badgeName,
        implementationNotes: token.implementationNotes,
        sortOrder: token.sortOrder,
        isActive: !token.isActive,
      });
      await load();
      showAdminToast(
        `${token.code} ${token.isActive ? "deactivated" : "activated"}.`,
        "success",
      );
    } catch (caught) {
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not update FET activation state.",
        "error",
      );
    }
  }

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Gamification"
        title="Manage Fan Engagement Token rewards, templates, and activation state."
      />

      <div className="grid gap-5 md:grid-cols-4">
        <AdminStateCard
          label="Catalog items"
          value={loading ? "..." : tokens.length.toString()}
          helper="Configured reward definitions."
          icon={Award}
        />
        <AdminStateCard
          label="Active"
          value={
            loading
              ? "..."
              : tokens.filter((token) => token.isActive).length.toString()
          }
          helper="Available to this club."
        />
        <AdminStateCard
          label="Generic"
          value={
            loading
              ? "..."
              : tokens
                  .filter((token) => token.templateScope === "generic")
                  .length.toString()
          }
          helper="Reusable across clubs."
        />
        <AdminStateCard
          label="Club-specific"
          value={
            loading
              ? "..."
              : tokens
                  .filter((token) => token.templateScope === "club_specific")
                  .length.toString()
          }
          helper="Tailored to local context."
        />
      </div>

      <div className="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
        <FetEditorForm
          form={form}
          setForm={setForm}
          client={client}
          access={access}
          onSaved={load}
        />
        <FetList
          tokens={tokens}
          loading={loading}
          onEdit={beginEdit}
          onDelete={removeToken}
          onToggleActive={toggleActive}
        />
      </div>
    </div>
  );
}
