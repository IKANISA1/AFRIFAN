import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { adminOperationalQueues } from "./admin-operational-queues";

const webRoot = process.cwd();

function source(path: string) {
  return readFileSync(resolve(webRoot, path), "utf8");
}

describe("admin operational queue adoption", () => {
  it("assigns every queue a unique id and explicit selection disposition", () => {
    const ids = adminOperationalQueues.map((queue) => queue.id);
    expect(new Set(ids).size).toBe(ids.length);
    expect(adminOperationalQueues.length).toBeGreaterThanOrEqual(35);
    adminOperationalQueues.forEach((queue) => {
      expect(queue.selection.rationale.length).toBeGreaterThan(30);
      expect(queue.route).toMatch(/^\/admin/);
    });
  });

  it.each([
    ...new Set(adminOperationalQueues.map((queue) => queue.sourceFile)),
  ])("%s has search, sorting, and bounded pagination", (file) => {
    const value = source(file);
    expect(value).toMatch(/type="search"|type=\{"search"\}/);
    expect(value).toMatch(/toggleSort|changeSort/);
    expect(value).toContain("AdminPagination");
    expect(value).toMatch(/useAdminCollection|paginateAdminRecords/);
  });

  it.each(
    adminOperationalQueues
      .filter((queue) => queue.rendering === "table")
      .map((queue) => [queue.id, queue.sourceFile]),
  )("%s declares responsive column priority", (_queueId, file) => {
    const value = source(file);
    expect(value).toContain("AdminDataGrid");
    expect(value).toContain("priority:");
  });

  it("keeps bulk selection limited to the reviewed ticket workflow", () => {
    const bulkQueues = adminOperationalQueues.filter(
      (queue) => queue.selection.mode === "bulk_review",
    );
    expect(bulkQueues.map((queue) => queue.id)).toEqual(["tickets.orders"]);

    const ticketSource = source("src/app/admin/tickets/page.tsx");
    expect(ticketSource).toContain("AdminSelectionBar");
    expect(ticketSource).toMatch(/next\.size\s*>\s*100/);
    expect(ticketSource).toContain("getAdminTicketBulkEligibility");
  });
});
