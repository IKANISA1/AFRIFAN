"use client";

import { Search } from "lucide-react";
import { FixtureTeams } from "@/components/team-card";
import { AdminDataGrid } from "../admin-data-grid";
import { AdminFilterBar } from "../admin-filter-bar";
import { AdminStatusBadge } from "../admin-status-badge";
import { AdminPagination } from "../admin-pagination";
import { AdminActionDrawer } from "../admin-action-drawer";
import type { AdminFixture } from "@/lib/data/admin/predictions";
import type { AdminResourceInteraction } from "../admin-resource-status-banner";
import type { useFixtureTab } from "./use-prediction-tabs";
import { formatKickoff, statusTone } from "./prediction-presenters";

export function PredictionFixturesTab({ fixtureCollection, fixtures, setDetailFixture, setInteraction }: {
  fixtureCollection: ReturnType<typeof useFixtureTab>;
  fixtures: AdminFixture[];
  setDetailFixture: (fixture: AdminFixture | null) => void;
  setInteraction: (interaction: AdminResourceInteraction) => void;
}) {
  return (
    <div className="space-y-3">
      <p className="font-display text-2xl font-medium normal-case">
        Fixtures ({fixtures.length})
      </p>
      <AdminFilterBar>
        <label className="admin-search-field">
          <Search size={16} aria-hidden="true" />
          <span className="sr-only">Search fixtures</span>
          <input
            type="search"
            value={fixtureCollection.query}
            onChange={(event) =>
              fixtureCollection.setQuery(event.target.value)
            }
            placeholder="Search teams, competition, or status"
          />
        </label>
      </AdminFilterBar>
      <p className="mb-4 text-sm text-[var(--admin-text-muted)]">
        Match status and results are read-only. LiveScore validates and confirms results automatically.
      </p>
      <AdminDataGrid
        caption="Prediction fixtures"
        onRowActivate={(rowId) => {
          setDetailFixture(
            fixtures.find((fixture) => fixture.id === rowId) ??
              null,
          );
          setInteraction("selected");
        }}
        columns={[
          {
            key: "match",
            label: "Match",
            priority: "primary",
            sortable: true,
            sortDirection:
              fixtureCollection.sortDirectionFor("match"),
            onSort: () => fixtureCollection.toggleSort("match"),
          },
          {
            key: "competition",
            label: "Competition",
            priority: "secondary",
            sortable: true,
            sortDirection:
              fixtureCollection.sortDirectionFor("competition"),
            onSort: () =>
              fixtureCollection.toggleSort("competition"),
          },
          {
            key: "kickoff",
            label: "Kickoff",
            priority: "primary",
            sortable: true,
            sortDirection:
              fixtureCollection.sortDirectionFor("kickoff"),
            onSort: () => fixtureCollection.toggleSort("kickoff"),
          },
          { key: "score", label: "Score", priority: "secondary" },
          {
            key: "status",
            label: "Status",
            priority: "primary",
            sortable: true,
            sortDirection:
              fixtureCollection.sortDirectionFor("status"),
            onSort: () => fixtureCollection.toggleSort("status"),
          },
          { key: "actions", label: "Actions", priority: "primary" },
        ]}
      >
        {fixtureCollection.pageResult.items.length === 0 ? (
          <tr>
            <td
              colSpan={6}
              className="py-8 text-center text-sm text-[var(--admin-text-muted)]"
            >
              {fixtureCollection.query
                ? "No fixtures match the current search."
                : "No fixtures found."}
            </td>
          </tr>
        ) : (
          fixtureCollection.pageResult.items.map((fixture) => (
            <tr key={fixture.id} data-row-id={fixture.id}>
              <td className="py-3 pr-4">
                <FixtureTeams homeTeam={fixture.homeTeamName} awayTeam={fixture.awayTeamName} />
              </td>
              <td className="py-3 pr-4 text-[var(--admin-text-muted)]">
                {fixture.competitionName}
              </td>
              <td className="py-3 pr-4 text-[var(--admin-text-muted)]">
                {formatKickoff(fixture.kickoffAt)}
              </td>
              <td className="py-3 pr-4">
                {fixture.homeScore != null ? (
                  <span className="font-medium text-[var(--admin-text-strong)]">
                    {fixture.homeScore} - {fixture.awayScore}
                  </span>
                ) : (
                  <span className="text-[var(--admin-text-muted)]">—</span>
                )}
              </td>
              <td className="py-3 pr-4">
                <AdminStatusBadge
                  label={fixture.status}
                  tone={statusTone(fixture.status)}
                />
              </td>
              <td className="py-3">
                <button
                  type="button"
                  onClick={() => setDetailFixture(fixture)}
                  className="min-h-12 rounded-full px-3 text-sm text-[var(--admin-text-strong)] hover:bg-[var(--admin-surface-hover)]"
                  aria-label={`View fixture ${fixture.homeTeamShortName} versus ${fixture.awayTeamShortName}`}
                >
                  View
                </button>
              </td>
            </tr>
          ))
        )}
      </AdminDataGrid>
      <AdminPagination
        page={fixtureCollection.pageResult}
        onPageChange={fixtureCollection.setPage}
        label="Prediction fixtures"
      />
    </div>
  );
}

export function PredictionFixtureDrawer({ detailFixture, setDetailFixture, permissionDenied }: { detailFixture: AdminFixture | null; setDetailFixture: (fixture: AdminFixture | null) => void; permissionDenied: boolean }) {
  return (
    <AdminActionDrawer
      open={detailFixture != null && !permissionDenied}
      onClose={() => setDetailFixture(null)}
      title="Fixture details"
    >
      {detailFixture ? (
        <dl className="grid gap-4 text-sm">
          <div>
            <dt className="text-[var(--admin-text-muted)]">Match</dt>
            <dd className="mt-1 text-[var(--admin-text-strong)]">
              <FixtureTeams homeTeam={detailFixture.homeTeamName} awayTeam={detailFixture.awayTeamName} />
            </dd>
          </div>
          <div>
            <dt className="text-[var(--admin-text-muted)]">Competition</dt>
            <dd className="mt-1 text-[var(--admin-text-strong)]">
              {detailFixture.competitionName}
            </dd>
          </div>
          <div>
            <dt className="text-[var(--admin-text-muted)]">Kickoff</dt>
            <dd className="mt-1 text-[var(--admin-text-strong)]">
              {new Date(detailFixture.kickoffAt).toLocaleString()}
            </dd>
          </div>
          <div>
            <dt className="text-[var(--admin-text-muted)]">Status</dt>
            <dd className="mt-1 text-[var(--admin-text-strong)]">{detailFixture.status}</dd>
          </div>
          <div>
            <dt className="text-[var(--admin-text-muted)]">Score</dt>
            <dd className="mt-1 text-[var(--admin-text-strong)]">
              {detailFixture.homeScore == null
                ? "Not recorded"
                : `${detailFixture.homeScore} - ${detailFixture.awayScore}`}
            </dd>
          </div>
        </dl>
      ) : null}
    </AdminActionDrawer>
  );
}
