"use client";

import { useCallback, useEffect, useState } from "react";
import { Layout, Plus, Trash2, Edit3, Eye, EyeOff, GripVertical } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import { getAdminContentBlocks, saveAdminContentBlock, deleteAdminContentBlock } from "@/lib/data/admin/content-blocks";
import { getAdminFeatures } from "@/lib/data/admin/features";
import type { ContentBlock, PlatformFeature } from "@/lib/types";
import { useHydrated } from "@/lib/use-hydrated";

export default function AdminContentBlocksPage() {
  const { access, client } = useAdminPortal();
  const hydrated = useHydrated();
  const [blocks, setBlocks] = useState<ContentBlock[]>([]);
  const [features, setFeatures] = useState<PlatformFeature[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const controlsDisabled = !hydrated || client == null;

  const [drawerOpen, setDrawerOpen] = useState(false);
  const [editingBlock, setEditingBlock] = useState<Partial<ContentBlock> | null>(null);

  const loadData = useCallback(async () => {
    if (client == null) return;
    setLoading(true);
    try {
      const [blocksData, featuresData] = await Promise.all([
        getAdminContentBlocks(client, access),
        getAdminFeatures(client, access),
      ]);
      setBlocks(blocksData);
      setFeatures(featuresData);
      setLoadError(null);
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : "Could not load content blocks.";
      setLoadError(message);
      showAdminToast(message, "error");
    } finally {
      setLoading(false);
    }
  }, [access, client]);

  useEffect(() => {
    if (client == null || !access.hasAccess) return;
    loadData().catch(() => {});
  }, [access.hasAccess, client, loadData]);

  async function handleSave(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!client || !editingBlock) return;

    try {
      await saveAdminContentBlock(client, access, editingBlock);
      showAdminToast("Block saved.", "success");
      setDrawerOpen(false);
      await loadData();
    } catch (e) {
      showAdminToast("Failed to save block.", "error");
    }
  }

  async function handleDelete(id: string) {
    if (!client || !confirmAdminDestructiveAction({ subject: "this content block" })) return;
    try {
      await deleteAdminContentBlock(client, access, id);
      showAdminToast("Block deleted.", "success");
      await loadData();
    } catch (e) {
      showAdminToast("Failed to delete block.", "error");
    }
  }

  function beginEdit(block: ContentBlock) {
    setEditingBlock(block);
    setDrawerOpen(true);
  }

  function beginCreate() {
    setEditingBlock({
      blockKey: "",
      blockType: "section",
      targetChannel: "both",
      placementKey: "home_mid",
      isActive: true,
      sortOrder: 0,
      content: {},
      metadata: {},
    });
    setDrawerOpen(true);
  }

  return (
    <div className="section-grid !gap-6">
      <AdminPageHeader
        eyebrow="CMS"
        title="Placements & Blocks"
        meta={
          <span className="admin-meta-chip">
            <Layout size={12} className="inline mr-1" />
            UI Composition
          </span>
        }
        actions={
          <button
            onClick={beginCreate}
            disabled={controlsDisabled}
            className="admin-action-button !bg-club-accent !text-white disabled:opacity-60"
          >
            <Plus size={16} /> New Block
          </button>
        }
      />

      <div className="grid gap-4 md:grid-cols-3">
        <AdminStateCard label="Total Blocks" value={loading ? "..." : blocks.length.toString()} icon={Layout} />
        <AdminStateCard label="Active" value={loading ? "..." : blocks.filter(b => b.isActive).length.toString()} tone="success" />
        <AdminStateCard label="Placements" value={loading ? "..." : new Set(blocks.map(b => b.placementKey)).size.toString()} tone="info" />
      </div>

      {loadError && !loading ? (
        <AdminErrorState title="Blocks could not be loaded" description={loadError} onRetry={loadData} />
      ) : (
        <div className="admin-surface">
          <AdminDataGrid
            columns={[
              { key: "block", label: "Block / Type" },
              { key: "placement", label: "Placement" },
              { key: "channel", label: "Channel" },
              { key: "feature", label: "Linked Feature" },
              { key: "status", label: "State" },
              { key: "actions", label: "", className: "text-right" },
            ]}
          >
            {blocks.map((block) => {
              const linkedFeature = features.find(f => f.id === block.featureId);
              return (
                <tr key={block.id}>
                  <td>
                    <p className="admin-row-title">{block.title || block.blockKey}</p>
                    <p className="admin-row-meta">{block.blockType}</p>
                  </td>
                  <td>
                    <code className="text-[10px] font-mono bg-white/5 px-1.5 py-0.5 rounded">{block.placementKey}</code>
                  </td>
                  <td>
                    <AdminStatusBadge label={block.targetChannel} tone="neutral" />
                  </td>
                  <td>
                    {linkedFeature ? (
                      <span className="text-xs text-emerald-400 font-medium">{linkedFeature.displayName}</span>
                    ) : (
                      <span className="text-xs text-slate-500">—</span>
                    )}
                  </td>
                  <td>
                    <AdminStatusBadge label={block.isActive ? "Active" : "Disabled"} tone={block.isActive ? "success" : "danger"} />
                  </td>
                  <td className="text-right">
                    <div className="flex justify-end gap-2">
                      <button onClick={() => beginEdit(block)} className="admin-action-button">Edit</button>
                      <button onClick={() => handleDelete(block.id!)} className="admin-action-button admin-action-button-danger"><Trash2 size={14}/></button>
                    </div>
                  </td>
                </tr>
              );
            })}
          </AdminDataGrid>
        </div>
      )}

      <AdminActionDrawer
        isOpen={drawerOpen}
        onClose={() => setDrawerOpen(false)}
        title={editingBlock?.id ? `Edit Block: ${editingBlock.blockKey}` : "New Content Block"}
      >
        {editingBlock && (
          <form onSubmit={handleSave} className="space-y-6 p-4">
            <div className="space-y-4">
              <label className="grid gap-2 text-sm font-semibold text-white">
                Block Key (unique)
                <input
                  required
                  value={editingBlock.blockKey}
                  onChange={e => setEditingBlock({...editingBlock, blockKey: e.target.value})}
                  className="admin-input"
                  placeholder="home_hero_banner"
                />
              </label>
              <div className="grid grid-cols-2 gap-4">
                <label className="grid gap-2 text-sm font-semibold text-white">
                  Block Type
                  <select
                    value={editingBlock.blockType}
                    onChange={e => setEditingBlock({...editingBlock, blockType: e.target.value})}
                    className="admin-input"
                  >
                    <option value="section">Section</option>
                    <option value="banner">Banner</option>
                    <option value="action">Quick Action</option>
                    <option value="html">HTML / Raw</option>
                  </select>
                </label>
                <label className="grid gap-2 text-sm font-semibold text-white">
                  Target Channel
                  <select
                    value={editingBlock.targetChannel}
                    onChange={e => setEditingBlock({
                      ...editingBlock,
                      targetChannel: e.target.value as ContentBlock["targetChannel"],
                    })}
                    className="admin-input"
                  >
                    <option value="both">Both</option>
                    <option value="web">Web Only</option>
                    <option value="mobile">Mobile Only</option>
                  </select>
                </label>
              </div>
              <label className="grid gap-2 text-sm font-semibold text-white">
                Placement Key
                <input
                  required
                  value={editingBlock.placementKey}
                  onChange={e => setEditingBlock({...editingBlock, placementKey: e.target.value})}
                  className="admin-input"
                  placeholder="home_top, home_mid, sidebar"
                />
              </label>
              <label className="grid gap-2 text-sm font-semibold text-white">
                Title
                <input
                  value={editingBlock.title || ""}
                  onChange={e => setEditingBlock({...editingBlock, title: e.target.value})}
                  className="admin-input"
                />
              </label>
              <label className="grid gap-2 text-sm font-semibold text-white">
                Linked Feature
                  <select
                    value={editingBlock.featureId || ""}
                    onChange={e => setEditingBlock({
                      ...editingBlock,
                      featureId: e.target.value || null,
                    })}
                    className="admin-input"
                  >
                  <option value="">None (Always Show)</option>
                  {features.map(f => (
                    <option key={f.id} value={f.id}>{f.displayName}</option>
                  ))}
                </select>
              </label>
              <div className="flex gap-4">
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={editingBlock.isActive}
                    onChange={e => setEditingBlock({...editingBlock, isActive: e.target.checked})}
                    className="accent-club-accent"
                  />
                  <span className="text-sm font-semibold text-white">Active</span>
                </label>
                <label className="flex items-center gap-2">
                  <span className="text-sm font-semibold text-white">Sort Order</span>
                  <input
                    type="number"
                    value={editingBlock.sortOrder ?? ""}
                    onChange={e => setEditingBlock({
                      ...editingBlock,
                      sortOrder:
                        e.target.value.length === 0
                          ? null
                          : parseInt(e.target.value, 10),
                    })}
                    className="admin-input w-20"
                  />
                </label>
              </div>
            </div>
            <div className="pt-6 border-t border-[var(--admin-border)] flex gap-3">
               <button type="submit" className="admin-action-button flex-1 !bg-club-accent !text-white">Save Block</button>
               <button type="button" onClick={() => setDrawerOpen(false)} className="admin-action-button flex-1">Cancel</button>
            </div>
          </form>
        )}
      </AdminActionDrawer>
    </div>
  );
}
