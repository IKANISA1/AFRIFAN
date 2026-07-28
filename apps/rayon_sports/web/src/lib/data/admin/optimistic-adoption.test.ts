import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const dataRoot = resolve(process.cwd(), "src/lib/data/admin");
const appRoot = resolve(process.cwd(), "src/app/admin");

function source(root: string, path: string) {
  return readFileSync(resolve(root, path), "utf8");
}

describe("admin optimistic-concurrency adoption", () => {
  it.each([
    "cms.ts",
    "cms-content.ts",
    "content-blocks.ts",
    "contributions.ts",
    "fan-clubs.ts",
    "football-sync.ts",
    "gamification.ts",
    "membership.ts",
    "matches.ts",
    "offers.ts",
    "runtime-registries.ts",
    "shop.ts",
    "squad.ts",
    "standings.ts",
  ])("%s uses conditional save and delete helpers", (file) => {
    const value = source(dataRoot, file);
    expect(value).toContain("mutateRecordWithVariantsIfUnchanged");
    expect(value).toContain("deleteAdminRecordWithAuditIfUnchanged");
  });

  it("prediction editors use loaded-token conditional saves", () => {
    const value = source(dataRoot, "predictions.ts");
    expect(value).toContain("mutateRecordWithVariantsIfUnchanged");
    expect(value).toContain("expectedUpdatedAt");
  });

  it.each([
    "cms/page.tsx",
    "cms/banners/page.tsx",
    "cms/config/page.tsx",
    "cms/content/page.tsx",
    "cms/content-blocks/page.tsx",
    "community/page.tsx",
    "contributions/page.tsx",
    "football-sync/page.tsx",
    "membership/page.tsx",
    "gamification/page.tsx",
    "matches/page.tsx",
    "offers/page.tsx",
    "predictions/page.tsx",
    "settings/runtime/page.tsx",
    "shop/page.tsx",
    "squad/page.tsx",
    "standings/page.tsx",
  ])("%s retains loaded version tokens and handles conflicts", (file) => {
    const value = source(appRoot, file);
    expect(value).toMatch(/expectedUpdatedAt|\.updatedAt/);
    expect(value).toContain("isAdminMutationConflict");
  });

  it("maps stale writes to HTTP 409 instead of generic server errors", () => {
    const value = source(
      resolve(process.cwd(), "src/app/api/admin"),
      "[resource]/route.ts",
    );
    expect(value).toContain('code: "STALE_RECORD"');
    expect(value).toContain("{ status: 409 }");
  });

  it.each([
    ["features.ts", "admin_update_platform_feature_if_unchanged"],
    [
      "membership-ops.ts",
      "admin_review_membership_application_if_unchanged",
    ],
  ])("%s uses a transactional version-checked RPC", (file, rpc) => {
    const value = source(dataRoot, file);
    expect(value).toContain("requireExpectedUpdatedAt");
    expect(value).toContain(rpc);
    expect(value).toContain("AdminMutationConflictError");
  });

  it("feature settings retain the loaded version and refresh on conflict", () => {
    const value = source(appRoot, "settings/features/page.tsx");
    expect(value).toContain(".updatedAt");
    expect(value).toContain("isAdminMutationConflict");
  });
});
