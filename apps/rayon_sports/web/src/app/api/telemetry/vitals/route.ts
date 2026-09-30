import { handleWebObservation } from "../../../../../../../../cloudflare/web-observations/http.mjs";
import { webObservationEnvironment } from "@/lib/web-observation-server";

export const dynamic = "force-dynamic";
export async function POST(request: Request) {
  return handleWebObservation(request, await webObservationEnvironment(), "web_vital");
}
