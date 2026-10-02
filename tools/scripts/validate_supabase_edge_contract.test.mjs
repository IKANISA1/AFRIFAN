import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { validateSupabaseEdgeContract } from "./validate_supabase_edge_contract.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
function fixture(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "africlub-edge-contract-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  fs.mkdirSync(path.join(dir, "supabase"));
  fs.copyFileSync(path.join(root, "supabase/config.toml"), path.join(dir, "supabase/config.toml"));
  fs.cpSync(path.join(root, "supabase/migrations"), path.join(dir, "supabase/migrations"), { recursive: true });
  fs.cpSync(path.join(root, "supabase/functions"), path.join(dir, "supabase/functions"), {
    recursive: true, filter: (file) => !file.includes("node_modules") && !file.endsWith("_test.ts"),
  });
  return dir;
}
function mutate(dir, file, from, to) {
  const target = path.join(dir, "supabase/functions", file);
  const source = fs.readFileSync(target, "utf8");
  assert.ok(source.includes(from), `Mutation must target actual source: ${file}`);
  fs.writeFileSync(target, source.replaceAll(from, to));
}

test("deployed source meets the governed Edge capability and HTTP contract", () => {
  assert.match(validateSupabaseEdgeContract(root), /18 governed functions/);
});
for (const name of ["admin-settle-fixture", "football-sync", "livescore-openai-sync"]) {
  test(`${name} cannot replace global authority with club-capable admin authority`, (t) => {
    const dir = fixture(t);
    mutate(dir, `${name}/index.ts`, "requireGlobalAdminCaller", "requireAdminCaller");
    assert.throws(() => validateSupabaseEdgeContract(dir), /global operation/);
  });
}
test("importing the shared boundary without wrapping the registered handler fails", (t) => {
  const dir = fixture(t);
  mutate(dir, "get-platform-config/index.ts", "serve(withEdgeBoundary(handleRequest))", "serve(handleRequest)");
  assert.throws(() => validateSupabaseEdgeContract(dir), /register.*withEdgeBoundary/);
});
test("direct inbound body parsing cannot bypass byte and deadline bounds", (t) => {
  const dir = fixture(t);
  mutate(dir, "admin-upload-image/index.ts", "readBoundedJson(request,", "request.json(");
  assert.throws(() => validateSupabaseEdgeContract(dir), /bound inbound bytes/);
});
test("wildcard browser origins are rejected at the shared boundary", (t) => {
  const dir = fixture(t);
  mutate(dir, "_shared/response.ts", '"Access-Control-Allow-Origin": origin', '"Access-Control-Allow-Origin": "*"');
  assert.throws(() => validateSupabaseEdgeContract(dir), /wildcard browser origins/);
});
test("provider image generation cannot omit atomic admission", (t) => {
  const dir = fixture(t);
  const file = path.join(dir, "supabase/migrations/20261001280000_verified_admin_image_generation.sql");
  const sql = fs.readFileSync(file, "utf8");
  assert.ok(sql.includes("public.consume_edge_rate_limit("));
  fs.writeFileSync(file, sql.replaceAll("public.consume_edge_rate_limit(", "public.unbounded_provider_work("));
  assert.throws(() => validateSupabaseEdgeContract(dir), /atomic rate limiter/);
});
for (const name of ["generate-admin-image", "generate-product-image"]) {
  test(`${name} cannot bypass the imported original command executor`, (t) => {
    const dir = fixture(t);
    mutate(dir, `${name}/index.ts`, "deps.executeImageGeneration(", "deps.unboundedProviderWork(");
    assert.throws(() => validateSupabaseEdgeContract(dir), /original image command admission/);
  });
}
test("shared generation cannot dispatch before claiming original admission", (t) => {
  const dir = fixture(t);
  mutate(dir, "_shared/admin_image_generation.ts", 'await admin.rpc("claim_admin_image_generation"', 'await admin.rpc("unverified_generation"');
  assert.throws(() => validateSupabaseEdgeContract(dir), /claim original admission before provider/);
});
for (const [from, to] of [
  ["if not budget.allowed then return", "if false then return"],
  ["perform public.assert_verified_staff_provider_proof(", "perform public.unverified_staff_proof("],
]) {
  test(`image database claim retains its denial/proof guard: ${from}`, (t) => {
    const dir = fixture(t);
    const file = path.join(dir, "supabase/migrations/20261001280000_verified_admin_image_generation.sql");
    const sql = fs.readFileSync(file, "utf8");
    assert.ok(sql.includes(from));
    fs.writeFileSync(file, sql.replaceAll(from, to));
    assert.throws(() => validateSupabaseEdgeContract(dir), /atomic rate limiter and post-wait original proof/);
  });
}
test("signed OTP hook must bound the body before signature verification", (t) => {
  const dir = fixture(t);
  mutate(dir, "send-sms/handler.ts", "readBoundedText(", "unboundedText(");
  assert.throws(() => validateSupabaseEdgeContract(dir), /bound the original body/);
});
test("management ingestion cannot omit verification of the signed request", (t) => {
  const dir = fixture(t);
  mutate(dir, "sms-ingest/index.ts", "verifySignedGatewayJson(", "acceptUnverifiedGateway(");
  assert.throws(() => validateSupabaseEdgeContract(dir), /required in-function control/);
});
test("settlement processing cannot replace its separate processor capability", (t) => {
  const dir = fixture(t);
  mutate(dir, "parse-momo-sms/index.ts", "requireSmsProcessor(", "acceptSupporter(");
  assert.throws(() => validateSupabaseEdgeContract(dir), /required in-function control/);
});
test("supporter authentication cannot be reintroduced as management ingress authority", (t) => {
  const dir = fixture(t);
  const target = path.join(dir, "supabase/functions/sms-ingest/index.ts");
  fs.appendFileSync(target, "\nvalidateRequest(request);\n");
  assert.throws(() => validateSupabaseEdgeContract(dir), /separate management\/processor capability/);
});
test("account closure receipt recovery still requires provider-verified user authentication", (t) => {
  const dir = fixture(t);
  mutate(dir, "delete-account/index.ts", ".auth.getUser(", ".auth.trustCachedUser(");
  assert.throws(() => validateSupabaseEdgeContract(dir), /required in-function control/);
});
