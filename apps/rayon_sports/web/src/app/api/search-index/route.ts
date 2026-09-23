import {
  controlledApiFailureResponse,
  controlledApiJson,
  withControlledApiTimeout,
} from "@/lib/controlled-api-response";
import { getSiteSearchIndex } from "@/lib/data/public";

export const revalidate = 300;

export async function GET() {
  try {
    const items = await withControlledApiTimeout(getSiteSearchIndex());
    return controlledApiJson(
      {
        code: items.length === 0 ? "SEARCH_INDEX_EMPTY" : "SEARCH_INDEX_READY",
        items,
      },
      200,
      {
        "Cache-Control":
          "public, max-age=0, s-maxage=300, stale-while-revalidate=600",
      },
    );
  } catch (error) {
    return controlledApiFailureResponse(error, "SEARCH_INDEX");
  }
}
