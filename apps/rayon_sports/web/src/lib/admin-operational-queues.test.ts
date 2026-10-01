import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { adminOperationalQueues } from "./admin-operational-queues";

const webRoot = process.cwd();

function source(path: string) {
  return readFileSync(resolve(webRoot, path), "utf8");
}

function importedSource(parent: string, content: string, symbol: string, extension: ".ts" | ".tsx") {
  const declaration = content.match(new RegExp(`import\\s+\\{[^}]*\\b${symbol}\\b[^}]*\\}\\s+from\\s+["']([^"']+)["']`));
  expect(declaration, `${symbol} must stay imported by ${parent}`).not.toBeNull();
  const specifier = declaration![1];
  const file = specifier.startsWith("@/") ? `src/${specifier.slice(2)}${extension}` : resolve(dirname(parent), `${specifier}${extension}`);
  return { file, content: source(file) };
}

function queueSource(file: string) {
  const page = source(file);
  if (file !== "src/app/admin/predictions/page.tsx") return page;
  expect(page).toMatch(/<PredictionsWorkspace\b/);
  const workspace = importedSource(file, page, "PredictionsWorkspace", ".tsx");
  expect(workspace.content).toMatch(/<PredictionFixturesTab\b/);
  expect(workspace.content).toMatch(/usePredictionsWorkspace\(\)/);
  const fixtures = importedSource(workspace.file, workspace.content, "PredictionFixturesTab", ".tsx");
  const controller = importedSource(workspace.file, workspace.content, "usePredictionsWorkspace", ".ts");
  expect(controller.content).toMatch(/useFixtureTab\(workspace\.fixtures\)/);
  const collections = importedSource(controller.file, controller.content, "useFixtureTab", ".ts");
  return [page, workspace.content, fixtures.content, controller.content, collections.content].join("\n");
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
    const value = queueSource(file);
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
    const value = queueSource(file);
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
