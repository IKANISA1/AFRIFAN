import { describe, expect, it } from "vitest";
import { androidPackageName, appleApplicationId } from "@/lib/app-associations";
import {
  GET as getAndroidAssociation,
  HEAD as headAndroidAssociation,
} from "./assetlinks.json/route";
import { GET as getAppleAssociation } from "./apple-app-site-association/route";

describe("well-known association routes", () => {
  it("serves Android Digital Asset Links without a redirect", async () => {
    const response = getAndroidAssociation();
    expect(response.status).toBe(200);
    expect(response.headers.get("location")).toBeNull();
    expect(response.headers.get("content-type")).toContain("application/json");
    const document = (await response.json()) as Array<{
      target: { package_name: string };
    }>;
    expect(document[0]?.target.package_name).toBe(androidPackageName);

    const headResponse = headAndroidAssociation();
    expect(headResponse.status).toBe(200);
    expect(await headResponse.text()).toBe("");
  });

  it("serves the Apple association with the production application id", async () => {
    const response = getAppleAssociation();
    expect(response.status).toBe(200);
    expect(response.headers.get("location")).toBeNull();
    expect(response.headers.get("content-type")).toContain("application/json");
    const document = (await response.json()) as {
      applinks: { details: Array<{ appIDs: string[] }> };
    };
    expect(document.applinks.details[0]?.appIDs).toContain(appleApplicationId);
  });
});
