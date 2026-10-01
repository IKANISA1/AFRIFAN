import { afterEach } from "vitest";

declare module "@vitest/runner" {
  interface TaskMeta {
    localRouteAssertions?: Record<string, unknown>[];
  }
}

const clubs = [
  { slug: "as_vita", id: 6 },
  { slug: "costa_do_sol", id: 1001 },
  { slug: "nkana", id: 26 },
  { slug: "rayon_sports", id: 24 },
  { slug: "vitalo", id: 44 },
] as const;
const requested = process.env.AFRICLUB_LOCAL_HTTP_CLUB;
const selected = clubs.find((club) => club.slug === requested);
if (requested && !selected) throw new Error("Undeclared local HTTP fixture club");
export const httpFixtureClub = selected ?? clubs[3];
export const httpFixtureClubId = () => String(httpFixtureClub.id);
export const httpFixtureOrigin = (fallback = "https://africlub.invalid") => selected
  ? `https://${selected.slug.replaceAll("_", "-")}.example.test` : fallback;
export type HttpStateSpec = {
  name: string; route: string; state: string;
  surface?: "consumer_web";
  kind?: "http_route";
};

/** Explicit registrations refer to existing state-specific handler assertions.
 * Results and these task metadata are emitted together by the local reporter.
 * Failed, skipped, retried or interrupted executions cannot be admitted.
 */
export function registerLocalHttpAssertions(specs: HttpStateSpec[]) {
  if (!selected) return;
  afterEach((context) => {
    const specsForTest = specs.filter((spec) => spec.name === context.task.name);
    if (!specsForTest.length) return;
    context.task.meta.localRouteAssertions = specsForTest.map((spec) => ({
      localRouteAssertion: 1, surface: spec.surface ?? "web_api", route: spec.route,
      kind: spec.kind ?? "api_route", state: spec.state, club: selected.slug,
      assertions: ["finite controlled HTTP response"],
    }));
  });
}
