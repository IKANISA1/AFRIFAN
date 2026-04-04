"use client";

import { useCallback, useEffect, useState } from "react";
import { Users } from "lucide-react";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { SectionHeading } from "@/components/section-heading";
import {
  deleteAdminFanClub,
  getAdminFanClubs,
  saveAdminFanClub,
} from "@/lib/data/admin";
import type { AdminFanClub } from "@/lib/types";
import { emptyForm, type CommunityForm } from "./_components/community-state";
import { CommunityContentEditor } from "./_components/community-content-editor";
import { CommunityContentList } from "./_components/community-content-list";

export default function AdminCommunityPage() {
  const { access, client } = useAdminPortal();
  const [clubs, setClubs] = useState<AdminFanClub[]>([]);
  const [form, setForm] = useState<CommunityForm>(emptyForm);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    if (client == null) return;

    setLoading(true);
    try {
      setClubs(await getAdminFanClubs(client, access));
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not load fan clubs.",
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

  function beginEdit(club: AdminFanClub) {
    setForm({
      id: club.id,
      name: club.name,
      region: club.region,
      description: club.description,
      memberCount: String(club.memberCount),
      eventCount: String(club.eventCount),
      rating: String(club.rating),
      bannerImageUrl: club.bannerImageUrl ?? "",
      isActive: club.isActive,
    });
    showAdminToast(`Editing ${club.name}.`, "info");
  }

  async function submitForm(formData: FormData) {
    if (client == null) return;

    showAdminToast(form.id ? "Saving chapter..." : "Creating chapter...", "info");
    try {
      await saveAdminFanClub(client, access, {
        id: form.id || null,
        name: String(formData.get("name") ?? ""),
        region: String(formData.get("region") ?? ""),
        description: String(formData.get("description") ?? ""),
        memberCount: Number(formData.get("memberCount") ?? 0),
        eventCount: Number(formData.get("eventCount") ?? 0),
        rating: Number(formData.get("rating") ?? 0),
        bannerImageUrl: String(formData.get("bannerImageUrl") ?? ""),
        isActive: formData.get("isActive") === "on",
      });
      setForm(emptyForm);
      await load();
      showAdminToast("Chapter saved.", "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not save chapter.",
        "error",
      );
    }
  }

  async function removeClub(club: AdminFanClub) {
    if (client == null) return;

    try {
      await deleteAdminFanClub(client, access, club.id);
      await load();
      showAdminToast(`${club.name} removed.`, "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not remove chapter.",
        "error",
      );
    }
  }

  const totalMembers = clubs.reduce((sum, club) => sum + club.memberCount, 0);
  const regions = Array.from(new Set(clubs.map((club) => club.region)));

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Community manager"
        title="Manage supporter chapters published on the fan clubs page."
        description="Add, edit, and retire supporter chapters. These records power the public community view and the wider supporter network."
      />

      <div className="grid gap-5 md:grid-cols-4">
        <AdminStateCard
          label="Chapters"
          value={loading ? "..." : clubs.length.toString()}
          helper="Registered supporter chapters."
          icon={Users}
        />
        <AdminStateCard
          label="Members"
          value={loading ? "..." : totalMembers.toString()}
          helper="Aggregate member count across all chapters."
        />
        <AdminStateCard
          label="Regions"
          value={loading ? "..." : regions.length.toString()}
          helper="Geographic coverage of the supporter network."
        />
        <AdminStateCard
          label="Active"
          value={
            loading ? "..." : clubs.filter((club) => club.isActive).length.toString()
          }
          helper="Chapters currently visible on the public site."
        />
      </div>

      <div className="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
        <CommunityContentEditor
          form={form}
          setForm={setForm}
          onSubmit={submitForm}
        />

        <CommunityContentList
          clubs={clubs}
          loading={loading}
          onBeginEdit={beginEdit}
          onRemove={(club) => removeClub(club).catch(() => {})}
        />
      </div>
    </div>
  );
}
